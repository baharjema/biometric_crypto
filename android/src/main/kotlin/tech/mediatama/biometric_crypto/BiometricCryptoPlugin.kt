package tech.mediatama.biometric_crypto

import android.content.Context
import android.util.Base64
import android.app.Activity
//import android.util.Log
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat

import java.security.KeyStore
import java.security.KeyPairGenerator
import java.security.PrivateKey
import java.security.Signature
import java.security.MessageDigest

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties

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

    // The MethodChannel that will the communication between Flutter and native Android
    //
    // This local reference serves to register the plugin with the Flutter Engine and unregister it
    // when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private val keystore = KeyStore.getInstance("AndroidKeyStore")
    private var activity: FragmentActivity? = null
    private lateinit var appContext: Context

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity as FragmentActivity
        // val currentActivity = binding.activity
        // if (currentActivity is FragmentActivity) {
        //     activity = currentActivity
        // } else {
        //     Log.e("BiometricCrypto", "GAGAL ATTACH ACTIVITY: MainActivity harus extends FlutterFragmentActivity, bukan FlutterActivity biasa.")
        //     activity = null
        // }
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

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        appContext = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "biometric_crypto")
        channel.setMethodCallHandler(this)
        keystore.load(null)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        //val alias = call.argument<String>("alias")!!
        when (call.method) {
            "isBiometricAvailable" -> {
                isBiometricAvailable(result)
            }
            "keyExists" -> {
                val alias = requireString(call, "alias", result) ?: return
                val exists = keyExists(alias)
                result.success(exists)
            }
            "generateKey" -> {
                val alias = requireString(call, "alias", result) ?: return
                generateKey(alias)
                result.success(null)
            }
            "authenticate" -> {
                if (activity == null) {
                    result.error(
                        "NO_ACTIVITY",
                        "Plugin requires a foreground activity.",
                        null
                    )
                    return
                }
                authenticate(activity!!, result)
            }
            "sign" -> {
                val alias = requireString(call, "alias", result) ?: return
                val challenge = requireString(call, "challenge", result) ?: return
                signWithBiometric(alias, challenge, result)
            }
            "getPublicKey" -> {
                val alias = requireString(call, "alias", result) ?: return
                getPublicKeyBase64(alias, result)
            }
            "deleteKey" -> {
                val alias = requireString(call, "alias", result) ?: return
                deleteKey(alias, result)
            }
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            else -> result.notImplemented()
        }
    }

    private fun requireString(
        call: MethodCall,
        key: String,
        result: MethodChannel.Result
    ): String? {
        val value = call.argument<String>(key)
        if (value.isNullOrBlank()) {
            result.error(
                "INVALID_ARGS",
                "$key is required",
                null
            )
            return null
        }
        return value
    }

    private fun keyExists(alias: String): Boolean {
        return keystore.containsAlias(alias)
    }

    private fun deleteKey(alias: String, result: MethodChannel.Result) {
        try{
            if (keystore.containsAlias(alias)) {
                keystore.deleteEntry(alias)
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("KEYSTORE_ERROR", e.message, null)
        }
    }

    private fun isBiometricAvailable(result: MethodChannel.Result){
        val ctx: Context = activity ?: appContext
        if (ctx == null) {
            result.error("NO_CONTEXT", "No context available", null)
            return
        }
        try {
            val manager = BiometricManager.from(ctx)
            val canAuthenticate = manager.canAuthenticate(
                BiometricManager.Authenticators.BIOMETRIC_STRONG or
                BiometricManager.Authenticators.DEVICE_CREDENTIAL
            )
            
            android.util.Log.d("BiometricCrypto", "canAuthenticate result: $canAuthenticate")
            
            when(canAuthenticate) {
                BiometricManager.BIOMETRIC_SUCCESS -> {
                    result.success(true)
                }
                11 -> {
                    // BIOMETRIC_ERROR_NONE_ENROLLED / NO_BIOMETRICS
                    result.error("NO_BIOMETRICS", "No biometrics enrolled on this device", null)
                }
                BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE -> {
                    result.error("HW_UNAVAILABLE", "Biometric hardware unavailable", null)
                }
                else -> {
                    result.error("BIOMETRIC_NOT_AVAILABLE", "Biometric authentication is not available: $canAuthenticate", null)
                }
            }
        } catch (e: Exception) {
            result.error("BIOMETRIC_ERROR", e.message, null)
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
                    //result.success(false)
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
                BiometricManager.Authenticators.BIOMETRIC_STRONG or
                BiometricManager.Authenticators.DEVICE_CREDENTIAL
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
                BiometricManager.Authenticators.BIOMETRIC_STRONG or
                BiometricManager.Authenticators.DEVICE_CREDENTIAL
            )
            .build()

        biometricPrompt.authenticate(
            promptInfo,
            BiometricPrompt.CryptoObject(signature)
        )
    }

    private fun getPublicKeyBase64(alias: String, result: MethodChannel.Result) {
        try {
            if (!keystore.containsAlias(alias)) {
                result.error("KEY_NOT_FOUND", "Key with alias $alias not found", null)
            }
            val cert = keystore.getCertificate(alias)
            val publicKey = cert.publicKey.encoded
            val base64PublicKey = Base64.encodeToString(publicKey, Base64.NO_WRAP)
            result.success(base64PublicKey)
        } catch (e: Exception) {
            result.error("KEYSTORE_ERROR", e.message, null)
        }
    }
}
