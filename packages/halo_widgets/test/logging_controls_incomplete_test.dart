// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A scorer holding a contact back until it has the fields its rules need
// (docs/design/logging-fields.md § An incomplete exchange): what Enter refuses,
// what it says, and the two ways past it — a `?` and Shift.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

void main() {
  installLoggingHarness();

  const exchange = {
    'key': 'contest/exchange',
    'label': 'Exch',
    'icon': 'flag-checkered',
    'input': {'kind': 'text', 'refType': 'contest', 'field': 'exchange'},
  };
  const name = {
    'key': 'contest/name',
    'label': 'Name',
    'icon': 'flag-checkered',
    'input': {'kind': 'text', 'refType': 'contest', 'field': 'name'},
  };

  /// A contest that needs its exchange, and says so the way a scorer does.
  Future<Map<String, dynamic>?> scorer({
    required Map<String, dynamic> operation,
    required Map<String, dynamic> qso,
    String? excludeUuid,
    List<Map<String, dynamic>>? segments,
  }) async {
    final ref = ((qso['refs'] as List?) ?? const []).whereType<Map>().where((ref) => ref['type'] == 'contest').firstOrNull;
    final copied = '${ref?['exchange'] ?? ''}'.trim().isNotEmpty;
    return {
      'notices': <String>[],
      'alerts': <String>[],
      if (!copied) 'incomplete': ['contest/exchange'],
    };
  }

  /// One that needs the report they actually gave us (QSON `their.sent`),
  /// not the default the field carries.
  Future<Map<String, dynamic>?> reportScorer({
    required Map<String, dynamic> operation,
    required Map<String, dynamic> qso,
    String? excludeUuid,
    List<Map<String, dynamic>>? segments,
  }) async {
    final report = '${(qso['their'] as Map?)?['sent'] ?? ''}'.trim();
    return {
      'notices': <String>[],
      'alerts': <String>[],
      if (report != '559') 'incomplete': ['rcvd'],
    };
  }

  /// One that cannot answer at all.
  Future<Map<String, dynamic>?> failingScorer({
    required Map<String, dynamic> operation,
    required Map<String, dynamic> qso,
    String? excludeUuid,
    List<Map<String, dynamic>>? segments,
  }) async => throw StateError('scorer down');

  /// One that needs their state, which the callbook's guess supplies.
  Future<Map<String, dynamic>?> stateScorer({
    required Map<String, dynamic> operation,
    required Map<String, dynamic> qso,
    String? excludeUuid,
    List<Map<String, dynamic>>? segments,
  }) async {
    final their = (qso['their'] as Map?) ?? const {};
    final state = '${their['state'] ?? (their['guess'] as Map?)?['state'] ?? ''}'.trim();
    return {
      'notices': <String>[],
      'alerts': <String>[],
      if (state.isEmpty) 'incomplete': ['state'],
    };
  }

  /// One that needs the app's own Grid field, which the operator can hide.
  Future<Map<String, dynamic>?> gridScorer({
    required Map<String, dynamic> operation,
    required Map<String, dynamic> qso,
    String? excludeUuid,
    List<Map<String, dynamic>>? segments,
  }) async {
    final grid = '${(qso['their'] as Map?)?['grid'] ?? ''}'.trim();
    return {
      'notices': <String>[],
      'alerts': <String>[],
      if (grid.isEmpty) 'incomplete': ['grid'],
    };
  }

  Widget panel({
    LoggingSession? session,
    List<Map<String, dynamic>> controls = const [exchange],
    ScoreQso? score,
    CallLookup? lookup,
    Operation? op,
    List<Qso> log = const [],
  }) => host(
    log: LogHooks(operation: op ?? running(['contest']), qsos: log, qsosRepository: qsos),
    session: session,
    lookups: LookupHooks(scoreQso: score ?? scorer, lookup: lookup),
    activities: ActivityHooks(activityControls: controls),
  );

  Finder field(String label) => find.widgetWithText(TextField, label);

  // The engine's Enter, not `sendKeyEvent`, which reaches the panel's shortcut
  // without finalizing the editing session (§ Enter and focus).
  Future<void> enter(WidgetTester tester, {bool shift = false}) async {
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
  }

  Future<List<Qso>> logged(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    return (await tester.runAsync(() => qsos.watchForOperation(operation.uuid).first))!;
  }

  bool focused(WidgetTester tester, String label) => tester.widget<TextField>(field(label)).focusNode?.hasFocus ?? false;

  testWidgets('Enter on a contact missing its exchange logs nothing, says what is missing, and goes there', (tester) async {
    await tester.pumpWidget(panel());
    await tester.pump();
    await tester.enterText(field('Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 400));
    await enter(tester);
    await tester.pump();

    expect(await logged(tester), isEmpty);
    expect(find.textContaining('Fill in Exch'), findsOneWidget);
    expect(focused(tester, 'Exch'), isTrue, reason: 'the field to fill is where the next keystroke goes');
  });

  // The held verdict is for the entry before the last keystroke until the
  // debounce has run: judged on it, the Enter that follows the exchange
  // without a pause is refused for a field that visibly holds one.
  testWidgets('an Enter straight after the exchange is typed is judged on the exchange', (tester) async {
    await tester.pumpWidget(panel());
    await tester.pump();
    await tester.enterText(field('Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(field('Exch'), 'MA');
    await enter(tester);

    final saved = await logged(tester);
    expect(saved, hasLength(1));
    expect(find.textContaining('Fill in'), findsNothing);
  });

  testWidgets('a ? in the exchange logs the contact as typed', (tester) async {
    await tester.pumpWidget(panel(controls: const [name, exchange]));
    await tester.pump();
    await tester.enterText(field('Their call'), 'W1AW');
    await tester.enterText(field('Name'), '?');
    await tester.pump(const Duration(milliseconds: 400));
    await enter(tester);

    final saved = await logged(tester);
    expect(saved, hasLength(1), reason: 'a ? in any field is the operator saying they did not copy it');
    expect(saved.single.refs.single['name'], '?');
  });

  testWidgets('Shift+Enter logs it as it stands', (tester) async {
    await tester.pumpWidget(panel());
    await tester.pump();
    await tester.enterText(field('Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 400));
    await enter(tester, shift: true);

    expect(await logged(tester), hasLength(1));
  });

  // The refusal is a log-time decision; a TU keyed for a contact that then
  // stays in the entry row thanks a station still being worked.
  testWidgets('with Enter Sends Messages on, the exchange is still asked for, and a refused contact keys no thanks', (tester) async {
    final sent = <String>[];
    final session = LoggingSession(
      enterSends: () => EnterSends(running: true, send: (messages, qso, {logged}) => sent.add(messages.map((m) => m.name).join('+'))),
    );
    await tester.pumpWidget(panel(session: session, controls: const [name, exchange]));
    await tester.pump();
    await tester.enterText(field('Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 400));
    await enter(tester);
    await tester.pump();
    expect(sent, ['hisCall+exchange'], reason: 'answering the caller is how the exchange gets copied');

    await tester.enterText(field('Name'), 'BOB');
    await tester.pump(const Duration(milliseconds: 400));
    await enter(tester);
    await tester.pump();

    expect(sent, ['hisCall+exchange'], reason: 'no TU for a contact that is not logged');
    expect(await logged(tester), isEmpty);
    expect(find.textContaining('Fill in Exch'), findsOneWidget);
  });

  // An edit is where a contact logged past the gate gets repaired, so it is
  // held to the same rule — and Shift still has the last word.
  testWidgets('saving an edit is held back the same way', (tester) async {
    final existing = (await tester.runAsync(
      () => qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'CW',
        'refs': [
          {'type': 'contest', 'exchange': 'MA'},
        ],
      }),
    ))!;
    await tester.pumpWidget(panel(session: LoggingSession(editingQso: existing)));
    await tester.pump();
    await tester.enterText(field('Exch'), '');
    await tester.pump(const Duration(milliseconds: 400));
    await enter(tester);
    await tester.pump();

    expect(find.textContaining('Fill in Exch'), findsOneWidget);
    expect((await logged(tester)).single.refs.single['exchange'], 'MA', reason: 'the edit was not saved');

    await enter(tester, shift: true);
    expect((await logged(tester)).single.refs.single['exchange'], anyOf(isNull, ''));
  });

  // The slid spot row logs from a surface where neither the message nor the
  // field is in sight: held back there and left, it is a contact the operator
  // believes they made.
  testWidgets('a spot slid to log that is held back brings the panel forward, at the field to fill', (tester) async {
    var held = 0;
    LoggingSession session({int? serial}) => LoggingSession(
      logRequest: serial == null
          ? null
          : (
              serial: serial,
              qso: const {
                'their': {'call': 'W1AW'},
                'band': '20m',
                'mode': 'CW',
              },
            ),
      onLogRequestHeld: () => held++,
    );
    await tester.pumpWidget(panel(session: session()));
    await tester.pump();
    await tester.pumpWidget(panel(session: session(serial: 1)));
    await tester.pump();

    expect(await logged(tester), isEmpty);
    expect(held, 1);
    expect(find.textContaining('Fill in Exch'), findsOneWidget);
    expect(focused(tester, 'Exch'), isTrue, reason: 'the panel came forward for this field');
  });

  // A field Enter waits on and the operator cannot see leaves only Shift or a
  // `?` as the way on. And once shown it stays: a field that went away again
  // as soon as it held a value would be gone while it is being typed into.
  testWidgets('a hidden field a scorer asks for is shown, and stays once filled in', (tester) async {
    await tester.pumpWidget(panel(controls: const [], score: gridScorer));
    await tester.pump();
    expect(field('Grid'), findsNothing, reason: 'the operator hid it, and nothing has asked for it yet');

    await tester.enterText(field('Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 400));
    expect(field('Grid'), findsOneWidget);

    await tester.enterText(field('Grid'), 'FN31');
    await tester.pump(const Duration(milliseconds: 400));
    expect(field('Grid'), findsOneWidget);

    await enter(tester);
    expect(((await logged(tester)).single.data['their'] as Map)['grid'], 'FN31');
  });

  // A report edit schedules no score, so the verdict held after it still
  // names the field the operator just filled. Refusing on that verdict keeps
  // refusing a contact that visibly holds what was asked for.
  testWidgets('a field filled since the verdict that named it is judged as filled', (tester) async {
    await tester.pumpWidget(panel(controls: const [], score: reportScorer));
    await tester.pump();
    await tester.enterText(field('Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 400));
    await enter(tester);
    await tester.pump();
    expect(find.textContaining('Fill in Rcvd'), findsOneWidget);

    await tester.enterText(field('Rcvd'), '559');
    await tester.pump(const Duration(milliseconds: 400));
    await enter(tester);

    expect(await logged(tester), hasLength(1));
  });

  testWidgets('a scorer that fails holds nothing back', (tester) async {
    await tester.pumpWidget(panel(score: failingScorer));
    await tester.pump();
    await tester.enterText(field('Their call'), 'W1AW');
    expect(tester.takeException(), isStateError, reason: 'the pills\' own pass, scored at the keystroke');
    await enter(tester);

    expect(await logged(tester), hasLength(1), reason: 'a broken extension must not stop the operator logging');
    expect(tester.takeException(), isStateError, reason: 'the Enter\'s failure is reported too');
  });

  // The row and the score are the current segment's; a contact from before
  // the contest started was never in it, and an edit to it cannot owe the
  // contest an exchange.
  testWidgets('an edit to a contact from an earlier segment is not held to the current one\'s exchange', (tester) async {
    final start = Qso(
      uuid: 'start',
      operationUuid: operation.uuid,
      data: {
        'band': 'event',
        'startAtMillis': 2000,
        'event': {
          'event': 'start',
          'operation': {
            'refs': [
              {'type': 'contest'},
            ],
          },
        },
      },
    );
    final earlier = (await tester.runAsync(
      () => qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'CW',
        'startAtMillis': 1000,
      }),
    ))!;
    await tester.pumpWidget(
      panel(
        session: LoggingSession(editingQso: earlier),
        op: operation,
        log: [earlier, start],
      ),
    );
    await tester.pump();
    await tester.enterText(field('Sent'), '579');
    await tester.pump(const Duration(milliseconds: 400));
    await enter(tester);

    expect(find.textContaining('Fill in'), findsNothing);
    expect((await logged(tester)).single.sentRST, '579');
  });

  // A slid spot is logged the moment it lands, before the callbook has
  // answered. Refused for the state that answer brings, the operator is sent
  // to type what the app was about to know.
  testWidgets('a field the callbook guesses is waited for before the contact is held for it', (tester) async {
    Future<Map<String, dynamic>?> lookup(
      String call, {
      required Map<String, dynamic> qso,
      required Map<String, dynamic> operation,
      required bool online,
      bool recentContext = false,
    }) async {
      if (!online) return {'guess': <String, dynamic>{}};
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return {
        'guess': {'state': 'CT'},
      };
    }

    LoggingSession session({int? serial}) => LoggingSession(
      logRequest: serial == null
          ? null
          : (
              serial: serial,
              qso: const {
                'their': {'call': 'W1AW'},
                'band': '20m',
                'mode': 'CW',
              },
            ),
    );
    await tester.pumpWidget(panel(session: session(), controls: const [], score: stateScorer, lookup: lookup));
    await tester.pump();
    await tester.pumpWidget(panel(session: session(serial: 1), controls: const [], score: stateScorer, lookup: lookup));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.textContaining('Fill in'), findsNothing);
    expect(await logged(tester), hasLength(1));
  });
}
