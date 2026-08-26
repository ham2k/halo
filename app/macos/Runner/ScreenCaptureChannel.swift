import Cocoa
import CoreGraphics
import CoreImage
import CoreMedia
import FlutterMacOS
import ScreenCaptureKit

// Screen, application and window capture for the `remote` experiment
// (HALO-369): this device offers a set of named sources, and a peer's Remote
// Screen panel subscribes to one of them.
//
// ScreenCaptureKit is macOS 12.3 and the app's floor is 12.0, so every symbol
// from it is reached only under `#available(macOS 12.3, *)` and the framework
// is weak-linked (see Configs/AppInfo.xcconfig — the flag there is what keeps
// the app launchable on 12.0–12.2). Importing it at file scope is inert: a
// weak import resolves to NULL and is never touched until a guarded branch
// runs. SCK is also the ONLY road — CGWindowListCreateImage carries
// `obsoleted=15.0` and does not compile against the current SDK.
//
// Swift will not let an unavailable type appear in a stored property of an
// always-available class, which is why the streaming half lives in its own
// `@available` class and is held here as AnyObject.
final class ScreenCaptureChannel: NSObject {
  private static let methodChannelName = "ham2k/screen_capture"
  private static let frameChannelName = "ham2k/screen_capture/frames"

  /// Enumerating shareable content can hang forever rather than failing
  /// (FB12114396, FB15779754 — `replayd` wedges, sometimes at 100% CPU). A
  /// Dart `await` on this channel would then never complete and the settings
  /// panel would be stuck in Loading for the rest of the session, so every
  /// enumeration races this deadline and reports a timeout instead.
  private static let enumerationTimeout: DispatchTimeInterval = .seconds(5)

  private let methodChannel: FlutterMethodChannel
  private let frameChannel: FlutterBasicMessageChannel

  /// Values are `ScreenCaptureSession`, typed loosely because that class is
  /// only available at 12.3 and this one is not.
  private var sessions: [String: AnyObject] = [:]

