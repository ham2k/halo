// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The QSO entry controls — the hottest path in the whole app. Keyboard
// ergonomics are the contract (DESIGN.md §7), ported from app-polo:
//   Enter   logs the QSO from anywhere in the controls
//   Esc     wipes the current entry (same as the wipe button, undo included)
//   Space   in the call field: runs command shortcuts (frequency, band,
//           mode — "14285 ", "20m ", "cw ") or advances to Sent;
//           in Sent/Rcvd: advances focus, cycling back to the call
//   focus   always returns to the callsign field after log/wipe;
//           every field places the cursor at the end on focus, never
//           selecting the existing text
//
// Frequency/band/mode and the QSO timestamp live behind the secondary
// control row (see secondary_control_row.dart) rather than as
// permanently-visible fields — this is app-polo's SecondaryExchangePanel
// pattern: a chip always shows a compact summary of the control's current
// value ("20m • SSB", a live-ticking "17:06:49z" clock), and tapping it
// expands the actual editable fields. This is what lets extensions keep
// contributing controls (POTA's park reference today, more activities
// later) without the controls' permanent footprint growing — only one
// control is expanded at a time. Command shortcuts still work while a
// control is collapsed, since they mutate the same underlying state the
// expanded fields edit.
//
// Everything here is pure Dart/Flutter; extensions only get debounced,
// async involvement (lookups, ref decoration) off the keystroke path.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';

import 'call_field_text.dart';
import 'call_info_summary.dart';
import 'key_bindings.dart';
import 'keyboard_accessory.dart';
import 'keyboard_dismiss.dart';
import 'logging_controls_catalog.dart';
import 'logging_controls_command.dart';
import 'logging_controls_controller.dart';
import 'logging_controls_draft.dart';
import 'logging_controls_entry_row.dart';
import 'logging_controls_event_row.dart';
import 'logging_controls_exchange.dart';
import 'logging_controls_info_frame.dart';
import 'logging_controls_ladder.dart';
import 'logging_controls_focus.dart';
import 'logging_controls_lookup.dart';
import 'logging_controls_radio.dart';
import 'logging_controls_refs.dart';
import 'logging_controls_esm.dart';
import 'logging_controls_metrics.dart';
import 'logging_controls_spotting.dart';
import 'logging_controls_time.dart';
import 'logging_controls_types.dart';
import 'logging_info_area.dart';
import 'mdi_icons.g.dart';
import 'platform_chrome.dart';
import 'qso_edit_pane.dart';
import 'rebuild_between_frames.dart';
import 'resizable_split_view.dart' show PaneSafeArea;
import 'semantic_id.dart';
import 'secondary_control_row.dart';
import 'spacing.dart';
import 'text_formatters.dart';
import 'theme.dart';
import 'wall_clock.dart';

part 'logging_controls_call_info.dart';
part 'logging_controls_dispatch.dart';
part 'logging_controls_fields.dart';
part 'logging_controls_keys.dart';
part 'logging_controls_strip.dart';
part 'logging_controls_submit.dart';
part 'logging_controls_updates.dart';
part 'logging_controls_wipe.dart';

/// The logging panel: the entry row, the information area and the secondary
/// control strip. Wired up through ten groups, one per concern — the log it
/// writes to and reads ([LogHooks]), what the app is doing with it right now
/// ([LoggingSession]), the rig it mirrors ([RadioHookup]), where it learns
/// about a callsign ([LookupHooks]), the activities' controls
/// ([ActivityHooks]), the command shortcuts ([CommandHooks]), the strip as
/// the operator arranged it ([ControlStripSettings]), the spotting networks
/// ([SpottingHooks]), the operator's preferences ([LoggingPreferences]) and
/// manual time entry ([ManualTimeHooks]). Only the log is required; a caller
/// names the groups it has something to say about.
class LoggingControls extends StatefulWidget {
  /// See [LogHooks].
  final LogHooks log;

  /// See [LoggingSession].
  final LoggingSession session;

  /// See [RadioHookup].
  final RadioHookup radio;

  /// See [LookupHooks].
  final LookupHooks lookups;

  /// See [ActivityHooks].
  final ActivityHooks activities;

  /// See [CommandHooks].
  final CommandHooks commands;

  /// See [ControlStripSettings].
  final ControlStripSettings strip;

  /// See [SpottingHooks].
  final SpottingHooks spotting;

  /// See [LoggingPreferences].
  final LoggingPreferences prefs;

  /// See [ManualTimeHooks].
  final ManualTimeHooks manualTime;

  const LoggingControls({
    super.key,
    required this.log,
    this.session = const LoggingSession(),
    this.radio = const RadioHookup(),
    this.lookups = const LookupHooks(),
    this.activities = const ActivityHooks(),
    this.commands = const CommandHooks(),
    this.strip = const ControlStripSettings(),
    this.spotting = const SpottingHooks(),
    this.prefs = const LoggingPreferences(),
    this.manualTime = const ManualTimeHooks(),
  });

  @override
  State<LoggingControls> createState() => _LoggingControlsState();
}

class _LoggingControlsState extends State<LoggingControls> with WidgetsBindingObserver, RebuildsBetweenFrames {
  final _callController = TextEditingController();

  /// The Radio control's state — frequency, band and mode, the Band/Mode
  /// dropdowns, and the VFO mirror. See [RadioControlModel]; what stays here
  /// is when it moves and what moves with it.
  late final RadioControlModel _radio = RadioControlModel(
    config: () => (radio: widget.radio, powerInPlay: () => _powerInPlay, editingQso: widget.session.editingQso),
    draft: _draft,
    onRescore: _lookup.scheduleScore,
  );
  final _sentController = TextEditingController();
  final _rcvdController = TextEditingController();
  final _gridController = TextEditingController();
  final _stateController = TextEditingController();
  // NOTE/TODO's inline editor — the only event kinds with editable free
  // text. Populated in `_populateFromEditingQso`, read back in
  // `_eventDataForSave`.
  final _eventTextController = TextEditingController();
  final _eventTextFocus = FocusNode();
  bool _eventTodoDone = false;
  final _callFocus = FocusNode();
  final _sentFocus = FocusNode();
  final _rcvdFocus = FocusNode();
  final _gridFocus = FocusNode();
  final _stateFocus = FocusNode();

  /// Which secondary control (if any) currently has its input expanded.
  String? _selectedControlKey;

