#include "include/biometric_crypto/biometric_crypto_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "biometric_crypto_plugin.h"

void BiometricCryptoPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  biometric_crypto::BiometricCryptoPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
