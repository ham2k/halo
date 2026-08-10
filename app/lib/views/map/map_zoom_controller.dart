// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Bridges the Map tab's zoom buttons (map_panel.dart) to whichever backend
// is currently live. Each backend that supports zoom-by-button wires its
// own zoomIn/zoomOut into a controller instance passed down at construction,
// so the buttons don't need a backend-specific controller type — the facade
// swaps backends (OSM vs Mapbox vs MapLibre) without the button widget
// caring which one is underneath.

class MapZoomController {
  void Function()? onZoomIn;
  void Function()? onZoomOut;

  void zoomIn() => onZoomIn?.call();
  void zoomOut() => onZoomOut?.call();
}
