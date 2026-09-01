import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // Set by MainFlutterWindow once the Flutter engine's `ham2k/window_chrome`
  // channel exists. The app-menu items (About, Preferences…) target the First
  // Responder; unhandled, they reach the app delegate at the end of the
  // responder chain, and we forward them to Flutter over the channel.
  var windowChromeChannel: FlutterMethodChannel?

  @objc func menuAbout(_ sender: Any?) {
    windowChromeChannel?.invokeMethod("menuAbout", arguments: nil)
  }

  @objc func menuPreferences(_ sender: Any?) {
    windowChromeChannel?.invokeMethod("menuPreferences", arguments: nil)
  }

  @objc func menuCheckForUpdates(_ sender: Any?) {
    windowChromeChannel?.invokeMethod("menuCheckForUpdates", arguments: nil)
  }

  /// Set by MainFlutterWindow once the engine's `ham2k/open_file` channel
  /// exists, same arrangement as windowChromeChannel above.
  var openFileChannel: FlutterMethodChannel? {
    didSet { flushPendingOpenFiles() }
  }

  /// Files the OS handed us before Flutter was ready to hear about them.
  ///
  /// A double-clicked document on a COLD launch arrives here well before the
  /// engine exists — dropping it then is invisible to whoever double-clicked,
  /// since the app opens and simply does nothing.
  private var pendingOpenFiles: [String] = []

  /// Documents opened through Finder, `open(1)`, or a drop on the Dock icon.
  ///
  /// `app_links` does NOT deliver these: on macOS it listens for `kAEGetURL`
  /// only, which is custom URL schemes. Opening a document is a different
  /// Apple Event entirely, so registering the type in Info.plist without this
  /// gets an app that Finder offers and that then ignores the file.
  override func application(_ application: NSApplication, open urls: [URL]) {
    let paths = urls.filter { $0.isFileURL }.map { $0.path }
    guard !paths.isEmpty else { return }
    pendingOpenFiles.append(contentsOf: paths)
    flushPendingOpenFiles()
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

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Only one instance of the app runs at a time: if another instance (by
    // bundle identifier) is already up, bring it to the front and quit this
    // newly launched one instead of leaving two windows open side by side.
    //
    // Unless this launch carries a dev data sandbox, which is a build running
    // against its own database, cache and preferences: a second one is then
    // not a second window onto the same log, and several checkouts' builds
    // are meant to run side by side. An ENVIRONMENT variable because a
    // dart-define is invisible here, and Dart reads the same name.
    //
    // Debug builds only, matching the Dart side (debugEnvFlag answers '' in
    // release) — a shipped app must not be talked out of its guard by a
    // variable anything could export.
    var dataSandbox = false
    #if DEBUG
      dataSandbox = !(ProcessInfo.processInfo.environment["HALO_DEV_DATA"] ?? "").isEmpty
    #endif
    if !dataSandbox, let bundleId = Bundle.main.bundleIdentifier {
      let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
      if let existing = others.first {
        existing.activate(options: [.activateAllWindows])
        NSApp.terminate(nil)
        return
      }
    }
    // Deliberately DON'T call super.applicationDidFinishLaunching(_:):
    // `applicationDidFinishLaunching(_:)` is an OPTIONAL NSApplicationDelegate
    // method that FlutterAppDelegate (and NSObject) don't implement, so calling
    // super raises -[AppDelegate applicationDidFinishLaunching:] "unrecognized
    // selector". macOS silently swallows that NSException during notification
    // dispatch by default (so it went unnoticed), but once Sentry installs its
    // exception handler the same throw becomes a FATAL crash at launch — a
    // black, unresponsive window. Flutter's own macOS AppDelegate template
    // doesn't override this method at all; the engine is set up in
    // MainFlutterWindow, so there is nothing in super to call.
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
