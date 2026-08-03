import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // iOS never delivers ⌘-letter chords to Flutter's HardwareKeyboard stream:
  // UIKit's key-command discovery (which walks the responder chain up to the
  // app delegate, since FlutterAppDelegate is itself a UIResponder) intercepts
  // them before the embedder does, unless the app registers UIKeyCommands
  // itself. These mirror the modifier shortcuts in app/lib/main.dart's
  // `_handleKeyEvent`, which covers every other platform.
  private var keyCommandChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    keyCommandChannel = FlutterMethodChannel(
      name: "ham2k/key_commands",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
  }

  // UIKit matches a UIKeyCommand only on an EXACT modifierFlags match, so ⌘K
  // and ⌘⇧K are naturally distinct commands — no shift bookkeeping needed here.
  override var keyCommands: [UIKeyCommand]? {
    [
      // Plain ⌘K is reserved by iOS itself (show/hide the software keyboard)
      // and never reaches this handler on a hardware keyboard — registered
      // anyway in case a future iOS version frees it up. ⌘⇧K is the one that
      // actually works today; app/lib/main.dart's `_handleKeyEvent` accepts
      // it as an alternate on every other platform too.
      UIKeyCommand(input: "k", modifierFlags: .command, action: #selector(runCommandDialog)),
      UIKeyCommand(input: "k", modifierFlags: [.command, .shift], action: #selector(runCommandDialog)),
      UIKeyCommand(input: "d", modifierFlags: [.command, .shift], action: #selector(runThemeToggle)),
      UIKeyCommand(input: "l", modifierFlags: [.command, .shift], action: #selector(runLocaleToggle)),
      // ⌘⇧=/⌘⇧- mirror the common browser-style zoom chords — main.dart's
      // `_handleKeyEvent` accepts them too (LogicalKeyboardKey.equal/minus
      // fire regardless of shift there).
      UIKeyCommand(input: "=", modifierFlags: .command, action: #selector(runZoomIn)),
      UIKeyCommand(input: "=", modifierFlags: [.command, .shift], action: #selector(runZoomIn)),
      UIKeyCommand(input: "-", modifierFlags: .command, action: #selector(runZoomOut)),
      UIKeyCommand(input: "-", modifierFlags: [.command, .shift], action: #selector(runZoomOut)),
      UIKeyCommand(input: "0", modifierFlags: .command, action: #selector(runZoomReset)),
    ]
  }

  @objc private func runCommandDialog() { sendKeyCommand("commandDialog") }
  @objc private func runThemeToggle() { sendKeyCommand("themeToggle") }
  @objc private func runLocaleToggle() { sendKeyCommand("localeToggle") }
  @objc private func runZoomIn() { sendKeyCommand("zoomIn") }
  @objc private func runZoomOut() { sendKeyCommand("zoomOut") }
  @objc private func runZoomReset() { sendKeyCommand("zoomReset") }

  private func sendKeyCommand(_ action: String) {
    keyCommandChannel?.invokeMethod("run", arguments: action)
  }
}
