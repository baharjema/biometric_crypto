package tech.mediatama.biometric_crypto

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** BiometricCryptoPlugin */
class BiometricCryptoPlugin :
    FlutterPlugin,
    MethodCallHandler {
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
            "generateKey" -> {
                generateKey(alias)
                result.success(null)
            }
            "sign" -> {
                val challenge = call.argument<String>("challenge")!!
                val sig = sign(alias, challenge)
                result.success(sig)
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

    private fun isBiometricAvailable(context: Context): Boolean {
        val biometricManager = BiometricManager.from(context)
        return when (biometricManager.canAuthenticate(
            BiometricManager.Authenticators.BIOMETRIC_STRONG
        )) {
            BiometricManager.BIOMETRIC_SUCCESS -> true
            else -> false
        }
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
        activity: FragmentActivity,
        alias: String,
        challenge: String,
        result: MethodChannel.Result
        ) {

        val privateKey = keystore.getKey(alias, null) as PrivateKey
        val signature = Signature.getInstance("SHA256withECDSA")
        signature.initSign(privateKey)

        val executor = ContextCompat.getMainExecutor(activity)

        val biometricPrompt = BiometricPrompt(
            activity,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {

                override fun onAuthenticationSucceeded(
                    authResult: BiometricPrompt.AuthenticationResult
                ) {
                    val crypto = authResult.cryptoObject?.signature
                    crypto?.update(challenge.toByteArray(Charsets.UTF_8))
                    val signed = crypto?.sign()

                    val base64 = Base64.encodeToString(
                        signed,
                        Base64.NO_WRAP
                    )

                    result.success(base64)
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
            .setTitle("Sign with biometrics")
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