  /// The callsign lookup, the worked-before answer and the live score for the
  /// call at the cursor — see [CallLookupModel]. What stays here is what a
  /// resolved lookup does to the entry ([_onLookupResolved]) and when the
  /// whole thing is forgotten.
  late final _lookup = CallLookupModel(
    config: () => (
      lookup: widget.lookups.lookup,
      workedBefore: widget.lookups.workedBefore,
      scoreQso: widget.lookups.scoreQso,
      editingQso: widget.session.editingQso,
      operation: widget.log.operation,
    ),
    activeCall: () => _callAtCursor,
    isCallInfoActive: () => _callInfoActive,
    qsoData: (call) => _draft.toData(callOverride: call),
    segmented: () => _segmented,
    onResolved: _onLookupResolved,
    // A stale QSO-scoped placeholder/transform must not linger onto the next
    // entry — see [ActivityRefsModel.controlsChanged].
    onCleared: () => _refs.controlsChanged(),
  );

  /// The command being typed into the call field — see
  /// [CommandInterpretationModel], which also decides what Enter does with
  /// it ([CommandInterpretationModel.runOnEnter]). Dispatching the actions
  /// is still this panel's ([_dispatchActions]), and so is the field's own
  /// reading ([_callText]).
  late final _command = CommandInterpretationModel(
    config: () => (
      interpretCommand: widget.commands.interpretCommand,
      editingQso: widget.session.editingQso,
      operationData: () => _operationDataForCommands,
      onMessageChanged: widget.commands.onCommandMessageChanged,
    ),
    callText: () => _callText,
    qsoData: _draft.toData,
  );

  /// The Time control — when the entry is stamped. See [TimeControlModel].
  late final TimeControlModel _time = TimeControlModel(config: () => (editingQso: widget.session.editingQso, manualTime: widget.manualTime), draft: _draft);

  /// The contest exchange fields — see [ExchangeFieldsModel]. What stays
  /// here is WHICH controls are exchange fields ([_textControls]), and when
  /// the draft they belong to is cleared, restored or logged.
  late final _exchange = ExchangeFieldsModel(
    config: () => (
      textControls: () => _textControls,
      editingQso: widget.session.editingQso,
      operationUuid: widget.log.operation.uuid,
      serialNumbers: widget.log.serialNumbers,
      sequences: widget.log.qsosRepository.sequences,
      call: _call,
      menuBelow: widget.prefs.aboveLog,
    ),
    draftQsoData: _draft.toData,
    onPrimaryFieldKeyEvent: _ladder.onPrimaryFieldKeyEvent,
    onFocusChanged: _onExchangeFocusChanged,
    onEdited: _lookup.exchangeEdited,
  );

  /// The activity refs and the controls they belong to — see
  /// [ActivityRefsModel]. What stays here is which of those controls are
  /// PRIMARY fields ([_textControls]), and when the draft is cleared,
  /// restored or logged.
  late final ActivityRefsModel _refs = ActivityRefsModel(
    config: () => (
      activityControls: widget.activities.activityControls,
      refreshActivityControls: widget.activities.refreshActivityControls,
      editingQso: widget.session.editingQso,
      fieldsLocked: () => _fieldsLocked,
      callAtCursor: () => _callAtCursor,
    ),
    draft: _draft,
    draftQsoData: (call) => _draft.toData(callOverride: call),
    onControlsRefreshed: _onActivityControlsRefreshed,
  );

  /// The QSO being composed or edited, beyond what the fields hold — see
  /// [QsoDraft]. The fields' controllers are this panel's; the draft reads
  /// and writes them through its configuration.
  late final QsoDraft _draft = QsoDraft(
    config: () => (
      operation: widget.log.operation,
      editingQso: widget.session.editingQso,
      callController: _callController,
      sentController: _sentController,
      rcvdController: _rcvdController,
      gridController: _gridController,
      stateController: _stateController,
      notesController: _notesController,
      radio: _radio,
      time: _time,
      exchange: _exchange,
      refs: _refs,
      lookup: _lookup,
      call: _call,
      rstOrDefault: _rstOrDefault,
      hasRadioService: widget.radio.radioService != null,
    ),
  );

  /// The Spotting control — see [SpottingControlModel].
  late final _spotting = SpottingControlModel(
    config: () => (
      sendSpot: widget.spotting.sendSpot,
      suggestSpotSources: widget.spotting.suggestSpotSources,
      radioService: widget.radio.radioService,
      editingQso: widget.session.editingQso,
      operation: widget.log.operation,
      notice: _command.showError,
      respotInterval: widget.spotting.respotInterval,
      autoRespotByDefault: widget.spotting.autoRespotByDefault,
      pulseBeforeRespot: widget.spotting.pulseBeforeRespot,
      onOpenSettings: widget.spotting.onOpenSettings,
    ),
  );

  /// The focus ladder — see [LoggingFocusLadder]. The panel hands it the row
  /// and each control's fields, and keeps opening a control for itself.
  late final LoggingFocusLadder _ladder = LoggingFocusLadder(
    config: () => (
      primaryFields: () => _primaryFields,
      expandedFocusFor: _expandedFocusFor,
      expandedFieldOrderFor: _expandedFieldOrderFor,
      selectedControlKey: _selectedControlKey,
      fieldsLocked: () => _fieldsLocked,
      editingEvent: _editingEvent,
      eventTextFocus: _eventTextFocus,
      callFocus: _callFocus,
      navigateToQsoList: widget.session.onNavigateToQsoList,
      walkQsoList: widget.session.onWalkQsoList,
      aboveLog: widget.prefs.aboveLog,
    ),
    selectControl: _onSelectControl,
    showControl: _showControl,
  );

  /// The call for which ESM's first step has gone out — the station called,
  /// or the caller given their exchange — so the next Enter completes the
  /// contact. Compared against the call in the field, so a corrected call is
  /// a new contact one Enter from its own first step; forgotten by the wipe
  /// and by an emptied call field ([_onCallChanged]).
  String? _esmAnsweredCall;

  /// Completed by the log an ESM step handed off to — see [EnterSends.send].
  Completer<Map<String, dynamic>?>? _esmLogged;

  /// What [LoggingSession.onEsmFacts] last heard — starting with nothing, so
  /// the first publish always goes out.
  EsmFacts? _publishedEsmFacts;
  bool _esmFactsPublished = false;
  bool _esmFactsScheduled = false;

