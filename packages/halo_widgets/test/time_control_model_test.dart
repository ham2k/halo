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
import 'package:halo_widgets/src/logging_controls_types.dart';

class _Harness {
  Qso? editingQso;

  /// Only its populating bracket is read by the model under test; the
  /// draft's own data paths are never asked, so it has nothing to read.
  late final draft = QsoDraft(config: () => throw UnsupportedError('the draft is not read here'));
  int notifications = 0;
  Duration increment = ManualTimeHooks.defaultIncrement;
  final stored = <int?>[];
  late final model = TimeControlModel(
    config: () => (editingQso: editingQso, manualTime: ManualTimeHooks(onChanged: stored.add, increment: increment)),
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
    expect(h.model.manualStartAtMillis, DateTime.utc(2020, 1, 1, 0, 0).millisecondsSinceEpoch, reason: 'the controller notified for a selection change only');
    h.model.timeController.text = '12:34';
    h.model.dateController.text = '2026-09-10';
    expect(h.model.effectiveStartAtMillis, DateTime.utc(2026, 9, 10, 12, 34).millisecondsSinceEpoch);
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

  test('"Return to now" hands the timestamp back, and an edited QSO keeps its own until overridden', () {
    final h = _Harness();
    h.model.bind();
    h.model.timeController.text = '12:34';
    h.model.dateController.text = '2026-09-10';
    expect(h.model.canResetToNow, isTrue, reason: 'composing with an override in effect');
    h.model.resetToNow();
    expect(h.model.manualStartAtMillis, isNull);
    expect(h.model.pausedAtMillis, isNull);
    expect(h.stored.last, isNull, reason: 'the operation must not resume a clock the operator handed back');
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

  test('a time typed for a new contact is manual time entry\'s, not part of the draft', () {
    final h = _Harness();
    h.model.bind();
    h.model.timeController.text = '12:34';
    h.model.dateController.text = '2026-09-10';
    final typed = DateTime.utc(2026, 9, 10, 12, 34).millisecondsSinceEpoch;
    expect(h.model.isManual, isTrue);
    expect(h.stored.last, typed);
    // Draft content is what a wipe clears and what makes an empty entry
    // count as composed; the clock is neither.
    expect(h.model.manualStartAtMillis, isNull);

    h.model.advancePast(typed);
    expect(h.model.effectiveStartAtMillis, typed + 60000);
    expect(h.stored.last, typed + 60000);
    h.model.dispose();
  });

  test('a time typed for an existing QSO is that QSO\'s, and leaves manual time entry alone', () {
    final h = _Harness();
    h.model.bind();
    h.editingQso = Qso(uuid: 'q1', operationUuid: 'op', data: {'startAtMillis': DateTime.utc(2025, 1, 2, 3, 4).millisecondsSinceEpoch});
    h.model.timeController.text = '05:06';
    h.model.dateController.text = '2025-01-02';
    expect(h.model.manualStartAtMillis, DateTime.utc(2025, 1, 2, 5, 6).millisecondsSinceEpoch);
    expect(h.model.pausedAtMillis, isNull);
    expect(h.stored, isEmpty);
    h.model.dispose();
  });

  test('advancing outside manual time entry does nothing', () {
    final h = _Harness();
    h.model.advancePast(1000);
    expect(h.model.isLive, isTrue);
    expect(h.stored, isEmpty);
    h.model.dispose();
  });

  test('wiping an already-wiped draft keeps the first wipe\'s undo back into manual time entry', () {
    // Alt+W on an empty draft wipes again while the first wipe's undo is
    // still live; recording the now-live clock would make that undo restore
    // the draft but not the stopped clock.
    final h = _Harness();
    h.model.setPaused(1000);
    h.model.leaveForWipe();
    h.model.leaveForWipe();
    expect(h.model.isLive, isTrue);
    h.model.undoWipe();
    expect(h.model.pausedAtMillis, 1000);
    h.model.dispose();
  });

  group('a time command from the call field', () {
    final base = DateTime.utc(2024, 5, 6, 7, 8);

    _Harness paused() {
      final h = _Harness();
      h.model.pausedAtMillis = base.millisecondsSinceEpoch;
      return h;
    }

    DateTime timeOf(_Harness h) => DateTime.fromMillisecondsSinceEpoch(h.model.effectiveStartAtMillis!, isUtc: true);

    test('moves the manual time, and leaves it manual', () {
      final h = paused();
      h.model.applyCommand({'deltaMillis': -3600000});
      expect(timeOf(h), DateTime.utc(2024, 5, 6, 6, 8));
      expect(h.model.isManual, isTrue);
      expect(h.model.timeController.text, '06:08', reason: 'the open control shows what the command set');
      h.model.dispose();
    });

    test('a step in seconds keeps them, though the fields show only minutes', () {
      // Re-reading the HH:MM fields after the command would drop the :30.
      final h = paused();
      h.model.applyCommand({'deltaMillis': 30000});
      expect(timeOf(h), DateTime.utc(2024, 5, 6, 7, 8, 30));
      expect(h.model.summary, '07:08:30z');
      h.model.applyCommand({'deltaMillis': 30000});
      expect(timeOf(h), DateTime.utc(2024, 5, 6, 7, 9));
      h.model.dispose();
    });

    test('sets the time, or only the minutes, keeping the date', () {
      final h = paused();
      h.model.applyCommand({'hour': 12, 'minute': 33});
      expect(timeOf(h), DateTime.utc(2024, 5, 6, 12, 33));
      h.model.applyCommand({'minute': 34});
      expect(timeOf(h), DateTime.utc(2024, 5, 6, 12, 34));
      h.model.dispose();
    });

    test('seconds are set when given, kept by ::SS alone, and zeroed by a time without them', () {
      // "::30" must not reset the minute, nor "12:33" leave a stale :30 behind.
      final h = paused();
      h.model.applyCommand({'hour': 12, 'minute': 33, 'second': 30});
      expect(timeOf(h), DateTime.utc(2024, 5, 6, 12, 33, 30));
      h.model.applyCommand({'second': 45});
      expect(timeOf(h), DateTime.utc(2024, 5, 6, 12, 33, 45));
      h.model.applyCommand({'minute': 40});
      expect(timeOf(h), DateTime.utc(2024, 5, 6, 12, 40));
      h.model.applyCommand({'second': 15});
      h.model.applyCommand({'hour': 13, 'minute': 0});
      expect(timeOf(h), DateTime.utc(2024, 5, 6, 13));
      h.model.dispose();
    });

    test('sets the date, keeping the year and the time', () {
      final h = paused();
      h.model.applyCommand({'month': 3, 'day': 18});
      expect(timeOf(h), DateTime.utc(2024, 3, 18, 7, 8));
      h.model.dispose();
    });

    test('a Feb 29 in a common year lands on the 28th, not in March', () {
      final h = _Harness();
      h.model.pausedAtMillis = DateTime.utc(2025, 5, 6, 7, 8).millisecondsSinceEpoch;
      h.model.applyCommand({'month': 2, 'day': 29});
      expect(timeOf(h), DateTime.utc(2025, 2, 28, 7, 8));
      h.model.dispose();
    });

    test('on a live clock it starts from now and enters manual time entry', () {
      final h = _Harness();
      final before = nowMillis();
      h.model.applyCommand({'deltaMillis': 60000});
      expect(h.model.isManual, isTrue);
      expect(h.model.pausedAtMillis! - before, inInclusiveRange(60000, 61000));
      h.model.dispose();
    });

    test('NOW returns to live time while composing', () {
      final h = paused();
      h.model.applyCommand({'now': true});
      expect(h.model.isLive, isTrue);
      expect(h.stored.last, isNull);
      h.model.dispose();
    });

    test('an action with nothing to set, or a value out of range, is refused and leaves the clock alone', () {
      // setTime is SDK surface: without the check, DateTime.utc rolls hour 25
      // into tomorrow, and an empty action still stops the clock.
      for (final params in <Map<String, dynamic>>[
        {},
        {'now': 'true'},
        {'minutes': 5},
        {'day': 18},
        {'hour': 25},
        {'minute': 60},
        {'second': -1},
        {'month': 13},
        {'month': 3, 'day': 32},
        {'deltaMillis': 'soon'},
        {'deltaMillis': 101 * 365 * Duration.millisecondsPerDay},
      ]) {
        final h = _Harness();
        expect(() => h.model.applyCommand(params), throwsArgumentError, reason: '$params');
        expect(h.model.isLive, isTrue, reason: '$params');
        h.model.dispose();
      }
    });
  });
}
