import Flutter
import GameController
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // iOS never delivers ⌘-letter chords to Flutter's HardwareKeyboard stream:
  // UIKit's key-command discovery (which walks the responder chain up to the
  // app delegate, since FlutterAppDelegate is itself a UIResponder) intercepts
  // them before the embedder does, unless the app registers UIKeyCommands
  // itself. The list below mirrors the default shortcuts in halo_app.dart's
  // `_handleKeyEvent`, which covers every other platform; with Keyboard
  // Shortcuts on, KeyBindingsService sends the operator's list in its place.
  private var keyCommandChannel: FlutterMethodChannel?

  // The operator's ⌘ chords, from KeyBindingsService's `setKeyCommands`;
  // nil keeps the built-in list.
  private var boundKeyCommands: [UIKeyCommand]?

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

  // An image on the clipboard (image_clipboard_io.dart), which Flutter's own
  // Clipboard cannot do.
  private var imageClipboardChannel: FlutterMethodChannel?

  // Equipment discovery by service record (mdns_io.dart). Dart cannot send
  // multicast on iOS without a restricted entitlement; NetServiceBrowser
  // can, for any type Info.plist lists under NSBonjourServices.
  private var bonjourChannel: FlutterMethodChannel?
  private var bonjourBrowser: BonjourBrowser?

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
    keyCommandChannel?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setKeyCommands" else {
        result(FlutterMethodNotImplemented)
        return
      }
      // nil puts the built-in list back; anything else must read whole, or
      // the Dart side hears why rather than believing its list is in force.
      if call.arguments == nil || call.arguments is NSNull {
        self?.boundKeyCommands = nil
        result(nil)
        return
      }
      guard let entries = call.arguments as? [[String: Any]] else {
        result(FlutterError(code: "bad-key-commands", message: "setKeyCommands takes a list of maps", details: nil))
        return
      }
      let commands = entries.compactMap(AppDelegate.boundKeyCommand)
      guard commands.count == entries.count else {
        result(FlutterError(code: "bad-key-commands", message: "\(entries.count - commands.count) key command(s) could not be read", details: nil))
        return
      }
      self?.boundKeyCommands = commands
      result(nil)
    }
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
    imageClipboardChannel = FlutterMethodChannel(
      name: "ham2k/image_clipboard",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    imageClipboardChannel?.setMethodCallHandler { call, result in
      guard call.method == "copyImage",
        let args = call.arguments as? [String: Any],
        let png = args["png"] as? FlutterStandardTypedData
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      // The PNG as it is, under its own type, rather than through
      // `UIPasteboard.image`, which re-encodes it.
      UIPasteboard.general.setData(png.data, forPasteboardType: "public.png")
      result(nil)
    }
    bonjourChannel = FlutterMethodChannel(
      name: "ham2k/bonjour",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    bonjourChannel?.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(nil) }
      switch call.method {
      case "start":
        guard let type = (call.arguments as? [String: Any])?["type"] as? String else {
          result(FlutterError(code: "bad-args", message: "start needs a type", details: nil))
          return
        }
        self.bonjourBrowser?.stop()
        self.bonjourBrowser = BonjourBrowser(type: type) { [weak self] found in
          self?.bonjourChannel?.invokeMethod("found", arguments: found)
        }
        result(nil)
      case "stop":
        self.bonjourBrowser?.stop()
        self.bonjourBrowser = nil
        result(nil)
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
    if let bound = boundKeyCommands { return bound }
    return [
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

  // One entry of `setKeyCommands`: {id, input, modifiers: [cmd|ctrl|alt|shift]}.
  // The id rides as the command's property list, so one action serves them all.
  private static func boundKeyCommand(_ entry: [String: Any]) -> UIKeyCommand? {
    guard let id = entry["id"] as? String, let input = entry["input"] as? String else { return nil }
    var flags: UIKeyModifierFlags = []
    for modifier in entry["modifiers"] as? [String] ?? [] {
      switch modifier {
      case "cmd": flags.insert(.command)
      case "ctrl": flags.insert(.control)
      case "alt": flags.insert(.alternate)
      case "shift": flags.insert(.shift)
      default: return nil
      }
    }
    return UIKeyCommand(title: "", action: #selector(runBoundKeyCommand(_:)), input: input, modifierFlags: flags, propertyList: id)
  }

  @objc private func runBoundKeyCommand(_ sender: UIKeyCommand) {
    if let id = sender.propertyList as? String { sendKeyCommand(id) }
  }
}

/// Browses one service type and resolves each instance it finds, reporting
/// name, host, port and TXT. Instances are held until [stop]: a NetService
/// nothing retains is released mid-resolve and never calls back.
private final class BonjourBrowser: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
  private let browser = NetServiceBrowser()
  private var services: [NetService] = []
  private var resolveAttempts: [ObjectIdentifier: Int] = [:]
  private let onFound: ([String: Any]) -> Void

  init(type: String, onFound: @escaping ([String: Any]) -> Void) {
    self.onFound = onFound
    super.init()
    browser.delegate = self
    browser.searchForServices(ofType: type, inDomain: "local.")
  }

  // Delegates are unowned: cleared before stopping, so a didStop delivered
  // after this browser is released cannot reach it.
  func stop() {
    browser.delegate = nil
    browser.stop()
    services.forEach {
      $0.delegate = nil
      $0.stop()
    }
    services.removeAll()
    resolveAttempts.removeAll()
  }

  // Refused — Local Network access declined in Settings, or the type
  // missing from NSBonjourServices. The dialog shows nothing found, the
  // same as every other platform without a network.
  func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
    NSLog("[bonjour] browse refused: \(errorDict)")
  }

  // didFind does not fire again for an instance already found, so a resolve
  // that timed out — a sleepy ESP32 radio missing the query — is retried
  // here or never. A few times, not forever: a unit switched off after it
  // was found would otherwise keep a resolve running for the whole visit.
  func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
    let key = ObjectIdentifier(sender)
    let attempts = (resolveAttempts[key] ?? 1) + 1
    guard attempts <= 3 else {
      NSLog("[bonjour] resolve of \(sender.name) failed: \(errorDict); giving up")
      return
    }
    NSLog("[bonjour] resolve of \(sender.name) failed: \(errorDict); retrying")
    resolveAttempts[key] = attempts
    sender.resolve(withTimeout: 5)
  }

  func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
    guard let index = services.firstIndex(where: { $0 == service }) else { return }
    let gone = services.remove(at: index)
    gone.delegate = nil
    gone.stop()
    resolveAttempts[ObjectIdentifier(gone)] = nil
  }

  func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
    services.append(service)
    service.delegate = self
    service.resolve(withTimeout: 5)
  }

  func netServiceDidResolveAddress(_ sender: NetService) {
    guard let host = sender.hostName, sender.port > 0 else {
      NSLog("[bonjour] \(sender.name) resolved without a host or port")
      return
    }
    var txt: [String: String] = [:]
    if let data = sender.txtRecordData() {
      for (key, value) in NetService.dictionary(fromTXTRecord: data) {
        txt[key] = String(data: value, encoding: .utf8) ?? ""
      }
    }
    onFound(["name": sender.name, "host": host, "port": sender.port, "txt": txt])
  }
}
