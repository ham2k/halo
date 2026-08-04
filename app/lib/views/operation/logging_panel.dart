// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HardwareKeyboard, KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:intl/intl.dart';

import '../../config/dev_bridge.dart';
import '../../main.dart';
import '../operation_dialogs.dart';
import '../../i18n/strings.g.dart';
import '../../services/link_opener.dart';
import '../../services/settings_service.dart';
import '../../tools/distance_format.dart';
import '../../tools/form_chrome_labels.dart';
import '../../tools/operation_stats.dart';
import '../../tools/scoring_labels.dart';
import '../../tools/scoring_summaries.dart';

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
  final info = context.t.loggingControls.info;
  return QsoListLabels(
    weekdayAbbrs: [for (var i = 0; i < 7; i++) weekday.format(DateTime.utc(2024, 1, 1 + i))],
    monthAbbrs: [for (var m = 1; m <= 12; m++) month.format(DateTime.utc(2024, m))],
    today: t.today,
    yesterday: t.yesterday,
    tomorrow: t.tomorrow,
    eventLabels: {'start': t.eventStarted, 'break': t.eventBreak, 'end': t.eventEnded},
    // Same "1 QSO"/"N QSOs" vocabulary the info area's stats line uses.
    qsoCount: (count) => count == 1 ? info.qsoCountOne : info.qsoCountOther(count: count),
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

  /// The report an empty Sent/Rcvd stands for, per mode band (Logging
  /// settings). Empty means "the standard one" — `defaultRSTFor` resolves
  /// them, so nothing here has to know what the standard reports are.
  final String defaultReport;
  final String defaultReportCW;
  final String defaultReportFT8;

  final String? ourEntityPrefix;

  /// The operator's own ITU region (1/2/3) and lowercase ISO country code
  /// — resolved by `operation_view.dart` alongside
  /// [ourEntityPrefix], and passed straight through to LoggingControls so a
  /// typed/commanded frequency gets a band-plan mode guess scoped to where
  /// the operator actually is.
  final int? ourItuRegion;
  final String? ourCountryCode;

  final Map<String, dynamic>? suggestedQso;

  /// Forwards LoggingControls' command output up to the operation view,
  /// which shows it on the Info pane (the wide layout is the operation
  /// view's job — see docs/design/layouts.md).
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
    this.defaultReport = '',
    this.defaultReportCW = '',
    this.defaultReportFT8 = '',
    this.ourEntityPrefix,
    this.ourItuRegion,
    this.ourCountryCode,
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

  /// The QSO list as a rung of the keyboard's focus ladder: Arrow Up
  /// off the logging controls' pill strip lands here, Up/Down then walk the
  /// list selecting each row for editing, and Enter/Escape hand the keyboard
  /// back down. The list's own rows stay plain tap targets — this is one node
  /// for "the keyboard is in the list", not one per row.
  final _listFocus = FocusNode(debugLabel: 'qsoList');
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

  // The mobile numbers row. Unlike the per-operation view
  // toggles, these live in the global General settings screen, so they can
  // change while this panel is alive — mirrored here and refreshed via the
  // listener below.
  late bool _showNumbersRow = widget.services.settings.showNumbersRow;
  late bool _showExtraInNumbersRow =
      widget.services.settings.showExtraInNumbersRow;
  late bool _vibrateNumbersRow = widget.services.settings.vibrateNumbersRow;
  late bool _leftieMode = widget.services.settings.leftieMode;

  // Whether the QSO list's empty state should warn to check the radio
  // — mirrors LoggingControls' own `_vfoIsUnset`: no band *and* no
  // frequency, or no mode. Cached and diffed in `_onRadioChanged` for the
  // same reason as the numbers-row settings above — this panel's QsoList is
  // expensive to rebuild, and most VFO changes (e.g. tuning within the same
  // band) don't flip this boolean.
  late bool _needsBandOrMode = _computeNeedsBandOrMode();

  bool _computeNeedsBandOrMode() {
    final vfo = widget.services.radio.vfoA;
    return (vfo.freq == null && vfo.band == null) || vfo.mode == null;
  }

  @override
  void initState() {
    super.initState();
    widget.services.settings.addListener(_onSettingsChanged);
    // The QSO list's empty state warns when the VFO needs attention
    // — rebuild so it clears the moment the operator answers via
    // the Radio control, without waiting for an unrelated rebuild.
    widget.services.radio.addListener(_onRadioChanged);
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
    widget.services.radio.removeListener(_onRadioChanged);
    // Only clear if still ours — a newer logging panel may have taken over.
    if (DevBridge.instance.actionHandler == _devAction) {
      DevBridge.instance.setFieldHandler = null;
      DevBridge.instance.actionHandler = null;
    }
    _listFocus.dispose();
    super.dispose();
  }

  // ── Keyboard navigation of the QSO list ──────────────────────────────────

  /// The rows arrow navigation can land on, and where the current selection
  /// sits among them.
  ///
  /// Navigable is every QSO the list shows except the event and annotation
  /// markers (operation start/break/end, NOTE/TODO/SOLAR/WEATHER). Those
  /// aren't editable contacts — tapping one opens a time dialog rather than
  /// loading the editor — so walking onto one would put the logging controls
  /// in a state no keystroke could get out of.
  ///
  /// `slot` is the selection's position in `indices`, or -1 when nothing is
  /// selected or the selection has since left the list (deleted, or filtered
  /// out by the view menu). Found in the same pass that builds the list, since
  /// this runs on every arrow keypress — including auto-repeat — over a log
  /// that can hold tens of thousands of contacts.
  ({List<int> indices, int slot}) get _navigable {
    final selectedUuid = _selectedQso?.uuid;
    final indices = <int>[];
    var slot = -1;
    for (var i = 0; i < widget.qsos.length; i++) {
      final qso = widget.qsos[i];
      if (qso.isEvent) continue;
      if (selectedUuid != null && qso.uuid == selectedUuid) slot = indices.length;
      indices.add(i);
    }
    return (indices: indices, slot: slot);
  }

  /// Selects a row for editing without touching field focus — the keyboard
  /// stays in the list so the next arrow keeps walking. Unlike a tap
  /// ([_handleSelectQso]) this never toggles: arrowing onto a row means "this
  /// one", never "none".
  void _selectQsoAt(int index) {
    setState(() => _selectedQso = widget.qsos[index]);
  }

  /// Arrow Up walked off the top of the logging controls. Takes the keyboard
  /// into the list, on the row already being edited or — much more often —
  /// the newest one. Returns whether it did — nothing navigable (an empty
  /// operation, or one holding only event markers) leaves focus where it
  /// was and returns false, so a caller that already gave up its own focus
  /// (a closing secondary control) knows to fall back instead.
  bool _handleNavigateToQsoList() {
    final (:indices, :slot) = _navigable;
    if (indices.isEmpty) return false;
    if (slot < 0) _selectQsoAt(indices.last);
    _listFocus.requestFocus();
    return true;
  }

  /// Moves the selection [delta] rows through [_navigable].
  ///
  /// Walking a single row past the newest QSO leaves the list entirely and
  /// hands the keyboard back to the pill strip, mirroring the Up that got
  /// here. It also deselects, back to the new QSO being composed — the state
  /// this walk started from, up through the pills, before Up ever touched the
  /// list. A [jump] — a page or an end key — clamps at that edge instead:
  /// nobody presses Page Down meaning "and then leave the list".
  void _moveListSelection(int delta, {bool jump = false}) {
    final (:indices, :slot) = _navigable;
    if (indices.isEmpty) return;
    // Nothing selected, or a selection that has since left the list: start
    // over at the newest row rather than guessing where the walk had got to.
    if (slot < 0) {
      _selectQsoAt(indices.last);
      return;
    }
    final next = slot + delta;
    if (next >= indices.length && !jump) {
      setState(() => _selectedQso = null);
      // Deferred a frame: LoggingControls' own didUpdateWidget reacts to the
      // deselection above by resetting which pill is open, so opening one
      // before that reset lands would just have it closed again.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // A second Down — including OS key-repeat — can land before this
        // frame and re-select the newest row via the `slot < 0` branch
        // above. When that happens the keyboard belongs back in the list,
        // not on the pills this now-stale callback was queued for.
        if (mounted && _selectedQso == null) _loggingController.focusSecondaryControls();
      });
      return;
    }
    final target = next.clamp(0, indices.length - 1);
    if (target == slot) return; // already sitting at that end
    _selectQsoAt(indices[target]);
  }

  /// Straight to the oldest or newest contact — Home/End, and Cmd+Up/Down on
  /// macOS. One pass over the log, like every other move.
  void _selectListEdge({required bool newest}) {
    final (:indices, :slot) = _navigable;
    if (indices.isEmpty) return;
    final target = newest ? indices.length - 1 : 0;
    if (target == slot) return;
    _selectQsoAt(indices[target]);
  }

  /// How many rows a page key moves: as many as the list can show, less one so
  /// a row of context carries over — the convention every list follows.
  ///
  /// Measured off the list's own box (the Focus wrapping it fills the same
  /// space), divided by a row's height. Before the first layout there is
  /// nothing to measure, so a modest jump stands in.
  int get _pageRows {
    final box = _listFocus.context?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return 10;
    final rows = (box.size.height / QsoList.rowHeight).floor() - 1;
    return rows < 1 ? 1 : rows;
  }

  KeyEventResult _onQsoListKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    // Shift+arrow is a range-selection gesture (this list has no such thing to
    // extend) and Ctrl belongs to the platform — neither means anything here.
    // Cmd and Option DO, but only on the arrows: see below.
    if (keyboard.isShiftPressed || keyboard.isControlPressed) return KeyEventResult.ignored;
    final meta = keyboard.isMetaPressed;
    final alt = keyboard.isAltPressed;
    final key = event.logicalKey;

    // The arrows, with the two modifiers the platform gives them: Cmd+Up/Down
    // is "to the start/end of the document" and Option+Up/Down is the bigger
    // step between them — a screenful here, the same as Page Up/Down. Both
    // together mean nothing, so they're left alone rather than guessed at.
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
      final down = key == LogicalKeyboardKey.arrowDown;
      if (meta && alt) return KeyEventResult.ignored;
      if (meta) {
        _selectListEdge(newest: down);
      } else if (alt) {
        _moveListSelection(down ? _pageRows : -_pageRows, jump: true);
      } else {
        _moveListSelection(down ? 1 : -1);
      }
      return KeyEventResult.handled;
    }
    // Nothing below takes a modifier.
    if (meta || alt) return KeyEventResult.ignored;

    switch (key) {
      case LogicalKeyboardKey.pageUp:
        _moveListSelection(-_pageRows, jump: true);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.pageDown:
        _moveListSelection(_pageRows, jump: true);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.home:
        _selectListEdge(newest: false);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.end:
        _selectListEdge(newest: true);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        // The row stays selected — this is "now let me edit it", not "open
        // it": the editor has been loaded with it since the arrow key landed.
        // The field the operator was last in before arrowing up into the
        // list (Call, if none is remembered) — not always Call, since Enter
        // here is "resume editing where I left off", not "start a fresh QSO"
        // (that's what Escape from the list is for).
        _loggingController.focusLastPrimaryField();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        // The same deselect Escape makes anywhere else in the panel, plus the
        // part only the list needs: the keyboard goes back to composing.
        // Locked QSOs are `_handlePanelEscape`'s own business — it declines,
        // and the disabled call field declines the focus too, so the keyboard
        // simply stays here.
        _handlePanelEscape();
        _loggingController.focusCall();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Escape reaching here (not `LoggingControls`' own `CallbackShortcuts`)
  /// means focus is elsewhere in this panel — the QSO list, or nowhere at
  /// all; Escape must deselect regardless of what has focus.
  ///
  /// It only ever deselects, never toggles: a second press must not
  /// re-select the QSO the first had just dropped (mirroring the compose
  /// form's wipe-undo would fight the focus ladder, where Escape is
  /// uniformly the way *out* of wherever the keyboard is — walking back
  /// *in* is the one thing it must never do).
  ///
  /// A locked (staged-delete or deleted) QSO's fields are always disabled, so
  /// its view can never hold focus and `LoggingControls`' own Escape guard
  /// never gets a chance to run — this mirrors that guard here so Escape
  /// doesn't close the read-only view it's meant to protect.
  void _handlePanelEscape() {
    if (_selectedQso == null || _loggingController.isFieldsLocked) return;
    setState(() => _selectedQso = null);
  }

  /// Only rebuild when a numbers-row setting actually changes —
  /// SettingsService also notifies on frequent sync-state writes, and this
  /// panel's QsoList is expensive to rebuild.
  void _onSettingsChanged() {
    final s = widget.services.settings;
    if (s.showNumbersRow != _showNumbersRow ||
        s.showExtraInNumbersRow != _showExtraInNumbersRow ||
        s.vibrateNumbersRow != _vibrateNumbersRow ||
        s.leftieMode != _leftieMode) {
      setState(() {
        _showNumbersRow = s.showNumbersRow;
        _showExtraInNumbersRow = s.showExtraInNumbersRow;
        _vibrateNumbersRow = s.vibrateNumbersRow;
        _leftieMode = s.leftieMode;
      });
    }
  }

  /// Rebuilds the QSO list's empty-state warning the moment the operator
  /// answers it via the Radio control, rather than waiting for an unrelated
  /// rebuild to catch up.
  void _onRadioChanged() {
    final needs = _computeNeedsBandOrMode();
    if (needs != _needsBandOrMode) {
      setState(() => _needsBandOrMode = needs);
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

  /// The call-info panel's line-1 location string — distance (and
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
    // Keyed by scorer, so this folds every
    // active scorer's sections into one day-keyed list (see
    // app/lib/tools/scoring_summaries.dart).
    final daySections = mergedDaySections(scoring);
    final list = QsoList(
      qsos: widget.qsos,
      noQsosLabel: context.t.qsoList.empty,
      needsBandOrMode: _needsBandOrMode,
      bandOrModeWarningLabel: context.t.qsoList.bandOrModeWarning,
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

    // Escape deselecting a QSO regardless of what has focus (e.g. the QSO
    // was selected via a list tap, which never focuses anything inside
    // LoggingControls). LoggingControls' own
    // CallbackShortcuts, closer to the compose form's fields, still handles
    // Escape whenever focus IS there (discard-typed-changes, wipe/undo) —
    // this one only fires when that inner one doesn't.
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _handlePanelEscape},
      child: Column(
        children: [
          Expanded(
            // skipTraversal: Tab belongs to the logging controls' own field
            // rotation; the list is reached with the arrow keys, not
            // by tabbing into it.
            child: Focus(
              focusNode: _listFocus,
              skipTraversal: true,
              onKeyEvent: _onQsoListKeyEvent,
              child: list,
            ),
          ),
          LoggingControls(
            controller: _loggingController,
            // Call notes carry socials and URLs, styled as links; this makes
            // them open.
            onOpenLink: openExternalUrl,
            operation: widget.operation,
            qsosRepository: widget.services.qsos,
            qsos: widget.qsos,
            settings: widget.services.settings,
            leftieMode: _leftieMode,
            enabledBands: _enabledBands,
            enabledModes: _enabledModes,
            radioService: widget.services.radio,
            // Same object, as a Listenable — so the Radio control follows a
            // connected rig (CAT) instead of only reading the VFO when it
            // seeds. See LoggingControls.radioUpdates.
            radioUpdates: widget.services.radio,
            ourItuRegion: widget.ourItuRegion,
            ourCountryCode: widget.ourCountryCode,
            lookup: widget.services.extensions.lookupCall,
            enqueueLookup: widget.services.lookupQueue.enqueue,
            // force: false — unlike the explicit "Lookup all QSOs" action,
            // a SEED batch shouldn't force-refresh a QSO that (somehow)
            // already carries real online lookup data.
            enqueueAllLookups: (qsos) => widget.services.lookupQueue.enqueueAll(qsos, force: false),
            activityControls: widget.loggingControls,
            refreshActivityControls: (qso) => widget.services.extensions
                .loggingControls(widget.operation.data, qso: qso),
            decorateQsoBeforeSave: (qso) =>
                widget.services.extensions.decorateQsoBeforeSave(qso, widget.operation.data),
            decorateRef: widget.services.extensions.decorateRef,
            interpretCommand: widget.services.extensions.interpretCommand,
            interpretationUpdates: widget.services.extensions.commandInterpretationUpdates,
            onCommandMessageChanged: (message) => widget.onCommandMessageChanged?.call(message),
            onCommandAction: widget.onCommandAction,
            // Lets the ⌘K dialog apply a command to this panel — see
            // HaLoServices.currentCommandDispatch. Attached to this
            // operation's own stack entry, so a disposing panel can't detach a
            // still-live one's dispatcher.
            onDispatcherChanged: (dispatch) =>
                widget.services.setCommandDispatchFor(widget.operation.uuid, dispatch),
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
            bandOrFreqRequiredLabel: context.t.loggingControls.bandOrFreqRequired,
            editingQso: _selectedQso,
            suggestedQso: widget.suggestedQso,
            onEditCanceled: () => setState(() => _selectedQso = null),
            onNavigateToQsoList: _handleNavigateToQsoList,
            onLogged: (qso) {
              // Event rows (NOTE/TODO/SOLAR/WEATHER annotations, operation
              // start/break/end) also arrive here via the command `addQso`
              // action — they're not contacts and must not count as QSOs.
              // _selectedQso is still set here for a save-of-edit; it only
              // clears below — that's what tells the two events apart.
              if (!qso.isEvent) {
                widget.services.track(
                  _selectedQso != null ? 'qso_edited' : 'qso_added',
                  _qsoTrackProps(qso),
                );
              }
              setState(() => _selectedQso = null);
            },
            onQsoDeleted: (qso) {
              if (!qso.isEvent) widget.services.track('qso_deleted', _qsoTrackProps(qso));
            },
            onQsoUndeleted: (qso) {
              if (!qso.isEvent) widget.services.track('qso_undeleted', _qsoTrackProps(qso));
            },
            // A comma-separated call list logs several QSOs at
            // once — one rescore for the whole batch, not one per call.
            onCallListLogged: () =>
                widget.services.scoring.rescoreOperation(widget.operation),
            controlOrder: _controlOrder,
            hiddenControlKeys: _hiddenControls,
            onControlsSettingsChanged: _handleControlsSettingsChanged,
            operationStatsLines: (qsos) => operationStatsLines(context, qsos),
            callLocationLine: (guess) => _callLocationLine(context, guess),
            scoreQso: widget.services.extensions.scoreQso,
            scoreNoticeLabel: (key) => scoreNoticeLabel(context, key),
            onCallInfoChanged: widget.onCallInfoChanged,
            onCallInfoTap: widget.onCallInfoTap,
            showRSTFields: widget.showRSTFields,
            showStateField: widget.showStateField,
            showGridField: widget.showGridField,
            defaultReport: widget.defaultReport,
            defaultReportCW: widget.defaultReportCW,
            defaultReportFT8: widget.defaultReportFT8,
            keyboardAccessory: widget.services.keyboardAccessory,
            showNumbersRow: _showNumbersRow,
            showExtraInNumbersRow: _showExtraInNumbersRow,
            vibrateNumbersRow: _vibrateNumbersRow,
            timeControlLabel: context.t.loggingControls.timeControl,
            radioControlLabel: context.t.loggingControls.radioControl,
            controlSettingsTitle: context.t.loggingControls.controlSettings,
            expandControlsLabel: context.t.loggingControls.expandControls,
            collapseControlsLabel: context.t.loggingControls.collapseControls,
            formLabels: formRendererLabelsFor(context.t),
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

  /// The qso_* events' shared properties — same two app-polo sends: the
  /// contact's DXCC prefix and the ref types on the QSO. Never the callsign
  /// or any other identifying detail.
  Map<String, Object?> _qsoTrackProps(Qso qso) => {
        'their_prefix': qso.theirEntityPrefix,
        'refs': qso.refs.map((r) => r['type']).join(','),
      };
}
