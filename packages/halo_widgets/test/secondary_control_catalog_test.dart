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
  List<Map<String, dynamic>> activityControls = const [];
  List<String> controlOrder = const [];
  Set<String> hidden = const {};

  late final catalog = SecondaryControlCatalog(
    config: () => (
      radioIcon: Icons.radio,
      hasPowerStore: hasPowerStore,
      canSpot: canSpot,
      activityControls: activityControls,
      controlOrder: controlOrder,
      hiddenControlKeys: hidden,
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
    expect(h.catalog.visibleKeys(), ['time', 'radio', 'spotting', 'pota', 'more'],
        reason: 'Power and Notes wait to be asked for; a text control is a primary field, not a chip');
    expect(h.catalog.powerVisible, isFalse);
  });

  test('a new control slots in beside its descriptor neighbour, not at the end of a stored order', () {
    // An operator who saved the dialog before Spotting existed: their order
    // has no 'spotting', and appending would put it past More.
    final h = _Harness()..controlOrder = const ['time', 'radio', 'more'];
    expect(h.catalog.visibleKeys(), ['time', 'radio', 'spotting', 'more'],
        reason: 'after Radio, its nearest placed predecessor — not past More');

    // A key whose earlier descriptors are all absent still goes last.
    h.controlOrder = const ['more'];
    expect(h.catalog.effectiveOrder(), ['more', 'time', 'radio', 'power', 'spotting', 'notes'],
        reason: 'a run of new keys keeps its own relative order');
  });

  test('a saved decision shows a default-hidden control, and the stored hidden set outranks everything', () {
    final h = _Harness()..controlOrder = const ['time', 'radio', 'power', 'notes', 'more'];
    expect(h.catalog.visibleKeys(), contains('notes'), reason: 'the order records that the operator was asked');
    expect(h.catalog.powerVisible, isTrue, reason: 'this is what lets a composed QSO carry a power at all');

    h.hidden = const {'notes', 'spotting', 'power', 'time'};
    expect(h.catalog.visibleKeys(), ['time', 'radio', 'more'],
        reason: 'hidden wins over a saved order; a mandatory control cannot be hidden');
  });

  test('unknown keys in the stored order are dropped, and duplicates collapse', () {
    final h = _Harness()..controlOrder = const ['ghost', 'radio', 'radio', 'time'];
    expect(h.catalog.effectiveOrder().where((k) => k == 'ghost'), isEmpty);
    expect(h.catalog.visibleKeys().first, 'radio');
    expect(h.catalog.visibleKeys().where((k) => k == 'radio').length, 1);
  });

  test('the settings draft keeps controls hidden under other activities, and lists the undecided as unchecked',
      () {
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
    expect(h.catalog.descriptors().map((d) => d.key), ['time', 'radio', 'notes', 'more']);
    expect(h.catalog.powerVisible, isFalse, reason: 'a saved order cannot conjure a control the operation lacks');
  });
}
