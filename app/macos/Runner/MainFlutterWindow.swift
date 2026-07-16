import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  // The AppBar height Flutter is actually rendering, pushed across the
  // `ham2k/window_chrome` channel (see WindowChromeService). The traffic
  // lights center vertically in THIS, so they track font-scale changes and
  // any future header redesign without the native side re-deriving the
  // height from settings. The initial value only matters for the brief
  // moment before Flutter's first report lands; it's Flutter's default
  // AppBar height.
  private var titleBarHeight: CGFloat = 48.0

  // The close button's left edge sits this far from the window's left edge —
  // a fixed margin, so the buttons never drift (the old code nudged X by a
  // relative offset on every re-center, which accumulated).
  private let trafficLightLeftMargin: CGFloat = 20.0

  private var windowChromeChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // No separate gray title bar: the traffic lights float over Flutter's
    // own content instead, so the app's AppBar color reaches the very top
    // of the window. Flutter reserves left clearance for the buttons (see
    // platform_chrome.dart in halo_widgets) rather than us trying to draw
    // around them here.
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Flutter tells us the real AppBar height; we recenter whenever it does.
    let channel = FlutterMethodChannel(
      name: "ham2k/window_chrome",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      if call.method == "setTitleBarHeight",
        let args = call.arguments as? [String: Any],
        let height = args["height"] as? Double
      {
        self.titleBarHeight = CGFloat(height)
        self.positionTrafficLights()
        result(nil)
      } else if call.method == "setMinimumSize",
        let args = call.arguments as? [String: Any],
        let width = args["width"] as? Double,
        let height = args["height"] as? Double
      {
        // The resize floor (layouts.md's minWindowSize), already multiplied
        // by the UI scale on the Flutter side — don't re-derive it here.
        self.contentMinSize = NSSize(width: width, height: height)
        // contentMinSize only constrains FUTURE user resizes; a floor that
        // grew (font-scale increase) must also lift the current window, or
        // it stays below minimum until the user happens to drag an edge.
        let current = self.contentRect(forFrameRect: self.frame).size
        if current.width < width || current.height < height {
          self.setContentSize(
            NSSize(width: max(current.width, width), height: max(current.height, height)))
        }
        result(nil)
      } else if call.method == "performHeaderDoubleClickAction" {
        // Flutter reports double-clicks on the header's empty background
        // (platform_chrome.dart's macOSHeaderDoubleClickArea) — the
        // chromeless window has no real title bar, so we apply the same
        // System Settings choice ("Double-click a window's title bar to…")
        // a native title bar would honor. Default when unset is zoom.
        //
        // Not in native full screen, though: the header stays visible there
        // (fullSizeContentView), but a real title bar's double-click surface
        // doesn't exist in full screen — miniaturize would just beep and
        // zoom can disturb the frame restored on exit.
        if self.styleMask.contains(.fullScreen) {
          result(nil)
          return
        }
        let action = UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") ?? "Maximize"
        switch action {
        case "Minimize":
          self.performMiniaturize(nil)
        case "None":
          break
        default:
          self.zoom(nil)
        }
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    self.windowChromeChannel = channel

    super.awakeFromNib()

    positionTrafficLights()
    DispatchQueue.main.async { [weak self] in self?.positionTrafficLights() }

    for name: Notification.Name in [
      NSWindow.didUpdateNotification,
      NSWindow.didResizeNotification,
    ] {
      NotificationCenter.default.addObserver(
        self, selector: #selector(positionTrafficLights), name: name, object: self)
    }

    // Header layout depends on full-screen state on both sides: Flutter
    // drops the traffic-light clearance (the buttons leave the header for
    // the system's auto-hiding titlebar overlay), and positionTrafficLights
    // must stand down (see its guard). The will- notifications fire as the
    // transition animation starts, so the header realigns while the buttons
    // are already gone (entering) or not yet back (exiting).
    for name: Notification.Name in [
      NSWindow.willEnterFullScreenNotification,
      NSWindow.willExitFullScreenNotification,
    ] {
      NotificationCenter.default.addObserver(
        self, selector: #selector(fullScreenChanged(_:)), name: name, object: self)
    }
  }

  @objc private func fullScreenChanged(_ notification: Notification) {
    let entering = notification.name == NSWindow.willEnterFullScreenNotification
    windowChromeChannel?.invokeMethod("fullScreenChanged", arguments: entering)
  }

  // AppKit keeps re-laying the traffic-light buttons out to their own default
  // position (near the top of the standard, much shorter title bar) on every
  // resize/fullscreen transition, so this re-applies on each one rather than
  // running once.
  //
  // Both axes are set to ABSOLUTE targets, which makes this idempotent — the
  // old code added a fixed offset to whatever X the buttons currently had, so
  // every re-center (e.g. after a font-scale change) pushed them further
  // right. Here the close button's left edge is pinned to a fixed margin and
  // the group is shifted by the resulting delta, preserving AppKit's own
  // inter-button spacing; running it twice changes nothing the second time.
  @objc private func positionTrafficLights() {
    // In native full screen the buttons live in the system's auto-hiding
    // titlebar overlay, not our header. Placing them with main-window
    // coordinates (frame.height is the whole screen there) throws them far
    // outside the ~28pt overlay — they'd flash into view and vanish on the
    // next didUpdate. AppKit owns their layout until full screen exits.
    if styleMask.contains(.fullScreen) { return }

    guard let close = standardWindowButton(.closeButton),
      let miniaturize = standardWindowButton(.miniaturizeButton),
      let zoom = standardWindowButton(.zoomButton),
      let superview = close.superview
    else { return }

    let windowHeight = self.frame.height
    let centerYFromTop = titleBarHeight / 2

    // Target origin for the close button, in its superview's coordinates.
    // Y is derived in window space (top-down, independent of whichever native
    // container the buttons live in) then converted into the superview.
    let closeOriginYInWindow = windowHeight - centerYFromTop - close.frame.height / 2
    let targetCloseY = superview.convert(NSPoint(x: 0, y: closeOriginYInWindow), from: nil).y
    let targetCloseX = trafficLightLeftMargin

    // Already placed: skip, so the didUpdate stream doesn't churn layout.
    if abs(close.frame.origin.x - targetCloseX) < 0.5,
      abs(close.frame.origin.y - targetCloseY) < 0.5
    {
      return
    }

    // One horizontal delta for the whole group preserves their spacing.
    let dx = targetCloseX - close.frame.origin.x

    for button in [close, miniaturize, zoom] {
      guard let buttonSuperview = button.superview else { continue }
      let buttonOriginYInWindow = windowHeight - centerYFromTop - button.frame.height / 2
      let buttonY = buttonSuperview.convert(NSPoint(x: 0, y: buttonOriginYInWindow), from: nil).y
      var frame = button.frame
      frame.origin.x += dx
      frame.origin.y = buttonY
      button.frame = frame
    }
  }
}
