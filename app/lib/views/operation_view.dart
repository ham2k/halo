// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The logging view: a dock of panes (docs/design/layouts.md) — the QSO list
// with its logging panel, Info, Spots and Map — under the operation's own
// header, whose sheet holds settings, activities and data.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard, KeyDownEvent, KeyEvent, LogicalKeyboardKey, PhysicalKeyboardKey;
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../config/dev_bridge.dart';
import '../services/command_actions.dart';
import '../services/halo_services.dart';
import '../services/error_reporting_service.dart';
import '../services/cat/drivers/cw_send_queue.dart' show sanitizeCwText;
import '../services/cat/zero_beat.dart';
import '../services/extensions/extension_service.dart' show TemplateError;
import '../services/spot_board_service.dart' show SpotBoardSubscription;
import '../services/panel_service.dart';
import '../services/settings_service.dart';
import '../services/wake_lock_service.dart';
import '../settings/settings_target_dialog.dart';
import 'dock_host.dart';
import 'operation_dialogs.dart';
import 'panel_use_tracker.dart';
import 'operation/adif_import_flow.dart';
import 'operation/activities_view.dart';
import 'operation/call_info_panel.dart';
import 'operation/cw_function_keys.dart';
import 'operation/extension_panel.dart';
import 'operation/information_panel.dart';
import 'operation/logging_panel.dart';
import 'operation/map_panel.dart';
import 'operation/operation_export_panel.dart';
import 'operation/operation_import_panel.dart';
import 'operation/operation_runtime_state.dart';
import 'operation/spots_panel.dart';
import 'tester_overlay.dart' show testerOverlayCovering;
import 'operation/positions_panel.dart';
import 'operation/read_only_while_deleted.dart';
import 'peers_panel.dart';
import 'sheet_header_dots.dart';
import '../tools/operation_title.dart';
import 'package:halo_i18n/halo_i18n.dart';

part 'operation/operation_view_dock.dart';
part 'operation/operation_view_header.dart';
part 'operation/operation_view_keying.dart';
part 'operation/operation_view_sheet.dart';

class OperationView extends StatefulWidget {
  /// The Operation view's panes are user-arrangeable
  /// (docs/design/layouts.md), and its dividers use the solid header-colored
  /// style (the default).
  static const layoutPolicy = ViewLayoutPolicy.customizable;

  final HaLoServices services;
  final String operationUuid;

  /// Open the Activities pane as soon as the operation loads — the
  /// new-operation flow skips its old call/title dialog and lands here, so
  /// picking activities is the first step of setting up an operation.
  /// Fallback until an onboarding flow exists: when the active profile has
  /// no callsign yet, the callsign editor opens instead (see
  /// [_OperationSheetHost._promptForCallsign]).
  final bool openActivities;

  /// A QSON-shaped suggestion to put into the logging fields as this view
  /// opens — a `/qso` deep link that had to push the view to land anywhere.
  ///
  /// A constructor argument rather than a call on the command context,
  /// because the context of a view being pushed has no `suggestQso` yet: the
  /// caller would have to poll for the state to mount (which is what app-polo
  /// does, with a 2s retry loop). Applied once, in `initState`.
  final Map<String, dynamic>? initialSuggestedQso;

  const OperationView({super.key, required this.services, required this.operationUuid, this.openActivities = false, this.initialSuggestedQso});

  @override
  State<OperationView> createState() => _OperationViewState();
}

class _OperationViewState extends State<OperationView> with DockHost<OperationView>, _OperationDock, _OperationHeader, _OperationSheetHost, _OperationKeying {
  @override
  PanelRenderContext get panelRenderContext => PanelRenderContext(
    operation: _draftOperation ?? _operationForPanels,
    qso: _draftQso,
    qsoCount: _realQsoCountForTabs,
    spotsRevision: _spotsRevision,
    lookupRevision: _lookupRevision,
  );

  @override
  Operation? _operation;
  late bool _showRSTFields = widget.services.settings.showRSTFields;
  late bool _showStateField = widget.services.settings.showStateField;
  late bool _showGridField = widget.services.settings.showGridField;
  late bool _showDeletedQSOs = widget.services.settings.showDeletedQSOs;
  late bool _showQsoNumbers = widget.services.settings.showQsoNumbers;
  late String _defaultReport = widget.services.settings.defaultReport;
  late String _defaultReportCW = widget.services.settings.defaultReportCW;
  late String _defaultReportFT8 = widget.services.settings.defaultReportFT8;
  late bool _switchSentRcvd = widget.services.settings.switchSentRcvd;
  late bool _jumpAfterRST = widget.services.settings.jumpAfterRST;
  late DxFlags _dxFlags = widget.services.settings.dxFlags;

  /// Cached QSO stream. Recreating `watchForOperation` inside `build` would
  /// make a fresh drift query on every rebuild — a menu toggle, a
  /// controls arrival, an entity-prefix resolve, a rescore refresh
  /// — each tearing
  /// down and re-running the whole query. Keyed on `_showDeletedQSOs`, the
  /// only input that changes during the view's life (the uuid is fixed).
  Stream<List<Qso>>? _qsoStream;
  bool? _qsoStreamIncludesDeleted;

  Stream<List<Qso>> _qsosStream() {
    if (_qsoStream == null || _qsoStreamIncludesDeleted != _showDeletedQSOs) {
      _qsoStream = widget.services.qsos.watchForOperation(widget.operationUuid, includeDeleted: _showDeletedQSOs);
      _qsoStreamIncludesDeleted = _showDeletedQSOs;
    }
    return _qsoStream!;
  }

  /// The operation row, kept live by [OperationsRepository.watchOperation]
  /// rather than manually re-fetched after every mutating action.
  StreamSubscription<Operation?>? _operationSub;

  /// Drives live rescoring: any scoring-relevant QSO change reschedules a
  /// debounced rescore. See [_onQsosChanged].
  StreamSubscription<List<Qso>>? _rescoreSub;

