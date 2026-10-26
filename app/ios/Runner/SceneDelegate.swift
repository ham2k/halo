import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let view = window?.rootViewController?.view { DisplayRegions.shared.watch(view) }
  }

  override func sceneWillEnterForeground(_ scene: UIScene) {
    super.sceneWillEnterForeground(scene)
    if let view = window?.rootViewController?.view { DisplayRegions.shared.watch(view) }
  }
}

/// The parts of the display iOS reserves or shapes, for the Dart side's
/// DisplayRegionInsets (packages/halo_widgets/lib/src/display_regions.dart):
/// Flutter's MediaQuery carries one inset per edge and no fold, so a
/// foldable's status-bar band, rounded corners and fold reach Dart only
/// through here.
///
/// Sent whole on `ham2k/display_regions` whenever any of it changes — the
/// view's size or safe area (a rotation, a fold to the other display) or the
/// hinge (half-folded and back, which changes neither). All in the Flutter
/// view's points, which are Flutter's logical pixels.
final class DisplayRegions {
  static let shared = DisplayRegions()

  var channel: FlutterMethodChannel? {
    didSet {
      channel?.setMethodCallHandler { [weak self] call, result in
        guard let self, call.method == "get" else {
          result(FlutterMethodNotImplemented)
          return
        }
        // The header's height is the Dart side's to decide; the bar region
        // it asks iOS about has to be that height to place it.
        if let extent = (call.arguments as? [String: Any])?["headerExtent"] as? Double {
          self.headerExtent = CGFloat(extent)
        }
        self.last = self.snapshot()
        result(self.last)
      }
    }
  }

  // The Dart side's `_headerExtent`, for the pushes sent before its first
  // `get` says so itself.
  private var headerExtent: CGFloat = 58
  private weak var view: UIView?
  private var watcher: Watcher?
  private var last: [String: Any]?

  func watch(_ view: UIView) {
    guard view !== self.view else { return }
    self.view = view
    watcher?.removeFromSuperview()
    let watcher = Watcher(frame: view.bounds)
    watcher.onChange = { [weak self] in self?.update() }
    view.insertSubview(watcher, at: 0)
    self.watcher = watcher
    update()
  }

  private func update() {
    let now = snapshot()
    guard let channel else { return }
    if let last, let now, NSDictionary(dictionary: last).isEqual(to: now) { return }
    last = now
    channel.invokeMethod("changed", arguments: now)
  }

  private func snapshot() -> [String: Any]? {
    guard let view else { return nil }
    var out: [String: Any] = ["width": view.bounds.width, "height": view.bounds.height]
    if #available(iOS 26.0, *) {
      out["cornerSafeArea"] = Self.insets(view.edgeInsets(for: .safeArea(cornerAdaptation: .horizontal)))
    }
    // The bar regions and reserved regions are iOS 27.1 SDK API: an older
    // Xcode builds without them, and the Dart side then corrects nothing.
    #if compiler(>=6.4)
      if #available(iOS 27.1, *) {
        out["headerBar"] = Self.insets(view.edgeInsets(for: .bar(onEdge: UIRectEdge.top, extent: headerExtent)))
        if let fold = view.reservedRegions(kind: .division, options: .includeInactive).first {
          // The frame includes the margins iOS keeps either side of the
          // fold itself.
          out["fold"] = [
            "left": fold.frame.minX, "top": fold.frame.minY,
            "width": fold.frame.width, "height": fold.frame.height,
            "active": fold.isActive,
          ]
        }
      }
    #else
      #warning("Built without the iOS 27.1 SDK: no fold or header bar is reported, and the iPhone Duo runs uncorrected (docs/quirks.md)")
    #endif
    return out
  }

  private static func insets(_ i: UIEdgeInsets) -> [String: Any] {
    ["top": i.top, "left": i.left, "bottom": i.bottom, "right": i.right]
  }

  /// A transparent, untouchable view filling the Flutter view, for the
  /// callbacks UIKit gives a view and not its observers: resized with its
  /// parent, told when the safe area moves, and carrying the hinge
  /// interaction.
  private final class Watcher: UIView {
    var onChange: (() -> Void)?

    override init(frame: CGRect) {
      super.init(frame: frame)
      autoresizingMask = [.flexibleWidth, .flexibleHeight]
      isUserInteractionEnabled = false
      isAccessibilityElement = false
      accessibilityElementsHidden = true
      backgroundColor = .clear
      #if compiler(>=6.4)
        if #available(iOS 27.1, *) {
          addInteraction(UIHingeInteraction { [weak self] _, _ in self?.onChange?() })
        }
      #endif
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
      super.layoutSubviews()
      onChange?()
    }

    override func safeAreaInsetsDidChange() {
      super.safeAreaInsetsDidChange()
      onChange?()
    }
  }
}
