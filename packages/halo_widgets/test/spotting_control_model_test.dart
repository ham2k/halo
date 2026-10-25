// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// SpottingControlModel on its own: the state machine ham2k/halo-dist#10
// specifies, what a send does to the per-source status, and auto-respotting.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/src/logging_controls_spotting.dart';
import 'package:halo_widgets/src/icon_resolver.dart';
import 'package:halo_widgets/src/mdi_icons.g.dart';
import 'package:halo_widgets/src/secondary_control_row.dart' show SecondaryControlSpec;
import 'package:halo_widgets/src/theme.dart';

class _FakeVfoStore implements VfoStore {
  _FakeVfoStore(this.vfoA);
  @override
  Vfo vfoA;
  @override
  void setVfo(String key, {double? freq, String? band, String? mode, num? power, bool clearFreq = false, bool clearPower = false}) {}
}

/// The harness's auto-respot interval: the Spotting setting's default.
const _every = Duration(minutes: 10);

class _Harness {
  Qso? editingQso;
  Vfo vfo = const Vfo();
  final sent = <Map<String, dynamic>>[];
  Map<String, Map<String, dynamic>> answer = {};
  int notifications = 0;

  /// Runs while a spot is in flight, before its answer lands.
  void Function()? duringSend;

  /// Holds every spot in flight until it completes.
  Completer<void>? hold;

  /// Holds every ask for the sources on offer until it completes.
  Completer<void>? holdSources;

  /// The spotting extensions went away under the panel.
  bool hooksGone = false;

  /// No extension offers a self-spot (the operation's activation ref removed).
  bool noSources = false;

  /// A spotting hook that throws instead of answering.
  bool throwOnSend = false;

  String operationUuid = 'op';

  /// The operation's shared data — where its own switches and its refs say
  /// whether it may self-spot (`Operation.selfSpotting`).
  Map<String, dynamic> operationData = const {'refs': []};
  final notices = <String>[];

  /// The operator's Spotting settings.
  Duration respotInterval = _every;
  bool autoRespotByDefault = false;
  bool pulseBeforeRespot = true;

  /// How far a test has pumped the clock since the spot, for tests that step
  /// to set points.
  int elapsedMs = 0;

  late final model = SpottingControlModel(
    config: () => (
      sendSpot: hooksGone
          ? null
          : ({required sources, required operation, qso, freq, mode, comment, spotterCall}) async {
              sent.add({'sources': sources, 'freq': freq, 'mode': mode, 'comment': comment, 'qso': qso, 'operation': operation});
              duringSend?.call();
              await hold?.future;
              if (throwOnSend) throw StateError('hook failed');
              return answer;
            },
      suggestSpotSources: ({required operation, qso}) async {
        await holdSources?.future;
        return noSources
            ? const []
            : [
                {'hookKey': 'pota', 'icon': 'pine-tree'},
                {'hookKey': 'sota', 'icon': 'image-filter-hdr'},
              ];
      },
      radioService: _FakeVfoStore(vfo),
      editingQso: editingQso,
      operation: Operation(uuid: operationUuid, data: operationData, localData: const {'multiIdentifier': 'OP1'}),
      notice: notices.add,
      respotInterval: respotInterval,
      autoRespotByDefault: autoRespotByDefault,
      pulseBeforeRespot: pulseBeforeRespot,
      onOpenSettings: null,
    ),
  )..addListener(() => notifications++);
}

