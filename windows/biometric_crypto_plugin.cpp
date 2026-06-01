#include "biometric_crypto_plugin.h"

#include <windows.h>
#include <ncrypt.h>
#include <bcrypt.h>
#include <wincrypt.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>
#include <vector>
#include <string>

#pragma comment(lib, "ncrypt.lib")
#pragma comment(lib, "bcrypt.lib")
#pragma comment(lib, "crypt32.lib")

namespace biometric_crypto {

static std::string base64_encode(const std::vector<uint8_t>& data) {
    DWORD chars = 0;
    CryptBinaryToStringA(data.data(), (DWORD)data.size(), CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF, NULL, &chars);
    std::string result(chars, '\0');
    CryptBinaryToStringA(data.data(), (DWORD)data.size(), CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF, &result[0], &chars);
    if (!result.empty() && result.back() == '\0') {
        result.pop_back();
    }
    return result;
}

static std::wstring utf8_to_utf16(const std::string& utf8) {
    if (utf8.empty()) return std::wstring();
    int size_needed = MultiByteToWideChar(CP_UTF8, 0, &utf8[0], (int)utf8.size(), NULL, 0);
    std::wstring utf16(size_needed, 0);
    MultiByteToWideChar(CP_UTF8, 0, &utf8[0], (int)utf8.size(), &utf16[0], size_needed);
    return utf16;
}

void BiometricCryptoPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "biometric_crypto",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<BiometricCryptoPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

BiometricCryptoPlugin::BiometricCryptoPlugin() {}

BiometricCryptoPlugin::~BiometricCryptoPlugin() {}

void BiometricCryptoPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    
    auto get_alias = [&]() -> std::wstring {
        const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
        if (args) {
            auto it = args->find(flutter::EncodableValue("alias"));
            if (it != args->end() && std::holds_alternative<std::string>(it->second)) {
                return utf8_to_utf16(std::get<std::string>(it->second));
            }
        }
        return L"";
    };

