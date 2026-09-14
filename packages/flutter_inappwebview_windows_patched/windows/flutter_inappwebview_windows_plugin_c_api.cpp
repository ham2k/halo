#include "include/flutter_inappwebview_windows/flutter_inappwebview_windows_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>
#include <flutter_plugin_registrar.h>

#include "flutter_inappwebview_windows_plugin.h"

void FlutterInappwebviewWindowsPluginCApiRegisterWithRegistrar(
  FlutterDesktopPluginRegistrarRef registrar)
{
  // The raw messenger is in hand only here: the C++ wrapper keeps its
  // registrar ref protected, and the plugin needs the messenger to ask the
  // engine whether it is still alive at teardown.
  flutter_inappwebview_plugin::FlutterInappwebviewWindowsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarManager::GetInstance()
    ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar),
    FlutterDesktopPluginRegistrarGetMessenger(registrar));
}
