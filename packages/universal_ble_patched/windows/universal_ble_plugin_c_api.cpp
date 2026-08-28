#include "include/universal_ble/universal_ble_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "src/ham2k_ble_mode.h"
#include "src/universal_ble_plugin.h"

void UniversalBlePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar)
{
    // HALO-290: `off` skips registration entirely, so neither the top-level
    // window proc delegate nor any BLE channel exists. Returning before
    // `RegisterWithRegistrar` leaves the Dart side to fail with a
    // MissingPluginException on first use -- acceptable only because the peer
    // BLE sub-switch defaults off and nothing touches the plugin until it is
    // turned on (peer_service.dart's `wantBle`). See PATCH.md.
    const auto mode = ham2k::Ham2kBleMode();
    if (mode == ham2k::BleMode::kOff)
    {
        return;
    }

    // Split out so `registrar` can stop between the two. GetRegistrar builds
    // the Flutter wrapper's own registrar map, which is the first thing the
    // `off` arm skips and therefore the first suspect the ladder must clear.
    auto *windows_registrar =
        flutter::PluginRegistrarManager::GetInstance()
            ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar);
    if (mode == ham2k::BleMode::kRegistrarOnly)
    {
        return;
    }

    universal_ble::UniversalBlePlugin::RegisterWithRegistrar(windows_registrar);
}
