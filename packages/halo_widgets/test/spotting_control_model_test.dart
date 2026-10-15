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
import 'package:halo_widgets/src/logging_controls_spotting.dart';

class _FakeVfoStore implements VfoStore {
  _FakeVfoStore(this.vfoA);
  @override
  Vfo vfoA;
  @override
  void setVfo(String key, {double? freq, String? band, String? mode, num? power, bool clearFreq = false, bool clearPower = false}) {}
}

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

  /// The spotting extensions went away under the panel.
  bool hooksGone = false;

  /// No extension offers a self-spot (the operation's activation ref removed).
  bool noSources = false;

  /// A spotting hook that throws instead of answering.
  bool throwOnSend = false;

  String operationUuid = 'op';
  final notices = <String>[];

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
      suggestSpotSources: ({required operation, qso}) async => noSources
          ? const []
          : [
              {'hookKey': 'pota', 'icon': 'pine-tree'},
              {'hookKey': 'sota', 'icon': 'image-filter-hdr'},
            ],
      radioService: _FakeVfoStore(vfo),
      editingQso: editingQso,
      operation: Operation(uuid: operationUuid, data: const {'refs': []}, localData: const {'multiIdentifier': 'OP1'}),
      notice: notices.add,
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
      for (final comment in ['QRV 20m', 'qrt thanks all', 'QSY', 'QRX 5', 'QRT, 73 all', 'QSY/40m']) {
        h = await spotted(tester, comment: comment);
        expect(h.model.state.buttonLabel, startsWith('Self-spot at'), reason: comment);
        h.model.dispose();
      }
      h = await spotted(tester, comment: 'QRP 5W');
      expect(h.model.state.buttonLabel, 'Re-spot every 10 min', reason: 'only the one-off codes are excluded');
      h.model.dispose();
    });

    testWidgets('repeats the same spot every ten minutes until stopped', (tester) async {
      final h = await spotted(tester);
      await h.model.press();
      expect(h.model.autoRespotting, isTrue);
      expect(h.model.state.summary, 'Auto spots');
      expect(h.model.state.buttonLabel, 'Stop auto spots');
      expect(h.sent, hasLength(1));

      await tester.pump(SpottingControlModel.respotInterval - const Duration(seconds: 5));
      expect(h.sent, hasLength(1), reason: 'not due yet');
      await tester.pump(const Duration(seconds: 10));
      expect(h.sent, hasLength(2));
      expect(h.sent.last['freq'], 14285);
      expect(h.sent.last['comment'], 'CQ POTA', reason: 'the comment cleared from the field after the first send is still the one repeated');
      expect((h.sent.last['sources'] as List).length, 2);

      await tester.pump(SpottingControlModel.respotInterval);
      expect(h.sent, hasLength(3));

      await h.model.press();
      expect(h.model.autoRespotting, isFalse);
      await tester.pump(SpottingControlModel.respotInterval * 2);
      expect(h.sent, hasLength(3), reason: 'stopped means no more spots');
      h.model.dispose();
    });

    // Retrying every source would put a spot on the one that took it every
    // thirty seconds, far under the floor the interval exists to keep; and a
    // source retried until it gives in is asked 120 times an hour.
    testWidgets('a source that refuses a round gets one retry of its own; then it waits for the next round', (tester) async {
      final h = await spotted(tester);
      await h.model.press();
      h.answer = {
        'pota': {'ok': false},
        'sota': {'ok': true},
      };
      await tester.pump(SpottingControlModel.respotInterval + const Duration(seconds: 1));
      expect(h.sent, hasLength(2));
      await tester.pump(SpottingControlModel.respotRetry);
      expect(h.sent, hasLength(3), reason: 'a refusal is retried soon, not in ten minutes');
      expect(keysOf(h.sent.last), ['pota'], reason: 'only the source that refused');
      await tester.pump(SpottingControlModel.respotRetry * 4);
      expect(h.sent, hasLength(3), reason: 'once: refusing again waits for the next round');
      expect(h.model.autoRespotting, isTrue);
      await tester.pump(SpottingControlModel.respotInterval - SpottingControlModel.respotRetry * 5);
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
      expect(h.notices.single, 'Auto spots stopped: the frequency changed');
      expect(h.model.state.buttonLabel, startsWith('Self-spot at'));
      // Back where it was: still off — a respot is armed by the operator, not
      // by the dial passing through.
      h.vfo = const Vfo(freq: 14285, mode: 'SSB');
      h.model.followVfo();
      await tester.pump(SpottingControlModel.respotInterval * 2);
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
      await tester.pump(SpottingControlModel.respotInterval + const Duration(seconds: 1));
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
    // says "Auto spots", glowing at full strength, and nothing goes out.
    testWidgets('stops when the spotting extensions are gone', (tester) async {
      final h = await spotted(tester);
      await h.model.press();
      h.hooksGone = true;
      await tester.pump(SpottingControlModel.respotInterval + const Duration(seconds: 1));
      expect(h.model.autoRespotting, isFalse);
      expect(h.model.respotGlow, 0);
      expect(h.notices.single, contains('Nothing to spot'));
      h.model.dispose();
    });

    testWidgets('stops, and says so, when nothing offers a self-spot any more', (tester) async {
      final h = await spotted(tester);
      await h.model.press();
      h.noSources = true;
      await tester.pump(SpottingControlModel.respotInterval + const Duration(seconds: 1));
      expect(h.model.autoRespotting, isFalse);
      expect(h.notices.single, contains('Nothing to spot'));
      await tester.pump(SpottingControlModel.respotInterval);
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
      await tester.pump(SpottingControlModel.respotInterval + const Duration(seconds: 1));
      expect(h.model.autoRespotting, isFalse);
      expect(h.notices.single, 'Auto spots stopped');
      await tester.pump(SpottingControlModel.respotInterval);
      expect(h.sent, hasLength(2));
      expect(errors.single, isA<StateError>(), reason: 'the error itself still goes on to the zone');
      h.model.dispose();
    });

    testWidgets('stops when the panel is handed another operation', (tester) async {
      final h = await spotted(tester);
      await h.model.press();
      h.operationUuid = 'other';
      await tester.pump(SpottingControlModel.respotInterval + const Duration(seconds: 1));
      expect(h.model.autoRespotting, isFalse);
      expect(h.sent, hasLength(1), reason: "the old activation's spot is not announced as the new one's");
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
    // "Auto spots" while no spot goes out.
    testWidgets('a radio with no frequency gets one retry, then it stops and says so', (tester) async {
      final h = await spotted(tester);
      await h.model.press();
      h.vfo = const Vfo();
      await tester.pump(SpottingControlModel.respotInterval + const Duration(seconds: 1));
      expect(h.model.autoRespotting, isTrue);
      await tester.pump(SpottingControlModel.respotRetry);
      expect(h.model.autoRespotting, isFalse);
      expect(h.notices.single, 'Auto spots stopped: the radio reports no frequency');
      expect(h.sent, hasLength(1));
      h.model.dispose();
    });

    testWidgets('a radio back within the retry carries on', (tester) async {
      final h = await spotted(tester);
      await h.model.press();
      h.vfo = const Vfo();
      await tester.pump(SpottingControlModel.respotInterval + const Duration(seconds: 1));
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
      await tester.pump(SpottingControlModel.respotInterval + const Duration(seconds: 1));
      expect(h.notices, isEmpty, reason: 'the retry may yet take it');
      await tester.pump(SpottingControlModel.respotRetry);
      expect(h.notices, ['pota failed: no alert']);
      await tester.pump(SpottingControlModel.respotInterval);
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
      await tester.pump(SpottingControlModel.respotInterval + const Duration(seconds: 1));
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
      await tester.pump(SpottingControlModel.respotInterval);
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
        await tester.pump(SpottingControlModel.respotInterval * 2);
        expect(h.sent, hasLength(2));
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
        await tester.pump(SpottingControlModel.respotInterval + const Duration(seconds: 1));
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
      await tester.pump(SpottingControlModel.respotInterval - const Duration(seconds: 90));
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
      await tester.pump(SpottingControlModel.respotInterval - const Duration(seconds: 61));
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
        final h = await spotted(tester, comment: 'QRV 20m');
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
}
