// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Time control: when the contact being composed is stamped. Automatic —
// the moment of logging — until the operator types a time or date, or opens
// an existing (necessarily historical) QSO; then that time, until "Now"
// hands it back. [TimeControlModel] holds the two fields and the override on
// behalf of `LoggingControls`; [TimeControlFields] draws the expanded row.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';

import 'logging_controls_draft.dart';
import 'panel_model.dart';
import 'spacing.dart';
import 'theme.dart';

/// What the model reads from the panel's live configuration.
typedef TimeControlConfig = ({Qso? editingQso});

/// The Time control's state. See the file comment.
class TimeControlModel extends ChangeNotifier with PanelModel {
  TimeControlModel({required this.config, required this.draft});

  /// The panel's configuration as it stands right now.
  final TimeControlConfig Function() config;

  /// The draft the panel composes — read for [QsoDraft.isPopulating]: a
  /// programmatic write to the fields is never a manual override. The
  /// model's own seed runs under the same bracket ([seedFields]).
  final QsoDraft draft;

  final timeController = TextEditingController();
  final dateController = TextEditingController();
  final timeFocus = FocusNode();
  final dateFocus = FocusNode();

  /// Overrides the QSO's timestamp when set via the Time control; null
  /// means "use the current time at the moment of logging."
  int? manualStartAtMillis;

  /// The time/date text as of the last notification, so a selection-only one
  /// can be told apart from a real edit. Kept current even while the panel is
  /// populating — a seeded value that never got recorded here would look like
  /// an edit the next time the cursor moved.
  String _lastText = '';


  bool _bound = false;

  static String fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  static String fmtTimeWithSeconds(DateTime dt) => '${fmtTime(dt)}:${dt.second.toString().padLeft(2, '0')}';
  static String fmtDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// The best-known timestamp for the entry being composed/edited: a manual
  /// override if one's been set, else the existing QSO's recorded time when
  /// editing one, else null — meaning "still automatic, tracks live now."
  int? get effectiveStartAtMillis => manualStartAtMillis ?? config().editingQso?.startAtMillis;

  /// Whether the chip should tick: nothing overrides the timestamp, so it
  /// shows the live clock.
  bool get isLive => effectiveStartAtMillis == null;

  /// Whether "Now" is offered: only while composing a new QSO with a manual
  /// override in effect — there's no "automatic" time to reset to when
  /// editing an existing, necessarily historical, entry.
  bool get canResetToNow => config().editingQso == null && manualStartAtMillis != null;

  /// The chip's text. Always shows seconds, even when they're not meaningful
  /// (a manually entered/edited time has none — it comes from a plain HH:MM
  /// field — so it's always :00 rather than the pill silently switching
  /// formats).
  String get summary {
    final millis = effectiveStartAtMillis;
    final dt = millis == null ? nowUtc() : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    return '${fmtTimeWithSeconds(dt)}z';
  }

  /// Attaches the field listeners and takes the baseline from whatever the
  /// fields hold: a seed that ran before the listeners existed notified
  /// nobody, and an out-of-date baseline reads the first cursor move as an
  /// edit. A second call is a no-op.
  void bind() {
    if (_bound) return;
    _bound = true;
    timeController.addListener(_onChanged);
    dateController.addListener(_onChanged);
    recordText();
  }

  @override
  void dispose() {
    timeController.dispose();
    dateController.dispose();
    timeFocus.dispose();
    dateFocus.dispose();
    super.dispose();
  }

  /// Re-baselines the edit detector after a programmatic write.
  void recordText() => _lastText = '${timeController.text} ${dateController.text}';

  /// (Re-)populates the time/date fields from [effectiveStartAtMillis], or
  /// from the current time if that's null — called whenever the Time
  /// control is opened, so it never shows a stale snapshot from an earlier
  /// open. Display-only: never read back as an override.
  void seedFields() {
    final millis = effectiveStartAtMillis;
    final dt = millis != null ? DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true) : nowUtc();
    // Under the bracket: without it these programmatic sets would read back
    // as a manual override — freezing auto-timestamping just for opening the
    // Time chip, and making "Now" re-freeze the clock it just released. The
    // bracket is the panel-wide one, so every listener that stands down for a
    // programmatic write stands down here too; these two controllers have no
    // listener but this model's own.
    draft.populate(() {
      timeController.text = fmtTime(dt);
      dateController.text = fmtDate(dt);
      recordText();
    });
  }

  /// Back to automatic timestamping.
  void resetToNow() {
    manualStartAtMillis = null;
    seedFields();
    notify();
  }

  void _onChanged() {
    // A TextEditingController notifies on SELECTION changes too, not just
    // text. Focusing a field moves the cursor to the end (the panel's focus
    // listeners), so without this guard merely EXPANDING the Time control
    // would read its own seeded value back as a manual override:
    // auto-timestamping would freeze and the "Now" button would appear,
    // without the operator typing anything.
    final text = '${timeController.text} ${dateController.text}';
    final changed = text != _lastText;
    _lastText = text;
    if (draft.isPopulating || !changed) return;
    final time = timeController.text.split(':');
    final date = dateController.text.split('-');
    if (time.length != 2 || date.length != 3) return;
    final hour = int.tryParse(time[0]);
    final minute = int.tryParse(time[1]);
    final year = int.tryParse(date[0]);
    final month = int.tryParse(date[1]);
    final day = int.tryParse(date[2]);
    if (hour == null || minute == null || year == null || month == null || day == null) {
      return;
    }
    manualStartAtMillis = DateTime.utc(year, month, day, hour, minute).millisecondsSinceEpoch;
    notify();
  }
}

/// The Time control's expanded row: the time and date fields, and a "Now"
/// button back to automatic timestamping when the model offers one.
class TimeControlFields extends StatelessWidget {
  const TimeControlFields({
    super.key,
    required this.model,
  });

  final TimeControlModel model;

  @override
  Widget build(BuildContext context) {
    final style = haloMonoStyle(context, fontSize: 15, fontWeight: FontWeight.w500);
    final labelColor = Theme.of(context).colorScheme.onTertiaryContainer;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          // Same width as the date field beside it — wide enough to fit a
          // full "2026-07-11", even though the time value itself ("16:54")
          // is shorter.
          width: 120,
          child: TextField(
            controller: model.timeController,
            focusNode: model.timeFocus,
            selectAllOnFocus: false,
            style: style,
            decoration: poloFieldDecoration(context, t.loggingControls.timeUtc, labelColor: labelColor),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9:]'))],
          ),
        ),
        const SizedBox(width: Space.md),
        SizedBox(
          width: 120,
          child: TextField(
            controller: model.dateController,
            focusNode: model.dateFocus,
            style: style,
            decoration: poloFieldDecoration(context, t.loggingControls.date, labelColor: labelColor),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9-]'))],
          ),
        ),
        if (model.canResetToNow) ...[
          const SizedBox(width: Space.md),
          TextButton(onPressed: model.resetToNow, child: Text(t.loggingControls.now)),
        ],
      ],
    );
  }
}
