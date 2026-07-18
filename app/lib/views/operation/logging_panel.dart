// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:intl/intl.dart';

import '../../main.dart';
import '../operation_dialogs.dart';
import '../../i18n/strings.g.dart';

/// Builds the QSO list's day-header/event-row vocabulary for the active
/// locale. Month/weekday abbreviations come from `intl`'s `DateFormat`
/// (already initialized for the app's locales by
/// `GlobalMaterialLocalizations`), so they localize for free; the relative
/// and event words come from the app's own translations. 2024-01-01 is a
/// Monday, so a 7-day walk from it yields Mon…Sun in order.
QsoListLabels _qsoListLabelsFor(BuildContext context) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final weekday = DateFormat.E(locale);
  final month = DateFormat.MMM(locale);
  final t = context.t.qsoList;
  return QsoListLabels(
    weekdayAbbrs: [for (var i = 0; i < 7; i++) weekday.format(DateTime.utc(2024, 1, 1 + i))],
    monthAbbrs: [for (var m = 1; m <= 12; m++) month.format(DateTime.utc(2024, m))],
    today: t.today,
    yesterday: t.yesterday,
    tomorrow: t.tomorrow,
    eventLabels: {'start': t.eventStarted, 'break': t.eventBreak, 'end': t.eventEnded},
  );
}

class LoggingPanel extends StatefulWidget {
  final Operation operation;
  final HaLoServices services;
  final List<Qso> qsos;
  final List<Map<String, dynamic>> loggingControls;
  final CommandActionHandler onCommandAction;
  final bool showRSTFields;
  final bool showStateField;
  final bool showGridField;
  final bool showQsoNumbers;
  final String? ourEntityPrefix;
  final Map<String, dynamic>? suggestedQso;

  /// Forwards LoggingControls' command output up to the operation view,
  /// which shows it on the Info pane (this panel used to render it in its
  /// own >=900px side area — that layout is the operation view's job now,
  /// see docs/design/layouts.md).
  final ValueChanged<String?>? onCommandMessageChanged;

  const LoggingPanel({
    super.key,
    required this.operation,
    required this.services,
    required this.qsos,
    required this.loggingControls,
    required this.onCommandAction,
    this.showRSTFields = true,
    this.showStateField = false,
    this.showGridField = false,
    this.showQsoNumbers = true,
    this.ourEntityPrefix,
    this.suggestedQso,
    this.onCommandMessageChanged,
  });

  @override
  State<LoggingPanel> createState() => _LoggingPanelState();
}

class _LoggingPanelState extends State<LoggingPanel> {
  Qso? _selectedQso;
  late List<String> _controlOrder =
      widget.services.settings.secondaryControlsOrder;
  late Set<String> _hiddenControls =
      widget.services.settings.hiddenSecondaryControls;
  // Read once, not per build: each getter re-parses the logging prefs JSON,
  // and this panel rebuilds on every QSO-stream emission. Fresh values
  // arrive with a fresh panel — the settings view is only reachable from
  // Home, so this state never survives a bands/modes edit.
  late final List<String> _enabledBands = widget.services.settings.enabledBands;
  late final List<String> _enabledModes = widget.services.settings.enabledModes;

  // The mobile numbers row (issue #27). Unlike the per-operation view
  // toggles, these live in the global General settings screen, so they can
  // change while this panel is alive — mirrored here and refreshed via the
  // listener below.
  late bool _showNumbersRow = widget.services.settings.showNumbersRow;
  late bool _showExtraInNumbersRow =
      widget.services.settings.showExtraInNumbersRow;
  late bool _vibrateNumbersRow = widget.services.settings.vibrateNumbersRow;

