// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// QsoDraft on its own: what the record carries for what the operator did,
// and what it must not carry for what was merely shown; what a draft keeps
// through a round trip; and the one bracket that tells a programmatic write
// from typing. The panel's widget suite exercises the same rules through
// the fields; these pin the draft's contract where a widget test would have
// to read it off the logged QSO.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/src/logging_controls_draft.dart';
import 'package:halo_widgets/src/logging_controls_exchange.dart';
import 'package:halo_widgets/src/logging_controls_lookup.dart';
import 'package:halo_widgets/src/logging_controls_radio.dart';
import 'package:halo_widgets/src/logging_controls_refs.dart';
import 'package:halo_widgets/src/logging_controls_time.dart';

class _FakeVfoStore implements VfoStore {
  @override
  Vfo vfoA = const Vfo(freq: 14285, mode: 'SSB');
  @override
  void setVfo(String key,
      {double? freq, String? band, String? mode, num? power, bool clearFreq = false, bool clearPower = false}) {}
}

/// The panel's side of the draft: its controllers, its models and its
/// configuration, as the real one wires them.
class _Harness {
  Qso? editingQso;
  bool powerInPlay = false;
  bool hasRadioService = true;
  List<Map<String, dynamic>> controls = const [];
  final store = _FakeVfoStore();
  final operation = const Operation(uuid: 'op', data: {'stationCall': 'KI2D,N0DEV', 'refs': []}, localData: {});

  final call = TextEditingController();
  final sent = TextEditingController();
  final rcvd = TextEditingController();
  final grid = TextEditingController();
  final state = TextEditingController();
  final notes = TextEditingController();

  String get callText => call.text.trim().toUpperCase();

  late final RadioControlModel radio = RadioControlModel(
    config: () => (
      radioService: store,
      hasConfiguredRadio: false,
      radioConnected: false,
      radioName: null,
      onOpenStationConfig: null,
      powerInPlay: () => powerInPlay,
      editingQso: editingQso,
      ituRegion: 2,
      countryCode: 'US',
      enabledBands: null,
      enabledModes: null,
    ),
    draft: draft,
    onRescore: () {},
  )..bind();
  late final TimeControlModel time = TimeControlModel(config: () => (editingQso: editingQso), draft: draft)..bind();
  late final ExchangeFieldsModel exchange = ExchangeFieldsModel(
    config: () => (
      textControls: () => const <Map<String, dynamic>>[],
      editingQso: editingQso,
      operationUuid: 'op',
      serialNumbers: null,
      sequences: null,
      call: callText,
    ),
    draftQsoData: () => draft.toData(),
    onPrimaryFieldKeyEvent: (node, event) => KeyEventResult.ignored,
    onFocusChanged: (node, controller) {},
  );
  late final ActivityRefsModel refs = ActivityRefsModel(
    config: () => (
      activityControls: controls,
      refreshActivityControls: null,
      editingQso: editingQso,
      fieldsLocked: () => false,
      callAtCursor: () => callText,
    ),
    draft: draft,
    draftQsoData: (call) => draft.toData(callOverride: call),
    onControlsRefreshed: () {},
  );
  late final CallLookupModel lookup = CallLookupModel(
    config: () => (lookup: null, workedBefore: null, scoreQso: null, editingQso: editingQso, operation: operation),
    activeCall: () => callText,
    isCallInfoActive: () => false,
    qsoData: (call) => draft.toData(callOverride: call),
    segmented: () => SegmentedOperation.from(operation: operation.data, qsos: const []),
    onResolved: (call, result, phase) {},
    onCleared: () {},
  );
  late final QsoDraft draft = QsoDraft(
    config: () => (
      operation: operation,
      editingQso: editingQso,
      callController: call,
      sentController: sent,
      rcvdController: rcvd,
      gridController: grid,
      stateController: state,
      notesController: notes,
      radio: radio,
      time: time,
      exchange: exchange,
      refs: refs,
      lookup: lookup,
      call: callText,
      rstOrDefault: (text) => text.isEmpty ? '59' : text,
      hasRadioService: hasRadioService,
    ),
  );

  void dispose() {
    draft.dispose();
    lookup.dispose();
    refs.dispose();
    exchange.dispose();
    time.dispose();
    radio.dispose();
    for (final c in [call, sent, rcvd, grid, state, notes]) {
      c.dispose();
    }
  }
}

