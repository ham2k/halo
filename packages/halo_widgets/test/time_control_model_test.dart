// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// TimeControlModel on its own: what counts as the operator taking over the
// timestamp, and what does not. The trap is a programmatic write reading back
// as a manual override — freezing auto-timestamping just for opening the chip.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/src/logging_controls_draft.dart';
import 'package:halo_widgets/src/logging_controls_time.dart';

class _Harness {
  Qso? editingQso;
  /// Only its populating bracket is read by the model under test; the
  /// draft's own data paths are never asked, so it has nothing to read.
  late final draft = QsoDraft(config: () => throw UnsupportedError('the draft is not read here'));
  int notifications = 0;
  late final model = TimeControlModel(
    config: () => (editingQso: editingQso),
    draft: draft,
  )..addListener(() => notifications++);
}

void main() {
  test('seeding the fields is display only: it never becomes an override', () {
    final h = _Harness();
    h.model.bind();
    h.model.seedFields();
    expect(h.model.timeController.text, matches(RegExp(r'^\d\d:\d\d$')));
    expect(h.model.manualStartAtMillis, isNull);
    expect(h.model.isLive, isTrue);
    expect(h.notifications, 0);
    h.model.dispose();
  });

  test('a moved cursor is not an edit, but typed text is', () {
    final h = _Harness();
    h.model.bind();
    // Seeded from a pinned override, not the clock: the typed values below
    // must differ from the baseline whatever time the test runs at.
    h.model.manualStartAtMillis = DateTime.utc(2020, 1, 1, 0, 0).millisecondsSinceEpoch;
    h.model.seedFields();
    final text = h.model.timeController.text;
    h.model.timeController.selection = const TextSelection.collapsed(offset: 0);
    expect(h.model.manualStartAtMillis, DateTime.utc(2020, 1, 1, 0, 0).millisecondsSinceEpoch,
        reason: 'the controller notified for a selection change only');
    h.model.timeController.text = '12:34';
    h.model.dateController.text = '2026-09-10';
    expect(h.model.manualStartAtMillis, DateTime.utc(2026, 9, 10, 12, 34).millisecondsSinceEpoch);
    expect(h.model.isLive, isFalse);
    expect(h.model.summary, '12:34:00z', reason: 'always with seconds, so the pill never switches formats');
    expect(h.notifications, greaterThan(0));
    expect(text, isNot('12:34'));
    h.model.dispose();
  });

  test('a write while the panel populates is not the operator\'s either', () {
    final h = _Harness();
    h.model.bind();
    h.draft.populate(() {
      h.model.timeController.text = '12:34';
      h.model.dateController.text = '2026-09-10';
    });
    expect(h.model.manualStartAtMillis, isNull);
    h.model.dispose();
  });

  test('"Now" hands the timestamp back, and an edited QSO keeps its own until overridden', () {
    final h = _Harness();
    h.model.bind();
    h.model.timeController.text = '12:34';
    h.model.dateController.text = '2026-09-10';
    expect(h.model.canResetToNow, isTrue, reason: 'composing with an override in effect');
    h.model.resetToNow();
    expect(h.model.manualStartAtMillis, isNull);
    expect(h.model.isLive, isTrue);
    expect(h.model.canResetToNow, isFalse);

    final recorded = DateTime.utc(2025, 1, 2, 3, 4).millisecondsSinceEpoch;
    h.editingQso = Qso(uuid: 'q1', operationUuid: 'op', data: {'startAtMillis': recorded});
    expect(h.model.effectiveStartAtMillis, recorded);
    expect(h.model.isLive, isFalse);
    h.model.manualStartAtMillis = recorded + 60000;
    expect(h.model.canResetToNow, isFalse, reason: 'an edited QSO has no automatic time to go back to');
    h.model.manualStartAtMillis = null;
    h.model.seedFields();
    expect(h.model.timeController.text, '03:04');
    expect(h.model.dateController.text, '2025-01-02');
    h.model.dispose();
  });
}