  /// Tells the app what the next Enter would hand ESM, when that changed.
  /// Null for an Enter that stops before ESM in [_log]: a locked form, an
  /// edit, a command, the band-or-frequency refusal.
  ///
  /// Read in a microtask, once per burst of changes: the call field
  /// notifies first in a populate or a caret move, and the exchange values
  /// written after it notify nobody, so a reading taken at the notification
  /// would describe an entry half-written.
  void _publishEsmFacts() {
    if (_esmFactsScheduled || widget.session.onEsmFacts == null) return;
    _esmFactsScheduled = true;
    scheduleMicrotask(() {
      _esmFactsScheduled = false;
      final publish = widget.session.onEsmFacts;
      if (publish == null || !mounted) return;
      final facts =
          _writeRefusal != null || widget.session.editingQso != null || _command.hasExecutableCommand || (_canLog && _radio.freq == null && _radio.band == null)
          ? null
          : _esmFacts;
      if (_esmFactsPublished && facts == _publishedEsmFacts) return;
      _esmFactsPublished = true;
      _publishedEsmFacts = facts;
      publish(facts);
    });
  }

  /// Set while editing an existing QSO and Delete has been tapped but not
  /// yet saved — mirrors app-polo's `_willBeDeleted` staged-delete flag.
  bool _pendingDelete = false;

  /// The guessed-ref provenance parked beside each of the draft's own two
  /// parking slots: the wipe's undo, and the detour through an earlier
  /// contact. See [ActivityRefsModel.takeGuessSnapshot] for why the draft
  /// cannot carry this itself.
  GuessProvenance? _undoGuesses;
  GuessProvenance? _composingGuesses;

  /// Why this operation may not be written right now, or null when it may —
  /// a travelled clock over a non-test operation today, a shared operation
  /// this device only reads later (`WritePolicy`).
  ///
  /// Live rather than cached: the answer changes when the clock does, and
  /// `ClockTravel` is what rebuilds this widget when it happens.
  WriteRefused? get _writeRefusal => WritePolicy.forOperation(widget.log.operation);

  /// Travel started or ended, so whether this operation is writable may have
  /// changed. Guarded on `mounted` because `ClockTravel` is a process-wide
  /// singleton and the notification can land mid-teardown.
  void _onClockTravelChanged() {
    if (mounted) setState(() {});
    _publishEsmFacts();
  }

  /// Whether the form is a read-only view: a staged delete, an
  /// already-deleted QSO awaiting restore (ham2k/halo-dist#59), or an
  /// operation that may not be written at all. Every input path — fields,
  /// save, keyboard shortcuts — must consult this, not `_pendingDelete`
  /// alone.
  ///
  /// The write policy belongs HERE rather than at the two `qsosRepository`
  /// calls: those throw, which tells the operator after the fact that the
  /// contact they typed did not land. Locking the form means it was never
  /// typeable, which is the difference between a refusal and a lost contact.
  bool get _fieldsLocked => _pendingDelete || (widget.session.editingQso?.deleted ?? false) || _writeRefusal != null;

  /// The default-focus rule's backstop (docs/design/logging-fields.md
  /// § Which field has focus), which owns the panel's Tab-trapping scope.
  late final _focusBackstop = DefaultFocusBackstop(
    target: () => _editingEvent ? _eventTextFocus : _callFocus,
    // `isCurrentOf`, not `of`: the latter would have every change to the
    // route's status rebuild the panel, not just push and pop over it.
    routeIsCurrent: () => ModalRoute.isCurrentOf(context) != false,
  );

  /// Editing an event/annotation row (NOTE, TODO, BREAK, …) rather than a
  /// contact — the main fields swap for [EventFieldRow], built from the
  /// same field primitives so the row's shape doesn't change, and every
  /// secondary control but Time is disabled (not hidden — see
  /// `SecondaryControlSpec.enabled`), since nothing else applies to a
  /// non-contact row.
  bool get _editingEvent => widget.session.editingQso?.isEvent ?? false;

  /// The Notes control's field. The value itself lives in
  /// [QsoDraft.extra] under `notes`, which is where the More pane reads
  /// and writes it and how it round-trips through [_applyFieldsFromData] — this
  /// controller is a second view onto that one value, not a second copy of
  /// it, so the two surfaces can never disagree about what the contact says.
  final _notesController = TextEditingController();
  final _notesFocus = FocusNode();

  /// Guards against double-logging: Enter is bound both as a keyboard
  /// shortcut and as every field's onSubmitted, and can also auto-repeat.
  bool _isLogging = false;

  /// The submit button's rendered diameter, measured post-frame (its own
  /// size comes from IntrinsicHeight/AspectRatio further down the tree, so
  /// it isn't known until after layout) and reused to size the info row's
  /// second button identically — see _buildWipeOrEditButton.
  final GlobalKey _submitButtonKey = GlobalKey();
  double? _editButtonDiameter;

  /// Prepended to each primary field's formatters so a space typed on an
  /// on-screen keyboard rotates focus / runs a command like the hardware Space
  /// shortcut does — see [VirtualSpaceFormatter]. One shared instance, built
  /// once, so the [_handleSpace] tear-off it holds is never compared.
  late final VirtualSpaceFormatter _virtualSpace = VirtualSpaceFormatter(_handleSpace);

  /// The call field's variant for command free-text mode, where a space is a
  /// parameter character rather than "next field". Without it that mode has no
  /// on-screen-keyboard exit at all: the hardware Space shortcut never fires
  /// for a virtual keyboard, so the double-space would just type a second
  /// literal space and the operator would be stuck in the field.
  late final VirtualSpaceFormatter _commandVirtualSpace = VirtualSpaceFormatter(
    _handleSpace,
    shouldIntercept: (old) => old.text.endsWith(' ') && old.selection.isCollapsed && old.selection.baseOffset == old.text.length,
    onPeriodShortcut: _exitOnPeriodShortcut,
  );

