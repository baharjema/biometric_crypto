import 'package:flutter/services.dart';

import 'biometric_crypto_platform_interface.dart';

class BiometricCrypto {
  static const MethodChannel _channel = MethodChannel('biometric_crypto');

  static Future<void> generateKey(String alias) async {
    await _channel.invokeMethod('generateKey', {'alias': alias});
  }

  static Future<String> getPublicKey(String alias) async {
    final publicKey = await _channel.invokeMethod<String>('getPublicKey', {
      'alias': alias,
    });
    return publicKey!;
  }

  /// Sign challenge (biometric prompt muncul di sini)
  static Future<String> sign(String alias, String challenge) async {
    final signature = await _channel.invokeMethod<String>('sign', {
      'alias': alias,
      'challenge': challenge,
    });
    return signature!;
  }

  /// Delete key (revoke local)
  static Future<void> deleteKey(String alias) async {
    await _channel.invokeMethod('deleteKey', {'alias': alias});
  }

  Future<String?> getPlatformVersion() {
    return BiometricCryptoPlatform.instance.getPlatformVersion();
  }
}
