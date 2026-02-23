import 'biometric_crypto_platform_interface.dart';

class BiometricCrypto {
  Future<void> generateKey(String alias) {
    return BiometricCryptoPlatform.instance.generateKey(alias);
  }

  Future<String> getPublicKey(String alias) {
    return BiometricCryptoPlatform.instance.getPublicKey(alias);
  }

  Future<String> sign(String alias, String challenge) {
    return BiometricCryptoPlatform.instance.sign(alias, challenge);
  }

  Future<void> deleteKey(String alias) {
    return BiometricCryptoPlatform.instance.deleteKey(alias);
  }

  Future<bool> isBiometricAvailable() {
    return BiometricCryptoPlatform.instance.isBiometricAvailable();
  }

  Future<bool> keyExists(String alias) {
    return BiometricCryptoPlatform.instance.keyExists(alias);
  }

  Future<bool> authenticate() {
    return BiometricCryptoPlatform.instance.authenticate();
  }

  Future<String?> getPlatformVersion() {
    return BiometricCryptoPlatform.instance.getPlatformVersion();
  }
}