void main() {
  // The Radio control's frequency listener defers its push past the frame.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('populate nests, and lets go on every exit', () {
    final h = _Harness();
    addTearDown(h.dispose);
    expect(h.draft.isPopulating, isFalse);
    h.draft.populate(() {
      expect(h.draft.isPopulating, isTrue);
      // A seed inside a populate stays one: the inner bracket restores what
      // it found, not false.
      h.draft.populate(() {});
      expect(h.draft.isPopulating, isTrue);
    });
    expect(h.draft.isPopulating, isFalse);
    // A flag left standing would silence the operator's own typing for the
    // rest of the session.
    expect(() => h.draft.populate(() => throw StateError('mid-write')), throwsStateError);
    expect(h.draft.isPopulating, isFalse);
  });

  group('the record', () {
    testWidgets('carries what the operator did, and a round trip keeps it', (tester) async {
      final h = _Harness();
      addTearDown(h.dispose);
      h.call.text = 'w1aw';
      h.rcvd.text = '57';
      h.grid.text = 'FN31PR';
      h.draft.markGridTouched();
      h.draft.theirNameOverride = 'Hiram';
      h.draft.setNote('  first contact  ');
      h.draft.ourExtra['operatorCall'] = 'N0DEV';
      h.draft.theirExtra['city'] = 'Newington';
      // A pane field deliberately cleared: a null, kept as a null.
      h.draft.theirExtra['county'] = null;
      // Programmatic, as the panel writes it: typed, it would arm a push.
      h.draft.populate(() => h.radio.setFrequency(14285));

      final data = h.draft.toData();
      expect(data['our'], {'call': 'KI2D', 'sent': '59', 'operatorCall': 'N0DEV'},
          reason: 'the FIRST station call, and the placeholder report');
      final their = data['their'] as Map<String, dynamic>;
      expect(their['call'], 'W1AW');
      expect(their['sent'], '57');
      expect(their['name'], 'Hiram');
      expect(their['grid'], 'FN31pr', reason: 'conventional Maidenhead casing');
      expect(their['city'], 'Newington');
      expect(data['notes'], 'first contact');
      expect(data['band'], '20m');
      expect(data.containsKey('power'), isFalse, reason: 'power is not in play');
      expect(data['refs'], isEmpty, reason: 'written even empty, so a ref removed during an edit stays removed');

      // The same data back into a fresh draft reads as the same record — a
      // wipe undone, a detour through an earlier QSO.
      final again = _Harness();
      addTearDown(again.dispose);
      again.draft.populate(() => again.draft.applyData(data, restoringDraft: true));
      expect(again.draft.theirNameOverride, 'Hiram');
      expect(again.draft.ourExtra, {'operatorCall': 'N0DEV'}, reason: "a draft's override survives the trip");
      expect(again.draft.theirExtra['city'], 'Newington');
      expect(again.draft.theirExtra.containsKey('county'), isTrue, reason: 'dropping the null would let the old value return');
      expect(again.draft.theirExtra['county'], isNull);
      expect(again.notes.text, 'first contact');
      expect(again.grid.text, 'FN31pr');
      expect(again.radio.freq, 14285);
      // The flag comes back with the field: a draft carries a grid only
      // because it was touched, and without the flag the restored grid would
      // show in the field and drop out of the logged record.
      expect(again.draft.gridTouched, isTrue);
      expect(again.draft.stateTouched, isFalse, reason: 'no state in the draft: nothing was touched');
      final back = again.draft.toData();
      expect(back['our'], data['our']);
      // Minus `locSource`: the first record wrote the grid's center with a
      // null `locSource` to clear a stored one; the restored draft carries
      // that center as a pair of its own, so the second record leaves the key
      // alone — nothing stored to clear.
      expect(back['their'], {...their}..remove('locSource'));
    });

    test('a suggestion carrying a grid displays it without making it touched', () {
      final h = _Harness();
      addTearDown(h.dispose);
      // A deep link or a spot that names a grid: shown, and left for the
      // lookup to keep tracking — a touched grid would stick across every
      // call of a list, and put a grid-center pair on the record.
      h.draft.populate(() => h.draft.applyData({'their': {'call': 'W1AW', 'grid': 'FN31pr'}}));
      expect(h.grid.text, 'FN31pr');
      expect(h.draft.gridTouched, isFalse);
      expect((h.draft.toData()['their'] as Map).containsKey('grid'), isFalse);
    });

    test('a state is written once touched, uppercased, and even empty', () {
      final h = _Harness();
      addTearDown(h.dispose);
      h.state.text = 'ct';
      var their = h.draft.toData()['their'] as Map<String, dynamic>;
      expect(their.containsKey('state'), isFalse, reason: 'merely displayed, not typed');
      h.draft.stateTouched = true;
      their = h.draft.toData()['their'] as Map<String, dynamic>;
      expect(their['state'], 'CT');
      h.state.clear();
      their = h.draft.toData()['their'] as Map<String, dynamic>;
      expect(their['state'], '', reason: 'deliberately cleared: written empty, so the stored value goes');
    });

    test('a band-only record opens on its band, and keeps the mode it had when the record names none', () {
      final h = _Harness();
      addTearDown(h.dispose);
      h.radio.mode = 'CW';
      h.draft.populate(() => h.draft.applyData({'their': {'call': 'W1AW'}, 'band': '40m'}));
      expect(h.radio.band, '40m');
      expect(h.radio.freq, isNull);
      expect(h.radio.mode, 'CW');
    });

    test('a saved record\'s refs go to the control that claims them, or ride along unclaimed', () {
      final h = _Harness();
      addTearDown(h.dispose);
      h.controls = const [
        {
          'key': 'pota/hunter',
          'label': 'POTA',
          'input': {'kind': 'refList', 'refType': 'potaHunter'},
        },
      ];
      final park = {'type': 'potaHunter', 'ref': 'US-1234'};
      final summit = {'type': 'sotaHunter', 'ref': 'W7O/CN-001'};
      h.draft.populate(() => h.draft.applyData({'their': {'call': 'W1AW'}, 'refs': [summit, park]}));
      expect(h.refs.refsFor('pota/hunter'), [park]);
      expect(h.refs.allRefs, containsAll([park, summit]), reason: 'a ref no control shows still round-trips');
      expect(h.draft.toData()['refs'], containsAll([park, summit]));
    });

    test('writes a grid only once touched — then even empty — and replaces a coordinate with its center', () {
      final h = _Harness();
      addTearDown(h.dispose);
      h.grid.text = 'FN31pr';
      var their = h.draft.toData()['their'] as Map<String, dynamic>;
      expect(their.containsKey('grid'), isFalse, reason: 'merely displayed, not typed');

      h.draft.theirExtra['lat'] = 1.0;
      h.draft.theirExtra['lon'] = 2.0;
      h.draft.markGridTouched();
      expect(h.draft.theirExtra.containsKey('lat'), isFalse, reason: 'a typed grid takes the pair out');
      their = h.draft.toData()['their'] as Map<String, dynamic>;
      expect(their['grid'], 'FN31pr');
      expect(their['lat'], isNotNull, reason: "the square's own center stands in for the pair");
      expect(their['locSource'], isNull);

      // A pair typed AFTER the grid, in the same pane visit, still wins.
      h.draft.theirExtra['lat'] = 41.7;
      h.draft.theirExtra['lon'] = -72.7;
      their = h.draft.toData()['their'] as Map<String, dynamic>;
      expect(their['lat'], 41.7);

      h.grid.clear();
      their = h.draft.toData()['their'] as Map<String, dynamic>;
      expect(their['grid'], '', reason: 'deliberately cleared: written empty, so the stored value goes');
    });

    test('a saved record keeps its own our block, its power, and reads as unchanged until edited', () {
      final h = _Harness();
      addTearDown(h.dispose);
      // A stored record carries its uuid in the data too — that is what tells
      // the draft it is not looking at one of its own snapshots.
      final qso = Qso(uuid: 'q1', operationUuid: 'op', data: {
        'uuid': 'q1',
        'our': {'call': 'KI2D', 'sent': '59', 'operatorCall': 'N0DEV'},
        'their': {'call': 'W1AW', 'sent': '57', 'city': 'Newington', 'grid': 'FN31pr'},
        'freq': 14285,
        'band': '20m',
        'mode': 'SSB',
        'power': 100,
        'startAtMillis': 1700000000000,
      });
      h.editingQso = qso;
      // Left over from the draft the operator was composing: the record's
      // own block replaces it, or it would ride into a contact it never met.
      h.draft.ourExtra['operatorCall'] = 'W1ABC';
      h.draft.populate(() => h.draft.applyData(qso.data));
      expect(h.draft.ourExtra, isEmpty, reason: 'a record already in the log is not an override');
      expect(h.draft.gridTouched, isFalse, reason: "a record's grid is displayed, not entered — the guess keeps tracking");
      expect(h.draft.theirExtra, isEmpty);
      expect(h.draft.powerOnRecord, isTrue);
      expect(h.radio.powerController.text, '100');
      expect(h.draft.powerShown, isTrue, reason: 'it went out on the air with that power');
      expect(h.draft.toData()['power'], 100);
      expect(h.draft.differsFrom(qso), isFalse);

      h.radio.powerController.clear();
      expect(h.draft.toData()['power'], isNull, reason: 'written even as null, so a wrong power can be cleared');
      expect(h.draft.differsFrom(qso), isTrue);
    });

    test('a note deleted from a saved contact is cleared; one never written is not stamped', () {
      final h = _Harness();
      addTearDown(h.dispose);
      expect(h.draft.toData().containsKey('notes'), isFalse);
      final qso = Qso(uuid: 'q1', operationUuid: 'op', data: {
        'uuid': 'q1',
        'their': {'call': 'W1AW'},
        'notes': 'the old note',
      });
      h.editingQso = qso;
      h.draft.populate(() => h.draft.applyData(qso.data));
      h.draft.setNote('');
      expect(h.draft.extra.containsKey('notes'), isFalse);
      expect(h.draft.toData()['notes'], '', reason: 'the record carries a note, so the clear has to be written');
    });
  });

  group('what counts as composed', () {
    test('a note, an override, a typed grid — but not an empty pane value or a mirrored VFO', () {
      final h = _Harness();
      addTearDown(h.dispose);
      expect(h.draft.hasComposedValues, isFalse);
      h.draft.setNote('hi');
      expect(h.draft.hasComposedValues, isTrue);
      h.draft.setNote('');
      expect(h.draft.hasComposedValues, isFalse, reason: 'typed and deleted again is nothing to keep');
      // A field cleared in the More pane carries its null in the snapshot.
      h.draft.theirExtra['lat'] = null;
      expect(h.draft.hasComposedValues, isFalse);
      h.draft.theirExtra['city'] = 'Newington';
      expect(h.draft.hasComposedValues, isTrue);
      h.draft.clear();
      expect(h.draft.hasComposedValues, isFalse);

      h.radio.freqController.text = '14074';
      expect(h.draft.hasComposedValues, isFalse, reason: 'with a radio, freq merely mirrors the VFO');
      h.hasRadioService = false;
      expect(h.draft.hasComposedValues, isTrue);
    });

    test('a manual time, a ref, an exchange value or a typed state each count on their own', () {
      final h = _Harness();
      addTearDown(h.dispose);
      h.time.manualStartAtMillis = 1700000000000;
      expect(h.draft.hasComposedValues, isTrue);
      h.time.manualStartAtMillis = null;
      h.refs.setRefs('pota/hunter', [{'type': 'potaHunter', 'ref': 'US-1234'}]);
      expect(h.draft.hasComposedValues, isTrue);
      h.refs.clear();
      h.exchange.typed('cq/zone', '05');
      expect(h.draft.hasComposedValues, isTrue);
      h.exchange.clear();
      expect(h.draft.hasComposedValues, isFalse);
      h.state.text = 'CT';
      expect(h.draft.hasComposedValues, isTrue);
    });
  });

  test('the parked draft is the composing one, whatever record is open', () {
    final h = _Harness();
    addTearDown(h.dispose);
    h.call.text = 'W1AW';
    h.draft.setNote('mid-contact');
    // Stepping into an earlier record: the configuration already shows it by
    // the time the snapshot is taken.
    h.editingQso = Qso(uuid: 'q1', operationUuid: 'op', data: {
      'their': {'call': 'K1ABC', 'city': 'Boston'},
      'startAtMillis': 1700000000000,
    });
    h.draft.snapshotComposing();
    final parked = h.draft.takeComposingSnapshot()!;
    expect((parked['their'] as Map)['call'], 'W1AW');
    expect((parked['their'] as Map).containsKey('city'), isFalse, reason: "not the open record's fields");
    expect(parked.containsKey('startAtMillis'), isFalse, reason: 'no manual time: automatic at log time');
    expect(parked['notes'], 'mid-contact');
    expect(h.draft.takeComposingSnapshot(), isNull);
  });

  test('a session reset forgets the overrides and the undo offer; a clear forgets the extras too', () {
    final h = _Harness();
    addTearDown(h.dispose);
    h.draft.theirNameOverride = 'Hiram';
    h.draft.markGridTouched();
    h.draft.stateTouched = true;
    h.draft.undoSlot.set({'their': {}}, onExpire: () {});
    h.draft.extra['notes'] = 'kept';
    h.draft.resetSession();
    expect(h.draft.theirNameOverride, isNull);
    expect(h.draft.gridTouched, isFalse);
    expect(h.draft.stateTouched, isFalse);
    expect(h.draft.undoSlot.value, isNull);
    expect(h.draft.extra['notes'], 'kept', reason: 'a new context, not a wipe');
    h.draft.clear();
    expect(h.draft.extra, isEmpty);
  });

  test('records compare as data: lists as multisets, and absent, null and empty alike', () {
    expect(qsoDataEquivalent({'refs': [{'type': 'a'}, {'type': 'b'}]}, {'refs': [{'type': 'b'}, {'type': 'a'}]}), isTrue);
    expect(qsoDataEquivalent({'refs': [], 'their': {'sent': ''}}, {'their': {'sent': null}}), isTrue);
    expect(qsoDataEquivalent({'their': {'call': 'W1AW'}}, {'their': {'call': 'W1AX'}}), isFalse);
    expect(qsoDataEquivalent({'refs': [{'type': 'a'}]}, {'refs': [{'type': 'a'}, {'type': 'a'}]}), isFalse);
  });
}
