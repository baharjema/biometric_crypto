import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'biometric_crypto_platform_interface.dart';

/// An implementation of [BiometricCryptoPlatform] that uses method channels.
class MethodChannelBiometricCrypto extends BiometricCryptoPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('biometric_crypto');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
