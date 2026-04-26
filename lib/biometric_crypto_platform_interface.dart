import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'biometric_crypto_method_channel.dart';

/// Platform interface for biometric cryptographic operations.
///
/// This abstract class defines the contract that platform implementations
/// (Android and iOS) must follow.
abstract class BiometricCryptoPlatform extends PlatformInterface {
  /// Constructor for the platform interface.
  BiometricCryptoPlatform() : super(token: _token);

  static final Object _token = Object();

  static BiometricCryptoPlatform _instance = MethodChannelBiometricCrypto();

  static BiometricCryptoPlatform get instance => _instance;

  static set instance(BiometricCryptoPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Generates a new cryptographic key pair with biometric protection.
  Future<void> generateKey(String alias) {
    throw UnimplementedError('generateKey() not implemented');
  }

  /// Retrieves the public key in PEM format.
  Future<String> getPublicKey(String alias) {
    throw UnimplementedError('getPublicKey() not implemented');
  }

  /// Signs a challenge with biometric verification.
  Future<String> sign(String alias, String challenge) {
    throw UnimplementedError('sign() not implemented');
  }

  /// Deletes a key from secure storage.
  Future<void> deleteKey(String alias) {
    throw UnimplementedError('deleteKey() not implemented');
  }

  /// Retrieves platform version information.
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() not implemented');
  }

  /// Checks if a key exists in secure storage.
  Future<bool> keyExists(String alias) {
    throw UnimplementedError('keyExists() not implemented');
  }

  /// Checks if biometric authentication is available.
  Future<bool> isBiometricAvailable() {
    throw UnimplementedError('isBiometricAvailable() not implemented');
  }

  /// Prompts for biometric authentication.
  Future<bool> authenticate() {
    throw UnimplementedError('authenticate() not implemented');
  }
}
