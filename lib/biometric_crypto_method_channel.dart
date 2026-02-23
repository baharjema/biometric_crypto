import 'package:flutter/services.dart';
import 'biometric_crypto_platform_interface.dart';

class MethodChannelBiometricCrypto extends BiometricCryptoPlatform {
  final MethodChannel _channel = const MethodChannel('biometric_crypto');

  @override
  Future<void> generateKey(String alias) async {
    await _channel.invokeMethod('generateKey', {
      'alias': alias,
    });
  }

  @override
  Future<String> getPublicKey(String alias) async {
    final result = await _channel.invokeMethod<String>(
      'getPublicKey',
      {'alias': alias},
    );

    if (result == null) {
      throw PlatformException(
        code: 'NULL_PUBLIC_KEY',
        message: 'Public key is null',
      );
    }

    return result;
  }

  @override
  Future<String> sign(String alias, String challenge) async {
    final result = await _channel.invokeMethod<String>(
      'sign',
      {
        'alias': alias,
        'challenge': challenge,
      },
    );

    if (result == null) {
      throw PlatformException(
        code: 'NULL_SIGNATURE',
        message: 'Signature is null',
      );
    }

    return result;
  }

  @override
  Future<void> deleteKey(String alias) async {
    await _channel.invokeMethod('deleteKey', {
      'alias': alias,
    });
  }

  @override
  Future<bool> keyExists(String alias) async {
    final result = await _channel.invokeMethod<bool>(
      'keyExists',
      {'alias': alias},
    );
    return result ?? false;
  }

  @override
  Future<bool> isBiometricAvailable() async {
    final result = await _channel.invokeMethod<bool>('isBiometricAvailable');
    return result ?? false;
  }

  @override
  Future<bool> authenticate() async {
    final result = await _channel.invokeMethod<bool>('authenticate');
    return result ?? false;
  }

  @override
  Future<String?> getPlatformVersion() async {
    return await _channel.invokeMethod<String>('getPlatformVersion');
  }
}