void main() {
  test('composing: no frequency disables self-spotting; a frequency enables it at that frequency', () {
    final h = _Harness();
    expect(h.model.state.enabled, isFalse);
    expect(h.model.state.showComment, isFalse);
    expect(h.model.state.summary, 'Self-spotting');
    h.vfo = const Vfo(freq: 14285, mode: 'SSB');
    expect(h.model.state.enabled, isTrue);
    expect(h.model.state.buttonLabel, contains('Self-spot at'));
    expect(h.model.state.summary, 'Self-spotting', reason: 'the pill keeps the short fixed label');
    h.model.dispose();
  });

  test('editing: a recent QSO can be spotted; one older than five minutes cannot', () {
    final h = _Harness();
    h.editingQso = Qso(
      uuid: 'q1',
      operationUuid: 'op',
      data: {
        'their': {'call': 'W1AW'},
        'startAtMillis': nowMillis() - 60 * 1000,
        'freq': 7200,
      },
    );
    expect(h.model.state.enabled, isTrue);
    expect(h.model.state.buttonLabel, startsWith('Spot W1AW at 7'));
    expect(h.model.state.summary, 'Spotting');
    h.editingQso = Qso(
      uuid: 'q2',
      operationUuid: 'op',
      data: {
        'their': {'call': 'W1AW'},
        'startAtMillis': nowMillis() - 6 * 60 * 1000,
      },
    );
    expect(h.model.state.enabled, isFalse);
    expect(h.model.state.buttonLabel, 'Too late to spot W1AW');
    h.model.dispose();
  });

  testWidgets('a send colours each source by its answer, clears the comment, and forgets the colours later', (tester) async {
    final h = _Harness();
    h.vfo = const Vfo(freq: 14285, mode: 'SSB');
    await h.model.refreshSources();
    expect(h.model.sources.length, 2);
    h.model.commentController.text = 'CQ POTA';
    h.answer = {
      'pota': {'ok': true},
      'sota': {'ok': false},
    };
    await h.model.send();
    expect(h.sent.single['freq'], 14285);
    expect(h.sent.single['mode'], 'SSB');
    expect(h.sent.single['comment'], 'CQ POTA');
    expect(h.sent.single['qso'], isNull, reason: 'a self-spot carries the VFO, not a QSO');
    expect(h.model.statusOf('pota'), isTrue);
    expect(h.model.statusOf('sota'), isFalse);
    expect(h.model.commentController.text, isEmpty);
    expect(h.model.sending, isFalse);
    await tester.pump(const Duration(minutes: 3));
    expect(h.model.statusOf('pota'), isNull, reason: 'a three-minute-old answer says nothing about now');
    h.model.dispose();
  });

  // A source whose own rules declined the spot (a Discord channel whose
  // template rendered blank) must neither light up as sent nor go red as
  // failed — and `skipped` without `ok` is still a failure, not a pass.
  test('a source that skipped the spot stays neutral, and only an ok skip counts', () async {
    final h = _Harness();
    h.vfo = const Vfo(freq: 14285, mode: 'SSB');
    await h.model.refreshSources();
    h.answer = {
      'pota': {'ok': true, 'skipped': true},
      'sota': {'ok': false, 'skipped': true},
    };
    await h.model.send();
    expect(h.model.statusOf('pota'), isNull);
    expect(h.model.statusOf('sota'), isFalse);
    h.model.dispose();
  });

  // The host offers no source for an incomplete call, so an enabled button
  // would send to nobody — no status icon, no notice — and read as spotting
  // being broken.
  test('editing: a recent QSO with an incomplete call cannot be spotted, and says why', () {
    final h = _Harness();
    h.editingQso = Qso(
      uuid: 'q1',
      operationUuid: 'op',
      data: {
        'their': {'call': 'W1A?'},
        'startAtMillis': nowMillis() - 60 * 1000,
        'freq': 7200,
      },
    );
    expect(h.model.state.enabled, isFalse);
    expect(h.model.state.buttonLabel, contains('incomplete call'));
    h.model.dispose();
  });

  test('the answers are keyed to the sources the send began with, not whatever is on offer when it lands', () async {
    final h = _Harness();
    h.vfo = const Vfo(freq: 14285);
    await h.model.refreshSources();
    h.answer = {
      'pota': {'ok': true},
      'sota': {'ok': true},
    };
    final pending = h.model.send();
    // The QSO context changes while the send is in flight.
    h.model.forgetSources();
    await pending;
    expect((h.sent.single['sources'] as List).length, 2);
    expect(h.model.statusOf('pota'), isTrue, reason: 'the answer belongs to the source that was asked');
    expect(h.model.statusOf('sota'), isTrue);
    h.model.dispose();
  });

  testWidgets('Enter in the comment field sends, and only while a send is possible', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(focusNode: h.model.commentFocus, controller: h.model.commentController),
        ),
      ),
    );
    h.model.commentFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(h.sent, isEmpty, reason: 'no frequency: nothing to spot at');
    h.vfo = const Vfo(freq: 14285, mode: 'SSB');
    await h.model.refreshSources();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(h.sent, hasLength(1));
    h.model.dispose();
  });

  group('auto-respotting', () {
    // Each source's respot is timed from when it last took one, on the real
    // clock, which the widget-test zone only moves when followed.
    setUp(() => AppClock.followZoneClock = true);
    tearDown(() => AppClock.followZoneClock = false);

    List<String> keysOf(Map<String, dynamic> sent) => [for (final source in sent['sources'] as List) (source as Map)['hookKey'] as String];

    /// A self-spot at 14.285 that every source took, with [comment].
    Future<_Harness> spotted(WidgetTester tester, {String comment = 'CQ POTA', bool allOk = true}) async {
      final h = _Harness();
      h.vfo = const Vfo(freq: 14285, mode: 'SSB');
      await h.model.refreshSources();
      h.answer = {
        'pota': {'ok': true},
        'sota': {'ok': allOk},
      };
      h.model.commentController.text = comment;
      await h.model.press();
      return h;
    }

    testWidgets('a self-spot every source took offers it briefly, then goes back to a plain self-spot', (tester) async {
      final h = await spotted(tester);
      expect(h.model.state.buttonLabel, 'Re-spot every 10 min');
      await tester.pump(SpottingControlModel.respotOfferWindow + const Duration(seconds: 1));
      expect(h.model.state.buttonLabel, startsWith('Self-spot at'), reason: 'past the window the button spots again rather than arming a repeat');
      expect(h.model.autoRespotting, isFalse);
      h.model.dispose();
    });

    // A repeat of a spot that only some sources took would keep failing on
    // the rest every ten minutes; and a one-off announcement repeated says
    // something false (still "QRT" while on the air).
    testWidgets('is not offered after a partial failure or a one-off Q-code', (tester) async {
      var h = await spotted(tester, allOk: false);
      expect(h.model.state.buttonLabel, startsWith('Self-spot at'));
      h.model.dispose();
      for (final comment in ['qrt thanks all', 'QRX 5', 'QRT, 73 all']) {
        h = await spotted(tester, comment: comment);
        expect(h.model.state.buttonLabel, startsWith('Self-spot at'), reason: comment);
        h.model.dispose();
      }
      h = await spotted(tester, comment: 'QRP 5W');
      expect(h.model.state.buttonLabel, 'Re-spot every 10 min', reason: 'only the one-off codes are excluded');
      h.model.dispose();
    });

    // QRV and QSY say the station is on the air at this frequency, which is
    // what a respot keeps saying; the code itself, repeated, would announce
    // an arrival every ten minutes.
    testWidgets('an arrival is offered like any spot, and repeats without its comment', (tester) async {
      for (final comment in ['QRV 20m', 'QSY', 'qsy/40m']) {
        final h = await spotted(tester, comment: comment);
        expect(h.model.state.buttonLabel, 'Re-spot every 10 min', reason: comment);
        await h.model.press();
        await tester.pump(_every + const Duration(seconds: 1));
        expect(h.sent, hasLength(2), reason: comment);
        expect(h.sent.first['comment'], comment, reason: 'the announcement itself goes out as typed');
        expect(h.sent.last['comment'], isNull, reason: comment);
        expect(h.model.respotComment, isNull, reason: comment);
        h.model.dispose();
      }
    });

    testWidgets('repeats the same spot every ten minutes until stopped', (tester) async {
      final h = await spotted(tester);
      await h.model.press();
      expect(h.model.autoRespotting, isTrue);
      expect(h.model.state.summary, 'Auto in 10m');
      expect(h.model.state.buttonLabel, 'Auto in 10:00. Stop?');
      expect(h.sent, hasLength(1));
      await tester.pump(const Duration(minutes: 6, seconds: 15));
      expect(h.model.state.buttonLabel, 'Auto in 3:45. Stop?', reason: 'counts down to the next respot');

      await tester.pump(_every - const Duration(minutes: 6, seconds: 20));
      expect(h.sent, hasLength(1), reason: 'not due yet');
      await tester.pump(const Duration(seconds: 10));
      expect(h.sent, hasLength(2));
      expect(h.sent.last['freq'], 14285);
      expect(h.sent.last['comment'], 'CQ POTA', reason: 'the comment cleared from the field after the first send is still the one repeated');
      expect((h.sent.last['sources'] as List).length, 2);

      await tester.pump(_every);
      expect(h.sent, hasLength(3));

      await h.model.press();
      expect(h.model.autoRespotting, isFalse);
      await tester.pump(_every * 2);
      expect(h.sent, hasLength(3), reason: 'stopped means no more spots');
      h.model.dispose();
    });

    // The pill sits in a row of chips: a per-second m:ss there would jitter
    // its width all interval long, so it steps coarsely and only counts
    // second by second at the very end.
    testWidgets('the chip counts down in coarse steps', (tester) async {
      final h = await spotted(tester);
      await h.model.press();
      final seen = <String>[h.model.state.summary];
      for (var i = 0; i < _every.inSeconds - 1; i++) {
        await tester.pump(const Duration(seconds: 1));
        if (h.model.state.summary != seen.last) seen.add(h.model.state.summary);
      }
      expect(seen, [for (var m = 10; m >= 1; m--) 'Auto in ${m}m', 'Auto in 30s', 'Auto in 15s', 'Auto in 10s', for (var s = 5; s >= 1; s--) 'Auto in $s']);
      h.model.dispose();
    });

    // Retrying every source would put a spot on the one that took it every
    // thirty seconds, far under the floor the interval exists to keep; and a
    // source retried until it gives in is asked 120 times an hour.
    // The row is built from a state resolved once; without its own
    // per-second refresh the countdown would sit at whatever it read then.
    testWidgets('the stop button counts down on its own', (tester) async {
      final h = await spotted(tester);
      await h.model.press();
      final theme = buildHaLoTheme(Brightness.light);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpottingControlFields(model: h.model, state: h.model.state, theme: theme, onPressed: () {}),
          ),
        ),
      );
      expect(find.text('Auto in 10:00. Stop?'), findsOneWidget);
      await tester.pump(const Duration(minutes: 6, seconds: 15));
      expect(find.text('Auto in 3:45. Stop?'), findsOneWidget);
      h.model.dispose();
    });

    // The comment field goes blank after a send; without this the operator
    // has no way to see what the respots announce.
    testWidgets('the row shows the comment it repeats, and takes no new one', (tester) async {
      final h = await spotted(tester);
      await h.model.press();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpottingControlFields(model: h.model, state: h.model.state, theme: buildHaLoTheme(Brightness.light), onPressed: () {}),
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'CQ POTA');
      expect(field.enabled, isFalse);
      expect(h.model.state.showComment, isFalse, reason: 'the focus ladder must not land on a field that takes no input');
      h.model.dispose();
    });

    testWidgets('a source that refuses a round gets one retry of its own; then it waits for the next round', (tester) async {
      final h = await spotted(tester);
      await h.model.press();
      h.answer = {
        'pota': {'ok': false},
        'sota': {'ok': true},
      };
      await tester.pump(_every + const Duration(seconds: 1));
      expect(h.sent, hasLength(2));
      await tester.pump(SpottingControlModel.respotRetry);
      expect(h.sent, hasLength(3), reason: 'a refusal is retried soon, not in ten minutes');
      expect(keysOf(h.sent.last), ['pota'], reason: 'only the source that refused');
      await tester.pump(SpottingControlModel.respotRetry * 4);
      expect(h.sent, hasLength(3), reason: 'once: refusing again waits for the next round');
      expect(h.model.autoRespotting, isTrue);
      await tester.pump(_every - SpottingControlModel.respotRetry * 5);
      expect(h.sent, hasLength(4));
      expect(keysOf(h.sent.last), ['pota', 'sota'], reason: 'the next round goes to every source');
      h.model.dispose();
    });

    // Told, since the chip changing is easy to miss: a QSY to chase a
    // station and back would otherwise leave the operator believing the
    // spots still go out.
    testWidgets('moving off the spotted frequency stops it, and says so', (tester) async {
      final h = await spotted(tester);
      await h.model.press();
      h.vfo = const Vfo(freq: 14290, mode: 'SSB');
      h.model.followVfo();
      expect(h.model.autoRespotting, isFalse);
      expect(h.notices.single, 'Auto re-spot stopped: the frequency changed');
      expect(h.model.state.buttonLabel, startsWith('Self-spot at'));
      // Back where it was: still off — a respot is armed by the operator, not
      // by the dial passing through.
      h.vfo = const Vfo(freq: 14285, mode: 'SSB');
      h.model.followVfo();
      await tester.pump(_every * 2);
      expect(h.sent, hasLength(1));
      h.model.dispose();
    });

    // CAT reports to the hertz: a nudge of the dial, or a radio that drops
    // its frequency while reconnecting, would otherwise end it with only the
    // chip's label to say so.
    testWidgets('a nudge of the dial or a radio reporting no frequency does not stop it', (tester) async {
      final h = await spotted(tester);
      await h.model.press();
      h.vfo = const Vfo(freq: 14285.3, mode: 'SSB');
      h.model.followVfo();
      h.vfo = const Vfo();
      h.model.followVfo();
      expect(h.model.autoRespotting, isTrue);
      h.vfo = const Vfo(freq: 14285.2, mode: 'SSB');
      await tester.pump(_every + const Duration(seconds: 1));
      expect(h.sent, hasLength(2));
      expect(h.sent.last['freq'], 14285, reason: 'the spotted frequency, not the nudged one');
      h.model.dispose();
    });

    testWidgets('retuning while the spot is in flight offers nothing', (tester) async {
      final h = _Harness();
      h.vfo = const Vfo(freq: 14285, mode: 'SSB');
      await h.model.refreshSources();
      h.answer = {
        'pota': {'ok': true},
        'sota': {'ok': true},
      };
      h.duringSend = () => h.vfo = const Vfo(freq: 7200, mode: 'SSB');
      await h.model.press();
      expect(h.model.state.buttonLabel, startsWith('Self-spot at'), reason: 'an offer to repeat a frequency the operator has left');
      h.model.dispose();
    });

    // Without this the timer stops without stopping auto-respotting: the chip
    // says "Auto re-spot", glowing at full strength, and nothing goes out.
    testWidgets('stops when the spotting extensions are gone', (tester) async {
      final h = await spotted(tester);
      await h.model.press();
      h.hooksGone = true;
      await tester.pump(_every + const Duration(seconds: 1));
      expect(h.model.autoRespotting, isFalse);
      expect(h.model.respotGlow, 0);
      expect(h.notices.single, contains('Nothing to spot'));
      h.model.dispose();
    });

    testWidgets('stops, and says so, when nothing offers a self-spot any more', (tester) async {
      final h = await spotted(tester);
      await h.model.press();
      h.noSources = true;
      await tester.pump(_every + const Duration(seconds: 1));
      expect(h.model.autoRespotting, isFalse);
      expect(h.notices.single, contains('Nothing to spot'));
      await tester.pump(_every);
      expect(h.sent, hasLength(1));
      h.model.dispose();
    });

    // With no answer there is nothing to retry on: rescheduling would call
    // the throwing hook again at once, forever.
    testWidgets('stops, and says so, when a hook throws', (tester) async {
      final h = await spotted(tester);
      final errors = <Object>[];
      // Started in a zone of its own, so the respot's timer — and the error
      // its unawaited send throws — land here rather than failing the test.
      await runZonedGuarded(h.model.press, (error, _) => errors.add(error));
      h.throwOnSend = true;
      await tester.pump(_every + const Duration(seconds: 1));
      expect(h.model.autoRespotting, isFalse);
      expect(h.notices.single, 'Auto re-spot stopped');
      await tester.pump(_every);
      expect(h.sent, hasLength(2));
      expect(errors.single, isA<StateError>(), reason: 'the error itself still goes on to the zone');
      h.model.dispose();
    });

    testWidgets('stops when the panel is handed another operation', (tester) async {
      final h = await spotted(tester);
      await h.model.press();
      h.operationUuid = 'other';
      await tester.pump(_every + const Duration(seconds: 1));
      expect(h.model.autoRespotting, isFalse);
      expect(h.sent, hasLength(1), reason: "the old activation's spot is not announced as the new one's");
      h.model.dispose();
    });

    testWidgets('stops, and says so, when the operation is edited to rule self-spotting out', (tester) async {
      final h = await spotted(tester);
      await h.model.press();
      h.operationData = const {'selfSpotting': false};
      expect(h.model.state.buttonLabel, 'Self-spot disabled', reason: 'the button must not count down to a spot that will not go');
      await tester.pump(_every + const Duration(seconds: 1));
      expect(h.model.autoRespotting, isFalse);
      expect(h.notices.single, 'Self-spot disabled');
      expect(h.sent, hasLength(1));
      h.model.dispose();
    });

    // Until the next round stops it, the model still reads as respotting;
    // the row must not stack the respot comment beside the disabled one.
    testWidgets('the row shows one comment field once self-spotting is ruled out mid-respot', (tester) async {
      final h = await spotted(tester);
      await h.model.press();
      h.operationData = const {'selfSpotting': false};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpottingControlFields(model: h.model, state: h.model.state, theme: buildHaLoTheme(Brightness.light), onPressed: () {}),
          ),
        ),
      );
      expect(h.model.autoRespotting, isTrue);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      h.model.dispose();
    });

    testWidgets("RESPOT under another operation does not repeat the last one's spot", (tester) async {
      final h = await spotted(tester);
      h.operationUuid = 'other';
      expect(await h.model.respotEvery(5), isNull);
      expect(h.sent, hasLength(2), reason: 'a fresh spot for this operation, not a repeat of the old one timed from back then');
      expect(h.sent.last['comment'], isNull);
      h.model.dispose();
    });

    // Without it, pressing repeats the spot before the QRT — or, after the
    // QRT cleared what to repeat, does nothing at all.
    testWidgets('a newer self-spot withdraws the offer to repeat an older one', (tester) async {
      var h = await spotted(tester);
      h.model.commentController.text = 'QRT thanks';
      await h.model.send();
      expect(h.model.state.buttonLabel, startsWith('Self-spot at'));
      h.model.dispose();

      h = await spotted(tester);
      h.answer = {
        'pota': {'ok': true},
        'sota': {'ok': false},
      };
      h.model.commentController.text = 'CQ on CW now';
      await h.model.send();
      expect(h.model.state.buttonLabel, startsWith('Self-spot at'), reason: 'an offer standing here would repeat "CQ POTA"');
      h.model.dispose();
    });

    // A radio off CAT leaves nothing to say where the station is: a retry
    // every thirty seconds forever would keep the chip glowing and saying
    // "Auto re-spot" while no spot goes out.
    testWidgets('a radio with no frequency gets one retry, then it stops and says so', (tester) async {
      final h = await spotted(tester);
      await h.model.press();
      h.vfo = const Vfo();
      await tester.pump(_every + const Duration(seconds: 1));
      expect(h.model.autoRespotting, isTrue);
      await tester.pump(SpottingControlModel.respotRetry);
      expect(h.model.autoRespotting, isFalse);
      expect(h.notices.single, 'Auto re-spot stopped: the radio reports no frequency');
      expect(h.sent, hasLength(1));
      h.model.dispose();
    });

    testWidgets('a radio back within the retry carries on', (tester) async {
      final h = await spotted(tester);
      await h.model.press();
      h.vfo = const Vfo();
      await tester.pump(_every + const Duration(seconds: 1));
      h.vfo = const Vfo(freq: 14285, mode: 'SSB');
      await tester.pump(SpottingControlModel.respotRetry);
      expect(h.sent, hasLength(2));
      expect(h.model.autoRespotting, isTrue);
      expect(h.notices, isEmpty);
      h.model.dispose();
    });

    // The icon alone is inside a collapsed chip: a source refusing every
    // round would otherwise never be seen.
    testWidgets('a source that refuses its retry too is told, once a round', (tester) async {
      final h = await spotted(tester);
      await h.model.press();
      h.answer = {
        'pota': {'ok': false, 'message': 'no alert'},
        'sota': {'ok': true},
      };
      await tester.pump(_every + const Duration(seconds: 1));
      expect(h.notices, isEmpty, reason: 'the retry may yet take it');
      await tester.pump(SpottingControlModel.respotRetry);
      expect(h.notices, ['pota failed: no alert']);
      await tester.pump(_every);
      await tester.pump(SpottingControlModel.respotRetry);
      expect(h.notices, hasLength(2));
      h.model.dispose();
    });

    testWidgets("a respot leaves the icons of the QSO open for editing alone", (tester) async {
      final h = await spotted(tester);
      await h.model.press();
      h.editingQso = Qso(
        uuid: 'q1',
        operationUuid: 'op',
        data: {
          'their': {'call': 'W1AW'},
          'startAtMillis': nowMillis(),
        },
      );
      h.model.forgetSources();
      h.answer = {
        'pota': {'ok': false},
        'sota': {'ok': true},
      };
      await tester.pump(_every + const Duration(seconds: 1));
      expect(h.sent, hasLength(2));
      expect(h.model.statusOf('pota'), isNull, reason: "red would read as W1AW's spot failing");
      expect(h.model.statusOf('sota'), isNull);
      h.model.dispose();
    });

    testWidgets('Enter during a respot keeps the comment and says why nothing went', (tester) async {
      final h = await spotted(tester);
      await h.model.press();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(focusNode: h.model.commentFocus, controller: h.model.commentController),
          ),
        ),
      );
      h.model.commentFocus.requestFocus();
      await tester.pump();
      h.hold = Completer();
      await tester.pump(_every);
      expect(h.model.sending, isTrue, reason: 'the respot is in flight');
      h.editingQso = Qso(
        uuid: 'q1',
        operationUuid: 'op',
        data: {
          'their': {'call': 'W1AW'},
          'startAtMillis': nowMillis(),
        },
      );
      h.model.commentController.text = 'nice signal';
      final handled = await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      // An Enter the field ignores goes on to the focus ladder, which closes
      // the control and takes the comment with it.
      expect(handled, isTrue);
      expect(h.notices.single, 'Another spot is still being sent');
      expect(h.model.commentController.text, 'nice signal');
      h.hold!.complete();
      await tester.pump();
      expect(h.sent, hasLength(2), reason: 'the respot only');
      h.model.dispose();
    });

    testWidgets('a comment typed while it is on offer is sent, not taken as a yes', (tester) async {
      final h = await spotted(tester);
      h.model.commentController.text = 'QRT thanks';
      await h.model.press();
      expect(h.model.autoRespotting, isFalse);
      expect(h.sent.last['comment'], 'QRT thanks');
      h.model.dispose();
    });

    testWidgets('a spot is not sent while another is in flight', (tester) async {
      final h = await spotted(tester);
      h.editingQso = Qso(
        uuid: 'q1',
        operationUuid: 'op',
        data: {
          'their': {'call': 'W1AW'},
          'startAtMillis': nowMillis(),
        },
      );
      h.hold = Completer();
      final pending = h.model.press();
      await tester.pump();
      h.editingQso = null;
      await h.model.runCommandAction(
        {
          'sendSpots': {'comment': 'CQ'},
        },
        qsos: const [],
        forward: null,
      );
      expect(h.notices.single, 'Another spot is still being sent');
      expect(h.sent, hasLength(2), reason: 'the first self-spot and the QSO spot, nothing more');
      h.hold!.complete();
      await pending;
      h.model.dispose();
    });

    group('typed spots', () {
      final forwarded = <Map<String, dynamic>?>[];
      Future<void> typed(_Harness h, String? comment, {String target = 'self'}) => h.model.runCommandAction(
        {
          'sendSpots': {'comment': ?comment, 'target': target},
        },
        qsos: const [],
        forward: (action, [params]) async => forwarded.add(params),
      );
      setUp(forwarded.clear);

      // Without this the old spot would follow the operator's QRT.
      testWidgets('a typed QRT ends auto-respotting, and is sent', (tester) async {
        final h = await spotted(tester);
        await h.model.press();
        await typed(h, 'QRT thanks all');
        expect(h.model.autoRespotting, isFalse);
        expect(h.sent.last['comment'], 'QRT thanks all');
        await tester.pump(_every * 2);
        expect(h.sent, hasLength(2));
        h.model.dispose();
      });

      testWidgets('a typed QSY while it runs keeps it running, timed from then, with no comment', (tester) async {
        final h = await spotted(tester);
        await h.model.press();
        await tester.pump(const Duration(minutes: 8));
        await typed(h, 'QSY up 5');
        expect(h.model.autoRespotting, isTrue);
        await tester.pump(const Duration(minutes: 5));
        expect(h.sent, hasLength(2), reason: 'not two minutes after the typed spot');
        await tester.pump(const Duration(minutes: 5, seconds: 1));
        expect(h.sent.map((s) => s['comment']), ['CQ POTA', 'QSY up 5', null]);
        h.model.dispose();
      });

      testWidgets('RESPOT right after a typed SPOT repeats it rather than spotting again', (tester) async {
        final h = _Harness();
        h.vfo = const Vfo(freq: 14285, mode: 'SSB');
        h.answer = {
          'pota': {'ok': true},
          'sota': {'ok': true},
        };
        await typed(h, 'CQ POTA 20m');
        expect(forwarded.single, {'target': 'self'}, reason: 'the app still hears of it, and has nothing to say');
        expect(await h.model.respotEvery(5), isNull);
        expect(h.sent, hasLength(1), reason: 'only the typed spot');
        await tester.pump(const Duration(minutes: 5, seconds: 1));
        expect(h.sent, hasLength(2));
        expect(h.sent.last['comment'], 'CQ POTA 20m');
        h.model.dispose();
      });

      // Answered by the app where it was typed — the palette's own line — and
      // not here, behind the palette, in the call field.
      testWidgets('a typed SPOT goes on to the app with why it did not go through, and is not repeated', (tester) async {
        final h = _Harness();
        h.vfo = const Vfo(freq: 14285, mode: 'SSB');
        h.answer = {
          'pota': {'ok': false, 'message': 'no alert'},
          'sota': {'ok': true},
        };
        await typed(h, 'CQ POTA');
        expect(forwarded.single, {'target': 'self', 'failure': 'pota failed: no alert'});
        expect(h.notices, isEmpty);
        h.answer = {
          'pota': {'ok': true},
          'sota': {'ok': true},
        };
        expect(await h.model.respotEvery(5), isNull);
        expect(h.sent, hasLength(2), reason: 'RESPOT spots afresh rather than repeating a spot that failed');
        h.model.dispose();
      });

      testWidgets('a typed SPOT while it runs becomes the spot it repeats, timed from then', (tester) async {
        final h = await spotted(tester);
        await h.model.press();
        await tester.pump(const Duration(minutes: 8));
        await typed(h, 'CQ POTA now on CW');
        await tester.pump(const Duration(minutes: 5));
        expect(h.sent, hasLength(2), reason: 'not two minutes after the typed spot');
        await tester.pump(const Duration(minutes: 5, seconds: 1));
        expect(h.sent.last['comment'], 'CQ POTA now on CW');
        h.model.dispose();
      });

      // SPOTLAST spots a QSO, not the station: taken for a self-spot, it
      // would replace what auto-respotting repeats with a spot that never
      // went out.
      testWidgets('SPOTLAST goes to the app and leaves auto-respotting alone', (tester) async {
        final h = await spotted(tester);
        await h.model.press();
        await typed(h, null, target: 'last');
        expect(forwarded.single!['target'], 'last');
        await tester.pump(_every + const Duration(seconds: 1));
        expect(h.sent.last['comment'], 'CQ POTA');
        h.model.dispose();
      });
    });

    testWidgets('the chip glows only in the last minute, on the real clock', (tester) async {
      AppClock.followZoneClock = true;
      addTearDown(() {
        AppClock.followZoneClock = false;
        AppClock.instance.reset();
      });
      final h = await spotted(tester);
      await h.model.press();
      expect(h.model.respotGlow, 0);
      await tester.pump(_every - const Duration(seconds: 90));
      expect(h.model.respotGlow, 0);
      // Travel moves the app clock past the glow lead; the respot timer counts
      // real time, so a glow read off the app clock would announce a send
      // that is still a minute and a half away.
      AppClock.instance.travel(delta: const Duration(minutes: 1));
      expect(h.model.respotGlow, 0);
      await tester.pump(const Duration(seconds: 60));
      expect(h.model.respotGlow, inInclusiveRange(0.4, 0.6));
      await tester.pump(const Duration(seconds: 31));
      expect(h.model.respotGlow, 0, reason: 'sent, and the next one is ten minutes out');
      expect(h.sent, hasLength(2));
      h.model.dispose();
    });

    // The chip redraws every second while it glows; flagged for the whole
    // interval, it would redraw for nine minutes showing nothing.
    testWidgets('flags the glow only in the last minute', (tester) async {
      final h = await spotted(tester);
      await h.model.press();
      await tester.pump(_every - const Duration(seconds: 61));
      expect(h.model.respotGlowing, isFalse);
      await tester.pump(const Duration(seconds: 2));
      expect(h.model.respotGlowing, isTrue);
      await tester.pump(const Duration(seconds: 60));
      expect(h.model.respotGlowing, isFalse, reason: 'sent; the next one is ten minutes out');
      h.model.stopAutoRespotting();
      expect(h.model.respotGlowing, isFalse);
      h.model.dispose();
    });

    group('RESPOT', () {
      testWidgets('repeats the self-spot just taken, timed from when it went out — no second spot now', (tester) async {
        final h = await spotted(tester);
        await tester.pump(const Duration(minutes: 2));
        expect(await h.model.respotEvery(5), isNull);
        expect(h.model.autoRespotting, isTrue);
        expect(h.sent, hasLength(1), reason: 'a spot two minutes old is repeated, not doubled');
        await tester.pump(const Duration(minutes: 2, seconds: 50));
        expect(h.sent, hasLength(1));
        await tester.pump(const Duration(seconds: 20));
        expect(h.sent, hasLength(2), reason: 'five minutes after the spot, not after the command');
        await tester.pump(const Duration(minutes: 5));
        expect(h.sent, hasLength(3));
        h.model.dispose();
      });

      testWidgets('spots now when there is nothing to repeat, and repeats that', (tester) async {
        final h = _Harness();
        h.vfo = const Vfo(freq: 7200, mode: 'CW');
        h.answer = {
          'pota': {'ok': true},
          'sota': {'ok': true},
        };
        expect(await h.model.respotEvery(7), isNull);
        expect(h.sent.single['freq'], 7200);
        expect(h.sent.single['comment'], isNull);
        await tester.pump(const Duration(minutes: 7, seconds: 1));
        expect(h.sent, hasLength(2));
        h.model.dispose();
      });

      // Repeating "QRT" every few minutes would say the station is leaving
      // while it is still on the air.
      testWidgets('a one-off announcement is not what it repeats', (tester) async {
        final h = await spotted(tester, comment: 'QRX 5');
        expect(await h.model.respotEvery(5), isNull);
        expect(h.sent, hasLength(2));
        expect(h.sent.last['comment'], isNull);
        h.model.dispose();
      });

      testWidgets('never more often than every five minutes', (tester) async {
        final h = await spotted(tester);
        await h.model.respotEvery(1);
        await tester.pump(const Duration(minutes: 4, seconds: 50));
        expect(h.sent, hasLength(1));
        await tester.pump(const Duration(seconds: 20));
        expect(h.sent, hasLength(2));
        h.model.dispose();
      });

      testWidgets('goes on to the app with why it could not start', (tester) async {
        final h = _Harness();
        final forwarded = <MapEntry<String, Map<String, dynamic>?>>[];
        await h.model.runCommandAction(
          {
            'autoRespot': {'minutes': 5},
          },
          qsos: const [],
          forward: (action, [params]) async => forwarded.add(MapEntry(action, params)),
        );
        expect(forwarded.single.key, 'autoRespot');
        expect(forwarded.single.value, {'failure': 'Set a frequency first.'});
        expect(h.notices, isEmpty);
        h.model.dispose();
      });

      // A Duration past 2^31 ms fires at once on the web, and a huge number of
      // minutes overflows one: either way, a spot per network round trip.
      testWidgets('never less often than every sixty minutes, whatever the action asks', (tester) async {
        final h = await spotted(tester);
        await h.model.runCommandAction(
          {
            'autoRespot': {'minutes': 1e13},
          },
          qsos: const [],
          forward: null,
        );
        await tester.pump(const Duration(minutes: 59, seconds: 50));
        expect(h.sent, hasLength(1));
        await tester.pump(const Duration(seconds: 20));
        expect(h.sent, hasLength(2));
        h.model.dispose();
      });

      testWidgets('says why it cannot start', (tester) async {
        final h = _Harness();
        expect(await h.model.respotEvery(10), 'Set a frequency first.');
        h.vfo = const Vfo(freq: 7200);
        h.answer = {
          'pota': {'ok': true},
          'sota': {'ok': false},
        };
        expect(await h.model.respotEvery(10), contains('sota failed'));
        expect(h.model.autoRespotting, isFalse);
        h.model.dispose();
      });

      // RESPOT 0 means off; an action saying 0 must not start a repeat.
      testWidgets('an action of 0 minutes stops it', (tester) async {
        final h = await spotted(tester);
        await h.model.press();
        await h.model.runCommandAction(
          {
            'autoRespot': {'minutes': 0},
          },
          qsos: const [],
          forward: null,
        );
        expect(h.model.autoRespotting, isFalse);
        h.model.dispose();
      });

      testWidgets('re-times one already running, and stops', (tester) async {
        final h = await spotted(tester);
        await h.model.press();
        await h.model.respotEvery(5);
        await tester.pump(const Duration(minutes: 5, seconds: 10));
        expect(h.sent, hasLength(2), reason: 'the new interval replaces the ten minutes');
        h.model.stopAutoRespotting();
        await tester.pump(const Duration(minutes: 20));
        expect(h.sent, hasLength(2));
        h.model.dispose();
      });
    });
  });

  group('chip feedback', () {
    // Faded on the real clock, which the widget-test zone only moves when
    // followed.
    setUp(() => AppClock.followZoneClock = true);
    tearDown(() => AppClock.followZoneClock = false);

    Future<_Harness> selfSpot(WidgetTester tester, {required bool pota, required bool sota}) async {
      final h = _Harness();
      h.vfo = const Vfo(freq: 14285, mode: 'SSB');
      await h.model.refreshSources();
      h.answer = {
        'pota': {'ok': pota},
        'sota': {'ok': sota},
      };
      await h.model.press();
      return h;
    }

    testWidgets('a self-spot shows on the chip as every, some or no source taking it', (tester) async {
      for (final (pota, sota, outcome) in [(true, true, SpotOutcome.allTook), (true, false, SpotOutcome.someTook), (false, false, SpotOutcome.noneTook)]) {
        final h = await selfSpot(tester, pota: pota, sota: sota);
        expect(h.model.outcome, outcome, reason: 'pota $pota, sota $sota');
        expect(h.model.outcomeStrength, 1);
        h.model.dispose();
      }
    });

    // Counted as taking it, a skip turns a spot nobody sent green, and makes
    // one the other source refused only "some".
    testWidgets('a source that skipped the spot is left out: every source skipping leaves the chip neutral', (tester) async {
      for (final (sota, outcome) in [(null, null), (true, SpotOutcome.allTook), (false, SpotOutcome.noneTook)]) {
        final h = _Harness();
        h.vfo = const Vfo(freq: 14285, mode: 'SSB');
        await h.model.refreshSources();
        h.answer = {
          'pota': {'ok': true, 'skipped': true},
          'sota': sota == null ? {'ok': true, 'skipped': true} : {'ok': sota},
        };
        await h.model.press();
        expect(h.model.outcome, outcome, reason: 'sota $sota');
        h.model.dispose();
      }
    });

    // Recorded, a spot nothing sent would be offered for auto-respotting —
    // or started, by default — and repeat sending nothing every round under
    // a chip saying "Auto re-spot". And with its icons neutral, the notice
    // is the only sign it went nowhere.
    testWidgets('a self-spot every source skipped says so, and is never what auto-respotting repeats', (tester) async {
      for (final byDefault in [false, true]) {
        final h = _Harness()..autoRespotByDefault = byDefault;
        h.vfo = const Vfo(freq: 14285, mode: 'SSB');
        await h.model.refreshSources();
        h.answer = {
          'pota': {'ok': true, 'skipped': true, 'message': 'No Discord channel takes this spot'},
          'sota': {'ok': true, 'skipped': true},
        };
        await h.model.press();
        expect(h.notices, ['No Discord channel takes this spot'], reason: 'byDefault $byDefault');
        expect(h.model.autoRespotting, isFalse, reason: 'byDefault $byDefault');
        await h.model.press();
        expect(h.sent, hasLength(2), reason: 'a second press is a new spot, not a yes to repeating the first');
        expect(h.model.autoRespotting, isFalse);
        expect(await h.model.respotEvery(5), 'No Discord channel takes this spot', reason: 'RESPOT has nothing to repeat');
        h.model.dispose();
      }
    });

    testWidgets('an auto-respot round every source skipped stops auto-respotting, and says why', (tester) async {
      final h = await selfSpot(tester, pota: true, sota: true);
      await h.model.press();
      expect(h.model.autoRespotting, isTrue);
      h.answer = {
        'pota': {'ok': true, 'skipped': true},
        'sota': {'ok': true, 'skipped': true},
      };
      await tester.pump(_every + const Duration(seconds: 1));
      expect(h.model.autoRespotting, isFalse);
      expect(h.notices, [t.spotting.allSkipped]);
      h.model.dispose();
    });

    testWidgets('a spot every source skipped drops the fading outcome of the one before', (tester) async {
      final h = await selfSpot(tester, pota: true, sota: true);
      expect(h.model.outcome, SpotOutcome.allTook);
      h.answer = {
        'pota': {'ok': true, 'skipped': true},
        'sota': {'ok': true, 'skipped': true},
      };
      await tester.pump(const Duration(seconds: 30));
      await h.model.press();
      expect(h.model.outcome, isNull, reason: "the earlier spot's green would read as this one's");
      h.model.dispose();
    });

    testWidgets('a source that never answers counts as one that did not take it', (tester) async {
      final h = _Harness();
      h.vfo = const Vfo(freq: 14285, mode: 'SSB');
      h.answer = {
        'pota': {'ok': true},
      };
      await h.model.press();
      expect(h.model.outcome, SpotOutcome.someTook);
      h.model.dispose();
    });

    testWidgets('fades over three minutes, then is gone', (tester) async {
      final h = await selfSpot(tester, pota: true, sota: true);
      await tester.pump(const Duration(seconds: 90));
      expect(h.model.outcomeStrength, closeTo(0.5, 0.01));
      final before = h.notifications;
      await tester.pump(const Duration(seconds: 91));
      expect(h.model.outcome, isNull);
      expect(h.notifications, greaterThan(before), reason: 'the chip stops redrawing every second only once told');
      h.model.dispose();
    });

    testWidgets('a typed SPOT shows on the chip too', (tester) async {
      final h = _Harness();
      h.vfo = const Vfo(freq: 14285, mode: 'SSB');
      h.answer = {
        'pota': {'ok': false},
        'sota': {'ok': false},
      };
      await h.model.runCommandAction(
        {
          'sendSpots': {'comment': 'CQ'},
        },
        qsos: const [],
        forward: null,
      );
      expect(h.model.outcome, SpotOutcome.noneTook);
      h.model.dispose();
    });

    // The chip speaks for the station's own spot: green for a hunter spot of
    // someone else would read as the station being spotted.
    // Editing a logged QSO turns the chip into spotting that QSO's station:
    // the station's own respot coloring it would read as that spot's answer.
    testWidgets('a respot while a QSO is open leaves the chip alone', (tester) async {
      final h = await selfSpot(tester, pota: true, sota: true);
      await h.model.press();
      await tester.pump(SpottingControlModel.resultShownFor + const Duration(seconds: 1));
      expect(h.model.outcome, isNull);
      h.editingQso = Qso(
        uuid: 'q1',
        operationUuid: 'op',
        data: {
          'their': {'call': 'W1AW'},
          'startAtMillis': nowMillis(),
        },
      );
      await tester.pump(_every - SpottingControlModel.resultShownFor);
      expect(h.sent, hasLength(2), reason: 'the respot went out a second ago, well inside the fade');
      expect(h.model.outcome, isNull);
      h.model.dispose();
    });

    // Left on past the due moment, the tint would have the chip redraw every
    // frame for as long as the round's hooks take, showing nothing.
    testWidgets('the pulse and glow end when the respot goes out, not when it lands', (tester) async {
      final h = await selfSpot(tester, pota: true, sota: true);
      await h.model.press();
      h.hold = Completer();
      await tester.pump(_every - const Duration(seconds: 5));
      expect(h.model.respotSoon, isTrue);
      expect(h.model.respotGlowing, isTrue);
      await tester.pump(const Duration(seconds: 6));
      expect(h.sent, hasLength(2), reason: 'out, its answer held');
      expect(h.model.respotSoon, isFalse);
      expect(h.model.respotGlowing, isFalse);
      h.hold!.complete();
      await tester.pump();
      h.model.dispose();
    });

    testWidgets("a spot of another station's QSO leaves the chip alone", (tester) async {
      final h = _Harness();
      h.editingQso = Qso(
        uuid: 'q1',
        operationUuid: 'op',
        data: {
          'their': {'call': 'W1AW'},
          'startAtMillis': nowMillis(),
        },
      );
      await h.model.refreshSources();
      h.answer = {
        'pota': {'ok': true},
        'sota': {'ok': true},
      };
      await h.model.press();
      expect(h.sent, hasLength(1));
      expect(h.model.outcome, isNull);
      h.model.dispose();
    });

    testWidgets('each auto-respot shows how its round went, its retry included', (tester) async {
      final h = await selfSpot(tester, pota: true, sota: true);
      await h.model.press();
      h.answer = {
        'pota': {'ok': false},
        'sota': {'ok': true},
      };
      await tester.pump(_every + const Duration(seconds: 1));
      expect(h.model.outcome, SpotOutcome.someTook);
      expect(h.model.outcomeStrength, closeTo(1, 0.01), reason: 'a new round shows afresh');
      h.answer = {
        'pota': {'ok': true},
      };
      await tester.pump(SpottingControlModel.respotRetry);
      expect(h.model.outcome, SpotOutcome.allTook, reason: 'the retry took it: every source has this round');
      h.model.dispose();
    });

    // A retry is only the sources that refused: judged alone, one refused
    // again would read as no source taking the round.
    testWidgets('a retry refused again is still only some, not none', (tester) async {
      final h = await selfSpot(tester, pota: true, sota: true);
      await h.model.press();
      h.answer = {
        'pota': {'ok': false},
        'sota': {'ok': true},
      };
      await tester.pump(_every + const Duration(seconds: 1));
      await tester.pump(SpottingControlModel.respotRetry);
      expect(h.sent, hasLength(3));
      expect(h.model.outcome, SpotOutcome.someTook);
      h.model.dispose();
    });

    testWidgets('a retry every retried source skips leaves the round to the sources that took it: all of them', (tester) async {
      final h = await selfSpot(tester, pota: true, sota: true);
      await h.model.press();
      h.answer = {
        'pota': {'ok': false},
        'sota': {'ok': true},
      };
      await tester.pump(_every + const Duration(seconds: 1));
      expect(h.model.outcome, SpotOutcome.someTook);
      h.answer = {
        'pota': {'ok': true, 'skipped': true},
      };
      await tester.pump(SpottingControlModel.respotRetry);
      expect(h.sent, hasLength(3));
      expect(h.model.outcome, SpotOutcome.allTook);
      h.model.dispose();
    });

    // The row is painted on the open chip's fill: the theme's own error red
    // and the `important` green fall under 3:1 on some of them.
    testWidgets("each source's icon takes the open chip's colors", (tester) async {
      final h = await selfSpot(tester, pota: true, sota: false);
      for (final brightness in Brightness.values) {
        final theme = buildHaLoTheme(brightness);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SpottingControlFields(model: h.model, state: h.model.state, theme: theme, onPressed: () {}),
            ),
          ),
        );
        Color? colorOf(String icon) => tester.widget<Icon>(find.byIcon(resolveIconName(icon, fallback: MdiIcons.radioTower))).color;
        expect(colorOf('pine-tree'), spotOutcomeColor(theme, SpotOutcome.allTook, selected: true), reason: '$brightness');
        expect(colorOf('image-filter-hdr'), spotOutcomeColor(theme, SpotOutcome.noneTook, selected: true), reason: '$brightness');
      }
      h.model.dispose();
    });

    testWidgets('pulses blue in the last twenty seconds before an auto-respot, over any outcome', (tester) async {
      final h = await selfSpot(tester, pota: true, sota: true);
      await h.model.press();
      final theme = buildHaLoTheme(Brightness.light);
      SecondaryControlSpec spec() => spottingControlSpec(h.model, theme, selected: false, onPressed: () {});
      await tester.pump(_every - const Duration(milliseconds: 20500)); // 20.5 s left
      expect(h.model.respotSoon, isFalse);
      expect(spec().liveTint, isNull);
      await tester.pump(const Duration(milliseconds: 500)); // 20 s left
      expect(h.model.respotSoon, isTrue);
      expect(h.model.respotPulse, closeTo(0, 0.01), reason: "starts from the chip's own colors, with no jump");
      expect(spec().liveTint!.color, respotSoonColor(theme, selected: false));
      expect(spec().liveIconColor, isNull, reason: 'a fading outcome would paint over the pulse');
      h.model.dispose();
    });

    // Each stage's pace is pinned by where its pulses peak and rest: half a
    // pulse in is all blue, a whole pulse in is back at rest.
    testWidgets('pulses slowly from twenty seconds out, once a second from seven, twice a second from three', (tester) async {
      final h = await selfSpot(tester, pota: true, sota: true);
      await h.model.press();
      Future<double> at(int msLeft) async {
        await tester.pump(Duration(milliseconds: (_every.inMilliseconds - msLeft) - h.elapsedMs));
        h.elapsedMs = _every.inMilliseconds - msLeft;
        return h.model.respotPulse;
      }

      // Six pulses over the 13 s from 20 to 7: a half pulse is 13/12 s.
      expect(await at(20000 - 1083), closeTo(1, 0.01));
      expect(await at(20000 - 2167), closeTo(0, 0.01));
      expect(await at(7000), closeTo(0, 0.01), reason: 'at rest as the pace changes');
      expect(await at(6500), closeTo(1, 0.01));
      expect(await at(6000), closeTo(0, 0.01));
      expect(await at(3000), closeTo(0, 0.01));
      expect(await at(2750), closeTo(1, 0.01));
      expect(await at(2500), closeTo(0, 0.01));
      expect(await at(1), closeTo(0, 0.01), reason: 'at rest as the spot goes out');
      h.model.dispose();
    });

    testWidgets('does not pulse with the setting off', (tester) async {
      final h = await selfSpot(tester, pota: true, sota: true);
      h.pulseBeforeRespot = false;
      await h.model.press();
      await tester.pump(_every - const Duration(seconds: 10));
      expect(h.model.respotSoon, isFalse);
      expect(spottingControlSpec(h.model, buildHaLoTheme(Brightness.light), selected: false, onPressed: () {}).liveTint, isNull);
      h.model.dispose();
    });

    // It colors the label as well as the icon, so it is held to the text
    // threshold, on every fill the chip can have: editing a logged QSO swaps
    // in the blue secondary pair, where a careless blue would vanish.
    test('the blue clears 4.5:1 on every fill the chip can have', () {
      double contrast(Color a, Color b) {
        final (hi, lo) = a.computeLuminance() > b.computeLuminance() ? (a, b) : (b, a);
        return (hi.computeLuminance() + 0.05) / (lo.computeLuminance() + 0.05);
      }

      for (final brightness in Brightness.values) {
        final theme = buildHaLoTheme(brightness);
        final colors = brightness == Brightness.dark ? HaLoColors.dark : HaLoColors.light;
        for (final (selected, fill) in [
          (true, theme.colorScheme.tertiary),
          (false, colors.tertiaryLight),
          (true, theme.colorScheme.secondary),
          (false, colors.secondaryLight),
        ]) {
          expect(contrast(respotSoonColor(theme, selected: selected), fill), greaterThanOrEqualTo(4.5), reason: '$brightness, selected $selected, on $fill');
        }
      }
    });

    // Each pair must read on the fill it is drawn on; a color that only
    // clears 3:1 on some fills vanishes on the others.
    // Editing a logged QSO swaps the chip onto the blue secondary pair: a
    // color tuned only for the amber fills fades to 2.5:1 there.
    test('every outcome color clears 3:1 on every fill the chip can have', () {
      double luminance(Color c) => c.computeLuminance();
      double contrast(Color a, Color b) {
        final (hi, lo) = luminance(a) > luminance(b) ? (a, b) : (b, a);
        return (luminance(hi) + 0.05) / (luminance(lo) + 0.05);
      }

      for (final brightness in Brightness.values) {
        final theme = buildHaLoTheme(brightness);
        final colors = brightness == Brightness.dark ? HaLoColors.dark : HaLoColors.light;
        for (final (selected, fill) in [
          (true, theme.colorScheme.tertiary),
          (false, colors.tertiaryLight),
          (true, theme.colorScheme.secondary),
          (false, colors.secondaryLight),
        ]) {
          final drawn = {for (final o in SpotOutcome.values) o: spotOutcomeColor(theme, o, selected: selected)};
          expect(drawn.values.toSet(), hasLength(3), reason: '$brightness selected $selected: three outcomes, three colors');
          for (final MapEntry(key: outcome, value: color) in drawn.entries) {
            expect(contrast(color, fill), greaterThanOrEqualTo(3), reason: '$outcome on $brightness, selected $selected, on $fill');
          }
        }
      }
    });
  });

  group('settings', () {
    setUp(() => AppClock.followZoneClock = true);
    tearDown(() => AppClock.followZoneClock = false);

    Future<_Harness> ready() async {
      final h = _Harness();
      h.vfo = const Vfo(freq: 14285, mode: 'SSB');
      await h.model.refreshSources();
      h.answer = {
        'pota': {'ok': true},
        'sota': {'ok': true},
      };
      return h;
    }

    testWidgets("the offer, and accepting it, use the operator's interval", (tester) async {
      final h = await ready();
      h.respotInterval = const Duration(minutes: 20);
      await h.model.press();
      expect(h.model.state.buttonLabel, 'Re-spot every 20 min');
      await h.model.press();
      await tester.pump(const Duration(minutes: 19, seconds: 50));
      expect(h.sent, hasLength(1));
      await tester.pump(const Duration(seconds: 20));
      expect(h.sent, hasLength(2));
      h.model.dispose();
    });

    // RESPOT's hook cannot read the setting, so it names no interval and
    // leaves it to the panel; a fixed fallback here would ignore the operator.
    testWidgets("a RESPOT naming no interval uses the operator's", (tester) async {
      final h = await ready();
      h.respotInterval = const Duration(minutes: 15);
      await h.model.runCommandAction({'autoRespot': <String, dynamic>{}}, qsos: const [], forward: null);
      expect(h.sent, hasLength(1));
      await tester.pump(const Duration(minutes: 14, seconds: 50));
      expect(h.sent, hasLength(1));
      await tester.pump(const Duration(seconds: 20));
      expect(h.sent, hasLength(2));
      h.model.dispose();
    });

    testWidgets('an interval below five minutes is held at five', (tester) async {
      final h = await ready();
      h.respotInterval = const Duration(minutes: 1);
      await h.model.press();
      expect(h.model.state.buttonLabel, 'Re-spot every 5 min');
      h.model.dispose();
    });

    testWidgets('auto-respot by default starts it without offering', (tester) async {
      final h = await ready();
      h.autoRespotByDefault = true;
      await h.model.press();
      expect(h.model.autoRespotting, isTrue);
      expect(h.model.state.buttonLabel, 'Auto in 10:00. Stop?');
      await tester.pump(_every + const Duration(seconds: 1));
      expect(h.sent, hasLength(2));
      h.model.dispose();
    });

    // Repeating a QRT, or a spot some source refused, is wrong whether the
    // operator was asked first or not.
    testWidgets('auto-respot by default still never starts on a one-off or a partial spot', (tester) async {
      var h = await ready();
      h.autoRespotByDefault = true;
      h.model.commentController.text = 'QRT 73';
      await h.model.press();
      expect(h.model.autoRespotting, isFalse);
      h.model.dispose();

      h = await ready();
      h.autoRespotByDefault = true;
      h.answer = {
        'pota': {'ok': true},
        'sota': {'ok': false},
      };
      await h.model.press();
      expect(h.model.autoRespotting, isFalse);
      expect(
        h.notices.single,
        'Auto re-spot not started: the spot did not go through',
        reason: 'the setting promised a repeat: the operator is told why there is none',
      );
      h.model.dispose();
    });

    testWidgets('auto-respot by default says so when the VFO moved during the spot', (tester) async {
      final h = await ready();
      h.autoRespotByDefault = true;
      h.duringSend = () => h.vfo = const Vfo(freq: 7200, mode: 'SSB');
      await h.model.press();
      expect(h.model.autoRespotting, isFalse);
      expect(h.notices.single, 'Auto re-spot not started: the frequency changed while spotting');
      h.model.dispose();
    });

    Future<List<Map<String, dynamic>?>> typed(_Harness h, String? comment) async {
      final forwarded = <Map<String, dynamic>?>[];
      await h.model.runCommandAction(
        {
          'sendSpots': {'comment': ?comment},
        },
        qsos: const [],
        forward: (action, [params]) async => forwarded.add(params),
      );
      return forwarded;
    }

    testWidgets('auto-respot by default starts on a typed SPOT too', (tester) async {
      final h = await ready();
      h.autoRespotByDefault = true;
      expect(await typed(h, 'CQ POTA'), [
        {'target': 'self'},
      ]);
      expect(h.model.autoRespotting, isTrue);
      h.model.dispose();
    });

    // QRT and QRX send their own code as the comment's start: the station
    // leaving or pausing, which no respot should follow.
    testWidgets('auto-respot by default never starts on a QRT or QRX command', (tester) async {
      for (final comment in ['QRT 73', 'QRX 5']) {
        final h = await ready();
        h.autoRespotByDefault = true;
        expect(await typed(h, comment), [
          {'target': 'self'},
        ], reason: 'nothing went wrong, so nothing to say');
        expect(h.model.autoRespotting, isFalse, reason: comment);
        h.model.dispose();
      }
    });

    // The operator typed QSY having just moved — which ended the respots at
    // the old frequency — and is calling CQ at the new one: without this
    // they would type SPOT straight after it to get them back.
    testWidgets('auto-respot by default starts on a QRV or QSY command, repeating no comment', (tester) async {
      for (final comment in ['QRV 20m SSB', 'QSY from 40m']) {
        final h = await ready();
        h.autoRespotByDefault = true;
        expect(await typed(h, comment), [
          {'target': 'self'},
        ]);
        expect(h.model.autoRespotting, isTrue, reason: comment);
        await tester.pump(_every + const Duration(seconds: 1));
        expect(h.sent.map((s) => s['comment']), [comment, null]);
        h.model.dispose();
      }
    });

    testWidgets('a typed SPOT that cannot start it says why, where it was typed', (tester) async {
      final h = await ready();
      h.autoRespotByDefault = true;
      h.duringSend = () => h.vfo = const Vfo(freq: 7200, mode: 'SSB');
      expect(await typed(h, 'CQ POTA'), [
        {'target': 'self', 'failure': 'Auto re-spot not started: the frequency changed while spotting'},
      ]);
      h.model.dispose();
    });

    // Without it, the picker says 20 minutes while respots go out every 10.
    // Rescheduled under a round still waiting on its hooks, a shorter
    // interval would start a second round beside it: a duplicate spot.
    testWidgets('an interval change during a round waits for that round', (tester) async {
      final h = await ready();
      await h.model.press();
      await h.model.press();
      h.holdSources = Completer();
      await tester.pump(_every + const Duration(seconds: 1));
      expect(h.sent, hasLength(1), reason: 'the round is waiting on its sources');
      h.respotInterval = const Duration(minutes: 5);
      h.model.followIntervalSetting();
      await tester.pump(const Duration(seconds: 1));
      h.holdSources!.complete();
      h.holdSources = null;
      await tester.pump();
      await tester.pump();
      expect(h.sent, hasLength(2), reason: 'one round, not a second beside it');
      await tester.pump(const Duration(minutes: 4, seconds: 50));
      expect(h.sent, hasLength(2));
      await tester.pump(const Duration(seconds: 20));
      expect(h.sent, hasLength(3), reason: 'five minutes after the round, at the new interval');
      h.model.dispose();
    });

    testWidgets('a running auto re-spot follows a change to the interval setting', (tester) async {
      final h = await ready();
      await h.model.press();
      await h.model.press();
      await tester.pump(const Duration(minutes: 8));
      h.respotInterval = const Duration(minutes: 20);
      h.model.followIntervalSetting();
      await tester.pump(const Duration(minutes: 3));
      expect(h.sent, hasLength(1), reason: 'no longer due at ten');
      await tester.pump(const Duration(minutes: 9, seconds: 1));
      expect(h.sent, hasLength(2), reason: 'twenty minutes after the spot');
      h.model.dispose();
    });

    testWidgets('an interval RESPOT named stands when the setting changes', (tester) async {
      final h = await ready();
      expect(await h.model.respotEvery(7), isNull);
      h.respotInterval = const Duration(minutes: 20);
      h.model.followIntervalSetting();
      await tester.pump(const Duration(minutes: 7, seconds: 1));
      expect(h.sent, hasLength(2));
      h.model.dispose();
    });
  });

  // An operation whose own switch or a contest ref rules self-spotting out
  // (`Operation.selfSpotting`). The button is the control's way in, but not
  // the only one — SPOT and RESPOT reach the same send — so each is held to it.
  group('an operation without self-spotting', () {
    _Harness forbidden() => _Harness()
      ..vfo = const Vfo(freq: 14285, mode: 'SSB')
      ..operationData = const {
        'refs': [
          {'type': 'qp', 'ref': 'NY', 'selfSpotting': false},
        ],
      };

    test('says so on the button, and offers neither the button nor the comment', () {
      final h = forbidden();
      final state = h.model.state;
      expect(state.buttonLabel, 'Self-spot disabled');
      expect(state.enabled, isFalse);
      expect(state.showComment, isFalse, reason: 'the focus ladder must not stop on a field that takes no input');
      expect(state.summary, 'Self-spotting', reason: 'the pill keeps its label; only the button explains');
      expect(h.model.selfSpotForbidden, isTrue);
      h.model.dispose();
    });

    testWidgets('shows the comment field, disabled', (tester) async {
      final h = forbidden();
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: SpottingControlFields(model: h.model, state: h.model.state, theme: ThemeData(), onPressed: () {}),
            ),
          ),
        ),
      );
      final comment = tester.widget<TextField>(find.byType(TextField));
      expect(comment.enabled, isFalse);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
      h.model.dispose();
    });

    test('still spots somebody else: a recent QSO being edited', () {
      final h = forbidden();
      h.editingQso = Qso(
        uuid: 'q1',
        operationUuid: 'op',
        data: {
          'their': {'call': 'W1AW'},
          'startAtMillis': nowMillis() - 60 * 1000,
        },
      );
      expect(h.model.selfSpotForbidden, isFalse);
      expect(h.model.state.enabled, isTrue);
      expect(h.model.state.buttonLabel, contains('W1AW'));
      h.model.dispose();
    });

    test('a typed SPOT sends nothing, and goes on to the app with why', () async {
      final h = forbidden();
      final forwarded = <Map<String, dynamic>?>[];
      await h.model.runCommandAction(
        {
          'sendSpots': {'comment': 'CQ NYQP', 'target': 'self'},
        },
        qsos: const [],
        forward: (action, [params]) async => forwarded.add(params),
      );
      expect(h.sent, isEmpty);
      expect(forwarded.single, {'target': 'self', 'failure': 'Self-spot disabled'});
      h.model.dispose();
    });

    test('RESPOT sends nothing, and says why', () async {
      final h = forbidden();
      expect(await h.model.respotEvery(5), 'Self-spot disabled');
      expect(h.sent, isEmpty);
      expect(h.model.autoRespotting, isFalse);
      h.model.dispose();
    });
  });
}
