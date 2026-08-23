// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Which spot is the QSO being logged, and what that row is tinted with. Both
// halves are a judgement about the operator's attention: a row lit up for the
// wrong station sends them to the wrong frequency, and a tint that outshines
// the logging panel makes the spots list read as the thing being typed into.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/views/operation/spots_panel.dart';

Map<String, dynamic> _spot(String call) => {
      'their': {'call': call},
      'refs': const <Map<String, dynamic>>[],
      'spot': {'timeInMillis': nowMillis() - 60000, 'source': 'test'},
    };

/// How much of `container` survives in `color` once it has been blended into
/// `surface` — 0 is the bare surface, 1 the container itself. Read off the
/// channel the two differ most in, so a near-tie doesn't decide it.
double _strengthOf(Color color, {required Color surface, required Color container}) {
  final channels = [
    (color.r, surface.r, container.r),
    (color.g, surface.g, container.g),
    (color.b, surface.b, container.b),
  ];
  channels.sort((a, b) => (b.$3 - b.$2).abs().compareTo((a.$3 - a.$2).abs()));
  final (value, from, to) = channels.first;
  return (value - from) / (to - from);
}

/// A section's spots. The label is taken but unused: `locateCurrentSpotRow`
/// sums geometry and never reads it, and the tests read better naming the
/// band they mean.
List<Map<String, dynamic>> _section(String label, List<String> calls) =>
    [for (final call in calls) _spot(call)];

