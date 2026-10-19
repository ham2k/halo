// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Time control: when the contact being composed is stamped. Automatic —
// the moment of logging — until the operator types a time or date, which
// enters manual time entry: that time, moving on by the increment after each
// contact, until "Return to now" hands it back (docs/design/logging-fields.md
// § Manual time entry). An existing (necessarily historical) QSO shows its own
// time instead. [TimeControlModel] holds the two fields and the overrides on
// behalf of `LoggingControls`; [TimeControlFields] draws the expanded row.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';

import 'call_info_summary.dart' show glyphGlow;
import 'halo_dialog.dart';
import 'logging_controls_draft.dart';
import 'logging_controls_types.dart' show ManualTimeHooks;
import 'mdi_icons.g.dart';
import 'modal_pane.dart' show showHaloDialog;
import 'panel_model.dart';
import 'secondary_control_row.dart' show SecondaryControlSpec;
import 'spacing.dart';
import 'theme.dart';

/// What the model reads from the panel's live configuration.
typedef TimeControlConfig = ({Qso? editingQso, ManualTimeHooks manualTime});

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

  /// Overrides this one contact's timestamp: the edited time of an existing
  /// QSO, or a time a suggestion arrived with. Null falls back to
  /// [pausedAtMillis], then to the moment of logging.
  int? manualStartAtMillis;

  /// Manual time entry's clock: the time new contacts are stamped with, or
  /// null for live time. Unlike [manualStartAtMillis] it is not part of the
  /// draft — a wipe after logging, a spot, an edit of another QSO all leave
  /// it — and it is stored for the operation through
  /// [ManualTimeHooks.onChanged], resuming from [ManualTimeHooks.startAtMillis].
  /// Set it through [setPaused].
  late int? pausedAtMillis = config().manualTime.startAtMillis;

  /// [pausedAtMillis] as the operator's last wipe found it — see [leaveForWipe].
  int? _pausedBeforeWipe;

  /// The time/date text as of the last notification, so a selection-only one
  /// can be told apart from a real edit. Kept current even while the panel is
  /// populating — a seeded value that never got recorded here would look like
  /// an edit the next time the cursor moved.
  String _lastText = '';

  bool _bound = false;

  static String fmtTime(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  static String fmtTimeWithSeconds(DateTime dt) => '${fmtTime(dt)}:${dt.second.toString().padLeft(2, '0')}';
  static String fmtDate(DateTime dt) => '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// The best-known timestamp for the entry being composed/edited: this
  /// contact's own override if one's been set, else the existing QSO's
  /// recorded time when editing one, or manual time entry's clock when
  /// composing, else null — meaning "still automatic, tracks live now."
  int? get effectiveStartAtMillis {
    final editingQso = config().editingQso;
    return manualStartAtMillis ?? (editingQso == null ? pausedAtMillis : editingQso.startAtMillis);
  }

  /// Whether the chip shows manual time entry: composing, with the mode on.
  bool get isManual => config().editingQso == null && pausedAtMillis != null;

  /// Whether the chip should tick: nothing overrides the timestamp, so it
  /// shows the live clock.
  bool get isLive => effectiveStartAtMillis == null;

  /// Whether "Return to now" is offered: only while composing a new QSO with
  /// a manual time in effect — there's no "automatic" time to reset to when
  /// editing an existing, necessarily historical, entry.
  bool get canResetToNow => config().editingQso == null && (manualStartAtMillis != null || pausedAtMillis != null);

  /// The chip's text. Always shows seconds, even when they're not meaningful
  /// (a time typed in the HH:MM field has none, so it's :00 rather than the
  /// pill silently switching formats). Only a call-field command (`+30s`,
  /// `12:33:30`, `::30`) sets them by hand.
  String get summary => '${fmtTimeWithSeconds(shownAt)}z';

  /// What the fields show: the contact's time, or now.
  DateTime get shownAt {
    final millis = effectiveStartAtMillis;
    return millis == null ? nowUtc() : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  /// [shownAt] as the date and time fields write it.
  (String, String) get shownFields => (fmtDate(shownAt), fmtTime(shownAt));

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
    final (date, time) = shownFields;
    // Under the bracket: without it these programmatic sets would read back
    // as a manual override — freezing auto-timestamping just for opening the
    // Time chip, and making "Return to now" re-freeze the clock it just released. The
    // bracket is the panel-wide one, so every listener that stands down for a
    // programmatic write stands down here too; these two controllers have no
    // listener but this model's own.
    draft.populate(() {
      timeController.text = time;
      dateController.text = date;
      recordText();
    });
  }

  /// Enters, moves or (null) leaves manual time entry, and stores it.
  void setPaused(int? millis) {
    if (millis == pausedAtMillis) return;
    pausedAtMillis = millis;
    config().manualTime.onChanged?.call(millis);
  }

  /// The operator set the contact's time. For a new contact that enters (or
  /// moves) manual time entry rather than stamping this one contact; for an
  /// existing one it is that QSO's own.
  void takeTime(int millis) {
    if (config().editingQso == null) {
      manualStartAtMillis = null;
      setPaused(millis);
    } else {
      manualStartAtMillis = millis;
    }
  }

  /// The operator's own wipe leaves manual time entry — the one after a log
  /// does not — and its undo ([undoWipe]) goes back into it.
  void leaveForWipe() {
    // A wipe of an already-wiped draft must not overwrite the earlier wipe's
    // way back, whose undo is still live.
    if (pausedAtMillis != null) _pausedBeforeWipe = pausedAtMillis;
    setPaused(null);
  }

  void undoWipe() {
    if (_pausedBeforeWipe case final pausedAt?) setPaused(pausedAt);
    _pausedBeforeWipe = null;
  }

  /// The wipe's undo is gone, and with it the way back.
  void forgetWipe() => _pausedBeforeWipe = null;

  /// Moves manual time entry on past a contact just logged at [loggedAtMillis]
  /// — a no-op outside it. One step per Enter, however many calls it logged.
  void advancePast(int loggedAtMillis) {
    if (pausedAtMillis == null) return;
    setPaused(loggedAtMillis + config().manualTime.increment.inMilliseconds);
  }

  /// A time command from the call field ([CommandAction]'s `setTime`) for a
  /// new contact — the panel interprets no command while editing a QSO:
  /// applied to the contact's current time, or to now, and then taken as if
  /// typed. NOW is the Now button.
  ///
  /// Throws [ArgumentError] for an action that names nothing to change or a
  /// value out of range: `DateTime.utc` would otherwise roll an hour 25 into
  /// tomorrow, and an empty action would still stop the clock.
  void applyCommand(Map<String, dynamic> params) {
    if (params['now'] == true) return resetToNow();
    bool within(String key, int min, int max) => switch (params[key]) {
      null => true,
      final int value => value >= min && value <= max,
      _ => false,
    };
    final valid =
        ['deltaMillis', 'hour', 'minute', 'second', 'month'].any((key) => params[key] != null) &&
        switch (params['deltaMillis']) {
          null => true,
          final num delta => delta.abs() <= _maxDeltaMillis,
          _ => false,
        } &&
        within('hour', 0, 23) &&
        within('minute', 0, 59) &&
        within('second', 0, 59) &&
        within('month', 1, 12) &&
        within('day', 1, 31) &&
        (params['day'] == null || params['month'] != null);
    if (!valid) throw ArgumentError.value(params, 'setTime');
    final delta = params['deltaMillis'] as num?;
    final [hour, minute, second, month, day] = [
      for (final key in ['hour', 'minute', 'second', 'month', 'day']) params[key] as int?,
    ];

    var dt = DateTime.fromMillisecondsSinceEpoch(effectiveStartAtMillis ?? nowMillis(), isUtc: true);
    if (delta != null) dt = dt.add(Duration(milliseconds: delta.toInt()));
    if (hour != null || minute != null || second != null) {
      // "12:33" means 12:33:00, but "::30" keeps the minute it was in.
      final seconds = second ?? (hour == null && minute == null ? dt.second : 0);
      dt = DateTime.utc(dt.year, dt.month, dt.day, hour ?? dt.hour, minute ?? dt.minute, seconds);
    }
    if (month != null) {
      // Clamped: a Feb 29 typed into a common year would otherwise roll
      // over into March.
      final clamped = math.min(day ?? dt.day, DateTime.utc(dt.year, month + 1, 0).day);
      dt = DateTime.utc(dt.year, month, clamped, dt.hour, dt.minute, dt.second);
    }
    takeTime(dt.millisecondsSinceEpoch);
    seedFields();
    notify();
  }

  /// Back to automatic timestamping.
  void resetToNow() {
    manualStartAtMillis = null;
    setPaused(null);
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
    takeTime(DateTime.utc(year, month, day, hour, minute).millisecondsSinceEpoch);
    notify();
  }
}