  @override
  void initState() {
    super.initState();
    widget.services.settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    widget.services.settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  /// Only rebuild when a numbers-row setting actually changes —
  /// SettingsService also notifies on frequent sync-state writes, and this
  /// panel's QsoList is expensive to rebuild.
  void _onSettingsChanged() {
    final s = widget.services.settings;
    if (s.showNumbersRow != _showNumbersRow ||
        s.showExtraInNumbersRow != _showExtraInNumbersRow ||
        s.vibrateNumbersRow != _vibrateNumbersRow) {
      setState(() {
        _showNumbersRow = s.showNumbersRow;
        _showExtraInNumbersRow = s.showExtraInNumbersRow;
        _vibrateNumbersRow = s.vibrateNumbersRow;
      });
    }
  }

  void _handleSelectQso(Qso qso) {
    setState(() {
      _selectedQso = _selectedQso?.uuid == qso.uuid ? null : qso;
    });
  }

  /// Start/break/end markers aren't real QSOs — tapping one edits its time
  /// instead of loading it into the QSO editor (which `_handleSelectQso`
  /// would otherwise do, showing a nonsensical form with no callsign/mode).
  Future<void> _handleSelectEvent(Qso qso) async {
    final newMillis = await editTimeDialog(
      context,
      title: context.t.qsoList.editEventTime,
      initialMillis:
          qso.startAtMillis ?? DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    if (newMillis == null) return;
    await widget.services.qsos.update(
      Qso(
        uuid: qso.uuid,
        operationUuid: qso.operationUuid,
        data: {...qso.data, 'startAtMillis': newMillis},
        deleted: qso.deleted,
        scoreCache: qso.scoreCache,
      ),
    );
  }

  void _handleControlsSettingsChanged(List<String> order, Set<String> hidden) {
    setState(() {
      _controlOrder = order;
      _hiddenControls = hidden;
    });
    widget.services.settings.setSecondaryControlsOrder(order);
    widget.services.settings.setHiddenSecondaryControls(hidden);
  }

  @override
  Widget build(BuildContext context) {
    // Cached by `ScoringService.rescoreOperation` into `Operation.localData`
    // (never synced — DESIGN.md §4); absent until the first rescore lands.
    final scoring =
        widget.operation.localData['scoring'] as Map<String, dynamic>?;
    final daySections = ((scoring?['daySections'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final list = QsoList(
      qsos: widget.qsos,
      noQsosLabel: context.t.qsoList.empty,
      selectedUuid: _selectedQso?.uuid,
      onSelect: _handleSelectQso,
      onSelectEvent: _handleSelectEvent,
      showRSTFields: widget.showRSTFields,
      showQsoNumbers: widget.showQsoNumbers,
      activityControls: widget.loggingControls,
      ourEntityPrefix: widget.ourEntityPrefix,
      daySections: daySections,
      labels: _qsoListLabelsFor(context),
    );

    return Column(
      children: [
        Expanded(child: list),
        LoggingControls(
          operation: widget.operation,
          qsosRepository: widget.services.qsos,
          qsos: widget.qsos,
          settings: widget.services.settings,
          enabledBands: _enabledBands,
          enabledModes: _enabledModes,
          radioService: widget.services.radio,
          lookup: widget.services.extensions.lookupCall,
          enqueueLookup: widget.services.lookupQueue.enqueue,
          activityControls: widget.loggingControls,
          refreshActivityControls: (qso) => widget.services.extensions
              .loggingControls(widget.operation.data, qso: qso),
          decorateRef: widget.services.extensions.decorateRef,
          interpretCommand: widget.services.extensions.interpretCommand,
          onCommandMessageChanged: (message) => widget.onCommandMessageChanged?.call(message),
          onCommandAction: widget.onCommandAction,
          suggestSpotSources: widget.services.extensions.suggestSpotSources,
          sendSpot: widget.services.extensions.sendSpot,
          spottingControlLabel: context.t.loggingControls.spottingControl,
          spottingLabel: context.t.loggingControls.spottingControl,
          spottingSelfLabel: context.t.loggingControls.spottingSelfControl,
          spotSelfLabel: (freq) => context.t.loggingControls.spotSelfAt(freq: freq),
          spotOtherLabel: (call, freq) => context.t.loggingControls.spotOtherAt(call: call, freq: freq),
          spotTooLateLabel: (call) => context.t.loggingControls.spotTooLate(call: call),
          spotNoFreqLabel: context.t.loggingControls.spotNoFreq,
          spotCommentHint: context.t.loggingControls.spotComment,
          editingQso: _selectedQso,
          suggestedQso: widget.suggestedQso,
          onEditCanceled: () => setState(() => _selectedQso = null),
          onLogged: (_) => setState(() => _selectedQso = null),
          // A comma-separated call list (issue #7) logs several QSOs at
          // once — one rescore for the whole batch, not one per call.
          onCallListLogged: () =>
              widget.services.scoring.rescoreOperation(widget.operation),
          controlOrder: _controlOrder,
          hiddenControlKeys: _hiddenControls,
          onControlsSettingsChanged: _handleControlsSettingsChanged,
          showRSTFields: widget.showRSTFields,
          showStateField: widget.showStateField,
          showGridField: widget.showGridField,
          showNumbersRow: _showNumbersRow,
          showExtraInNumbersRow: _showExtraInNumbersRow,
          vibrateNumbersRow: _vibrateNumbersRow,
          timeControlLabel: context.t.loggingControls.timeControl,
          radioControlLabel: context.t.loggingControls.radioControl,
          controlSettingsTitle: context.t.loggingControls.controlSettings,
          saveLabel: context.t.common.save,
          cancelLabel: context.t.common.cancel,
          timeLabel: context.t.loggingControls.timeUtc,
          dateLabel: context.t.loggingControls.date,
          nowLabel: context.t.loggingControls.now,
          freqLabel: context.t.loggingControls.frequency,
          modeLabel: context.t.loggingControls.mode,
          dupeLabel: context.t.loggingControls.dupe,
          theirCallLabel: context.t.loggingControls.theirCall,
          sentLabel: context.t.loggingControls.sent,
          rcvdLabel: context.t.loggingControls.rcvd,
          moreLabel: context.t.loggingControls.more,
          revertLabel: context.t.loggingControls.revert,
          deleteLabel: context.t.common.delete,
          undoDeleteLabel: context.t.loggingControls.undoDelete,
          restoreLabel: context.t.loggingControls.restore,
          wipeLabel: context.t.loggingControls.wipe,
          undoLabel: context.t.loggingControls.undo,
          pendingDeleteWarning: context.t.loggingControls.pendingDeleteWarning,
          deletedQsoWarning: context.t.loggingControls.deletedQsoWarning,
          qsoEditFormTitle: context.t.qsoEditForm.title,
          theirNameLabel: context.t.qsoEditForm.theirName,
          theirGridLabel: context.t.qsoEditForm.theirGrid,
          theirStateLabel: context.t.qsoEditForm.theirState,
          notesLabel: context.t.qsoEditForm.notes,
          bandLabel: context.t.qsoEditForm.band,
        ),
      ],
    );
  }
}
