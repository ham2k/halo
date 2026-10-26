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
      bool callFocused = false,
      bool incompleteCall = false,
    }) {
      final step = esmStep(
        running: running,
        callEmpty: callEmpty,
        canLog: canLog,
        answered: answered,
        hasExchange: hasExchange,
        exchangeCopied: exchangeCopied,
        callFocused: callFocused,
        incompleteCall: incompleteCall,
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

    // Reports only (a POTA activation): the caller's report comes back after
    // their exchange, so a thanks keyed in the same Enter talks over it. The
    // report has a default, so the second Enter never finds nothing copied
    // and asks again — from the call field either.
    test('running with reports only answers first, and the second Enter thanks and logs', () {
      expect(step(), 'hisCall+exchange -> toExchange');
      expect(step(answered: true), 'thanks -> log');
      expect(step(answered: true, callFocused: true), 'thanks -> log');
    });

    // A `?` call is a partial being asked back: the step that would answer or
    // complete it — the exchange, the thanks, the log — goes to a station
    // that has not answered yet, however far the contact had got.
    test('an incomplete call keys only their call and stays, running or S&P', () {
      for (final running in [true, false]) {
        expect(step(running: running, incompleteCall: true), 'hisCall -> stay');
        expect(step(running: running, incompleteCall: true, hasExchange: true, answered: true, exchangeCopied: true), 'hisCall -> stay');
      }
    });

    test('running with an exchange sends it first and waits for theirs', () {
      expect(step(hasExchange: true), 'hisCall+exchange -> toExchange');
      expect(step(hasExchange: true, answered: true), 'again -> toExchange');
      expect(step(hasExchange: true, answered: true, exchangeCopied: true), 'thanks -> log');
    });

    // Back in the call field, the operator is correcting the call or has
    // moved to another one in a stack: AGN? would not say which station is
    // meant, their call and the exchange do. Once something is copied, the
    // next Enter is still the thanks.
    test('running, Enter from the call field with nothing copied answers again', () {
      expect(step(hasExchange: true, answered: true, callFocused: true), 'hisCall+exchange -> toExchange');
      expect(step(hasExchange: true, answered: true, exchangeCopied: true, callFocused: true), 'thanks -> log');
      expect(step(running: false, hasExchange: true, answered: true, callFocused: true), ' -> toExchange', reason: 'S&P has nothing to re-send');
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
        ? EnterSends(
            running: running,
            send: (messages, qso, {logged}) => sent.add('${messages.map((m) => m.name).join('+')} @ ${(qso['their'] as Map?)?['call'] ?? ''}'),
          )
        : null;

    const name = {
      'key': 'contest/name',
      'label': 'Name',
      'icon': 'flag-checkered',
      'input': {'kind': 'text', 'refType': 'contest', 'field': 'name'},
    };

    const serial = {
      'key': 'contest/serial',
      'label': 'Nr',
      'icon': 'flag-checkered',
      'input': {
        'kind': 'serial',
        'refType': 'contest',
        'field': 'serial',
        'sequence': {'key': 'serial'},
      },
    };

    Widget host({
      required EnterSends? Function() enterSends,
      bool contest = false,
      bool twoFields = false,
      LoggingPreferences? prefs,
      List<Map<String, dynamic>>? controls,
      ValueChanged<EsmFacts?>? onEsmFacts,
      _TunedVfoStore? radio,
      Future<Map<String, dynamic>> Function(Map<String, dynamic> qso, Map<String, dynamic> operation)? decorate,
    }) {
      radio ??= _TunedVfoStore();
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
              decorateQsoBeforeSave: decorate,
            ),
            session: LoggingSession(enterSends: enterSends, onEsmFacts: onEsmFacts),
            prefs: prefs ?? const LoggingPreferences(),
            radio: RadioHookup(radioService: radio, radioUpdates: radio),
            activities: ActivityHooks(activityControls: controls ?? [if (contest && twoFields) name, if (contest) exchange]),
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

    // `K1A?` typed mid-pileup is a partial being asked back: the `?` keyed
    // with it is the asking. Enter must not fall through to the plain log,
    // which accepts an incomplete call, and close a contact with a station
    // that has not answered yet.
    testWidgets('an incomplete call keys their call with its ? and logs nothing, running or S&P', (tester) async {
      for (final running in [true, false]) {
        sent.clear();
        await tester.pumpWidget(host(enterSends: esm(running: running)));
        await tester.pump();
        await tester.enterText(field('Their call'), 'K1A?');
        await enter(tester);

        expect(sent, ['hisCall @ K1A?'], reason: running ? 'running' : 'S&P');
        expect(await logged(tester), isEmpty, reason: running ? 'running' : 'S&P');
        expect(focused(tester, 'Their call'), isTrue, reason: 'the full call is still to be typed');
      }
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

    testWidgets('running with reports only, the first Enter answers and the second thanks and logs', (tester) async {
      await tester.pumpWidget(host(enterSends: esm()));
      await tester.pump();
      await tester.enterText(field('Their call'), 'W1AW');
      await enter(tester);

      expect(sent, ['hisCall+exchange @ W1AW']);
      expect(await logged(tester), isEmpty, reason: 'their report has not come back yet');

      await enter(tester);
      expect(sent.last, 'thanks @ W1AW');
      expect((await logged(tester)).single.theirCall, 'W1AW');
    });

    // Sent is drawn first by default: focus to "the field after the call"
    // would put their report in ours, and the log would carry both wrong.
    testWidgets('with reports only, the first Enter moves to Rcvd, in either order', (tester) async {
      for (final switchSentRcvd in [false, true]) {
        for (final running in [true, false]) {
          await tester.pumpWidget(
            host(
              enterSends: esm(running: running),
              prefs: LoggingPreferences(switchSentRcvd: switchSentRcvd),
            ),
          );
          await tester.pump();
          await tester.enterText(field('Their call'), running ? 'W1AW' : 'K2XX');
          await enter(tester);

          expect(focused(tester, 'Rcvd'), isTrue, reason: 'switchSentRcvd: $switchSentRcvd, running: $running');
        }
      }
    });

    // With the reports hidden, the field after the call can be the serial WE
    // send: their report or number typed there would be logged as ours.
    testWidgets('with the reports hidden, the first Enter goes to State, never our own serial', (tester) async {
      for (final showStateField in [true, false]) {
        await tester.pumpWidget(
          host(
            enterSends: esm(),
            contest: true,
            controls: [serial],
            prefs: LoggingPreferences(showRSTFields: false, showStateField: showStateField),
          ),
        );
        await tester.pump();
        await tester.enterText(field('Their call'), showStateField ? 'W1AW' : 'K2XX');
        await enter(tester);

        expect(sent.last, startsWith('hisCall+exchange'), reason: 'a serial is ours to send, not an exchange to wait for');
        expect(focused(tester, 'Nr'), isFalse, reason: 'showStateField: $showStateField');
        expect(focused(tester, showStateField ? 'State' : 'Their call'), isTrue, reason: 'showStateField: $showStateField');
      }
    });

    // A station that faded, the field cleared, CQ called, and the same
    // station back again: what went out before the CQ is not this exchange.
    testWidgets('an emptied call field forgets the first step', (tester) async {
      await tester.pumpWidget(host(enterSends: esm()));
      await tester.pump();
      await tester.enterText(field('Their call'), 'W1AW');
      await enter(tester);
      await tester.enterText(field('Their call'), '');
      await tester.enterText(field('Their call'), 'W1AW');
      await enter(tester);

      expect(sent.last, 'hisCall+exchange @ W1AW');
      expect(await logged(tester), isEmpty);
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

    testWidgets('running, Enter back in the call field answers the call again instead of AGN?', (tester) async {
      await tester.pumpWidget(host(enterSends: esm(), contest: true));
      await tester.pump();
      await tester.enterText(field('Their call'), 'W1AW');
      await enter(tester);
      expect(focused(tester, 'Exch'), isTrue);

      await tester.tap(field('Their call'));
      await tester.pump();
      await enter(tester);
      expect(sent.last, 'hisCall+exchange @ W1AW');
      expect(focused(tester, 'Exch'), isTrue, reason: 'and waits for theirs where it did the first time');
      expect(await logged(tester), isEmpty);
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

    testWidgets('on a stack, the messages carry the call being logged, not the field', (tester) async {
      // `{{ qso.call }}` keyed off the raw field would send the whole stack in
      // Morse; `callField` is what the template reads instead.
      final keyed = <Object?>[];
      await tester.pumpWidget(host(enterSends: () => EnterSends(running: true, send: (_, qso, {logged}) => keyed.add(qso['callField']))));
      await tester.pump();
      await tester.enterText(field('Their call'), 'KN2//KI2D//NK2Y//FR');
      await enter(tester);
      await enter(tester);

      const nk2y = {'call': 'NK2Y', 'fullCall': 'NK2Y', 'partial': '', 'nextCall': 'KI2D', 'nextPartial': 'FR'};
      expect(keyed, [nk2y, nk2y], reason: 'the answer and the thanks');
      final saved = (await logged(tester)).single;
      expect(saved.theirCall, 'NK2Y');
      expect(saved.data.containsKey('callField'), isFalse, reason: 'a template value, never part of the record');
    });

    testWidgets('a step that logs hands over the contact as saved and the entry the log left, for the thanks', (tester) async {
      // The thanks closes this contact and speaks to the next: `qso` is the
      // record as written, extensions' additions and all, which the
      // keypress's draft never saw; `next` is the station stacked behind it,
      // which the thanks may call.
      Future<EsmLogged?>? after;
      await tester.pumpWidget(
        host(
          enterSends: () => EnterSends(running: true, send: (_, qso, {logged}) => after = logged),
          decorate: (qso, _) async => {...qso, 'notes': 'decorated'},
        ),
      );
      await tester.pump();
      await tester.enterText(field('Their call'), 'KN2//KI2D//NK2Y//FR');
      await enter(tester);
      await enter(tester);

      final saved = (await logged(tester)).single;
      expect(saved.theirCall, 'NK2Y');
      final handed = (await tester.runAsync(() => after!))!;
      expect(handed.qso, saved.data, reason: 'the record as written');
      expect(handed.qso['notes'], 'decorated');
      expect(handed.qso.containsKey('callField'), isFalse, reason: 'a logged call is a full one, with nothing next to it');
      expect(handed.next['callField'], {'call': 'KI2D', 'fullCall': 'KI2D', 'partial': '', 'nextCall': '', 'nextPartial': 'FR'});
      expect((handed.next['their'] as Map?)?['call'], 'KN2//KI2D//FR');
    });

    testWidgets('a comma list hands over its first contact', (tester) async {
      Future<EsmLogged?>? after;
      await tester.pumpWidget(host(enterSends: () => EnterSends(running: true, send: (_, qso, {logged}) => after = logged)));
      await tester.pump();
      await tester.enterText(field('Their call'), 'W1AW,K1ABC');
      await enter(tester);
      await enter(tester);

      expect((await logged(tester)).map((qso) => qso.theirCall), unorderedEquals(['W1AW', 'K1ABC']));
      final handed = (await tester.runAsync(() => after!))!;
      expect((handed.qso['their'] as Map?)?['call'], 'W1AW');
    });

    testWidgets('a partial left after the log is handed over as one, not as a call', (tester) async {
      // "KR//KI2D" logs KI2D and leaves KR — a station copied in part. A
      // thanks that keyed it as `fullCall` would call a station that doesn't
      // exist; as `partial` it asks it back ("TU KR?").
      Future<EsmLogged?>? after;
      await tester.pumpWidget(host(enterSends: () => EnterSends(running: true, send: (_, qso, {logged}) => after = logged)));
      await tester.pump();
      await tester.enterText(field('Their call'), 'KR//KI2D');
      await enter(tester);
      await enter(tester);

      expect((await logged(tester)).single.theirCall, 'KI2D');
      final handed = await tester.runAsync(() => after!);
      expect(handed?.next['callField'], {'call': 'KR', 'fullCall': '', 'partial': 'KR', 'nextCall': '', 'nextPartial': ''});
    });

    testWidgets('a log that fails hands over nothing, so no thanks goes out', (tester) async {
      Future<EsmLogged?>? after;
      await tester.pumpWidget(host(enterSends: () => EnterSends(running: true, send: (_, qso, {logged}) => after = logged)));
      await tester.pump();
      await tester.enterText(field('Their call'), 'W1AW');
      await enter(tester);
      await tester.runAsync(db.close);
      await enter(tester);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(await tester.runAsync(() => after!), isNull);
    });

    testWidgets('on a stack, moving to another call starts that exchange over', (tester) async {
      // The field text is the same wherever the cursor sits. Keyed on it, the
      // second Enter would thank KI2D and log it with NK2Y's exchange.
      await tester.pumpWidget(host(enterSends: esm(), contest: true));
      await tester.pump();
      await tester.enterText(field('Their call'), 'KI2D//NK2Y');
      await enter(tester);
      expect(sent.last, 'hisCall+exchange @ KI2D//NK2Y');
      await tester.enterText(field('Exch'), 'MA');

      await tester.tap(field('Their call'));
      tester.testTextInput.updateEditingValue(const TextEditingValue(text: 'KI2D//NK2Y', selection: TextSelection.collapsed(offset: 2)));
      await tester.pump();
      await enter(tester);

      expect(sent.last, 'hisCall+exchange @ KI2D//NK2Y', reason: 'KI2D has not been answered yet');
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

    // The app tints the messages the next Enter keys from what the panel
    // publishes, so every fact that moves the step must be published when it
    // moves: the call typed, the first step remembered, the focus back in the
    // call field, the exchange copied, the wipe. A highlight that trails any
    // of them shows the operator a message other than the one Enter keys.
    testWidgets('what the panel publishes predicts what each Enter keys', (tester) async {
      EsmFacts? published;
      await tester.pumpWidget(host(enterSends: esm(), contest: true, onEsmFacts: (facts) => published = facts));
      await tester.pump();

      Future<void> enterAsPredicted(String reason) async {
        final step = published == null ? null : esmStepFor(published!, running: true);
        final predicted = step?.send.map((m) => m.name).join('+');
        sent.clear();
        await enter(tester);
        expect(sent.map((s) => s.split(' @ ').first).firstOrNull, predicted, reason: reason);
      }

      await tester.tap(field('Their call'));
      await tester.pump();
      await enterAsPredicted('the empty call field');
      await tester.enterText(field('Their call'), 'W1AW');
      await enterAsPredicted('the call typed');
      await enterAsPredicted('answered, nothing copied');
      // By way of Rcvd, and by focus alone — the keyboard's way back, which
      // moves no caret: leaving an exchange field and tapping into the call
      // field each publish on their own, so neither would show a call
      // field's focus going unheard.
      await tester.tap(field('Rcvd'));
      await tester.pump();
      tester.widget<TextField>(field('Their call')).focusNode!.requestFocus();
      await tester.pump();
      await enterAsPredicted('back in the call field');
      await tester.enterText(field('Exch'), 'MA');
      await enterAsPredicted('the exchange copied');
      expect(await logged(tester), hasLength(1));
      await enterAsPredicted('the entry the log wiped');
    });

    // Enter refuses a contact with neither band nor frequency before ESM is
    // asked, so nothing it would key may be shown as about to go.
    testWidgets('a contact the band check would refuse publishes nothing to key', (tester) async {
      EsmFacts? published;
      await tester.pumpWidget(host(enterSends: esm(), radio: _UntunedVfoStore(), onEsmFacts: (facts) => published = facts));
      await tester.pump();
      await tester.enterText(field('Their call'), 'W1AW');
      await tester.pump();

      expect(published, isNull);
      await enter(tester);
      expect(sent, isEmpty);
    });
  });
}

class _UntunedVfoStore extends _TunedVfoStore {
  @override
  Vfo get vfoA => const Vfo();
}

class _TunedVfoStore extends ChangeNotifier implements VfoStore {
  @override
  Vfo get vfoA => const Vfo(freq: 14025, band: '20m', mode: 'CW');

  @override
  void setVfo(String key, {double? freq, String? band, String? mode, num? power, bool clearFreq = false, bool clearPower = false}) {}
}
