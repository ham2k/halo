import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  // Matches Flutter's default AppBar height (kToolbarHeight) so the traffic
  // lights center vertically in the merged title bar/AppBar rather than
  // sitting at the standard native title bar's default position (near the
  // very top of our much taller custom bar).
  private let appBarHeight: CGFloat = 56

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // No separate gray title bar: the traffic lights float over Flutter's
    // own content instead, so the app's AppBar color reaches the very top
    // of the window. Flutter reserves left clearance for the buttons (see
    // isMacOSChromelessWindow in polo_widgets) rather than us trying to
    // draw around them here.
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    centerTrafficLights()
    // AppKit performs its own layout pass on the titlebar view (resetting
    // the buttons back to their default position) after awakeFromNib
    // returns but before the window is actually displayed, so the very
    // first frame the user sees is uncorrected unless we reapply once more
    // on the next run-loop tick, after that layout pass has happened.
    DispatchQueue.main.async { [weak self] in self?.centerTrafficLights() }

    for name: Notification.Name in [
      NSWindow.didResizeNotification,
      NSWindow.didBecomeKeyNotification,
      NSWindow.didBecomeMainNotification,
    ] {
      NotificationCenter.default.addObserver(
        self, selector: #selector(centerTrafficLights), name: name, object: self)
    }
  }

  // AppKit keeps re-laying the traffic-light buttons out to their own
  // default position (near the top of the standard, much shorter title
  // bar) on every resize/fullscreen transition, so this re-applies on each
  // one rather than running once. Coordinates are computed in the window's
  // own space (top-down, independent of whatever native container view the
  // buttons happen to live in) and converted into each button's actual
  // superview space, rather than assuming that superview's own height
  // equals our AppBar height — it doesn't; only the window's frame does.
  @objc private func centerTrafficLights() {
    guard let close = standardWindowButton(.closeButton),
      let miniaturize = standardWindowButton(.miniaturizeButton),
      let zoom = standardWindowButton(.zoomButton)
    else { return }

    let windowHeight = self.frame.height
    for button in [close, miniaturize, zoom] {
      guard let superview = button.superview else { continue }
      let desiredCenterYFromTop = appBarHeight / 2
      let desiredOriginYInWindow = windowHeight - desiredCenterYFromTop - button.frame.height / 2
      let pointInSuperview = superview.convert(NSPoint(x: 0, y: desiredOriginYInWindow), from: nil)
      var frame = button.frame
      frame.origin.y = pointInSuperview.y
      button.frame = frame
    }
  }
}
