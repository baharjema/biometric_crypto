import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'biometric_crypto_method_channel.dart';

abstract class BiometricCryptoPlatform extends PlatformInterface {
  /// Constructs a BiometricCryptoPlatform.
  BiometricCryptoPlatform() : super(token: _token);

  static final Object _token = Object();

  static BiometricCryptoPlatform _instance = MethodChannelBiometricCrypto();

  /// The default instance of [BiometricCryptoPlatform] to use.
  ///
  /// Defaults to [MethodChannelBiometricCrypto].
  static BiometricCryptoPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [BiometricCryptoPlatform] when
  /// they register themselves.
  static set instance(BiometricCryptoPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
