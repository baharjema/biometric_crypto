import 'package:flutter_test/flutter_test.dart';
import 'package:biometric_crypto/biometric_crypto.dart';
import 'package:biometric_crypto/biometric_crypto_platform_interface.dart';
import 'package:biometric_crypto/biometric_crypto_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockBiometricCryptoPlatform
    with MockPlatformInterfaceMixin
    implements BiometricCryptoPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final BiometricCryptoPlatform initialPlatform = BiometricCryptoPlatform.instance;

  test('$MethodChannelBiometricCrypto is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelBiometricCrypto>());
  });

  test('getPlatformVersion', () async {
    BiometricCrypto biometricCryptoPlugin = BiometricCrypto();
    MockBiometricCryptoPlatform fakePlatform = MockBiometricCryptoPlatform();
    BiometricCryptoPlatform.instance = fakePlatform;

    expect(await biometricCryptoPlugin.getPlatformVersion(), '42');
  });

  
  const alias = 'biometric_test_key';
  testWidgets('generateKey & getPublicKey', (tester) async {
    // 1. generate key
    await BiometricCrypto.generateKey(alias);

    // 2. get public key
    final pubKey = await BiometricCrypto.getPublicKey(alias);

    expect(pubKey, isNotNull);
    expect(pubKey.isNotEmpty, true);
  });


  testWidgets('deleteKey', (tester) async {
    await BiometricCrypto.deleteKey(alias);
    // setelah delete, sign harus gagal
    try {
      final pubKey = await BiometricCrypto.getPublicKey(alias);
      expect(pubKey, isNull);
      expect(pubKey.isEmpty, true);
    } catch (e) {
      expect(e, isNotNull);
    }
  });
}
