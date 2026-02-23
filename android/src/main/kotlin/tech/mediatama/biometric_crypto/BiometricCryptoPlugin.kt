package tech.mediatama.biometric_crypto

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import androidx.fragment.app.FragmentActivity

/** BiometricCryptoPlugin */
class BiometricCryptoPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware {

    private var activity: FragmentActivity? = null

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity as FragmentActivity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }
    // The MethodChannel that will the communication between Flutter and native Android
    //
    // This local reference serves to register the plugin with the Flutter Engine and unregister it
    // when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private val keystore = KeyStore.getInstance("AndroidKeyStore")


    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "biometric_crypto")
        channel.setMethodCallHandler(this)
        keystore.load(null)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        val alias = call.argument<String>("alias")!!
        when (call.method) {
            "isBiometricAvailable" -> {
                val available = isBiometricAvailable()
                result.success(available)
            }
            "keyExists" -> {
                val exists = keyExists(alias)
                result.success(exists)
            }
            "generateKey" -> {
                generateKey(alias)
                result.success(null)
            }
            "sign" -> {
                val challenge = call.argument<String>("challenge")!!
                signWithBiometric(alias, challenge, result)
                //result.success(sig)
            }
            "getPublicKey" -> {
                val publicKey = getPublicKeyBase64(alias)
                result.success(publicKey)
            }
            "deleteKey" -> {
                keystore.deleteEntry(alias)
                result.success(null)
            }
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private fun keyExists(alias: String): Boolean {
        return keystore.containsAlias(alias)
    }

    private fun isBiometricAvailable(): Boolean {
        val manager = BiometricManager.from(activity!!)
        return manager.canAuthenticate(
            BiometricManager.Authenticators.BIOMETRIC_STRONG
        ) == BiometricManager.BIOMETRIC_SUCCESS
    }

    private fun authenticate(
        activity: FragmentActivity,
        result: MethodChannel.Result
        ) {

        val executor = ContextCompat.getMainExecutor(activity)

        val biometricPrompt = BiometricPrompt(
            activity,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {

                override fun onAuthenticationSucceeded(
                    authenticationResult: BiometricPrompt.AuthenticationResult
                ) {
                    result.success(true)
                }

                override fun onAuthenticationFailed() {
                    result.success(false)
                }

                override fun onAuthenticationError(
                    errorCode: Int,
                    errString: CharSequence
                ) {
                    result.error(
                        "AUTH_ERROR",
                        errString.toString(),
                        null
                    )
                }
            }
        )

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Authenticate")
            .setSubtitle("Confirm your identity")
            .setAllowedAuthenticators(
                BiometricManager.Authenticators.BIOMETRIC_STRONG
            )
            .build()

        biometricPrompt.authenticate(promptInfo)
    }

    private fun generateKey(alias: String) {
        if (keystore.containsAlias(alias)) return

        val kpg = KeyPairGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_EC,
            "AndroidKeyStore"
        )

        kpg.initialize(
            KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
            )
            .setDigests(KeyProperties.DIGEST_SHA256)
            .setUserAuthenticationRequired(true)
            .setUserAuthenticationParameters(
                0,
                KeyProperties.AUTH_BIOMETRIC_STRONG
            )
            .build()
        )

        kpg.generateKeyPair()
    }
    private fun sign(alias: String, challenge: String): String {
        val privateKey = keystore.getKey(alias, null) as PrivateKey

        val signature = Signature.getInstance("SHA256withECDSA")
        signature.initSign(privateKey)
        signature.update(challenge.toByteArray(Charsets.UTF_8))

        val signed = signature.sign()
        return Base64.encodeToString(signed, Base64.NO_WRAP)
    }

    private fun signWithBiometric(
    alias: String,
    challenge: String,
    result: MethodChannel.Result
    ) {

        val privateKey = keystore.getKey(alias, null) as PrivateKey
        val signature = Signature.getInstance("SHA256withECDSA")
        signature.initSign(privateKey)

        val executor = ContextCompat.getMainExecutor(activity!!)

        val biometricPrompt = BiometricPrompt(
            activity!!,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {

                override fun onAuthenticationSucceeded(
                    authResult: BiometricPrompt.AuthenticationResult
                ) {
                    val crypto = authResult.cryptoObject?.signature

                    val challengeHash =
                        MessageDigest.getInstance("SHA-256")
                            .digest(challenge.toByteArray(Charsets.UTF_8))

                    crypto?.update(challengeHash)
                    val signed = crypto?.sign()

                    result.success(
                        Base64.encodeToString(signed, Base64.NO_WRAP)
                    )
                }

                override fun onAuthenticationError(
                    errorCode: Int,
                    errString: CharSequence
                ) {
                    result.error("SIGN_ERROR", errString.toString(), null)
                }
            }
        )

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Biometric Authentication")
            .setSubtitle("Confirm to sign challenge")
            .setAllowedAuthenticators(
                BiometricManager.Authenticators.BIOMETRIC_STRONG
            )
            .build()

        biometricPrompt.authenticate(
            promptInfo,
            BiometricPrompt.CryptoObject(signature)
        )
    }

    private fun getPublicKeyBase64(alias: String): String {
        val cert = keystore.getCertificate(alias)
        val publicKey = cert.publicKey.encoded
        return Base64.encodeToString(publicKey, Base64.NO_WRAP)
    }
}
