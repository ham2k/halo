// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

/// Every metric, paired with its reader, so a field added to [LayoutMetrics]
/// without being added here fails the completeness check below rather than
/// quietly escaping the ordering and whole-pixel rules.
const _metrics = <String, double Function(LayoutMetrics)>{
  'qsoRowHeight': _qsoRowHeight,
  'qsoRowPaddingV': _qsoRowPaddingV,
  'sectionHeaderHeight': _sectionHeaderHeight,
  'spotTilePaddingV': _spotTilePaddingV,
  'spotTileLineGap': _spotTileLineGap,
  'statusBarCollapsed': _statusBarCollapsed,
  'statusBarRow': _statusBarRow,
  'chipStripClosedGap': _chipStripClosedGap,
  'chipStripOpenGap': _chipStripOpenGap,
  'controlPanelMinHeight': _controlPanelMinHeight,
  'fieldPaddingTop': _fieldPaddingTop,
  'fieldPaddingBottom': _fieldPaddingBottom,
  'chromeHeight': _chromeHeight,
  'numbersRowPaddingV': _numbersRowPaddingV,
};

double _qsoRowHeight(LayoutMetrics m) => m.qsoRowHeight;
double _qsoRowPaddingV(LayoutMetrics m) => m.qsoRowPaddingV;
double _sectionHeaderHeight(LayoutMetrics m) => m.sectionHeaderHeight;
double _spotTilePaddingV(LayoutMetrics m) => m.spotTilePaddingV;
double _spotTileLineGap(LayoutMetrics m) => m.spotTileLineGap;
double _statusBarCollapsed(LayoutMetrics m) => m.statusBarCollapsed;
double _statusBarRow(LayoutMetrics m) => m.statusBarRow;
double _chipStripClosedGap(LayoutMetrics m) => m.chipStripClosedGap;
double _chipStripOpenGap(LayoutMetrics m) => m.chipStripOpenGap;
double _controlPanelMinHeight(LayoutMetrics m) => m.controlPanelMinHeight;
double _fieldPaddingTop(LayoutMetrics m) => m.fieldPaddingTop;
double _fieldPaddingBottom(LayoutMetrics m) => m.fieldPaddingBottom;
double _chromeHeight(LayoutMetrics m) => m.chromeHeight;
double _numbersRowPaddingV(LayoutMetrics m) => m.numbersRowPaddingV;

