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
import '../../i18n/strings.g.dart';
import '../../services/cat/equipment.dart';
import '../../services/link_opener.dart';
import '../../services/settings_service.dart';
import '../../tools/distance_format.dart';
import '../../tools/form_chrome_labels.dart';
import '../../tools/operation_stats.dart';
import '../../tools/scoring_labels.dart';
import '../../tools/scoring_summaries.dart';
import '../settings_view.dart';
import '../station_panel.dart';

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

  /// Rcvd before Sent, and focus advancing on a complete report — both reach
  /// the QSO list as well as the entry row, so the two never disagree.
  final bool switchSentRcvd;
  final bool jumpAfterRST;

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

  /// Forwards the QSO being composed up to the operation view, for extension
  /// panels declaring the `qso` trigger. Null unless one of them is actually
  /// in the layout — see LoggingControls' `onQsoChanged`, which is only cheap
  /// while this is null.
  final QsoDraftChanged? onQsoChanged;

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
    this.switchSentRcvd = false,
    this.jumpAfterRST = false,
    this.ourEntityPrefix,
    this.ourItuRegion,
    this.ourCountryCode,
    this.suggestedQso,
    this.onCommandMessageChanged,
    this.onCallInfoChanged,
    this.onQsoChanged,
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

  // Whether the 'gato' experiment is on — the single read every gate below
  // shares, and the cat listener's own attach/detach guard. Tracked
  // explicitly (not re-read from experimentEnabled at dispose time, which
  // can have changed since initState if the operator flips the experiment,
  // e.g. from the Experiments panel, without leaving this screen — that
  // would either leak the listener into a disposed State, where a later
  // CatService.notifyListeners() throws, or skip attaching it after a live
  // enable, freezing the fields below). Kept in sync by _onSettingsChanged.
  late bool _gatoEnabled = widget.services.settings.experimentEnabled('gato') /* stored key, see experiments.yaml */;

  // Whether the Radio control's icon should read as CAT-configured — mirrors
  // zeroBeatSuggestionFor's gate (operation_view.dart): the experiment check
  // comes first so `services.cat`, a `late final` that builds a whole
  // CatService the first time it's touched, is never built just to answer
  // "no" for an operator without Station Configuration on.
  late bool _hasConfiguredRadio = _computeHasConfiguredRadio();

  bool _computeHasConfiguredRadio() => _gatoEnabled && widget.services.cat.radio1 != null;

  // Whether radio1 is actually connected right now, as opposed to merely
  // configured — the Station Configuration button's red/green.
  late bool _radioConnected = _computeRadioConnected();

  bool _computeRadioConnected() {
    if (!_gatoEnabled) return false;
    final uuid = widget.services.cat.radio1;
    return uuid != null && widget.services.cat.stateFor(uuid).status == EquipmentStatus.connected;
  }

  // radio1's display name — the Radio control's own reflection of the same
  // name station_panel.dart's equipment list shows for it.
  late String? _radioName = _computeRadioName();

  String? _computeRadioName() {
    if (!_gatoEnabled) return null;
    final cat = widget.services.cat;
    final node = cat.radio1 == null ? null : cat.nodeFor(cat.radio1!);
    return node == null ? null : cat.displayNameFor(node);
  }

  /// Merges the operator's tracked station-info fields (Station
  /// Configuration's "Track Station Info for each QSO") into a QSO at save
  /// time. Runs before `decorateQsoBeforeSave`'s extension hooks, so an
  /// activity can still see and adjust the captured values. Rig/antenna/key
  /// nest under `our`; power is top-level (`Qso.power`), matching QSON
  /// convention (freq/band/mode) rather than app-only placement.
  Map<String, dynamic> _withStationInfo(Map<String, dynamic> qso) {
    if (!_gatoEnabled) return qso;
    final settings = widget.services.settings;
    if (!settings.trackStationInfo) return qso;
    final cat = widget.services.cat;
    final tracked = settings.stationInfoTrackedFields;

    String? nameFor(String? uuid) {
      final node = uuid == null ? null : cat.nodeFor(uuid);
      return node == null ? null : cat.displayNameFor(node);
    }

    final our = {...(qso['our'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{}};
    num? power;
    if (tracked.contains('rig')) {
      final name = nameFor(cat.radio1);
      if (name != null) our['rig'] = name;
    }
    if (tracked.contains('power')) {
      power = cat.displayedPower;
    }
    if (tracked.contains('antenna')) {
      final name = nameFor(cat.designatedFor(kCategoryAntenna));
      if (name != null) our['antenna'] = name;
    }
    if (tracked.contains('key')) {
      final name = nameFor(cat.designatedFor(kCategoryKey));
      if (name != null) our['key'] = name;
    }
    return {...qso, 'our': our, if (power != null) 'power': power};
  }

  /// The Radio control's quick-access dialog: current configuration and the
  /// current rig only, not the full Station Configuration page — that's one
  /// tap away via the footer's More Settings.
  Future<void> _openStationConfigDialog(BuildContext context) => showModalPane<void>(
    context,
    title: context.t.settings.station.title,
    closeLabel: context.t.common.close,
    // StationPanel is its own scrolling ListView — the pane must not also
    // wrap it in a SingleChildScrollView.
    scrollable: false,
    builder: (context) => StationPanel(
      services: widget.services,
      compact: true,
      onMoreSettings: () {
        final navigator = Navigator.of(context);
        navigator.pop();
        navigator.push(MaterialPageRoute(
          builder: (_) => SettingsView(services: widget.services, initialPanel: 'station'),
        ));
      },
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _metrics = LayoutDensity.metricsOf(context);
  }

  /// The resolved dimensions, refreshed by [didChangeDependencies].
  ///
  /// Cached for the same reason `QsoList` caches its own: [_pageRows] runs
  /// from key handlers, outside build, where depending on an inherited widget
  /// is not allowed. The two caches resolve from contexts one widget apart,
  /// which is what keeps a page jump stepping by the height the rows really
  /// have — see [_pageRows].
  late LayoutMetrics _metrics;

  @override
  void initState() {
    super.initState();
    widget.services.settings.addListener(_onSettingsChanged);
    // The QSO list's empty state warns when the VFO needs attention
    // — rebuild so it clears the moment the operator answers via
    // the Radio control, without waiting for an unrelated rebuild.
    widget.services.radio.addListener(_onRadioChanged);
    // Gated the same way _computeHasConfiguredRadio reads it — no listener,
    // no CatService built, when the experiment is off. _onSettingsChanged
    // keeps this in sync with _gatoEnabled if the experiment flips later.
    if (_gatoEnabled) {
      widget.services.cat.addListener(_onCatChanged);
    }
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
    if (_gatoEnabled) {
      widget.services.cat.removeListener(_onCatChanged);
    }
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
  /// Every row the list shows is navigable, including event and annotation
  /// markers (operation start/break/end, NOTE/TODO/SOLAR/WEATHER) — selecting
  /// one loads `LoggingControls`' inline event editor the same way a tap
  /// does (`Qso.isEvent`), same as any other row.
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
    // The cached metrics, not a fresh lookup: this runs from a key handler,
    // and `LayoutDensity.of` depends on an inherited widget, which outside
    // build registers a permanent dependency and asserts once the element is
    // deactivated. Reading the same rung QsoList paints with is what keeps a
    // page jump stepping by the height the rows really have.
    final rows = (box.size.height / _metrics.qsoRowHeight).floor() - 1;
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
    // The 'gato' experiment can flip while this panel stays mounted (e.g.
    // toggled from the Experiments panel over this one) — keep the cat
    // listener's attachment and the fields it feeds in sync with it right
    // away, rather than leaving them to drift until the next CAT event.
    final gato = s.experimentEnabled('gato') /* stored key, see experiments.yaml */;
    if (gato != _gatoEnabled) {
      if (gato) {
        widget.services.cat.addListener(_onCatChanged);
      } else {
        widget.services.cat.removeListener(_onCatChanged);
      }
      // Its own setState — _onCatChanged's below only fires one if the
      // radio-derived fields it owns actually changed, which they don't
      // when this flips with no CAT radio ever configured (has/connected/
      // name all stay false/false/null), leaving build()'s own read of
      // _gatoEnabled stale until some unrelated rebuild catches up.
      setState(() => _gatoEnabled = gato);
      _onCatChanged();
    }
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

  /// Rebuilds the Radio control's icon when CAT equipment is added, removed,
  /// designated as `radio1`, or connects/disconnects — not a VFO update,
  /// that's [_onRadioChanged].
  void _onCatChanged() {
    final has = _computeHasConfiguredRadio();
    final connected = _computeRadioConnected();
    final name = _computeRadioName();
    if (has != _hasConfiguredRadio || connected != _radioConnected || name != _radioName) {
      setState(() {
        _hasConfiguredRadio = has;
        _radioConnected = connected;
        _radioName = name;
      });
    }
  }

  void _handleSelectQso(Qso qso) {
    setState(() {
      _selectedQso = _selectedQso?.uuid == qso.uuid ? null : qso;
    });
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
      showRSTFields: widget.showRSTFields,
      switchSentRcvd: widget.switchSentRcvd,
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
              child: _LazyQsoList(
                // Only worth deferring a large log's expensive first build —
                // a short one (including a brand-new, empty operation) is
                // cheap enough that showing it immediately, empty-state
                // message and all, beats replacing it with a spinner first.
                // A field on the SAME widget type, not a ternary between two
                // different ones at this tree slot: logging (or deleting) a
                // QSO can cross the threshold while the panel is open, and a
                // changed runtimeType here would discard and remount
                // _QsoListState — silently throwing an operator's scroll
                // position and jumping back to the bottom mid-review.
                largeEnough: widget.qsos.length >= _lazyQsoListThreshold,
                child: list,
              ),
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
            hasConfiguredRadio: _hasConfiguredRadio,
            radioConnected: _radioConnected,
            // Gated on the experiment, not on whether a radio happens to be
            // configured — the button itself is a Station Configuration
            // affordance that shouldn't exist for operators without it on.
            onOpenStationConfig: _gatoEnabled ? () => _openStationConfigDialog(context) : null,
            stationConfigLabel: context.t.settings.station.title,
            radioName: _radioName,
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
                .loggingControls(widget.operation.data, qso: qso)
                .then((result) => result.loadFailed ? null : result.controls),
            decorateQsoBeforeSave: (qso) =>
                widget.services.extensions.decorateQsoBeforeSave(_withStationInfo(qso), widget.operation.data),
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
            // Wrapped rather than torn off, to inject the activities this
            // operation has hunted — an operation that activates nothing names
            // no activity on its own refs, so without this the pills fall back
            // to the core dupe rule and call a station worked at another park a
            // plain duplicate (docs/design/activities.md §4).
            scoreQso: ({required operation, required qso, excludeUuid, segments}) =>
                widget.services.extensions.scoreQso(
                  operation: operation,
                  qso: qso,
                  excludeUuid: excludeUuid,
                  segments: segments,
                  huntedRefTypes: ((widget.operation.localData['huntedRefTypes'] as List?) ?? const [])
                      .whereType<String>()
                      .toSet(),
                ),
            scoreNoticeLabel: (key) => scoreNoticeLabel(context, key),
            onCallInfoChanged: widget.onCallInfoChanged,
            onQsoChanged: widget.onQsoChanged,
            onCallInfoTap: widget.onCallInfoTap,
            showRSTFields: widget.showRSTFields,
            showStateField: widget.showStateField,
            showGridField: widget.showGridField,
            defaultReport: widget.defaultReport,
            defaultReportCW: widget.defaultReportCW,
            defaultReportFT8: widget.defaultReportFT8,
            switchSentRcvd: widget.switchSentRcvd,
            jumpAfterRST: widget.jumpAfterRST,
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
            noteFieldLabel: context.t.loggingControls.noteField,
            todoFieldLabel: context.t.loggingControls.todoField,
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
            pendingDeleteEventWarning: (kind) =>
                context.t.loggingControls.pendingDeleteEventWarning(kind: kind),
            deletedEventWarning: (kind) => context.t.loggingControls.deletedEventWarning(kind: kind),
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

/// Below this QSO count, [QsoList]'s first build is cheap enough that
/// [_LazyQsoList]'s spinner isn't worth showing at all — see its call site.
const _lazyQsoListThreshold = 200;

/// Defers [child]'s first build behind a spinner until the enclosing route's
/// own push transition finishes — [QsoList]'s first inflation on a large
/// operation is expensive enough (HALO-258) to stutter if it lands on the
/// same frames as that transition. Tied to the transition's actual
/// [AnimationStatus] first, rather than a guessed duration alone: a fixed
/// timer close to the transition's own length would land the swap
/// mid-animation as often as after it. Only defers once: [child]'s
/// underlying QSO stream already updates in place above this widget
/// regardless of readiness, so later emissions rebuild [child] without
/// resetting it.
class _LazyQsoList extends StatefulWidget {
  final Widget child;
  final bool largeEnough;

  const _LazyQsoList({required this.child, required this.largeEnough});

  @override
  State<_LazyQsoList> createState() => _LazyQsoListState();
}

/// Slack past the transition's own length before [_LazyQsoListState] gives
/// up on the status listener and forces readiness — see its settle timer.
const _settleSlack = Duration(milliseconds: 100);

class _LazyQsoListState extends State<_LazyQsoList> {
  bool _ready = false;
  Animation<double>? _routeAnimation;
  Timer? _settleTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeArm();
  }

  @override
  void didUpdateWidget(_LazyQsoList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Logging past the threshold while the panel is already open (the call
    // site keeps this the same widget type specifically to allow that — see
    // its comment) only changes `largeEnough`, which doesn't dirty
    // dependencies — without this, arming would never happen and the
    // spinner this build shows from here on would never clear.
    _maybeArm();
  }

  void _maybeArm() {
    if (_ready || _routeAnimation != null || !widget.largeEnough) return;
    final route = ModalRoute.of(context);
    final animation = route?.animation;
    if (animation == null || animation.isCompleted) {
      // No enclosing route transition (or it already finished before this
      // widget mounted, e.g. reached other than by a fresh push) — nothing
      // to wait for.
      _ready = true;
      return;
    }
    _routeAnimation = animation..addStatusListener(_onRouteAnimationStatus);
    // The status listener is the fast path, but the transition's own
    // AnimationController is driven by a Ticker that a backgrounded/occluded
    // desktop window can stop delivering frames to — stranding the
    // controller mid-flight with no forward or reverse status ever firing
    // again. A wall-clock deadline, comfortably past the transition's own
    // length, is the only way off that path that doesn't depend on the
    // ticker resuming on its own. Armed a frame late (post-frame callback,
    // not here) so the deadline is measured from an actual rendered frame —
    // arming mid-build would count time this build itself hasn't spent yet.
    // ModalRoute always extends TransitionRoute, and `route` is non-null
    // here (its animation isn't) — see ModalRoute's declaration. The longer
    // of the two directions: _onRouteAnimationStatus treats a pop
    // (dismissed) as equally valid as a completed push, so the deadline
    // has to cover whichever transition is actually playing.
    final forward = route!.transitionDuration;
    final reverse = route.reverseTransitionDuration;
    final transitionDuration = (forward > reverse ? forward : reverse) + _settleSlack;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _ready) return;
      _settleTimer = Timer(transitionDuration, () {
        if (!mounted || _ready) return;
        _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
        setState(() => _ready = true);
      });
    });
  }

  void _onRouteAnimationStatus(AnimationStatus status) {
    // completed: the ordinary forward-push case this exists for. dismissed:
    // the transition unwound instead of finishing (e.g. this widget mounted
    // mid-pop, or a push got cancelled) — settling back to nothing playing
    // out is just as much "stop waiting" as finishing forward is.
    if (status != AnimationStatus.completed && status != AnimationStatus.dismissed) return;
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    _settleTimer?.cancel();
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    _settleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      (!widget.largeEnough || _ready) ? widget.child : const Center(child: CircularProgressIndicator());
}