/// The Time control's expanded row: the time and date fields, a "Return to
/// now" button back to automatic timestamping when the model offers one, and
/// in manual time entry the button to its settings.
class TimeControlFields extends StatelessWidget {
  const TimeControlFields({super.key, required this.model});

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
          FilledButton.icon(
            key: const ValueKey('returnToNowButton'),
            onPressed: model.resetToNow,
            icon: const Icon(MdiIcons.restore),
            label: Text(t.loggingControls.now),
          ),
        ],
        if (model.isManual && model.config().manualTime.onIncrementChanged != null) ...[
          const SizedBox(width: Space.sm),
          Semantics(
            identifier: 'action.manualTimeSettings',
            // Icon-only, and the app shows no hover tooltips: this label is
            // the only accessible name it has.
            label: t.loggingControls.manualTimeSettings,
            button: true,
            child: InkWell(
              key: const ValueKey('manualTimeSettingsButton'),
              // Not one of the control's fields: a click's focus grab would
              // leave Tab with nowhere in the control to go from.
              canRequestFocus: false,
              onTap: () => showManualTimeSettings(context, model.config().manualTime),
              child: Padding(
                padding: const EdgeInsets.all(Space.xs),
                child: Icon(MdiIcons.tune, size: 20, color: labelColor, shadows: glyphGlow(Theme.of(context))),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Manual time entry's settings: how far the time moves after each contact.
/// A pick takes effect at once.
Future<void> showManualTimeSettings(BuildContext context, ManualTimeHooks hooks) => showHaloDialog<void>(
  context: context,
  builder: (context) => _ManualTimeSettingsDialog(hooks: hooks),
);

class _ManualTimeSettingsDialog extends StatefulWidget {
  const _ManualTimeSettingsDialog({required this.hooks});

  final ManualTimeHooks hooks;

  @override
  State<_ManualTimeSettingsDialog> createState() => _ManualTimeSettingsDialogState();
}

class _ManualTimeSettingsDialogState extends State<_ManualTimeSettingsDialog> {
  // Held here as well as stored: the hooks the dialog was opened with do not
  // change under it when the pick is stored.
  late var _increment = widget.hooks.increment;

  String _label(Duration increment) =>
      increment == Duration.zero ? t.loggingControls.manualTimeIncrementNone : t.loggingControls.manualTimeIncrementMinutes(count: increment.inMinutes);

  @override
  Widget build(BuildContext context) {
    return HaloDialog(
      title: Text(t.loggingControls.manualTimeSettings),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.xs),
            child: Text(t.loggingControls.manualTimeIncrement, style: Theme.of(context).textTheme.titleSmall),
          ),
          RadioGroup<Duration>(
            groupValue: _increment,
            onChanged: (picked) {
              if (picked == null) return;
              setState(() => _increment = picked);
              widget.hooks.onIncrementChanged?.call(picked);
            },
            child: Column(
              children: [
                for (final increment in ManualTimeHooks.increments)
                  RadioListTile<Duration>(dense: true, visualDensity: VisualDensity.compact, value: increment, title: Text(_label(increment))),
              ],
            ),
          ),
        ],
      ),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.common.done)),
    );
  }
}

