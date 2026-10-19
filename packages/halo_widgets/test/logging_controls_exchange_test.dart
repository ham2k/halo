// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The primary fields an activity contributes: contest exchanges and the
// reference lists an activity control writes to. The searchable-options
// field and serial numbers are beside this file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

void main() {
  installLoggingHarness();

  group('only a running activity gets the entry row', () {
    // The entry row is the scarcest space in the app, and EVERY enabled
    // extension is asked for logging controls on every operation. So the core
    // decides who gets in: a primary field only if the operation carries a ref
    // of the type it writes to. Extensions may short-circuit for their own
    // efficiency, but they are not what enforces this — an extension that
    // forgets must not be able to put its exchange in front of someone logging
    // an ordinary QSO, and a stray `serial` field would be worse still,
    // handing out numbers from a series nobody is keeping.
    const exchange = {
      'key': 'contest/exchange',
      'label': 'Exch',
      'icon': 'flag-checkered',
      'input': {'kind': 'text', 'refType': 'contest', 'field': 'exchange'},
    };
    const serial = {
      'key': 'contest/ourSerial',
      'label': 'Our #',
      'icon': 'flag-checkered',
      'input': {
        'kind': 'serial',
        'refType': 'contest',
        'field': 'ourSerial',
        'sequence': {'key': 'serial'},
      },
    };
    // POTA's hunter chip is the reason secondary controls are NOT gated: you
    // chase a park from whatever operation you happen to be running.
    const hunter = {
      'key': 'pota/hunter',
      'label': 'POTA',
      'icon': 'pine-tree',
      'input': {'kind': 'refList', 'refType': 'potaHunter'},
    };

    Widget hostFor(Operation op, List<Map<String, dynamic>> controls, {QsosRepository? repo}) => MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          log: LogHooks(operation: op, qsosRepository: repo ?? qsos),
          radio: baseRadio(),
          activities: ActivityHooks(activityControls: controls),
        ),
      ),
    );

    testWidgets('an exchange field is hidden when the operation is not running that contest', (tester) async {
      await tester.pumpWidget(hostFor(operation, const [exchange]));
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Exch'), findsNothing);
    });

    testWidgets('the same field appears once the activity is added', (tester) async {
      await tester.pumpWidget(hostFor(running(['contest']), const [exchange]));
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Exch'), findsOneWidget);
    });

    testWidgets('another contest running does not let this one in', (tester) async {
      // The gate is per ref type, not "is any contest active" — two contests
      // can be set up at once and only one may own a given field.
      await tester.pumpWidget(hostFor(running(['other-contest']), const [exchange]));
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Exch'), findsNothing);
    });

    testWidgets('a secondary chip is still offered from an operation running nothing', (tester) async {
      await tester.pumpWidget(hostFor(operation, const [hunter]));
      await tester.pump();
      expect(find.byIcon(MdiIcons.pineTree), findsOneWidget);
    });

    testWidgets('a serial from a contest that is not running allocates no number', (tester) async {
      // The severe case. A number issued here is spent forever — the counter
      // never rolls back — so a log for a contest the operator never entered
      // would silently consume the series.
      final repo = QsosRepository(db, sequences: SequencesRepository(db));
      await tester.pumpWidget(hostFor(operation, const [serial], repo: repo));
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Our #'), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1, repository: repo);
      expect(logged.single.refs, isEmpty, reason: 'no contest ref, and no number spent');
    });

    testWidgets("an inactive contest's exchange survives editing a QSO that carries it", (tester) async {
      // Removing the activity must not destroy what already went out on the
      // air. The field is hidden, so nothing can edit it — and it has to
      // round-trip untouched rather than being dropped on the next save.
      final existing = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'CW',
        'refs': [
          {'type': 'contest', 'exchange': 'MA 042'},
        ],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: baseLog(),
              session: LoggingSession(editingQso: existing),
              radio: baseRadio(),
              activities: ActivityHooks(activityControls: const [exchange]),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Exch'), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, 'Sent'), '579');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsosWhere(tester, 'the edited Sent', (logged) => logged.single.sentRST == '579');
      expect(logged.single.refs, [
        {'type': 'contest', 'exchange': 'MA 042'},
      ]);
    });
  });

  group('decorateQsoBeforeSave', () {
    // An activity's last chance to project data it owns into generic QSON
    // fields. It has to run on EVERY save path — a QSO decorated only when
    // logged one way would export differently depending on how it was typed.
    Widget hostWith(Future<Map<String, dynamic>> Function(Map<String, dynamic>, Map<String, dynamic>) decorate, {Qso? editing, List<Qso> log = const []}) =>
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: LogHooks(operation: operation, qsos: log, qsosRepository: qsos, decorateQsoBeforeSave: decorate),
              session: LoggingSession(editingQso: editing),
              radio: baseRadio(),
            ),
          ),
        );

    Future<Map<String, dynamic>> addExchange(Map<String, dynamic> qso, Map<String, dynamic> _) async => {
      ...qso,
      'their': {...(qso['their'] as Map?)?.cast<String, dynamic>() ?? {}, 'exchange': 'ZN5'},
    };

    testWidgets('decorates a single logged QSO', (tester) async {
      await tester.pumpWidget(hostWith(addExchange));
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.theirExchange, 'ZN5');
      expect(logged.single.theirCall, 'W1AW', reason: 'the patch must not clobber the callsign');
    });

    testWidgets('decorates every call of a call list, not just the first', (tester) async {
      await tester.pumpWidget(hostWith(addExchange));
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW,K1ABC,N1XYZ');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 3);
      expect(logged, hasLength(3));
      expect(logged.map((q) => q.theirExchange), everyElement('ZN5'));
    });

    testWidgets('decorates an edited QSO too', (tester) async {
      final existing = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'CW',
      });
      await tester.pumpWidget(hostWith(addExchange, editing: existing));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Sent'), '579');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsosWhere(tester, 'the edited Sent', (logged) => logged.single.sentRST == '579');
      expect(logged.single.theirExchange, 'ZN5');
    });

    testWidgets('the hook is handed the operation that was true when the contact was made', (tester) async {
      // A rover changes county at a `break`; a hook that projects "our county"
      // onto a contact has to see the segment the contact falls in, or an
      // EDIT of an old contact would carry it to wherever the operator is now
      // — which is exactly what stamping the county at save time used to
      // guard against, and what handing over the right operation makes
      // unnecessary.
      final breakRow = Qso(
        uuid: 'break',
        operationUuid: operation.uuid,
        data: {
          'band': 'event',
          'startAtMillis': 2000,
          'event': {
            'event': 'break',
            'operation': {
              'refs': [
                {'type': 'qp', 'location': 'WRRN'},
              ],
            },
          },
        },
      );
      final earlier = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'CW',
        'startAtMillis': 1000,
      });
      final seen = <String?>[];
      Future<Map<String, dynamic>> record(Map<String, dynamic> qso, Map<String, dynamic> op) async {
        final refs = (op['refs'] as List?) ?? const [];
        seen.add(refs.isEmpty ? null : (refs.first as Map)['location'] as String?);
        return qso;
      }

      Future<void> untilSeen(int count) async {
        for (var i = 0; i < 50 && seen.length < count; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
      }

      // Editing the contact made BEFORE the break: the base operation (which
      // carries no `qp` ref) is what was true then, not the break's county.
      await tester.pumpWidget(hostWith(record, editing: earlier, log: [earlier, breakRow]));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Sent'), '579');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await untilSeen(1);
      expect(seen, [null]);

      // A NEW contact belongs to the current segment — the county the break set.
      await tester.pumpWidget(hostWith(record, log: [earlier, breakRow]));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await untilSeen(2);
      expect(seen, [null, 'WRRN']);
    });

    testWidgets('a QSO still saves when no decorator is wired', (tester) async {
      // Every test and tooling path leaves it null; saving must not depend on it.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(log: baseLog(), radio: baseRadio()),
          ),
        ),
      );
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.theirCall, 'W1AW');
      expect(logged.single.theirExchange, isNull);
    });
  });

  testWidgets('activity text control folds a contest exchange into the logged QSO', (tester) async {
    // The on-air exchange is the whole point of a contest control: whatever the
    // operator types must reach the QSO's contest ref, or the log is unusable
    // for submission.
    const controls = [
      {
        'key': 'simple-contest/exchange',
        'label': 'Exch',
        'icon': 'flag-checkered',
        'input': {'kind': 'text', 'refType': 'simple-contest', 'field': 'exchange', 'placeholder': '59 001'},
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: LogHooks(operation: running(['simple-contest']), qsosRepository: qsos),
            radio: baseRadio(),
            activities: ActivityHooks(activityControls: controls),
          ),
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, 'Exch'), 'MA 042');
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.refs, [
      {'type': 'simple-contest', 'exchange': 'MA 042'},
    ]);

    // Logging wiped the field, so the next QSO starts clean rather than
    // silently repeating the previous station's exchange.
    final field = tester.widget<TextField>(find.widgetWithText(TextField, 'Exch'));
    expect(field.controller?.text, '');
  });

  testWidgets('the controls are refreshed again once the online lookup lands', (tester) async {
    // The offline pass knows the caller's COUNTRY; only the online one knows
    // their STATE — and a QSO party's suggestion is the state. Refreshed off
    // the offline pass alone, W1WA's field stayed blank until the operator
    // happened to retype the call and hit the cache.
    const exchange = {
      'key': 'c/exchange',
      'label': 'Exch',
      'icon': 'flag-checkered',
      'input': {'kind': 'text', 'refType': 'c', 'field': 'exchange'},
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: LogHooks(operation: running(['c']), qsosRepository: qsos),
            radio: baseRadio(),
            lookups: LookupHooks(
              lookup: (call, {required qso, required operation, required online, recentContext = false}) async => {
                'guess': online ? {'state': 'MA'} : <String, dynamic>{},
              },
            ),
            activities: ActivityHooks(
              activityControls: const [exchange],
              // The hint is whatever state the QSO carries when asked — the shape
              // a QSO party's control takes.
              refreshActivityControls: (qso) async {
                final state = ((qso['their'] as Map?)?['guess'] as Map?)?['state'] as String?;
                return [
                  {
                    ...exchange,
                    'input': {...exchange['input'] as Map, 'placeholder': ?state},
                  },
                ];
              },
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1WA');
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.widgetWithText(TextField, 'Exch'));
    expect(field.decoration?.hintText, 'MA', reason: 'the state arrived with the online pass, and was asked for');
  });

  group('a prefill and the callsign it was made for', () {
    const exchange = {
      'key': 'c/exchange',
      'label': 'Exch',
      'icon': 'flag-checkered',
      'input': {'kind': 'text', 'refType': 'c', 'field': 'exchange'},
    };

    /// A contest that suggests `CA` for W6ABC and cannot fetch at all for
    /// anybody else — the refresh a withdrawal must not depend on.
    Future<void> pumpPanel(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: LogHooks(operation: running(['c']), qsosRepository: qsos),
              radio: baseRadio(),
              lookups: LookupHooks(
                lookup: (call, {required qso, required operation, required online, recentContext = false}) async => {'guess': <String, dynamic>{}},
              ),
              activities: ActivityHooks(
                activityControls: const [exchange],
                refreshActivityControls: (qso) async => (qso['their'] as Map?)?['call'] == 'W6ABC'
                    ? [
                        {
                          ...exchange,
                          'input': {...exchange['input'] as Map, 'suggestedValue': 'CA'},
                        },
                      ]
                    : null,
              ),
            ),
          ),
        ),
      );
    }

    String exch(WidgetTester tester) => tester.widget<TextField>(find.widgetWithText(TextField, 'Exch')).controller!.text;

    testWidgets('is taken back when the call is corrected, even if nothing is fetched for the new one', (tester) async {
      // Correcting W6ABC to K2XYZ whose refresh fails: nothing refreshes, so a
      // withdrawal that waited on a refresh would leave `CA` in an untouched
      // field — a legal code nothing tints, logged as K2XYZ's exchange.
      await pumpPanel(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W6ABC');
      await tester.pumpAndSettle();
      expect(exch(tester), 'CA');

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K2XYZ');
      await tester.pumpAndSettle();
      expect(exch(tester), '', reason: "W6ABC's exchange must not be logged for K2XYZ");
    });

    // The refresh carrying the suggestion is its own round trip after the
    // lookup, and lands after the lookup's rescore has read the field empty:
    // without a rescore of its own, the verdict on the empty exchange stands
    // — a missing-exchange alert under a field that visibly holds one.
    testWidgets('is scored, even when it lands after the lookup\'s own rescore', (tester) async {
      final scored = <Object?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: LogHooks(operation: running(['c']), qsosRepository: qsos),
              radio: baseRadio(),
              lookups: LookupHooks(
                lookup: (call, {required qso, required operation, required online, recentContext = false}) async => {'guess': <String, dynamic>{}},
                scoreQso: ({required operation, required qso, excludeUuid, segments}) async {
                  final refs = (qso['refs'] as List?) ?? const [];
                  scored.add(refs.whereType<Map>().where((ref) => ref['type'] == 'c').firstOrNull?['exchange']);
                  return {'notices': <String>[], 'alerts': <String>[]};
                },
              ),
              activities: ActivityHooks(
                activityControls: const [exchange],
                refreshActivityControls: (qso) async {
                  await Future<void>.delayed(const Duration(seconds: 1));
                  return [
                    {
                      ...exchange,
                      'input': {...exchange['input'] as Map, 'suggestedValue': 'CA'},
                    },
                  ];
                },
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W6ABC');
      await tester.pump(const Duration(milliseconds: 900));
      expect(scored, isNotEmpty);
      expect(scored.last, isNull, reason: 'the lookup has landed and been scored; the suggestion has not');
      await tester.pump(const Duration(seconds: 1));
      expect(exch(tester), 'CA');
      await tester.pump(const Duration(milliseconds: 300));
      expect(scored.last, 'CA');
    });

    // A field holding several calls still has one call the lookup ran for;
    // refusing to prefill there leaves that station's exchange unsuggested.
    testWidgets('is made for the call under the cursor in a list', (tester) async {
      await pumpPanel(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K2XYZ,W6ABC');
      await tester.pumpAndSettle();
      expect(exch(tester), 'CA');
    });

    testWidgets('is taken back when the cursor moves to another call in a list', (tester) async {
      await pumpPanel(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K2XYZ,W6ABC');
      await tester.pumpAndSettle();
      expect(exch(tester), 'CA');

      final call = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!;
      call.selection = const TextSelection.collapsed(offset: 2);
      await tester.pumpAndSettle();
      expect(exch(tester), '', reason: "the lookup now runs for K2XYZ, and W6ABC's exchange must not stand in for it");
    });

    // Stepping off a call and back before the other call's lookup lands
    // leaves W6ABC's lookup current, so nothing is fetched again: the prefill
    // the step away took back has to come back from the controls in force.
    testWidgets('comes back when the cursor returns before another lookup lands', (tester) async {
      await pumpPanel(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K2XYZ,W6ABC');
      await tester.pumpAndSettle();
      expect(exch(tester), 'CA');

      final call = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!;
      call.selection = const TextSelection.collapsed(offset: 2);
      await tester.pump();
      expect(exch(tester), '');
      call.selection = TextSelection.collapsed(offset: call.text.length);
      await tester.pumpAndSettle();
      expect(exch(tester), 'CA');
    });

    testWidgets('is made for the stacked call Enter would log', (tester) async {
      await pumpPanel(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K2XYZ//W6ABC');
      await tester.pumpAndSettle();
      expect(exch(tester), 'CA');
    });

    testWidgets('is taken back when the cursor moves to another stacked call', (tester) async {
      await pumpPanel(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K2XYZ//W6ABC');
      await tester.pumpAndSettle();
      expect(exch(tester), 'CA');

      final call = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!;
      call.selection = const TextSelection.collapsed(offset: 2);
      await tester.pumpAndSettle();
      expect(exch(tester), '', reason: "Enter now logs K2XYZ, and W6ABC's exchange must not go with it");
    });
  });

  group('a refresh that could not fetch', () {
    // `refreshActivityControls` fires when a callsign lookup resolves, mid-QSO,
    // while the operator is typing. Its result is installed over
    // `activityControls` — so a fan-out that failed and answered with an empty
    // list would take every activity field off the panel with no message. Null
    // is how "I could not fetch them" is said; an empty list still means "no
    // controls for this QSO" and must keep working.
    const exchange = {
      'key': 'c/exchange',
      'label': 'Exch',
      'icon': 'flag-checkered',
      'input': {'kind': 'text', 'refType': 'c', 'field': 'exchange'},
    };

    Future<void> pumpTyping(
      WidgetTester tester,
      Future<List<Map<String, dynamic>>?> Function(Map<String, dynamic>) refresh, {
      List<Map<String, dynamic>> panelControls = const [],
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: LogHooks(operation: running(['c']), qsosRepository: qsos),
              radio: baseRadio(),
              lookups: LookupHooks(
                lookup: (call, {required qso, required operation, required online, recentContext = false}) async => {'guess': <String, dynamic>{}},
              ),
              activities: ActivityHooks(activityControls: panelControls, refreshActivityControls: refresh),
            ),
          ),
        ),
      );
    }

    testWidgets('a later failure keeps what an earlier refresh fetched', (tester) async {
      // The panel-level set is EMPTY here on purpose. Assigning null on
      // failure would look harmless — `ActivityRefsModel.controls` falls back
      // to `widget.activityControls` — which is exactly why the fallback must
      // not be the thing under test: with nothing to fall back to, dropping
      // the guard takes the field away and only this shape notices.
      var call = 0;
      await pumpTyping(tester, (_) async => call++ == 0 ? [exchange] : null);

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Exch'), findsOneWidget, reason: 'the first refresh fetched it');

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Exch'), findsOneWidget, reason: 'a refresh that could not fetch must not blank the QSO in progress');
    });

    testWidgets('an empty answer still means the activities want no controls', (tester) async {
      // The mutation this catches: folding empty in with null would make a
      // control impossible to remove for a QSO once it had been shown.
      // Keyed on the callsign, not on how many times it was asked: a call is
      // refreshed once per lookup pass, and a counter would read the second
      // pass for W1AW as the answer for K1ABC.
      await pumpTyping(tester, (qso) async => (qso['their'] as Map?)?['call'] == 'W1AW' ? [exchange] : const []);

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Exch'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Exch'), findsNothing);
    });

    testWidgets('a ref added to the operation is not shadowed by an earlier empty refresh', (tester) async {
      // The scenario the refs model's refreshed set traps: a callsign lookup
      // resolved BEFORE the contest was added to the operation, caching an
      // empty per-QSO refresh. Adding the contest gives the operation a fresh
      // `activityControls` list — that has to win, not the stale cache, or
      // the exchange field stays invisible for the rest of the session.
      await pumpTyping(tester, (_) async => const []);

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Exch'), findsNothing, reason: 'nothing configured yet');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: LogHooks(operation: running(['c']), qsosRepository: qsos),
              radio: baseRadio(),
              lookups: LookupHooks(
                lookup: (call, {required qso, required operation, required online, recentContext = false}) async => {'guess': <String, dynamic>{}},
              ),
              activities: ActivityHooks(
                activityControls: const [exchange],
                // A real per-QSO refresh reads the same operation data the
                // operation-level one does, so it agrees once the ref exists —
                // this isn't the fixed-forever-empty callback pumpTyping's other
                // tests use, because a resolved lookup re-fires this on the ref
                // add (see the test below), and that has to see the new field
                // too rather than race the operation-level fetch to install it.
                refreshActivityControls: (_) async => const [exchange],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Exch'), findsOneWidget, reason: "the operation's own refresh must not be shadowed by the stale per-QSO one");
    });

    testWidgets('a per-QSO refresh already in flight when a ref is added cannot reshadow it on return', (tester) async {
      // Distinct from the test above: there the stale refresh had already
      // LANDED before the ref was added. Here it's still IN FLIGHT — issued
      // before, resolving after. Two guards stop it here, because the ref add
      // also re-issues a refresh: the generation it started against, and the
      // refresh ticket, which the newer refresh has moved past. This test is
      // the end-to-end property; the generation guard on its own — a
      // `controlsChanged` with no refresh issued after it — is pinned in
      // activity_refs_model_test.dart.
      final completers = <Completer<List<Map<String, dynamic>>?>>[];
      await pumpTyping(tester, (_) {
        final completer = Completer<List<Map<String, dynamic>>?>();
        completers.add(completer);
        return completer.future;
      });

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump(const Duration(milliseconds: 300)); // past the lookup debounce
      await tester.pump(); // the lookup resolves and a refresh is issued per pass
      // Every refresh issued before the ref is added is stale once it is — how
      // many there are depends on how many lookup passes landed, which is not
      // what this test is about.
      final staleCount = completers.length;
      expect(staleCount, greaterThan(0));

      // The ref is added — a fresh `activityControls` identity — WHILE
      // refresh #1 is still pending. Per the fix above, that also re-issues
      // a refresh (#2) against the new activityControls, since a lookup is
      // already resolved for the active call.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: LogHooks(operation: running(['c']), qsosRepository: qsos),
              radio: baseRadio(),
              lookups: LookupHooks(
                lookup: (call, {required qso, required operation, required online, recentContext = false}) async => {'guess': <String, dynamic>{}},
              ),
              activities: ActivityHooks(
                activityControls: const [exchange],
                refreshActivityControls: (_) {
                  final completer = Completer<List<Map<String, dynamic>>?>();
                  completers.add(completer);
                  return completer.future;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(completers, hasLength(staleCount + 1), reason: 'adding the ref re-issued a refresh for the resolved lookup');

      // Resolve the stale, pre-ref-add refreshes AFTER the fresh one — the
      // actual race, not just calls that happen to finish in issue order.
      completers.last.complete(const [exchange]);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Exch'), findsOneWidget, reason: 'the fresh refresh landed');

      for (final stale in completers.take(staleCount)) {
        stale.complete(const []);
      }
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Exch'), findsOneWidget, reason: 'the stale refresh landing late must not blank the field the fresh one just set');
    });
  });

  group('clearing an exchange', () {
    // An empty field means two different things and a contest has to tell them
    // apart: never filled in, or emptied on purpose. Only the latter is
    // recorded, as `field: ''`, and that record is the only thing stopping
    // `processQsoBeforeSave` from guessing the value straight back.
    const clearingControls = [
      {
        'key': 'c/exchange',
        'label': 'Exch',
        'icon': 'flag-checkered',
        'input': {'kind': 'text', 'refType': 'c', 'field': 'exchange'},
      },
    ];

    Widget clearingHost({Qso? editing}) => MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          log: LogHooks(operation: running(['c']), qsosRepository: qsos, qsos: editing == null ? const [] : [editing]),
          session: LoggingSession(editingQso: editing),
          radio: baseRadio(),
          activities: ActivityHooks(activityControls: clearingControls),
        ),
      ),
    );

    testWidgets('a field never filled in leaves no trace on the ref', (tester) async {
      await tester.pumpWidget(clearingHost());
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.refs, isEmpty, reason: 'an untouched empty field is not a decision');
    });

    testWidgets('a field the operator empties is recorded as an explicit blank', (tester) async {
      await tester.pumpWidget(clearingHost());
      await tester.enterText(find.widgetWithText(TextField, 'Exch'), 'MA');
      await tester.pump();
      // …thought better of it.
      await tester.enterText(find.widgetWithText(TextField, 'Exch'), '');
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.refs, [
        {'type': 'c', 'exchange': ''},
      ]);
    });

    testWidgets('reopening a QSO with a blanked exchange restores it as blank', (tester) async {
      // The other half: an explicit blank comes back as operator input, so a
      // lookup resolving after the record opens cannot helpfully fill it.
      final existing = Qso(
        uuid: 'existing',
        operationUuid: operation.uuid,
        data: {
          'their': {'call': 'W1AW'},
          'band': '20m',
          'mode': 'CW',
          'refs': [
            {'type': 'c', 'exchange': ''},
          ],
        },
      );
      await tester.pumpWidget(clearingHost(editing: existing));
      await tester.pump(const Duration(milliseconds: 500));

      final field = tester.widget<TextField>(find.widgetWithText(TextField, 'Exch'));
      expect(field.controller?.text, '');
    });
  });

  testWidgets('a text control uppercases by default, and honours uppercase:false', (tester) async {
    // Contest exchanges are conventionally uppercase, and every other logging
    // field forces it — a lowercase state would also fail a case-sensitive
    // pattern. Names are the exception, hence the opt-out.
    const controls = [
      {
        'key': 'c/state',
        'label': 'St',
        'icon': 'flag-checkered',
        'input': {'kind': 'text', 'refType': 'c', 'field': 'state'},
      },
      {
        'key': 'c/name',
        'label': 'Name',
        'icon': 'pound',
        'input': {'kind': 'text', 'refType': 'c', 'field': 'name', 'uppercase': false},
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: LogHooks(operation: running(['c']), qsosRepository: qsos),
            radio: baseRadio(),
            activities: ActivityHooks(activityControls: controls),
          ),
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, 'St'), 'ma');
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Steve');
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.refs.single['state'], 'MA');
    expect(logged.single.refs.single['name'], 'Steve');
  });

  testWidgets('clearing a text control blanks the field on the ref', (tester) async {
    // Blanking an exchange while editing has to actually blank it — otherwise
    // the old value silently stays in the log and gets exported.
    //
    // It is recorded as `exchange: ''` rather than dropped, which is a change
    // from simply removing it: a contest guesses an exchange onto an ABSENT
    // field at save (docs/design/contests.md §8), so a removed field would be
    // indistinguishable from one never filled in, and the value the operator
    // just deleted would come straight back.
    const controls = [
      {
        'key': 'c/exchange',
        'label': 'Exch',
        'icon': 'flag-checkered',
        'input': {'kind': 'text', 'refType': 'c', 'field': 'exchange'},
      },
    ];

    final existing = await qsos.add(operation.uuid, {
      'their': {'call': 'W1AW'},
      'band': '20m',
      'mode': 'SSB',
      'startAtMillis': 1000,
      'refs': [
        {'type': 'c', 'exchange': 'MA'},
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: LogHooks(operation: running(['c']), qsosRepository: qsos),
            session: LoggingSession(editingQso: existing),
            radio: baseRadio(),
            activities: ActivityHooks(activityControls: controls),
          ),
        ),
      ),
    );
    await tester.pump();

    // The saved value is restored into the field...
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Exch')).controller?.text, 'MA');

    await tester.enterText(find.widgetWithText(TextField, 'Exch'), '');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final stored = (await waitForQsosWhere(
      tester,
      'the cleared exchange',
      (logged) => logged.single.refs.any((r) => r['type'] == 'c' && r['exchange'] == ''),
    )).single;
    final ref = stored.refs.firstWhere((r) => r['type'] == 'c');
    expect(ref['exchange'], '', reason: 'the old value must not survive, and the blank must be recorded');
  });

  testWidgets('two text controls sharing a ref type merge into one ref', (tester) async {
    // A contest's setup writes several fields of the SAME ref, so they must
    // merge rather than the last one winning.
    const controls = [
      {
        'key': 'simple-contest/exchange',
        'label': 'Exch',
        'icon': 'flag-checkered',
        'input': {'kind': 'text', 'refType': 'simple-contest', 'field': 'exchange'},
      },
      {
        'key': 'simple-contest/serial',
        'label': 'Nr',
        'icon': 'pound',
        'input': {'kind': 'text', 'refType': 'simple-contest', 'field': 'serial', 'numeric': true},
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: LogHooks(operation: running(['simple-contest']), qsosRepository: qsos),
            radio: baseRadio(),
            activities: ActivityHooks(activityControls: controls),
          ),
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, 'Exch'), 'MA');
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Nr'), '042');
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.refs, [
      {'type': 'simple-contest', 'exchange': 'MA', 'serial': '042'},
    ]);
  });

  testWidgets('activity refList control folds refs into the logged QSO', (tester) async {
    const controls = [
      {
        'key': 'pota/hunter',
        'label': 'POTA',
        'icon': 'pine-tree',
        'input': {'kind': 'refList', 'refType': 'pota', 'placeholder': 'US-1234', 'pattern': r'[A-Z0-9]+-[0-9]{4,5}'},
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            activities: ActivityHooks(activityControls: controls),
          ),
        ),
      ),
    );
    await openControl(tester, MdiIcons.pineTree);

    await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'US-1234');
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.refs, [
      {'type': 'pota', 'ref': 'US-1234'},
    ]);

    // Wipe cleared the control's field too.
    await openControl(tester, MdiIcons.pineTree);
    final potaField = tester.widget<TextField>(find.widgetWithText(TextField, 'POTA'));
    expect(potaField.controller?.text, '');
  });

  // A reference the pattern rejects is kept and logged, so the chip counts it
  // and reads "✓ POTA" like any other. The tint that says otherwise lives in
  // the expanded field — and the field is shut for most of a QSO, and shut
  // again the moment the contact is logged. Without the chip's own mark the
  // operator is left a check mark over the one reference needing attention.
  testWidgets('the activity chip wears the error pair while a reference fails its pattern', (tester) async {
    const controls = [
      {
        'key': 'pota/hunter',
        'label': 'POTA',
        'icon': 'pine-tree',
        'color': '#00AA00',
        'input': {'kind': 'refList', 'refType': 'pota', 'pattern': r'[A-Z0-9]+-[0-9]{4,5}'},
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            activities: ActivityHooks(activityControls: controls),
          ),
        ),
      ),
    );
    await openControl(tester, MdiIcons.pineTree);

    ChoiceChip potaChip() => tester.widget<ChoiceChip>(find.ancestor(of: find.text('✓ POTA'), matching: find.byType(ChoiceChip)).first);

    final scheme = Theme.of(tester.element(find.byType(LoggingControls))).colorScheme;

    await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'NOT-A-PARK');
    await tester.pump();
    expect(potaChip().selectedColor, scheme.error, reason: 'open chip alerts');

    // Shut, which is how the chip spends most of a QSO — the state in which it
    // is the ONLY thing that can report this.
    await openControl(tester, MdiIcons.pineTree);
    expect(
      tester.widget<ChoiceChip>(find.ancestor(of: find.text('✓ POTA'), matching: find.byType(ChoiceChip)).first).backgroundColor,
      scheme.errorContainer,
      reason: 'closed chip alerts',
    );

    // And it clears: correcting the code takes the alert away rather than
    // leaving the chip red for the rest of the operation.
    await openControl(tester, MdiIcons.pineTree);
    await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'US-1234');
    await tester.pump();
    expect(potaChip().selectedColor, isNot(scheme.error));
  });

  testWidgets("activity control's chip icon accents to the extension's color once a reference is entered (issue #187)", (tester) async {
    const controls = [
      {
        'key': 'pota/hunter',
        'label': 'POTA',
        'icon': 'pine-tree',
        'color': '#068541',
        'input': {'kind': 'refList', 'refType': 'pota', 'placeholder': 'US-1234', 'pattern': r'[A-Z0-9]+-[0-9]{4,5}'},
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            activities: ActivityHooks(activityControls: controls),
          ),
        ),
      ),
    );

    // No reference yet: the icon stays the default theme color, not the
    // extension's accent — the accent marks a filled-in field.
    Color? iconColor() => tester.widget<Icon>(find.byIcon(MdiIcons.pineTree)).color;
    expect(iconColor(), isNot(const Color(0xFF068541)));

    await openControl(tester, MdiIcons.pineTree);

    // Still open, no reference yet: no accent.
    expect(iconColor(), isNot(const Color(0xFF068541)));

    await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'US-1234');
    await tester.pump();

    // Still open, but the entered text now matches the control's own
    // pattern and has been accepted as a reference: the accent shows even
    // while the panel is expanded (issue #187 follow-up).
    expect(iconColor(), const Color(0xFF068541));
    // A single reference gets a single check ahead of the label.
    expect(find.text('✓ POTA'), findsOneWidget);

    await openControl(tester, MdiIcons.pineTree); // close the panel

    // Closed: the accent stays.
    expect(iconColor(), const Color(0xFF068541));
    expect(find.text('✓ POTA'), findsOneWidget);
  });

  testWidgets('activity control chip label gets a check per reference, or a check plus count past two (issue #187 follow-up)', (tester) async {
    const controls = [
      {
        'key': 'pota/hunter',
        'label': 'POTA',
        'icon': 'pine-tree',
        'color': '#068541',
        'input': {'kind': 'refList', 'refType': 'pota', 'placeholder': 'US-1234', 'pattern': r'[A-Z0-9]+-[0-9]{4,5}'},
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            activities: ActivityHooks(activityControls: controls),
          ),
        ),
      ),
    );

    // No reference yet: plain label.
    expect(find.text('POTA'), findsOneWidget);

    await openControl(tester, MdiIcons.pineTree);

    // A twofer (two parks activated together) gets two checks, not "×2" —
    // it's the common case worth spelling out rather than abbreviating.
    await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'US-1234, US-5678');
    await tester.pump();
    expect(find.text('✓✓ POTA'), findsOneWidget);

    // A third reference collapses to a single check plus the total count,
    // so the label doesn't grow one glyph per park on a bigger rove.
    await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'US-1234, US-5678, US-9012');
    await tester.pump();
    expect(find.text('✓×3 POTA'), findsOneWidget);
  });

  testWidgets('activity refList control accepts a comma-separated list of references', (tester) async {
    const controls = [
      {
        'key': 'pota/hunter',
        'label': 'POTA',
        'icon': 'pine-tree',
        'input': {'kind': 'refList', 'refType': 'pota', 'placeholder': 'US-1234', 'pattern': r'[A-Z0-9]+-[0-9]{4,5}'},
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            activities: ActivityHooks(activityControls: controls),
          ),
        ),
      ),
    );
    await openControl(tester, MdiIcons.pineTree);

    await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'US-1234, US-5678');
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.refs, [
      {'type': 'pota', 'ref': 'US-1234'},
      {'type': 'pota', 'ref': 'US-5678'},
    ]);
  });
}
