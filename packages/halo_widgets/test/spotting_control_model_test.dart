// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// SpottingControlModel on its own: the state machine ham2k/halo-dist#10
// specifies, and what a send does to the per-source status.

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
  late final model = SpottingControlModel(
    config: () => (
      sendSpot: ({required sources, required operation, qso, freq, mode, comment, spotterCall}) async {
        sent.add({'sources': sources, 'freq': freq, 'mode': mode, 'comment': comment, 'qso': qso});
        return answer;
      },
      suggestSpotSources: ({required operation, qso}) async => [
        {'hookKey': 'pota', 'icon': 'pine-tree'},
        {'hookKey': 'sota', 'icon': 'image-filter-hdr'},
      ],
      radioService: _FakeVfoStore(vfo),
      editingQso: editingQso,
      operation: const Operation(uuid: 'op', data: {'refs': []}, localData: {'multiIdentifier': 'OP1'}),
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
}
