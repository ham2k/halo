// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

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

  testWidgets('newest QSO renders at the bottom, next to the logging panel', (
    tester,
  ) async {
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

  testWidgets(
    'the divider between rows is a hairline, not Material\'s default 16px-tall spacer',
    (tester) async {
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

      expect(tester.getSize(find.byType(Divider)).height, 1);
    },
  );

  testWidgets(
    'event markers render distinctly and are excluded from QSO numbering',
    (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final start = await qsos.addEvent(
        operation.uuid,
        kind: 'start',
        atMillis: 500,
      );
      final first = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'SSB',
        'startAtMillis': 1000,
      });
      final brk = await qsos.addEvent(
        operation.uuid,
        kind: 'break',
        atMillis: 1500,
      );
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
            body: QsoList(
              qsos: [start, first, brk, second],
              onSelect: (_) {},
              onSelectEvent: (qso) => tapped = qso,
            ),
          ),
        ),
      );

      expect(find.text('Operation started'), findsOneWidget);
      expect(find.text('Break'), findsOneWidget);
      // Real QSOs still number 1 and 2 — events don't consume a number.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      await tester.tap(find.text('Break'));
      expect(tapped?.uuid, brk.uuid);
    },
  );

  group('annotation rows (note/todo/solar/weather events, ham2k/app-halo-dist#64)', () {
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
        'event': {
          'event': kind,
          'icon': ?icon,
          'note': ?note,
          'description': ?description,
          'data': ?data,
        },
      });
    }

    testWidgets(
      'a note shows its text on a yellow row, keeps the time column, and consumes no QSO number',
      (tester) async {
        final operation = await operations.create(stationCall: 'KI2D');
        final first = await qsos.add(operation.uuid, {
          'their': {'call': 'W1AW'},
          'band': '20m',
          'mode': 'SSB',
          'startAtMillis': 1000,
        });
        final note = await addAnnotation(
          operation.uuid,
          'note',
          note: 'THIS IS WHEN THE COPS SHOWED UP',
          icon: 'sticker-text-outline',
          atMillis: 1500,
        );
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
              body: QsoList(
                qsos: [first, note, second],
                onSelect: (_) {},
                onSelectEvent: (qso) => tapped = qso,
              ),
            ),
          ),
        );

        expect(find.text('THIS IS WHEN THE COPS SHOWED UP'), findsOneWidget);
        // Timeline entry, not a centered marker: the annotation keeps the
        // QSO rows' HH:MMz time column (1500ms UTC → 00:00z, same as the
        // neighboring rows' format).
        expect(
          find.descendant(of: find.byType(AnnotationRow), matching: find.text('00:00z')),
          findsOneWidget,
        );
        // Real QSOs still number 1 and 2 — annotations don't consume one.
        expect(find.text('1'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);

        // app-polo's eventRow yellow, blended over the surface at light-mode
        // opacity — the "sticky note" treatment the styling is ported from.
        final material = tester.widget<Material>(
          find.descendant(of: find.byType(AnnotationRow), matching: find.byType(Material)),
        );
        final theme = Theme.of(tester.element(find.byType(AnnotationRow)));
        expect(
          material.color,
          Color.alphaBlend(
            const Color(0xFFFCF4A7).withValues(alpha: 0.85),
            theme.colorScheme.surface,
          ),
        );

        await tester.tap(find.text('THIS IS WHEN THE COPS SHOWED UP'));
        expect(tapped?.uuid, note.uuid);
      },
    );

    testWidgets('solar/weather annotations show their description line', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final solar = await addAnnotation(
        operation.uuid,
        'solar',
        description: '🟡SFI 117 • 🟢A 14 • 🟢K 1 • 😎SN 60',
        icon: 'sun-wireless',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QsoList(qsos: [solar], onSelect: (_) {}),
          ),
        ),
      );

      expect(find.text('🟡SFI 117 • 🟢A 14 • 🟢K 1 • 😎SN 60'), findsOneWidget);
      final icon = tester.widget<Icon>(
        find.descendant(of: find.byType(AnnotationRow), matching: find.byType(Icon)),
      );
      expect(icon.icon, resolveIconName('sun-wireless'));
    });

    testWidgets('a todo\'s icon tracks its done state, not the stored icon', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final pending = await addAnnotation(
        operation.uuid,
        'todo',
        note: 'FIX THIS CALL',
        icon: 'sticker-outline',
        data: {'done': false},
        atMillis: 1000,
      );
      final done = await addAnnotation(
        operation.uuid,
        'todo',
        note: 'ALREADY HANDLED',
        icon: 'sticker-outline',
        data: {'done': true},
        atMillis: 2000,
      );
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

      final icons = tester
          .widgetList<Icon>(
            find.descendant(of: find.byType(AnnotationRow), matching: find.byType(Icon)),
          )
          .toList();
      expect(icons[0].icon, resolveIconName('sticker'));
      expect(icons[1].icon, resolveIconName('sticker-check-outline'));
      expect(icons[2].icon, resolveIconName('sticker-check-outline'));
    });
  });

  group('frequency', () {
    testWidgets(
      'splits MHz (bold) / kHz, with no Hz segment for a whole-kHz frequency',
      (tester) async {
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
        // MHz/kHz separated by exactly one period; no fractional-kHz precision
        // anywhere in the list, so there's no second period for an Hz segment.
        expect(find.text('.'), findsOneWidget);
      },
    );

    testWidgets('shows the band instead when the QSO has no frequency', (
      tester,
    ) async {
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

  group('DX/State column', () {
    testWidgets('shows a flag when both entities are known and differ', (
      tester,
    ) async {
      final qso = Qso(
        uuid: 'q',
        operationUuid: 'op-1',
        data: {
          'their': {
            'call': 'G0ABC',
            'entityPrefix': 'G',
            'flag': '🇬🇧',
            'state': 'ignored-when-dx',
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

      expect(find.text('🇬🇧'), findsOneWidget);
      expect(find.text('ignored-when-dx'), findsNothing);
    });

    testWidgets('shows the state when both entities match', (tester) async {
      final qso = Qso(
        uuid: 'q',
        operationUuid: 'op-1',
        data: {
          'their': {
            'call': 'K2HAM',
            'entityPrefix': 'K',
            'flag': '🇺🇸',
            'state': 'NY',
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

      expect(find.text('NY'), findsOneWidget);
      expect(find.text('🇺🇸'), findsNothing);
    });

    testWidgets(
      'falls back to the state, not a flag, while our own entity is still unresolved',
      (tester) async {
        final qso = Qso(
          uuid: 'q',
          operationUuid: 'op-1',
          data: {
            'their': {
              'call': 'G0ABC',
              'entityPrefix': 'G',
              'flag': '🇬🇧',
              'state': 'shown-until-resolved',
            },
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
      },
    );

    testWidgets(
      'a DX contact with a resolved entity but no flag falls back to state instead of going blank',
      (tester) async {
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
            'their': {
              'call': 'XX1ABC',
              'entityPrefix': 'XX',
              'state': 'fallback-state',
            },
            'mode': 'SSB',
            'startAtMillis': 1000,
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: QsoList(
                qsos: [qso],
                onSelect: (_) {},
                ourEntityPrefix: 'K',
              ),
            ),
          ),
        );

        expect(find.text('fallback-state'), findsOneWidget);
      },
    );

    testWidgets('shows nothing when neither a flag nor a state is available', (
      tester,
    ) async {
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
  });

  testWidgets(
    'callsign column is sized to fit a deleted QSO\'s callsign too, not just active ones',
    (tester) async {
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
    },
  );

  testWidgets(
    'callsign column stays sized to fit at a larger font-scale setting',
    (tester) async {
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
      expect(
        tester.getSize(find.text('VP8/VERYLONGCALL')).height,
        lessThan(40),
      );
    },
  );

  testWidgets(
    'references show one icon per type, with ×N for repeats of the same type',
    (tester) async {
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

      expect(find.byIcon(resolveIconName('pine-tree')), findsOneWidget);
      expect(find.byIcon(resolveIconName('image-filter-hdr')), findsOneWidget);
      expect(find.text('×2'), findsOneWidget);
    },
  );

  group('day headers', () {
    testWidgets('groups QSOs into one pinned header per UTC day', (
      tester,
    ) async {
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
      final rowHeight = tester
          .getSize(
            find
                .ancestor(of: find.text('W1AW'), matching: find.byType(Padding))
                .first,
          )
          .height;
      expect(headerHeight, closeTo(rowHeight, 1));
    });

    testWidgets(
      "only the current day's header stays pinned — short days' headers don't stack",
      (tester) async {
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
        final pinnedCount = headers
            .evaluate()
            .where((e) => tester.getTopLeft(find.byWidget(e.widget)).dy <= 0.5)
            .length;
        expect(pinnedCount, 1);
      },
    );

    testWidgets(
      'shows score badges from the matching daySections entry, skipping qsoCount',
      (tester) async {
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
                      'qsoCount': {'icon': 'radio', 'summary': '1'},
                      'dxcc': {'icon': 'earth', 'summary': '5'},
                    },
                  },
                ],
              ),
            ),
          ),
        );

        expect(find.byIcon(resolveIconName('earth')), findsOneWidget);
        expect(find.byIcon(resolveIconName('radio')), findsNothing);
        expect(find.text('5'), findsOneWidget);
      },
    );

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

      Future<void> pumpHeader(WidgetTester tester, int forDayMillis) =>
          tester.pumpWidget(
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

      testWidgets('within the last week uses a weekday abbreviation', (
        tester,
      ) async {
        await pumpHeader(tester, dayOf(now.subtract(const Duration(days: 3))));
        expect(find.text('Sun 7'), findsOneWidget);
      });

      testWidgets('within the last 9 months uses month + day, no year', (
        tester,
      ) async {
        await pumpHeader(tester, dayOf(now.subtract(const Duration(days: 60))));
        expect(find.text('Nov 11'), findsOneWidget);
      });

      testWidgets('beyond 9 months includes the year', (tester) async {
        await pumpHeader(
          tester,
          dayOf(now.subtract(const Duration(days: 400))),
        );
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

      testWidgets('uses the injected locale vocabulary', (tester) async {
        const es = QsoListLabels(
          weekdayAbbrs: ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'],
          monthAbbrs: ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'],
          today: 'Hoy',
          yesterday: 'Ayer',
          tomorrow: 'Mañana',
          eventLabels: {'start': 'Operación iniciada', 'break': 'Descanso', 'end': 'Operación finalizada'},
        );
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: DayHeaderRow(dayMillis: dayOf(now), count: 1, now: now, labels: es)),
        ));
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
    testWidgets(
      'shrinking viewport height when near bottom pushes list up, keeping bottom QSO in view',
      (tester) async {
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
                      ElevatedButton(
                        onPressed: () => setState(() => height = 250.0),
                        child: const Text('Shrink'),
                      ),
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
      },
    );

    testWidgets(
      'shrinking viewport height when scrolled up preserves user position',
      (tester) async {
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
                      ElevatedButton(
                        onPressed: () => setState(() => height = 250.0),
                        child: const Text('Shrink'),
                      ),
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
        final customScrollView =
            tester.widget<CustomScrollView>(find.byType(CustomScrollView));
        final offsetBeforeShrink = customScrollView.controller!.offset;

        // Shrink viewport (simulating secondary control opening)
        await tester.tap(find.text('Shrink'));
        await tester.pumpAndSettle();

        // Bottom QSO should STILL not be forced into view.
        expect(find.text('K30HAM'), findsNothing);

        // Scroll offset should remain unchanged (not jumped to maxScrollExtent).
        final offsetAfterShrink = customScrollView.controller!.offset;
        expect(offsetAfterShrink, equals(offsetBeforeShrink));
      },
    );
  });
}