    if (method_call.method_name() == "getPlatformVersion") {
        result->Success(flutter::EncodableValue("Windows CNG"));
    } 
    else if (method_call.method_name() == "isBiometricAvailable") {
        NCRYPT_PROV_HANDLE hProv = 0;
        SECURITY_STATUS status = NCryptOpenStorageProvider(&hProv, MS_PLATFORM_CRYPTO_PROVIDER, 0);
        if (status == ERROR_SUCCESS) {
            NCryptFreeObject(hProv);
            result->Success(flutter::EncodableValue(true));
        } else {
            result->Success(flutter::EncodableValue(false));
        }
    }
    else if (method_call.method_name() == "keyExists") {
        std::wstring alias = get_alias();
        if (alias.empty()) { result->Error("INVALID_ARGS", "Missing alias"); return; }
        
        NCRYPT_PROV_HANDLE hProv = 0;
        NCRYPT_KEY_HANDLE hKey = 0;
        bool exists = false;
        if (NCryptOpenStorageProvider(&hProv, MS_PLATFORM_CRYPTO_PROVIDER, 0) == ERROR_SUCCESS) {
            if (NCryptOpenKey(hProv, &hKey, alias.c_str(), 0, 0) == ERROR_SUCCESS) {
                exists = true;
                NCryptFreeObject(hKey);
            }
            NCryptFreeObject(hProv);
        }
        result->Success(flutter::EncodableValue(exists));
    }
    else if (method_call.method_name() == "generateKey") {
        std::wstring alias = get_alias();
        if (alias.empty()) { result->Error("INVALID_ARGS", "Missing alias"); return; }
        
        NCRYPT_PROV_HANDLE hProv = 0;
        NCRYPT_KEY_HANDLE hKey = 0;
        if (NCryptOpenStorageProvider(&hProv, MS_PLATFORM_CRYPTO_PROVIDER, 0) == ERROR_SUCCESS) {
            if (NCryptOpenKey(hProv, &hKey, alias.c_str(), 0, 0) == ERROR_SUCCESS) {
                NCryptDeleteKey(hKey, 0);
            }
            
            if (NCryptCreatePersistedKey(hProv, &hKey, BCRYPT_ECDSA_P256_ALGORITHM, alias.c_str(), 0, 0) == ERROR_SUCCESS) {
                if (NCryptFinalizeKey(hKey, 0) == ERROR_SUCCESS) {
                    NCryptFreeObject(hKey);
                    NCryptFreeObject(hProv);
                    result->Success(flutter::EncodableValue(true));
                    return;
                }
                NCryptFreeObject(hKey);
            }
            NCryptFreeObject(hProv);
        }
        result->Error("KEY_GEN_FAILED", "Failed to generate CNG key");
    }
    else if (method_call.method_name() == "getPublicKey") {
        std::wstring alias = get_alias();
        if (alias.empty()) { result->Error("INVALID_ARGS", "Missing alias"); return; }
        
        NCRYPT_PROV_HANDLE hProv = 0;
        NCRYPT_KEY_HANDLE hKey = 0;
        std::string pubkeyB64;
        bool success = false;
        
        if (NCryptOpenStorageProvider(&hProv, MS_PLATFORM_CRYPTO_PROVIDER, 0) == ERROR_SUCCESS) {
            if (NCryptOpenKey(hProv, &hKey, alias.c_str(), 0, 0) == ERROR_SUCCESS) {
                DWORD cbResult = 0;
                if (NCryptExportKey(hKey, 0, BCRYPT_ECCPUBLIC_BLOB, NULL, NULL, 0, &cbResult, 0) == ERROR_SUCCESS) {
                    std::vector<BYTE> blob(cbResult);
                    if (NCryptExportKey(hKey, 0, BCRYPT_ECCPUBLIC_BLOB, NULL, blob.data(), cbResult, &cbResult, 0) == ERROR_SUCCESS) {
                        if (blob.size() >= sizeof(BCRYPT_ECCKEY_BLOB)) {
                            BCRYPT_ECCKEY_BLOB* header = (BCRYPT_ECCKEY_BLOB*)blob.data();
                            if (header->cbKey == 32) {
                                std::vector<uint8_t> spki = {
                                    0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01,
                                    0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00, 0x04
                                };
                                uint8_t* raw_key = blob.data() + sizeof(BCRYPT_ECCKEY_BLOB);
                                spki.insert(spki.end(), raw_key, raw_key + 64);
                                pubkeyB64 = base64_encode(spki);
                                success = true;
                            }
                        }
                    }
                }
                NCryptFreeObject(hKey);
            }
            NCryptFreeObject(hProv);
        }
        
        if (success) {
            result->Success(flutter::EncodableValue(pubkeyB64));
        } else {
            result->Error("PUBKEY_FAILED", "Failed to retrieve public key");
        }
    }
    else if (method_call.method_name() == "deleteKey") {
        std::wstring alias = get_alias();
        if (alias.empty()) { result->Error("INVALID_ARGS", "Missing alias"); return; }
        
        NCRYPT_PROV_HANDLE hProv = 0;
        NCRYPT_KEY_HANDLE hKey = 0;
        if (NCryptOpenStorageProvider(&hProv, MS_PLATFORM_CRYPTO_PROVIDER, 0) == ERROR_SUCCESS) {
            if (NCryptOpenKey(hProv, &hKey, alias.c_str(), 0, 0) == ERROR_SUCCESS) {
                NCryptDeleteKey(hKey, 0);
            }
            NCryptFreeObject(hProv);
        }
        result->Success();
    }
    else if (method_call.method_name() == "sign") {
        std::wstring alias = get_alias();
        if (alias.empty()) { result->Error("INVALID_ARGS", "Missing alias"); return; }
        
        std::string challenge;
        const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
        if (args) {
            auto it = args->find(flutter::EncodableValue("challenge"));
            if (it != args->end() && std::holds_alternative<std::string>(it->second)) {
                challenge = std::get<std::string>(it->second);
            }
        }
        if (challenge.empty()) { result->Error("INVALID_ARGS", "Missing challenge"); return; }
        
        // Hash challenge (SHA-256)
        BCRYPT_ALG_HANDLE hAlg = NULL;
        BCRYPT_HASH_HANDLE hHash = NULL;
        std::vector<BYTE> hash(32);
        DWORD cbData = 0, cbHash = 0;
        
        if (BCryptOpenAlgorithmProvider(&hAlg, BCRYPT_SHA256_ALGORITHM, NULL, 0) == ERROR_SUCCESS) {
            if (BCryptCreateHash(hAlg, &hHash, NULL, 0, NULL, 0, 0) == ERROR_SUCCESS) {
                BCryptHashData(hHash, (PUCHAR)challenge.data(), (ULONG)challenge.size(), 0);
                BCryptFinishHash(hHash, hash.data(), (ULONG)hash.size(), 0);
                BCryptDestroyHash(hHash);
            }
            BCryptCloseAlgorithmProvider(hAlg, 0);
        }
        
        NCRYPT_PROV_HANDLE hProv = 0;
        NCRYPT_KEY_HANDLE hKey = 0;
        std::string sigB64;
        bool success = false;
        
        if (NCryptOpenStorageProvider(&hProv, MS_PLATFORM_CRYPTO_PROVIDER, 0) == ERROR_SUCCESS) {
            if (NCryptOpenKey(hProv, &hKey, alias.c_str(), 0, 0) == ERROR_SUCCESS) {
                
                DWORD cbResult = 0;
                // Note: BCRYPT_PAD_PKCS1 is only for RSA. ECDSA uses 0/NULL padding.
                if (NCryptSignHash(hKey, NULL, hash.data(), (DWORD)hash.size(), NULL, 0, &cbResult, 0) == ERROR_SUCCESS) {
                    std::vector<BYTE> sig(cbResult);
                    if (NCryptSignHash(hKey, NULL, hash.data(), (DWORD)hash.size(), sig.data(), cbResult, &cbResult, 0) == ERROR_SUCCESS) {
                        sigB64 = base64_encode(sig);
                        success = true;
                    }
                }
                NCryptFreeObject(hKey);
            }
            NCryptFreeObject(hProv);
        }
        
        if (success) {
            result->Success(flutter::EncodableValue(sigB64));
        } else {
            result->Error("SIGN_FAILED", "Failed to sign challenge");
        }
    }
    else {
        result->NotImplemented();
    }
}

}  // namespace biometric_crypto
