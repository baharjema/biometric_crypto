import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:biometric_crypto/biometric_crypto_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelBiometricCrypto platform = MethodChannelBiometricCrypto();
  const MethodChannel channel = MethodChannel('biometric_crypto');

  setUp(() {
    final Map<String, String> store = {};

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        final args = methodCall.arguments as dynamic;
        switch (methodCall.method) {
          case 'getPlatformVersion':
            return '42';
          case 'generateKey':
            store[args['alias'] as String] = 'pubkey_${args['alias']}';
            return null;
          case 'getPublicKey':
            final alias = args['alias'] as String;
            return store[alias]; // may be null to simulate missing key
          case 'sign':
            final alias = args['alias'] as String;
            final challenge = args['challenge'] as String;
            if (!store.containsKey(alias)) return null;
            return 'signature_${alias}_$challenge';
          case 'deleteKey':
            store.remove(args['alias'] as String);
            return null;
          case 'keyExists':
            return store.containsKey(args['alias'] as String);
          case 'isBiometricAvailable':
            return true;
          case 'authenticate':
            return true;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });

  test(
      'generateKey/getPublicKey/sign/deleteKey/keyExists/isBiometricAvailable/authenticate',
      () async {
    const alias = 'mc_test_key';

    // initially key does not exist
    expect(await platform.keyExists(alias), false);

    // generate key
    await platform.generateKey(alias);

    // key should exist
    expect(await platform.keyExists(alias), true);

    // get public key
    final pub = await platform.getPublicKey(alias);
    expect(pub, isNotNull);
    expect(pub!.isNotEmpty, true);

    // sign
    final sig = await platform.sign(alias, 'abc');
    expect(sig, 'signature_${alias}_abc');

    // biometric available
    expect(await platform.isBiometricAvailable(), true);

    // authenticate
    expect(await platform.authenticate(), true);

    // delete key
    await platform.deleteKey(alias);
    expect(await platform.keyExists(alias), false);

    // getPublicKey after delete should throw PlatformException
    expect(
        () => platform.getPublicKey(alias), throwsA(isA<PlatformException>()));

    // sign after delete should throw PlatformException
    expect(
        () => platform.sign(alias, 'abc'), throwsA(isA<PlatformException>()));
  });
}
