import 'package:flutter_test/flutter_test.dart';
import 'package:biometric_crypto/biometric_crypto.dart';
import 'package:biometric_crypto/biometric_crypto_platform_interface.dart';
import 'package:biometric_crypto/biometric_crypto_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockBiometricCryptoPlatform
    with MockPlatformInterfaceMixin
    implements BiometricCryptoPlatform {
  final Map<String, String> _keys = {};

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<bool> authenticate() async {
    return true;
  }

  @override
  Future<void> deleteKey(String alias) async {
    _keys.remove(alias);
  }

  @override
  Future<void> generateKey(String alias) async {
    // create a dummy public key
    _keys[alias] = 'pubkey_${alias}';
  }

  @override
  Future<String> getPublicKey(String alias) async {
    final key = _keys[alias];
    if (key == null) throw StateError('Key not found');
    return key;
  }

  @override
  Future<bool> isBiometricAvailable() async {
    return true;
  }

  @override
  Future<bool> keyExists(String alias) async {
    return _keys.containsKey(alias);
  }

  @override
  Future<String> sign(String alias, String challenge) async {
    if (!_keys.containsKey(alias)) throw StateError('Key not found');
    return 'signature_${alias}_$challenge';
  }
}

void main() {
  final BiometricCryptoPlatform initialPlatform =
      BiometricCryptoPlatform.instance;

  test('$MethodChannelBiometricCrypto is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelBiometricCrypto>());
  });

  test('getPlatformVersion', () async {
    final biometricCryptoPlugin = BiometricCrypto();
    final fakePlatform = MockBiometricCryptoPlatform();
    BiometricCryptoPlatform.instance = fakePlatform;

    expect(await biometricCryptoPlugin.getPlatformVersion(), '42');
  });

  const alias = 'biometric_test_key';

  test('full lifecycle and API surface', () async {
    final plugin = BiometricCrypto();
    final fake = MockBiometricCryptoPlatform();
    BiometricCryptoPlatform.instance = fake;

    // biometric availability
    expect(await plugin.isBiometricAvailable(), true);

    // key should not exist yet
    expect(await plugin.keyExists(alias), false);

    // generate key
    await plugin.generateKey(alias);
    expect(await plugin.keyExists(alias), true);

    // get public key
    final pubKey = await plugin.getPublicKey(alias);
    expect(pubKey, isNotNull);
    expect(pubKey.isNotEmpty, true);

    // sign
    final signature = await plugin.sign(alias, 'challenge');
    expect(signature, 'signature_${alias}_challenge');

    // authenticate
    expect(await plugin.authenticate(), true);

    // delete and verify removal
    await plugin.deleteKey(alias);
    expect(await plugin.keyExists(alias), false);

    // signing with deleted key should throw
    expect(() => plugin.sign(alias, 'challenge'), throwsA(isA<StateError>()));
  });
}