  /// What the extension runtime says about this operation — see
  /// [OperationRuntimeState].
  @override
  late final _runtime = OperationRuntimeState(
    services: widget.services,
    currentOperation: () => _operation,
    controlsOperation: () => _draftOperation ?? _operation,
  )..addListener(_onRuntimeChanged);

  void _onRuntimeChanged() {
    if (mounted) setState(() {});
  }

  /// Whether [OperationView.openActivities] has fired — the operation stream
  /// re-emits on every change, and the pane must only auto-open once.
  bool _openedActivities = false;

  /// Whether THIS view has already auto-opened the sheet for the
  /// 'operation-sheet' onboarding flow — same one-shot guard as
  /// [_openedActivities], for the same reason: the operation stream re-emits
  /// on every change. Independent of [_openedActivities]: this fires for
  /// ANY operation, new or existing, the first time ever for this user;
  /// that one only fires for a freshly created operation.
  bool _openedOperationSheetOnboarding = false;

  /// [SpotsPanel.visible]'s host half. The panel ANDs it with its pane's own
  /// `DockPaneVisibility`, and in a dock that second half is the whole
  /// answer, so this one never goes false.
  final _spotsVisible = ValueNotifier(true);

  /// A QSON-shaped `{their: {call}, freq?, band?, mode?, refs?}` map handed
  /// from the Spots tab (tapping a spot — see `SpotsPanel.onSuggestQso`) to
  /// prefill the Logging tab's fields. Not cleared after being applied —
  /// `LoggingControls` only re-applies a suggestion when this becomes a NEW
  /// map instance (see its `suggestedQso` doc comment), so a stale
  /// reference here is harmless.
  Map<String, dynamic>? _suggestedQso;

  /// The current call-info, pushed up from LoggingControls — shown
  /// as the Call Info detail on the Info tab (wide) or a modal (narrow) — the
  /// producer (LoggingPanel) and the display (InformationPanel) are sibling
  /// panes.
  @override
  CallInfoData? _callInfo;

  /// The QSO picked for editing in the logging panel, for the Map pane.
  String? _selectedQsoUuid;

  /// Keep the pane subtrees' State alive when the layout flips between the
  /// narrow and the wide dock (docs/design/layouts.md): Flutter reparents a
  /// GlobalKey'd subtree instead of rebuilding it, so a half-typed callsign
  /// survives a window resize across the S/L boundary. Both classes are fed
  /// from the one build below — the keys are never mounted twice in a frame.
  ///
  /// Adoption only happens for subtrees BUILT in the new class's first
  /// frame, which a dock's are: it mounts every pane of a group, on top or
  /// not. A pane the new class's arrangement does not hold is disposed.
  final _loggingKey = GlobalKey();
  final _spotsKey = GlobalKey();
  final _mapKey = GlobalKey();

  /// [reveal] false fills the fields and leaves the operator where they are —
  /// what sliding a spot row open does. The spots list is the thing being
  /// worked in that gesture, and on a narrow window surfacing the logging
  /// panel would take it away mid-slide. A row TAP still reveals: there the
  /// operator has chosen the station and wants the fields.
  ///
  /// [measured] marks a suggestion that reports where this operator's own
  /// radio IS, rather than where someone else heard a station — a `/qso` deep
  /// link from a companion app. Avoid Zero-Beating exists to move off a
  /// SPOT's frequency, so applying it to a measured one would mistune the rig
  /// the link is describing, and would disagree with the VFO write the same
  /// link already made. Both entry points must pass the same value: the
  /// offset is a property of where the suggestion came from, never of whether
  /// the operation happened to be open when it arrived.
  void _suggestQso(Map<String, dynamic> qso, {bool reveal = true, bool measured = false}) {
    setState(() {
      _suggestedQso = measured ? qso : zeroBeatSuggestionFor(qso, services: widget.services, offsetter: _zeroBeat);
      // A slide peek is the one suggestion the operator has not committed to.
      _suggestedQsoIsTentative = !reveal;
    });
    // A tentative suggestion belongs to the open row, and the panel may hold
    // it back rather than overwrite work in progress — [_suggestionSettled]
    // is where that is put to the operator, once the gesture is over, and
    // [_withdrawSuggestedQso] is where it goes when the row closes.
    if (!reveal) return;
    // The operator may have tabbed the logging pane behind others, so
    // surface it (no-op when it's already on top).
    _revealLoggingPanel();
  }

  /// Takes back a suggestion a slide made — the row that made it has closed.
  /// Only ever a tentative one: a station the operator TAPPED (or typed) is
  /// theirs, and a slide closing somewhere else may not take it away.
  void _withdrawSuggestedQso(String? call) {
    // A row discarded while open withdraws AFTER the frame (see its
    // `dispose`), which is late enough for this view to have gone with it —
    // a whole operation closing takes both down together.
    if (!mounted || !_suggestedQsoIsTentative) return;
    // And late enough for the fields to belong to a different row by then, so
    // a withdrawal only ever takes back the station it put there.
    final suggested = (_suggestedQso?['their'] as Map?)?['call'] as String?;
    if (call != null && suggested != null && call.toUpperCase() != suggested.toUpperCase()) return;
    setState(() {
      _suggestedQso = null;
      _suggestedQsoIsTentative = false;
    });
  }

  /// Bumped when a slid row comes to rest open — see
  /// `LoggingSession.suggestionSettledSerial`.
  int _suggestionSettledSerial = 0;

  void _suggestionSettled() => setState(() => _suggestionSettledSerial++);

  /// Bumped when the operator works the call field themselves — see
  /// `SpotsPanel.closeSlidesSerial`.
  int _closeSlidesSerial = 0;

  void _onCallEdited() {
    // Typing on an on-screen keyboard reaches no HardwareKeyboard handler;
    // the call field changing is what says the operator is logging.
    _wakeHold.touch();
    setState(() => _closeSlidesSerial++);
  }