void main() {
  group('the height ladder', () {
    test('picks a density from the height, at the declared boundaries', () {
      expect(LayoutDensity.forHeight(0), LayoutDensity.densest);
      expect(LayoutDensity.forHeight(449.9), LayoutDensity.densest);
      expect(LayoutDensity.forHeight(450), LayoutDensity.dense, reason: 'boundaries are inclusive upward');
      expect(LayoutDensity.forHeight(480), LayoutDensity.dense, reason: 'the resizable-window floor');
      expect(LayoutDensity.forHeight(649.9), LayoutDensity.dense);
      expect(LayoutDensity.forHeight(650), LayoutDensity.normal);
      expect(LayoutDensity.forHeight(999.9), LayoutDensity.normal);
      expect(LayoutDensity.forHeight(1000), LayoutDensity.sparse);
      expect(LayoutDensity.forHeight(1399.9), LayoutDensity.sparse);
      expect(LayoutDensity.forHeight(1400), LayoutDensity.sparsest);
      expect(LayoutDensity.forHeight(4000), LayoutDensity.sparsest);
    });

    test('the ladder covers every rung, with one band each', () {
      // A band list one short of the rungs would leave the last rung
      // unreachable by Auto, silently.
      expect(LayoutDensity.bands.length, LayoutDensity.values.length - 1);
      final reached = {for (final b in [0.0, ...LayoutDensity.bands]) LayoutDensity.forHeight(b)};
      expect(reached, LayoutDensity.values.toSet());
    });

    test('a landscape phone is dense and an ordinary desktop window is normal', () {
      // The tightest geometry the app actually reaches, per
      // app/test/ui/status_bar_keyboard_test.dart's device matrix.
      expect(LayoutDensity.forHeight(390), LayoutDensity.densest);
      expect(LayoutDensity.forHeight(430), LayoutDensity.densest);
      expect(LayoutDensity.forHeight(900), LayoutDensity.normal, reason: 'a laptop window is what normal describes');
    });

    test('a large font scale reaches a denser layout at the same physical window', () {
      // The ladder reads the UiScale-DIVIDED height, so this is what a 900pt
      // window becomes at font scale 1.90 — 474pt, genuinely less room, so a
      // genuinely denser layout. Mutation check: read the physical height
      // instead and this stays `normal` while the UI overflows.
      expect(LayoutDensity.forHeight(900), LayoutDensity.normal);
      expect(LayoutDensity.forHeight(900 / 1.90), LayoutDensity.dense);
    });
  });

  group('an explicit preference stands, except where the layout must fit', () {
    test('auto follows the height alone', () {
      expect(DensityPreference.auto.resolve(390), LayoutDensity.densest);
      expect(DensityPreference.auto.resolve(900), LayoutDensity.normal);
      expect(DensityPreference.auto.resolve(1400), LayoutDensity.sparsest);
    });

    test('a pick applies when the height can afford it', () {
      expect(DensityPreference.densest.resolve(1400), LayoutDensity.densest);
      expect(DensityPreference.dense.resolve(1400), LayoutDensity.dense);
      expect(DensityPreference.normal.resolve(1400), LayoutDensity.normal);
      expect(DensityPreference.sparse.resolve(1400), LayoutDensity.sparse);
      expect(DensityPreference.sparsest.resolve(1400), LayoutDensity.sparsest);
    });

    test('a genuinely short window overrides any pick', () {
      // The one case the ceiling exists for: below the dense threshold the
      // fixed furniture struggles to fit, so the layout wins over taste.
      // Mutation check: return the preference outright and these fail.
      expect(DensityPreference.sparsest.resolve(390), LayoutDensity.densest);
      expect(DensityPreference.normal.resolve(390), LayoutDensity.densest);
      expect(DensityPreference.sparse.resolve(600), LayoutDensity.dense);
    });

    test('a roomier pick stands on any window that is not short', () {
      // The regression that made two of the three rungs unreachable: an
      // ordinary desktop window is under 1000pt, so clamping `sparse` to what
      // the ladder would have chosen turned it into a no-op and the shortcut
      // appeared to toggle between two values.
      expect(DensityPreference.sparse.resolve(700), LayoutDensity.sparse);
      expect(DensityPreference.sparsest.resolve(800), LayoutDensity.sparsest);
      expect(DensityPreference.sparse.resolve(900), LayoutDensity.sparse);
      expect(DensityPreference.normal.resolve(1400), LayoutDensity.normal);
    });

    test('a denser pick always stands — it can only help things fit', () {
      expect(DensityPreference.densest.resolve(390), LayoutDensity.densest);
      expect(DensityPreference.dense.resolve(900), LayoutDensity.dense);
      expect(DensityPreference.densest.resolve(1400), LayoutDensity.densest);
    });

    test('every rung is reachable on an ordinary window', () {
      // What the operator actually experiences: on one window, each pick
      // produces its own layout. Nothing here may collapse two together.
      const height = 900.0;
      final reached = {
        for (final p in DensityPreference.values.where((p) => p != DensityPreference.auto)) p.resolve(height),
      };
      expect(reached, LayoutDensity.values.toSet());
    });

    test('auto is the default a missing or unknown stored value falls back to', () {
      expect(DensityPreference.values.first, DensityPreference.auto);
    });
  });

  group('stepping (the ⌘⇧-/⌘⇧= shortcuts)', () {
    test('steps from what is IN EFFECT, not from the stored value', () {
      // On a 900pt window auto is normal, so one step denser is dense — not
      // whatever `auto` happens to neighbour in the enum. Mutation check:
      // step the enum index instead and auto→denser lands on `auto` itself.
      expect(DensityPreference.auto.stepped(height: 900, denser: true), DensityPreference.dense);
      expect(DensityPreference.auto.stepped(height: 900, denser: false), DensityPreference.sparse);
      // On a large display auto is already sparsest, so there is nowhere
      // roomier to go.
      expect(DensityPreference.auto.stepped(height: 1400, denser: false), isNull);
      expect(DensityPreference.auto.stepped(height: 1400, denser: true), DensityPreference.sparse);
    });

    test('walks the ladder one rung at a time and stops at both ends', () {
      // A tall window, so nothing is clamped and the walk is the pure ladder.
      const h = 1400.0;
      var at = DensityPreference.sparsest;
      final walkedDown = <DensityPreference>[];
      for (var next = at.stepped(height: h, denser: true); next != null; next = at.stepped(height: h, denser: true)) {
        at = next;
        walkedDown.add(next);
      }
      expect(walkedDown, [
        DensityPreference.sparse,
        DensityPreference.normal,
        DensityPreference.dense,
        DensityPreference.densest,
      ], reason: 'one rung per press, all the way down, then stop');

      final walkedUp = <DensityPreference>[];
      for (var next = at.stepped(height: h, denser: false); next != null; next = at.stepped(height: h, denser: false)) {
        at = next;
        walkedUp.add(next);
      }
      expect(walkedUp, [
        DensityPreference.dense,
        DensityPreference.normal,
        DensityPreference.sparse,
        DensityPreference.sparsest,
      ], reason: 'and all the way back up');
    });

    test('a clamped preference still steps monotonically, in the pressed direction', () {
      // Below the `normal` band the ceiling holds the EFFECTIVE density down
      // while the stored one is free to move, so stepping from the effective
      // value is wrong in both directions. Both traps are pinned here:
      //
      //  - from a clamped `normal`, roomier computes `normal` again and
      //    reports the end of the ladder with two rungs still ahead;
      //  - from a clamped `sparse`, roomier lands on `normal` — DENSER than
      //    what the operator asked for.
      const short = 500.0;
      expect(DensityPreference.normal.resolve(short), LayoutDensity.dense, reason: 'clamped');
      expect(DensityPreference.normal.stepped(height: short, denser: false), DensityPreference.sparse);
      expect(DensityPreference.sparse.stepped(height: short, denser: false), DensityPreference.sparsest);
      expect(DensityPreference.sparse.stepped(height: short, denser: true), DensityPreference.normal);

      // Only the true ends of the ladder stop.
      expect(DensityPreference.sparsest.stepped(height: short, denser: false), isNull);
      expect(DensityPreference.densest.stepped(height: short, denser: true), isNull);
    });

    test('every press moves the setting, at every window and in both directions', () {
      // The shape of the two bugs above, generalised: a press must never
      // leave the setting where it was, and must never move it the way the
      // operator did not press.
      for (final height in [390.0, 500.0, 700.0, 900.0, 1500.0]) {
        for (final start in DensityPreference.values) {
          for (final denser in [true, false]) {
            final next = start.stepped(height: height, denser: denser);
            if (next == null) continue;
            expect(next, isNot(start), reason: '$start at $height did not move');
            if (start != DensityPreference.auto) {
              final before = LayoutDensity.values.byName(start.name).index;
              final after = LayoutDensity.values.byName(next.name).index;
              expect(
                denser ? after < before : after > before,
                isTrue,
                reason: '$start at $height moved the wrong way (denser: $denser)',
              );
            }
          }
        }
      }
    });

    test('the result is always explicit — stepping is taking manual control', () {
      for (final start in DensityPreference.values) {
        for (final denser in [true, false]) {
          for (final height in [390.0, 900.0, 1400.0]) {
            final next = start.stepped(height: height, denser: denser);
            expect(next, isNot(DensityPreference.auto), reason: 'stepping must never land back on auto');
          }
        }
      }
    });
  });

  group('the metrics themselves', () {
    test('every metric has a reader in lib/, not just a value here', () {
      // A metric nothing honours is worse than none: it reads as wired when
      // it is not. `chipHeight` was removed for exactly this reason once the
      // chips turned out to be measured rather than set.
      //
      // Checked by name against the source rather than by call graph, which
      // is crude but catches the case that actually happens — a field added
      // to the ladder and then never read.
      // Each root asserted on its OWN: `lib` always resolves, so checking
      // only that the combined list is non-empty lets a missing `app/lib`
      // quietly narrow the guard instead of failing it — and metrics read
      // only from the app (spotTilePaddingV) would then look unwired, or a
      // genuinely unwired one would slip through. Same per-root `fail` as
      // no_hover_tooltips_test's `_uiSources`.
      final sources = <String>[];
      for (final root in [Directory('lib'), Directory('../../app/lib')]) {
        if (!root.existsSync()) {
          fail('expected ${root.path} to exist — run this suite from the halo_widgets package '
              '(cwd: ${Directory.current.path})');
        }
        sources.addAll(root
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('density.dart'))
            .map((f) => f.readAsStringSync()));
      }
      final unread = _metrics.keys.where((m) => !sources.any((s) => s.contains('.$m'))).toList();
      expect(unread, isEmpty, reason: 'these metrics are declared but nothing reads them: $unread');
    });

    test('every field is covered by this file', () {
      // `toString` on a Dart object lists no fields, so the guard is the
      // count: LayoutMetrics' constructor parameters and _metrics must agree.
      // Bump both together — a metric missing here escapes every rule below.
      expect(_metrics.length, 14, reason: 'add the new LayoutMetrics field to _metrics');
    });

    test('every metric increases strictly across the whole ladder', () {
      // Walks adjacent pairs rather than naming levels, so a rung added at
      // either end is covered the day it lands. A metric that ties between
      // two rungs makes one of them indistinguishable on screen — the
      // shortcut moves and nothing visibly happens.
      for (final entry in _metrics.entries) {
        final read = entry.value;
        for (var i = 0; i < LayoutDensity.values.length - 1; i++) {
          final tighter = LayoutDensity.values[i];
          final roomier = LayoutDensity.values[i + 1];
          expect(
            read(tighter.metrics),
            lessThan(read(roomier.metrics)),
            reason: '${entry.key}: $tighter must be strictly denser than $roomier',
          );
        }
      }
    });

    test('a QSO row declares exactly what its padding and content add up to', () {
      // qso_list_test measures this against the real widget at every density;
      // this is the arithmetic form, so a metrics edit that breaks the
      // relationship fails here first, with the two numbers in the message.
      // 20pt is the mono line the row paints; 1pt is the divider below it.
      for (final density in LayoutDensity.values) {
        final m = density.metrics;
        expect(m.sectionHeaderHeight, m.qsoRowPaddingV * 2 + 20, reason: '$density header');
        expect(m.qsoRowHeight, m.sectionHeaderHeight + 1, reason: '$density row');
      }
    });

    test('every value is a whole logical pixel', () {
      // Fractional values land off the device pixel grid at most font scales
      // and reintroduce the hairline seams PixelGrid exists to remove.
      for (final entry in _metrics.entries) {
        for (final density in LayoutDensity.values) {
          final value = entry.value(density.metrics);
          expect(value, value.roundToDouble(), reason: '${entry.key} at $density is fractional');
        }
      }
    });

    test('normal is the pre-density layout, value for value', () {
      // The defining spec for this rung is the card itself, HALO-76:
      // "Current layout corresponds to Normal". These are the constants each
      // field replaced; changing one here is a change to what every existing
      // user sees, not a density tweak.
      const m = LayoutMetrics.normal;
      expect(m.qsoRowHeight, 29);
      expect(m.qsoRowPaddingV, 4);
      expect(m.sectionHeaderHeight, 28);
      expect(m.spotTilePaddingV, 6);
      expect(m.spotTileLineGap, 2);
      expect(m.statusBarCollapsed, 28);
      expect(m.statusBarRow, 36);
      expect(m.chipStripClosedGap, 14);
      expect(m.chipStripOpenGap, 4);
      expect(m.controlPanelMinHeight, 56);
      expect(m.fieldPaddingTop, 6);
      expect(m.fieldPaddingBottom, 8);
      expect(m.chromeHeight, 48);
      expect(m.numbersRowPaddingV, 4);
    });

    test('the chip density is ordered and inside Flutter clamp', () {
      // The one density knob NOT on the metrics ladder: it was carved out
      // because a chip's height is measured rather than set, which also
      // carved it out of every check the ladder gets. `VisualDensity` clamps
      // to ±4 SILENTLY rather than throwing, so a rung pushed past it would
      // simply stop varying with no failure anywhere.
      for (var i = 0; i < LayoutDensity.values.length - 1; i++) {
        final tighter = LayoutDensity.values[i].chipVisualDensity;
        final roomier = LayoutDensity.values[i + 1].chipVisualDensity;
        expect(
          tighter.vertical,
          lessThan(roomier.vertical),
          reason: '${LayoutDensity.values[i]} must compress chips more than ${LayoutDensity.values[i + 1]}',
        );
      }
      for (final density in LayoutDensity.values) {
        final v = density.chipVisualDensity;
        expect(v.vertical, inInclusiveRange(VisualDensity.minimumDensity, VisualDensity.maximumDensity),
            reason: '$density is outside the range VisualDensity silently clamps to');
        expect(v.horizontal, inInclusiveRange(VisualDensity.minimumDensity, VisualDensity.maximumDensity));
      }
    });

    test('each density resolves to its own metrics', () {
      expect(LayoutDensity.dense.metrics, same(LayoutMetrics.dense));
      expect(LayoutDensity.normal.metrics, same(LayoutMetrics.normal));
      expect(LayoutDensity.sparse.metrics, same(LayoutMetrics.sparse));
    });
  });

  group('the scope', () {
    testWidgets('defaults to normal with nothing above it', (tester) async {
      late LayoutDensity seen;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seen = LayoutDensity.of(context);
            return const SizedBox();
          },
        ),
      );
      expect(seen, LayoutDensity.normal, reason: 'a widget hosted outside the app root behaves as it always did');
    });

    testWidgets('a pane may tighten the density but never loosen it', (tester) async {
      late LayoutDensity seen;
      Widget host({required LayoutDensity outer, required double paneHeight}) => LayoutDensityScope(
        density: outer,
        child: LayoutDensityScope.forHeight(
          height: paneHeight,
          child: Builder(
            builder: (context) {
              seen = LayoutDensity.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      // A short pane inside a tall window: the pane wins, because it is the
      // one that has to fit.
      await tester.pumpWidget(host(outer: LayoutDensity.sparse, paneHeight: 300));
      expect(seen, LayoutDensity.densest);

      // A tall pane inside a dense window cannot buy back room the window
      // doesn't have — e.g. a scrolling pane taller than the viewport.
      await tester.pumpWidget(host(outer: LayoutDensity.dense, paneHeight: 2000));
      expect(seen, LayoutDensity.dense);

      await tester.pumpWidget(host(outer: LayoutDensity.sparse, paneHeight: 1500));
      expect(seen, LayoutDensity.sparse);
    });

    testWidgets('a text field actually gets shorter as the density tightens', (tester) async {
      // The end-to-end proof that the chain works: scope → metrics →
      // poloFieldDecoration → what paints. Every other test here is about the
      // vocabulary in the abstract; this one is why the vocabulary exists.
      //
      // Field height matters more than its own few pixels: the logging row's
      // IntrinsicHeight hands the same height to the submit button's diameter
      // and, through that, to the information area's minimum — so this
      // difference lands three times in the panel's total.
      Future<double> heightAt(LayoutDensity density) async {
        await tester.pumpWidget(
          MaterialApp(
            home: LayoutDensityScope(
              density: density,
              child: Scaffold(
                body: Builder(
                  builder: (context) => TextField(decoration: poloFieldDecoration(context, 'Their call')),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return tester.getSize(find.byType(TextField)).height;
      }

      final heights = <LayoutDensity, double>{};
      for (final density in LayoutDensity.values) {
        heights[density] = await heightAt(density);
      }

      for (var i = 0; i < LayoutDensity.values.length - 1; i++) {
        expect(
          heights[LayoutDensity.values[i]],
          lessThan(heights[LayoutDensity.values[i + 1]]!),
          reason: '${LayoutDensity.values[i]} must paint shorter than ${LayoutDensity.values[i + 1]}',
        );
      }

      // The span end to end, so a metrics edit that flattens the ladder into
      // near-identical rungs is a failure rather than a shrug.
      expect(heights[LayoutDensity.sparsest]! - heights[LayoutDensity.densest]!, greaterThanOrEqualTo(15.0));
    });

    testWidgets('chrome rows never shrink below a finger on touch', (tester) async {
      // The tab strips ARE the app's primary navigation on a phone, and a
      // landscape phone lands in `densest` — exactly the rung whose raw value
      // is under Material's minimum tap target. The clamp is what stops the
      // density ladder from quietly making navigation harder to hit.
      Future<double> readAt(LayoutDensity density) async {
        late double height;
        await tester.pumpWidget(
          LayoutDensityScope(
            density: density,
            child: Builder(
              builder: (context) {
                height = LayoutDensity.chromeHeightOf(context);
                return const SizedBox();
              },
            ),
          ),
        );
        return height;
      }

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(await readAt(LayoutDensity.densest), kMinInteractiveDimension);
      expect(await readAt(LayoutDensity.dense), kMinInteractiveDimension);
      expect(await readAt(LayoutDensity.normal), kMinInteractiveDimension);
      expect(await readAt(LayoutDensity.sparsest), 60, reason: 'the floor is a floor, not a pin');

      // Desktop has a precise pointer, so the tight rungs are allowed.
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(await readAt(LayoutDensity.densest), 42);
      expect(await readAt(LayoutDensity.dense), 44);

      // Restored in the BODY, not an addTearDown: the framework asserts that
      // foundation debug variables are back to normal before teardowns run.
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('a density change notifies dependents', (tester) async {
      var builds = 0;
      // ONE child instance, reused across pumps. A fresh `Builder` each time
      // rebuilds because its own widget changed, which would pass this test
      // against an `updateShouldNotify` that always returned false.
      final child = Builder(
        builder: (context) {
          LayoutDensity.of(context);
          builds++;
          return const SizedBox();
        },
      );
      Widget host(LayoutDensity density) => LayoutDensityScope(density: density, child: child);

      await tester.pumpWidget(host(LayoutDensity.normal));
      expect(builds, 1);

      await tester.pumpWidget(host(LayoutDensity.normal));
      expect(builds, 1, reason: 'an unchanged density must not rebuild the subtree');

      await tester.pumpWidget(host(LayoutDensity.dense));
      expect(builds, 2, reason: 'a changed density must reach its dependents');
    });
  });
}
