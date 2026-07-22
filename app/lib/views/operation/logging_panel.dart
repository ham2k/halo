// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:intl/intl.dart';

import '../../config/dev_bridge.dart';
import '../../main.dart';
import '../operation_dialogs.dart';
import '../../i18n/strings.g.dart';
import '../../services/settings_service.dart';
import '../../tools/distance_format.dart';
import '../../tools/scoring_labels.dart';

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

  /// Forwards the current call-info up to the operation view for the Call Info
  /// detail panel (Info tab / modal). See LoggingControls' `onCallInfoChanged`.
  final CallInfoChanged? onCallInfoChanged;

  /// Fires when the compact call-info area is tapped — the operation view opens
  /// the detail (modal on narrow, focuses the Info tab on wide).
  final VoidCallback? onCallInfoTap;

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
    this.onCallInfoChanged,
    this.onCallInfoTap,
  });

  @override
  State<LoggingPanel> createState() => _LoggingPanelState();
}

class _LoggingPanelState extends State<LoggingPanel> {
  Qso? _selectedQso;

  /// A QSO Escape just deselected (ham2k/app-halo-dist#199 follow-up) — kept
  /// for a few seconds so a second Escape can re-select it, the same way a
  /// wiped-but-not-yet-lost new QSO can be restored (LoggingControls' own
  /// `_wipeUndoSlot`). Never set by Save/Delete/Restore/Revert ending an
  /// edit, only by Escape itself — those are deliberate, final actions, not
  /// something to offer undoing.
  final _lastDeselected = TimedUndoSlot<Qso>();
  // Imperative handle into LoggingControls, used to drive the dev bridge
  // (window.__halo setField/tap) when it's installed (dev/preview web).
  final _loggingController = LoggingControlsController();
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
    // Route the dev bridge's actions to this panel's LoggingControls — only
    // when the bridge is installed (dev/preview web), so nothing runs in
    // production or on native.
    if (DevBridge.instance.installed) {
      DevBridge.instance.setFieldHandler = _loggingController.setField;
      DevBridge.instance.actionHandler = _devAction;
    }
  }

  void _devAction(String id) {
    switch (id) {
      case 'log':
        _loggingController.submit();
      case 'wipe':
        _loggingController.wipe();
    }
  }

  @override
  void dispose() {
    widget.services.settings.removeListener(_onSettingsChanged);
    // Only clear if still ours — a newer logging panel may have taken over.
    if (DevBridge.instance.actionHandler == _devAction) {
      DevBridge.instance.setFieldHandler = null;
      DevBridge.instance.actionHandler = null;
    }
    _lastDeselected.dispose();
    super.dispose();
  }

  /// Escape's own way of ending an editing session — see
  /// `LoggingControls.onEscapeDeselect`'s doc. Stashes the QSO for a few
  /// seconds so `_handleUndoDeselect` can restore it.
  void _handleEscapeDeselect() {
    final qso = _selectedQso;
    if (qso == null) return;
    _lastDeselected.set(qso, onExpire: () {
      if (mounted) setState(() {});
    });
    setState(() => _selectedQso = null);
  }

  /// Re-selects the QSO `_handleEscapeDeselect` most recently deselected, if
  /// any and still within its undo window. Returns whether it did —
  /// `LoggingControls` falls through to its own empty-form wipe when it
  /// didn't (see `onUndoDeselect`'s doc).
  bool _handleUndoDeselect() {
    final qso = _lastDeselected.take();
    if (qso == null) return false;
    setState(() => _selectedQso = qso);
    return true;
  }

  /// Escape reaching here (not `LoggingControls`' own `CallbackShortcuts`)
  /// means focus is elsewhere in this panel — the QSO list, or nowhere at
  /// all — issue #199's follow-up ask that Escape deselect regardless of
  /// what has focus. Deselecting takes priority; with nothing selected,
  /// falls through to undoing the last deselect instead. A locked (staged-
  /// delete or deleted) QSO's fields are always disabled, so its view can
  /// never hold focus and `LoggingControls`' own Escape guard never gets a
  /// chance to run — this mirrors that guard here so Escape doesn't close
  /// the read-only view it's meant to protect.
  void _handlePanelEscape() {
    if (_selectedQso != null) {
      if (_loggingController.isFieldsLocked) return;
      _handleEscapeDeselect();
    } else {
      _handleUndoDeselect();
    }
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
    _lastDeselected.clear();
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

  /// The info area's default statistics (issue #40) — count + duration,
  /// "since last" (only while the last QSO is recent), and last-10 / last-100
  /// Q/h rates. Mirrors app-polo's OpInfo; the live clock ticker inside
  /// LoggingControls keeps the "since last" figure fresh.
  List<String> _operationStatsLines(BuildContext context, List<Qso> qsos) {
    final t = context.t.loggingControls.info;
    final contacts = [for (final q in qsos) if (q.isRealContact) q];
    if (contacts.isEmpty) return [t.noQsos];

    final count = contacts.length;
    final firstMs = contacts.first.startAtMillis;
    final lastMs = contacts.last.startAtMillis;
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;

    final countText = count == 1 ? t.qsoCountOne : t.qsoCountOther(count: count);
    final line1 = <String>[
      (firstMs != null && lastMs != null)
          ? t.qsosInTime(count: countText, time: fmtTimeBetween(firstMs, lastMs))
          : countText,
      // "since last" only while the last QSO is recent (<6h) — otherwise a
      // long-idle log would show a distractingly large figure.
      if (lastMs != null && nowMs - lastMs < 6 * 60 * 60 * 1000) t.sinceLast(time: fmtTimeBetween(lastMs, nowMs)),
    ];

    final line2 = <String>[];
    // Rates: QSOs-per-hour over the last 10 / 100, needing >10 / >100 contacts
    // (same thresholds and window as app-polo).
    int? rateOverLast(int n) {
      final start = contacts[count - n].startAtMillis;
      final end = contacts[count - 1].startAtMillis;
      if (start == null || end == null || end <= start) return null;
      return (n / ((end - start) / 1000 / 60) * 60).round();
    }

    if (count > 10) {
      final rate = rateOverLast(10);
      if (rate != null) line2.add(t.ratePer10(rate: rate));
    }
    if (count > 100) {
      final rate = rateOverLast(100);
      if (rate != null) line2.add(t.ratePer100(rate: rate));
    }

    return [line1.join(' • '), if (line2.isNotEmpty) line2.join(' • ')];
  }

  /// The call-info panel's line-1 location string (issue #40) — distance (and
  /// bearing, if the setting is on) to the contact, then a location label.
  /// Country is shown only for DX contacts, never our own entity. A distance
  /// from a centroid (not a real grid) is shown approximate ("~") and rounded.
  String? _callLocationLine(BuildContext context, Map<String, dynamic> guess) {
    final t = context.t.loggingControls.info;
    final entityPrefix = guess['entityPrefix'] as String?;

    final ourGrid = widget.operation.grid;
    final ourLoc = ourGrid == null ? null : gridToLocation(ourGrid);
    final resolved = locationForQsoInfoWithSource(
      grid: guess['grid'] as String?,
      entityPrefix: entityPrefix,
      state: guess['state'] as String?,
    );

    String? distStr;
    int? bearingDeg;
    // Skip an entity-centroid distance for the largest countries — the country
    // center is a poor estimate; show a distance for them only once we know the
    // state (a state-centroid fix).
    final skipCentroid =
        resolved?.source == QsoLocationSource.entity && kLargeEntities.contains(entityPrefix);
    if (ourLoc != null && resolved != null && !skipCentroid) {
      final miles = widget.services.settings.distanceUnits == DistanceUnits.miles;
      final approximate = resolved.source != QsoLocationSource.grid;
      final km = distanceOnEarthKm(resolved.location, ourLoc);
      distStr = fmtDistance(approximate ? approxRoundedKm(km, miles: miles) : km, miles: miles);
      if (approximate) distStr = '~$distStr'; // centroid-based, not a real fix
      if (widget.services.settings.showBearing) {
        bearingDeg = bearingOnEarthDeg(ourLoc, resolved.location).round();
      }
    }

    final location = (guess['location'] as String?)?.trim();
    final country = (guess['country'] as String?)?.trim();
    // Location + country (country for DX only, never our own entity), joined
    // with an en dash rather than a bullet.
    final label = [
      if (location != null && location.isNotEmpty) location,
      if (country != null && country.isNotEmpty && entityPrefix != widget.ourEntityPrefix) country,
    ].join(' – ');

    if (distStr != null && label.isNotEmpty) {
      // The distance's "to" flows straight into the place — "2,605 km to
      // Santo Domingo, DN – Dominican Republic".
      final phrase = bearingDeg != null
          ? t.distanceBearingTo(distance: distStr, bearing: bearingDeg)
          : t.distanceTo(distance: distStr);
      return '$phrase $label';
    }
    if (label.isNotEmpty) return label;
    // No place to point "to" — say the distance "away" instead ("15 km away").
    if (distStr != null) {
      return bearingDeg != null
          ? t.distanceBearingAway(distance: distStr, bearing: bearingDeg)
          : t.distanceAway(distance: distStr);
    }
    return null;
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

    // Escape deselecting a QSO regardless of what has focus (issue #199
    // follow-up — e.g. the QSO was selected via a list tap, which never
    // focuses anything inside LoggingControls). LoggingControls' own
    // CallbackShortcuts, closer to the compose form's fields, still handles
    // Escape whenever focus IS there (discard-typed-changes, wipe/undo) —
    // this one only fires when that inner one doesn't.
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _handlePanelEscape},
      child: Column(
        children: [
          Expanded(child: list),
          LoggingControls(
            controller: _loggingController,
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
            interpretationUpdates: widget.services.extensions.commandInterpretationUpdates,
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
            onEditCanceled: () {
              _lastDeselected.clear();
              setState(() => _selectedQso = null);
            },
            onEscapeDeselect: _handleEscapeDeselect,
            onUndoDeselect: _handleUndoDeselect,
            onLogged: (_) {
              _lastDeselected.clear();
              setState(() => _selectedQso = null);
            },
            // A comma-separated call list (issue #7) logs several QSOs at
            // once — one rescore for the whole batch, not one per call.
            onCallListLogged: () =>
                widget.services.scoring.rescoreOperation(widget.operation),
            controlOrder: _controlOrder,
            hiddenControlKeys: _hiddenControls,
            onControlsSettingsChanged: _handleControlsSettingsChanged,
            operationStatsLines: (qsos) => _operationStatsLines(context, qsos),
            callLocationLine: (guess) => _callLocationLine(context, guess),
            scoreQso: widget.services.extensions.scoreQso,
            scoreNoticeLabel: (key) => scoreNoticeLabel(context, key),
            onCallInfoChanged: widget.onCallInfoChanged,
            onCallInfoTap: widget.onCallInfoTap,
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
      ),
    );
  }
}
