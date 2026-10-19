// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ExchangeFieldsModel on its own: how typed exchanges become ref fields, how
// the options offer is held to the operator's choice, and what a serial
// preview holds and lets go. The panel's widget suite exercises the same
// rules through the fields; these pin the model's contract where a widget
// test would have to read it off a controller.

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/src/logging_controls_exchange.dart';

const _zone = {
  'key': 'cq/zone',
  'label': 'Zone',
  'input': {'kind': 'text', 'refType': 'cq', 'field': 'zone'},
};
const _serial = {
  'key': 'cq/serial',
  'label': 'Serial',
  'input': {
    'kind': 'serial',
    'refType': 'cq',
    'field': 'serial',
    'sequence': {
      'key': 'serial',
      'scope': ['band'],
    },
  },
};

/// A second, unscoped sequence beside the per-band one.
const _other = {
  'key': 'cq/other',
  'label': 'Other #',
  'input': {
    'kind': 'serial',
    'refType': 'cq',
    'field': 'other',
    'sequence': {'key': 'other'},
  },
};
const _counties = [
  {'code': 'ASD', 'name': 'Ashland'},
  {'code': 'CUY', 'name': 'Cuyahoga'},
  {'code': 'WAS', 'name': 'Washington'},
];
const _county = {
  'key': 'qp/county',
  'label': 'County',
  'input': {'kind': 'options', 'refType': 'qp', 'field': 'county', 'options': _counties},
};

/// A number source that says what it was asked to let go of.
class _Source implements SerialNumberSource {
  _Source(this.sequences);
  final SequencesRepository sequences;
  int claims = 0;
  final released = <Set<String>?>[];
  bool failing = false;

  /// A claim on a gated label does not resolve until its gate completes —
  /// the peers' acks still in flight.
  final gates = <String, Completer<void>>{};

  @override
  Future<int> claim(String operationUuid, SequenceRequest request) async {
    claims++;
    if (failing) throw Exception('no peers');
    if (gates[request.label] case final gate?) await gate.future;
    return sequences.peek(operationUuid, request);
  }

  @override
  void release(String operationUuid, {Map<SequenceRequest, int> committed = const {}, Set<String>? labels}) {
    released.add(labels);
  }

  @override
  bool isConflicted(String operationUuid, SequenceRequest request, int number) => false;
}

class _Harness {
  _Harness({this.controls = const [], this.sequences, this.source});

  List<Map<String, dynamic>> controls;
  Qso? editingQso;
  SequencesRepository? sequences;
  _Source? source;
  String call = '';
  Map<String, dynamic> draft = const {};
  int notifications = 0;
  final focusEvents = <FocusNode>[];
  int edits = 0;

  late final model = ExchangeFieldsModel(
    config: () =>
        (textControls: () => controls, editingQso: editingQso, operationUuid: 'op', serialNumbers: source, sequences: sequences, call: call, menuBelow: false),
    draftQsoData: () => draft,
    onPrimaryFieldKeyEvent: (node, event) => KeyEventResult.ignored,
    onFocusChanged: (node, controller) => focusEvents.add(node),
    onEdited: () => edits++,
  )..addListener(() => notifications++);

  /// The fields, built so their focus nodes are attached.
  Widget host() => MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          for (final control in controls)
            TextField(
              key: ValueKey<String>(control['key'] as String),
              controller: model.controllerFor(control['key'] as String),
              focusNode: model.focusFor(control['key'] as String),
              onChanged: (text) => model.typed(control['key'] as String, text),
            ),
        ],
      ),
    ),
  );
}

