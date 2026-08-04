// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The app-wide spacing vocabulary: seven rungs, and every padding, margin and
// gap in the app is one of them (docs/design/user-interface.md § Spacing).
//
// Values are plain logical pixels in the UiScale-divided space
// (docs/design/ui-scaling.md rule 2) — the root `UiScale` already multiplies
// the whole tree by the font scale, so nothing here is ever multiplied again.

import 'layout.dart';

/// The rungs a padding, margin or gap may take.
///
/// Pick by role, not by arithmetic: [md] is the default gap between related
/// things, [xl] the padding of a panel or card, [lg] the inset of a compact
/// row, [xs] the space between a glyph and its label. Reach for a neighbour
/// only when the default genuinely reads wrong — a value that fits none of
/// them is usually a *size* (a row height, a control diameter, a map camera
/// inset), which belongs in a named constant of its own rather than here.
///
/// Distinct from [ShirtSize], which is the *width* vocabulary for choosing a
/// pane arrangement: that one classifies a window, this one measures a gap.
/// They share the t-shirt idiom and nothing else — the rungs don't correspond,
/// and neither is derived from the other.
///
/// The ladder stays short: its job is to give new UI a small menu to choose
/// from, and a ninth rung two pixels from an eighth defeats that. A new rung
/// needs a role no existing one covers, not a site that happens to want an
/// in-between number.
///
/// A measurement that mirrors one of these gaps must name the same rung
/// rather than repeat its value — `TextPainter` width math that hand-copies a
/// padding measures the wrong widget the moment the rung moves, and nothing
/// catches it. `logging_controls.dart`'s notice-pill measurements are the
/// worked example.
abstract final class Space {
  /// Hairline separation — the space between two lines of the same record,
  /// or a nudge that must not read as a gap at all.
  static const double xxs = 2.0;

  /// A glyph and its label; the inset of a chip or pill.
  static const double xs = 4.0;

  /// A compact row's vertical breathing room.
  static const double sm = 6.0;

  /// **The default.** The gap between two related controls, and the standing
  /// answer when no rung is obviously better.
  static const double md = 8.0;

  /// A list row's own inset; the gap between a group's members.
  static const double lg = 12.0;

  /// The padding of a panel, card or dialog body; the gap between groups.
  static const double xl = 16.0;

  /// The gap between major sections of a scrolling view.
  static const double xxl = 24.0;
}