/// The Time chip's glyph — the settings dialog's entry reads this too.
const timeChipIcon = MdiIcons.clockOutline;

/// The Time chip's fill in manual time entry: the same dark red in both
/// themes, so a stopped clock reads the same whatever the brightness.
const manualTimeChipColor = Color(0xFF8E1B1B);

/// A century, the most a `setTime` delta may move: past int64 microseconds a
/// [Duration] wraps rather than throws. The time-commands parser holds the
/// same bound, so its operator sees the reason.
const _maxDeltaMillis = 100 * 365 * Duration.millisecondsPerDay;

/// The Time chip and its expanded fields, read from [model].
SecondaryControlSpec timeControlSpec(TimeControlModel model) => SecondaryControlSpec(
  key: 'time',
  icon: model.isManual ? MdiIcons.pause : timeChipIcon,
  fill: model.isManual ? manualTimeChipColor : null,
  summary: model.summary,
  // Live clock only while nothing overrides the timestamp (a manually
  // set time, or editing an existing — necessarily historical — QSO);
  // the chip re-reads this once per second without rebuilding the
  // panel (a panel-level ticker calling setState on the whole logging
  // panel would cost a full panel rebuild per tick).
  liveSummary: model.isLive ? () => model.summary : null,
  expandedBuilder: (context) => TimeControlFields(model: model),
);
