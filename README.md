# 🔐 biometric_crypto

A robust Flutter plugin that provides **secure biometric authentication** with cryptographic key generation.

## ✨ Features

- **Secure Key Generation**: Generates RSA key pairs using platform-specific secure storage:
  - 🤖 AndroidKeyStore on Android
  - 🍎 Secure Enclave on iOS
- **Public Key Export**: Returns the public key for server-side verification
- **Biometric Authentication**: Seamless biometric sign-in verification
- **Cross-Platform**: Supports both Android and iOS

## 📋 Requirements

- Flutter SDK
- Android 5.0+ (API level 21) or iOS 12.0+

---

## 🚀 Getting Started

### Android Setup

#### 1. Update MainActivity

Ensure your `MainActivity` extends `FlutterFragmentActivity`:

```kotlin
class MainActivity : FlutterFragmentActivity() {
    // ...
}
```

#### 2. Add Required Permissions

Add the following permissions to your `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="android.permission.USE_FINGERPRINT" />
```

### iOS Setup

#### Add Face ID Usage Description

Add a Face ID usage description to your `Info.plist`:

```xml
<key>NSFaceIDUsageDescription</key>
<string>Biometric authentication is used to secure your account.</string>
```

---

## ⚠️ Important Notes

> **iOS Simulator Limitation**: The Secure Enclave is not available on the iOS Simulator. A biometric prompt will appear when calling authenticate methods before sign-in.

---

## 📚 Next Steps

- Explore the example app in the `example/` directory
- Check out the API documentation for detailed method references
- Review integration tests in `integration_test/` for implementation patterns

---

For questions, contributions, or to report issues, please visit the project repository or refer to the troubleshooting section in the documentation.
