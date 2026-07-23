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

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Only one instance of the app runs at a time: if another instance (by
    // bundle identifier) is already up, bring it to the front and quit this
    // newly launched one instead of leaving two windows open side by side.
    if let bundleId = Bundle.main.bundleIdentifier {
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
