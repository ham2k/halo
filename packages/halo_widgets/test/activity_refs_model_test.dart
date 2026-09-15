// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ActivityRefsModel on its own: which refs a lookup's guess may put on the
// draft and which it must take back, and when a per-QSO refresh of the
// controls is too late to be believed. The panel's widget suite exercises the
// same rules through the chips; these pin the model's contract where a widget
// test would have to read it off the QSO it logs.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/src/logging_controls_draft.dart';
import 'package:halo_widgets/src/logging_controls_refs.dart';
import 'package:halo_widgets/src/ref_text_input.dart';

const _hunter = {
  'key': 'pota/hunter',
  'label': 'POTA',
  'icon': 'pine-tree',
  'input': {'kind': 'refList', 'refType': 'potaHunter'},
};
const _sota = {
  'key': 'sota/hunter',
  'label': 'SOTA',
  'icon': 'image-filter-hdr',
  'input': {'kind': 'refList', 'refType': 'sotaHunter'},
};

/// A text exchange writing a field of the same ref type as [_hunter] — it
/// reads one field of the ref, and must never claim the whole ref.
const _hunterExchange = {
  'key': 'pota/note',
  'label': 'Note',
  'input': {'kind': 'text', 'refType': 'potaHunter', 'field': 'note'},
};

Map<String, dynamic> _guess(List<Map<String, dynamic>> refs) => {
      'guess': {'refs': refs},
    };

class _Harness {
  _Harness({this.controls = const []});

  List<Map<String, dynamic>> controls;
  Qso? editingQso;
  bool locked = false;
  /// Only its populating bracket is read by the model under test; the
  /// draft's own data paths are never asked, so it has nothing to read.
  late final draft = QsoDraft(config: () => throw UnsupportedError('the draft is not read here'));
  String callAtCursor = 'W1AW';
  Future<List<Map<String, dynamic>>?> Function(Map<String, dynamic> qso)? refresh;
  final refreshedFor = <String>[];

  /// What [ActivityRefsModel.controls] answered inside each refresh notice —
  /// the other models read it there, so it must already be the new set.
  final controlsAtNotice = <List<Map<String, dynamic>>>[];
  int notifications = 0;

  late final ActivityRefsModel model = ActivityRefsModel(
    config: () => (
      activityControls: controls,
      refreshActivityControls: refresh,
      editingQso: editingQso,
      fieldsLocked: () => locked,
      callAtCursor: () => callAtCursor,
    ),
    draft: draft,
    draftQsoData: (call) {
      refreshedFor.add(call);
      return {'their': {'call': call}};
    },
    onControlsRefreshed: () => controlsAtNotice.add(model.controls),
  )..addListener(() => notifications++);
}

