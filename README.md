# biometric_crypto

`biometric_crypto` is a Flutter plugin that provides secure biometric authentication. It generates a key pair using AndroidKeyStore (on Android) or the Secure Enclave (on iOS) and returns the public key. The public key can then be sent to your server for verification during biometric sign-in.

> ⚠️ **Note:** On the iOS Simulator the Secure Enclave is not available. A biometric prompt will appear each time a key is generated.

## Getting Started

### Android

1. Ensure your `MainActivity` extends `FlutterFragmentActivity`:

```kotlin
class MainActivity : FlutterFragmentActivity() {
    // ...
}
```

2. Add the necessary permissions to your `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="android.permission.USE_FINGERPRINT" />
```

### iOS

Add a Face ID usage description to your `Info.plist`:

```xml
<key>NSFaceIDUsageDescription</key>
<string>Biometric authentication is used to secure your account.</string>
```

---

Feel free to extend this README with examples, API usage, or troubleshooting tips as needed.
