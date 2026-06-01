import Cocoa
import FlutterMacOS
import LocalAuthentication
import Security

public class BiometricCryptoPlugin: NSObject, FlutterPlugin {

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "biometric_crypto", binaryMessenger: registrar.messenger)
    let instance = BiometricCryptoPlugin()
    instance.checkAndClearOnFreshInstall()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
      case "isBiometricAvailable":
        result(isBiometricAvailable())
      case "keyExists":
        guard let alias = requireString(from: call, key: "alias", result: result) else {
            return
        }
        result(keyExists(alias: alias))
      case "generateKey":
        guard let alias = requireString(from: call, key: "alias", result: result) else {
            return
        }
        generateKey(alias: alias, result: result)
      case "getPublicKey":
        guard let alias = requireString(from: call, key: "alias", result: result) else {
            return
        }
        getPublicKey(alias: alias, result: result)
      case "sign":
        guard let alias = requireString(from: call, key: "alias", result: result) else {
            return
        }
        guard let challenge = requireString(from: call, key: "challenge", result: result) else{
            return
        }
        sign(alias: alias, challenge: challenge, result: result)
      case "deleteKey":
        guard let alias = requireString(from: call, key: "alias", result: result) else {
            return
        }
        deleteKey(alias: alias, result: result)
       case "authenticate":
        authenticate { success, error in
            if success {
                result(true)
            } else {
                result(FlutterError(
                    code: "AUTH_FAILED",
                    message: error?.localizedDescription,
                    details: nil
                ))
            }
        }
      case "getPlatformVersion":
        result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
      default:
        result(FlutterMethodNotImplemented)
    }
  }

  private func checkAndClearOnFreshInstall() {
      let defaults = UserDefaults.standard
      let hasRunBeforeKey = "hasRunBefore_BiometricCrypto"
      
      if !defaults.bool(forKey: hasRunBeforeKey) {
          clearKeys()
          defaults.set(true, forKey: hasRunBeforeKey)
      }
  }

  private func requireString(
    from call: FlutterMethodCall,
    key: String,
    result: @escaping FlutterResult
    ) -> String? {

        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Arguments must be a map",
                details: nil
            ))
            return nil
        }
        guard let alias = args[key] as? String,
            !alias.trimmingCharacters(in: .whitespaces).isEmpty else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "\(key) is required",
                details: nil
            ))
            return nil
        }
        return alias
    }

  private func keyExists(alias: String) -> Bool {
      let tag = alias.data(using: .utf8)!
      let query: [String: Any] = [
          kSecClass as String: kSecClassKey,
          kSecAttrApplicationTag as String: tag,
          kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
          kSecReturnRef as String: false
      ]
      return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
  }

  private func isBiometricAvailable() -> Bool {
      let context = LAContext()
      var error: NSError?
      let available = context.canEvaluatePolicy(
          .deviceOwnerAuthenticationWithBiometrics,
          error: &error
      )
      return available
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

    private func generateKey(alias: String, result: FlutterResult) 
    {
        if keyExists(alias: alias) {
            deleteKey(alias: alias, result: { _ in })
        }
        let tag = alias.data(using: .utf8)!

        #if targetEnvironment(simulator)
        // ===== SIMULATOR (No Secure Enclave) =====
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag
            ]
        ]
        #else
        // ===== REAL DEVICE (Secure Enclave) =====
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryCurrentSet],
            nil
        ) else {
            result(FlutterError(
                code: "ACCESS_CONTROL_FAILED",
                message: "Unable to create access control",
                details: nil
            ))
            return
        }

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
        #endif

        var error: Unmanaged<CFError>?
        guard SecKeyCreateRandomKey(attributes as CFDictionary, &error) != nil else {
            let err = error?.takeRetainedValue()
            result(FlutterError(
                code: "KEY_GEN_FAILED",
                message: err?.localizedDescription ?? "Unknown error",
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
      let status = SecItemCopyMatching(query as CFDictionary, &item)
      guard status == errSecSuccess else {
          result(FlutterError(code: "KEY_NOT_FOUND", message: nil, details: nil))
          return
      }
      let privateKey = item as! SecKey
      guard let publicKey = SecKeyCopyPublicKey(privateKey),
            let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?
      else {
          result(FlutterError(code: "PUBKEY_FAILED", message: nil, details: nil))
          return
      }
      let spkiHeader: [UInt8] = [
        0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01,
        0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00
    ]
    
    // Gabungkan Header dengan Raw Data iOS
    var spkiData = Data(spkiHeader)
    spkiData.append(publicKeyData)
    
    // Return SPKI Data ke Flutter (lalu teruskan ke Server)
    result(spkiData.base64EncodedString())
  }

  private func sign(
    alias: String,
    challenge: String,
    result: @escaping FlutterResult
  ) {
      if !isBiometricAvailable() {
          result(FlutterError(code: "BIOMETRIC_NOT_AVAILABLE", message: nil, details: nil))
          return
      }
      let context = LAContext()
      context.localizedReason = "Authenticate to sign"
      let tag = alias.data(using: .utf8)!
      let challengeData = challenge.data(using: .utf8)!
      let query: [String: Any] = [
          kSecClass as String: kSecClassKey,
          kSecAttrApplicationTag as String: tag,
          kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
          kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
          kSecReturnRef as String: true,
          kSecUseAuthenticationContext as String: context,
          kSecUseOperationPrompt as String: "Authenticate to sign"
      ]
      var item: CFTypeRef?
      let status = SecItemCopyMatching(query as CFDictionary, &item)
      guard status == errSecSuccess else {
          result(FlutterError(code: "KEY_NOT_FOUND", message: nil, details: nil))
          return
      }
      let privateKey = item as! SecKey
      var error: Unmanaged<CFError>?
      guard let signature = SecKeyCreateSignature(
          privateKey,
          .ecdsaSignatureMessageX962SHA256,
          challengeData as CFData,
          &error
      ) as Data?
      else {
          result(FlutterError(
              code: "SIGN_FAILED",
              message: error?.takeRetainedValue().localizedDescription,
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

  private func clearKeys(){
     let query: [String: Any] = [
        kSecClass as String: kSecClassKey,
        kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom
      ]
      SecItemDelete(query as CFDictionary)
  }
}