  init(messenger: FlutterBinaryMessenger) {
    methodChannel = FlutterMethodChannel(name: Self.methodChannelName, binaryMessenger: messenger)
    // Binary codec, not the standard one: a frame is already a packed
    // header+JPEG buffer (see ScreenCaptureSession.wireFrame) and passes
    // straight through to the peer's media socket without being re-encoded
    // or copied into a Dart map on the way.
    frameChannel = FlutterBasicMessageChannel(
      name: Self.frameChannelName,
      binaryMessenger: messenger,
      codec: FlutterBinaryCodec.sharedInstance())
    super.init()
    methodChannel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result) ?? result(FlutterMethodNotImplemented)
    }
    // A shared application's pointer is only worth drawing while its
    // operator is actually in it: left on, a viewer watches a cursor drift
    // around a window nobody is touching, which reads as activity that is
    // not happening.
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(frontmostApplicationChanged),
      name: NSWorkspace.didActivateApplicationNotification,
      object: nil)
  }

  deinit {
    NSWorkspace.shared.notificationCenter.removeObserver(self)
  }

  @objc private func frontmostApplicationChanged(_ notification: Notification) {
    guard #available(macOS 12.3, *) else { return }
    for session in sessions.values {
      (session as? ScreenCaptureSession)?.refreshCursorVisibility()
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "available":
      if #available(macOS 12.3, *) { result(true) } else { result(false) }

    case "permission":
      result(Self.permissionState())

    case "requestPermission":
      // Returns the CURRENT answer immediately — the dialog is drawn by
      // another process and outlives this call — so the caller must not read
      // the return value as "the user just decided".
      result(CGRequestScreenCaptureAccess())

    case "listSources":
      guard #available(macOS 12.3, *) else {
        result(Self.unsupportedError())
        return
      }
      Self.listSources(result: result)

    case "start":
      guard #available(macOS 12.3, *) else {
        result(Self.unsupportedError())
        return
      }
      guard let args = call.arguments as? [String: Any],
        let sourceId = args["id"] as? String
      else {
        result(Self.argumentError("start needs an id"))
        return
      }
      start(
        sourceId: sourceId,
        maxWidth: args["maxWidth"] as? Int ?? 1280,
        fps: args["fps"] as? Int ?? 10,
        quality: args["quality"] as? Double ?? 0.6,
        result: result)

    case "stop":
      guard let args = call.arguments as? [String: Any],
        let sourceId = args["id"] as? String
      else {
        result(Self.argumentError("stop needs an id"))
        return
      }
      stop(sourceId: sourceId)
      result(nil)

    case "thumbnail":
      guard #available(macOS 12.3, *) else {
        result(Self.unsupportedError())
        return
      }
      guard let args = call.arguments as? [String: Any],
        let sourceId = args["id"] as? String
      else {
        result(Self.argumentError("thumbnail needs an id"))
        return
      }
      Self.thumbnail(
        sourceId: sourceId, maxWidth: args["maxWidth"] as? Int ?? 320, result: result)

    case "stopAll":
      stopAll()
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Permission

  /// `CGPreflightScreenCaptureAccess` caches its answer for the life of the
  /// process: once it has returned false it keeps returning false even after
  /// the operator grants the permission, so polling it never observes the
  /// change and a granted build still reports "denied" until it is relaunched.
  /// The Dart side says so rather than pretending a retry will help.
  private static func permissionState() -> String {
    return CGPreflightScreenCaptureAccess() ? "granted" : "denied"
  }

  // MARK: - Enumeration

  @available(macOS 12.3, *)
  private static func listSources(result: @escaping FlutterResult) {
    var settled = false
    let lock = NSLock()
    // One `settle` for both arms: whichever of the callback and the deadline
    // arrives first answers, and the other is dropped. Calling a FlutterResult
    // twice traps.
    let settle: (Any?) -> Void = { value in
      lock.lock()
      let first = !settled
      settled = true
      lock.unlock()
      guard first else { return }
      DispatchQueue.main.async { result(value) }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + enumerationTimeout) {
      settle(
        FlutterError(
          code: "timeout",
          message: "macOS did not answer with the list of shareable content",
          details: nil))
    }

    SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) {
      content, error in
      if let error = error {
        settle(
          FlutterError(
            code: "unavailable", message: error.localizedDescription, details: nil))
        return
      }
      guard let content = content else {
        settle([[String: Any]]())
        return
      }
      settle(describe(content))
    }
  }

  /// Sources as the operator picks them, ordered displays → applications →
  /// windows.
  ///
  /// Ids are what a peer's panel stores, so they are chosen for stability
  /// rather than convenience: a display keys on its `CGDirectDisplayID` and an
  /// application on its bundle id, both of which survive the producer
  /// restarting. A window's `CGWindowID` does NOT — it is reissued on every
  /// launch — so a window offers the least durable selection of the three and
  /// the panel treats an id that no longer resolves as "the source went away"
  /// rather than an error.
  @available(macOS 12.3, *)
  private static func describe(_ content: SCShareableContent) -> [[String: Any]] {
    var sources: [[String: Any]] = []

    for display in content.displays {
      sources.append([
        "id": "display:\(display.displayID)",
        "name": displayName(display),
        "kind": "display",
      ])
    }

    // An application is offered only when it actually has a window on screen:
    // every background agent and daemon is "running", and a list of two
    // hundred of them is not a picker.
    let windowsByApp = Dictionary(grouping: content.windows.filter { $0.owningApplication != nil }) {
      $0.owningApplication!.bundleIdentifier
    }
    // Sorted, because a Dictionary yields keys in hash order: the picker
    // would list applications unpredictably, and — worse — that order
    // reshuffles when the dictionary's capacity changes, which moves
    // `offeredSources` and fires a spurious offer broadcast to every peer
    // from ensureSourcesFresh's listEquals check.
    var apps: [[String: Any]] = []
    for (bundleId, windows) in windowsByApp {
      guard let app = windows.first?.owningApplication, !bundleId.isEmpty else { continue }
      apps.append([
        "id": "app:\(bundleId)",
        "name": app.applicationName.isEmpty ? bundleId : app.applicationName,
        "kind": "app",
      ])
    }
    apps.sort { ($0["name"] as? String ?? "") < ($1["name"] as? String ?? "") }
    sources.append(contentsOf: apps)

    for window in content.windows {
      let title = window.title ?? ""
      // A titleless window is a shadow, a menu or a helper panel; it has
      // nothing to show the operator in a list.
      guard !title.isEmpty, window.frame.width > 1, window.frame.height > 1 else { continue }
      let owner = window.owningApplication?.applicationName
      sources.append([
        "id": "window:\(window.windowID)",
        "name": owner.map { "\($0) — \(title)" } ?? title,
        "kind": "window",
      ])
    }

    return sources
  }

  /// The display holding most of [windows] — by overlapping area, so an
  /// application straddling two screens is captured on the one showing more
  /// of it. Null when nothing overlaps anything, which is an app with no
  /// on-screen windows at all.
  @available(macOS 12.3, *)
  fileprivate static func displayHosting(_ windows: [SCWindow], in content: SCShareableContent)
    -> SCDisplay?
  {
    var best: (display: SCDisplay, area: CGFloat)?
    for display in content.displays {
      var area: CGFloat = 0
      for window in windows {
        let overlap = window.frame.intersection(display.frame)
        if !overlap.isNull { area += overlap.width * overlap.height }
      }
      if area > 0, area > (best?.area ?? 0) { best = (display, area) }
    }
    return best?.display
  }

  @available(macOS 12.3, *)
  private static func displayName(_ display: SCDisplay) -> String {
    let screen = NSScreen.screens.first { screen in
      (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID)
        == display.displayID
    }
    return screen?.localizedName ?? "Display \(display.displayID)"
  }

  // MARK: - Capture

  @available(macOS 12.3, *)
  private func start(
    sourceId: String, maxWidth: Int, fps: Int, quality: Double, result: @escaping FlutterResult
  ) {
    // Restarting an already-running source is how the viewer changes rate or
    // size, so the old stream goes before the new one is built rather than
    // both holding the same window.
    stop(sourceId: sourceId)

    let session = ScreenCaptureSession(
      sourceId: sourceId,
      maxWidth: maxWidth,
      fps: fps,
      quality: quality,
      onFrame: { [weak self] frame in
        // Raw Data, because the channel's codec is FlutterBinaryCodec:
        // it encodes NSData and throws an NSException on anything else,
        // FlutterStandardTypedData included. That throw is not catchable
        // from Swift and takes the whole app down.
        self?.frameChannel.sendMessage(frame)
      })
    // Set after construction so it can hold the session itself, which is
    // what the identity check below needs. Changing a viewer's size or rate
    // stops the old stream and starts a new one under the SAME key, and a
    // stop error from the old one arriving afterwards would otherwise evict
    // the new, running session from the map — leaving a capture nothing can
    // reach to stop it.
    session.onStop = { [weak self, weak session] reason in
      guard let self = self, let session = session else { return }
      guard self.sessions[sourceId] === session else { return }
      self.sessions.removeValue(forKey: sourceId)
      self.methodChannel.invokeMethod(
        "captureStopped", arguments: ["id": sourceId, "reason": reason])
    }
    sessions[sourceId] = session
    session.start { [weak session] error in
      if let error = error {
        // Same identity check as onStop above, for the same reason: a
        // viewer changing size or rate calls start again under this key, and
        // an OLD attempt's failure landing afterwards would evict the new,
        // running session — leaving a capture that nothing can reach to stop
        // it, recording indicator and all.
        if let session = session, self.sessions[sourceId] === session {
          self.sessions.removeValue(forKey: sourceId)
        }
        result(FlutterError(code: "capture", message: error, details: nil))
      } else {
        result(nil)
      }
    }
  }

  private func stop(sourceId: String) {
    guard let session = sessions.removeValue(forKey: sourceId) else { return }
    if #available(macOS 12.3, *), let session = session as? ScreenCaptureSession {
      session.stop()
    }
  }

  private func stopAll() {
    for id in sessions.keys { stop(sourceId: id) }
  }

  // MARK: - Thumbnails

  /// One still of [sourceId], for the picker's tiles.
  ///
  /// A separate path from [start] rather than a stream taken briefly: the
  /// picker shows every screen, app and window at once, and a machine with
  /// eighty of them cannot afford eighty SCStreams to draw a grid.
  ///
  /// Answers null rather than an error for a source that has gone — a
  /// window closing while the picker is open is ordinary, and a tile that
  /// simply has no picture is a better answer than a dialog full of errors.
  @available(macOS 12.3, *)
  private static func thumbnail(sourceId: String, maxWidth: Int, result: @escaping FlutterResult) {
    var settled = false
    let lock = NSLock()
    let settle: (Any?) -> Void = { value in
      lock.lock()
      let first = !settled
      settled = true
      lock.unlock()
      guard first else { return }
      DispatchQueue.main.async { result(value) }
    }
    // Shorter than the enumeration's deadline: a grid asks for many of these
    // and a wedged one must not hold a tile blank for as long as a whole
    // listing may take.
    //
    // `oneShot` is captured so the deadline can TEAR IT DOWN, not merely
    // answer null. A stream that starts cleanly and then only ever delivers
    // idle frames reaches none of OneShotCapture's own exits, and the holder
    // retains itself — leaving an SCStream running, and the recording
    // indicator lit, for the rest of the process. One per tile that fails
    // this way, on a grid that asks for dozens.
    var oneShot: OneShotCapture?
    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
      if let pending = oneShot {
        pending.finish(nil)
      } else {
        settle(nil)
      }
    }

    SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) {
      content, error in
      if let error = error {
        // Null stays the ANSWER — a tile without a picture beats a dialog
        // full of errors — but "the window closed", "permission revoked" and
        // "replayd wedged" must not be one indistinguishable outcome with
        // nothing to read when every tile comes back blank.
        NSLog("[ham2k] thumbnail enumeration failed: %@", error.localizedDescription)
      }
      guard let content = content,
        let (filter, size, _) = ScreenCaptureSession.filter(for: sourceId, in: content)
      else {
        settle(nil)
        return
      }
      let config = SCStreamConfiguration()
      let scale = min(1.0, Double(maxWidth) / max(1.0, Double(size.width)))
      config.width = max(2, Int((Double(size.width) * scale).rounded()))
      config.height = max(2, Int((Double(size.height) * scale).rounded()))
      config.showsCursor = false
      config.pixelFormat = kCVPixelFormatType_32BGRA

      if #available(macOS 14.0, *) {
        // The one-shot API, where it exists — no stream, no delegate, no
        // teardown to get wrong.
        SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) {
          image, _ in
          guard let image = image else {
            settle(nil)
            return
          }
          settle(ScreenCaptureSession.jpeg(from: CIImage(cgImage: image), quality: 0.5))
        }
      } else {
        // 12.3–13.x have no one-shot: stand a stream up, keep the first
        // complete frame, tear it down. The holder keeps itself alive until
        // it has answered, since nothing else retains it.
        let capture = OneShotCapture(filter: filter, config: config, settle: settle)
        oneShot = capture
        capture.begin()
      }
    }
  }

  // MARK: - Errors

  private static func unsupportedError() -> FlutterError {
    return FlutterError(
      code: "unsupported",
      message: "Screen sharing needs macOS 12.3 or later",
      details: nil)
  }

  private static func argumentError(_ message: String) -> FlutterError {
    return FlutterError(code: "arguments", message: message, details: nil)
  }
}

