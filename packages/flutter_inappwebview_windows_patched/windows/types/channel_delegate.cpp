#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include "../flutter_inappwebview_windows_plugin.h"
#include "../utils/util.h"
#include "channel_delegate.h"

namespace flutter_inappwebview_plugin
{
  ChannelDelegate::ChannelDelegate(flutter::BinaryMessenger* messenger, const std::string& name) : messenger(messenger)
  {
    channel = std::make_shared<flutter::MethodChannel<flutter::EncodableValue>>(
      this->messenger, name,
      &flutter::StandardMethodCodec::GetInstance()
    );
    channel->SetMethodCallHandler(
      [this](const auto& call, auto result)
      {
        this->HandleMethodCall(call, std::move(result));
      });
  }

  void ChannelDelegate::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {}

  void ChannelDelegate::UnregisterMethodCallHandler() const
  {
    // InAppWebView's destructor disposes its find-interaction, print-job,
    // web-message and notification delegates through here, and every webview
    // still alive at quit is destroyed inside engine teardown, after the
    // messenger has lost its engine. Unregistering then reads through that
    // null engine; skipping it is safe, as the callback map dies
    // with the engine. See PATCH.md.
    if (channel && FlutterInappwebviewWindowsPlugin::isMessengerAvailable()) {
      channel->SetMethodCallHandler(nullptr);
    }
  }

  ChannelDelegate::~ChannelDelegate()
  {
    messenger = nullptr;
    channel.reset();
  }
}