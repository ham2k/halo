// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Per-screen-instance de-duplication for the `panel_used` event
// (docs/design/telemetry.md). A screen's State owns one of these, so leaving
// and re-entering the screen reports its panels again while repeated use
// during a single visit reports once.

/// The shape of `HaLoServices.track`, taken as a function so this stays
/// independent of the services object (and trivially fakeable in tests).
typedef TrackEvent = void Function(String event, [Map<String, Object?> properties]);

class PanelUseTracker {
  PanelUseTracker({required this.track, required this.screen});

  final TrackEvent track;

  /// The `screen_viewed` name of the screen these panels live in — reported
  /// alongside the panel, since panel names are only unique within a screen.
  final String screen;

  final Set<String> _reported = {};

  /// Call on a panel's first real input — a tap or a keystroke inside it.
  /// NOT on the panel merely appearing: the operation screen's two-pane
  /// layout has several panels on screen at once and only some get touched,
  /// which is the whole reason this event exists separately from
  /// `screen_viewed`.
  void used(String panel) {
    if (!_reported.add(panel)) return;
    track('panel_used', {'screen': screen, 'panel': panel});
  }
}