void main() {
  group('refs from the fields', () {
    test('typed values land on one ref per type; a serial as a number', () {
      final h = _Harness(controls: [_zone, _serial, _county]);
      addTearDown(h.model.dispose);
      h.model.typed('cq/zone', '05');
      h.model.typed('cq/serial', '12');
      h.model.typed('qp/county', 'CUY');
      final refs = h.model.refsWithTextValues([
        {'type': 'pota', 'ref': 'US-0001'},
      ]);
      expect(refs, [
        {'type': 'pota', 'ref': 'US-0001'},
        {'type': 'cq', 'zone': '05', 'serial': 12},
        {'type': 'qp', 'county': 'CUY'},
      ]);
    });

    test('a field the operator emptied is an explicit blank; one never filled in clears the ref field', () {
      final h = _Harness(controls: [_zone, _serial]);
      addTearDown(h.model.dispose);
      // Both emptied on purpose: typed, then backspaced away.
      h.model.typed('cq/zone', '5');
      h.model.typed('cq/zone', '');
      h.model.typed('cq/serial', '57');
      h.model.typed('cq/serial', '');
      final refs = h.model.refsWithTextValues([
        {'type': 'cq', 'zone': '04', 'serial': 7},
      ]);
      // The blank survives as a decision — the save hook stamps a guess only
      // onto an ABSENT field — while the serial, touched or not, is removed
      // rather than written as '', which the allocator could not read.
      expect(refs, [
        {'type': 'cq', 'zone': ''},
      ]);
      expect(h.model.hasTypedValues, isFalse, reason: 'two emptied fields are nothing to undo');
    });

    test('a later call in a list loses only the serial, never the exchange beside it', () {
      final h = _Harness(controls: [_zone, _serial]);
      addTearDown(h.model.dispose);
      expect(
        h.model.refsWithoutSerials([
          {'type': 'cq', 'serial': 1, 'zone': '05'},
        ]),
        [
          {'type': 'cq', 'zone': '05'},
        ],
      );
    });

    test('a field is read from the first control that has a value for it', () {
      final grid = {
        'key': 'vhf/grid',
        'input': {'kind': 'text', 'refType': 'vhf', 'field': 'grid'},
      };
      final h = _Harness(
        controls: [
          grid,
          {...grid, 'key': 'other/grid'},
        ],
      );
      addTearDown(h.model.dispose);
      h.model.typed('other/grid', 'FN20aa');
      expect(h.model.valueForField('grid'), 'FN20aa', reason: 'the first control is empty; it does not answer');
    });

    test('a ref left with nothing but its type is dropped', () {
      final h = _Harness(controls: [_zone]);
      addTearDown(h.model.dispose);
      expect(
        h.model.refsWithTextValues([
          {'type': 'cq', 'zone': '04'},
        ]),
        isEmpty,
      );
    });

    test('a value restored off a saved QSO counts as typed, so a suggestion never overwrites it', () {
      final h = _Harness(
        controls: [
          {
            ..._zone,
            'input': {..._zone['input'] as Map, 'suggestedValue': '14'},
          },
        ],
      );
      addTearDown(h.model.dispose);
      h.model.applySuggestedValues(call: 'W1AW');
      expect(h.model.controllerFor('cq/zone').text, '14', reason: 'untouched: the lookup fills it');
      expect(h.model.isTouched('cq/zone'), isFalse);
      h.model.restore('cq/zone', '05');
      h.model.applySuggestedValues(call: 'W1AW');
      expect(h.model.controllerFor('cq/zone').text, '05');
      expect(h.model.valueOf('cq/zone'), '05');
      expect(h.model.isTouched('cq/zone'), isTrue);
    });

    test('a prefill is taken back when the callsign it was made for leaves the field', () {
      // Driven by the call field, not by a refresh: correcting W6ABC to a
      // station the lookup has nothing for — or whose refresh fails, or is
      // dropped — never reaches `applySuggestedValues`, and the old guess left
      // behind is a legal value in an untouched field, which nothing tints and
      // `refsWithTextValues` files as the new station's exchange.
      final h = _Harness(
        controls: [
          {
            ..._zone,
            'input': {..._zone['input'] as Map, 'suggestedValue': '14'},
          },
        ],
      );
      addTearDown(h.model.dispose);
      h.model.applySuggestedValues(call: 'W6ABC');
      expect(h.model.valueOf('cq/zone'), '14');

      h.model.withdrawSuggestionsExcept(call: 'W2XYZ');
      expect(h.model.valueOf('cq/zone'), '', reason: 'the guess for the old callsign does not survive it');
      expect(h.model.controllerFor('cq/zone').text, '');
      expect(h.model.refsWithTextValues(const []), isEmpty);

      // And the new caller's own suggestion goes in once it arrives.
      h.controls = [
        {
          ..._zone,
          'input': {..._zone['input'] as Map, 'suggestedValue': '05'},
        },
      ];
      h.model.applySuggestedValues(call: 'W2XYZ');
      expect(h.model.valueOf('cq/zone'), '05');

      // Clearing the field takes it back too.
      h.model.withdrawSuggestionsExcept(call: '');
      expect(h.model.valueOf('cq/zone'), '');
    });

    test('a prefill stands while its callsign does, whatever else refreshes', () {
      // `loggingControls` is also called with no `qso` — a plain operation
      // refresh — and every contest then declares no `suggestedValue`. That is
      // "nobody was asked", not "no suggestion for this caller": treated
      // alike, any other refresh of the panel would wipe the prefill.
      final h = _Harness(
        controls: [
          {
            ..._zone,
            'input': {..._zone['input'] as Map, 'suggestedValue': '14'},
          },
        ],
      );
      addTearDown(h.model.dispose);
      h.model.applySuggestedValues(call: 'W6ABC');
      expect(h.model.valueOf('cq/zone'), '14');

      h.controls = [_zone];
      h.model.applySuggestedValues(call: 'W6ABC');
      h.model.withdrawSuggestionsExcept(call: 'W6ABC');
      expect(h.model.valueOf('cq/zone'), '14', reason: 'same callsign, so the guess still stands');
    });

    test('an empty call makes no prefill and takes back every one made', () {
      // The panel passes an empty call when the cursor names no station — an
      // emptied field, or the blank entry after a just-typed comma. A prefill
      // kept there would be logged for whatever call is typed next.
      final h = _Harness(
        controls: [
          {
            ..._zone,
            'input': {..._zone['input'] as Map, 'suggestedValue': '14'},
          },
        ],
      );
      addTearDown(h.model.dispose);
      h.model.applySuggestedValues(call: '');
      expect(h.model.valueOf('cq/zone'), '', reason: 'no station to make it for');

      h.model.applySuggestedValues(call: 'K2ABC');
      expect(h.model.valueOf('cq/zone'), '14');
      h.model.withdrawSuggestionsExcept(call: '');
      expect(h.model.valueOf('cq/zone'), '', reason: 'the field no longer names K2ABC');
    });

    test('what the operator typed over a prefill is theirs, and never taken back', () {
      final h = _Harness(
        controls: [
          {
            ..._zone,
            'input': {..._zone['input'] as Map, 'suggestedValue': '14'},
          },
        ],
      );
      addTearDown(h.model.dispose);
      h.model.applySuggestedValues(call: 'W6ABC');
      h.model.typed('cq/zone', '15');
      h.model.withdrawSuggestionsExcept(call: 'W2XYZ');
      expect(h.model.valueOf('cq/zone'), '15');
    });
  });

  group('the options offer', () {
    testWidgets('follows focus and the keystrokes, and a dismissal lasts until the next one', (tester) async {
      final h = _Harness(controls: [_county]);
      addTearDown(h.model.dispose);
      h.model.focusFor('qp/county');
      expect(h.model.attachedFocusFor('qp/county'), isNull, reason: 'a node with no field yet is an orphan the focus ladder must not sort');
      await tester.pumpWidget(h.host());
      expect(h.model.attachedFocusFor('qp/county'), isNotNull);
      expect(h.model.suggestions, isEmpty, reason: 'no options field has focus');
      h.model.focusFor('qp/county').requestFocus();
      await tester.pump();
      expect(h.focusEvents, isNotEmpty, reason: 'the panel is told, so its focus ladder can note the node');
      expect(h.model.menuOpen, isTrue, reason: 'an empty field offers the whole set');
      await tester.enterText(find.byKey(const ValueKey('qp/county')), 'WA');
      expect([for (final o in h.model.suggestions) o.code], ['WAS']);
      h.model.dismissMenu();
      expect(h.model.menuOpen, isFalse);
      await tester.enterText(find.byKey(const ValueKey('qp/county')), 'WAS');
      expect(h.model.menuOpen, isTrue, reason: 'a new character is a new question');
    });

    testWidgets('an arrow that cannot move the highlight is not a choice; a tap is', (tester) async {
      final h = _Harness(controls: [_county]);
      addTearDown(h.model.dispose);
      await tester.pumpWidget(h.host());
      h.model.focusFor('qp/county').requestFocus();
      await tester.pump();
      // 'SH' matches Ashland and Washington by substring only — the prefix
      // rule refuses both.
      await tester.enterText(find.byKey(const ValueKey('qp/county')), 'SH');
      expect([for (final o in h.model.suggestions) o.code], ['ASD', 'WAS']);
      // ↓ from an untouched highlight: already at the bottom, nothing moves.
      h.model.moveSelection(-1);
      expect(h.model.acceptOnLeave(), isFalse);
      expect(h.model.valueOf('qp/county'), 'SH', reason: 'Space must not rewrite SH as a county nobody worked');
      final before = h.notifications;
      expect(h.model.acceptSuggestion(index: 0, explicit: true), isTrue);
      expect(h.model.valueOf('qp/county'), 'ASD');
      expect(h.model.controllerFor('qp/county').text, 'ASD');
      expect(h.model.isTouched('qp/county'), isTrue);
      expect(h.notifications, greaterThan(before), reason: 'the field repaints on an accept');
      expect(h.model.acceptSuggestion(index: 0, explicit: true), isFalse, reason: 'accepting the value already in the field is a no-op, not a second write');
    });

    // The live score reads the exchange. An edit that does not say so leaves the
    // pills judged on the exchange as it stood when the call was typed — a
    // county typed after the call never shows its New Mult.
    testWidgets('a typed value and an accepted suggestion are edits; a lookup prefill is not', (tester) async {
      final h = _Harness(
        controls: [
          {
            ..._county,
            'input': {..._county['input'] as Map, 'suggestedValue': 'WAS'},
          },
        ],
      );
      addTearDown(h.model.dispose);
      await tester.pumpWidget(h.host());
      expect(h.model.applySuggestedValues(call: 'W1AW'), isTrue, reason: 'the panel re-scores on a changed value');
      expect(h.edits, 0, reason: 'nobody typed: no keystroke pause to hold the pills for');
      expect(h.model.applySuggestedValues(call: 'W1AW'), isFalse, reason: 'the same value again changes nothing to score');
      h.model.focusFor('qp/county').requestFocus();
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('qp/county')), 'AS');
      expect(h.edits, 1);
      expect(h.model.acceptSuggestion(index: 0, explicit: true), isTrue);
      expect(h.edits, 2);
      expect(h.model.acceptSuggestion(index: 0, explicit: true), isFalse);
      expect(h.edits, 2, reason: 'a no-op accept changed nothing to score');
    });

    testWidgets('a walked highlight is taken by Space as-is, and Enter takes it instead of logging', (tester) async {
      final h = _Harness(controls: [_county]);
      addTearDown(h.model.dispose);
      await tester.pumpWidget(h.host());
      h.model.focusFor('qp/county').requestFocus();
      await tester.pump();
      expect(h.model.acceptPendingChoice(), isFalse, reason: 'nothing walked to: Enter is just Enter');
      // The whole set, best at index 0; +1 walks away from the field.
      h.model.moveSelection(1);
      expect(h.model.acceptPendingChoice(), isTrue);
      expect(h.model.valueOf('qp/county'), 'CUY');
      expect(h.model.acceptPendingChoice(), isFalse, reason: 'the menu closed on the accepted value: nothing pends');

      // 'A' is a prefix of ASD alone; the other rows are substring hits Space
      // would refuse on its own. Walked to, one is taken as-is.
      await tester.enterText(find.byKey(const ValueKey('qp/county')), 'A');
      final second = h.model.suggestions[1].code;
      h.model.moveSelection(1);
      expect(h.model.acceptOnLeave(), isTrue);
      expect(h.model.valueOf('qp/county'), second);
    });

    testWidgets('leaving the field forgets its dismissal and its highlight', (tester) async {
      final h = _Harness(controls: [_county, _zone]);
      addTearDown(h.model.dispose);
      await tester.pumpWidget(h.host());
      h.model.focusFor('qp/county').requestFocus();
      await tester.pump();
      h.model.moveSelection(1);
      h.model.dismissMenu();
      h.model.focusFor('cq/zone').requestFocus();
      await tester.pump();
      h.model.focusFor('qp/county').requestFocus();
      await tester.pump();
      // Coming back is a new look at the field: the offer shows again, and
      // Enter logs rather than taking a row chosen before the operator left.
      expect(h.model.menuOpen, isTrue);
      expect(h.model.acceptPendingChoice(), isFalse);
    });

    testWidgets('a multi-value field replaces only the value the cursor is in, borrowing the first prefix', (tester) async {
      final h = _Harness(
        controls: [
          {
            ..._county,
            'input': {
              ..._county['input'] as Map,
              'options': const [
                {'code': 'ORDES', 'name': 'Deschutes'},
                {'code': 'ORJEF', 'name': 'Jefferson'},
                {'code': 'IDJEF', 'name': 'Jefferson'},
              ],
              'multiValue': {'separator': '/', 'inheritPrefix': 2},
            },
          },
        ],
      );
      addTearDown(h.model.dispose);
      await tester.pumpWidget(h.host());
      h.model.focusFor('qp/county').requestFocus();
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('qp/county')), 'ORDES/JEF');
      expect([for (final o in h.model.suggestions) o.code], ['ORJEF', 'IDJEF'], reason: 'the borrowed prefix names Oregon; the literal name match follows');
      expect(h.model.acceptOnLeave(), isTrue);
      expect(h.model.controllerFor('qp/county').text, 'ORDES/ORJEF');
      expect(h.model.controllerFor('qp/county').selection.baseOffset, 'ORDES/ORJEF'.length);
    });
  });

  group('serial previews', () {
    late HaLoDatabase db;
    setUp(() => db = HaLoDatabase(NativeDatabase.memory()));

    testWidgets('a serial preview is not a suggestion, and is never taken back as one', (tester) async {
      // Serial previews land in an untouched field too. A contest that declares
      // no `suggestedValue` must not thereby wipe the number the sequence is
      // about to issue.
      final sequences = SequencesRepository(db);
      final h = _Harness(controls: [_serial], sequences: sequences, source: _Source(sequences));
      addTearDown(h.model.dispose);
      h.draft = {'band': '20m'};
      h.call = 'W1';
      await h.model.refreshSerialPreviews();
      expect(h.model.valueOf('cq/serial'), '1');

      h.model.applySuggestedValues(call: 'W1');
      h.model.withdrawSuggestionsExcept(call: '');
      expect(h.model.valueOf('cq/serial'), '1');
    });

    tearDown(() => db.close());

    testWidgets('an idle draft holds no number; the first edit takes one; a wipe lets it go and refills', (tester) async {
      final sequences = SequencesRepository(db);
      final h = _Harness(controls: [_serial, _other], sequences: sequences, source: _Source(sequences));
      addTearDown(h.model.dispose);
      h.draft = {'band': '20m'};
      await h.model.refreshSerialPreviews();
      expect(h.source!.claims, 0);
      expect(h.model.valueOf('cq/serial'), '');

      h.call = 'W1';
      await h.model.refreshSerialPreviews();
      expect(h.model.valueOf('cq/serial'), '1');
      expect(h.model.valueOf('cq/other'), '1');
      expect(h.model.isTouched('cq/serial'), isFalse, reason: 'shown, not typed: commit still allocates');
      expect(h.notifications, 1);
      await h.model.refreshSerialPreviews();
      expect(h.source!.claims, 2, reason: 'same declarations, same labels: no re-query');

      // The draft moves band: the per-band label it left is released, and
      // only that one — the unscoped sequence beside it keeps its number.
      h.draft = {'band': '40m'};
      await h.model.refreshSerialPreviews();
      expect(h.source!.released, [
        {'cq/serial|20m'},
      ]);

      // A number the operator typed over is what they are sending: another
      // band change re-queries the sequence — 15m's next is 8, not the 1
      // already shown, so the fill would run — but must not overwrite it.
      h.model.typed('cq/serial', '57');
      await tester.pump();
      sequences.noteIssued('op', h.model.serialSequences.first.requestFor(const Qso(uuid: '', operationUuid: 'op', data: {'band': '15m'})), 7);
      h.draft = {'band': '15m'};
      await h.model.refreshSerialPreviews();
      expect(h.model.valueOf('cq/serial'), '57');
      expect(h.model.valueOf('cq/other'), '1');

      // Cleared (an undo-wipe, an edit opening): the fields empty, the hold
      // is the panel's to release — and the next refresh must be able to
      // refill, so the change detection starts over.
      h.model.clear();
      expect(h.model.valueOf('cq/serial'), '', reason: 'cleared, until the refresh lands');
      await tester.pump();
      expect(h.model.valueOf('cq/serial'), '8', reason: 'no longer typed over: the sequence answers again');
      expect(h.model.valueOf('cq/other'), '1');
      expect(h.source!.released, hasLength(2), reason: 'a clear keeps the hold; only the panel lets go');
    });

    testWidgets('an exchange typed before the call starts the contact, and takes the number', (tester) async {
      final sequences = SequencesRepository(db);
      final h = _Harness(controls: [_zone, _serial], sequences: sequences, source: _Source(sequences));
      addTearDown(h.model.dispose);
      h.draft = {'band': '20m'};
      h.model.typed('cq/zone', '05');
      await tester.pump();
      expect(h.model.valueOf('cq/serial'), '1');
    });

    testWidgets('forgetting the previews makes the next refresh ask again, without letting go', (tester) async {
      final sequences = SequencesRepository(db);
      final h = _Harness(controls: [_serial], sequences: sequences, source: _Source(sequences));
      addTearDown(h.model.dispose);
      h.draft = {'band': '20m'};
      h.call = 'W1';
      await h.model.refreshSerialPreviews();
      expect(h.source!.claims, 1);
      // A source or an operation swapped under the panel: the panel released
      // the old hold itself, and the new source has to be asked.
      h.model.forgetSerialState();
      await h.model.refreshSerialPreviews();
      expect(h.source!.claims, 2);
      expect(h.source!.released, isEmpty);
    });

    testWidgets('a claim that settles after the draft moved on is not the current number', (tester) async {
      final sequences = SequencesRepository(db);
      final h = _Harness(controls: [_serial], sequences: sequences, source: _Source(sequences));
      addTearDown(h.model.dispose);
      // 20m has issued up to 7, so its next is 8; 40m starts at 1.
      sequences.noteIssued('op', h.model.serialSequences.single.requestFor(const Qso(uuid: '', operationUuid: 'op', data: {'band': '20m'})), 7);
      h.source!.gates['cq/serial|20m'] = Completer<void>();
      h.draft = {'band': '20m'};
      h.call = 'W1';
      final stale = h.model.refreshSerialPreviews();
      h.draft = {'band': '40m'};
      await h.model.refreshSerialPreviews();
      expect(h.model.valueOf('cq/serial'), '1');
      h.source!.gates['cq/serial|20m']!.complete();
      await stale;
      expect(h.model.valueOf('cq/serial'), '1', reason: "20m's late answer is for a draft that no longer exists");
    });

    testWidgets('a claim that fails refuses the commit, and never fills the field', (tester) async {
      final sequences = SequencesRepository(db);
      final h = _Harness(controls: [_serial], sequences: sequences, source: _Source(sequences)..failing = true);
      addTearDown(h.model.dispose);
      h.call = 'W1';
      await expectLater(h.model.refreshSerialPreviews(), throwsException);
      expect(h.model.valueOf('cq/serial'), '');
      expect(await h.model.settleSerialClaims(), isFalse);
    });

    testWidgets('editing a logged QSO never previews: its number was sent long ago', (tester) async {
      final sequences = SequencesRepository(db);
      final h = _Harness(controls: [_serial], sequences: sequences, source: _Source(sequences));
      addTearDown(h.model.dispose);
      h.editingQso = const Qso(uuid: 'q', operationUuid: 'op', data: {'band': '20m'});
      h.call = 'W1AW';
      await h.model.refreshSerialPreviews();
      expect(h.source!.claims, 0);
    });
  });
}
