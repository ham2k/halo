// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// SecondaryControlCatalog on its own — the order and visibility rules the
// strip is assembled by, with no panel around them. The widget suite drives
// the same rules through the settings dialog; these pin the catalog's
// contract where a panel would hide which side moved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/src/logging_controls_catalog.dart';

class _Harness {
  bool hasPowerStore = true;
  bool canSpot = true;
  bool offersOperator = false;
  List<Map<String, dynamic>> activityControls = const [];
  List<String> controlOrder = const [];
  Set<String> hidden = const {};
  bool spottingAfterReferences = false;
  List<ControlDescriptor> hostControls = const [];

  late final catalog = SecondaryControlCatalog(
    config: () => (
      radioIcon: Icons.radio,
      hasPowerStore: hasPowerStore,
      offersOperator: offersOperator,
      canSpot: canSpot,
      activityControls: activityControls,
      controlOrder: controlOrder,
      hiddenControlKeys: hidden,
      spottingAfterReferences: spottingAfterReferences,
      hostControls: hostControls,
    ),
  );
}

const _pota = {
  'key': 'pota',
  'label': 'POTA',
  'input': {'kind': 'refList'},
};
const _exchange = {
  'key': 'serial',
  'label': 'Serial',
  'input': {'kind': 'text'},
};

