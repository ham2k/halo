// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Layout density: how much vertical room the app's fixed furniture spends,
// chosen from the height available rather than the width (docs/design/
// layouts.md owns the width vocabulary, ShirtSize).
//
// Heights here are plain logical pixels in the UiScale-divided space
// (docs/design/ui-scaling.md rule 2), so a larger font scale genuinely fits
// less and reaches for a denser layout sooner — the same way ShirtSize
// collapses to narrower arrangements.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'platform_chrome.dart';

/// How tightly the app spends vertical space.
///
/// Deliberately about **named dimensions**, not about every padding in the
/// app: row heights, control diameters and field padding are what the height
/// budget is actually made of. The seven `Space` rungs stay compile-time
/// constants and do not vary — see docs/design/user-interface.md § Spacing.
enum LayoutDensity {
  densest,
  dense,
  normal,
  sparse,
  sparsest;

  /// How the secondary-control pills are compressed.
  ///
  /// A `VisualDensity`, not a [LayoutMetrics] height, because a chip's height
  /// is not something this code sets: `SecondaryControlRow` MEASURES its
  /// chips and lays the strip out from what it finds. Flutter's own knob is
  /// the only way in, and chips are one of the few widgets it genuinely
  /// reaches — its units are notional, not pixels, so it is deliberately not
  /// on the whole-pixel ladder the metrics follow.
  VisualDensity get chipVisualDensity => switch (this) {
    LayoutDensity.densest => const VisualDensity(horizontal: -1, vertical: -4),
    LayoutDensity.dense => const VisualDensity(horizontal: -1, vertical: -3),
    LayoutDensity.normal => VisualDensity.compact,
    LayoutDensity.sparse => VisualDensity.standard,
    LayoutDensity.sparsest => const VisualDensity(horizontal: 0, vertical: 2),
  };

  /// The metrics this density resolves to.
  LayoutMetrics get metrics => switch (this) {
    LayoutDensity.densest => LayoutMetrics.densest,
    LayoutDensity.dense => LayoutMetrics.dense,
    LayoutDensity.normal => LayoutMetrics.normal,
    LayoutDensity.sparse => LayoutMetrics.sparse,
    LayoutDensity.sparsest => LayoutMetrics.sparsest,
  };

  /// The band boundaries, ascending. A height below the first is [densest];
  /// at or above the last, [sparsest].
  ///
  /// Grounded in the heights the app actually meets, in the UiScale-divided
  /// space: a landscape phone is 390–430 and a large font scale divides an
  /// ordinary window into the same range, so both land in [densest]; the
  /// resizable-window floor (`minWindowSize.height`, 480) is [dense]; a
  /// laptop window is [normal], which is what the app looked like before
  /// densities existed; a maximized desktop window reaches [sparse], and a
  /// large display [sparsest].
  ///
  /// These decide only what **Auto** picks. An explicit preference is not
  /// gated by them except in the bands below [normal] — see
  /// [DensityPreference.resolve].
  static const List<double> bands = [450.0, 650.0, 1000.0, 1400.0];

  /// The density [height] alone calls for, before any user preference.
  static LayoutDensity forHeight(double height) {
    var index = 0;
    while (index < bands.length && height >= bands[index]) {
      index++;
    }
    return values[index];
  }

  /// The density in effect for [context].
  ///
  /// Defaults to [normal] with no scope above — the pre-density layout, so a
  /// widget tested or hosted outside the app root behaves as it always did.
  static LayoutDensity of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LayoutDensityScope>()?.density ?? LayoutDensity.normal;

  /// [of], resolved to the dimensions themselves — the common case.
  static LayoutMetrics metricsOf(BuildContext context) => of(context).metrics;

  /// [LayoutMetrics.chromeHeight], held to the tap-target minimum on the
  /// mobile PLATFORMS — `isMobilePlatform`, i.e. iOS or Android and not web.
  ///
  /// Platform, not pointer: a touch device running the web build is
  /// deliberately outside the clamp and does get the tight rungs. Widening
  /// this to every coarse pointer would also catch touchscreen laptops, which
  /// are overwhelmingly driven by trackpad.
  ///
  /// The clamp lives here rather than in the metrics so the ladder itself
  /// stays honest — `density_test` requires every metric to increase strictly,
  /// and a platform-dependent value would make that untestable. Every chrome
  /// row reads THIS, so they cannot disagree about where the floor is.
  ///
  /// The floor is deliberately not conditioned on the density: a landscape
  /// phone lands in [densest], which is exactly the case where the tab strip
  /// is the app's primary navigation and a thumb still has to hit it.
  static double chromeHeightOf(BuildContext context) {
    final height = metricsOf(context).chromeHeight;
    return isMobilePlatform ? math.max(height, kMinInteractiveDimension) : height;
  }

  /// The denser of two densities — how [DensityPreference.resolve] holds a
  /// pick to what a genuinely short window can fit.
  LayoutDensity atMost(LayoutDensity other) => index <= other.index ? this : other;
}

