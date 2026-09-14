import Flutter
import GameController
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

  // Physical-keyboard presence for the logging fields' focus rules
  // (docs/design/logging-fields.md): Flutter has no keyboard-presence API, so
  // the Dart side (HardwareKeyboardService) asks here. GCKeyboard is the only
  // public signal (iOS 14+, within the deployment floor).
  private var hardwareKeyboardChannel: FlutterMethodChannel?

  // The other Ham2K loggers on this device, for the link-across offer
  // (the Dart side is SiblingAppsService). iOS can only ask
  // `canOpenURL` about a SCHEME, and only about the ones the plist's
  // LSApplicationQueriesSchemes lists — anything else answers false whether
  // installed or not. Which schemes are meaningful probes is decided in Dart
  // (the `halo` alias family, never `logger`; see deep_link_service.dart).
  private var siblingAppsChannel: FlutterMethodChannel?

  // Documents opened from Files, a share sheet, or a browser download
  // (HALO-422). `app_links` handles custom URL schemes; an opened document
  // arrives through this delegate method instead, so a registered type
  // without it is an app the OS offers and that then ignores the file.
  private var openFileChannel: FlutterMethodChannel? {
    didSet { flushPendingOpenFiles() }
  }

  // Files handed over before the engine existed — every cold launch by
  // opening a document.
  private var pendingOpenFiles: [String] = []

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    guard url.isFileURL else {
      // Not ours to claim — a custom-scheme link belongs to app_links, and
      // swallowing it here would break every deep link the app has.
      return super.application(app, open: url, options: options)
    }
    // A document from another app's container is security-scoped: readable
    // only between these two calls, and the copy has to happen inside them.
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    // Copied into our own tmp because the original may be gone — or
    // unreadable — by the time Dart asks for it.
    // Previous copies first: one bundle per open, kept forever, is a tmp
    // directory that only grows.
    sweepOpenedCopies()
    let destination = FileManager.default.temporaryDirectory
      .appendingPathComponent("opened-" + UUID().uuidString + "-" + url.lastPathComponent)
    do {
      try? FileManager.default.removeItem(at: destination)
      try FileManager.default.copyItem(at: url, to: destination)
    } catch {
      NSLog("[open-file] could not copy \(url.lastPathComponent): \(error)")
      return false
    }
    pendingOpenFiles.append(destination.path)
    flushPendingOpenFiles()
    return true
  }

  private func sweepOpenedCopies() {
    let tmp = FileManager.default.temporaryDirectory
    guard let entries = try? FileManager.default.contentsOfDirectory(
      at: tmp, includingPropertiesForKeys: nil) else { return }
    for entry in entries where entry.lastPathComponent.hasPrefix("opened-") {
      try? FileManager.default.removeItem(at: entry)
    }
  }

  private func flushPendingOpenFiles() {
    guard let channel = openFileChannel, !pendingOpenFiles.isEmpty else { return }
    let paths = pendingOpenFiles
    pendingOpenFiles = []
    // ONE message carrying every path, not one per file. Flutter's default
    // channel buffer holds a single message until Dart installs a handler, so
    // a cold launch opening several documents would keep the last and discard
    // the rest with only a console warning.
    channel.invokeMethod("openFiles", arguments: ["paths": paths])
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    openFileChannel = FlutterMethodChannel(
      name: "ham2k/open_file",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    keyCommandChannel = FlutterMethodChannel(
      name: "ham2k/key_commands",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    hardwareKeyboardChannel = FlutterMethodChannel(
      name: "ham2k/hardware_keyboard",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    hardwareKeyboardChannel?.setMethodCallHandler { call, result in
      guard call.method == "isAttached" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(GCKeyboard.coalesced != nil)
    }
    siblingAppsChannel = FlutterMethodChannel(
      name: "ham2k/sibling_apps",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    siblingAppsChannel?.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "list":
        let ids = args?["ids"] as? [String] ?? []
        result(ids.filter { id in
          guard let url = URL(string: "\(id)://") else { return false }
          return UIApplication.shared.canOpenURL(url)
        })
      case "open":
        // Dart has already put the target's scheme on the URL: on iOS that
        // IS the targeting, so the `id` Android needs goes unread here.
        guard let raw = args?["url"] as? String, let url = URL(string: raw) else {
          result(FlutterError(code: "bad-args", message: "open needs a url", details: nil))
          return
        }
        UIApplication.shared.open(url, options: [:]) { ok in result(ok) }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    // Re-query on disconnect rather than pushing `false`: `coalesced`
    // merges every attached keyboard, so one leaving doesn't mean none
    // remain.
    NotificationCenter.default.addObserver(
      forName: .GCKeyboardDidConnect, object: nil, queue: .main
    ) { [weak self] _ in
      self?.hardwareKeyboardChannel?.invokeMethod("changed", arguments: true)
    }
    NotificationCenter.default.addObserver(
      forName: .GCKeyboardDidDisconnect, object: nil, queue: .main
    ) { [weak self] _ in
      self?.hardwareKeyboardChannel?.invokeMethod("changed", arguments: GCKeyboard.coalesced != nil)
    }
  }

  // UIKit matches a UIKeyCommand only on an EXACT modifierFlags match, so ⌘K
  // and ⌘⇧K are naturally distinct commands — no shift bookkeeping needed here.
  override var keyCommands: [UIKeyCommand]? {
    [
      // Plain ⌘K is reserved by iOS itself (show/hide the software keyboard)
      // and never reaches this handler on a hardware keyboard — registered
      // anyway in case a future iOS version frees it up. ⌘⇧K is reserved
      // too, at least on the Simulator — ⌘⌥K is the one that actually works;
      // app/lib/main.dart's `_handleKeyEvent` accepts either as an alternate
      // on every other platform too.
      UIKeyCommand(input: "k", modifierFlags: .command, action: #selector(runCommandDialog)),
      UIKeyCommand(input: "k", modifierFlags: [.command, .shift], action: #selector(runCommandDialog)),
      UIKeyCommand(input: "k", modifierFlags: [.command, .alternate], action: #selector(runCommandDialog)),
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
