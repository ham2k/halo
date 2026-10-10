// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard, KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../config/dev_bridge.dart';
import '../../services/hook_payloads.dart';
import '../../services/halo_services.dart';
import 'package:halo_i18n/halo_i18n.dart';
import '../../services/cat/equipment.dart';
import '../../services/cat/cat_service.dart';
import '../../services/error_reporting_service.dart';
import '../../services/link_opener.dart';
import '../../services/settings_service.dart';
import '../../tools/call_location_line.dart';
import '../../tools/operation_stats.dart';
import '../../tools/scoring_labels.dart';
import '../../tools/scoring_summaries.dart';
import '../../tools/worked_before_label.dart';
import '../station_config_dialog.dart';
import '../keyer_area.dart';
import 'extension_panel.dart' show PanelRenderContext;

/// Builds the QSO list's day-header/event-row vocabulary for the active
/// locale. Month/weekday abbreviations come from `intl`'s `DateFormat`
/// (already initialized for the app's locales by
/// `GlobalMaterialLocalizations`), so they localize for free; the relative
/// and event words come from the app's own translations. 2024-01-01 is a
/// Monday, so a 7-day walk from it yields Mon…Sun in order.
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

  /// Which contacts get a country flag in the QSO list (Logging settings).
  final DxFlags dxFlags;

  final String? ourEntityPrefix;

  /// The operator's own ITU region (1/2/3) and lowercase ISO country code
  /// — resolved by `OperationRuntimeState.resolveOurEntity` alongside
  /// [ourEntityPrefix], and passed straight through to LoggingControls so a
  /// typed/commanded frequency gets a band-plan mode guess scoped to where
  /// the operator actually is.
  final int? ourItuRegion;
  final String? ourCountryCode;

  final Map<String, dynamic>? suggestedQso;

  /// All passed straight through to [LoggingControls]'s groups — see their docs.
  final ({int serial, Map<String, dynamic> qso})? logRequest;
  final Future<bool> Function({required bool editing})? confirmLogOverwrite;
  final bool suggestedQsoIsTentative;
  final int suggestionSettledSerial;

  /// The operator typed in (or wiped) the call field — see
  /// [LoggingSession.onCallEdited]. The spots list closes any open slid row
  /// on it.
  final VoidCallback? onCallEdited;

  /// A QSO (or event row) was just written from the controls — the
  /// operation view's own signal that the operator is logging, whatever
  /// keyboard they use.
  final VoidCallback? onQsoLogged;
  final SerialNumberSource? serialNumbers;

  /// Forwards LoggingControls' command output up to the operation view,
  /// which shows it on the Info pane (the wide layout is the operation
  /// view's job — see docs/design/layouts.md).
  final ValueChanged<String?>? onCommandMessageChanged;

  /// Forwards the current call-info up to the operation view for the Call Info
  /// detail panel (Info tab / modal). See [LookupHooks.onCallInfoChanged].
  final CallInfoChanged? onCallInfoChanged;

  /// Forwards the QSO being composed up to the operation view, for extension
  /// panels declaring the `qso` trigger. Null unless one of them is actually
  /// in the layout — see [LoggingSession.onQsoChanged], which is only cheap
  /// while this is null.
  final QsoDraftChanged? onQsoChanged;

  /// Forwards the same draft plus which fields the operator actually filled,
  /// for the peers sharing this operation. Independent of [onQsoChanged]:
  /// what reads it is a panel on ANOTHER device, so the layout here has no
  /// say in whether it is wanted. See [LoggingSession.onPeerDraftChanged].
  final PeerDraftChanged? onPeerDraftChanged;

  /// Fires when the info area is tapped while it shows the call info — the
  /// operation view opens the detail (modal on narrow, focuses the Info tab
  /// on wide).
  final VoidCallback? onCallInfoTap;

  /// Keys CW message [n] (1-based) — the keyer area's message buttons, the
  /// same path as F1-F8 (OperationView renders the template against the
  /// draft contact, which only it holds).
  final void Function(int n)? onSendCwMessage;

  /// Keys what an Enter Sends Messages step picked, rendered against the
  /// draft handed over — see [LoggingSession.enterSends]. Null leaves ESM
  /// off whatever its switch says.
  final void Function(List<EsmMessage> messages, Map<String, dynamic> qso, {Future<Map<String, dynamic>?>? logged})? onEnterSends;

  /// What the keyer area's button labels render against — the operation
  /// and the draft contact, the same context the messages themselves get.
  /// A new one arrives with each draft change (debounced upstream).
  final PanelRenderContext? cwTemplateContext;

  /// Whether the keyer area is the voice keyer's — the draft contact's mode
  /// is Phone — decided by the operation view, which routes the function
  /// keys by the same answer.
  final bool keyingPhone;

  /// Fires when a day header in the QSO list is tapped, or the info area
  /// while it shows anything but the call info — the operation view opens
  /// the operation's own info the same two ways.
  final VoidCallback? onOperationInfoTap;

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
    this.dxFlags = DxFlags.dx,
    this.ourEntityPrefix,
    this.ourItuRegion,
    this.ourCountryCode,
    this.suggestedQso,
    this.logRequest,
    this.confirmLogOverwrite,
    this.suggestedQsoIsTentative = false,
    this.suggestionSettledSerial = 0,
    this.onCallEdited,
    this.onQsoLogged,
    this.serialNumbers,
    this.onCommandMessageChanged,
    this.onCallInfoChanged,
    this.onQsoChanged,
    this.onPeerDraftChanged,
    this.onCallInfoTap,
    this.onSendCwMessage,
    this.onEnterSends,
    this.cwTemplateContext,
    this.keyingPhone = false,
    this.onOperationInfoTap,
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
  late List<String> _controlOrder = widget.services.settings.secondaryControlsOrder;
  late Set<String> _hiddenControls = widget.services.settings.hiddenSecondaryControls;
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
  late bool _showExtraInNumbersRow = widget.services.settings.showExtraInNumbersRow;
  late bool _vibrateNumbersRow = widget.services.settings.vibrateNumbersRow;
  late bool _leftieMode = widget.services.settings.leftieMode;

  // Whether the QSO list's empty state should warn to check the radio
  // — mirrors LoggingControls' own `_vfoIsUnset`: no band *and* no
  // frequency, or no mode. Cached and diffed in `_onRadioChanged` for the
  // same reason as the numbers-row settings above — this panel's QsoList is
  // expensive to rebuild, and most VFO changes (e.g. tuning within the same
  // band) don't flip this boolean.
  late bool _needsBandOrMode = _computeNeedsBandOrMode();

  // Whether every saved QSO gets the current power stamped on it
  // (_withStationInfo). The logging controls need this to know that power is
  // being logged even with the Power control out of the row — and it can
  // flip while this panel is alive, from the Radio control's own quick
  // Station Configuration dialog.
  late bool _trackingPower = _computeTrackingPower();

  bool _computeTrackingPower() {
    final settings = widget.services.settings;
    return settings.trackStationInfo && settings.stationInfoTrackedFields.contains('power');
  }

  bool _computeNeedsBandOrMode() {
    final vfo = widget.services.radio.vfoA;
    return (vfo.freq == null && vfo.band == null) || vfo.mode == null;
  }

  /// The CW keying surfaces (keyer area, Escape-stops-a-message). Kept in
  /// sync by _onSettingsChanged.
  late bool _keyerEnabled = widget.services.settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */;

  /// Enter Sends Messages, on top of the keyer. Kept in sync by
  /// _onSettingsChanged like _keyerEnabled.
  late bool _esmEnabled = widget.services.settings.experimentEnabled('esm') /* stored key, see experiments.yaml */;

  // Whether the Radio control's icon should read as CAT-configured.
  late bool _hasConfiguredRadio = _computeHasConfiguredRadio();

  // The ROLE, not locality: a peer's radio the operator picked for the main
  // VFO is a configured radio, whether or not this device holds the session
  // to it. `_radioConnected` below is where locality is the question.
  bool _computeHasConfiguredRadio() => widget.services.cat.radio1 != null;

  // Whether the main VFO's radio is actually reachable right now, as opposed
  // to merely configured — the Station Configuration button's red/green.
  //
  // Asked of whichever kind fills the role, because the pair is read as one:
  // a configured radio that never reads connected is a permanent red alarm,
  // which is what a peer's rig would be if this only ever asked about a
  // local session. For a peer that means the peer is offering it right now —
  // the same fact the Station dialog's row states as availability.
  late bool _radioConnected = _computeRadioConnected();

  bool _computeRadioConnected() => widget.services.radio1IsLive;

  late bool _radioTransmitting = widget.services.cat.radio1IsTransmitting || widget.services.cat.pttKeys.held.value;

  // The main VFO's display name — the Radio control's own reflection of the
  // same name station_panel.dart's equipment list shows for it.
  late String? _radioName = _computeRadioName();

  String? _computeRadioName() => widget.services.radio1Name;

  /// Merges the operator's tracked station-info fields (Station
  /// Configuration's "Track Station Info for each QSO") into a QSO at save
  /// time. Runs before `decorateQsoBeforeSave`'s extension hooks, so an
  /// activity can still see and adjust the captured values. Rig/antenna/key
  /// nest under `our`; power is top-level (`Qso.power`), matching QSON
  /// convention (freq/band/mode) rather than app-only placement.
  Map<String, dynamic> _withStationInfo(Map<String, dynamic> qso) {
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
      // Whatever drives the VFO — a peer's rig is the one the contact was
      // worked through, and the panel names it two rows up.
      final name = widget.services.radio1Name;
      if (name != null) our['rig'] = name;
    }
    // Never over a power the entry already states — the Power control's
    // field, the More pane, or the record's own value. Ambient capture fills
    // a gap; it does not correct the operator, and on a saved edit it would
    // otherwise rewrite what a contact was actually worked at with whatever
    // the rig is set to today.
    if (tracked.contains('power') && qso['power'] == null) {
      power = cat.displayedPower;
    }
    if (tracked.contains('antenna')) {
      final name = nameFor(cat.designatedFor(kCategoryAntenna));
      if (name != null) our['antenna'] = name;
    }
    if (tracked.contains('key')) {
      // The key in use may be a radio keying over CAT; that is a keying
      // source, not a key on the desk worth a QSO's key field. A keyer
      // device is one.
      final uuid = cat.designatedFor(kCategoryKey);
      final node = uuid == null ? null : cat.nodeFor(uuid);
      final name = nameFor(uuid);
      if (name != null && node != null && cat.typeFor(node)?.category != kCategoryTransceiver) our['key'] = name;
    }
    return {...qso, 'our': our, 'power': ?power};
  }

  Future<void> _openStationConfigDialog(BuildContext context) => showStationConfigDialog(context, widget.services);

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
    widget.services.cat.addListener(_onCatChanged);
    // A peer's rig going away or coming back is this notifier's news
    // alone — CatService hears nothing, so without this the chip keeps
    // whatever colour it had when the link dropped.
    widget.services.peerRemoteRadios.addListener(_onCatChanged);
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
    widget.services.cat.removeListener(_onCatChanged);
    widget.services.peerRemoteRadios.removeListener(_onCatChanged);
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
        if (widget.services.cat.escapeStoppedKeying) return KeyEventResult.handled;
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
  /// re-select the QSO the first had just dropped (an undo on a second
  /// press would fight the focus ladder, where Escape is
  /// uniformly the way *out* of wherever the keyboard is — walking back
  /// *in* is the one thing it must never do).
  ///
  /// A locked (staged-delete or deleted) QSO's fields are always disabled, so
  /// its view can never hold focus and `LoggingControls`' own Escape guard
  /// never gets a chance to run — this mirrors that guard here so Escape
  /// doesn't close the read-only view it's meant to protect.
  void _handlePanelEscape() {
    // An Escape OperationView's key handler spent on stopping keying is spent
    // here too — the same rule LoggingSession.escapeClaimed carries into the
    // fields.
    if (widget.services.cat.escapeStoppedKeying) return;
    if (_selectedQso == null || _loggingController.isFieldsLocked) return;
    setState(() => _selectedQso = null);
  }

  /// Only rebuild when a numbers-row setting actually changes —
  /// SettingsService also notifies on frequent sync-state writes, and this
  /// panel's QsoList is expensive to rebuild.
  void _onSettingsChanged() {
    final s = widget.services.settings;
    final keyer = s.experimentEnabled('keyer') /* stored key, see experiments.yaml */;
    if (keyer != _keyerEnabled) {
      // Switched off mid-message: the keyer area and its Escape go away with
      // the flag, so nothing would be left to stop what is on the air.
      if (!keyer && widget.services.cat.cwSending) widget.services.cat.stopCw();
      setState(() => _keyerEnabled = keyer);
    }
    final esm = s.experimentEnabled('esm') /* stored key, see experiments.yaml */;
    if (esm != _esmEnabled) setState(() => _esmEnabled = esm);
    final trackingPower = _computeTrackingPower();
    if (trackingPower != _trackingPower) setState(() => _trackingPower = trackingPower);
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

  /// Enter Sends Messages as it stands at this Enter: on, and the key the
  /// draft's mode picks able to send — otherwise off, and Enter logs.
  EnterSends? _enterSends() {
    final send = widget.onEnterSends;
    if (send == null || !_keyerEnabled || !_esmEnabled) return null;
    final cat = widget.services.cat;
    final esm = cat.enterSends.value;
    if (!esm.on) return null;
    if (widget.keyingPhone ? !cat.canPlayVoice : !cat.canKeyCw) return null;
    return EnterSends(running: esm.running, send: send);
  }

  /// Rebuilds the Radio control's icon when CAT equipment is added, removed,
  /// designated as `radio1`, or connects/disconnects — not a VFO update,
  /// that's [_onRadioChanged].
  void _onCatChanged() {
    final has = _computeHasConfiguredRadio();
    final connected = _computeRadioConnected();
    final name = _computeRadioName();
    final transmitting = widget.services.cat.radio1IsTransmitting || widget.services.cat.pttKeys.held.value;
    if (has != _hasConfiguredRadio || connected != _radioConnected || name != _radioName || transmitting != _radioTransmitting) {
      setState(() {
        _hasConfiguredRadio = has;
        _radioConnected = connected;
        _radioName = name;
        _radioTransmitting = transmitting;
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

  /// The call-info panel's line-1 location string, against THIS operation
  /// and this device's own units — see [callLocationLine], which the peer
  /// positions panel composes the same line with.
  String? _callLocationLine(BuildContext context, Map<String, dynamic> guess) => callLocationLine(
    context,
    guess,
    ourLocation: widget.operation.location,
    miles: widget.services.settings.distanceUnits == DistanceUnits.miles,
    showBearing: widget.services.settings.showBearing,
    showReverseBearing: widget.services.settings.showReverseBearing,
    ourEntityPrefix: widget.ourEntityPrefix,
  );

  @override
  Widget build(BuildContext context) {
    // Cached by `ScoringService.rescoreOperation` into `Operation.localData`
    // (never synced — DESIGN.md §4); absent until the first rescore lands.
    final scoring = widget.operation.localData['scoring'] as Map<String, dynamic>?;
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
      onTapDayHeader: widget.onOperationInfoTap,
      showRSTFields: widget.showRSTFields,
      switchSentRcvd: widget.switchSentRcvd,
      showQsoNumbers: widget.showQsoNumbers,
      activityControls: widget.loggingControls,
      ourEntityPrefix: widget.ourEntityPrefix,
      dxFlags: widget.dxFlags,
      daySections: daySections,
    );

    // Escape deselecting a QSO regardless of what has focus (e.g. the QSO
    // was selected via a list tap, which never focuses anything inside
    // LoggingControls). LoggingControls' own
    // CallbackShortcuts, closer to the compose form's fields, still handles
    // Escape whenever focus IS there (discard-typed-changes) —
    // this one only fires when that inner one doesn't.
    final panel = CallbackShortcuts(
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
            log: LogHooks(
              operation: widget.operation,
              qsosRepository: widget.services.qsos,
              qsos: widget.qsos,
              decorateQsoBeforeSave: (qso, operation) =>
                  widget.services.extensions.decorateQsoBeforeSave(qsoWithOperator(_withStationInfo(qso), widget.operation), operation),
              onWriteError: (error, stack) => ErrorReportingService.report(error, stack, context: 'loggingControls:log'),
              serialNumbers: widget.serialNumbers,
              onLogged: (qso) {
                // Event rows (NOTE/TODO/SOLAR/WEATHER annotations, operation
                // start/break/end) also arrive here via the command `addQso`
                // action — they're not contacts and must not count as QSOs.
                // _selectedQso is still set here for a save-of-edit; it only
                // clears below — that's what tells the two events apart.
                if (!qso.isEvent) {
                  widget.services.track(_selectedQso != null ? 'qso_edited' : 'qso_added', _qsoTrackProps(qso));
                }
                setState(() => _selectedQso = null);
                widget.onQsoLogged?.call();
              },
              onQsoDeleted: (qso) {
                if (!qso.isEvent) widget.services.track('qso_deleted', _qsoTrackProps(qso));
              },
              onQsoUndeleted: (qso) {
                if (!qso.isEvent) widget.services.track('qso_undeleted', _qsoTrackProps(qso));
              },
              // A comma-separated call list logs several QSOs at
              // once — one rescore for the whole batch, not one per call.
              onCallListLogged: () => widget.services.scoring.rescoreOperation(widget.operation),
            ),
            session: LoggingSession(
              controller: _loggingController,
              // Only with CAT: the strip reads CatService.cwProgress, which
              // nothing writes without a keyer-capable radio.
              // Escape stops every message, chain and repeat before it closes
              // or cancels anything — see LoggingSession.escapeClaimed. The
              // stop itself is OperationView's key handler's, which runs first.
              escapeClaimed: _keyerEnabled ? () => widget.services.cat.escapeStoppedKeying : null,
              // A call typed over a CQ stops it — see CatService.stopMessageOne.
              onCallTyped: _keyerEnabled ? widget.services.cat.stopMessageOne : null,
              enterSends: _enterSends,
              editingQso: _selectedQso,
              suggestedQso: widget.suggestedQso,
              logRequest: widget.logRequest,
              confirmLogOverwrite: widget.confirmLogOverwrite,
              suggestedQsoIsTentative: widget.suggestedQsoIsTentative,
              suggestionSettledSerial: widget.suggestionSettledSerial,
              onCallEdited: widget.onCallEdited,
              onEditCanceled: () => setState(() => _selectedQso = null),
              onNavigateToQsoList: _handleNavigateToQsoList,
              onQsoChanged: widget.onQsoChanged,
              onPeerDraftChanged: widget.onPeerDraftChanged,
            ),
            radio: RadioHookup(
              enabledBands: _enabledBands,
              enabledModes: _enabledModes,
              radioService: widget.services.radio,
              // Same object, as a Listenable — so the Radio control follows a
              // connected rig (CAT) instead of only reading the VFO when it
              // seeds. See RadioHookup.radioUpdates.
              radioUpdates: widget.services.radio,
              hasConfiguredRadio: _hasConfiguredRadio,
              radioConnected: _radioConnected,
              radioTransmitting: _radioTransmitting,
              // Offered with no radio configured too: the dialog is where
              // one gets configured.
              onOpenStationConfig: () => _openStationConfigDialog(context),
              onConnectRadio: _hasConfiguredRadio ? radio1ConnectAction(widget.services.cat, connected: _radioConnected) : null,
              radioName: _radioName,
              ourItuRegion: widget.ourItuRegion,
              ourCountryCode: widget.ourCountryCode,
              trackingPower: _trackingPower,
            ),
            lookups: LookupHooks(
              // Call notes carry socials and URLs, styled as links; this makes
              // them open.
              onOpenLink: openExternalUrl,
              lookup: widget.services.extensions.lookupCall,
              enqueueLookup: widget.services.lookupQueue.enqueue,
              // force: false — unlike the explicit "Lookup all QSOs" action,
              // a SEED batch shouldn't force-refresh a QSO that (somehow)
              // already carries real online lookup data.
              enqueueAllLookups: (qsos) => widget.services.lookupQueue.enqueueAll(qsos, force: false),
              operationStatsLines: (qsos) => operationStatsLines(context, qsos),
              callLocationLine: (guess) => _callLocationLine(context, guess),
              // Wrapped rather than torn off, to inject the activities this
              // operation has hunted — an operation that activates nothing names
              // no activity on its own refs, so without this the pills fall back
              // to the core dupe rule and call a station worked at another park a
              // plain duplicate (docs/design/activities.md §4).
              scoreQso: ({required operation, required qso, excludeUuid, segments}) {
                // The last rescore's checkpoints, when the log this panel holds
                // is exactly what they folded plus appended contacts — so the
                // pills resume from a cached sheet instead of re-folding a
                // long log on every keystroke (liveResumeFor says when).
                final resume = widget.services.scoring.liveResumeFor(widget.operation, widget.qsos, excludeUuid: excludeUuid);
                return widget.services.extensions.scoreQso(
                  operation: operation,
                  qso: qso,
                  excludeUuid: excludeUuid,
                  segments: segments,
                  huntedRefTypes: ((widget.operation.localData['huntedRefTypes'] as List?) ?? const []).whereType<String>().toSet(),
                  resume: resume,
                );
              },
              scoreNoticeLabel: (key) => scoreNoticeLabel(context, key),
              workedBefore: (call, {excludingQsoUuid}) => widget.services.qsos.historyStartTimesForCall(call, excludingUuid: excludingQsoUuid),
              workedBeforeLabel: (times) => workedBeforeLabel(context, times),
              onCallInfoChanged: widget.onCallInfoChanged,
              onCallInfoTap: widget.onCallInfoTap,
              onOperationInfoTap: widget.onOperationInfoTap,
            ),
            activities: ActivityHooks(
              activityControls: widget.loggingControls,
              refreshActivityControls: (qso) => widget.services.extensions
                  .loggingControls(operationPayloadFor(widget.operation), qso: qso)
                  .then((result) => result.loadFailed ? null : result.controls),
              decorateRef: widget.services.extensions.decorateRef,
            ),
            commands: CommandHooks(
              interpretCommand: widget.services.extensions.interpretCommand,
              interpretationUpdates: widget.services.extensions.commandInterpretationUpdates,
              onCommandMessageChanged: (message) => widget.onCommandMessageChanged?.call(message),
              onCommandAction: widget.onCommandAction,
              // Lets the ⌘K dialog apply a command to this panel — see
              // HaLoServices.currentCommandDispatch. Attached to this
              // operation's own stack entry, so a disposing panel can't detach a
              // still-live one's dispatcher.
              onDispatcherChanged: (dispatch) => widget.services.setCommandDispatchFor(widget.operation.uuid, dispatch),
            ),
            strip: ControlStripSettings(
              aboveEntryRow: _keyerEnabled
                  ? KeyerArea(
                      cat: widget.services.cat,
                      services: widget.services,
                      onSendMessage: widget.onSendCwMessage,
                      templateContext: widget.cwTemplateContext,
                      phone: widget.keyingPhone,
                      enterSends: _esmEnabled,
                      suppressed: _selectedQso != null,
                    )
                  : null,
              controlOrder: _controlOrder,
              hiddenControlKeys: _hiddenControls,
              onControlsSettingsChanged: _handleControlsSettingsChanged,
            ),
            spotting: SpottingHooks(suggestSpotSources: widget.services.extensions.suggestSpotSources, sendSpot: widget.services.extensions.sendSpot),
            prefs: LoggingPreferences(
              // Leftie Mode is a one-handed-phone layout; a desktop or web session
              // carrying a stored `true` (restored from a phone) has no toggle to
              // clear it, so the platform gates the layout, not just the setting.
              leftieMode: isMobilePlatform && _leftieMode,
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
              // What the save path would stamp on a contact that names neither
              // — the pane offers them as placeholders, not as values.
              defaultOperatorCall: operatorCallFor(widget.operation),
              defaultPosition: multiIdentifierFor(widget.operation),
              showPositionField: operationHasPositions(widget.operation),
            ),
          ),
        ],
      ),
    );

    // LoggingControls' modifier chords, for the same reason as Escape above:
    // with a delete staged its fields are disabled, so the keyboard is in the
    // list (or nowhere) exactly when Cmd/Ctrl+Z has something to take back.
    return Focus(canRequestFocus: false, skipTraversal: true, onKeyEvent: (node, event) => _loggingController.handleChord(event), child: panel);
  }

  /// The qso_* events' shared properties — same two app-polo sends: the
  /// contact's DXCC prefix and the ref types on the QSO. Never the callsign
  /// or any other identifying detail.
  Map<String, Object?> _qsoTrackProps(Qso qso) => {'their_prefix': qso.theirEntityPrefix, 'refs': qso.refs.map((r) => r['type']).join(',')};
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
  Widget build(BuildContext context) => (!widget.largeEnough || _ready) ? widget.child : const Center(child: CircularProgressIndicator());
}

/// What the Radio control's plug does while the main radio is down: connect
/// it. Only for this station's own radio with somewhere to connect to — a
/// peer's session is the other device's, and a radio with no port or
/// address has nothing to open. Null hides the plug.
VoidCallback? radio1ConnectAction(CatService cat, {required bool connected}) {
  if (connected) return null;
  if (cat.radio1 case LocalRadio(:final uuid)) {
    final node = cat.nodeFor(uuid);
    if (node == null || (cat.typeFor(node)?.isUnconfigured(node.config) ?? true)) return null;
    return () => unawaited(cat.connect(uuid));
  }
  return null;
}
