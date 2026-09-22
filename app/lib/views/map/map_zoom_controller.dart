// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Bridges the Map tab's zoom buttons (map_panel.dart) to whichever backend
// is currently live. Each backend that supports zoom-by-button wires its
// own zoomIn/zoomOut into a controller instance passed down at construction,
// so the buttons don't need a backend-specific controller type — the facade
// swaps backends (OSM vs the MapLibre webview/web view) without the button
// widget caring which one is underneath.

class MapZoomController {
  void Function()? onZoomIn;
  void Function()? onZoomOut;

  /// Set by every backend that can be pointed somewhere — see [moveTo].
  void Function(double latitude, double longitude, double zoom)? onMoveTo;

  void zoomIn() => onZoomIn?.call();
  void zoomOut() => onZoomOut?.call();

  /// Centers the map on one point at [zoom], leaving whatever it is showing
  /// in place — this is a camera move, not a data change, so it never
  /// competes with a backend's own fit-to-markers.
  ///
  /// Silently does nothing when no backend is live: the Activities pane
  /// builds its controller with the pane and hands it to whichever backend
  /// the platform picks, so the rows above the map can call this during the
  /// frame before that backend's State has wired itself up.
  void moveTo(double latitude, double longitude, {double zoom = closeUpZoom}) => onMoveTo?.call(latitude, longitude, zoom);

  /// Close enough to read one reference's surroundings — a summit's
  /// activation zone frames at roughly half the pane at this level, where
  /// the marker-fit's own cap (zoom 11) leaves it a speck.
  static const closeUpZoom = 14.0;
}