  /// The spots list's slid-right action, carrying the QSO it means to log —
  /// see `LoggingSession.logRequest`. The serial is what makes a repeat of
  /// the same spot a new request.
  ({int serial, Map<String, dynamic> qso})? _logRequest;

  /// Whether [_suggestedQso] came from a gesture the operator can still take
  /// back — see `LoggingSession.suggestedQsoIsTentative`.
  bool _suggestedQsoIsTentative = false;

  /// Log a spot outright, without surfacing the logging panel: the operator
  /// stays on the spots list and the contact is logged behind it.
  void _logQsoFromSpot(Map<String, dynamic> qso) {
    if (_operation?.deleted ?? false) return;
    final zeroBeat = zeroBeatSuggestionFor(qso, services: widget.services, offsetter: _zeroBeat);
    setState(() {
      _suggestedQso = zeroBeat;
      _logRequest = (serial: (_logRequest?.serial ?? 0) + 1, qso: zeroBeat);
    });
  }

  /// The logging panel has work a slid spot would destroy. Ask, rather than
  /// letting a gesture made on another surface throw it away — and on "go
  /// back", surface the panel so the operator lands on the thing they kept.
  Future<bool> _confirmLogOverwrite({required bool editing}) async {
    final t = context.t;
    final clear = await showHaloDialog<bool>(
      context: context,
      builder: (context) => HaloDialog(
        title: Text(t.operation.spots.logConflict.title),
        content: Text(editing ? t.operation.spots.logConflict.editingBody : t.operation.spots.logConflict.composingBody),
        cancel: TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(t.operation.spots.logConflict.goBack)),
        actions: [FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(t.operation.spots.logConflict.clearAndLog))],
      ),
    );
    if (clear == true) return true;
    // Kept what they had — so put them in front of it. Without this the
    // operator is left on the spots list wondering what their choice did.
    if (mounted) _revealLoggingPanel();
    return false;
  }

  /// Whether the first dock this view mounts still owes the logging pane a
  /// reveal, for the link that pushed the view with fields to fill. A dock
  /// opens on its STORED selection, which is shared by every operation: left
  /// on Spots anywhere, a phone would open this one on Spots too, with the
  /// link's callsign filled in behind it and nothing on screen to say so.
  late bool _revealLoggingOnMount = widget.initialSuggestedQso != null;

  /// This view's zero-beat draw cache — per view, because it is keyed by spot
  /// and only meaningful for the spots this operation is working. The rule it
  /// feeds is [zeroBeatSuggestionFor].
  final _zeroBeat = ZeroBeatOffsetter();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registerNativePanels();
  }

  void _onSettingsChanged() {
    final s = widget.services.settings;
    // Local mirrors of the logging panel's own toggles (see
    // _buildLoggingSettingsButton) — flipped from the settings dialog,
    // so this is the only place they follow SettingsService.
    final changed =
        s.showRSTFields != _showRSTFields ||
        s.showStateField != _showStateField ||
        s.showGridField != _showGridField ||
        s.showDeletedQSOs != _showDeletedQSOs ||
        s.showQsoNumbers != _showQsoNumbers ||
        s.defaultReport != _defaultReport ||
        s.defaultReportCW != _defaultReportCW ||
        s.defaultReportFT8 != _defaultReportFT8 ||
        s.switchSentRcvd != _switchSentRcvd ||
        s.jumpAfterRST != _jumpAfterRST ||
        s.dxFlags != _dxFlags;
    if (changed && mounted) {
      setState(() {
        _showRSTFields = s.showRSTFields;
        _showStateField = s.showStateField;
        _showGridField = s.showGridField;
        _showDeletedQSOs = s.showDeletedQSOs;
        _showQsoNumbers = s.showQsoNumbers;
        _defaultReport = s.defaultReport;
        _defaultReportCW = s.defaultReportCW;
        _defaultReportFT8 = s.defaultReportFT8;
        _switchSentRcvd = s.switchSentRcvd;
        _jumpAfterRST = s.jumpAfterRST;
        _dxFlags = s.dxFlags;
      });
    }
  }

  /// One per screen instance — see [PanelUseTracker].
  late final _panels = PanelUseTracker(track: widget.services.track, screen: 'operation');

  @override
  void initState() {
    super.initState();
    widget.services.track('screen_viewed', {'screen': 'operation'});
    widget.services.settings.addListener(_onSettingsChanged);
    // A ref-add's own refresh (`_onOperationChanged` below) can race a
    // runtime restart triggered by enabling the extension in the same
    // gesture — `refreshControls` sees `loadFailed` and, correctly,
    // keeps the stale controls rather than blanking the panel. Nothing then
    // retries, so the just-added contest's exchange field stays missing
    // until something unrelated (a callsign lookup) happens to refresh
    // after the restart settles. `runtimeGeneration` ticks once the runtime
    // is actually live again (extension_service.dart), which is the signal
    // to try once more.
    widget.services.extensions.runtimeGeneration.addListener(_onRuntimeGenerationChanged);
    _operationSub = widget.services.operations.watchOperation(widget.operationUuid).listen(_onOperationChanged);
    // Non-deleted, non-event set — the same QSOs the scorer sees. A
    // soft-delete/undelete changes this set (and each QSO's updatedAtMillis),
    // so the fingerprint below still moves.
    _rescoreSub = widget.services.qsos.watchForOperation(widget.operationUuid).listen(_onQsosChanged);
    // Feed the dev bridge (window.__halo.getState) the current operation +
    // compose state while this screen is active — only when the bridge was
    // actually installed (dev/preview build on web), so nothing runs in
    // production or on native.
    if (DevBridge.instance.installed) DevBridge.instance.stateProvider = _devBridgeState;
    // Claims this view's slot on the ⌘K command-context stack. Held by
    // identity so popping back from a nested operation reveals this one again
    // rather than leaving the palette context-less — see
    // HaLoServices.openOperationContext.
    _commandContext = widget.services.openOperationContext(widget.operationUuid);
    // Lets a `/qso` deep link prefill THIS operation while it is the
    // front-most one, without pushing a second copy of the view over it.
    // `measured` because only a deep link reaches this callback.
    _commandContext.suggestQso = (qso) => _suggestQso(qso, measured: true);
    // Whether the operator can actually SEE this operation — false with
    // Settings, or another operation, pushed over it. A suggestion delivered
    // to a view nobody is looking at is not lost, but it is invisible, and
    // the caller says so rather than leaving the link looking dead.
    _commandContext.isVisible = () => mounted && (ModalRoute.of(context)?.isCurrent ?? false);
    // The link that pushed this view. Set directly rather than through
    // `_suggestQso`: that one calls setState and reveals the logging panel,
    // neither of which is legal before the first build — the reveal waits for
    // the dock instead (see [_revealLoggingOnMount]). No zero-beat offset
    // here for the same reason `measured` skips it above.
    _suggestedQso = widget.initialSuggestedQso;
    // F1-F8 key CW messages while this operation is in front — see
    // [_onCwKeyEvent]. A HardwareKeyboard handler rather than a Shortcuts
    // widget, because the keys must work whichever field has focus, and the
    // main key handler (main.dart) only looks at modified chords.
    HardwareKeyboard.instance.addHandler(_onCwKeyEvent);
    widget.services.cat.pttKeys.addTarget(_pttTarget);
    // Opening the view is the first activity on it; every key, pointer
    // press, scroll, call edit and logged QSO after that refreshes the hold
    // (see [_onWakeKeyEvent], the Listener around the Scaffold and
    // [_onCallEdited]), and closing it lets go.
    _wakeHold.touch();
    HardwareKeyboard.instance.addHandler(_onWakeKeyEvent);
    // Keeps spots flowing, judged against this operation and its log (shown
    // to the board below, mounted Spots Panel or not), while it is open: the
    // `spot-history` lookup reads that cache from the logging panel alone, and
    // extension panels read the board through `getSpots`. Refcounted, so
    // closing every operation stops the fetching.
    _spotBoardView = widget.services.spotBoard.subscribe();
    widget.services.spotBoard.addListener(_onSpotsChanged);
  }

  /// This view's hold on the spot board, and how it says what it shows.
  late final SpotBoardSubscription _spotBoardView;

  /// Counts board changes rather than carrying the spots themselves: it
  /// exists only to fire an extension panel's `spots` trigger, and the
  /// panels that care read the board themselves.
  int _spotsRevision = 0;

  void _onSpotsChanged() {
    // Every other operation view would be rebuilding itself on every board
    // change for nothing.
    if (!mounted || !_anyPanelWants('spots')) return;
    setState(() => _spotsRevision++);
  }

  /// Whether this device is sharing its logging state with peers at all —
  /// the experiment, the master switch, and a holder to publish into.
  bool get _peerSharingDrafts =>
      widget.services.settings.experimentEnabled('p2p') /* stored key, see experiments.yaml */ && widget.services.settings.peerSyncEnabled;

  /// Publishes the composed contact to every peer sharing this operation.
  ///
  /// Deliberately NOT debounced the way [_onQsoDraftChanged] is. That
  /// debounce exists to coalesce a keystroke burst into one setState, which
  /// rebuilds three panes here; this one crosses a socket and rebuilds
  /// nothing locally, and the whole value of the panel on the other end is
  /// that it keeps up with the operator. The publisher upstream already
  /// fires at most once per frame per distinct draft.
  /// The header last sent, so a change to it can be noticed. Position and
  /// operator are attached HERE rather than inside the controls, so they are
  /// in neither of the publisher's dedupe keys — without this, running
  /// `POSITION 2` or `OPER` mid-contact moves nothing the publisher compares
  /// and every peer keeps rendering the old header until the next keystroke.
  (String, String)? _lastPeerHeader;

  /// Re-sends the block this device already published, under a header the
  /// operator has just changed. Cheap and rare: only a `POSITION`/`OPER`
  /// write reaches it, and it does nothing until one does.
  @override
  void _republishPeerHeaderIfChanged(Operation operation) {
    if (!_peerSharingDrafts) return;
    final drafts = widget.services.peerDrafts;
    final draft = drafts.localDraft;
    if (draft == null || draft.operationUuid != operation.uuid) return;
    final header = _peerHeaderFor(operation);
    if (header == _lastPeerHeader) return;
    _lastPeerHeader = header;
    drafts.publishLocal(
      PeerQsoDraftPayload(qso: draft.qso, operationUuid: draft.operationUuid, fields: draft.fields, position: header.$1, operatorCall: header.$2),
    );
  }

  /// Read fresh every time: the operator can set either from the command bar
  /// mid-contact, and a value captured once when the view mounted would name
  /// the wrong position for the rest of the session.
  (String, String) _peerHeaderFor(Operation operation) => (multiIdentifierFor(operation), operatorCallFor(operation));

  void _onPeerDraft(Operation operation, Map<String, dynamic> qso, List<PeerDraftField> fields) {
    final header = _peerHeaderFor(operation);
    _lastPeerHeader = header;
    widget.services.peerDrafts.publishLocal(
      PeerQsoDraftPayload(
        qso: qso,
        operationUuid: operation.uuid,
        fields: [for (final field in fields) PeerDraftFieldPayload(key: field.key, label: field.label, value: field.value, hint: field.hint)],
        position: header.$1,
        operatorCall: header.$2,
      ),
    );
  }

  /// The QSO being composed, republished from the logging panel for panels
  /// declaring `qso`. Null until one of them is in the arrangement — the
  /// render args then leave `qso` out entirely rather than sending `{}`.
  /// Once one is, this carries the draft even with an empty call: the band
  /// and mode come from the radio, and are worth showing before anything is
  /// typed.
  Map<String, dynamic>? _draftQso;
  Timer? _draftQsoDebounce;

  /// Coalesces the keystroke burst of typing a callsign into one rebuild.
  ///
  /// The panel's own [panelRenderThrottle] already bounds how often it may
  /// cross the bridge, but that is downstream of this view's setState — and
  /// the setState is the expensive half, rebuilding the logging, spots and
  /// map panes alongside the panel that asked. Debounced on the same window,
  /// so a panel sees one draft per pause rather than one per letter.
  void _onQsoDraftChanged(Map<String, dynamic> qso) {
    // Kept as it arrives, ahead of the debounce below: a CW message keyed
    // in the pause the debounce is waiting out must carry the call as typed,
    // not the last draft that settled.
    _latestDraftQso = qso;
    _draftQsoDebounce?.cancel();
    // The FIRST draft, carrying a call that resolved before anyone asked for
    // it — a `lookup` panel added to the layout while a callsign is already
    // in the field. Its `lookup` already fired against no draft at all, and
    // `_lookupAnsweredFor` holds that call, so nothing would fire again
    // until a DIFFERENT callsign resolved: the panel would sit on call-less
    // content indefinitely.
    if (_draftQso == null && (qso['their'] as Map?)?['guess'] != null) _flushDraft = true;
    if (_flushDraft) {
      // A lookup just resolved, and the guess it resolved to lives inside
      // this draft. Both are pushed from one post-frame callback — call-info
      // first, draft second — so waiting out the debounce here would fire
      // `lookup` against the draft from BEFORE the answer, and a panel
      // declaring only `lookup` would never see a later one.
      _flushDraft = false;
      setState(() {
        _draftQso = qso;
        // So a panel woken by `lookup` is woken for THIS draft. Without it
        // the first draft arrives as a `qso` change, which a lookup-only
        // panel does not listen for.
        _lookupRevision++;
      });
      return;
    }
    _draftQsoDebounce = Timer(panelRenderThrottle, () {
      if (!mounted) return;
      setState(() => _draftQso = qso);
    });
  }

  /// This view's own claim on the device staying awake — its own, so a
  /// second OperationView pushed over this one and popped again releases
  /// only its hold, not the one this view is still working under.
  late final WakeHold _wakeHold = widget.services.wakeLock.hold(WakeReason.logging);

  /// Typing counts as activity on the logging view — but only while this
  /// view is the front-most route. A dialog over it, or Settings pushed on
  /// top, owns the keyboard, and keys typed there are not logging. Never
  /// claims the key.
  bool _onWakeKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) _wakeHold.touch();
    return false;
  }

  /// Set when a lookup resolves, so the draft carrying its guess skips the
  /// debounce. Cleared by the next draft either way — a lookup that changes
  /// nothing about the draft must not leave the next keystroke unbuffered.
  bool _flushDraft = false;

  /// Bumped when a callsign RESOLVES, so `lookup` is a trigger about lookups
  /// rather than a second, slower `qso`. Carries no value into the render
  /// args: the resolved guess already travels inside the draft QSO.
  int _lookupRevision = 0;

  /// The call the current guess answers for — null while nothing has
  /// resolved. Cleared that way on every keystroke that drops the guess, so
  /// retyping the same call resolves afresh.
  String? _lookupAnsweredFor;

  /// This view's entry on the command-context stack.
  late final OperationCommandContext _commandContext;

  /// The snapshot `window.__halo.getState()` returns while an operation is open:
  /// the operation, the callsign being composed/edited and its lookup guess,
  /// and the current VFO. Kept JSON-able (maps/strings/nums) so it js-ifies.
  Map<String, dynamic> _devBridgeState() {
    final op = _operation;
    final info = _callInfo;
    return {
      'view': 'operation',
      'operation': op == null ? null : {'uuid': op.uuid, 'stationCall': op.stationCall, 'title': op.title, 'qsoCount': op.qsoCount},
      'call': info?.call,
      'editing': info?.isEditing ?? false,
      'guess': info?.guess,
      'vfo': widget.services.radio.vfoA.toJson(),
    };
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onCwKeyEvent);
    widget.services.cat.pttKeys.removeTarget(_pttTarget);
    HardwareKeyboard.instance.removeHandler(_onWakeKeyEvent);
    _wakeHold.release();
    widget.services.settings.removeListener(_onSettingsChanged);
    widget.services.extensions.runtimeGeneration.removeListener(_onRuntimeGenerationChanged);
    // Only clear if it's still ours — a newer OperationView may have taken over.
    if (DevBridge.instance.stateProvider == _devBridgeState) {
      DevBridge.instance.stateProvider = null;
    }
    // This device stops being a position in the operation it is leaving.
    // Nothing else says so: a peer learns a position is gone from its session
    // dropping, and this device's session is still up.
    widget.services.peerDrafts.clearLocalFor(widget.operationUuid);
    _operationSub?.cancel();
    _rescoreSub?.cancel();
    _runtime.dispose();
    _draftQsoDebounce?.cancel();
    _spotsVisible.dispose();
    _sheetHeaderLines.dispose();
    widget.services.closeOperationContext(_commandContext);
    _spotBoardView.cancel();
    widget.services.spotBoard.removeListener(_onSpotsChanged);
    // "Listen for other apps" stops routing captures here once this view
    // closes — but only if THIS operation is still the one receiving; a
    // second OperationView may have taken over already. Unconditional,
    // deliberately: gating this on `listenForOtherAppsEnabled` looks free
    // but isn't safe — turning the setting off does not clear
    // `receivingOperationUuid` (only starts/stops the sockets), so a stale
    // receiver would survive past this view's close and later silently
    // catch captures meant for whatever operation is open when listening
    // is turned back on. Constructing `inboundQsos` here costs a cheap
    // object and one listener registration — worth it for correctness.
    widget.services.inboundQsos.stopReceivingFor(widget.operationUuid);
    super.dispose();
  }

  /// Publishes this view's operation into its stack entry, so the ⌘K dialog's
  /// operation-scoped commands (SEED, NOTE, SPOT) have something to run
  /// against. Same map shape `logging_controls.dart` passes its own
  /// `interpretCommand` calls.
  void _setCommandContext(Operation? operation) {
    _commandContext.operation = operation == null ? null : {...operation.data, 'uuid': operation.uuid};
  }

  void _onOperationChanged(Operation? operation) {
    if (!mounted) return;
    final previous = _operation;
    var patched = operation;
    final pending = _pendingTitleFragments;
    if (patched != null && pending != null) {
      if (_sameTitleFragments(patched.titleFragments, pending)) {
        // The row's own cache has caught up (retitleOperation's write from
        // a PRIOR emission landed) — stop overriding, it's redundant now.
        _pendingTitleFragments = null;
      } else {
        patched = _withTitleSuggestion(patched, pending);
      }
    }
    setState(() => _operation = patched);
    _setCommandContext(patched);
    if (patched != null) _spotBoardView.show(patched, _runtime.latestQsos, logRevision: logFingerprintFor(_runtime.latestQsos));
    if (operation == null) return;
    widget.services.outlineGrid.prefetchFor(operation.refs); // kept on the device for the field

    // With no profile callsign yet (fresh install — no onboarding flow
    // exists), the callsign editor takes the Activities pane's place:
    // setting an identity comes first.
    if (widget.openActivities && !_openedActivities) {
      _openedActivities = true;
      // Also consumes the independent trigger below for THIS view: a new
      // operation is this view's to handle end to end, including the
      // case where operatorCall is still empty and only
      // the callsign prompt shows, never the sheet — that must stay exactly
      // as it is, not get a second, onboarding-driven attempt to reopen
      // something on a later re-emission of the operation stream.
      _openedOperationSheetOnboarding = true;
      final markOnboardingSeen = widget.services.settings.onboardingShownCount(OnboardingFlows.operationSheet) == 0;
      _afterPushTransition(() => _openActivitiesOrPromptForCallsign(operation, markOnboardingSeen: markOnboardingSeen));
    } else if (!_openedOperationSheetOnboarding && widget.services.settings.onboardingShownCount(OnboardingFlows.operationSheet) == 0) {
      // Independent of the new-operation auto-open above: the
      // FIRST operation this user ever opens — new or existing — shows the
      // sheet once, so it isn't a surprise the first time they go looking
      // for it on an operation that predates the sheet.
      _openedOperationSheetOnboarding = true;
      _afterPushTransition(() => _openActivitiesOrPromptForCallsign(operation, markOnboardingSeen: true));
    }

    _runtime.operationChanged(previous, operation);
  }

  void _onRuntimeGenerationChanged() => _runtime.runtimeRestarted();

  void _onQsosChanged(List<Qso> qsos) {
    _runtime.qsosChanged(qsos);
    if (_operation case final operation?) _spotBoardView.show(operation, qsos, logRevision: logFingerprintFor(qsos));
  }

  /// Tap on the info area while it shows the call info: on wide layouts the detail
  /// already lives on the Info tab, so just surface it; on narrow, open it as a
  /// modal (which re-reads the latest `_callInfo` on rebuild via the modal's
  /// own key, so live updates flow through while it's open).
  Future<void> _handleCallInfoTap(Operation operation) async {
    if (_revealInfoPane()) return;
    final info = _callInfo;
    if (info == null) return;
    await showModalPane<void>(
      context,
      title: info.call,
      closeLabel: context.t.common.close,
      // The panel is a ListView and scrolls itself; wrapped in the pane's own
      // scroll view it would sit in unbounded height and lay out blank.
      scrollable: false,
      builder: (_) => CallInfoPanel(
        operation: operation,
        services: widget.services,
        call: info.call,
        guess: info.guess,
        lookups: info.lookups,
        alertKeys: info.alertKeys,
        noticeKeys: info.noticeKeys,
        scoreSources: info.scoreSources,
        ourEntityPrefix: _runtime.ourEntityPrefix,
      ),
    );
  }

  /// Tap on a day header in the QSO list, or on the info area while it shows
  /// anything but the call info: the operation's own info — its stats and
  /// scoring, the counterpart to the call detail standing for the contact.
  /// Same two presentations as [_handleCallInfoTap], and the same consequence
  /// on wide: the Info pane shows what it shows, which is the call detail
  /// while one is being composed. The modal, which is this tap's own, is the
  /// stats unconditionally.
  Future<void> _handleOperationInfoTap(Operation operation, List<Qso> qsos) async {
    if (_revealInfoPane()) return;
    await showModalPane<void>(
      context,
      // The operation, the way the Call Info modal is titled with the call —
      // `InformationPanel` heads its own body "Operation Stats", so naming
      // the pane that too would say it twice.
      title: displayTitleFor(context, operation),
      closeLabel: context.t.common.close,
      // See the Call Info modal above — InformationPanel is a ListView too.
      scrollable: false,
      builder: (_) => InformationPanel(
        operation: operation,
        qsos: qsos,
        services: widget.services,
        ourEntityPrefix: _runtime.ourEntityPrefix,
        activityControls: _runtime.loggingControls,
      ),
    );
  }

  Future<void> _handleCommandAction(String action, [Map<String, dynamic>? params]) => runCommandAction(widget.services, action, params, context);

  @override
  Widget build(BuildContext context) {
    final current = _draftOperation ?? _operation;
    if (current == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    Operation operation = current;
    // While the sheet buffers ref edits, the row's cached titleSuggestion
    // still describes the SAVED refs — swap in the draft's freshly suggested
    // fragments so the header retitles as activities are picked, not on Save.
    if (_draftOperation != null && _draftTitleFragments != null) {
      operation = _withTitleSuggestion(operation, _draftTitleFragments!);
    }

    return StreamBuilder<List<Qso>>(
      stream: _qsosStream(),
      builder: (context, snapshot) {
        final qsos = snapshot.data ?? const <Qso>[];
        // Start/break/end markers ride the same list (for QsoList to render
        // them inline) but aren't real contacts — every QSO *count* shown to
        // the user excludes them, matching scoring/export.
        final realQsoCount = qsos.where((q) => q.isRealContact).length;
        final headerLines = _headerTitleLines(context, operation);
        // The only thing that tells the sheet's copy of the trailing
        // controls that the title moved under it — see [_sheetHeaderLines].
        if (_activeSheetKey != null && _sheetHeaderLines.value != headerLines) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _activeSheetKey != null) _sheetHeaderLines.value = headerLines;
          });
        }

        final isTwoPane = ShirtSize.of(context).isTwoPane;
        // Which arrangement the dock draws — assigned before anything below
        // reads the mixin's spec, options or state, all of which resolve
        // through it.
        dockLayoutClass = isTwoPane ? DockLayoutClass.wide : DockLayoutClass.narrow;

        if (_revealLoggingOnMount) {
          _revealLoggingOnMount = false;
          // After the frame: the dock this build mounts has no State until then.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _revealLoggingPanel();
          });
        }

        // Edit mode as the HEADER sees it: the operation's own title and
        // setup route give way to the view's name and its layout options.
        final editingHeader = layoutEditing;

        // The pane subtrees, built once and placed by whichever dock class is
        // active (their GlobalKeys carry the State across a flip).
        // The Listeners below sit INSIDE each KeyedSubtree so the keys still
        // wrap the same subtree they always did — the reparenting between
        // classes depends on that. They only observe: pointer-down does not
        // compete for the gesture or change hit testing.
        final loggingPanel = KeyedSubtree(
          key: _loggingKey,
          child: Listener(
            onPointerDown: (_) => _panels.used('logging'),
            child: ReadOnlyWhileDeleted(
              operation: operation,
              onUndelete: () => _undelete(operation),
              child: LoggingPanel(
                operation: operation,
                services: widget.services,
                onSendCwMessage: _sendCwMessageFromArea,
                onEnterSends: _sendEsmMessages,
                cwTemplateContext: panelRenderContext,
                keyingPhone: _keyingPhone,
                qsos: qsos,
                loggingControls: _runtime.loggingControls,
                onCommandAction: _handleCommandAction,
                showRSTFields: _showRSTFields,
                showStateField: _showStateField,
                showGridField: _showGridField,
                showQsoNumbers: _showQsoNumbers,
                defaultReport: _defaultReport,
                defaultReportCW: _defaultReportCW,
                defaultReportFT8: _defaultReportFT8,
                switchSentRcvd: _switchSentRcvd,
                jumpAfterRST: _jumpAfterRST,
                dxFlags: _dxFlags,
                ourEntityPrefix: _runtime.ourEntityPrefix,
                ourItuRegion: _runtime.ourItuRegion,
                ourCountryCode: _runtime.ourCountryCode,
                suggestedQso: _suggestedQso,
                suggestedQsoIsTentative: _suggestedQsoIsTentative,
                suggestionSettledSerial: _suggestionSettledSerial,
                onCallEdited: _onCallEdited,
                onQsoLogged: _wakeHold.touch,
                // Gated like the drafts: with sharing off the panel's own fallback
                // is the same answer, and touching the field would construct the
                // peer service on an install that never turned the experiment on.
                serialNumbers: _peerSharingDrafts ? widget.services.serialClaims : null,
                logRequest: _logRequest,
                confirmLogOverwrite: _confirmLogOverwrite,
                onSelectionChanged: (uuid) => setState(() => _selectedQsoUuid = uuid),
                onCallInfoChanged: (info) {
                  // Entering a call is logging-panel use, and it is the one
                  // interaction the pointer listener below cannot see: the call
                  // field is autofocused, so an operator who just types never
                  // puts a pointer down inside the panel. Hooking this existing
                  // callback keeps key handling out of it — the focus ladder is
                  // a contract (docs/design/logging-fields.md), and a
                  // panel-wide key listener is exactly what it forbids.
                  _panels.used('logging');
                  // A callsign being ANSWERED FOR is what `lookup` is about, and
                  // this callback also fires for every letter typed. Keyed on
                  // which call has an answer, so typing K→KI→KI2 fires nothing
                  // and KI2D resolving fires once. Not an identity check on the
                  // guess map: editing a QSO rebuilds it on every call, which
                  // would make this per-keystroke after all.
                  //
                  // A LATER source answering the same call is not seen here: the
                  // callback upstream dedupes on a signature holding the guess's
                  // display fields, so a second lookup that only adds others
                  // never reaches this. Widening it would re-render the Info
                  // pane for the same fields it is already showing.
                  // A NULL info says the call-info area isn't showing — a command
                  // message has the space — which is not news about lookups.
                  // Forgetting here would fire `lookup` a second time for the
                  // same already-resolved call the moment the message clears.
                  var resolved = false;
                  if (info != null) {
                    final answeredFor = info.guess == null ? null : info.call;
                    resolved = answeredFor != null && answeredFor != _lookupAnsweredFor;
                    _lookupAnsweredFor = answeredFor;
                  }
                  if (resolved) _flushDraft = true;
                  setState(() {
                    _callInfo = info;
                    if (resolved) _lookupRevision++;
                  });
                },
                // Null unless a panel in this arrangement asked for something
                // that lives in the draft: the draft is rebuilt and deep-compared
                // on every keystroke to produce, so the only cheap version of it
                // is the one nobody asked for.
                //
                // `lookup` counts. Its payload IS the draft — a resolved guess
                // travels inside `their.guess` and nowhere else — so a panel
                // declaring only `lookup` would otherwise be woken with no
                // callsign at all, forever. What `lookup` buys over `qso` is
                // renders, not this.
                //
                // A CW message counts too: `{{ qso.call }}` in one is rendered
                // against this draft (`_sendCwMessage`), and with nothing else
                // asking for it F1 would key the message with the call blank.
                // And the voice keyer: its MODE is the draft's (`_keyingPhone`),
                // so with nothing tracking the draft F1 in SSB would fall
                // through to a CW keyer that keys nothing, silently.
                onQsoChanged: _anyPanelWants('qso') || _anyPanelWants('lookup') || _cwMessagesConfigured || _phoneKeyingPossible ? _onQsoDraftChanged : null,
                // Peer sharing is its own reason to publish, independent of the
                // layout: the panel that reads this lives on ANOTHER device, so
                // gating it on what a panel here declares would leave a position
                // invisible to its peers whenever nothing local happened to want
                // a draft. Null while sharing is off, which is what keeps the
                // whole path off the keystroke route.
                onPeerDraftChanged: _peerSharingDrafts ? (qso, fields) => _onPeerDraft(operation, qso, fields) : null,
                onCallInfoTap: () => _handleCallInfoTap(operation),
                onOperationInfoTap: () => _handleOperationInfoTap(operation, qsos),
              ),
            ),
          ),
        );
        final spotsPanel = KeyedSubtree(
          key: _spotsKey,
          child: Listener(
            onPointerDown: (_) => _panels.used('spots'),
            child: _LazyTab(
              child: SpotsPanel(
                operation: operation,
                services: widget.services,
                onSuggestQso: _suggestQso,
                onWithdrawSuggestion: _withdrawSuggestedQso,
                onSuggestionSettled: _suggestionSettled,
                closeSlidesSerial: _closeSlidesSerial,
                onLogQso: _logQsoFromSpot,
                logRevision: logFingerprintFor(qsos),
                qsos: qsos,
                // Same payload the map panel highlights from, so the two panes
                // agree on which station is being worked and on the
                // new-vs-editing accent that says so.
                callInfo: _callInfo,
                visible: _spotsVisible,
              ),
            ),
          ),
        );
        final mapPanel = KeyedSubtree(
          key: _mapKey,
          child: Listener(
            onPointerDown: (_) => _panels.used('map'),
            child: _LazyTab(
              // Stretches to the split's very edge: the divider overlay's
              // near-invisible wash (see resizable_split_view.dart) is what
              // keeps the native map view from stealing drags on the strip.
              child: MapPanel(
                operation: operation,
                qsos: qsos,
                settings: widget.services.settings,
                callInfo: _callInfo,
                selectedQsoUuid: _selectedQsoUuid,
                geoshapes: widget.services.geoshapes,
                activityControls: _runtime.mapControls,
                offersPostcard: true,
                deviceGrid: widget.services.location.grid,
              ),
            ),
          ),
        );
        final infoPanel = Listener(
          onPointerDown: (_) => _panels.used('info'),
          child: InformationPanel(
            operation: operation,
            qsos: qsos,
            services: widget.services,
            callInfo: _callInfo,
            ourEntityPrefix: _runtime.ourEntityPrefix,
            activityControls: _runtime.loggingControls,
          ),
        );
        // Observes only: a pointer press or a scroll anywhere on the view is
        // activity for the awake hold, and this neither competes for the
        // gesture nor changes hit testing.
        return Listener(
          onPointerDown: (_) => _wakeHold.touch(),
          onPointerSignal: (_) => _wakeHold.touch(),
          child: Scaffold(
            // The body extends full height behind the on-screen keyboard, so
            // each pane paints its own background there (and a two-pane split
            // reflects for free). The logging panel keeps its fields above the
            // keyboard with its own bottom spacer (see LoggingControls); the
            // Quick Lookup / branding panes do the same on Home.
            resizeToAvoidBottomInset: false,
            appBar: _headerAppBar(context, operation: operation, isTwoPane: isTwoPane, editingHeader: editingHeader, headerLines: headerLines),
            body: AdifDropTarget(
              // Wraps the whole body so a log file can be dropped anywhere on
              // the operation, not onto some particular panel — the operator is
              // dropping it "into this operation", and which pane happened to be
              // under the cursor is not a distinction they are making.
              onFile: (file) async {
                if (operation.deleted) return;
                await importAdifFile(context, services: widget.services, operation: operation, file: file);
              },
              child: PaneSafeArea.root(
                context,
                // Real device safe-area insets (notch, home indicator) bubble
                // in from here; PaneSafeArea's own
                // divider-clearance role composes with it further down.
                child: withViewOverrides(
                  _dockLayout(
                    loggingPanel: loggingPanel,
                    infoPanel: infoPanel,
                    spotsPanel: spotsPanel,
                    mapPanel: mapPanel,
                    realQsoCount: realQsoCount,
                    qsos: qsos,
                    operation: operation,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// [qso] with a CW frequency moved a few Hz off the spotted one, so that
/// everyone answering the same spot isn't transmitting on the same note
/// (services/cat/zero_beat.dart).
///
/// Resolved from [services] here, at the one place every suggestion passes
/// through that can see both the settings and the CAT state — halo_widgets is
/// a package below the app and reaches neither. Offsetting once, at the
/// source, is also what keeps the frequency field, the logged QSO and the VFO
/// showing the same number: everything downstream reads this one value.
///
/// A top-level function rather than a method so a test can pin the joints
/// that fail silently — that `enabled` reads `settings.avoidZeroBeat`, that
/// the range reaches the draw, and that "connected" means radio1 rather than
/// any node in the shack.
///
/// Returns the caller's own map untouched when nothing should move, and a
/// copy when something does — the map it is handed belongs to the spot list
/// either way, so neither is safe to mutate.
Map<String, dynamic> zeroBeatSuggestionFor(Map<String, dynamic> qso, {required HaLoServices services, required ZeroBeatOffsetter offsetter}) {
  final settings = services.settings;
  // Checked before `services.cat`, which is what keeps it untouched: that
  // getter is a `late final`, so reading it builds a CatService — registry,
  // stored equipment, a RadioService listener held for the process — and
  // this runs on every spot tap.
  if (!settings.avoidZeroBeat) return qso;
  // The main VFO specifically — a rig connected in the shack but not driving
  // the panel is not going to be retuned by this suggestion either. A PEER's
  // rig is: an operator's move reaches it as `catSet`, so leaving it out
  // would tune it exactly zero beat, which is what this prevents.
  return offsetter.apply(qso, enabled: true, radioConnected: services.radio1IsLive, rangeHz: settings.zeroBeatRangeHz);
}