/// The operator's Layout Density setting: [auto] follows the height of the
/// window, the other five name a density outright. Stored by
/// `SettingsService.densityPreference`; the rule for what it *means* lives
/// here, with the vocabulary it resolves into.
///
/// An explicit pick is honoured, with one exception: on a window short enough
/// to sit below the [LayoutDensity.normal] band, the layout has to fit, and
/// that wins. See [resolve].
enum DensityPreference {
  auto,
  densest,
  dense,
  normal,
  sparse,
  sparsest;

  /// The density this preference resolves to at [height] logical pixels.
  ///
  /// The height overrides an explicit pick **only in the bands below
  /// [LayoutDensity.normal]** — windows short enough that the fixed furniture
  /// genuinely struggles to fit. Everywhere else the pick stands, including a
  /// roomier one than the ladder would have chosen: `sparsest` on an 800pt
  /// window costs nothing but room the window has, and clamping it there
  /// would make most of the ladder unreachable on an ordinary window.
  ///
  /// A DENSER pick is always honoured, even on a short window — it can only
  /// help things fit.
  ///
  /// The band boundaries are about what suits a height by DEFAULT, not about
  /// what fits. Conflating the two is what once made every roomier rung a
  /// no-op below 1000pt.
  LayoutDensity resolve(double height) {
    final fromHeight = LayoutDensity.forHeight(height);
    if (this == DensityPreference.auto) return fromHeight;
    final pick = LayoutDensity.values.byName(name);
    if (fromHeight.index < LayoutDensity.normal.index) return pick.atMost(fromHeight);
    return pick;
  }

  /// The densities the Settings picker offers, in order — [auto] first, since
  /// it is the default and the one most operators should stay on.
  static List<DensityPreference> get selectableValues => values;

  /// This preference stepped one rung tighter ([denser]) or roomier, as the
  /// ⌘⇧-/⌘⇧= shortcuts do. Null at the end of the ladder, so a caller can
  /// tell "nowhere further to go" from "moved" and say so rather than
  /// looking broken.
  ///
  /// [auto] steps from the density in EFFECT at [height], so the first press
  /// off it moves by exactly one visible rung. Every other value steps from
  /// ITSELF — the shortcut moves the setting, and once the setting is
  /// explicit that is the thing being stepped.
  ///
  /// Stepping from the effective density in the explicit case looks tempting
  /// and is wrong: below the `normal` band [resolve]'s ceiling holds the
  /// effective value down, so from a clamped `normal` the roomier step
  /// computed `normal` again and reported the end of the ladder with two
  /// rungs still ahead, and from a clamped `sparse` it moved the stored value
  /// DENSER while the operator pressed roomier.
  ///
  /// The ceiling still applies to the result: on a window too short for it a
  /// roomier pick is stored but does not take effect, which is what the
  /// caller's "too short" message is for.
  DensityPreference? stepped({required double height, required bool denser}) {
    final from = this == DensityPreference.auto
        ? resolve(height)
        : LayoutDensity.values.byName(name);
    final index = from.index + (denser ? -1 : 1);
    if (index < 0 || index >= LayoutDensity.values.length) return null;
    return DensityPreference.values.byName(LayoutDensity.values[index].name);
  }
}

/// The dimensions one [LayoutDensity] resolves to.
///
/// Every field is a **named** dimension that something's height is actually
/// made of. Two rules hold across all five instances:
///
/// - A height declared here must equal what the widget paints. The QSO list's
///   pinned day header asserts on the difference at runtime, and the row
///   heights feed scroll arithmetic that never measures
///   ([`QsoList`]'s `_estimatedTopOf`), so a row that paints taller than it
///   declares scrolls to the wrong place with nothing to catch it.
///   `density_test.dart` and `qso_list_test.dart` pin each pair.
/// - Values stay whole logical pixels. Fractional ones land off the device
///   pixel grid at most font scales and reintroduce the hairline seams
///   `PixelGrid` exists to remove (docs/design/ui-scaling.md).
@immutable
class LayoutMetrics {
  /// An ordinary QSO row, divider included. Declared rather than measured:
  /// see the class doc.
  final double qsoRowHeight;

  /// The QSO row's own vertical padding. [qsoRowHeight] is this twice, plus
  /// the mono line the row paints, plus its divider.
  final double qsoRowPaddingV;

  /// The pinned day header in the QSO list, and — because the two read as one
  /// list — the spots panel's section header.
  final double sectionHeaderHeight;

  /// A spot tile's vertical padding.
  final double spotTilePaddingV;

  /// The status footer's collapsed height, and one row of its expanded list.
  final double statusBarCollapsed;
  final double statusBarRow;

  /// The gap below the secondary-control pill strip when it is closed / open.
  final double chipStripClosedGap;
  final double chipStripOpenGap;

  /// The minimum content height of an open secondary control's panel.
  final double controlPanelMinHeight;

  /// The vertical content padding every text field gets
  /// (`poloFieldDecoration`) — top and bottom. The highest-leverage value
  /// here: it sets the main logging fields' height, the submit button's
  /// diameter, and through that the information area's minimum height.
  final double fieldPaddingTop;
  final double fieldPaddingBottom;

