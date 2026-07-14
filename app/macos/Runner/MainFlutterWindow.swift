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
