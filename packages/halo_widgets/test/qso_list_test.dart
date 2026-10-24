// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

/// A real OS accessibility text-scale curve can be non-linear — unlike
/// `TextScaler.linear`, which multiplies every font size by the identical
/// factor and so can't distinguish "measured the row's own font sizes" from
/// "sampled the curve at an arbitrary reference size" (both read the same
/// ratio under a linear scaler). This flattens above the sizes any row
/// actually paints at, so a fix that samples at the wrong size reads no
/// growth at all while the row's real text keeps growing.
class _FlattensAboveRowSizes extends TextScaler {
  const _FlattensAboveRowSizes();

  @override
  double scale(double fontSize) => fontSize <= 20 ? fontSize * 1.4 : fontSize;

  @override
  double get textScaleFactor => 1.4;
}

void main() {
  late HaLoDatabase db;
  late OperationsRepository operations;
  late QsosRepository qsos;

  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
    operations = OperationsRepository(db);
    qsos = QsosRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  // An empty log only warrants a warning when the VFO actually needs
  // attention — the same signal that opens the Radio control on mount
  // (HALO-24). A band picked by hand (no frequency) or a frequency with no
  // band already satisfies that check, so an operator who has answered it
  // shouldn't be told to double-check something that's already correct.
  group('the empty state', () {
    testWidgets('reads as an ordinary empty log by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: QsoList(qsos: const [], onSelect: (_) {}),
            ),
          ),
        ),
      );

      expect(find.text('No QSOs yet — work someone!'), findsOneWidget);
      expect(find.textContaining('band and mode'), findsNothing);
    });

    testWidgets('warns to check band and mode when needsBandOrMode is set', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: QsoList(qsos: const [], onSelect: (_) {}, needsBandOrMode: true),
            ),
          ),
        ),
      );

      expect(find.text('Please make sure your band and mode are correct'), findsOneWidget);
      expect(find.textContaining('work someone'), findsNothing);
    });

    // The app's other empty-list messages (spots, activities, search) stay in
    // the dimmed `outline` — they mean "nothing here". The warning is a
    // check-the-radio message, so it takes the same red every other warning
    // in the app uses; the ordinary text stays dimmed like its siblings.
    testWidgets('only the warning is styled red, not the ordinary empty text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: QsoList(qsos: const [], onSelect: (_) {}),
            ),
          ),
        ),
      );
      final scheme = Theme.of(tester.element(find.byType(QsoList))).colorScheme;
      final dimmed = tester.widget<Text>(find.text('No QSOs yet — work someone!'));
      expect(dimmed.style?.color, scheme.outline);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: QsoList(qsos: const [], onSelect: (_) {}, needsBandOrMode: true),
            ),
          ),
        ),
      );
      final warning = tester.widget<Text>(find.text('Please make sure your band and mode are correct'));
      expect(warning.style?.color, scheme.error);
    });

    testWidgets('uses the supplied labels when the app passes translated ones', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: QsoList(
                qsos: const [],
                onSelect: (_) {},
                needsBandOrMode: true,
                noQsosLabel: 'Aún no hay QSOs — ¡haz un contacto!',
                bandOrModeWarningLabel: 'Verifica que tu banda y modo sean correctos',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Verifica que tu banda y modo sean correctos'), findsOneWidget);
    });
  });

  group('revealing the selected row (APP-19)', () {
    // Keyboard navigation walks the log one row at a time, selecting each
    // without moving focus — so the list itself has to follow the selection.
    // These cover the three outcomes that matter: follow it as the walk
    // leaves the viewport, hold still when it hasn't, and — the one a naive
    // `ensureVisible` gets wrong — keep the row clear of the PINNED day
    // header rather than tucking it underneath.
    //
    // Every case walks one row at a time, because that is the only motion the
    // reveal supports: a row far outside the viewport isn't built at all, so
    // there is nothing to scroll to. Jumping to an arbitrary row is what the
    // "goto" search still has to solve — see docs/backlog.md.

    /// [count] QSOs, all on the same UTC day (so there is exactly one day
    /// header) unless [oncePerDay], which gives every row its own.
    Future<List<Qso>> buildLog(Operation operation, int count, {bool oncePerDay = false}) async {
      final list = <Qso>[];
      for (var i = 1; i <= count; i++) {
        list.add(
          await qsos.add(operation.uuid, {
            'their': {'call': 'K${i}HAM'},
            'band': '20m',
            'mode': 'SSB',
            'startAtMillis': oncePerDay ? i * 86400000 : 1000 + i * 60000,
          }),
        );
      }
      return list;
    }

    Widget hostWith(List<Qso> list, String? selectedUuid) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 300,
          child: QsoList(qsos: list, selectedUuid: selectedUuid, onSelect: (_) {}),
        ),
      ),
    );

    double offsetOf(WidgetTester tester) => tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!.offset;

    testWidgets('follows the selection as a walk leaves the top of the viewport', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final list = await buildLog(operation, 40);

      await tester.pumpWidget(hostWith(list, null));
      await tester.pumpAndSettle();

      // Walk up from the newest, one row per press, and check the list keeps
      // up: the moment the walk passes the top of the viewport, every further
      // step has to scroll or the operator is selecting rows they can't see.
      var scrolled = false;
      for (var step = 1; step <= 15; step++) {
        final target = list[list.length - 1 - step];
        final before = offsetOf(tester);
        await tester.pumpWidget(hostWith(list, target.uuid));
        await tester.pumpAndSettle();
        if (offsetOf(tester) < before) scrolled = true;
        expect(find.text(target.theirCall), findsOneWidget, reason: 'step $step of the walk left its row off screen');
      }
      expect(scrolled, isTrue, reason: 'a 15-row walk must have scrolled the list at some point');
    });

    testWidgets('follows the selection back down again', (tester) async {
      // The direction the first version got wrong, and hand-testing caught:
      // `getOffsetToReveal(box, 1.0)` comes back one header-height short with
      // this list's pinned/grouped slivers, so every downward step scrolled
      // one row less than it needed and the walk fell permanently one row
      // behind — the selected row sat just under the bottom edge, invisible,
      // for the whole way down. Walking up first is what makes room to walk
      // back down at all.
      final operation = await operations.create(stationCall: 'KI2D');
      final list = await buildLog(operation, 40);

      await tester.pumpWidget(hostWith(list, null));
      await tester.pumpAndSettle();
      for (var step = 1; step <= 15; step++) {
        await tester.pumpWidget(hostWith(list, list[list.length - 1 - step].uuid));
        await tester.pumpAndSettle();
      }

      for (var step = 14; step >= 0; step--) {
        final target = list[list.length - 1 - step];
        await tester.pumpWidget(hostWith(list, target.uuid));
        await tester.pumpAndSettle();
        expect(find.text(target.theirCall), findsOneWidget, reason: 'step $step of the walk back down left its row off screen');
      }
    });

    testWidgets('jumps to a selection nowhere near the viewport', (tester) async {
      // Page Up/Down and Home/End (APP-19) move the selection past everything
      // the list has rendered, so there is no row to measure — the reveal has
      // to estimate where it is, jump, and place it once it exists. Without
      // that the operator pages through a log that never moves.
      final operation = await operations.create(stationCall: 'KI2D');
      final list = await buildLog(operation, 200);

      await tester.pumpWidget(hostWith(list, null));
      await tester.pumpAndSettle();
      expect(find.text('K1HAM'), findsNothing, reason: 'the list opens at the newest');

      // Home, from the far end of a 200-QSO log.
      await tester.pumpWidget(hostWith(list, list.first.uuid));
      await tester.pumpAndSettle();
      expect(find.text('K1HAM'), findsOneWidget);
      expect(offsetOf(tester), 0, reason: 'the oldest contact is the top of the list');

      // …and End, back the whole way.
      await tester.pumpWidget(hostWith(list, list.last.uuid));
      await tester.pumpAndSettle();
      expect(find.text('K200HAM'), findsOneWidget);
    });

    testWidgets('a row does not overflow its fixed slot at an OS text scale above 1.0 (HALO-209)', (tester) async {
      // Every row sits in a fixed-extent sliver slot (HALO-258), which
      // `RenderSliverFixedExtentList` enforces on the ACTUAL rendered
      // geometry, not just on the arithmetic that estimates a reveal's
      // scroll offset — so unlike the pre-fixed-extent bug this card
      // originally described, scroll math can no longer drift from where a
      // row actually paints; both read the same `_rowHeightScale`. What can
      // still go wrong is the opposite direction: if that shared scale
      // doesn't grow enough for the OS accessibility text-scale preference
      // (ui-scaling.md §3, composes independently of the app's own Font
      // Scale), the row's real text overflows the now-rigid slot instead of
      // the slot growing to fit it, the way an unconstrained row used to.
      final operation = await operations.create(stationCall: 'KI2D');
      final list = await buildLog(operation, 2);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: hostWith(list, null),
        ),
      );
      await tester.pumpAndSettle();

      // The pitch between rows is exactly the slot each one sits in — see
      // 'consecutive rows sit exactly one row-height apart'. It has to have
      // actually grown past the unscaled declared height (proving the OS
      // scale was applied at all, not just coincidentally sufficient), and
      // the row's own text has to fit inside it (proving it grew enough).
      final pitch = tester.getTopLeft(find.bySemanticsIdentifier('qso.row.K2HAM')).dy - tester.getTopLeft(find.bySemanticsIdentifier('qso.row.K1HAM')).dy;
      final declared = QsoList.rowHeightOf(tester.element(find.byType(QsoList)));
      expect(pitch, greaterThan(declared), reason: 'the slot never grew for the OS text scale');

      final textHeight = tester.getSize(find.text('K1HAM')).height;
      expect(textHeight, lessThanOrEqualTo(pitch), reason: "the row's own text overflowed its slot");
    });

    testWidgets('an annotation row does not overflow its slot at an OS text scale above 1.0 (HALO-209)', (tester) async {
      // AnnotationRow's description uses bodyMedium unmodified — Material 3's
      // 1.43x line-height multiplier, meant for prose, unlike the plain row's
      // `haloMonoStyle` (no explicit `height`) that the previous test's slot
      // was calibrated against. A scale that only measured the mono style
      // would under-provision the ONE slot every row kind shares.
      final operation = await operations.create(stationCall: 'KI2D');
      final qso1 = await qsos.add(operation.uuid, {
        'their': {'call': 'K1HAM'},
        'band': '20m',
        'mode': 'SSB',
        'startAtMillis': 1000,
      });
      final note = await qsos.add(operation.uuid, {
        'band': 'event',
        'freq': 0,
        'mode': 'note',
        'startAtMillis': 2000,
        'our': {'call': 'EVENT'},
        'their': {'call': 'NOTE'},
        'event': {'event': 'note', 'note': 'A note long enough to take a row of its own'},
      });
      final qso2 = await qsos.add(operation.uuid, {
        'their': {'call': 'K2HAM'},
        'band': '20m',
        'mode': 'SSB',
        'startAtMillis': 3000,
      });

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: hostWith([qso1, note, qso2], null),
        ),
      );
      await tester.pumpAndSettle();

      // The pitch between the two QSO rows spans the annotation row between
      // them too — divide by two rows' worth to get one slot's real height.
      final slot = (tester.getTopLeft(find.bySemanticsIdentifier('qso.row.K2HAM')).dy - tester.getTopLeft(find.bySemanticsIdentifier('qso.row.K1HAM')).dy) / 2;
      final noteHeight = tester.getSize(find.text('A note long enough to take a row of its own')).height;
      expect(noteHeight, lessThanOrEqualTo(slot), reason: "the annotation row's text overflowed its slot");
    });

    testWidgets('a row does not overflow under a non-linear OS text-scale curve (HALO-209)', (tester) async {
      // `TextScaler.linear` — every other test in this file — multiplies
      // every font size by the identical factor, so it can't tell "measured
      // at the row's own font sizes" apart from "sampled an arbitrary
      // reference size": both read the same ratio under it. A real OS
      // accessibility curve isn't guaranteed linear; [_FlattensAboveRowSizes]
      // is the shape that broke the fix this replaced (which sampled
      // `scaler.scale(100) / 100` — flat here, reading NO growth at all).
      final operation = await operations.create(stationCall: 'KI2D');
      final list = await buildLog(operation, 2);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: _FlattensAboveRowSizes()),
          child: hostWith(list, null),
        ),
      );
      await tester.pumpAndSettle();

      final pitch = tester.getTopLeft(find.bySemanticsIdentifier('qso.row.K2HAM')).dy - tester.getTopLeft(find.bySemanticsIdentifier('qso.row.K1HAM')).dy;
      final declared = QsoList.rowHeightOf(tester.element(find.byType(QsoList)));
      expect(pitch, greaterThan(declared), reason: 'the slot never grew under the curve');

      final textHeight = tester.getSize(find.text('K1HAM')).height;
      expect(textHeight, lessThanOrEqualTo(pitch), reason: "the row's own text overflowed its slot");
    });

    testWidgets('a jump lands the row fully on screen, clear of the pinned header', (tester) async {
      // The estimate gets the row built; the measured reveal is what actually
      // places it. Same invariant the walk holds, over a distance no walk
      // could cover.
      final operation = await operations.create(stationCall: 'KI2D');
      final list = await buildLog(operation, 60, oncePerDay: true);

      await tester.pumpWidget(hostWith(list, null));
      await tester.pumpAndSettle();

      final viewport = tester.getRect(find.byType(CustomScrollView));
      for (final target in [list[10], list[45], list[3], list[58]]) {
        await tester.pumpWidget(hostWith(list, target.uuid));
        await tester.pumpAndSettle();
        expect(find.text(target.theirCall), findsOneWidget, reason: 'jumped to ${target.theirCall}');
        final row = tester.getRect(find.text(target.theirCall));
        expect(row.top, greaterThanOrEqualTo(viewport.top + LayoutMetrics.normal.sectionHeaderHeight));
        expect(row.bottom, lessThanOrEqualTo(viewport.bottom));
      }
    });

    testWidgets('still lands on the row in a log full of taller annotation rows', (tester) async {
      // The arithmetic counts every entry as an ordinary row, so a log salted
      // with notes drifts — that's what the measured correction pass is for.
      // Without one, a jump over a hundred entries lands somewhere near the
      // row rather than on it.
      final operation = await operations.create(stationCall: 'KI2D');
      final list = <Qso>[];
      for (var i = 1; i <= 120; i++) {
        list.add(
          await qsos.add(operation.uuid, {
            'their': {'call': 'K${i}HAM'},
            'band': '20m',
            'mode': 'SSB',
            'startAtMillis': 1000 + i * 60000,
          }),
        );
        if (i % 3 == 0) {
          list.add(
            await qsos.add(operation.uuid, {
              'band': 'event',
              'freq': 0,
              'mode': 'note',
              'startAtMillis': 1000 + i * 60000 + 1,
              'our': {'call': 'EVENT'},
              'their': {'call': 'NOTE'},
              'event': {'event': 'note', 'note': 'A note long enough to take a row of its own'},
            }),
          );
        }
      }

      await tester.pumpWidget(hostWith(list, null));
      await tester.pumpAndSettle();

      final viewport = tester.getRect(find.byType(CustomScrollView));
      for (final target in [list.first, list[80], list[20]]) {
        await tester.pumpWidget(hostWith(list, target.uuid));
        await tester.pumpAndSettle();
        expect(find.text(target.theirCall), findsOneWidget, reason: 'jumped to ${target.theirCall}');
        final row = tester.getRect(find.text(target.theirCall));
        expect(row.top, greaterThanOrEqualTo(viewport.top + LayoutMetrics.normal.sectionHeaderHeight));
        expect(row.bottom, lessThanOrEqualTo(viewport.bottom));
      }
    });

    testWidgets('leaves an already-visible selection alone', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final list = await buildLog(operation, 40);

      await tester.pumpWidget(hostWith(list, null));
      await tester.pumpAndSettle();
      final before = offsetOf(tester);
      expect(find.text('K40HAM'), findsOneWidget, reason: 'the newest row is on screen at rest');

      // Selecting it with a tap must not jerk the list out from under the
      // pointer — only a row that ISN'T fully visible earns a scroll.
      await tester.pumpWidget(hostWith(list, list.last.uuid));
      await tester.pumpAndSettle();

      expect(offsetOf(tester), before);
    });

    testWidgets('holds the selected row clear of the pinned day headers', (tester) async {
      // One QSO per day, so the row being revealed always has headers pinned
      // directly above it. `getOffsetToReveal` accounts for them, so this
      // passes today — it is here to keep it that way: a reveal rewritten to
      // guess an offset (`jumpTo(index * rowHeight)`, say, which is the shape
      // the "goto" search will want) would put the selected row behind the
      // header and this is what would notice.
      final operation = await operations.create(stationCall: 'KI2D');
      final list = await buildLog(operation, 20, oncePerDay: true);

      await tester.pumpWidget(hostWith(list, null));
      await tester.pumpAndSettle();

      final viewport = tester.getRect(find.byType(CustomScrollView));
      for (var step = 1; step <= 10; step++) {
        final target = list[list.length - 1 - step];
        await tester.pumpWidget(hostWith(list, target.uuid));
        await tester.pumpAndSettle();
        final row = tester.getRect(find.text(target.theirCall));
        expect(row.top, greaterThanOrEqualTo(viewport.top + LayoutMetrics.normal.sectionHeaderHeight), reason: 'step $step put the row behind a pinned header');
        expect(row.bottom, lessThanOrEqualTo(viewport.bottom));
      }
    });
  });

  testWidgets('each QSO row carries a stable qso.row.<call> semantics identifier (#236)', (tester) async {
    // These translation-independent hooks are what let agent/browser tooling
    // target a specific logged QSO's row without a bridge call — so a
    // regression that drops or renames them must fail here.
    final handle = tester.ensureSemantics();
    final operation = await operations.create(stationCall: 'KI2D');
    final w1aw = await qsos.add(operation.uuid, {
      'their': {'call': 'W1AW'},
      'mode': 'SSB',
      'startAtMillis': 1000,
    });
    final k2ham = await qsos.add(operation.uuid, {
      'their': {'call': 'K2HAM'},
      'mode': 'SSB',
      'startAtMillis': 2000,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QsoList(qsos: [w1aw, k2ham], onSelect: (_) {}),
        ),
      ),
    );

    expect(find.bySemanticsIdentifier('qso.row.W1AW'), findsOneWidget);
    expect(find.bySemanticsIdentifier('qso.row.K2HAM'), findsOneWidget);
    handle.dispose();
  });

  // The freq/band column is the log's only record of where a contact was
  // worked, and a wrong one is discovered long after the station is gone.
  // These assert the COLOR, not just the text: a '???' painted in the
  // ordinary row color is exactly the miss they exist to catch.
  group('a QSO with no band reads as an error', () {
    testWidgets('neither frequency nor band shows ??? in the error color', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'mode': 'SSB',
        'startAtMillis': 1000,
      });
      final theme = buildHaLoTheme(Brightness.light);

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: QsoList(qsos: [qso], onSelect: (_) {}),
          ),
        ),
      );

      expect(tester.widget<Text>(find.text('???')).style?.color, theme.colorScheme.error);
    });

    testWidgets('a frequency outside every ham band paints red', (tester) async {
      // 5000 kHz is WWV, not an amateur allocation — the stored band field
      // is deliberately absent, but even a present one must not vouch for a
      // frequency the band plan disowns.
      expect(bandForFrequency(5000), isNull, reason: 'fixture assumes 5000 kHz is not a ham band');
      final operation = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'freq': 5000.0,
        'mode': 'SSB',
        'startAtMillis': 1000,
      });
      final theme = buildHaLoTheme(Brightness.light);

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: QsoList(qsos: [qso], onSelect: (_) {}),
          ),
        ),
      );

      // The MHz group of the frequency — the whole reading is styled as one,
      // so one part settles it.
      expect(tester.widget<Text>(find.text('5')).style?.color, theme.colorScheme.error);
    });

    testWidgets('an in-band frequency keeps the ordinary row color', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'freq': 14074.0,
        'mode': 'FT8',
        'startAtMillis': 1000,
      });
      final theme = buildHaLoTheme(Brightness.light);

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: QsoList(qsos: [qso], onSelect: (_) {}),
          ),
        ),
      );

      expect(tester.widget<Text>(find.text('14')).style?.color, isNot(theme.colorScheme.error));
      expect(find.text('???'), findsNothing);
    });
  });

  // An incomplete call scores nothing until it is fixed, and nothing but the
  // list leads the operator back to it — a `?` in the ordinary call color is
  // easy to scroll past.
  testWidgets('an incomplete call is painted orange, selected or not, and a complete one is not', (tester) async {
    final operation = await operations.create(stationCall: 'KI2D');
    final incomplete = await qsos.add(operation.uuid, {
      'their': {'call': 'K1A?C'},
      'band': '20m',
      'mode': 'SSB',
      'startAtMillis': 1000,
    });
    final complete = await qsos.add(operation.uuid, {
      'their': {'call': 'W1AW'},
      'band': '20m',
      'mode': 'SSB',
      'startAtMillis': 2000,
    });
    final theme = buildHaLoTheme(Brightness.light);

    Future<void> pumpList({String? selectedUuid}) => tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: QsoList(qsos: [incomplete, complete], selectedUuid: selectedUuid, onSelect: (_) {}),
        ),
      ),
    );

    await pumpList();
    expect(tester.widget<Text>(find.text('K1A?C')).style?.color, theme.colorScheme.tertiary);
    expect(tester.widget<Text>(find.text('W1AW')).style?.color, isNot(theme.colorScheme.tertiary));

    await pumpList(selectedUuid: incomplete.uuid);
    expect(tester.widget<Text>(find.text('K1A?C')).style?.color, theme.colorScheme.tertiary);
  });

  testWidgets('newest QSO renders at the bottom, next to the logging panel', (tester) async {
    final operation = await operations.create(stationCall: 'KI2D');
    final first = await qsos.add(operation.uuid, {
      'their': {'call': 'W1AW'},
      'band': '20m',
      'mode': 'SSB',
      'startAtMillis': 1000,
    });
    final second = await qsos.add(operation.uuid, {
      'their': {'call': 'K2HAM'},
      'band': '40m',
      'mode': 'CW',
      'startAtMillis': 2000,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QsoList(qsos: [first, second], onSelect: (_) {}),
        ),
      ),
    );

    // The newer QSO (K2HAM) must be visually BELOW the older one (W1AW) —
    // reverse:true plus oldest-first input previously put the oldest QSO
    // at the bottom, the opposite of the intended contest-logger layout.
    final firstY = tester.getCenter(find.text('W1AW')).dy;
    final secondY = tester.getCenter(find.text('K2HAM')).dy;
    expect(secondY, greaterThan(firstY));

    // Row numbers stay chronological (1 = first QSO logged) regardless of
    // where each row renders.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('consecutive rows sit exactly one row-height apart, not Material\'s default 16px-tall divider spacer', (tester) async {
    // Every row is forced into a fixed-height sliver slot (HALO-258, so
    // `jumpTo` can compute maxScrollExtent as itemExtent * count instead of
    // laying out every row to find it) — the hairline divider is now
    // painted as part of that slot rather than taking a spacer slot of its
    // own, so the pitch between rows must equal the row height exactly.
    final operation = await operations.create(stationCall: 'KI2D');
    final first = await qsos.add(operation.uuid, {
      'their': {'call': 'W1AW'},
      'mode': 'SSB',
      'startAtMillis': 1000,
    });
    final second = await qsos.add(operation.uuid, {
      'their': {'call': 'K2HAM'},
      'mode': 'SSB',
      'startAtMillis': 2000,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QsoList(qsos: [first, second], onSelect: (_) {}),
        ),
      ),
    );

    final pitch = tester.getTopLeft(find.bySemanticsIdentifier('qso.row.K2HAM')).dy - tester.getTopLeft(find.bySemanticsIdentifier('qso.row.W1AW')).dy;
    expect(pitch, QsoList.rowHeightOf(tester.element(find.byType(QsoList))));
  });

  testWidgets("a segment row shows its stored description, the way polo's rows read", (tester) async {
    // "for ARRL 10G Sep • at FN20rm" is what the row carries from the app
    // that wrote it — the list has no wording of its own to fall back on, so
    // a row that lost its description would go silently blank.
    final operation = await operations.create(stationCall: 'KI2D');
    final brk = await qsos.addEvent(operation.uuid, kind: 'break', atMillis: 1500, operation: {'grid': 'FN20rm'}, description: 'for ARRL 10G Sep • at FN20rm');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QsoList(qsos: [brk], onSelect: (_) {}),
        ),
      ),
    );

    expect(find.text('for ARRL 10G Sep • at FN20rm'), findsOneWidget);
  });

  testWidgets("a row with no description falls back to its override's square, and one with neither shows its mark alone", (tester) async {
    // A row written while the extension host was down carries no
    // description, and the list has no wording of its own — without this
    // fallback the operator gets an unexplained blank line in the log.
    final operation = await operations.create(stationCall: 'KI2D');
    final withGrid = await qsos.addEvent(operation.uuid, kind: 'break', atMillis: 1000, operation: {'grid': 'FN20rm', 'refs': null});
    final withNothing = await qsos.addEvent(operation.uuid, kind: 'break', atMillis: 2000, operation: {'grid': null, 'refs': null});

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QsoList(qsos: [withGrid, withNothing], onSelect: (_) {}),
        ),
      ),
    );

    expect(find.text('FN20rm'), findsOneWidget);
    expect(find.byType(EventRow), findsNWidgets(2));
    // No invented wording for the one that has nothing to say.
    expect(find.textContaining('Break'), findsNothing);
  });

  testWidgets('a stop row renders as the operation-ended marker, like end', (tester) async {
    // `stop` is the kind polo's STOP command writes (and HaLo's now does);
    // `end` is what the list was built for. A `stop` falling through to the
    // annotation row would show a synced polo log's end as a yellow note.
    final operation = await operations.create(stationCall: 'KI2D');
    final first = await qsos.add(operation.uuid, {
      'their': {'call': 'W1AW'},
      'band': '20m',
      'mode': 'SSB',
      'startAtMillis': 1000,
    });
    final stop = await qsos.addEvent(operation.uuid, kind: 'stop', atMillis: 1500, description: 'at FN31pr');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QsoList(qsos: [first, stop], onSelect: (_) {}),
        ),
      ),
    );

    expect(find.byType(EventRow), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Icon && w.icon == MdiIcons.stopCircle), findsOneWidget);
    expect(find.text('at FN31pr'), findsOneWidget);
    expect(find.byType(AnnotationRow), findsNothing);
  });

  testWidgets('event markers render distinctly and are excluded from QSO numbering', (tester) async {
    final operation = await operations.create(stationCall: 'KI2D');
    final start = await qsos.addEvent(operation.uuid, kind: 'start', atMillis: 500, description: 'at FN31pr');
    final first = await qsos.add(operation.uuid, {
      'their': {'call': 'W1AW'},
      'band': '20m',
      'mode': 'SSB',
      'startAtMillis': 1000,
    });
    final brk = await qsos.addEvent(operation.uuid, kind: 'break', atMillis: 1500, description: 'at FN20aa');
    final second = await qsos.add(operation.uuid, {
      'their': {'call': 'K2HAM'},
      'band': '40m',
      'mode': 'CW',
      'startAtMillis': 2000,
    });

    Qso? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QsoList(qsos: [start, first, brk, second], onSelect: (_) {}, onSelectEvent: (qso) => tapped = qso),
        ),
      ),
    );

    expect(find.text('at FN31pr'), findsOneWidget);
    expect(find.text('at FN20aa'), findsOneWidget);
    // Real QSOs still number 1 and 2 — events don't consume a number.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text('at FN20aa'));
    expect(tapped?.uuid, brk.uuid);
  });

  testWidgets('the day header is the operation\'s own tap target', (tester) async {
    final operation = await operations.create(stationCall: 'KI2D');
    final qso = await qsos.add(operation.uuid, {
      'their': {'call': 'W1AW'},
      'band': '20m',
      'mode': 'SSB',
      'startAtMillis': 1000,
    });

    var headerTaps = 0;
    Qso? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QsoList(qsos: [qso], onSelect: (q) => selected = q, onTapDayHeader: () => headerTaps++),
        ),
      ),
    );

    await tester.tap(find.byType(DayHeaderRow));
    expect(headerTaps, 1);
    // The header is not a row: a tap on it must never load a QSO into the
    // editor, whichever QSO happens to sit under it.
    expect(selected, isNull);
  });

  group('annotation rows (note/todo/solar/weather events, ham2k/halo-dist#64)', () {
    // The event pseudo-QSO shape the annotation-commands extension emits
    // through its `addQso` action.
    Future<Qso> addAnnotation(
      String operationUuid,
      String kind, {
      String? note,
      String? description,
      String? icon,
      Map<String, dynamic>? data,
      int atMillis = 1500,
    }) {
      return qsos.add(operationUuid, {
        'band': 'event',
        'freq': 0,
        'mode': kind,
        'startAtMillis': atMillis,
        'our': {'call': 'EVENT'},
        'their': {'call': kind.toUpperCase()},
        'event': {'event': kind, 'icon': ?icon, 'note': ?note, 'description': ?description, 'data': ?data},
      });
    }

    testWidgets('a note shows its text on a yellow row, keeps the time column, and consumes no QSO number', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final first = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'SSB',
        'startAtMillis': 1000,
      });
      final note = await addAnnotation(operation.uuid, 'note', note: 'THIS IS WHEN THE COPS SHOWED UP', icon: 'sticker-text-outline', atMillis: 1500);
      final second = await qsos.add(operation.uuid, {
        'their': {'call': 'K2HAM'},
        'band': '20m',
        'mode': 'SSB',
        'startAtMillis': 2000,
      });

      Qso? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(qsos: [first, note, second], onSelect: (_) {}, onSelectEvent: (qso) => tapped = qso),
          ),
        ),
      );

      expect(find.text('THIS IS WHEN THE COPS SHOWED UP'), findsOneWidget);
      // Timeline entry, not a centered marker: the annotation keeps the
      // QSO rows' HH:MMz time column (1500ms UTC → 00:00z, same as the
      // neighboring rows' format).
      expect(find.descendant(of: find.byType(AnnotationRow), matching: find.text('00:00z')), findsOneWidget);
      // Real QSOs still number 1 and 2 — annotations don't consume one.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // app-polo's eventRow yellow, blended over the surface at light-mode
      // opacity — the "sticky note" treatment the styling is ported from.
      final material = tester.widget<Material>(find.descendant(of: find.byType(AnnotationRow), matching: find.byType(Material)));
      final theme = Theme.of(tester.element(find.byType(AnnotationRow)));
      expect(material.color, Color.alphaBlend(const Color(0xFFFCF4A7).withValues(alpha: 0.85), theme.colorScheme.surface));

      await tester.tap(find.text('THIS IS WHEN THE COPS SHOWED UP'));
      expect(tapped?.uuid, note.uuid);
    });

    testWidgets('solar/weather annotations show their description line', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final solar = await addAnnotation(operation.uuid, 'solar', description: '🟡SFI 117 • 🟢A 14 • 🟢K 1 • 😎SN 60', icon: 'sun-wireless');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(qsos: [solar], onSelect: (_) {}),
          ),
        ),
      );

      expect(find.text('🟡SFI 117 • 🟢A 14 • 🟢K 1 • 😎SN 60'), findsOneWidget);
      final icon = tester.widget<Icon>(find.descendant(of: find.byType(AnnotationRow), matching: find.byType(Icon)));
      expect(icon.icon, MdiIcons.sunWireless);
    });

    testWidgets('a todo\'s icon tracks its done state, not the stored icon', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final pending = await addAnnotation(operation.uuid, 'todo', note: 'FIX THIS CALL', icon: 'sticker-outline', data: {'done': false}, atMillis: 1000);
      final done = await addAnnotation(operation.uuid, 'todo', note: 'ALREADY HANDLED', icon: 'sticker-outline', data: {'done': true}, atMillis: 2000);
      // app-polo's older todo shape keeps `done` directly on the event, not
      // under `data` — synced logs contain it, and app-polo itself reads
      // both (`data.done ?? done`).
      final legacyDone = await qsos.add(operation.uuid, {
        'band': 'event',
        'startAtMillis': 3000,
        'event': {'event': 'todo', 'note': 'LEGACY SHAPE', 'done': true},
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(qsos: [pending, done, legacyDone], onSelect: (_) {}),
          ),
        ),
      );

      final icons = tester.widgetList<Icon>(find.descendant(of: find.byType(AnnotationRow), matching: find.byType(Icon))).toList();
      expect(icons[0].icon, MdiIcons.sticker);
      expect(icons[1].icon, MdiIcons.stickerCheckOutline);
      expect(icons[2].icon, MdiIcons.stickerCheckOutline);
    });
  });

  group('frequency', () {
    testWidgets('splits MHz (bold) / kHz on a thousands mark, with no Hz segment for a whole-kHz frequency', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'freq': 14074,
        'mode': 'FT8',
        'startAtMillis': 1000,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(qsos: [qso], onSelect: (_) {}),
          ),
        ),
      );

      expect(find.text('14'), findsOneWidget);
      expect(find.text('074'), findsOneWidget);
      // The row reads as kHz — `14.074` — so what divides the two parts is
      // the thousands mark. No fractional-kHz precision anywhere in the list,
      // so there is no second mark for a decimal, and never the device's
      // comma.
      expect(find.text('.'), findsOneWidget);
      expect(find.text(','), findsNothing);
    });

    testWidgets('shows the band instead when the QSO has no frequency', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '40m',
        'mode': 'CW',
        'startAtMillis': 1000,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(qsos: [qso], onSelect: (_) {}),
          ),
        ),
      );

      expect(find.text('40m'), findsOneWidget);
    });

    testWidgets('a QSO with neither frequency nor band still reserves the column, so later columns line up (#354)', (tester) async {
      final withFreq = Qso(
        uuid: 'q1',
        operationUuid: 'op-1',
        data: {
          'their': {'call': 'W1AW'},
          'freq': 14074,
          'mode': 'SSB',
          'startAtMillis': 1000,
        },
      );
      // Equal-length callsign, same mode (so no Mode column), but NO freq and
      // NO band — its freq/band cell used to collapse to zero width and pull
      // the callsign left.
      final withNeither = Qso(
        uuid: 'q2',
        operationUuid: 'op-1',
        data: {
          'their': {'call': 'W2AW'},
          'mode': 'SSB',
          'startAtMillis': 2000,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(qsos: [withFreq, withNeither], onSelect: (_) {}),
          ),
        ),
      );

      expect(tester.getTopLeft(find.text('W1AW')).dx, tester.getTopLeft(find.text('W2AW')).dx);
    });
  });

  group('mode column', () {
    testWidgets('hidden when every QSO uses the same mode', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final first = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'freq': 14074,
        'mode': 'SSB',
        'startAtMillis': 1000,
      });
      final second = await qsos.add(operation.uuid, {
        'their': {'call': 'K2HAM'},
        'freq': 14200,
        'mode': 'SSB',
        'startAtMillis': 2000,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(qsos: [first, second], onSelect: (_) {}),
          ),
        ),
      );

      // 'SSB' would otherwise render twice (once per row) if the column showed.
      expect(find.text('SSB'), findsNothing);
    });

    testWidgets('shown when the operation mixes modes', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final first = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'freq': 14074,
        'mode': 'SSB',
        'startAtMillis': 1000,
      });
      final second = await qsos.add(operation.uuid, {
        'their': {'call': 'K2HAM'},
        'freq': 7074,
        'mode': 'CW',
        'startAtMillis': 2000,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(qsos: [first, second], onSelect: (_) {}),
          ),
        ),
      );

      expect(find.text('SSB'), findsOneWidget);
      expect(find.text('CW'), findsOneWidget);
    });
  });

  group('name column', () {
    testWidgets('a noted station leads with its marker emoji, in the emoji font', (tester) async {
      // A ZWJ sequence: rendered outside the bundled emoji font it paints as
      // nothing on web, and the name would read as un-noted.
      final qso = Qso(
        uuid: 'q',
        operationUuid: 'op-1',
        data: {
          'their': {
            'call': 'K1ABC',
            'guess': {'name': 'Alice', 'emoji': '🧑‍💻'},
          },
          'mode': 'SSB',
          'startAtMillis': 1000,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(qsos: [qso], onSelect: (_) {}, ourEntityPrefix: 'K'),
          ),
        ),
      );

      expect(find.text('🧑‍💻'), findsOneWidget);
      expect(tester.widget<Text>(find.text('🧑‍💻')).style?.fontFamily, emojiFontFamily);
      expect(find.textContaining('Alice'), findsOneWidget);
    });

    testWidgets('a station with no marker shows the name alone', (tester) async {
      final qso = Qso(
        uuid: 'q',
        operationUuid: 'op-1',
        data: {
          'their': {'call': 'K1ABC', 'name': 'Alice'},
          'mode': 'SSB',
          'startAtMillis': 1000,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(qsos: [qso], onSelect: (_) {}, ourEntityPrefix: 'K'),
          ),
        ),
      );

      expect(find.text('Alice'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Text && w.style?.fontFamily == emojiFontFamily), findsNothing);
    });
  });

  group('badge column', () {
    Qso noted(String? notes) => Qso(
      uuid: 'q',
      operationUuid: 'op-1',
      data: {
        'our': {'sent': '59'},
        'their': {'call': 'K1ABC', 'name': 'Alice', 'sent': '59'},
        'mode': 'SSB',
        'startAtMillis': 1000,
        'notes': ?notes,
      },
    );

    Future<void> pumpRow(WidgetTester tester, Qso qso, {double width = 800}) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: QsoList(qsos: [qso], onSelect: (_) {}, ourEntityPrefix: 'K'),
            ),
          ),
        ),
      ),
    );

    testWidgets('a QSO with a note wears the notes marker against the signal reports', (tester) async {
      await pumpRow(tester, noted('Met at Dayton'));

      final marker = find.byIcon(MdiIcons.noteOutline);
      expect(marker, findsOneWidget);
      // Right-aligned with the ref badges, not trailing the name: down a log
      // the markers form one column instead of a ragged edge set by each
      // name's length.
      final name = tester.getRect(find.text('Alice'));
      final rst = tester.getRect(find.text('59 59'));
      final box = tester.getRect(marker);
      expect(box.left, greaterThanOrEqualTo(name.right));
      expect(rst.left - box.right, inInclusiveRange(0, 12));
    });

    testWidgets('a QSO without a note, or with a blank one, wears no marker', (tester) async {
      // The Logs edit form saves an untouched notes field as '', so "has a
      // notes key" is not "has a note".
      for (final notes in [null, '', '  \n']) {
        await pumpRow(tester, noted(notes));
        expect(find.byIcon(MdiIcons.noteOutline), findsNothing, reason: 'notes: ${notes == null ? 'absent' : '"$notes"'}');
      }
    });

    testWidgets('a list too narrow for the badge column drops the marker rather than overflow', (tester) async {
      // The marker lives in the refs column and is dropped with it: drawn
      // outside the column plan, it is the one fixed-width child the width
      // budget never counted. The width is found, not chosen — a literal
      // would hold only for today's test font and column samples.
      double? narrowest;
      for (var width = 300.0; width <= 800 && narrowest == null; width += 2) {
        await pumpRow(tester, noted('Met at Dayton'), width: width);
        if (find.byIcon(MdiIcons.noteOutline).evaluate().isNotEmpty) narrowest = width;
      }
      expect(narrowest, isNotNull);
      expect(narrowest, greaterThan(300), reason: 'the search must start below the threshold');

      await pumpRow(tester, noted('Met at Dayton'), width: narrowest! - 2);
      expect(find.byIcon(MdiIcons.noteOutline), findsNothing);
      expect(tester.takeException(), isNull);
    });

    Qso row(String uuid, {bool conflict = false, String? notes}) => Qso(
      uuid: uuid,
      operationUuid: 'op-1',
      data: {
        'our': {'sent': '59'},
        'their': {'call': 'K1ABC', 'name': 'Alice', 'sent': '59'},
        'mode': 'SSB',
        'startAtMillis': 1000,
        'serialConflict': ?(conflict ? true : null),
        'notes': ?notes,
      },
    );

    Future<void> pumpList(WidgetTester tester, List<Qso> qsos, double width) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: QsoList(qsos: qsos, onSelect: (_) {}, ourEntityPrefix: 'K'),
            ),
          ),
        ),
      ),
    );

    testWidgets('marks on different rows share one slot instead of each reserving its own', (tester) async {
      // The column's width is a budget, not a layout: it only decides whether
      // the column FITS. So the observable is the narrowest list that still
      // shows it — which a second kind of mark, on another row, must not move.
      // Reserving a slot per kind list-wide costs a narrow split the whole
      // column over a note that shares no row with anything.
      final conflictOnly = [row('a', conflict: true)];
      double? narrowest;
      for (var width = 300.0; width <= 800 && narrowest == null; width += 2) {
        await pumpList(tester, conflictOnly, width);
        if (find.byIcon(MdiIcons.alert).evaluate().isNotEmpty) narrowest = width;
      }
      expect(narrowest, isNotNull);

      await pumpList(tester, [row('a', conflict: true), row('b', notes: 'Met at Dayton')], narrowest!);
      expect(find.byIcon(MdiIcons.alert), findsOneWidget);
      expect(find.byIcon(MdiIcons.noteOutline), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a note never costs a contest log its exchange column', (tester) async {
      // A column holding only notes markers ranks BELOW the exchange. Ranked
      // above it, as references are, the marker's few pixels are admitted
      // first, the exchange then misses the fit, and one note blanks the
      // exchange on every row of a narrow pane.
      Qso contact(String uuid, {String? notes}) => Qso(
        uuid: uuid,
        operationUuid: 'op-1',
        data: {
          'our': {'sent': '599', 'exchange': '042'},
          'their': {'call': 'K1ABC', 'name': 'Alice', 'sent': '599', 'exchange': 'ZN14'},
          'mode': 'CW',
          'startAtMillis': 1000,
          'notes': ?notes,
        },
      );
      final exchange = find.textContaining('ZN14');

      double? narrowest;
      for (var width = 300.0; width <= 800 && narrowest == null; width += 2) {
        await pumpList(tester, [contact('a')], width);
        if (exchange.evaluate().isNotEmpty) narrowest = width;
      }
      expect(narrowest, isNotNull);
      expect(narrowest, greaterThan(300), reason: 'the search must start below the threshold');

      await pumpList(tester, [contact('a'), contact('b', notes: 'Met at Dayton')], narrowest!);
      expect(exchange, findsNWidgets(2));
      expect(tester.takeException(), isNull);

      // And with room for both, the marker is back.
      await pumpList(tester, [contact('a'), contact('b', notes: 'Met at Dayton')], 800);
      expect(find.byIcon(MdiIcons.noteOutline), findsOneWidget);
    });

    testWidgets('a row carrying both marks is budgeted for both', (tester) async {
      // The other half of sharing: one row's marks ADD. Budgeting the widest
      // kind rather than the widest row would overflow exactly this row.
      for (var width = 300.0; width <= 800; width += 2) {
        await pumpList(tester, [row('a', conflict: true, notes: 'Met at Dayton')], width);
        expect(tester.takeException(), isNull, reason: 'width $width');
      }
      expect(find.byIcon(MdiIcons.alert), findsOneWidget);
      expect(find.byIcon(MdiIcons.noteOutline), findsOneWidget);
    });
  });

  group('DX/State column', () {
    testWidgets('shows a flag when both entities are known and differ', (tester) async {
      final qso = Qso(
        uuid: 'q',
        operationUuid: 'op-1',
        data: {
          'their': {'call': 'G0ABC', 'entityPrefix': 'G', 'flag': '🇬🇧', 'state': 'ignored-when-dx'},
          'mode': 'SSB',
          'startAtMillis': 1000,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(qsos: [qso], onSelect: (_) {}, ourEntityPrefix: 'K'),
          ),
        ),
      );

      expect(find.text('🇬🇧'), findsOneWidget);
      expect(find.text('ignored-when-dx'), findsNothing);
    });

    testWidgets('shows the state when both entities match', (tester) async {
      final qso = Qso(
        uuid: 'q',
        operationUuid: 'op-1',
        data: {
          'their': {'call': 'K2HAM', 'entityPrefix': 'K', 'flag': '🇺🇸', 'state': 'NY'},
          'mode': 'SSB',
          'startAtMillis': 1000,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(qsos: [qso], onSelect: (_) {}, ourEntityPrefix: 'K'),
          ),
        ),
      );

      expect(find.text('NY'), findsOneWidget);
      expect(find.text('🇺🇸'), findsNothing);
    });

    // The setting is the ONLY thing that distinguishes these two from the
    // pair above: the same-entity QSO must flag under `all` and the DX one
    // must not under `none`, or the column has quietly hardcoded `dx`.
    testWidgets('DxFlags.all flags a same-entity contact too', (tester) async {
      final qso = Qso(
        uuid: 'q',
        operationUuid: 'op-1',
        data: {
          'their': {'call': 'K2HAM', 'entityPrefix': 'K', 'flag': '🇺🇸', 'state': 'NY'},
          'mode': 'SSB',
          'startAtMillis': 1000,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(qsos: [qso], onSelect: (_) {}, ourEntityPrefix: 'K', dxFlags: DxFlags.all),
          ),
        ),
      );

      expect(find.text('🇺🇸'), findsOneWidget);
      expect(find.text('NY'), findsNothing);
    });

    testWidgets('DxFlags.none shows the state even for a DX contact', (tester) async {
      final qso = Qso(
        uuid: 'q',
        operationUuid: 'op-1',
        data: {
          'their': {'call': 'G0ABC', 'entityPrefix': 'G', 'flag': '🇬🇧', 'state': 'Kent'},
          'mode': 'SSB',
          'startAtMillis': 1000,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(qsos: [qso], onSelect: (_) {}, ourEntityPrefix: 'K', dxFlags: DxFlags.none),
          ),
        ),
      );

      expect(find.text('Kent'), findsOneWidget);
      expect(find.text('🇬🇧'), findsNothing);
    });

    testWidgets('falls back to the state, not a flag, while our own entity is still unresolved', (tester) async {
      final qso = Qso(
        uuid: 'q',
        operationUuid: 'op-1',
        data: {
          'their': {'call': 'G0ABC', 'entityPrefix': 'G', 'flag': '🇬🇧', 'state': 'shown-until-resolved'},
          'mode': 'SSB',
          'startAtMillis': 1000,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          // ourEntityPrefix omitted — mirrors OperationView before its
          // lookupCall(online: false) resolution lands.
          home: Scaffold(
            body: QsoList(qsos: [qso], onSelect: (_) {}),
          ),
        ),
      );

      expect(find.text('shown-until-resolved'), findsOneWidget);
      expect(find.text('🇬🇧'), findsNothing);
    });

    testWidgets('a DX contact with a resolved entity but no flag falls back to state instead of going blank', (tester) async {
      // A resolvable entity with no matching flag data (e.g. an edge-case
      // DXCC entity present in lib-country-files but missing from
      // lib-dxcc-data's table) must not be treated the same as "no entity
      // resolved at all" — it's still a known-DX contact, just without a
      // flag glyph, so the row should still show something rather than
      // nothing.
      final qso = Qso(
        uuid: 'q',
        operationUuid: 'op-1',
        data: {
          'their': {'call': 'XX1ABC', 'entityPrefix': 'XX', 'state': 'fallback-state'},
          'mode': 'SSB',
          'startAtMillis': 1000,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(qsos: [qso], onSelect: (_) {}, ourEntityPrefix: 'K'),
          ),
        ),
      );

      expect(find.text('fallback-state'), findsOneWidget);
    });

    testWidgets('an empty (not missing) flag also falls back to state instead of rendering blank', (tester) async {
      // Distinct from the null-flag case above: some lookup sources stamp
      // an empty string rather than omitting the key entirely, and that
      // must not be mistaken for "has a flag to show".
      final qso = Qso(
        uuid: 'q',
        operationUuid: 'op-1',
        data: {
          'their': {'call': 'XX1ABC', 'entityPrefix': 'XX', 'flag': '', 'state': 'fallback-state'},
          'mode': 'SSB',
          'startAtMillis': 1000,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(qsos: [qso], onSelect: (_) {}, ourEntityPrefix: 'K'),
          ),
        ),
      );

      expect(find.text('fallback-state'), findsOneWidget);
    });

    testWidgets('shows nothing when neither a flag nor a state is available', (tester) async {
      final qso = Qso(
        uuid: 'q',
        operationUuid: 'op-1',
        data: {
          'their': {'call': 'N0CALL'},
          'mode': 'SSB',
          'startAtMillis': 1000,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(qsos: [qso], onSelect: (_) {}, ourEntityPrefix: 'K'),
          ),
        ),
      );

      // Nothing to assert findsOneWidget on — just confirm it doesn't crash
      // and the row still renders the callsign.
      expect(find.text('N0CALL'), findsOneWidget);
    });

    testWidgets('a row with no flag/state still reserves that column\'s width, so Name lines up with sibling rows (issue #186)', (tester) async {
      final withState = Qso(
        uuid: 'q1',
        operationUuid: 'op-1',
        data: {
          'their': {'call': 'K2HAM', 'name': 'Has State', 'entityPrefix': 'K', 'state': 'NY'},
          'mode': 'SSB',
          'startAtMillis': 1000,
        },
      );
      final withoutState = Qso(
        uuid: 'q2',
        operationUuid: 'op-1',
        data: {
          'their': {'call': 'K3HAM', 'name': 'No State'},
          'mode': 'SSB',
          'startAtMillis': 2000,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(qsos: [withState, withoutState], onSelect: (_) {}, ourEntityPrefix: 'K'),
          ),
        ),
      );

      // Same callsign length on both rows, so if Name's left edge differs
      // it can only be the DX/State column collapsing to zero width on
      // the row with nothing to show there.
      expect(tester.getTopLeft(find.text('Has State')).dx, tester.getTopLeft(find.text('No State')).dx);
    });

    testWidgets('same alignment guarantee for a flag, not just a state (issue #186)', (tester) async {
      final withFlag = Qso(
        uuid: 'q1',
        operationUuid: 'op-1',
        data: {
          'their': {'call': 'G0ABC', 'name': 'Has Flag', 'entityPrefix': 'G', 'flag': '🇬🇧'},
          'mode': 'SSB',
          'startAtMillis': 1000,
        },
      );
      final withoutFlag = Qso(
        uuid: 'q2',
        operationUuid: 'op-1',
        data: {
          'their': {'call': 'G1ABC', 'name': 'No Flag'},
          'mode': 'SSB',
          'startAtMillis': 2000,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(qsos: [withFlag, withoutFlag], onSelect: (_) {}, ourEntityPrefix: 'K'),
          ),
        ),
      );

      expect(tester.getTopLeft(find.text('Has Flag')).dx, tester.getTopLeft(find.text('No Flag')).dx);
    });
  });

  testWidgets('callsign column is sized to fit a deleted QSO\'s callsign too, not just active ones', (tester) async {
    final short = Qso(
      uuid: 'short',
      operationUuid: 'op-1',
      data: {
        'their': {'call': 'W1AW'},
        'mode': 'SSB',
        'startAtMillis': 1000,
      },
    );
    final long = Qso(
      uuid: 'long',
      operationUuid: 'op-1',
      data: {
        'their': {'call': 'VP8/VERYLONGCALL'},
        'mode': 'SSB',
        'startAtMillis': 2000,
      },
      deleted: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QsoList(qsos: [short, long], onSelect: (_) {}),
        ),
      ),
    );

    // If the callsign column were sized only from active QSOs (excluding the
    // deleted one), the long deleted callsign would wrap onto a second line,
    // making its Text taller than the short active callsign's.
    final shortHeight = tester.getSize(find.text('W1AW')).height;
    final longHeight = tester.getSize(find.text('VP8/VERYLONGCALL')).height;
    expect(longHeight, shortHeight);
  });

  testWidgets('callsign column stays sized to fit at a larger font-scale setting', (tester) async {
    final qso = Qso(
      uuid: 'q',
      operationUuid: 'op-1',
      data: {
        'their': {'call': 'VP8/VERYLONGCALL'},
        'mode': 'SSB',
        'startAtMillis': 1000,
      },
    );

    // A font-scale setting above 1x (accessibility or the app's own "Larger"
    // preference) must still fit the callsign on one line — the column-width
    // measurement has to apply the same ambient scaling the real Text gets.
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: MaterialApp(
          home: Scaffold(
            body: QsoList(qsos: [qso], onSelect: (_) {}),
          ),
        ),
      ),
    );

    // A single-line callsign at fontSize 15 * 1.5 scale has a known height
    // ceiling well under two wrapped lines' worth.
    expect(tester.getSize(find.text('VP8/VERYLONGCALL')).height, lessThan(40));
  });

  testWidgets('references show one icon per type, with ×N for repeats of the same type', (tester) async {
    final operation = await operations.create(stationCall: 'KI2D');
    final qso = await qsos.add(operation.uuid, {
      'their': {'call': 'W1AW'},
      'mode': 'SSB',
      'startAtMillis': 1000,
      'refs': [
        {'type': 'pota', 'ref': 'US-1234'},
        {'type': 'pota', 'ref': 'US-5678'},
        {'type': 'sota', 'ref': 'W1/AA-001'},
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QsoList(
            qsos: [qso],
            onSelect: (_) {},
            activityControls: [
              {
                'icon': 'pine-tree',
                'input': {'refType': 'pota'},
              },
              {
                'icon': 'image-filter-hdr',
                'input': {'refType': 'sota'},
              },
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(MdiIcons.pineTree), findsOneWidget);
    expect(find.byIcon(MdiIcons.imageFilterHdr), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);
  });

  testWidgets('a contest ref shows no icon, whichever primary field kind declares it first', (tester) async {
    // Contest refs are metadata, not somewhere you went to operate — an icon
    // on every row of a contest log is noise. `_isContestRef` decides this
    // from the control owning the ref type, and `controlForRefType` returns
    // the FIRST one: CQ WPX declares its `serial` (order 10) before its
    // `text` exchange (order 20), so leaving `serial` out of that check
    // silently reinstated the icon for exactly one contest.
    final operation = await operations.create(stationCall: 'KI2D');
    final qso = await qsos.add(operation.uuid, {
      'their': {'call': 'W1AW'},
      'mode': 'CW',
      'startAtMillis': 1000,
      'refs': [
        {'type': 'cqwpx', 'ourSerial': 1, 'theirSerial': '12'},
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QsoList(
            qsos: [qso],
            onSelect: (_) {},
            activityControls: const [
              {
                'key': 'cqwpx/ourSerial',
                'icon': 'flag-checkered',
                'input': {'kind': 'serial', 'refType': 'cqwpx', 'field': 'ourSerial'},
              },
              {
                'key': 'cqwpx/theirSerial',
                'icon': 'flag-checkered',
                'input': {'kind': 'text', 'refType': 'cqwpx', 'field': 'theirSerial'},
              },
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(MdiIcons.flagCheckered), findsNothing);
    // And not mistaken for an unknown ref type either (issue #261's marker).
    expect(find.text('?'), findsNothing);
  });

  testWidgets('a searchable-options exchange is contest metadata too, not a place you went', (tester) async {
    // Same rule as above for the kind M5 added. The core writes only
    // `{type, field}` onto the ref an exchange field fills — no `program` — so
    // this control's kind is the ONLY thing that can say a state-park QSO is a
    // contest contact rather than an activity reference.
    final operation = await operations.create(stationCall: 'KI2D');
    final qso = await qsos.add(operation.uuid, {
      'their': {'call': 'W1AW'},
      'mode': 'CW',
      'startAtMillis': 1000,
      'refs': [
        {'type': 'stateparks', 'park': 'ADA'},
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QsoList(
            qsos: [qso],
            onSelect: (_) {},
            activityControls: const [
              {
                'key': 'stateparks/park',
                'icon': 'flag-checkered',
                'input': {
                  'kind': 'options',
                  'refType': 'stateparks',
                  'field': 'park',
                  'options': [
                    {'code': 'ADA', 'name': 'Adams Lake SP'},
                  ],
                },
              },
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(MdiIcons.flagCheckered), findsNothing);
    expect(find.text('?'), findsNothing);
  });

  testWidgets('a ref-type icon is drawn in the row\'s dim gray, not the tertiary accent', (tester) async {
    final operation = await operations.create(stationCall: 'KI2D');
    final qso = await qsos.add(operation.uuid, {
      'their': {'call': 'W1AW'},
      'mode': 'SSB',
      'startAtMillis': 1000,
      'refs': [
        {'type': 'pota', 'ref': 'US-1234'},
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QsoList(
            qsos: [qso],
            onSelect: (_) {},
            activityControls: [
              {
                'icon': 'pine-tree',
                'input': {'refType': 'pota'},
              },
            ],
          ),
        ),
      ),
    );

    final finder = find.byIcon(MdiIcons.pineTree);
    final icon = tester.widget<Icon>(finder);
    final scheme = Theme.of(tester.element(finder)).colorScheme;
    // The same gray the time column paints in — a reference sits at the
    // weight of the data beside it, not at the callsign's or an accent's.
    final timeColor = tester.widget<Text>(find.text('00:00z')).style?.color;
    expect(icon.color, timeColor);
    expect(icon.color, isNot(scheme.tertiary));
    expect(icon.color, isNot(scheme.onSurface));
  });

  testWidgets('shows the other station\'s exchange after the signal reports (#354)', (tester) async {
    final qso = Qso(
      uuid: 'q1',
      operationUuid: 'op-1',
      data: {
        'our': {'sent': '599'},
        'their': {'call': 'W1AW', 'sent': '599', 'exchange': 'ZN14'},
        'mode': 'CW',
        'startAtMillis': 1000,
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QsoList(qsos: [qso], onSelect: (_) {}),
        ),
      ),
    );

    final exchange = find.text('ZN14');
    expect(exchange, findsOneWidget);
    // Positioned after the RST cell ("599 599").
    expect(tester.getTopLeft(exchange).dx, greaterThan(tester.getTopLeft(find.text('599 599')).dx));
  });

  testWidgets('a serial contest shows the number we sent ahead of the one received', (tester) async {
    // Without `our.exchange` in the cell, a serial contest's row shows only
    // what came back, and the operator has nothing to check their own
    // number against. Same sent-then-received order as the RST cell.
    final qso = Qso(
      uuid: 'q1',
      operationUuid: 'op-1',
      data: {
        'our': {'sent': '599', 'exchange': '042'},
        'their': {'call': 'W1AW', 'sent': '599', 'exchange': '117'},
        'mode': 'CW',
        'startAtMillis': 1000,
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QsoList(qsos: [qso], onSelect: (_) {}),
        ),
      ),
    );

    expect(find.text('042 117'), findsOneWidget);
    expect(find.text('117'), findsNothing, reason: 'the received serial never stands alone');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QsoList(qsos: [qso], onSelect: (_) {}, switchSentRcvd: true),
        ),
      ),
    );
    expect(find.text('117 042'), findsOneWidget, reason: 'the switched row order flips the pair too');

    // Only ours so far (theirs not yet typed, or a call-list entry whose
    // number the core issues after the hook): no stray space either side.
    final oursOnly = Qso(
      uuid: 'q2',
      operationUuid: 'op-1',
      data: {
        'our': {'sent': '599', 'exchange': '043'},
        'their': {'call': 'W1AW', 'sent': '599', 'exchange': ''},
        'mode': 'CW',
        'startAtMillis': 2000,
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QsoList(qsos: [oursOnly], onSelect: (_) {}),
        ),
      ),
    );
    expect(find.text('043'), findsOneWidget);
  });

  testWidgets('the RST cell is wide enough to fit "599 599" without clipping', (tester) async {
    final qso = Qso(
      uuid: 'q1',
      operationUuid: 'op-1',
      data: {
        'our': {'sent': '599'},
        'their': {'call': 'W1AW', 'sent': '599'},
        'mode': 'CW',
        'startAtMillis': 1000,
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QsoList(qsos: [qso], onSelect: (_) {}),
        ),
      ),
    );

    final finder = find.text('599 599');
    expect(finder, findsOneWidget);
    final text = tester.widget<Text>(finder);
    final style = DefaultTextStyle.of(tester.element(finder)).style.merge(text.style);
    final painter = TextPainter(
      text: TextSpan(text: '599 599', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final intrinsicWidth = painter.width;
    painter.dispose();
    // A fixed-width column narrower than this clips the text instead of
    // failing loudly, so the box has to be measured against, not eyeballed.
    expect(tester.getSize(finder).width, greaterThanOrEqualTo(intrinsicWidth));
  });

  testWidgets('the RST column still fits "599 599" even when every report in the log is shorter', (tester) async {
    final qso = Qso(
      uuid: 'q1',
      operationUuid: 'op-1',
      data: {
        'our': {'sent': '59'},
        'their': {'call': 'W1AW', 'sent': '59'},
        'mode': 'SSB',
        'startAtMillis': 1000,
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QsoList(qsos: [qso], onSelect: (_) {}),
        ),
      ),
    );

    final finder = find.text('59 59');
    expect(finder, findsOneWidget);
    final style = DefaultTextStyle.of(tester.element(finder)).style.merge(tester.widget<Text>(finder).style);
    final painter = TextPainter(
      text: TextSpan(text: '599 599', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final floorWidth = painter.width;
    painter.dispose();
    expect(tester.getSize(finder).width, greaterThanOrEqualTo(floorWidth));
  });

  testWidgets('HALO-143: switchSentRcvd puts the received report first, matching the entry row', (tester) async {
    // The cell carries no labels, so the two reports are indistinguishable
    // once swapped — which is exactly why it has to follow the entry row.
    // An operator who set the row to Rcvd-first and reads a fixed
    // Sent-first list is reading every contact backwards.
    final qso = Qso(
      uuid: 'q1',
      operationUuid: 'op-1',
      data: {
        'our': {'sent': '57'},
        'their': {'call': 'W1AW', 'sent': '33'},
        'mode': 'SSB',
        'startAtMillis': 1000,
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QsoList(qsos: [qso], onSelect: (_) {}),
        ),
      ),
    );
    expect(find.text('57 33'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QsoList(qsos: [qso], onSelect: (_) {}, switchSentRcvd: true),
        ),
      ),
    );
    expect(find.text('33 57'), findsOneWidget);
  });

  testWidgets('a ref of a type with no active control shows a red question-mark marker (issue #261)', (tester) async {
    final operation = await operations.create(stationCall: 'KI2D');
    final qso = await qsos.add(operation.uuid, {
      'their': {'call': 'W1AW'},
      'mode': 'SSB',
      'startAtMillis': 1000,
      'refs': [
        {'type': 'pota', 'ref': 'US-1234'},
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // No matching control for 'pota' — its extension isn't active.
          body: QsoList(qsos: [qso], onSelect: (_) {}, activityControls: const []),
        ),
      ),
    );

    expect(find.byIcon(MdiIcons.pineTree), findsNothing);
    final markerFinder = find.byType(CircleAvatar);
    expect(markerFinder, findsOneWidget);
    expect(find.descendant(of: markerFinder, matching: find.byIcon(MdiIcons.help)), findsOneWidget);
  });

  // A reference an extension reaches back for by CODE, not just by type
  // (`alsoHandles: ['qp/ny']`). The badge column answers the same question the
  // activity row does, so a lookup here that passes only the type disagrees
  // with the row beside it: the operator sees "New York QSO Party" above a log
  // whose every line wears the red question mark.
  group('a reference claimed by prefix', () {
    // The accent is what tells the two branches apart in the tree: a badge the
    // row recognises is a bare icon in the row's own foreground, while the
    // unknown marker is a tinted CircleAvatar. Without it both branches draw
    // the same widget once the code reaches them, and the assertions below
    // hold whether or not the type-only lookup was fixed.
    const nyqpRefList = {
      'icon': 'pine-tree',
      'color': '#3C8C3C',
      'input': {
        'kind': 'refList',
        'refType': 'ny-qso-party',
        'alsoHandles': ['qp/ny'],
      },
    };

    testWidgets('wears its claimant\'s icon rather than the unknown marker', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'mode': 'SSB',
        'startAtMillis': 1000,
        'refs': [
          {'type': 'qp', 'ref': 'NY'},
        ],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(qsos: [qso], onSelect: (_) {}, activityControls: const [nyqpRefList]),
          ),
        ),
      );

      expect(find.byIcon(MdiIcons.pineTree), findsOneWidget);
      expect(find.byType(CircleAvatar), findsNothing);
    });

    // The badge is one per type, and the code it carries decides which
    // extension it belongs to. Taking whichever code came first would hand the
    // badge to the unclaimed reference and flag the pair as unknown, with the
    // claimant installed and answering.
    testWidgets('claims the badge for a type it shares with an unclaimed reference', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'mode': 'SSB',
        'startAtMillis': 1000,
        'refs': [
          {'type': 'qp', 'ref': 'ZZ'},
          {'type': 'qp', 'ref': 'NY'},
        ],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(qsos: [qso], onSelect: (_) {}, activityControls: const [nyqpRefList]),
          ),
        ),
      );

      expect(find.byIcon(MdiIcons.pineTree), findsOneWidget);
      expect(find.text('\u00d72'), findsOneWidget);
      expect(find.byType(CircleAvatar), findsNothing);
    });

    // A QSO party's control is a form, which makes its references contest
    // metadata — the same as if it had published the type outright. Deciding
    // that on the type alone finds no control, so every row of a legacy QSO
    // party log grows a badge the party itself would never have drawn.
    testWidgets('reads as the contest reference it is, and shows no badge', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'mode': 'SSB',
        'startAtMillis': 1000,
        'refs': [
          {'type': 'qp', 'ref': 'NY', 'exchange': '59 ONO'},
        ],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(
              qsos: [qso],
              onSelect: (_) {},
              activityControls: const [
                {
                  'icon': 'pine-tree',
                  'input': {
                    'kind': 'form',
                    'refType': 'ny-qso-party',
                    'alsoHandles': ['qp/ny'],
                  },
                },
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(MdiIcons.pineTree), findsNothing);
      expect(find.byType(CircleAvatar), findsNothing);
    });
  });

  group('day headers', () {
    testWidgets('groups QSOs into one pinned header per UTC day', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      const dayMillis = 1000 * 60 * 60 * 24;
      final first = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'mode': 'SSB',
        'startAtMillis': 1000,
      });
      final second = await qsos.add(operation.uuid, {
        'their': {'call': 'K2HAM'},
        'mode': 'SSB',
        // A day later — its own header, separate from the first QSO's.
        'startAtMillis': dayMillis + 1000,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(qsos: [first, second], onSelect: (_) {}),
          ),
        ),
      );

      expect(find.byType(DayHeaderRow), findsNWidgets(2));
      // Both QSOs are decades in the past relative to "now" (the test run's
      // real clock), so the dynamic date label falls into its oldest tier:
      // month/day/year, no weekday — see `DayHeaderRow._dayLabel`.
      expect(find.text('Jan 1 1970'), findsOneWidget);
      expect(find.text('Jan 2 1970'), findsOneWidget);
      expect(find.text('1 QSO'), findsNWidgets(2));
    });

    testWidgets('is exactly as tall as an ordinary QSO row', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'mode': 'SSB',
        'startAtMillis': 1000,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(qsos: [qso], onSelect: (_) {}),
          ),
        ),
      );

      final headerHeight = tester.getSize(find.byType(DayHeaderRow)).height;
      // The row's own height, measured the same way: its immediate
      // `Padding` ancestor (`buildRow`'s `EdgeInsets.symmetric(vertical:
      // 4)`), found via the callsign text it wraps.
      final rowHeight = tester.getSize(find.ancestor(of: find.text('W1AW'), matching: find.byType(Padding)).first).height;
      expect(headerHeight, closeTo(rowHeight, 1));
    });

    testWidgets("only the current day's header stays pinned — short days' headers don't stack", (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      const dayMillis = 1000 * 60 * 60 * 24;
      // Six single-QSO days: each day's own section is shorter than the
      // header itself, the exact case where sibling
      // `SliverPersistentHeader`s (without a `SliverMainAxisGroup` per
      // day) never get pushed off by the next one and pile up on screen
      // instead of only the current day's header showing.
      final qsoList = [
        for (var day = 0; day < 6; day++)
          await qsos.add(operation.uuid, {
            'their': {'call': 'W1AW'},
            'mode': 'SSB',
            'startAtMillis': day * dayMillis + 1000,
          }),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 200,
              child: QsoList(qsos: qsoList, onSelect: (_) {}),
            ),
          ),
        ),
      );

      // Scroll partway through the list — past a couple of day boundaries
      // but not to either end — where a stacking bug would show more than
      // one header pinned at the very top at once.
      await tester.drag(find.byType(Scrollable), const Offset(0, -120));
      await tester.pump();

      final headers = find.byType(DayHeaderRow);
      final pinnedCount = headers.evaluate().where((e) => tester.getTopLeft(find.byWidget(e.widget)).dy <= 0.5).length;
      expect(pinnedCount, 1);
    });

    testWidgets('shows score badges from the matching daySections entry, skipping qsoCount and tallies with no summary', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'mode': 'SSB',
        'startAtMillis': 1000,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(
              qsos: [qso],
              onSelect: (_) {},
              // Map keys are namespaced per scorer once more than one is
              // active, so the skip must key off the tally's own `key`
              // (which ScoreTally always carries) rather than the map key.
              daySections: [
                {
                  'day': 0,
                  'count': 1,
                  'scores': {
                    'core.qsoCount': {'key': 'qsoCount', 'icon': 'radio', 'summary': '1'},
                    'core.dxcc': {'key': 'dxcc', 'icon': 'earth', 'summary': '5'},
                    // A tally with no `summary` (e.g. activityScoring's
                    // hunting tally, which folds its count into `label`
                    // instead) opts itself out of this compact badge row —
                    // the render site doesn't special-case any scorer key.
                    'pota.hunting': {'key': 'hunting', 'icon': 'pine-tree'},
                  },
                },
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(MdiIcons.earth), findsOneWidget);
      expect(find.byIcon(MdiIcons.radio), findsNothing);
      expect(find.byIcon(MdiIcons.pineTree), findsNothing);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('a badge for an activity that has met its goal tints green', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'mode': 'SSB',
        'startAtMillis': 1000,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(
              qsos: [qso],
              onSelect: (_) {},
              daySections: [
                {
                  'day': 0,
                  'count': 1,
                  'scores': {
                    'pota.activation': {'key': 'activation', 'icon': 'pine-tree', 'summary': '10 ✓', 'activated': true},
                  },
                },
              ],
            ),
          ),
        ),
      );

      final finder = find.byIcon(MdiIcons.pineTree);
      final icon = tester.widget<Icon>(finder);
      final important = HaLoColors.of(tester.element(finder)).important;
      expect(icon.color, important);
    });

    testWidgets('an activity short of its goal keeps the neutral badge color', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'mode': 'SSB',
        'startAtMillis': 1000,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(
              qsos: [qso],
              onSelect: (_) {},
              daySections: [
                {
                  'day': 0,
                  'count': 1,
                  'scores': {
                    'pota.activation': {'key': 'activation', 'icon': 'pine-tree', 'summary': '7/10', 'activated': false},
                  },
                },
              ],
            ),
          ),
        ),
      );

      final finder = find.byIcon(MdiIcons.pineTree);
      final icon = tester.widget<Icon>(finder);
      final theme = Theme.of(tester.element(finder));
      expect(icon.color, theme.colorScheme.onSurfaceVariant);
    });

    group('dynamic date label', () {
      const dayMillis = 1000 * 60 * 60 * 24;
      // A Wednesday afternoon, so "this week" cases land on predictable
      // weekday abbreviations regardless of when the test suite runs — and
      // a non-midnight time-of-day, matching how the real app always calls
      // this with the actual current moment: [dayMillis] arguments below
      // are truncated day-start boundaries, so "yesterday" (a full 24h+
      // before [now]'s own day-start) only lands within the 1-2 day window
      // `_dayLabel` checks for because [now] itself isn't also day-aligned.
      final now = DateTime.utc(2024, 1, 10, 15, 30);
      int dayOf(DateTime dt) {
        final millis = dt.millisecondsSinceEpoch;
        return millis - (millis % dayMillis);
      }

      Future<void> pumpHeader(WidgetTester tester, int forDayMillis) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DayHeaderRow(dayMillis: forDayMillis, count: 1, now: now),
          ),
        ),
      );

      testWidgets('today', (tester) async {
        await pumpHeader(tester, dayOf(now));
        expect(find.text('Today'), findsOneWidget);
      });

      testWidgets('yesterday', (tester) async {
        await pumpHeader(tester, dayOf(now.subtract(const Duration(days: 1))));
        expect(find.text('Yesterday'), findsOneWidget);
      });

      testWidgets('within the last week uses a weekday abbreviation', (tester) async {
        await pumpHeader(tester, dayOf(now.subtract(const Duration(days: 3))));
        expect(find.text('Sun 7'), findsOneWidget);
      });

      testWidgets('within the last 9 months uses month + day, no year', (tester) async {
        await pumpHeader(tester, dayOf(now.subtract(const Duration(days: 60))));
        expect(find.text('Nov 11'), findsOneWidget);
      });

      testWidgets('beyond 9 months includes the year', (tester) async {
        await pumpHeader(tester, dayOf(now.subtract(const Duration(days: 400))));
        expect(find.text('Dec 6 2022'), findsOneWidget);
      });

      testWidgets('a day two or more in the future is not mislabeled "Yesterday"', (tester) async {
        // A date typo or a clock-skewed synced device can produce a
        // future-dated QSO; it should read as a calendar date, not
        // "Yesterday" (the pre-fix behavior — any diffInDays <= 2 matched).
        await pumpHeader(tester, dayOf(now.add(const Duration(days: 3))));
        expect(find.text('Yesterday'), findsNothing);
        expect(find.text('Sat 13'), findsOneWidget);
      });

      testWidgets("uses the current locale's vocabulary", (tester) async {
        // runAsync: the Spanish translations are a deferred library, and its
        // load is a real future that fake async would never complete.
        await tester.runAsync(() => LocaleSettings.setLocale(AppLocale.es));
        addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.en));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DayHeaderRow(dayMillis: dayOf(now), count: 1, now: now),
            ),
          ),
        );
        expect(find.text('Hoy'), findsOneWidget);
      });
    });
  });

  group('show QSO numbers', () {
    testWidgets('hides the number column when disabled', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'mode': 'SSB',
        'startAtMillis': 1000,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(qsos: [qso], onSelect: (_) {}, showQsoNumbers: false),
          ),
        ),
      );

      expect(find.text('1'), findsNothing);
    });
  });

  group('viewport height changes / secondary logging controls (#192)', () {
    testWidgets('shrinking viewport height when near bottom pushes list up, keeping bottom QSO in view', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final list = <Qso>[];
      for (var i = 1; i <= 30; i++) {
        list.add(
          await qsos.add(operation.uuid, {
            'their': {'call': 'K${i}HAM'},
            'band': '20m',
            'mode': 'SSB',
            'startAtMillis': 1000 + i * 60000,
          }),
        );
      }

      var height = 400.0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    SizedBox(
                      height: height,
                      child: QsoList(qsos: list, onSelect: (_) {}),
                    ),
                    ElevatedButton(onPressed: () => setState(() => height = 250.0), child: const Text('Shrink')),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The last QSO (K30HAM) should be in view.
      expect(find.text('K30HAM'), findsOneWidget);

      // Shrink viewport (simulating secondary control opening)
      await tester.tap(find.text('Shrink'));
      await tester.pumpAndSettle();

      // The last QSO (K30HAM) must STILL be in view.
      expect(find.text('K30HAM'), findsOneWidget);
    });

    testWidgets('shrinking viewport height when scrolled up preserves user position', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final list = <Qso>[];
      for (var i = 1; i <= 30; i++) {
        list.add(
          await qsos.add(operation.uuid, {
            'their': {'call': 'K${i}HAM'},
            'band': '20m',
            'mode': 'SSB',
            'startAtMillis': 1000 + i * 60000,
          }),
        );
      }

      var height = 400.0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    SizedBox(
                      height: height,
                      child: QsoList(qsos: list, onSelect: (_) {}),
                    ),
                    ElevatedButton(onPressed: () => setState(() => height = 250.0), child: const Text('Shrink')),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll up by dragging down.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
      await tester.pumpAndSettle();

      // Bottom QSO should no longer be visible.
      expect(find.text('K30HAM'), findsNothing);

      // Record the scroll offset after dragging up.
      final customScrollView = tester.widget<CustomScrollView>(find.byType(CustomScrollView));
      final offsetBeforeShrink = customScrollView.controller!.offset;

      // Shrink viewport (simulating secondary control opening)
      await tester.tap(find.text('Shrink'));
      await tester.pumpAndSettle();

      // Bottom QSO should STILL not be forced into view.
      expect(find.text('K30HAM'), findsNothing);

      // Scroll offset should remain unchanged (not jumped to maxScrollExtent).
      final offsetAfterShrink = customScrollView.controller!.offset;
      expect(offsetAfterShrink, equals(offsetBeforeShrink));
    });
  });

  group('columns in a pane too narrow for them', () {
    // Column widths are list-wide and content-derived, so nothing about them
    // shrinks when the pane does: in a narrow split the fixed columns used to
    // outgrow the row and simply overflow. In debug that is a yellow-striped
    // RenderFlex warning; in RELEASE it is a silent clip, which is the part
    // that matters — logged data disappears off the edge of a row with no
    // indication to the operator that it is there. So a column that doesn't
    // fit has to be dropped, not painted out of bounds.

    Future<List<Qso>> mixedModeLog(Operation operation) async {
      final list = <Qso>[];
      for (var i = 1; i <= 4; i++) {
        list.add(
          await qsos.add(operation.uuid, {
            'their': {'call': 'K${i}HAM'},
            'band': '20m',
            // Mixed modes, so the Mode column earns its place on content.
            'mode': i.isEven ? 'SSB' : 'CW',
            'startAtMillis': 1000 + i * 60000,
          }),
        );
      }
      return list;
    }

    Widget hostAtWidth(List<Qso> list, double width) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: 300,
          child: QsoList(qsos: list, onSelect: (_) {}),
        ),
      ),
    );

    testWidgets('a wide pane shows the optional columns', (tester) async {
      final operation = await operations.create(stationCall: 'N0CALL');
      final list = await mixedModeLog(operation);

      await tester.pumpWidget(hostAtWidth(list, 900));
      await tester.pumpAndSettle();

      // The control for the narrow case below: Mode is present on content
      // alone, so its absence there is about FIT and nothing else.
      expect(find.text('CW'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a narrow pane drops columns instead of overflowing', (tester) async {
      final operation = await operations.create(stationCall: 'N0CALL');
      final list = await mixedModeLog(operation);

      // Narrow enough that the optional columns can't all fit, wide enough to
      // still hold time + freq + callsign — the regime a real split pane
      // lives in.
      await tester.pumpWidget(hostAtWidth(list, 320));
      await tester.pumpAndSettle();

      // Nothing overflowed: no RenderFlex warning was raised at all. This is
      // the assertion that fails if the fit budget is ever dropped.
      expect(tester.takeException(), isNull);

      // Mode gave way — it is the first of the columns present here that the
      // budget is willing to lose.
      expect(find.text('CW'), findsNothing);

      // ...and the callsign did NOT: "the callsign never truncates" is the
      // rule the squeeze has to respect, so it survives a pane this narrow
      // whole rather than being ellipsized to make room.
      expect(find.text('K1HAM'), findsOneWidget);
    });

    testWidgets('a pane below the minimum stops shrinking rather than overflowing', (tester) async {
      final operation = await operations.create(stationCall: 'N0CALL');
      final list = await mixedModeLog(operation);

      // Narrower than time + freq + callsign can possibly fit. There is
      // nothing left to drop, so the list holds its minimum width and the
      // ClipRect trims the right edge — rows stay internally consistent
      // instead of laying their columns on top of each other. Dropping the
      // minimum brings the RenderFlex overflow straight back.
      await tester.pumpWidget(hostAtWidth(list, 120));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // The mandatory columns are all still laid out, whether or not the
      // pane is wide enough to reveal them.
      expect(find.text('K1HAM'), findsOneWidget);
    });

    // A log carrying every optional column at once, so the budget has
    // something to drop in each of its six slots rather than only Mode.
    Future<List<Qso>> richLog(Operation operation) async {
      final list = <Qso>[];
      for (var i = 1; i <= 4; i++) {
        list.add(
          await qsos.add(operation.uuid, {
            'their': {'call': 'K${i}HAM', 'grid': 'FN31pr', 'state': 'NY', 'exchange': 'EXCH$i', 'sent': '59', 'received': '57'},
            'band': '20m',
            'mode': i.isEven ? 'SSB' : 'CW',
            'startAtMillis': 1000 + i * 60000,
            'refs': [
              {'type': 'pota', 'ref': 'K-000$i'},
              {'type': 'pota', 'ref': 'K-100$i'},
            ],
          }),
        );
      }
      return list;
    }

    testWidgets('drops the lowest-priority column first, keeping the rest', (tester) async {
      final operation = await operations.create(stationCall: 'N0CALL');
      final list = await richLog(operation);

      // Wide: everything earns its place, including the exchange — the last
      // column in the priority order and so the first to go.
      await tester.pumpWidget(hostAtWidth(list, 1200));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('EXCH1'), findsOneWidget, reason: 'the control: exchange fits at 1200');

      // Squeezed just enough that not everything fits. Whatever else the
      // budget decides, it must give up the exchange BEFORE the QSO number
      // at the head of the row — that ordering is the whole point of the
      // priority list, and nothing else in this suite pins it.
      await tester.pumpWidget(hostAtWidth(list, 470));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('EXCH1'), findsNothing);
      expect(find.text('1'), findsOneWidget, reason: 'QSO number outranks the exchange');
    });

    testWidgets('event and annotation rows survive the minimum too', (tester) async {
      final operation = await operations.create(stationCall: 'N0CALL');
      final list = await richLog(operation);
      // The other two row types share the list's width but have their own
      // fixed leading/time columns — DayHeaderRow already proved a sibling
      // row can overflow at a minimum derived from the QSO row alone.
      // `isEvent` is `band == 'event'` and the kind lives in a nested map —
      // get either wrong and these render as ordinary QSO rows, testing
      // nothing.
      list.add(
        await qsos.add(operation.uuid, {
          'band': 'event',
          'startAtMillis': 500,
          'event': {'event': 'start'},
        }),
      );
      list.add(
        await qsos.add(operation.uuid, {
          'band': 'event',
          'startAtMillis': 600,
          'event': {'event': 'note', 'note': 'A note long enough to need the width it does not have'},
        }),
      );

      await tester.pumpWidget(hostAtWidth(list, 120));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('a declared height must equal what paints, at every density', () {
    // The contract the whole list rests on. `_estimatedTopOf` walks the log
    // adding `qsoRowHeight` per row and `sectionHeaderHeight` per day
    // boundary WITHOUT measuring anything — an off-screen row is either not
    // built or carries a stale paint transform, so measuring is not available
    // to it. And `_DayHeaderDelegate` declares its extent to Flutter, which
    // asserts "layoutExtent exceeds paintExtent" the instant the header
    // paints taller than it claimed.
    //
    // So a density that changes the row padding without changing the declared
    // height (or vice versa) breaks scrolling silently in one direction and
    // loudly in the other. This measures what actually paints and holds it to
    // the metric.
    for (final density in LayoutDensity.values) {
      testWidgets('$density: a QSO row and a day header paint their declared heights', (tester) async {
        final operation = await operations.create(stationCall: 'KI2D');
        final list = <Qso>[];
        for (var i = 1; i <= 3; i++) {
          list.add(
            await qsos.add(operation.uuid, {
              'their': {'call': 'K${i}HAM'},
              'band': '20m',
              'mode': 'SSB',
              'startAtMillis': 1000 + i * 60000,
            }),
          );
        }

        await tester.pumpWidget(
          MaterialApp(
            home: LayoutDensityScope(
              density: density,
              child: Scaffold(
                body: SizedBox(
                  height: 400,
                  child: QsoList(qsos: list, onSelect: (_) {}),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // No pinned-sliver assertion fired.
        expect(tester.takeException(), isNull);

        final metrics = density.metrics;
        final header = tester.getSize(find.byType(DayHeaderRow).first);
        expect(header.height, metrics.sectionHeaderHeight, reason: 'the pinned header paints what _DayHeaderDelegate declared');

        // A row's own painted height, divider included, is what the scroll
        // arithmetic adds up. Measured between two adjacent rows' tops rather
        // than from one row's box, since the divider sits between them.
        // Scoped to the row sliver: the day header is an InkWell too (it
        // opens the operation info), and a bare byType would measure the
        // pitch from IT to the first row.
        final rows = find.descendant(of: find.byType(SliverFixedExtentList), matching: find.byType(InkWell));
        expect(rows, findsAtLeast(2));
        final firstTop = tester.getTopLeft(rows.at(0)).dy;
        final secondTop = tester.getTopLeft(rows.at(1)).dy;
        expect(secondTop - firstTop, metrics.qsoRowHeight, reason: 'row pitch must equal QsoList.rowHeightOf, which _estimatedTopOf and _pageRows both trust');
      });
    }
  });

  group('the Mode column and the sideband', () {
    /// Two phone contacts on the two bands that run OPPOSITE sidebands — the
    /// log holds `USB` and `LSB`, which is one mode worked.
    Future<void> pumpTwoBands(WidgetTester tester, {required String fortyMetreMode}) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final first = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'freq': 14250.0,
        'mode': 'USB',
        'startAtMillis': 1000,
      });
      final second = await qsos.add(operation.uuid, {
        'their': {'call': 'K2HAM'},
        'band': '40m',
        'freq': 7185.0,
        'mode': fortyMetreMode,
        'startAtMillis': 2000,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(qsos: [first, second], onSelect: (_) {}),
          ),
        ),
      );
    }

    testWidgets('two bands worth of phone is one mode, and grows no column', (tester) async {
      // The whole point of collapsing the display: `USB` on 20m and `LSB` on
      // 40m is an operator who worked SSB all day. Counting the STORED modes
      // makes that two modes and grows a Mode column that repeats a value the
      // frequency beside it already implies.
      await pumpTwoBands(tester, fortyMetreMode: 'LSB');

      expect(find.text('SSB'), findsNothing);
      expect(find.text('USB'), findsNothing);
      expect(find.text('LSB'), findsNothing);
    });

    testWidgets('a sideband the band does not run grows the column and paints it', (tester) async {
      // The sporadic case: one contact out of step still has another mode to
      // be counted against, so a count alone would find it.
      await pumpTwoBands(tester, fortyMetreMode: 'USB');

      expect(find.text('SSB'), findsOneWidget); // the 20m contact
      final odd = tester.widget<Text>(find.text('USB'));
      expect(odd.style?.color, ThemeData().colorScheme.error);
    });

    testWidgets('a whole operation on the wrong sideband is still told', (tester) async {
      // The case a count cannot reach, and the one worth catching: a rig left
      // in USB on 40m for a whole session displays that one mode on every row,
      // so `modesUsed` holds a single entry and the column — the only thing
      // carrying the warning — would be dropped with it.
      final operation = await operations.create(stationCall: 'KI2D');
      final only = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '40m',
        'freq': 7185.0,
        'mode': 'USB',
        'startAtMillis': 1000,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(qsos: [only], onSelect: (_) {}),
          ),
        ),
      );

      final odd = tester.widget<Text>(find.text('USB'));
      expect(odd.style?.color, ThemeData().colorScheme.error);
    });
  });

  group('an annotation row from another client', () {
    Future<void> pumpRow(WidgetTester tester, Map<String, dynamic> event) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnnotationRow(
            qso: Qso(uuid: 'e', operationUuid: 'op', data: {'band': 'event', 'event': event}),
            onTap: () {},
          ),
        ),
      ),
    );

    testWidgets('with a description that is not a string shows its note', (tester) async {
      await pumpRow(tester, {'event': 'note', 'description': 42, 'note': 'check later'});
      expect(tester.takeException(), isNull);
      expect(find.text('check later'), findsOneWidget);
    });

    testWidgets('with an icon that is not a string still draws', (tester) async {
      await pumpRow(tester, {'event': 'break', 'icon': 7});
      expect(tester.takeException(), isNull);
      expect(find.text('BREAK'), findsOneWidget);
    });

    testWidgets("reads a TODO's done flag the way PoLo does", (tester) async {
      await pumpRow(tester, {
        'event': 'todo',
        'note': 'x',
        'done': true,
        'data': {'done': false},
      });
      expect(find.byIcon(resolveIconName('sticker')), findsOneWidget, reason: 'data.done says open, whatever a bare done left behind says');
    });
  });
}
