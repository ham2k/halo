// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Enter Sends Messages (docs/design/logging-fields.md § Enter Sends Messages):
// the step table, and the panel carrying a step out — what is keyed, whether
// the contact logs, and where focus goes.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  group('esmStep', () {
    // Records compare their List fields by identity, so a step is checked by
    // what it says.
    String? step({
      bool running = true,
      bool callEmpty = false,
      bool canLog = true,
      bool answered = false,
      bool hasExchange = false,
      bool exchangeCopied = false,
    }) {
      final step = esmStep(
        running: running,
        callEmpty: callEmpty,
        canLog: canLog,
        answered: answered,
        hasExchange: hasExchange,
        exchangeCopied: exchangeCopied,
      );
      return step == null ? null : '${step.send.map((m) => m.name).join('+')} -> ${step.then.name}';
    }

    test('running with nothing typed calls CQ and logs nothing', () {
      expect(step(callEmpty: true, canLog: false), 'cq -> stay');
    });

    test('S&P with nothing typed leaves Enter alone — there is no CQ to call', () {
      expect(step(running: false, callEmpty: true, canLog: false), isNull);
    });

    test('a call that cannot log leaves Enter to refuse it, keying nothing', () {
      expect(step(canLog: false), isNull);
      expect(step(running: false, canLog: false), isNull);
    });

    // Reports only: nothing is left to receive once the caller has their
    // exchange, so waiting for a second Enter would leave the thanks unsent
    // and the contact unlogged for no reason.
    test('running with reports only answers, thanks and logs in one Enter', () {
      expect(step(), 'hisCall+exchange+thanks -> log');
    });

    test('running with an exchange sends it first and waits for theirs', () {
      expect(step(hasExchange: true), 'hisCall+exchange -> toExchange');
      expect(step(hasExchange: true, answered: true), 'again -> toExchange');
      expect(step(hasExchange: true, answered: true, exchangeCopied: true), 'thanks -> log');
    });

    // Before the station has been called there is no report of theirs to
    // log, so S&P takes two Enters even with reports only.
    test('S&P calls first, then sends the exchange and logs', () {
      expect(step(running: false), 'myCall -> toExchange');
      expect(step(running: false, answered: true), 'exchange -> log');
    });

    test('S&P with nothing of the exchange copied sends nothing and logs nothing', () {
      expect(step(running: false, answered: true, hasExchange: true), ' -> toExchange');
    });
  });

  group('panel', () {
    late HaLoDatabase db;
    late QsosRepository qsos;
    late Operation operation;
    late List<String> sent;

    setUp(() async {
      db = HaLoDatabase(NativeDatabase.memory());
      qsos = QsosRepository(db);
      operation = await OperationsRepository(db).create(stationCall: 'KI2D');
      sent = [];
    });

    tearDown(() async => db.close());

    const exchange = {
      'key': 'contest/exchange',
      'label': 'Exch',
      'icon': 'flag-checkered',
      'input': {'kind': 'text', 'refType': 'contest', 'field': 'exchange'},
    };

    EnterSends? Function() esm({bool running = true, bool on = true}) =>
        () => on
        ? EnterSends(running: running, send: (messages, qso) => sent.add('${messages.map((m) => m.name).join('+')} @ ${(qso['their'] as Map?)?['call'] ?? ''}'))
        : null;

    const name = {
      'key': 'contest/name',
      'label': 'Name',
      'icon': 'flag-checkered',
      'input': {'kind': 'text', 'refType': 'contest', 'field': 'name'},
    };

    Widget host({required EnterSends? Function() enterSends, bool contest = false, bool twoFields = false}) {
      final radio = _TunedVfoStore();
      return MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: LogHooks(
              operation: contest
                  ? Operation(
                      uuid: operation.uuid,
                      data: {
                        ...operation.data,
                        'refs': [
                          {'type': 'contest'},
                        ],
                      },
                    )
                  : operation,
              qsosRepository: qsos,
            ),
            session: LoggingSession(enterSends: enterSends),
            radio: RadioHookup(radioService: radio, radioUpdates: radio),
            activities: ActivityHooks(activityControls: [if (contest && twoFields) name, if (contest) exchange]),
          ),
        ),
      );
    }

    Future<List<Qso>> logged(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      return (await tester.runAsync(() => qsos.watchForOperation(operation.uuid).first))!;
    }

    // The engine's Enter, not `sendKeyEvent`: a key event reaches the panel's
    // shortcut without finalizing the editing session, and would pass against
    // a field that blurs (logging-fields.md § Enter and focus).
    Future<void> enter(WidgetTester tester) async {
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
    }

    Finder field(String label) => find.widgetWithText(TextField, label);

    bool focused(WidgetTester tester, String label) => tester.widget<TextField>(field(label)).focusNode?.hasFocus ?? false;

    testWidgets('with ESM off, Enter logs and keys nothing', (tester) async {
      await tester.pumpWidget(host(enterSends: esm(on: false)));
      await tester.pump();
      await tester.enterText(field('Their call'), 'W1AW');
      await enter(tester);

      expect(await logged(tester), hasLength(1));
      expect(sent, isEmpty);
    });

    testWidgets('running, an empty call field calls CQ', (tester) async {
      await tester.pumpWidget(host(enterSends: esm()));
      await tester.pump();
      await tester.tap(field('Their call'));
      await tester.pump();
      await enter(tester);

      expect(sent, ['cq @ ']);
      expect(await logged(tester), isEmpty);
    });

    testWidgets('running with reports only, one Enter answers and logs', (tester) async {
      await tester.pumpWidget(host(enterSends: esm()));
      await tester.pump();
      await tester.enterText(field('Their call'), 'W1AW');
      await enter(tester);

      // The call rides along with the messages: the log that follows wipes the
      // draft, so a render that waited for it would key a blank call.
      expect(sent, ['hisCall+exchange+thanks @ W1AW']);
      expect((await logged(tester)).single.theirCall, 'W1AW');
    });

    testWidgets('running a contest, the first Enter sends the exchange and moves to theirs', (tester) async {
      await tester.pumpWidget(host(enterSends: esm(), contest: true));
      await tester.pump();
      await tester.enterText(field('Their call'), 'W1AW');
      await enter(tester);

      expect(sent, ['hisCall+exchange @ W1AW']);
      expect(await logged(tester), isEmpty, reason: 'their exchange has not been copied yet');
      expect(focused(tester, 'Exch'), isTrue);

      // Nothing copied: ask again rather than log a contact missing its exchange.
      await enter(tester);
      expect(sent.last, 'again @ W1AW');
      expect(await logged(tester), isEmpty);

      await tester.enterText(field('Exch'), 'MA');
      await enter(tester);
      expect(sent.last, 'thanks @ W1AW');
      expect((await logged(tester)).single.theirCall, 'W1AW');
    });

    testWidgets('running, an exchange copied in part completes the contact', (tester) async {
      // A DX station in NAQP sends a name and no location. Asking again for
      // what will never come would leave the contact unloggable by Enter.
      await tester.pumpWidget(host(enterSends: esm(), contest: true, twoFields: true));
      await tester.pump();
      await tester.enterText(field('Their call'), 'W1AW');
      await enter(tester);
      await tester.enterText(field('Name'), 'HANK');
      await enter(tester);

      expect(sent.last, 'thanks @ W1AW');
      expect((await logged(tester)).single.theirCall, 'W1AW');
    });

    testWidgets('a call corrected after the first step starts the exchange over', (tester) async {
      // The operator fixing a busted call has a new station to give the
      // exchange to; completing the old contact would log one never worked.
      await tester.pumpWidget(host(enterSends: esm(), contest: true));
      await tester.pump();
      await tester.enterText(field('Their call'), 'W1AW');
      await enter(tester);
      await tester.enterText(field('Their call'), 'W1AX');
      await enter(tester);

      expect(sent.last, 'hisCall+exchange @ W1AX');
      expect(await logged(tester), isEmpty);
    });

    testWidgets('S&P with reports only calls first, and the second Enter logs', (tester) async {
      await tester.pumpWidget(host(enterSends: esm(running: false)));
      await tester.pump();
      await tester.enterText(field('Their call'), 'W1AW');
      await enter(tester);

      expect(sent, ['myCall @ W1AW']);
      expect(await logged(tester), isEmpty, reason: 'the station has not answered yet');

      await enter(tester);
      expect(sent.last, 'exchange @ W1AW');
      expect((await logged(tester)).single.theirCall, 'W1AW');
    });

    testWidgets('a logged contact starts the next one from the first step', (tester) async {
      await tester.pumpWidget(host(enterSends: esm(running: false)));
      await tester.pump();
      await tester.enterText(field('Their call'), 'W1AW');
      await enter(tester);
      await enter(tester);
      expect(await logged(tester), hasLength(1));

      // Working the same station again (a new band, a dupe check) is a new
      // exchange: without the wipe forgetting the first step, this Enter
      // would log a contact nobody called.
      await tester.enterText(field('Their call'), 'W1AW');
      await enter(tester);
      expect(sent.last, 'myCall @ W1AW');
      expect(await logged(tester), hasLength(1));
    });
  });
}

class _TunedVfoStore extends ChangeNotifier implements VfoStore {
  @override
  Vfo get vfoA => const Vfo(freq: 14025, band: '20m', mode: 'CW');

  @override
  void setVfo(String key, {double? freq, String? band, String? mode, num? power, bool clearFreq = false, bool clearPower = false}) {}
}