void main() {
  group('a guess from the lookup', () {
    test('lands on the refList control of its type, or among the unmatched refs', () {
      final h = _Harness(controls: [_hunter, _hunterExchange]);
      addTearDown(h.model.dispose);
      final park = {'type': 'potaHunter', 'ref': 'US-1234'};
      final summit = {'type': 'sotaHunter', 'ref': 'W7O/CN-001'};
      expect(h.model.applyGuessRefs(_guess([park, summit]), 'W1AW'), isTrue);
      expect(h.model.refsFor('pota/hunter'), [park]);
      expect(h.model.allRefs, [park, summit], reason: 'the summit has no control, and still logs');
      expect(h.notifications, 1);
      expect(h.model.hasRefs, isTrue);
      // The online pass proposes the same refs. Neither type is free any
      // more — the summit's only holder is the unmatched list — so nothing
      // lands, and the answer is false: true here is what would make the
      // ref-change re-lookup cycle forever.
      expect(h.model.applyGuessRefs(_guess([park, summit]), 'W1AW'), isFalse);
      expect(h.model.allRefs, [park, summit]);
      expect(h.notifications, 1);
      // Still the call the guess was made for — a stacked second call moves
      // the cursor off it without correcting it — so nothing is taken back.
      h.model.takeBackGuessUnlessIn(['W1AW', 'K1ABC']);
      expect(h.model.allRefs, [park, summit]);
      expect(h.notifications, 1);
      // Corrected: the guess goes, and the chip repaints.
      h.model.takeBackGuessUnlessIn(['K1ABC']);
      expect(h.model.hasRefs, isFalse);
      expect(h.notifications, 2);
    });

    test('never replaces a ref of a type the draft already carries', () {
      final h = _Harness(controls: [_hunter]);
      addTearDown(h.model.dispose);
      final typed = {'type': 'potaHunter', 'ref': 'US-0001'};
      h.model.setRefs('pota/hunter', [typed]);
      // The operator's own entry outranks the guess; and answering true here
      // on every pass is what would make the ref-change re-lookup cycle.
      expect(h.model.applyGuessRefs(_guess([{'type': 'potaHunter', 'ref': 'US-1234'}]), 'W1AW'), isFalse);
      expect(h.model.refsFor('pota/hunter'), [typed]);
      h.model.takeBackGuessUnlessIn([]);
      expect(h.model.refsFor('pota/hunter'), [typed], reason: 'nothing was guessed, so nothing is taken back');
    });

    test('is refused while editing a saved QSO, while the form is locked, and while populating', () {
      final h = _Harness(controls: [_hunter]);
      addTearDown(h.model.dispose);
      final proposed = _guess([{'type': 'potaHunter', 'ref': 'US-1234'}]);
      h.editingQso = const Qso(uuid: 'q', operationUuid: 'op', data: {});
      expect(h.model.applyGuessRefs(proposed, 'W1AW'), isFalse, reason: 'a saved contact was made somewhere else');
      h.editingQso = null;
      h.locked = true;
      expect(h.model.applyGuessRefs(proposed, 'W1AW'), isFalse);
      h.locked = false;
      h.draft.populate(() => expect(h.model.applyGuessRefs(proposed, 'W1AW'), isFalse));
      expect(h.model.applyGuessRefs(proposed, 'W1AW'), isTrue);
    });

    test('skips a malformed proposal — no type, or no ref', () {
      final h = _Harness(controls: [_hunter]);
      addTearDown(h.model.dispose);
      expect(h.model.applyGuessRefs(_guess([{'type': 'potaHunter'}, {'ref': 'US-1234'}]), 'W1AW'), isFalse);
      expect(h.model.hasRefs, isFalse);
    });

    test('is taken back by identity, leaving an equal ref the operator typed alone', () {
      final h = _Harness(controls: [_hunter]);
      addTearDown(h.model.dispose);
      final guessed = {'type': 'potaHunter', 'ref': 'US-1234'};
      final summit = {'type': 'sotaHunter', 'ref': 'W7O/CN-001'};
      h.model.applyGuessRefs(_guess([guessed, summit]), 'W1AW');
      // The operator adds one that reads the same as the guess. Correcting
      // the call must take back the guess and only the guess.
      final typed = {'type': 'potaHunter', 'ref': 'US-1234'};
      final before = h.notifications;
      h.model.setRefs('pota/hunter', [...h.model.refsFor('pota/hunter'), typed]);
      expect(h.notifications, before + 1, reason: 'the chip counts what the field holds');
      expect(h.model.clearGuessedRefs(), isTrue);
      expect(h.model.refsFor('pota/hunter'), [same(typed)]);
      expect(h.model.allRefs, [same(typed)], reason: 'the guessed summit went too');
      expect(h.model.clearGuessedRefs(), isFalse, reason: 'nothing left to take back');
    });

    test('both lookup passes contribute for one call, and one clear takes both back', () {
      final h = _Harness(controls: [_hunter, _sota]);
      addTearDown(h.model.dispose);
      h.model.applyGuessRefs(_guess([{'type': 'potaHunter', 'ref': 'US-1234'}]), 'W1AW');
      h.model.applyGuessRefs(_guess([{'type': 'sotaHunter', 'ref': 'W7O/CN-001'}]), 'W1AW');
      expect(h.model.refsFor('sota/hunter'), hasLength(1));
      expect(h.model.clearGuessedRefs(), isTrue);
      expect(h.model.hasRefs, isFalse);
    });
  });

  group('the controls in force', () {
    test('a text exchange of the same type never claims a ref; a refList control does', () {
      final h = _Harness(controls: [_hunterExchange, _hunter]);
      addTearDown(h.model.dispose);
      expect(h.model.refListControlKeyForType('potaHunter'), 'pota/hunter');
      expect(h.model.refListControlKeyForType('sotaHunter'), isNull);
      expect(h.model.isRefListControl('pota/hunter'), isTrue);
      expect(h.model.isRefListControl('pota/note'), isFalse);
    });

    test('a refreshed set stands in for the operation\'s until the controls start over',
        () async {
      final h = _Harness(controls: [_hunter]);
      addTearDown(h.model.dispose);
      h.refresh = (qso) async => [_hunter, _sota];
      await h.model.refreshControlsFor('W1AW');
      expect(h.refreshedFor, ['W1AW'], reason: 'asked against the draft for that call');
      expect(h.model.controls, [_hunter, _sota]);
      expect(h.controlsAtNotice, [
        [_hunter, _sota],
      ], reason: 'the other models react to the NEW descriptors, so the set is installed first');
      expect(h.notifications, 1);
      expect(h.model.isRefListControl('sota/hunter'), isTrue, reason: 'a refreshed control claims like any other');
      expect(h.model.refListControlKeyForType('sotaHunter'), 'sota/hunter');
      h.model.controlsChanged();
      expect(h.model.controls, [_hunter]);
      await h.model.refreshControlsFor('W1AW');
      expect(h.model.controls, [_hunter, _sota]);
    });

    test('a refresh that resolves after the call moved on, or after the operation changed, is dropped',
        () async {
      final h = _Harness(controls: [_hunter]);
      addTearDown(h.model.dispose);
      final gate = Completer<void>();
      h.refresh = (qso) async {
        await gate.future;
        return [_hunter, _sota];
      };
      final moved = h.model.refreshControlsFor('W1AW');
      h.callAtCursor = 'K1ABC';
      gate.complete();
      await moved;
      expect(h.model.controls, [_hunter], reason: 'the answer is for a call no longer in the field');
      expect(h.controlsAtNotice, isEmpty);
      expect(h.notifications, 0);

      h.callAtCursor = 'W1AW';
      final stale = h.model.refreshControlsFor('W1AW');
      h.model.controlsChanged();
      await stale;
      expect(h.model.controls, [_hunter], reason: 'fetched against the old operation-level set');
    });

    test('a refresh that resolves after the panel is gone touches nothing', () async {
      // Switching operations mid-lookup is routine. No addTearDown here: the
      // test disposes the model itself, and a second dispose asserts.
      final h = _Harness(controls: [_hunter]);
      final gate = Completer<void>();
      h.refresh = (qso) async {
        await gate.future;
        return [_hunter, _sota];
      };
      final late = h.model.refreshControlsFor('W1AW');
      h.model.dispose();
      gate.complete();
      await late;
      // The notice is the load-bearing check: a disposed model's notify() is
      // already a no-op, so counting notifications would prove nothing.
      expect(h.controlsAtNotice, isEmpty, reason: 'the other models are disposed too');
    });

    test('a refresh that could not fetch keeps what is showing', () async {
      final h = _Harness(controls: [_hunter]);
      addTearDown(h.model.dispose);
      h.refresh = (qso) async => [_hunter, _sota];
      await h.model.refreshControlsFor('W1AW');
      h.refresh = (qso) async => null;
      await h.model.refreshControlsFor('W1AW');
      expect(h.model.controls, [_hunter, _sota]);
      h.refresh = (qso) async => [];
      await h.model.refreshControlsFor('W1AW');
      expect(h.model.controls, isEmpty, reason: 'an empty answer still means "no controls for this QSO"');
    });
  });

  test('a saved QSO\'s refs restore onto their control or among the unmatched, and a clear forgets all', () {
    final h = _Harness(controls: [_hunter]);
    addTearDown(h.model.dispose);
    final park = {'type': 'potaHunter', 'ref': 'US-1234'};
    final park2 = {'type': 'potaHunter', 'ref': 'US-5678'};
    final summit = {'type': 'sotaHunter', 'ref': 'W7O/CN-001'};
    h.model.restore(summit, controlKey: null);
    expect(h.model.hasRefs, isTrue, reason: 'a ref no control shows is still content worth an undo');
    // A twofer: both parks come back onto the one chip.
    h.model.restore(park, controlKey: 'pota/hunter');
    h.model.restore(park2, controlKey: 'pota/hunter');
    expect(h.model.refsFor('pota/hunter'), [park, park2]);
    expect(h.model.allRefs, [park, park2, summit]);
    h.model.clear();
    expect(h.model.hasRefs, isFalse);
    expect(h.model.allRefs, isEmpty);
  });

  testWidgets('the chip\'s field reads the refs as they are now, and an edit reaches the panel', (tester) async {
    final h = _Harness(controls: [_hunter]);
    addTearDown(h.model.dispose);
    var refsChanged = 0;
    // Specified while the chip holds nothing…
    final spec = activityControlSpec(h.model, _hunter, onRefsChanged: () => refsChanged++, decorate: null);
    expect(spec.summary, 'POTA');
    // …and built after a guess landed. The row can build an expanded field
    // from an earlier spec, so a snapshot taken at spec time would hand the
    // field refs it has since moved past.
    final park = {'type': 'potaHunter', 'ref': 'US-1234'};
    h.model.applyGuessRefs(_guess([park]), 'W1AW');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: spec.expandedBuilder))));
    final field = tester.widget<RefTextInput>(find.byType(RefTextInput));
    expect(field.refs, [park]);
    expect(identical(field.focusNode, h.model.focusFor('pota/hunter')), isTrue);

    final typed = {'type': 'potaHunter', 'ref': 'US-0001'};
    field.onChanged([typed]);
    expect(h.model.refsFor('pota/hunter'), [typed]);
    expect(refsChanged, 1, reason: 'a park added after the call has to reach the lookup');
  });
}