  @override
  void initState() {
    super.initState();
    // Publish the dispatcher while this panel is live, so a command run from
    // the ⌘K dialog lands on THIS logging panel's state.
    widget.commands.onDispatcherChanged?.call(_dispatchActions);
    _focusBackstop.attach();
    FocusManager.instance.addListener(_rebuildForNumbersRow);
    // Observe metrics so the numbers row appears/disappears with the on-screen
    // keyboard — MediaQuery can't tell us (Scaffold strips the inset, see
    // `virtualKeyboardIsUp`), so `didChangeMetrics` is the rebuild trigger.
    WidgetsBinding.instance.addObserver(this);
    // `_writeRefusal` is derived from the clock, which moves without anything
    // here changing. Without this the panel stays typeable after DEVTT until
    // some unrelated rebuild happens to notice — and stays locked after the
    // clock comes back.
    ClockTravel.instance.addListener(_onClockTravelChanged);
    _radio.addListener(_onModelChanged);
    _lookup.addListener(_onModelChanged);
    _command.addListener(_onModelChanged);
    _time.addListener(_onModelChanged);
    _spotting.addListener(_onModelChanged);
    _exchange.addListener(_onModelChanged);
    _refs.addListener(_onModelChanged);
    // Population normally happens in didUpdateWidget, as editingQso
    // transitions from null to a selected QSO — but if this widget is ever
    // constructed with editingQso already set (rather than transitioning
    // into it), that transition never fires. Applying it here too, before
    // any listeners are attached below, covers that case for free with no
    // risk of triggering their side effects.
    if (widget.session.editingQso != null) {
      _applyFieldsFromData(widget.session.editingQso!.data);
      if (widget.session.editingQso!.isEvent) {
        _applyEventFieldsFromData(widget.session.editingQso!.data);
        _seedFromRadioService();
      }
    } else {
      _seedFromRadioService();
      // Wins over the generic VFO seed above — a suggestion is specific
      // operator intent ("log THIS call"), the VFO seed is just ambient
      // radio state.
      if (widget.session.suggestedQso != null) {
        _applySuggestedQso(widget.session.suggestedQso!);
        // Remembered here as much as in didUpdateWidget: a panel built with a
        // suggestion already in hand — a cold start on a deeplink, a pane
        // remounted while a spot row is open — otherwise starts life believing
        // the call it was handed is an entry somebody composed, and refuses
        // every spot after it.
        _rememberSuggestedCall(tentative: widget.session.suggestedQsoIsTentative);
      }
    }
    _time.seedFields();
    _callController.addListener(_onCallChanged);
    // From the call field, a second Enter with nothing copied answers again
    // rather than asking again (esmStep's callFocused).
    _callFocus.addListener(_publishEsmFacts);
    _publishEsmFacts();
    _command.bind(widget.commands.interpretationUpdates);
    _radio.bind();
    _time.bind();
    // After the seed above, so the initial state doesn't arrive twice.
    widget.radio.radioUpdates?.addListener(_onRadioVfoChanged);
    // The time and frequency baselines are taken by `_time.bind()` and
    // `_radio.bind()` above, from whatever the fields already hold: an
    // initial seed that ran before the listeners existed notified nobody,
    // and an out-of-date baseline reads the first cursor move as an edit — a
    // `suggestedQso` (a spot deeplinked into a cold start) writes the
    // frequency before the model's listener exists.
    // Sent/Rcvd don't otherwise need a rebuild on every keystroke, but the
    // info row's second button (_buildWipeOrEditButton) re-evaluates
    // _qsoDataChanged() on every build, which reads these controllers —
    // without a rebuild, editing just the RST wouldn't flip that button
    // from "delete" to "revert changes".
    _sentController.addListener(_onSentOrRcvdChanged);
    _rcvdController.addListener(_onSentOrRcvdChanged);
    _sentController.addListener(() => _maybeJumpAfterRST(_sentFocus, _sentController));
    _rcvdController.addListener(() => _maybeJumpAfterRST(_rcvdFocus, _rcvdController));
    // A QSO CONSTRUCTED already-editing (rather than transitioned into) is
    // populated above, before these listeners exist — so without a baseline
    // the first notification they see reads as "0 → 3" and jumps. And the
    // first notification needs no typing: gaining focus collapses the
    // selection, which is itself a value change. Seed from what the fields
    // actually hold.
    _rstLengthSeen[_sentFocus] = _sentController.text.trim().length;
    _rstLengthSeen[_rcvdFocus] = _rcvdController.text.trim().length;
    // Same reasoning as Sent/Rcvd above — the button needs a rebuild when
    // an optional Grid/State field changes too.
    _gridController.addListener(_onSentOrRcvdChanged);
    _stateController.addListener(_onSentOrRcvdChanged);
    // All fields place the cursor at the end on focus, rather than selecting
    // the existing text — switching fields (e.g. cycling back to the call
    // field via space without logging) shouldn't put you one keystroke away
    // from wiping out a value you didn't mean to touch. This also overrides
    // the desktop-platform default of selecting all text when a field gains
    // focus via keyboard (as opposed to a tap) — see each field's
    // `selectAllOnFocus: false` below.
    for (final (focus, controller) in [
      (_callFocus, _callController),
      (_sentFocus, _sentController),
      (_rcvdFocus, _rcvdController),
      (_radio.freqFocus, _radio.freqController),
      (_time.timeFocus, _time.timeController),
      (_time.dateFocus, _time.dateController),
      (_gridFocus, _gridController),
      (_stateFocus, _stateController),
      (_radio.powerFocus, _radio.powerController),
    ]) {
      focus.addListener(() {
        if (focus.hasFocus) {
          _ladder.notePrimaryFocus(focus);
          controller.selection = TextSelection.collapsed(offset: _ladder.takePendingCaretOffset(focus, controller) ?? controller.text.length);
          if (identical(focus, _radio.freqFocus)) _radio.onFreqFocusChanged(hasFocus: true);
        } else if (identical(focus, _radio.freqFocus)) {
          _radio.onFreqFocusChanged(hasFocus: false);
        } else if (identical(focus, _sentFocus) || identical(focus, _rcvdFocus)) {
          // Show the operator what their shorthand became, at the moment they
          // are done with the field — the save expands it either way
          // (`_rstOrDefault`), so without this the record would carry a
          // report the field never displayed.
          final expanded = expandRST(controller.text, _radio.mode);
          if (expanded != controller.text) controller.text = expanded;
        }
      });
    }
    // Tab's walk, the arrow keys' end-of-value traversal, and Arrow Up out
    // to the pills, on the fixed primary fields. The exchange fields get the
    // same handler through the exchange model's own Tab handler, which their
    // nodes are built with; Freq and Time are secondary-control fields and
    // deliberately keep the default (they're a rung up already — their way
    // out is Down/Enter, see [LoggingFocusLadder.onExpandedKeyEvent]).
    for (final node in [_callFocus, _sentFocus, _rcvdFocus, _stateFocus, _gridFocus]) {
      node.onKeyEvent = _ladder.onPrimaryFieldKeyEvent;
    }
    _eventTextFocus.onKeyEvent = _ladder.onEventTextKeyEvent;
    _spotting.refreshSources();
    // Constructed already editing a QSO (rather than transitioning into it via
    // didUpdateWidget): score it so its pills show, and enqueue it for a
    // background lookup if it never got one — same as _populateFromEditingQso
    // does for the transition case. Scoring is guarded on _callInfoActive so
    // it only schedules a timer here — never setStates during initState;
    // enqueueLookup needs no such guard, it's fire-and-forget into the
    // caller's own queue.
    if (widget.session.editingQso != null) {
      if (_callInfoActive) {
        _lookup.scheduleScore();
        _lookup.refreshWorkedBefore();
      }
      widget.lookups.enqueueLookup?.call(widget.session.editingQso!);
    }
    // Wire the imperative handle (used by the app's dev bridge) so the call
    // field / Log / Wipe can be driven from outside the widget.
    _attachController(widget.session.controller);
    // Settles the serial previews' baseline: an idle panel shows no number
    // (docs/design/contests.md §5.8.1), but a panel constructed mid-contact —
    // a rebuild with the call already typed — takes its number now.
    unawaited(_exchange.refreshSerialPreviews());
    // A station that has never been set up has nothing in its VFO. Open the
    // Radio control so the operator is looking at the fields that need
    // answering, instead of finding out at log time that the contact can't be
    // written (HALO-24). Only while composing — an existing QSO carries its
    // own recorded band and mode — and only once per mount, so an operator who
    // closes it isn't fought by the next rebuild. Post-frame because
    // `_onSelectControl` calls setState, which initState cannot.
    if (widget.session.editingQso == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // `_radio.vfoIsUnset` is read here rather than above, because a
        // `suggestedQso` (a spot deeplinked into a cold start) pushes its own
        // freq/mode to the store from its own post-frame callback, registered
        // just before this one. Popping the control open over a frequency the
        // operator was handed a moment ago would be pure noise.
        if (mounted && _selectedControlKey == null && _radio.vfoIsUnset) _onSelectControl('radio');
      });
    }
  }

  @override
  void didUpdateWidget(LoggingControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    // In this order, and each on its own: a block that returns early is
    // written as one that says so, so nothing after it runs — or fails to
    // run — by accident.
    final logRequested = _syncLogRequest(oldWidget);
    _syncPowerInPlay(oldWidget);
    _syncSuggestionLifecycle(oldWidget, logRequested: logRequested);
    _syncKeyboardAccessory(oldWidget);
    _syncActivityControls(oldWidget);
    _syncSerialSource(oldWidget);
    _syncController(oldWidget);
    _syncRadioUpdates(oldWidget);
    if (widget.spotting.respotInterval != oldWidget.spotting.respotInterval) _spotting.followIntervalSetting();
    // An edit opening or closing, or a contest's exchange fields arriving —
    // none of them touches a field this hears otherwise.
    _publishEsmFacts();
    if (_syncEditingQso(oldWidget)) return;
    // Nothing below applies while editing an existing QSO — a suggestion or
    // a refs change must never clobber an in-progress edit.
    if (widget.session.editingQso != null) return;
    _syncComposingInputs(oldWidget);
  }

  /// A tentative suggestion the operator has not been asked about yet — it
  /// would overwrite an edit or a part-typed callsign, so it waits for the
  /// gesture to settle rather than take the fields mid-drag.
  Map<String, dynamic>? _heldSuggestion;

  /// The same, once cleared to proceed but waiting for the edit it displaces
  /// to be gone — the mirror of [_pendingLogRequest].
  Map<String, dynamic>? _pendingSuggestion;

  /// The callsign the last applied suggestion put in the field, and whether it
  /// came from a slide's peek (rather than a tap, or anything else that
  /// chooses a station outright).
  ///
  /// The field's own text is what says whether the operator has taken it over
  /// — NOT a flag set from the call field's listener. That listener fires for
  /// every programmatic rewrite too (a command expansion, a pane save), and
  /// any one of them counting as "the operator typed something" turns a
  /// suggestion nobody composed into work the next spot has to ask about, and
  /// then silently refuses every slide after it.
  String? _suggestedCall;
  bool _suggestionWasTentative = false;

  /// A [LoggingSession.logRequest] that is waiting for an edit to be
  /// cancelled before it can be applied. `onEditCanceled` reaches the parent
  /// and comes back as a widget update, so the fields are not this panel's to
  /// fill until that lands.
  Map<String, dynamic>? _pendingLogRequest;

  /// One of the panel's models changed something it paints — a typed
  /// frequency, a resolved lookup, a command's describe preview. None of
  /// them notifies during build (the Radio control's one build-phase write
  /// defers itself a frame), so a direct `setState` here is safe.
  void _onModelChanged() {
    if (!mounted) return;
    setState(() {});
    _publishEsmFacts();
  }

  /// Seeds the Radio control from the operation's `vfoA`
  /// ([RadioControlModel.seedFromVfo]), the Power field with it under its
  /// own rule. Never called while editing an existing *contact*, whose own
  /// recorded values always take priority ([QsoDraft.applyData]); an
  /// event's freq/mode are sentinels instead of a record, so
  /// `_populateFromEditingQso` calls this for one anyway, same as composing.
  void _seedFromRadioService({bool skipFrequency = false}) => _radio.seedFromVfo(skipFrequency: skipFrequency);

  /// The VFO moved underneath us — a connected radio was tuned, or
  /// something else in the app wrote to it. Mirror it into the Radio
  /// control, but never over the operator.
  void _onRadioVfoChanged() {
    if (!mounted) return;
    // Ahead of the editing guard: a self-spot is about the VFO, whatever QSO
    // is open.
    _spotting.followVfo();
    // An existing QSO's own recorded freq/band/mode always wins; ambient
    // radio state must not rewrite something already logged. An event's
    // freq/mode are sentinels, not a record — its Radio control keeps
    // following the live VFO the whole time it's open, same as composing.
    if (widget.session.editingQso != null && !widget.session.editingQso!.isEvent) return;
    final previousBand = _radio.band;
    final previousMode = _radio.mode;
    setState(() {
      // Suppresses the frequency listener's push-back. Without it, seeding a
      // value the radio just reported arms the 5s debounce and sends it
      // straight back at the radio, forever.
      _draft.populate(() {
        // Skip only the frequency, never the whole seed: suppressing it
        // entirely would drop a mode the rig reported meanwhile, and the
        // pending push would then send the panel's stale mode back — taking a
        // rig the operator had just put into CW back out of it, and logging
        // USB at 59.
        _seedFromRadioService(skipFrequency: _radio.freqTouched);
      });
    });
    // [QsoDraft.populate] above suppressed the frequency listener's own rescore, and the
    // mode never had one. The dupe / New Band / New Mode pills are scored
    // against band and mode, so without this a rig retuned at its own front
    // panel left them describing the band the operator has left. Debounced
    // and gated on a plausible callsign, so a spun VFO knob costs nothing.
    if (_radio.band != previousBand || _radio.mode != previousMode) {
      _radio.resyncDropdownFields();
      _lookup.scheduleScore();
    }
  }

  @override
  void dispose() {
    // Leaving the operation lets its number go (docs/design/contests.md
    // §5.8.1): a hold with no panel behind it would block the other
    // positions for as long as the operator stays away.
    if (widget.session.editingQso == null) widget.log.serialNumbers?.release(widget.log.operation.uuid);
    // A published row would otherwise outlive this panel, hanging over
    // whatever replaced it with a handler that types into nothing. The
    // controller defers the write when the tree is locked, which it is here
    // (dispose runs inside `finalizeTree`) — and `deactivate` is no better,
    // since that runs during build.
    widget.prefs.keyboardAccessory?.clearIfOwner(this);
    FocusManager.instance.removeListener(_rebuildForNumbersRow);
    widget.commands.onDispatcherChanged?.call(null);
    widget.session.controller?.detach();
    widget.radio.radioUpdates?.removeListener(_onRadioVfoChanged);
    ClockTravel.instance.removeListener(_onClockTravelChanged);
    WidgetsBinding.instance.removeObserver(this);
    _lookup.dispose();
    _command.dispose();
    _spotting.dispose();
    _draft.dispose();
    _exchange.dispose();
    _refs.dispose();
    _notesController.dispose();
    _notesFocus.dispose();
    _ladder.dispose();
    _callController.dispose();
    _sentController.dispose();
    _rcvdController.dispose();
    _gridController.dispose();
    _stateController.dispose();
    _eventTextController.dispose();
    _focusBackstop.dispose();
    _eventTextFocus.dispose();
    _callFocus.dispose();
    _sentFocus.dispose();
    _rcvdFocus.dispose();
    _gridFocus.dispose();
    _stateFocus.dispose();
    _time.dispose();
    _radio.dispose();
    super.dispose();
  }

  void _onSentOrRcvdChanged() => setState(() {});

  /// The length each report field held last time it was looked at, so a jump
  /// can tell "the operator just finished a report" from "a full report is
  /// already sitting there".
  final Map<FocusNode, int> _rstLengthSeen = {};

  /// Which controls the strip offers, in what order, and which are hidden —
  /// see [SecondaryControlCatalog]. The specs themselves are built in
  /// [_buildSecondaryControls], only for the visible ones.
  late final _catalog = SecondaryControlCatalog(
    config: () => (
      radioIcon: _radio.chipIcon,
      hasPowerStore: widget.radio.radioService != null,
      canSpot: widget.spotting.suggestSpotSources != null && widget.spotting.sendSpot != null,
      activityControls: _refs.controls,
      controlOrder: widget.strip.controlOrder,
      hiddenControlKeys: widget.strip.hiddenControlKeys,
      spottingAfterReferences: widget.strip.spottingAfterReferences,
    ),
  );

  // ── Mobile numbers row (issue #27) ──────────────────────────────────────

  /// Whether this panel's More pane is open. The pane is a route of its own,
  /// outside [DefaultFocusBackstop.panelScope], and modal over the panel — so
  /// while it is up, any focused field is the pane's (or something the pane
  /// opened), and the row keeps typing into it.
  bool _editPaneOpen = false;

  /// Inserts a numbers-row key at the focused field's cursor as a keystroke
  /// would: through the field's input formatters and its `onChanged`, so
  /// every field reacts to a tapped digit exactly as to a typed one (the
  /// call's [LoggingSession.onCallTyped], Grid/State's "touched" marks, the
  /// note reaching the draft…) without this panel listing what each one does.
  void _handleNumberKey(String key) {
    final field = _focusedNumberField;
    if (field == null || _fieldsLocked) return;
    field.userUpdateTextEditingValue(_SpaceAndNumbers._typedAtCursor(field.textEditingValue, key), SelectionChangedCause.keyboard);
  }

  /// Rebuilds so the bar's visibility and contextual "/"→"." key track the
  /// focused field. Hears every primary-focus change, since a move between
  /// two of the panel's fields notifies neither the panel's scope nor any
  /// node it could list. Only runs while the feature is on, on mobile, so it
  /// costs nothing otherwise.
  void _rebuildForNumbersRow() {
    if (!widget.prefs.showNumbersRow || !isMobilePlatform) return;
    rebuildBetweenFrames();
  }

  /// `setState` for the part files' extensions, which may not call it.
  ///
  /// Those extensions hold this panel's behaviour, and this class its state
  /// and every callback handed to something that compares it later — the
  /// listeners above and below, and [_handleNumberKey] inside a
  /// [KeyboardAccessorySpec]. An extension method's tear-off is a new closure
  /// on every read, so a `removeListener` given one never matches the
  /// `addListener` it undoes, and a spec holding one never equals the last.
  void _setStateFromPart(VoidCallback fn) => setState(fn);

  /// The call field's text as [_onCallChanged] last heard it, populates
  /// included — so a caret move after a spot or an opened QSO is seen as one.
  String _lastCallText = '';

  void _onCallChanged() {
    final textChanged = _callController.text != _lastCallText;
    _lastCallText = _callController.text;
    // An emptied call field ends ESM's contact: without this, the same call
    // typed again could be thanked and logged without ever being answered.
    if (_callController.text.trim().isEmpty) _esmAnsweredCall = null;
    _publishEsmFacts();
    if (_draft.isPopulating) return;
    // Past the guard, the change is the operator's own — typing, or the clear
    // that `_wipe` does — which is exactly what the spots list wants to hear
    // about. A suggestion filling the field never reaches here.
    widget.session.onCallEdited?.call();
    // Before anything else reacts: a prefill made for the call that just
    // changed must not outlive it, whether or not the new call's lookup and
    // refresh ever land.
    _exchange.withdrawSuggestionsExcept(call: _callAtCursor);
    // Back on the call the installed controls were fetched for — the caret
    // stepped off it and returned before another call's lookup landed — no
    // lookup or refresh runs again (its lookup is still the current one), so
    // without this the prefill the step away took back never returns.
    if (_refs.refreshedFor == _callAtCursor && _exchange.applySuggestedValues(call: _callAtCursor)) _lookup.exchangePrefilled();
    setState(() {});
    // The first character of a call is what takes a serial number.
    unawaited(_exchange.refreshSerialPreviews());
    _lookup.cancelLookup();
    // Whatever was shown for the previous text is gone, an execution
    // confirmation included.
    _command.keystroke();

    // Live scoring for the call-info notices line — independent of the lookup
    // and command paths below, so schedule it before their early returns.
    // Only a keystroke is on its way to another call. The listener also
    // hears the caret move — a click into the field, a step between the calls
    // of a list — and holding on one blanks pills already showing.
    _lookup.callTyped(settles: textChanged && !_callController.text.contains(',') && !_isCallStackField);
    _lookup.scheduleScore();

    final call = _call;
    if (call.isEmpty) {
      if (_lookup.lookupFor != null || _command.hasRetained) {
        setState(() {
          _lookup.forget();
          _command.forgetRetained();
        });
      }
      return;
    }

    // Command shortcuts only apply while composing a new QSO — see _log().
    _command.scheduleDescribe();

    _scheduleLookup();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleSubmitButtonMeasurement();
    // Push the current call-info and QSO draft up to the host (Info tab /
    // modal, extension panels) after this build settles, so neither ever
    // setStates a parent mid-build.
    if (widget.lookups.onCallInfoChanged != null || widget.session.onQsoChanged != null || widget.session.onPeerDraftChanged != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _notifyCallInfo();
        _notifyQsoDraft();
      });
    }
    final theme = Theme.of(context);
    final poloColors = HaLoColors.of(context);

    // While editing an existing QSO, the panel swaps its tertiary ("new
    // QSO") accent for the secondary ("editing") accent — mirrors
    // app-polo's `themeColor` switching. Only the tertiary* tokens are
    // remapped (not a full ColorScheme swap), so unrelated colors
    // (primary, error) are unaffected. `accentTheme` carries the remapped
    // HaLoColors extension too, so SecondaryControlRow's chips (which read
    // HaLoColors.of(context)/Theme.of(context) ambiently) pick it up.
    final editing = widget.session.editingQso != null;
    // Viewing an already-deleted QSO: fields are read-only, same as a
    // staged delete — the only actions are restoring it (the second
    // button) or selecting away (ham2k/halo-dist#59).
    final deletedQso = widget.session.editingQso?.deleted ?? false;
    final fieldsLocked = _fieldsLocked;
    final accentPoloColors = editing ? poloColors.copyWith(tertiaryLight: poloColors.secondaryLight) : poloColors;
    final accentTheme = editing
        ? theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              tertiary: theme.colorScheme.secondary,
              onTertiary: theme.colorScheme.onSecondary,
              tertiaryContainer: theme.colorScheme.secondaryContainer,
              onTertiaryContainer: theme.colorScheme.onSecondaryContainer,
            ),
            extensions: [accentPoloColors],
          )
        : theme;

    _syncNumbersRow(context, accentTheme);

    // Resolved once per build, for the menu.
    final exchangeMenu = _exchange.openMenu;
    final panel = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _handleEscape,
        // Enter picks a highlighted suggestion instead of logging — see
        // `_handleEnter`. Bound here AND on the exchange field's own
        // `onSubmitted`, because a single-line TextField consumes Enter itself
        // and never lets it reach an ancestor Shortcuts.
        const SingleActivator(LogicalKeyboardKey.enter): _handleEnter,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _handleEnter,
        const SingleActivator(LogicalKeyboardKey.space): _handleSpace,
      },
      child: FocusTraversalGroup(
        child: Material(
          elevation: 4,
          // app-polo's logging panel uses the operation's theme color
          // (tertiary here, secondary while editing) as its background,
          // with a divider line in the same tint separating it from the
          // QSO list above.
          color: accentTheme.colorScheme.tertiaryContainer,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!widget.prefs.aboveLog) Container(height: 2, color: accentPoloColors.tertiaryLight),
              Padding(
                // No top inset at all — SecondaryControlRow's expanded
                // panel slides out flush against the divider above, and the
                // row itself animates the border→pills gap, so any padding
                // here would show as bare panel background above the
                // panel's dark area. Left/right add the real device inset
                // (ham2k/halo-dist#205) — SecondaryControlRow's own
                // `horizontalBleed` stays keyed to the fixed
                // `secondaryPanelHorizontalInset` only, so its expanded
                // panel still stops short of the physical edge by that
                // device inset instead of bleeding into it.
                // Mirrored above the log: the expanded panel then sits flush
                // against the divider BELOW, and the inset goes over the fields.
                padding: PaneSafeArea.symmetricOf(
                  context,
                  horizontal: secondaryPanelHorizontalInset,
                ).add(EdgeInsets.only(top: widget.prefs.aboveLog ? Space.md : 0, bottom: widget.prefs.aboveLog ? 0 : Space.md)),
                // Scoped so every field's label/underline reads clearly
                // against the tertiary-tinted panel, without touching the
                // rest of the theme (the log button keeps its own
                // deliberate primaryContainer styling below).
                child: Theme(
                  data: accentTheme.copyWith(
                    inputDecorationTheme: accentTheme.inputDecorationTheme.copyWith(
                      // Matches app-polo's H2kTextInput, whose fields sit on
                      // a near-white `colors.background` fill regardless of
                      // the panel's own (tertiary-tinted) background.
                      filled: true,
                      fillColor: accentTheme.colorScheme.surface,
                      labelStyle: TextStyle(color: accentTheme.colorScheme.onTertiaryContainer.withValues(alpha: 0.85)),
                      floatingLabelStyle: TextStyle(color: accentTheme.colorScheme.onTertiaryContainer),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentTheme.colorScheme.onTertiaryContainer.withValues(alpha: 0.4))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentTheme.colorScheme.tertiary, width: 3)),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    // Above the log the whole stack reads the other way up —
                    // fields, then keyer and info, then the pills and what they
                    // open — so the fields are what meets the panel's edge.
                    verticalDirection: widget.prefs.aboveLog ? VerticalDirection.up : VerticalDirection.down,
                    children: [
                      AbsorbPointer(
                        absorbing: fieldsLocked,
                        child: Opacity(
                          opacity: fieldsLocked ? 0.5 : 1,
                          child: SecondaryControlRow(
                            // Every pill still shows while editing an event —
                            // just disabled but Time, so the row's shape
                            // doesn't change between editing a contact and an
                            // event. A BREAK's grid/contest-exchange segment
                            // override has no editing UI yet either
                            // (docs/design/contests.md §5.1.3), so it stays
                            // disabled along with the rest.
                            controls: _buildSecondaryControls(accentTheme, accentPoloColors, enabledFor: _editingEvent ? (key) => key == 'time' : null),
                            selectedKey: _selectedControlKey,
                            onSelect: _onSelectControl,
                            onOpenSettings: _openControlSettingsDialog,
                            horizontalBleed: secondaryPanelHorizontalInset,
                            panelBelow: widget.prefs.aboveLog,
                            // The dupe warning (and the other scoring notices)
                            // live on the info area's third line — see
                            // `_buildInfoArea` (issue #40).
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.md),
                      LoggingInfoFrame(
                        buttonDiameter: _editButtonDiameter ?? 44,
                        leftieMode: widget.prefs.leftieMode,
                        signature: _infoAreaSignature(fieldsLocked: fieldsLocked, deletedQso: deletedQso),
                        strip: widget.strip.aboveEntryRow,
                        actionButton: _buildWipeOrEditButton(accentTheme),
                        entryRowAbove: widget.prefs.aboveLog,
                        child: fieldsLocked ? LockedFormWarning(theme: theme, text: _lockedWarningText(deletedQso)) : _buildInfoArea(accentTheme),
                      ),
                      const SizedBox(height: Space.md),
                      // A Stack so the `options` suggestion pills can float over
                      // the info area above instead of pushing the fields down
                      // under the operator's cursor. Clip.none: the pills are
                      // deliberately painted outside this box, and the row itself
                      // is what gives the Stack its size (the pills are
                      // positioned, so they never enlarge it).
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          LoggingEntryRow(
                            call: (controller: _callController, focus: _callFocus),
                            rstFields: widget.prefs.showRSTFields ? _rstPair : const [],
                            rstPlaceholder: _rstPlaceholder,
                            numericKeyboardType: _numbersAndPunctuationOnIOS,
                            exchange: _exchange,
                            textControls: _textControls,
                            state: widget.prefs.showStateField ? (controller: _stateController, focus: _stateFocus) : null,
                            stateHint: _guessStateHint,
                            onStateChanged: (_) {
                              _draft.stateTouched = true;
                              // Scored on (New State / New Province, and a party's
                              // exchange), so a typed state reaches the scorer the
                              // way an exchange field's value does.
                              _lookup.exchangeEdited();
                            },
                            grid: widget.prefs.showGridField ? (controller: _gridController, focus: _gridFocus) : null,
                            gridHint: _guessGridHint,
                            onGridChanged: (_) {
                              _draft.markGridTouched();
                              // A scorer judges the grid (`shortGrid`).
                              _lookup.exchangeEdited();
                            },
                            command: _command,
                            virtualSpace: _virtualSpace,
                            commandVirtualSpace: _commandVirtualSpace,
                            enabled: !fieldsLocked,
                            leftieMode: widget.prefs.leftieMode,
                            // The log button is a circle as tall as the row, so the
                            // height already measured for it is also its width. The
                            // 44 fallback (first frame, before that measurement
                            // lands) matches the info area's own above.
                            buttonWidth: _editButtonDiameter ?? 44,
                            submitButton: _buildSubmitButton(accentTheme, editing: editing, deletedQso: deletedQso),
                            eventFields: _editingEvent
                                ? EventFieldRow(
                                    editingQso: widget.session.editingQso!,
                                    textController: _eventTextController,
                                    textFocus: _eventTextFocus,
                                    enabled: !fieldsLocked,
                                    todoDone: _eventTodoDone,
                                    onTodoDoneChanged: (done) => setState(() => _eventTodoDone = done),
                                    onSubmitted: _log,
                                  )
                                : null,
                            onSubmitted: () => _log(fromEnter: true),
                            onExchangeSubmitted: _handleEnter,
                            onCallTyped: widget.session.onCallTyped,
                          ),
                          if (exchangeMenu != null) ExchangeSuggestionsMenu(model: _exchange, menu: exchangeMenu, theme: accentTheme),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // The numbers row is NOT drawn here. It has to sit under the
              // status footer and directly on the keyboard, and the footer
              // lives one level up in the app's status-bar overlay — so this
              // publishes the row and the overlay draws it in that one spot.
              // See `_syncNumbersRow` / KeyboardAccessoryController.
              // Reserve the home indicator at the bottom so the fields (and
              // numbers row) clear it — the Scaffold doesn't resize, it
              // extends full height so each pane fills behind it. Zero
              // wherever the host's own bottom chrome already holds that
              // strip, which the MediaQuery in [_bottomReserve] answers. The
              // keyboard is NOT reserved here: `_StatusBarOverlay` does that
              // for the whole app so the footer can ride above it, so the space
              // this panel is handed already ends above the keyboard. The
              // spacer takes the numbers row's colour when it's showing (so the
              // row reads as continuing into the strip); otherwise it's the
              // panel's own background (Material above), so the home-indicator
              // strip matches the panel.
              if (_bottomReserve > 0) SizedBox(width: double.infinity, height: _bottomReserve),
              if (widget.prefs.aboveLog) Container(height: 2, color: accentPoloColors.tertiaryLight),
            ],
          ),
        ),
      ),
    );

    // Trap Tab (and Shift+Tab) inside the logging controls: a FocusScope
    // confines traversal to its descendants and wraps at the ends, the same
    // primitive a dialog uses. Without it, Tab past the last field escapes
    // into the QSO list above. Programmatic focus moves and mouse clicks
    // still cross the boundary freely — only keyboard traversal is confined.
    return FocusScope(
      node: _focusBackstop.panelScope,
      child: Focus(canRequestFocus: false, skipTraversal: true, onKeyEvent: (node, event) => _handleChord(event), child: panel),
    );
  }

  /// Rebuilds when the on-screen keyboard opens or closes — the numbers row
  /// appears and disappears with it, and `virtualKeyboardIsUp` reads the raw
  /// view inset, which has no MediaQuery dependency to rebuild on.
  ///
  /// The panel no longer sizes anything to the keyboard itself: `_StatusBarOverlay`
  /// reserves the keyboard's height below the status footer for the whole app,
  /// so the space this panel is given already ends above the keyboard.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _focusBackstop.onResumed();
  }

  @override
  void didChangeMetrics() {
    if (isMobilePlatform && mounted) setState(() {});
  }

  /// What [_notifyCallInfo] last pushed.
  String? _lastCallInfoSig;

  /// What [_notifyQsoDraft] last pushed, and to whom — see there for why
  /// these are read-only.
  Map<String, dynamic>? _lastPublishedQso;
  List<PeerDraftField>? _lastPublishedFields;
  TemplateCalls? _lastPublishedCalls;
}