/// A single frame from a stream, for macOS 12.3–13.x where
/// `SCScreenshotManager` does not exist.
///
/// Retains itself until it answers: it is created and dropped by the caller
/// in one expression, and an SCStream's output delegate is held weakly.
@available(macOS 12.3, *)
private final class OneShotCapture: NSObject, SCStreamOutput, SCStreamDelegate {
  private let filter: SCContentFilter
  private let config: SCStreamConfiguration
  private let settle: (Any?) -> Void
  private var stream: SCStream?
  private var alive: OneShotCapture?

  init(filter: SCContentFilter, config: SCStreamConfiguration, settle: @escaping (Any?) -> Void) {
    self.filter = filter
    self.config = config
    self.settle = settle
    super.init()
  }

  func begin() {
    alive = self
    let stream = SCStream(filter: filter, configuration: config, delegate: self)
    self.stream = stream
    do {
      try stream.addStreamOutput(
        self, type: .screen,
        sampleHandlerQueue: DispatchQueue(label: "com.ham2k.screencapture.thumb"))
    } catch {
      finish(nil)
      return
    }
    stream.startCapture { [weak self] error in
      if error != nil { self?.finish(nil) }
    }
  }

  fileprivate func finish(_ value: Any?) {
    guard alive != nil else { return }
    alive = nil
    stream?.stopCapture { _ in }
    stream = nil
    settle(value)
  }

