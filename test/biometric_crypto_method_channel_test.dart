import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:biometric_crypto/biometric_crypto_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelBiometricCrypto platform = MethodChannelBiometricCrypto();
  const MethodChannel channel = MethodChannel('biometric_crypto');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
