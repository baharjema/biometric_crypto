import Flutter
import UIKit
import LocalAuthentication
import Security

public class BiometricCryptoPlugin: NSObject, FlutterPlugin {

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "biometric_crypto", binaryMessenger: registrar.messenger())
    let instance = BiometricCryptoPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let alias = args["alias"] as? String
    else {
      result(FlutterError(
        code: "INVALID_ARGS",
        message: "Missing alias",
        details: nil
      ))
      return
    }
    switch call.method {
      case "generateKey":
        generateKey(alias: alias, result: result)
      case "getPublicKey":
        getPublicKey(alias: alias, result: result)
      case "sign":
        let challenge = args["challenge"] as! String
        sign(alias: alias, challenge: challenge, result: result)
      case "deleteKey":
        deleteKey(alias: alias, result: result)
      case "getPlatformVersion":
        result("iOS " + UIDevice.current.systemVersion)
      default:
        result(FlutterMethodNotImplemented)
    }
  }

  private func keyExists(alias: String) -> Bool {
    let query: [String: Any] = [
        kSecClass as String: kSecClassKey,
        kSecAttrApplicationTag as String: alias.data(using: .utf8)!,
        kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
        kSecReturnRef as String: true
    ]

    let status = SecItemCopyMatching(query as CFDictionary, nil)
    return status == errSecSuccess
  }

  private func isBiometricAvailable() -> Bool {
    let context = LAContext()
    var error: NSError?

    return context.canEvaluatePolicy(
        .deviceOwnerAuthenticationWithBiometrics,
        error: &error
    )
  }

  private func authenticate(
    completion: @escaping (Bool, Error?) -> Void
  ) {
      let context = LAContext()

      context.evaluatePolicy(
          .deviceOwnerAuthenticationWithBiometrics,
          localizedReason: "Authenticate to continue"
      ) { success, error in
          DispatchQueue.main.async {
              completion(success, error)
          }
      }
  }

  private func generateKey(alias: String, result: FlutterResult) {

    let tag = alias.data(using: .utf8)!

    // Cek jika key sudah ada
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrApplicationTag as String: tag,
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeyClass as String: kSecAttrKeyClassPrivate
    ]

    var item: CFTypeRef?
    if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess {
      result(nil) // key sudah ada
      return
    }

    let access =
      SecAccessControlCreateWithFlags(
        nil,
        kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        [.privateKeyUsage, .biometryCurrentSet],
        nil
      )!

    let attributes: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeySizeInBits as String: 256,
      kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
      kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String: true,
        kSecAttrApplicationTag as String: tag,
        kSecAttrAccessControl as String: access
      ]
    ]

    var error: Unmanaged<CFError>?
    guard SecKeyCreateRandomKey(attributes as CFDictionary, &error) != nil else {
      result(FlutterError(
        code: "KEY_GEN_FAILED",
        message: error!.takeRetainedValue().localizedDescription,
        details: nil
      ))
      return
    }

    result(nil)
  }
  private func getPublicKey(alias: String, result: FlutterResult) {

    let tag = alias.data(using: .utf8)!

    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrApplicationTag as String: tag,
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
      kSecReturnRef as String: true
    ]

    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
          let privateKey = item as? SecKey
    else {
      result(FlutterError(code: "KEY_NOT_FOUND", message: nil, details: nil))
      return
    }

    guard let publicKey = SecKeyCopyPublicKey(privateKey),
          let data = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?
    else {
      result(FlutterError(code: "PUBKEY_FAILED", message: nil, details: nil))
      return
    }

    // DER / SPKI compatible dengan .NET
    result(data.base64EncodedString())
  }

  private func sign(
  alias: String,
  challenge: String,
  result: @escaping FlutterResult
  ) {

    let context = LAContext()
    context.localizedReason = "Login dengan Face ID"

    let tag = alias.data(using: .utf8)!
    let data = challenge.data(using: .utf8)!

    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrApplicationTag as String: tag,
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
      kSecReturnRef as String: true,
      kSecUseAuthenticationContext as String: context
    ]

    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
          let privateKey = item as? SecKey
    else {
      result(FlutterError(code: "KEY_NOT_FOUND", message: nil, details: nil))
      return
    }

    var error: Unmanaged<CFError>?
    guard let signature = SecKeyCreateSignature(
      privateKey,
      .ecdsaSignatureMessageX962SHA256,
      data as CFData,
      &error
    ) as Data?
    else {
      result(FlutterError(
        code: "SIGN_FAILED",
        message: error!.takeRetainedValue().localizedDescription,
        details: nil
      ))
      return
    }

    result(signature.base64EncodedString())
  }

  private func deleteKey(alias: String, result: FlutterResult) {

    let tag = alias.data(using: .utf8)!

    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrApplicationTag as String: tag,
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom
    ]

    SecItemDelete(query as CFDictionary)
    result(nil)
  }
}