  func stream(
    _ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
    of type: SCStreamOutputType
  ) {
    guard type == .screen, CMSampleBufferIsValid(sampleBuffer) else { return }
    // The first buffers are routinely `.idle` with stale pixels; taking one
    // would put a blank tile in the grid.
    guard let attachments = CMSampleBufferGetSampleAttachmentsArray(
      sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
      let statusValue = attachments.first?[.status] as? Int,
      SCFrameStatus(rawValue: statusValue) == .complete,
      let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
    else { return }
    finish(ScreenCaptureSession.jpeg(from: CIImage(cvPixelBuffer: pixelBuffer), quality: 0.5))
  }

  func stream(_ stream: SCStream, didStopWithError error: Error) { finish(nil) }
}

/// One running capture. Owns its `SCStream`, encodes each delivered frame to
/// JPEG and hands the finished wire frame back.
@available(macOS 12.3, *)
private final class ScreenCaptureSession: NSObject, SCStreamOutput, SCStreamDelegate {
  /// Frames encode and are handed off on this queue, never on the main one —
  /// JPEG encoding at ten frames a second would otherwise be ten stalls a
  /// second in the UI.
  private static let queue = DispatchQueue(label: "com.ham2k.screencapture", qos: .userInitiated)

  /// Creating a CIContext is expensive and it is safe to share, so one serves
  /// every session.
  fileprivate static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

