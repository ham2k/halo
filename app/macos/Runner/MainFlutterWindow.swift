import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  // Matches Flutter's default AppBar height (kToolbarHeight) so the traffic
  // lights center vertically in the merged title bar/AppBar rather than
  // sitting at the standard native title bar's default position (near the
  // very top of our much taller custom bar).
  private let appBarHeight: CGFloat = 48

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // No separate gray title bar: the traffic lights float over Flutter's
    // own content instead, so the app's AppBar color reaches the very top
    // of the window. Flutter reserves left clearance for the buttons (see
    // isMacOSChromelessWindow in halo_widgets) rather than us trying to
    // draw around them here.
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    centerTrafficLights()
    DispatchQueue.main.async { [weak self] in self?.centerTrafficLights() }

    for name: Notification.Name in [
      NSWindow.didUpdateNotification,
      NSWindow.didResizeNotification,
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
    let leftOffset: CGFloat = 6
    
    let desiredCenterYFromTop = appBarHeight / 2
    let desiredOriginYInWindow = windowHeight - desiredCenterYFromTop - close.frame.height / 2
    guard let superview = close.superview else { return }
    let pointInSuperview = superview.convert(NSPoint(x: 0, y: desiredOriginYInWindow), from: nil)
    
    // If the close button is already centered, skip to prevent redundant updates or layout loops
    if abs(close.frame.origin.y - pointInSuperview.y) < 0.1 {
      return
    }

    for button in [close, miniaturize, zoom] {
      guard let buttonSuperview = button.superview else { continue }
      let buttonOriginY = windowHeight - desiredCenterYFromTop - button.frame.height / 2
      let buttonPoint = buttonSuperview.convert(NSPoint(x: 0, y: buttonOriginY), from: nil)
      var frame = button.frame
      frame.origin.x = frame.origin.x + leftOffset
      frame.origin.y = buttonPoint.y
      button.frame = frame
    }
  }
}