void main() {
  group('locateCurrentSpotRow', () {
    // Every row is plain here, so the offset is headers + whole rows: one
    // header of 30, then two 20m rows and W3GHI, then its own 40m header.
    test('sums the headers and rows above the match into a scroll offset', () {
      final found = locateCurrentSpotRow([
        _section('20m', ['K1ABC', 'W2DEF']),
        _section('40m', ['W3GHI', 'K4JKL', 'N5MNO']),
      ], currentCall: 'K4JKL', headerHeight: 30, heightOf: (_) => 40);

      expect(found, isNotNull);
      expect(found!.top, closeTo(30 + 2 * 40 + 30 + 40, 0.001));
      expect(found.height, closeTo(40, 0.001));
    });

    // The whole reason the sum takes a per-row height instead of a count times
    // one representative value. A few pixels per row is nothing on its own and
    // a row's worth by the time a POTA board has scrolled a hundred of them —
    // far enough that the correction pass can no longer even measure the
    // target, because it was never mounted.
    test('rows above of differing heights each contribute their own', () {
      double heightOf(Map<String, dynamic> spot) =>
          (spot['their'] as Map)['call'] == 'W2DEF' ? 80.0 : 40.0;
      final found = locateCurrentSpotRow(
        [_section('20m', ['K1ABC', 'W2DEF', 'K4JKL'])],
        currentCall: 'K4JKL',
        headerHeight: 30,
        heightOf: heightOf,
      );

      expect(found!.top, closeTo(30 + 40 + 80, 0.001),
          reason: 'the taller row pushes the target down by its own height, not the average');
    });

    // "Calls of Note" pins a duplicate of a spot that also appears in its band
    // section — the SAME Map instance, so naming the row by spot identity puts
    // one GlobalKey on two tiles and the tree throws. A (section, index) pair
    // names exactly one, and the first copy is the one nearest the top.
    test('names the row by position, so a pinned duplicate names only one tile', () {
      final shared = _spot('K1ABC');
      final found = locateCurrentSpotRow([
        [shared],                          // Calls of Note
        [_spot('W2DEF'), shared],          // 20m
      ], currentCall: 'K1ABC', headerHeight: 30, heightOf: (_) => 40);

      expect((found!.section, found.index), (0, 0));
      expect(found.top, closeTo(30, 0.001), reason: 'directly under the first header');
    });

    test('no match anywhere is null, not a zeroed position', () {
      final args = (headerHeight: 30.0, heightOf: (Map<String, dynamic> _) => 40.0);
      expect(
        locateCurrentSpotRow([_section('20m', ['K1ABC'])],
            currentCall: 'W9XYZ', headerHeight: args.headerHeight, heightOf: args.heightOf),
        isNull,
      );
      expect(
        locateCurrentSpotRow([_section('20m', ['K1ABC'])],
            currentCall: null, headerHeight: args.headerHeight, heightOf: args.heightOf),
        isNull,
      );
      expect(
        locateCurrentSpotRow([], currentCall: 'K1ABC', headerHeight: args.headerHeight, heightOf: args.heightOf),
        isNull,
      );
    });
  });

  group('spotRowHeightFor', () {
    // Additive because the two features land on different lines of the tile.
    // This says nothing about whether the constants match the widget — see
    // spots_panel_reveal_test.dart, which measures real rows against them at
    // every density.
    test('a label and an emoji each add their own height, and stack', () {
      final metrics = LayoutDensity.normal.metrics;
      final plain = spotRowHeightFor(metrics: metrics, hasLabel: false, hasEmoji: false);
      final labelled = spotRowHeightFor(metrics: metrics, hasLabel: true, hasEmoji: false);
      final noted = spotRowHeightFor(metrics: metrics, hasLabel: false, hasEmoji: true);
      final both = spotRowHeightFor(metrics: metrics, hasLabel: true, hasEmoji: true);

      expect(labelled, greaterThan(plain));
      expect(noted, greaterThan(plain));
      expect(both, closeTo(labelled + noted - plain, 0.001));
    });

    test('a denser layout makes every row shorter, by its spacing alone', () {
      // The reveal sums declared heights, so a ladder the tile does not
      // actually follow scrolls to the wrong place with nothing to catch it.
      // Mutation check: read a fixed metric here and the strict ordering goes.
      for (var i = 0; i < LayoutDensity.values.length - 1; i++) {
        final tighter = LayoutDensity.values[i].metrics;
        final roomier = LayoutDensity.values[i + 1].metrics;
        for (final hasLabel in [false, true]) {
          for (final hasEmoji in [false, true]) {
            expect(
              spotRowHeightFor(metrics: tighter, hasLabel: hasLabel, hasEmoji: hasEmoji),
              lessThan(spotRowHeightFor(metrics: roomier, hasLabel: hasLabel, hasEmoji: hasEmoji)),
            );
          }
        }
        // The label and emoji lines are text, not spacing, so the whole
        // difference between two rungs is the tile's padding and the gap
        // between its two lines — nothing else on the row moves.
        expect(
          spotRowHeightFor(metrics: roomier, hasLabel: true, hasEmoji: true) -
              spotRowHeightFor(metrics: tighter, hasLabel: true, hasEmoji: true),
          closeTo(
            (roomier.spotTilePaddingV - tighter.spotTilePaddingV) * 2 +
                (roomier.spotTileLineGap - tighter.spotTileLineGap),
            0.001,
          ),
        );
      }
    });

    test('normal is the pre-density row height', () {
      // 50 is what every row was before the tile joined the ladder; changing
      // it is a change to what existing operators see, not a density tweak.
      expect(
        spotRowHeightFor(metrics: LayoutDensity.normal.metrics, hasLabel: false, hasEmoji: false),
        50,
      );
    });
  });

  group('spotRowScaleFor', () {
    // The scale stands for the OS text scale, which stretches the row's TEXT
    // and leaves the tile's padding and line gap — the two things the ladder
    // moves — at their logical-pixel sizes. So the invariant across a rung
    // change is the painted height of the text, not the ratio itself.
    double textHeightAt(LayoutMetrics m, double scale) =>
        spotRowHeightFor(metrics: m, hasLabel: false, hasEmoji: false) * scale -
        (m.spotTilePaddingV * 2 + m.spotTileLineGap);

    test('carries the text stretch across every pair of rungs', () {
      // 1.158 is what a real 1.3 text scale calibrates to at `normal`, per
      // spots_panel_reveal_test's measurements. Mutation check: return `scale`
      // unchanged and every pair but the identity ones fails.
      const learned = 1.158;
      for (final from in LayoutDensity.values) {
        for (final to in LayoutDensity.values) {
          final converted = spotRowScaleFor(learned, from: from.metrics, to: to.metrics);
          expect(
            textHeightAt(to.metrics, converted),
            closeTo(textHeightAt(from.metrics, learned), 0.001),
            reason: '$from -> $to',
          );
        }
      }
    });

    test('an unstretched row stays unstretched, whatever the rung', () {
      // No OS text scale in play is the common case; a conversion that drifted
      // off 1.0 would put every board slightly wrong for the majority of users.
      for (final from in LayoutDensity.values) {
        for (final to in LayoutDensity.values) {
          expect(spotRowScaleFor(1.0, from: from.metrics, to: to.metrics), closeTo(1.0, 0.001));
        }
      }
    });

    test('a tighter rung needs a LARGER scale for the same stretch', () {
      // The fixed spacing shrinks while the stretched text does not, so the
      // stretch is a bigger share of a denser row. Getting this backwards
      // would double the error instead of removing it.
      expect(
        spotRowScaleFor(1.158, from: LayoutMetrics.normal, to: LayoutMetrics.densest),
        greaterThan(1.158),
      );
      expect(
        spotRowScaleFor(1.158, from: LayoutMetrics.normal, to: LayoutMetrics.sparsest),
        lessThan(1.158),
      );
    });
  });

  group('spotScrollTarget', () {
    // Viewport 300 tall, scrolled to 100, so 100..400 is on screen.
    double? target(double top, double bottom, {double pixels = 100, double maxExtent = 1000}) =>
        spotScrollTarget(
          top: top,
          bottom: bottom,
          pixels: pixels,
          viewport: 300,
          minExtent: 0,
          maxExtent: maxExtent,
        );

    // The contract the whole feature rests on: a spot already in front of the
    // operator must not move. Without it every keystroke that resolves to a
    // visible row jerks the list, which is worse than not scrolling at all.
    test('a span already fully on screen does not move', () {
      expect(target(150, 190), isNull, reason: 'comfortably inside');
      expect(target(100, 140), isNull, reason: 'flush against the top edge');
      expect(target(360, 400), isNull, reason: 'flush against the bottom edge');
    });

    // Least-move, in both directions: a row above comes to the top edge, a row
    // below comes to the bottom edge — never centred, which would scroll far
    // more than asked.
    test('scrolls only as far as the nearest edge', () {
      expect(target(40, 80), 40, reason: 'above: its top meets the viewport top');
      expect(target(500, 540), closeTo(240, 0.001), reason: 'below: its bottom meets the viewport bottom');
    });

    // A row past the end of the scrollable range: the clamp keeps the offset
    // legal rather than handing the controller something it would reject.
    test('clamps to the scrollable range', () {
      expect(target(2000, 2040, maxExtent: 500), 500);
      expect(target(-50, -10), 0);
    });

    // Sub-pixel moves read as jitter, not as a reveal.
    test('a move under half a pixel is not worth making', () {
      expect(target(99.7, 139.7), isNull);
    });
  });

  group('spotIsCurrentQso', () {
    test('matches the call being logged, whatever case it was spotted in', () {
      expect(spotIsCurrentQso(_spot('k1abc'), currentCall: 'K1ABC'), isTrue);
    });

    // A merged multi-op spot is one row for several stations (see
    // mergeSpotsByFreqAndRefs). Reading `their.call` as one string would leave
    // the row dark for everyone but whoever happened to be merged first.
    test('matches any operator on a merged multi-op spot', () {
      expect(spotIsCurrentQso(_spot('K1ABC,W2DEF'), currentCall: 'W2DEF'), isTrue);
    });

    // The whole point of the highlight is "this is the station you are about to
    // work". W1AW/P is a different station on a different rig, and lighting its
    // row up while W1AW is being typed points at the wrong frequency.
    test('does not match a portable suffix, in either direction', () {
      expect(spotIsCurrentQso(_spot('W1AW/P'), currentCall: 'W1AW'), isFalse);
      expect(spotIsCurrentQso(_spot('W1AW'), currentCall: 'W1AW/P'), isFalse);
    });

    // Nothing is being logged: no call-info at all, or a spot with no call.
    // Both must leave the list untouched rather than lighting up everything
    // whose call is likewise absent.
    test('nothing matches when there is no call on one side or the other', () {
      expect(spotIsCurrentQso(_spot('K1ABC'), currentCall: null), isFalse);
      expect(spotIsCurrentQso(_spot('K1ABC'), currentCall: ''), isFalse);
      expect(spotIsCurrentQso(_spot(''), currentCall: 'K1ABC'), isFalse);
    });
  });

  group('currentQsoHighlight', () {
    for (final brightness in Brightness.values) {
      final name = brightness.name;
      final scheme = buildHaLoTheme(brightness).colorScheme;

      // The same new-vs-editing accent LoggingControls swaps its own panel
      // background between, and the map its highlight marker: a spots list that
      // stayed orange while the logging panel went blue would be telling the
      // operator they are composing a QSO they are actually editing.
      test('$name: composing reads as tertiary, editing as secondary', () {
        final composing = currentQsoHighlight(scheme, editing: false);
        final editing = currentQsoHighlight(scheme, editing: true);
        expect(composing, isNot(editing));
        expect(
          _strengthOf(composing, surface: scheme.surface, container: scheme.tertiaryContainer),
          closeTo(0.5, 0.01),
        );
        expect(
          _strengthOf(editing, surface: scheme.surface, container: scheme.secondaryContainer),
          closeTo(0.5, 0.01),
        );
      });

      // The row is an ECHO of the logging panel, and has to stay the quieter of
      // the two in both brightnesses. Lightening in HSL would satisfy the word
      // "lighter" and fail this in dark mode, where the container is the darker
      // colour and anything lighter than it is louder.
      test('$name: the tint sits between the list surface and the panel fill', () {
        for (final editing in [false, true]) {
          final tint = currentQsoHighlight(scheme, editing: editing);
          final container = editing ? scheme.secondaryContainer : scheme.tertiaryContainer;
          for (final channel in [
            (tint.r, scheme.surface.r, container.r),
            (tint.g, scheme.surface.g, container.g),
            (tint.b, scheme.surface.b, container.b),
          ]) {
            final (value, surface, fill) = channel;
            expect(value, inInclusiveRange(surface < fill ? surface : fill, surface < fill ? fill : surface));
          }
        }
      });
    }
  });
}
