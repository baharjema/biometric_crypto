import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'biometric_crypto_method_channel.dart';

abstract class BiometricCryptoPlatform extends PlatformInterface {
  BiometricCryptoPlatform() : super(token: _token);

  static final Object _token = Object();

  static BiometricCryptoPlatform _instance = MethodChannelBiometricCrypto();

  static BiometricCryptoPlatform get instance => _instance;

  static set instance(BiometricCryptoPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> generateKey(String alias) {
    throw UnimplementedError('generateKey() not implemented');
  }

  Future<String> getPublicKey(String alias) {
    throw UnimplementedError('getPublicKey() not implemented');
  }

  Future<String> sign(String alias, String challenge) {
    throw UnimplementedError('sign() not implemented');
  }

  Future<void> deleteKey(String alias) {
    throw UnimplementedError('deleteKey() not implemented');
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() not implemented');
  }

  Future<bool> keyExists(String alias) {
    throw UnimplementedError('keyExists() not implemented');
  }

  Future<bool> isBiometricAvailable() {
    throw UnimplementedError('isBiometricAvailable() not implemented');
  }

  Future<bool> authenticate() {
    throw UnimplementedError('authenticate() not implemented');
  }
}
