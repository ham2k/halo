#ifndef FLUTTER_PLUGIN_FLUTTER_INAPPWEBVIEW_PLUGIN_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_INAPPWEBVIEW_PLUGIN_PLUGIN_H_

#include <flutter/plugin_registrar_windows.h>
#include <flutter_messenger.h>

namespace flutter_inappwebview_plugin
{
  class WebViewEnvironmentManager;
  class InAppWebViewManager;
  class InAppBrowserManager;
  class HeadlessInAppWebViewManager;
  class CookieManager;
  class PlatformUtil;

  class FlutterInappwebviewWindowsPlugin : public flutter::Plugin {
  public:
    flutter::PluginRegistrarWindows* registrar;
    std::unique_ptr<WebViewEnvironmentManager> webViewEnvironmentManager;
    std::unique_ptr<InAppWebViewManager> inAppWebViewManager;
    std::unique_ptr<InAppBrowserManager> inAppBrowserManager;
    std::unique_ptr<HeadlessInAppWebViewManager> headlessInAppWebViewManager;
    std::unique_ptr<CookieManager> cookieManager;
    std::unique_ptr<PlatformUtil> platformUtil;

    static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar,
      FlutterDesktopMessengerRef messenger);

    FlutterInappwebviewWindowsPlugin(flutter::PluginRegistrarWindows* registrar,
      FlutterDesktopMessengerRef messenger);

    virtual ~FlutterInappwebviewWindowsPlugin();

    // Whether the messenger still reaches a running engine. False from the
    // moment the engine's destructor starts: it clears the messenger's engine
    // pointer BEFORE destroying the plugins, and FlutterDesktopMessengerSetCallback
    // dereferences that pointer with no null check in Release. Every
    // unregister that can run from a destructor checks this first.
    bool isMessengerAvailable() const;

    // Disallow copy and assign.
    FlutterInappwebviewWindowsPlugin(const FlutterInappwebviewWindowsPlugin&) = delete;
    FlutterInappwebviewWindowsPlugin& operator=(const FlutterInappwebviewWindowsPlugin&) = delete;
  private:
    // The engine-owned messenger, not ref-counted here: the engine holds its
    // own reference until after Stop() has destroyed this plugin, so the ref
    // outlives every use of it in this class.
    FlutterDesktopMessengerRef messenger_ref_ = nullptr;
    // The ID of the WindowProc delegate registration.
    int window_proc_id = -1;
    std::optional<LRESULT> FlutterInappwebviewWindowsPlugin::HandleWindowProc(
      HWND hWnd,
      UINT message,
      WPARAM wParam,
      LPARAM lParam);
  };
}
#endif  // FLUTTER_PLUGIN_FLUTTER_INAPPWEBVIEW_PLUGIN_PLUGIN_H_