void main() {
  test('a fresh install shows the row in descriptor order, with the never-decided controls out', () {
    final h = _Harness()..activityControls = const [_pota, _exchange];
    expect(h.catalog.visibleKeys(), [
      'time',
      'radio',
      'spotting',
      'pota',
      'more',
    ], reason: 'Power and Notes wait to be asked for; a text control is a primary field, not a chip');
    expect(h.catalog.powerVisible, isFalse);
  });

  // Chasing logs the reference first and spots back after it: a default
  // that put Spotting ahead of the references would have every hunter
  // reaching past it, and Notes ahead of Spotting would hide it behind a
  // pill most never use.
  test('spotting after references puts Spotting after every reference and before Notes, by default only', () {
    const sota = {
      'key': 'sota',
      'label': 'SOTA',
      'input': {'kind': 'refList'},
    };
    final h = _Harness()
      ..spottingAfterReferences = true
      ..activityControls = const [_pota, sota];
    expect(h.catalog.effectiveOrder(), ['time', 'radio', 'operator', 'power', 'pota', 'sota', 'spotting', 'notes', 'more']);
    expect(h.catalog.visibleKeys(), ['time', 'radio', 'pota', 'sota', 'spotting', 'more']);

    h.controlOrder = const ['spotting', 'time', 'radio', 'pota', 'sota', 'more'];
    expect(h.catalog.visibleKeys().first, 'spotting', reason: 'an order the operator saved still wins');
  });

  test('a new control slots in beside its descriptor neighbour, not at the end of a stored order', () {
    // An operator who saved the dialog before Spotting existed: their order
    // has no 'spotting', and appending would put it past More.
    final h = _Harness()..controlOrder = const ['time', 'radio', 'more'];
    expect(h.catalog.visibleKeys(), ['time', 'radio', 'spotting', 'more'], reason: 'after Radio, its nearest placed predecessor — not past More');

    // A key whose earlier descriptors are all absent still goes last.
    h.controlOrder = const ['more'];
    expect(h.catalog.effectiveOrder(), [
      'more',
      'time',
      'radio',
      'operator',
      'power',
      'spotting',
      'notes',
    ], reason: 'a run of new keys keeps its own relative order');
  });

  // The app's keyer goes beside the radio it keys: anywhere else, an
  // operator who saved the dialog before it existed would find it past More.
  test("an app's own control sits right after Radio, by default and in a stored order that predates it", () {
    const keyer = ControlDescriptor(key: 'keyer', icon: Icons.key, label: 'Keyer');
    final h = _Harness()..hostControls = const [keyer];
    expect(h.catalog.visibleKeys(), ['time', 'radio', 'keyer', 'spotting', 'more']);

    h.controlOrder = const ['time', 'radio', 'spotting', 'more'];
    expect(h.catalog.visibleKeys(), ['time', 'radio', 'keyer', 'spotting', 'more']);

    h.hidden = const {'keyer'};
    expect(h.catalog.visibleKeys(), isNot(contains('keyer')), reason: 'hidden like any control the operator can turn off');
  });

  test('a saved decision shows a default-hidden control, and the stored hidden set outranks everything', () {
    final h = _Harness()..controlOrder = const ['time', 'radio', 'power', 'notes', 'more'];
    expect(h.catalog.visibleKeys(), contains('notes'), reason: 'the order records that the operator was asked');
    expect(h.catalog.powerVisible, isTrue, reason: 'this is what lets a composed QSO carry a power at all');

    h.hidden = const {'notes', 'spotting', 'power', 'time'};
    expect(h.catalog.visibleKeys(), ['time', 'radio', 'more'], reason: 'hidden wins over a saved order; a mandatory control cannot be hidden');
  });

  test('unknown keys in the stored order are dropped, and duplicates collapse', () {
    final h = _Harness()..controlOrder = const ['ghost', 'radio', 'radio', 'time'];
    expect(h.catalog.effectiveOrder().where((k) => k == 'ghost'), isEmpty);
    expect(h.catalog.visibleKeys().first, 'radio');
    expect(h.catalog.visibleKeys().where((k) => k == 'radio').length, 1);
  });

  test('the settings draft keeps controls hidden under other activities, and lists the undecided as unchecked', () {
    final h = _Harness()..hidden = const {'sota'};
    final draft = h.catalog.settingsDraft();
    // The trap: rebuilding the hidden set from this operation's descriptors
    // alone would drop 'sota', and saving here would un-hide it everywhere.
    expect(draft.hidden, containsAll(['sota', 'power', 'notes']));
    expect(draft.order, isNot(contains('sota')), reason: 'not offered here, so not listed');
  });

  test('Power needs somewhere to keep its value, and Spotting needs a way to send', () {
    final h = _Harness()
      ..hasPowerStore = false
      ..canSpot = false
      ..controlOrder = const ['power', 'spotting'];
    expect(h.catalog.descriptors().map((d) => d.key), ['time', 'radio', 'operator', 'notes', 'more']);
    expect(h.catalog.powerVisible, isFalse, reason: 'a saved order cannot conjure a control the operation lacks');
  });

  group('Operator follows each operation until the operator decides', () {
    // The strip's choices are saved for every operation, but Operator's
    // default is per operation. Saving the dialog to move Notes on a solo
    // operation must not hide Operator on the multi-call ones.
    (List<String>, Set<String>) saveUntouched(_Harness h) {
      final draft = h.catalog.settingsDraft();
      return h.catalog.settingsResult(draft, draft.order, draft.hidden);
    }

    (List<String>, Set<String>) saveWith(_Harness h, {required bool operatorShown}) {
      final draft = h.catalog.settingsDraft();
      final hidden = {...draft.hidden};
      operatorShown ? hidden.remove('operator') : hidden.add('operator');
      return h.catalog.settingsResult(draft, draft.order, hidden);
    }

    test('is listed whatever the operation, checked as its default says', () {
      final h = _Harness();
      expect(h.catalog.settingsDraft().order, contains('operator'));
      expect(h.catalog.settingsDraft().hidden, contains('operator'));
      h.offersOperator = true;
      expect(h.catalog.settingsDraft().hidden, isNot(contains('operator')));
    });

    test('an untouched checkbox records nothing, on either kind of operation', () {
      final solo = _Harness();
      final (order, hidden) = saveUntouched(solo);
      final multi = _Harness()
        ..offersOperator = true
        ..controlOrder = order
        ..hidden = hidden;
      expect(multi.catalog.visibleKeys(), contains('operator'), reason: 'saved on a solo operation, it still follows the multi-call one');

      final (order2, hidden2) = saveUntouched(multi);
      final solo2 = _Harness()
        ..controlOrder = order2
        ..hidden = hidden2;
      expect(solo2.catalog.visibleKeys(), isNot(contains('operator')), reason: 'saved on a multi-call operation, it still follows the solo one');
    });

    test('ticked, it is in the row on every operation', () {
      final (order, hidden) = saveWith(_Harness(), operatorShown: true);
      final solo = _Harness()
        ..controlOrder = order
        ..hidden = hidden;
      expect(solo.catalog.visibleKeys(), contains('operator'));
      final (order2, hidden2) = saveUntouched(solo);
      expect(
        (_Harness()
              ..controlOrder = order2
              ..hidden = hidden2)
            .catalog
            .visibleKeys(),
        contains('operator'),
        reason: 'a later save keeps the decision',
      );
    });

    test('unticked, it is out of the row on every operation', () {
      final (order, hidden) = saveWith(_Harness()..offersOperator = true, operatorShown: false);
      final multi = _Harness()
        ..offersOperator = true
        ..controlOrder = order
        ..hidden = hidden;
      expect(multi.catalog.visibleKeys(), isNot(contains('operator')));
    });
  });
}
