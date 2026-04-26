import 'biometric_crypto_platform_interface.dart';

/// Main plugin class for biometric cryptographic operations.
///
/// [BiometricCrypto] provides secure key generation and cryptographic signing
/// using biometric authentication. Keys are stored in the Android Keystore (Android)
/// or Secure Enclave (iOS).
///
/// Example usage:
/// ```dart
/// final crypto = BiometricCrypto();
/// await crypto.generateKey('my_key');
/// final publicKey = await crypto.getPublicKey('my_key');
/// final signature = await crypto.sign('my_key', 'challenge_data');
/// ```
class BiometricCrypto {
  /// Generates a new cryptographic key pair with biometric protection.
  ///
  /// The generated key is stored securely in the Android Keystore (Android)
  /// or Secure Enclave (iOS) and requires biometric authentication for use.
  ///
  /// Parameters:
  ///   - [alias]: A unique identifier for the generated key
  ///
  /// Throws an exception if the operation fails or biometric authentication is cancelled.
  Future<void> generateKey(String alias) {
    return BiometricCryptoPlatform.instance.generateKey(alias);
  }

  /// Retrieves the public key corresponding to a previously generated key.
  ///
  /// This public key can be sent to your server for signature verification
  /// during biometric authentication flows.
  ///
  /// Parameters:
  ///   - [alias]: The identifier of the key to retrieve
  ///
  /// Returns: The public key in PEM format
  Future<String> getPublicKey(String alias) {
    return BiometricCryptoPlatform.instance.getPublicKey(alias);
  }

  /// Signs a challenge string using the specified key with biometric verification.
  ///
  /// Requires biometric authentication before the signing operation is performed.
  /// This is typically used for server-side validation of user authentication.
  ///
  /// Parameters:
  ///   - [alias]: The identifier of the key to use for signing
  ///   - [challenge]: The data to be signed (typically a server-provided nonce)
  ///
  /// Returns: The cryptographic signature in Base64 format
  Future<String> sign(String alias, String challenge) {
    return BiometricCryptoPlatform.instance.sign(alias, challenge);
  }

  /// Deletes a previously generated key from secure storage.
  ///
  /// Once deleted, the key cannot be recovered and will need to be regenerated.
  ///
  /// Parameters:
  ///   - [alias]: The identifier of the key to delete
  Future<void> deleteKey(String alias) {
    return BiometricCryptoPlatform.instance.deleteKey(alias);
  }

  /// Checks if biometric authentication is available on the device.
  ///
  /// Returns true if the device has biometric hardware and is enrolled with at least one biometric.
  /// Returns false if biometric is not supported or no biometric is enrolled.
  Future<bool> isBiometricAvailable() {
    return BiometricCryptoPlatform.instance.isBiometricAvailable();
  }

  /// Checks if a key with the given alias exists in secure storage.
  ///
  /// Parameters:
  ///   - [alias]: The identifier of the key to check
  ///
  /// Returns: true if the key exists, false otherwise
  Future<bool> keyExists(String alias) {
    return BiometricCryptoPlatform.instance.keyExists(alias);
  }

  /// Prompts the user for biometric authentication.
  ///
  /// Returns true if authentication succeeds, false if cancelled or failed.
  /// This is typically called before performing sensitive operations.
  Future<bool> authenticate() {
    return BiometricCryptoPlatform.instance.authenticate();
  }

  /// Retrieves the native platform version information.
  ///
  /// Useful for debugging and diagnostics.
  Future<String?> getPlatformVersion() {
    return BiometricCryptoPlatform.instance.getPlatformVersion();
  }
}