  private let sourceId: String
  private let maxWidth: Int
  private let fps: Int
  private let quality: Double
  private let onFrame: (Data) -> Void

  /// Assigned by the owner after construction — see the identity check at
  /// its call site.
  var onStop: (String) -> Void = { _ in }

  private var stream: SCStream?
  private var sequence: Int = 0

  /// Whose frontmost-ness the cursor follows: the shared application's
  /// bundle id, or nil for a whole display, where the pointer is part of
  /// what is on that screen and is always drawn.
  ///
  /// A WINDOW follows its owning application rather than its own key state.
  /// `SCWindow.isActive` would be exact, but reading it means another
  /// `SCShareableContent` enumeration — the call that can wedge — on every
  /// app switch, to answer a question the owning app gets right whenever the
  /// shared window is the one its operator is using.
  fileprivate var cursorOwner: String?

  /// Held so the cursor can be turned on and off without rebuilding the
  /// stream — `SCStream.updateConfiguration` takes a whole configuration,
  /// not one property.
  private var config: SCStreamConfiguration?

  /// Frames already handed to Flutter and not yet sent. The platform channel
  /// is drained on the main thread while capture runs on its own queue, so a
  /// busy UI would otherwise grow an unbounded backlog of stale frames and
  /// the viewer would fall further behind the longer it watched. Dropping the
  /// newest frame is right for a live view: what arrives next is better than
  /// what was skipped.
  private var inFlight = 0
  private static let maxInFlight = 2

  init(
    sourceId: String, maxWidth: Int, fps: Int, quality: Double,
    onFrame: @escaping (Data) -> Void
  ) {
    self.sourceId = sourceId
    self.maxWidth = max(160, maxWidth)
    self.fps = min(30, max(1, fps))
    self.quality = min(1.0, max(0.1, quality))
    self.onFrame = onFrame
  }

  func start(completion: @escaping (String?) -> Void) {
    // Answered exactly once, from whichever arrives first — the enumeration,
    // the deadline, or this session being torn down mid-flight.
    //
    // Every one of those can otherwise leave the caller waiting forever, and
    // the Dart side awaits this before it can grant or refuse a viewer: a
    // start that never answers is a pane stuck on "Connecting…" for the life
    // of the session, with the watcher already registered so the operator is
    // told someone is watching a capture that never began.
    var settled = false
    let lock = NSLock()
    let settle: (String?) -> Void = { error in
      lock.lock()
      let first = !settled
      settled = true
      lock.unlock()
      guard first else { return }
      DispatchQueue.main.async { completion(error) }
    }
    // The same wedge listSources and thumbnail race — `replayd` hanging
    // rather than failing (FB12114396).
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.startTimeout) {
      settle("macOS did not answer with the list of shareable content")
    }

    SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) {
      [weak self] content, error in
      if let error = error {
        settle(error.localizedDescription)
        return
      }
      // Deallocated while enumerating — `stop` removed the only strong
      // reference, which a dock tab flick does routinely. The caller is
      // still owed an answer, and `settle` is held by this closure rather
      // than by `self` precisely so it can give one.
      guard let self = self else {
        settle("The capture was stopped before it started")
        return
      }
      guard let content = content,
        let (filter, size, cursorOwner) = Self.filter(for: self.sourceId, in: content)
      else {
        settle("That screen or window is no longer available")
        return
      }
      self.cursorOwner = cursorOwner
      self.begin(filter: filter, sourceSize: size, settle: settle)
    }
  }

  fileprivate static let startTimeout: DispatchTimeInterval = .seconds(5)

  private func begin(
    filter: SCContentFilter, sourceSize: CGSize, settle: @escaping (String?) -> Void
  ) {
    let config = SCStreamConfiguration()
    // The default is 1920×1080 whatever the source measures, so a stream that
    // never sets these sends a letterboxed 1080p frame for a small window.
    let scale = min(1.0, Double(maxWidth) / max(1.0, Double(sourceSize.width)))
    config.width = max(2, Int((Double(sourceSize.width) * scale).rounded()))
    config.height = max(2, Int((Double(sourceSize.height) * scale).rounded()))
    config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
    // The default depth of 8 buys smoothness at the cost of latency, which is
    // the wrong trade for a remote view of a radio's screen.
    config.queueDepth = 3
    config.pixelFormat = kCVPixelFormatType_32BGRA
    config.showsCursor = Self.cursorVisible(for: cursorOwner)
    self.config = config

    let stream = SCStream(filter: filter, configuration: config, delegate: self)
    do {
      try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: Self.queue)
    } catch {
      settle(error.localizedDescription)
      return
    }
    self.stream = stream
    stream.startCapture { error in settle(error?.localizedDescription) }
  }

  /// Whether the pointer belongs in this source's picture right now.
  fileprivate static func cursorVisible(for owner: String?) -> Bool {
    guard let owner = owner else { return true }
    return NSWorkspace.shared.frontmostApplication?.bundleIdentifier == owner
  }

  /// Re-applies the cursor rule after the frontmost application changed.
  ///
  /// A configuration update rather than a restart: rebuilding the stream on
  /// every app switch would drop frames and re-arm the whole capture for a
  /// single boolean. `updateConfiguration` carries no availability of its
  /// own, so it is there from 12.3 like the rest of SCStream.
  fileprivate func refreshCursorVisibility() {
    guard let stream = stream, let config = config else { return }
    let wanted = Self.cursorVisible(for: cursorOwner)
    guard config.showsCursor != wanted else { return }
    config.showsCursor = wanted
    stream.updateConfiguration(config) { _ in }
  }

  func stop() {
    guard let stream = stream else { return }
    self.stream = nil
    stream.stopCapture { error in
      // Logged rather than discarded: a stop that failed leaves a stream
      // this process can no longer reach, still capturing and still lighting
      // the recording indicator — the one state this whole class is written
      // to avoid, and it would otherwise happen in silence.
      if let error = error {
        NSLog("[ham2k] stopping a capture failed: %@", error.localizedDescription)
      }
    }
  }

  /// Resolves the id a peer stored back to something capturable. Returns the
  /// source's own pixel size alongside, since the stream must be told what to
  /// scale from.
  /// Resolves the id a peer stored, the source's own pixel size, and the
  /// bundle id whose frontmost-ness decides whether the cursor is drawn —
  /// nil for a whole display, where the pointer is simply part of what is on
  /// that screen.
  fileprivate static func filter(for sourceId: String, in content: SCShareableContent)
    -> (SCContentFilter, CGSize, String?)?
  {
    let parts = sourceId.split(separator: ":", maxSplits: 1).map(String.init)
    guard parts.count == 2 else { return nil }
    let (kind, key) = (parts[0], parts[1])

    switch kind {
    case "display":
      guard let displayID = UInt32(key),
        let display = content.displays.first(where: { $0.displayID == displayID })
      else { return nil }
      return (
        SCContentFilter(display: display, excludingWindows: []),
        CGSize(width: display.width, height: display.height),
        nil
      )

    case "app":
      // "Share WSJT-X" means its windows wherever they sit, so the filter is
      // the display restricted to that application rather than one window —
      // a dialog it opens stays in shot, and so does a window it reopens.
      let apps = content.applications.filter { $0.bundleIdentifier == key }
      guard !apps.isEmpty else { return nil }
      // The display the app is actually ON, not simply the first one. A
      // filter is scoped to its display, so on a laptop with an external
      // monitor the wrong guess captures a blank desktop the size of the
      // built-in screen, and scales the stream from its dimensions too.
      let appWindows = content.windows.filter { $0.owningApplication?.bundleIdentifier == key }
      guard let display = ScreenCaptureChannel.displayHosting(appWindows, in: content)
        ?? content.displays.first
      else { return nil }
      return (
        SCContentFilter(display: display, including: apps, exceptingWindows: []),
        CGSize(width: display.width, height: display.height),
        key
      )

    case "window":
      guard let windowID = UInt32(key),
        let window = content.windows.first(where: { $0.windowID == windowID })
      else { return nil }
      return (
        SCContentFilter(desktopIndependentWindow: window),
        window.frame.size,
        window.owningApplication?.bundleIdentifier
      )

    default:
      return nil
    }
  }

  // MARK: - SCStreamOutput

  func stream(
    _ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType
  ) {
    guard type == .screen, CMSampleBufferIsValid(sampleBuffer) else { return }
    // SCK keeps delivering while nothing on screen changes, marking those
    // buffers `.idle` and leaving the pixels stale (`.blank` frames carry no
    // image at all). Encoding and sending them would spend the whole frame
    // budget re-transmitting an unchanged picture.
    guard let attachments = CMSampleBufferGetSampleAttachmentsArray(
      sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
      let statusValue = attachments.first?[.status] as? Int,
      SCFrameStatus(rawValue: statusValue) == .complete
    else { return }

    guard inFlight < Self.maxInFlight,
      let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
    else { return }

    let image = CIImage(cvPixelBuffer: pixelBuffer)
    guard let jpeg = Self.jpeg(from: image, quality: quality) else { return }

    sequence += 1
    let frame = Self.wireFrame(
      sourceId: sourceId,
      width: Int(image.extent.width),
      height: Int(image.extent.height),
      sequence: sequence,
      jpeg: jpeg)

    inFlight += 1
    DispatchQueue.main.async { [weak self] in
      self?.onFrame(frame)
      Self.queue.async { [weak self] in
        guard let self = self else { return }
        self.inFlight = max(0, self.inFlight - 1)
      }
    }
  }

  /// Shared by the streaming path and the picker's thumbnails, so both
  /// spend one CIContext rather than each building its own.
  fileprivate static func jpeg(from image: CIImage, quality: Double) -> Data? {
    return ciContext.jpegRepresentation(
      of: image,
      colorSpace: CGColorSpaceCreateDeviceRGB(),
      options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: quality])
  }

  /// The frame as it travels: one byte of format version, a big-endian
  /// `UInt16` header length, that many bytes of UTF-8 JSON, then the JPEG.
  ///
  /// Packed here rather than in Dart so the bytes the encoder produced reach
  /// the peer's socket untouched. The header carries no timestamp on purpose:
  /// a sender's wall clock is not comparable against the receiver's, so the
  /// viewer stamps arrival with its own clock and the sequence number is what
  /// orders frames. Kept in step with ScreenFrame in
  /// packages/halo_core/lib/src/peer/peer_screen.dart.
  private static func wireFrame(
    sourceId: String, width: Int, height: Int, sequence: Int, jpeg: Data
  ) -> Data {
    let header: [String: Any] = [
      "src": sourceId, "w": width, "h": height, "seq": sequence, "fmt": "jpeg",
    ]
    let headerData =
      (try? JSONSerialization.data(withJSONObject: header)) ?? Data("{}".utf8)
    var out = Data(capacity: 3 + headerData.count + jpeg.count)
    out.append(1)
    out.append(UInt8((headerData.count >> 8) & 0xFF))
    out.append(UInt8(headerData.count & 0xFF))
    out.append(headerData)
    out.append(jpeg)
    return out
  }

  // MARK: - SCStreamDelegate

  func stream(_ stream: SCStream, didStopWithError error: Error) {
    self.stream = nil
    // The operator revoking Screen Recording, or the shared window closing,
    // both arrive here and nowhere else — a viewer left watching a pane that
    // simply stopped updating cannot tell those apart from a slow network.
    DispatchQueue.main.async { [weak self] in
      self?.onStop(error.localizedDescription)
    }
  }
}