  /// The vertical padding around the mobile numbers row's keys.
  ///
  /// The KEY height itself does not vary: those are tap targets on a phone,
  /// already at Apple's 44pt minimum. Only the strip's padding gives, so this
  /// ladder is a narrow one by design.
  final double numbersRowPaddingV;

  /// The height of a **chrome row**: the app header, every tab strip, the
  /// wide split's pane title bar, and a dock group's header.
  ///
  /// One value for all of them on purpose. They stack and abut — the narrow
  /// tab strip sits directly under the app header, and the wide split's title
  /// bar has to line up with the TabBar across the divider — so a ladder that
  /// moved one without the other would read as a mistake at every rung but
  /// `normal`.
  ///
  /// Read it through [LayoutDensity.chromeHeightOf], never directly: on a
  /// touch device these rows carry the app's primary navigation and may not
  /// shrink below the tap-target minimum, whatever the density says.
  final double chromeHeight;

  const LayoutMetrics._({
    required this.qsoRowHeight,
    required this.qsoRowPaddingV,
    required this.sectionHeaderHeight,
    required this.spotTilePaddingV,
    required this.statusBarCollapsed,
    required this.statusBarRow,
    required this.chipStripClosedGap,
    required this.chipStripOpenGap,
    required this.controlPanelMinHeight,
    required this.fieldPaddingTop,
    required this.fieldPaddingBottom,
    required this.chromeHeight,
    required this.numbersRowPaddingV,
  });

  /// What the app looked like before densities existed — every value here is
  /// the constant it replaced, unchanged.
  static const normal = LayoutMetrics._(
    numbersRowPaddingV: 4,
    chromeHeight: 48,
    qsoRowHeight: 29,
    qsoRowPaddingV: 4,
    sectionHeaderHeight: 28,
    spotTilePaddingV: 6,
    statusBarCollapsed: 28,
    statusBarRow: 36,
    chipStripClosedGap: 14,
    chipStripOpenGap: 4,
    controlPanelMinHeight: 56,
    fieldPaddingTop: 6,
    fieldPaddingBottom: 8,
  );

  static const densest = LayoutMetrics._(
    numbersRowPaddingV: 2,
    chromeHeight: 42,
    qsoRowHeight: 23,
    qsoRowPaddingV: 1,
    sectionHeaderHeight: 22,
    spotTilePaddingV: 3,
    statusBarCollapsed: 22,
    statusBarRow: 27,
    chipStripClosedGap: 5,
    chipStripOpenGap: 1,
    controlPanelMinHeight: 44,
    fieldPaddingTop: 3,
    fieldPaddingBottom: 4,
  );

  static const dense = LayoutMetrics._(
    numbersRowPaddingV: 3,
    chromeHeight: 44,
    qsoRowHeight: 25,
    qsoRowPaddingV: 2,
    sectionHeaderHeight: 24,
    spotTilePaddingV: 4,
    statusBarCollapsed: 24,
    statusBarRow: 30,
    chipStripClosedGap: 8,
    chipStripOpenGap: 2,
    controlPanelMinHeight: 48,
    fieldPaddingTop: 4,
    fieldPaddingBottom: 5,
  );

  static const sparse = LayoutMetrics._(
    numbersRowPaddingV: 6,
    chromeHeight: 54,
    qsoRowHeight: 35,
    qsoRowPaddingV: 7,
    sectionHeaderHeight: 34,
    spotTilePaddingV: 9,
    statusBarCollapsed: 32,
    statusBarRow: 42,
    chipStripClosedGap: 18,
    chipStripOpenGap: 6,
    controlPanelMinHeight: 64,
    fieldPaddingTop: 9,
    fieldPaddingBottom: 11,
  );

  static const sparsest = LayoutMetrics._(
    numbersRowPaddingV: 8,
    chromeHeight: 60,
    qsoRowHeight: 41,
    qsoRowPaddingV: 10,
    sectionHeaderHeight: 40,
    spotTilePaddingV: 12,
    statusBarCollapsed: 36,
    statusBarRow: 48,
    chipStripClosedGap: 22,
    chipStripOpenGap: 8,
    controlPanelMinHeight: 72,
    fieldPaddingTop: 12,
    fieldPaddingBottom: 14,
  );
}

/// Publishes a [LayoutDensity] to a subtree.
///
/// Inserted once at the app root from the window height and the operator's
/// preference, and again by anything that knows its subtree is genuinely
/// shorter than the window — a vertical dock split, a Modal Pane. A pane
/// reading the window's height would spend room it doesn't have.
class LayoutDensityScope extends InheritedWidget {
  final LayoutDensity density;

  const LayoutDensityScope({super.key, required this.density, required super.child});

  /// Inserts a scope for a subtree [height] logical pixels tall, never
  /// sparser than what is already in effect: a pane cannot be roomier than
  /// the window it sits in, however tall the pane itself is.
  static Widget forHeight({Key? key, required double height, required Widget child}) {
    return Builder(
      builder: (context) => LayoutDensityScope(
        key: key,
        density: LayoutDensity.forHeight(height).atMost(LayoutDensity.of(context)),
        child: child,
      ),
    );
  }

  @override
  bool updateShouldNotify(LayoutDensityScope oldWidget) => density != oldWidget.density;
}
