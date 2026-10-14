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

/// The logging panel: the entry row, the information area and the secondary
/// control strip. Wired up through nine groups, one per concern — the log it
/// writes to and reads ([LogHooks]), what the app is doing with it right now
/// ([LoggingSession]), the rig it mirrors ([RadioHookup]), where it learns
/// about a callsign ([LookupHooks]), the activities' controls
/// ([ActivityHooks]), the command shortcuts ([CommandHooks]), the strip as
/// the operator arranged it ([ControlStripSettings]), the spotting networks
/// ([SpottingHooks]) and the operator's preferences ([LoggingPreferences]).
/// Only the log is required; a caller names the groups it has something to
/// say about.
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
  late final TimeControlModel _time = TimeControlModel(config: () => (editingQso: widget.session.editingQso), draft: _draft);

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
      aboveLog: widget.prefs.aboveLog,
    ),
    selectControl: _onSelectControl,
    showControl: _showControl,
  );

  /// The operation resolved into its segments. `widget.log.qsos` is the whole log,
  /// which is what carries the `break`/`start` event rows; an unsegmented
  /// operation resolves to a single segment that is its own data, unchanged.
  SegmentedOperation get _segmented => SegmentedOperation.from(operation: widget.log.operation.data, qsos: widget.log.qsos);

  /// Ref types the operation is actually running right now.
  ///
  /// This is the gate on PRIMARY field real estate (see `_textControls`).
  /// Secondary chips deliberately don't consult it: an extension can offer one
  /// from any operation — POTA's hunter control is the case that matters, since
  /// you chase a park from whatever you happen to be running.
  ///
  /// Reads the CURRENT segment, not the base operation: a QSO being typed now
  /// belongs to whatever the last `break`/`start` established, so a contest
  /// that ended at a break stops claiming the entry row and a park entered at
  /// one starts claiming it (docs/design/contests.md §5.1.3).
  Set<String> get _activeRefTypes {
    final current = _segmented.current;
    return {
      for (final ref in ((current['refs'] as List?) ?? const []).whereType<Map<dynamic, dynamic>>())
        if (ref['type'] case final String type) type,
    };
  }

  /// Every typed-exchange activity control currently contributed — `text` and
  /// `serial` alike, since both render the same way and differ only in who
  /// supplies the value.
  ///
  /// These render as PRIMARY fields, inline after Sent/Rcvd — not as secondary
  /// control chips like `refList`. A contest exchange is typed on every single
  /// QSO, hundreds of times an hour, so it belongs in the entry row next to the
  /// callsign; a chip that has to be expanded first is unusable at that rate.
  /// app-polo lays them out in the same place, between the RSTs and Grid/State.
  ///
  /// Precisely because that row is the scarcest space in the app, a control only
  /// earns a place in it if the operation is RUNNING that activity
  /// ([_activeRefTypes]) — every enabled contest extension is asked for logging
  /// controls, but merely having one installed must not put its exchange in
  /// front of someone logging an ordinary QSO. Enforced here rather than left to
  /// each extension: this is the core's rule about its own entry row, and the
  /// consequences of an extension forgetting it are severe — a stray `serial`
  /// field would hand out numbers from a series nobody is keeping.
  ///
  /// A control with no `refType` can never match, which is the intended
  /// reading: a primary field writes to a ref, so one that names no ref has
  /// nothing to attach itself to.
  Iterable<Map<String, dynamic>> get _textControls {
    final active = _activeRefTypes;
    return _refs.controls.where((c) {
      final input = c['input'] as Map?;
      final kind = input?['kind'];
      // `options` rides the same pipeline as `text`: it is a typed exchange
      // field that happens to search a known set, so save, restore, focus
      // cycling, the suggestion rule and the explicit-blank rule all come free
      // by joining here rather than by reimplementing any of them.
      if (kind != 'text' && kind != 'serial' && kind != 'options') return false;
      return active.contains(input?['refType']);
    });
  }

  /// Enter, which means two different things depending on whether the operator
  /// has a suggestion picked out.
  ///
  /// A highlight they walked to with the arrow keys is a PENDING CHOICE, so Enter
  /// takes it and stops there: logging a QSO whose exchange they were still
  /// choosing is the worst available reading of that keystroke, and unlike a
  /// wrong exchange it cannot be undone by pressing Enter again. With the
  /// highlight untouched there is no pending choice and Enter is just Enter — it
  /// logs, exactly as it does from every other field.
  ///
  /// The second Enter therefore logs, because accepting clears the highlight,
  /// which is the sequence the operator's hands were making anyway: pick, send.
  void _handleEnter() {
    if (_exchange.acceptPendingChoice()) return;
    _log(fromEnter: true);
  }

  /// The call for which ESM's first step has gone out — the station called,
  /// or the caller given their exchange — so the next Enter completes the
  /// contact. Compared against the call in the field rather than cleared on
  /// each keystroke: a corrected call is a new contact to ESM, and one Enter
  /// away from its own first step.
  String? _esmAnsweredCall;

  /// The exchange fields ESM waits on: the contest's own, not the reports
  /// (which carry defaults) nor the serial we send (which is allocated).
  List<PrimaryField> get _esmExchangeFields {
    final keys = {
      for (final control in _textControls)
        if ((control['input'] as Map?)?['kind'] != 'serial') control['key'] as String,
    };
    return [
      for (final field in _primaryFields)
        if (keys.contains(field.key)) field,
    ];
  }

  /// Completed by the log an ESM step handed off to — see [EnterSends.send].
  Completer<Map<String, dynamic>?>? _esmLogged;

  /// Enter Sends Messages: keys what [esmStep] picks and answers whether this
  /// Enter ends here. False means go on and log.
  bool _enterSendsMessages(EnterSends esm) {
    final exchange = _esmExchangeFields;
    // The call the messages key, not the field: on a stack, answering NK2Y
    // and then moving to KI2D is a new station to answer, not KI2D's thanks.
    final calls = _callText.templateCalls;
    final call = calls.call;
    final step = esmStep(
      running: esm.running,
      callEmpty: _callController.text.trim().isEmpty,
      canLog: _canLog,
      answered: call.isNotEmpty && _esmAnsweredCall == call,
      hasExchange: exchange.isNotEmpty,
      exchangeCopied: exchange.any((field) => _exchange.valueOf(field.key).trim().isNotEmpty),
      callFocused: _callFocus.hasFocus,
      incompleteCall: isIncompleteCall(call),
    );
    if (step == null) return false;
    // A step that logs hands over what the entry is AFTER the log too, for
    // the messages that speak to it — the thanks, which may name the next
    // stacked call.
    if (step.send.isNotEmpty && step.then == EsmThen.log) {
      final logged = _esmLogged = Completer<Map<String, dynamic>?>();
      esm.send(step.send, _withCallField(_draft.toData(), calls), logged: logged.future);
    } else if (step.send.isNotEmpty) {
      esm.send(step.send, _withCallField(_draft.toData(), calls));
    }
    switch (step.then) {
      case EsmThen.stay:
        return true;
      case EsmThen.toExchange:
        _esmAnsweredCall = call;
        final empty = exchange.where((field) => _exchange.valueOf(field.key).trim().isEmpty);
        final fields = _primaryFields;
        // No exchange at all (S&P with reports only): the field after the
        // call, where the report they give us goes; nothing after it, and the
        // call field keeps focus — [_esmAnsweredCall] still makes the next
        // Enter the second step.
        final target = empty.isNotEmpty
            ? empty.first
            : exchange.isNotEmpty
            ? exchange.first
            : fields.length > 1
            ? fields[1]
            : null;
        target?.focus.requestFocus();
        return true;
      case EsmThen.log:
        return false;
    }
  }

  /// Runs `widget.log.decorateQsoBeforeSave` if wired, so an activity can project
  /// its ref data into generic QSON fields. Identity when no callback is
  /// supplied, which is every test and tooling path.
  Future<Map<String, dynamic>> _decorated(Map<String, dynamic> data) async {
    final decorate = widget.log.decorateQsoBeforeSave;
    if (decorate == null) return data;
    // A new contact has no `startAtMillis` yet (its time is automatic) and
    // belongs to the CURRENT segment — not the base, which is what
    // `effectiveAt(null)` answers.
    final at = data['startAtMillis'] as int?;
    return decorate(data, at == null ? _segmented.current : _segmented.effectiveAt(at));
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
  /// shortcut does — see [VirtualSpaceFormatter]. One shared instance since it
  /// only closes over the stable [_handleSpace] tear-off.
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

  /// The exit when iOS turned the operator's second space into a period. Puts
  /// the field back to [baseText] — the value before the gesture began —
  /// rather than editing whatever is there now: iOS applies BOTH halves of the
  /// shortcut before this runs, so "strip the trailing space" would leave the
  /// period sitting on the end of the value.
  void _exitOnPeriodShortcut(String baseText) {
    _callController.value = TextEditingValue(
      text: baseText,
      selection: TextSelection.collapsed(offset: baseText.length),
      composing: TextRange.empty,
    );
    _ladder.advancePrimaryFocus();
  }

  /// Keyboard for the numeric-leaning primary fields (RST, frequency) on iOS.
  /// `numberWithOptions(signed: true)` selects iOS's NumbersAndPunctuation
  /// keyboard: numbers up front, but WITH a space bar (so Space still rotates
  /// focus — see [VirtualSpaceFormatter]) and the symbols these fields use —
  /// an RST like "5NN"/"59A" reaches letters via its ABC key, and +/- and the
  /// frequency separators sit on the primary page. Without it these fields get
  /// the letter-first default keyboard, which buries digits behind the "123"
  /// key for input that's mostly numeric.
  ///
  /// Null off iOS: Android's default keyboard already has both letters and a
  /// space bar, and a signed-number type there would instead drop to a numeric
  /// pad that loses the letters RSTs occasionally need — so each field keeps
  /// its existing keyboard on other platforms.
  TextInputType? get _numbersAndPunctuationOnIOS => isIOSPlatform ? const TextInputType.numberWithOptions(signed: true) : null;

  /// The keyboard for the frequency and power fields: iOS's
  /// NumbersAndPunctuation (the decimal separators, the symbols, and a space
  /// bar for Space-to-advance), the decimal pad elsewhere. Not the entry
  /// row's: there a null deliberately keeps the RST fields' letter-bearing
  /// default keyboard.
  TextInputType get _decimalKeyboardType => _numbersAndPunctuationOnIOS ?? const TextInputType.numberWithOptions(decimal: true);

  void _scheduleSubmitButtonMeasurement() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = _submitButtonKey.currentContext?.size;
      if (size != null && (_editButtonDiameter == null || (size.height - _editButtonDiameter!).abs() > 0.5)) {
        setState(() => _editButtonDiameter = size.height);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Publish the dispatcher while this panel is live, so a command run from
    // the ⌘K dialog lands on THIS logging panel's state.
    widget.commands.onDispatcherChanged?.call(_dispatchActions);
    _focusBackstop.attach();
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
        // Keep the mobile numbers row in sync with which field has focus.
        _rebuildForNumbersRow();
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
    widget.session.controller?.attach(
      setField: _devSetField,
      submit: _log,
      wipe: _wipe,
      isFieldsLocked: () => _fieldsLocked,
      handleChord: _handleChord,
      focusCall: _callFocus.requestFocus,
      focusSecondaryControls: _ladder.focusPillAndOpen,
      focusLastPrimaryField: _ladder.focusLastPrimaryField,
    );
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

  /// Sets a primary field as if typed — the controller listeners fire, so the
  /// debounced lookup/scoring run just like user input. `call` only for now.
  void _devSetField(String field, String value) {
    switch (field) {
      case 'call':
        // Same single-assignment idiom as the `setCallField` command path
        // (text + end cursor in one write, then focus) so `_onCallChanged`
        // reacts exactly as if typed.
        _callController.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
        _callFocus.requestFocus();
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
    if (_syncEditingQso(oldWidget)) return;
    // Nothing below applies while editing an existing QSO — a suggestion or
    // a refs change must never clobber an in-progress edit.
    if (widget.session.editingQso != null) return;
    _syncComposingInputs(oldWidget);
  }

  /// A log request landed with this update — see [_handleLogRequest]. Runs
  /// before the editing guards in [didUpdateWidget] can return; says so,
  /// because a suggestion arriving on the same frame reads differently.
  bool _syncLogRequest(LoggingControls oldWidget) {
    final request = widget.session.logRequest;
    final logRequested = request != null && request.serial != oldWidget.session.logRequest?.serial;
    if (logRequested) {
      // The commit asks its own question, about the same gesture — so a peek
      // held from the way in has nothing left to say.
      _heldSuggestion = null;
      unawaited(_handleLogRequest(request.qso));
    }
    return logRequested;
  }

  void _syncPowerInPlay(LoggingControls oldWidget) {
    // Power may have just come into play — the operator added the control to
    // the row, or switched station-info tracking on. The field is seeded from
    // the VFO only while power IS in play, so without this it stays empty
    // until the next VFO notification, and a QSO logged in between carries
    // none. Decided from the inputs rather than a remembered flag: a `late`
    // field's initializer runs on its first READ, which is here, and would
    // simply record the new state and see no change.
    final controlsChanged =
        oldWidget.radio.trackingPower != widget.radio.trackingPower ||
        !const ListEquality<String>().equals(oldWidget.strip.controlOrder, widget.strip.controlOrder) ||
        !const SetEquality<String>().equals(oldWidget.strip.hiddenControlKeys, widget.strip.hiddenControlKeys);
    if (controlsChanged) _radio.seedPowerFromVfo();
  }

  /// A slid spot row's suggestion: withdrawn, held, or confirmed. Runs before
  /// the editing guards in [didUpdateWidget]: an edit in progress is exactly
  /// when a tentative suggestion has something to say, and those guards
  /// would swallow all three of these.
  void _syncSuggestionLifecycle(LoggingControls oldWidget, {required bool logRequested}) {
    if (oldWidget.session.suggestedQso != null && widget.session.suggestedQso == null) _withdrawTentativeSuggestion();
    if (!logRequested &&
        widget.session.suggestedQsoIsTentative &&
        widget.session.suggestedQso != null &&
        !identical(oldWidget.session.suggestedQso, widget.session.suggestedQso) &&
        (widget.session.editingQso != null || _hasComposedCall)) {
      // Held rather than applied — and rather than dropped: the operator gets
      // it back the moment the gesture settles.
      //
      // Never on the frame a log request lands. A commit carries a fresh
      // suggestion of its own alongside the request, and holding THAT arms a
      // question about a gesture that has already finished: it survives the
      // log, and the next row to settle raises a prompt about a station the
      // operator dealt with long ago — which, accepted, replaces the one they
      // are working and retunes the radio to it.
      _heldSuggestion = widget.session.suggestedQso;
    }
    if (widget.session.suggestionSettledSerial != oldWidget.session.suggestionSettledSerial) {
      final held = _heldSuggestion;
      if (held != null) {
        _heldSuggestion = null;
        unawaited(_confirmHeldSuggestion(held));
      }
    }
  }

  void _syncKeyboardAccessory(LoggingControls oldWidget) {
    // Withdraw from the controller we actually published to. `deactivate` only
    // ever sees the CURRENT one, so without this a swapped controller keeps a
    // row nothing can ever take back.
    if (!identical(oldWidget.prefs.keyboardAccessory, widget.prefs.keyboardAccessory)) {
      oldWidget.prefs.keyboardAccessory?.clearIfOwner(this);
    }
  }

  void _syncActivityControls(LoggingControls oldWidget) {
    // The controls a contest contributes arrive asynchronously, after this
    // widget first builds — so a serial field is typically declared here
    // rather than in initState, and this is where its first preview comes
    // from. The operation's own refs matter just as much, since they decide
    // which primary controls survive `_textControls` at all: adding the
    // activity is what makes the serial field appear. Deliberately before the
    // editing guards in [didUpdateWidget]: showing the right number never
    // depends on what is being composed.
    if (!identical(oldWidget.activities.activityControls, widget.activities.activityControls) ||
        !identical(oldWidget.log.operation.data['refs'], widget.log.operation.data['refs'])) {
      // A per-QSO refresh cached before this change must not shadow it —
      // see [ActivityRefsModel.controlsChanged].
      _refs.controlsChanged();
      // `_scheduleLookup` only re-fetches per-QSO controls when the active
      // call CHANGES (`_lookup.lookupFor == activeCall` short-circuits it) — so
      // clearing the cache here would otherwise silently drop an
      // already-resolved lookup's guessed field (a suggested grid, say)
      // for the rest of the composing session, with nothing left to bring
      // it back except retyping the callsign.
      if (_lookup.lookupFor != null) unawaited(_refs.refreshControlsFor(_lookup.lookupFor!));
      unawaited(_exchange.refreshSerialPreviews());
    }
  }

  void _syncSerialSource(LoggingControls oldWidget) {
    // The source is the panel's only handle on its held number: a source
    // swapped out (sharing switched off) or an operation swapped under the
    // panel would otherwise leave that number held with nothing left to
    // release it — and served again the moment the source came back.
    if (widget.session.editingQso == null &&
        (oldWidget.log.serialNumbers != widget.log.serialNumbers || oldWidget.log.operation.uuid != widget.log.operation.uuid)) {
      oldWidget.log.serialNumbers?.release(oldWidget.log.operation.uuid);
      _exchange.forgetSerialState();
      unawaited(_exchange.refreshSerialPreviews());
    }
  }

  void _syncController(LoggingControls oldWidget) {
    if (oldWidget.session.controller != widget.session.controller) {
      oldWidget.session.controller?.detach();
      widget.session.controller?.attach(
        setField: _devSetField,
        submit: _log,
        wipe: _wipe,
        isFieldsLocked: () => _fieldsLocked,
        handleChord: _handleChord,
        focusCall: _callFocus.requestFocus,
        focusSecondaryControls: _ladder.focusPillAndOpen,
        focusLastPrimaryField: _ladder.focusLastPrimaryField,
      );
    }
  }

  void _syncRadioUpdates(LoggingControls oldWidget) {
    // The VFO notifier can be swapped with the widget (a different
    // HaLoServices in a harness, a future per-profile RadioService). Without
    // this the listener stays on the OLD notifier and `dispose` removes it
    // from the new one, so following dies and the old notifier keeps this
    // State alive.
    //
    // Before the editing guards in [didUpdateWidget], like [_syncController]
    // and for the same reason: re-subscribing is bookkeeping about which
    // notifier this State is attached to, not something a QSO being edited
    // gets a say in.
    // Below them it simply never ran while an edit was open.
    if (!identical(oldWidget.radio.radioUpdates, widget.radio.radioUpdates)) {
      oldWidget.radio.radioUpdates?.removeListener(_onRadioVfoChanged);
      widget.radio.radioUpdates?.addListener(_onRadioVfoChanged);
    }
  }

  /// A QSO opened for editing, or the edit ended. True when that was the
  /// update: the fields are a new context's, and nothing below applies.
  bool _syncEditingQso(LoggingControls oldWidget) {
    if (oldWidget.session.editingQso?.uuid != widget.session.editingQso?.uuid) {
      // Captured before _resetEditingSessionState() below, which clears
      // _draft.theirNameOverride — a snapshot taken after that would silently drop
      // a name entered via the More pane.
      if (oldWidget.session.editingQso == null && widget.session.editingQso != null) {
        _draft.snapshotComposing();
        // Parked with it, for the reason given at [_handleWipeTap]: the
        // reset below forgets which refs were a lookup's.
        _composingGuesses = _refs.takeGuessSnapshot();
      }
      _resetEditingSessionState();
      if (widget.session.editingQso != null) {
        _populateFromEditingQso(widget.session.editingQso!);
      } else {
        final composingSnapshot = _draft.takeComposingSnapshot();
        final composingGuesses = _composingGuesses;
        _composingGuesses = null;
        _resetLocalFields();
        // Overlaid back on top of the blank fields _resetLocalFields just
        // seeded.
        if (composingSnapshot != null) _restoreDraft(composingSnapshot, guesses: composingGuesses);
      }
      // Self- vs other-spot eligibility can differ per extension (e.g. only
      // self-spotting an operation with an activation ref) — re-fetch
      // whenever what's being spotted changes.
      _spotting.forgetSources();
      _spotting.refreshSources();
      // The fields are this panel's own again, which is exactly what anything
      // parked was waiting for — and [didUpdateWidget] stops here, so the
      // drain is this method's, not the end of the update's.
      _drainPending();
      return true;
    }
    return false;
  }

  /// While composing: the operation's refs changed, or a new suggestion
  /// arrived — and then whatever was parked waiting for the fields is
  /// applied, unless a tentative suggestion was left held.
  void _syncComposingInputs(LoggingControls oldWidget) {
    // While composing a new QSO, self-spot eligibility depends on the
    // operation's own activation refs (not editingQso, which stays null
    // throughout) — refresh when those refs change too.
    if (!identical(oldWidget.log.operation.data['refs'], widget.log.operation.data['refs'])) {
      _spotting.refreshSources();
    }

    // A new suggestion (e.g. tapping a different spot) — same reset scope
    // as [_syncEditingQso], applied for it instead. Deliberately independent
    // from the refs check just above (not `else if`),
    // so both can fire in the same call — e.g. an operation-refs change and
    // a spot tap landing in the same frame would otherwise let one silently
    // suppress the other.
    if (widget.session.suggestedQso != null && !identical(oldWidget.session.suggestedQso, widget.session.suggestedQso)) {
      // A gesture the operator can still drag back may not take the fields or
      // the VFO from work already in progress — [_syncSuggestionLifecycle]
      // held it instead, and anything parked stays parked with it.
      if (widget.session.suggestedQsoIsTentative && _hasComposedCall) return;
      _resetEditingSessionState();
      _applySuggestedQso(widget.session.suggestedQso!);
      _rememberSuggestedCall(tentative: widget.session.suggestedQsoIsTentative);
      _spotting.forgetSources();
      _spotting.refreshSources();
      // A suggestion means "work THIS station", so Enter must be able to log
      // it right away — the tap that produced it landed outside the logging
      // fields, leaving nothing focused for Enter to reach. Focus the
      // callsign field (cursor-at-end comes from its focus listener). Not on
      // mobile without a physical keyboard: there an uninvited virtual
      // keyboard would cover the call info the tap just surfaced
      // (docs/design/logging-fields.md's mobile carve-out).
      if (!isMobilePlatform || hardwareKeyboardAttached.value) _callFocus.requestFocus();
    }

    // A request held back until the edit it had to clear is gone — see
    // [_handleLogRequest]. By here `editingQso` is null, so the fields are
    // this panel's own again and the spot can take them.
    _drainPending();
  }

  /// Applies whatever was parked waiting for an edit to be gone — see
  /// [_handleLogRequest] and [_confirmHeldSuggestion].
  ///
  /// Called from BOTH [_syncEditingQso] and [_syncComposingInputs], because
  /// the update that clears the edit is the former, and `didUpdateWidget`
  /// stops there. Draining only at the end of an update leaves the work parked until some unrelated rebuild — a spot poll, a
  /// clock tick — picks it up seconds later, on top of whatever the operator
  /// has typed since, moving the VFO with it.
  void _drainPending() {
    if (widget.session.editingQso != null) return;
    final pending = _pendingLogRequest;
    if (pending != null) {
      _pendingLogRequest = null;
      unawaited(_applyAndLog(pending));
    }
    final pendingSuggestion = _pendingSuggestion;
    if (pendingSuggestion != null) {
      _pendingSuggestion = null;
      _applyTentativeSuggestion(pendingSuggestion);
    }
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

  /// Whether the call in the field is still exactly what a suggestion put
  /// there — nothing typed over it, nothing typed after it.
  bool get _callIsUntouchedSuggestion => _suggestedCall != null && _call == _suggestedCall;

  /// The row that made the tentative suggestion has closed. Its fill goes with
  /// it: leaving it there makes the next Log a contact with whoever was slid
  /// last.
  void _withdrawTentativeSuggestion() {
    _heldSuggestion = null;
    _pendingSuggestion = null;
    // Only a peek's own fill, and only while it is still exactly what the peek
    // put there: an entry the operator has typed over is theirs, and the row
    // that started it closing may not take it away.
    if (!_suggestionWasTentative || !_callIsUntouchedSuggestion) return;
    _suggestionWasTentative = false;
    // Focus stays where it is: pulling it here would raise the mobile keyboard
    // over the list the operator is still working. And behind [QsoDraft.populate],
    // which is what stops the clear from reaching `onCallEdited`: this runs
    // from didUpdateWidget, so the listener would report the operator editing
    // the field — from inside a build, to a view that has already built. Any
    // OTHER callback this wipe fires is under the same constraint.
    _draft.populate(() {
      _wipe(focusCall: false);
    });
  }

  /// Puts a held suggestion to the operator, and applies it if they clear the
  /// way. Declining keeps their work — [LoggingSession.confirmLogOverwrite] surfaces this
  /// panel so they land on it — and leaves the row to ask again if the
  /// gesture is carried through to a commit.
  Future<void> _confirmHeldSuggestion(Map<String, dynamic> qso) async {
    final editing = widget.session.editingQso != null;
    // The conflict is re-read here, not trusted from when the suggestion was
    // held: the operator may have logged, wiped or cancelled the edit in
    // between, and a prompt offering to clear an empty panel teaches them the
    // prompt means nothing.
    if (!editing && !_hasComposedCall) {
      _applyTentativeSuggestion(qso);
      return;
    }
    final clear = await _askOverwrite(editing: editing);
    if (!mounted || !clear) return;
    // Re-read AFTER the wait, because the wait is the point: the row that
    // raised this dialog can be closed or discarded while it is up, which
    // takes the suggestion back. Applying it anyway fills the fields and
    // retunes the radio for a row that no longer exists — and the withdrawal
    // has already been and gone, so nothing is left that could undo it.
    if (!identical(widget.session.suggestedQso, qso)) return;
    if (editing) {
      // Comes back as a widget update with `editingQso` null; the suggestion
      // waits for it rather than filling fields that still belong to the edit.
      widget.session.onEditCanceled?.call();
      _pendingSuggestion = qso;
      return;
    }
    _applyTentativeSuggestion(qso);
  }

  /// Puts [LoggingSession.confirmLogOverwrite]'s question to the operator,
  /// from OUTSIDE the frame that decided to ask it.
  ///
  /// Both askers run from `didUpdateWidget` — deliberately, so neither is
  /// swallowed by the editing guards there — which is the build phase, with
  /// the Navigator mid-flush. A route pushed into it from there trips the
  /// Navigator's own `!_debugLocked` assertion when the push animation lands,
  /// and what reaches the operator is a crash where the question should be.
  Future<bool> _askOverwrite({required bool editing}) {
    final confirm = widget.session.confirmLogOverwrite;
    if (confirm == null) return Future.value(false);
    final asked = Completer<bool>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        asked.complete(false);
        return;
      }
      // `Future.sync`, so a caller that throws BEFORE returning its future
      // still reaches the awaiting side. Left bare, a synchronous throw
      // escapes this callback with the completer unfinished, and everything
      // waiting on it waits forever: the contact the operator committed to
      // with a full slide is never logged, and nothing retries it (the
      // request's serial only changes once).
      asked.complete(Future.sync(() => confirm(editing: editing)));
    });
    return asked.future;
  }

  void _applyTentativeSuggestion(Map<String, dynamic> qso) {
    _resetEditingSessionState();
    _applySuggestedQso(qso);
    _rememberSuggestedCall(tentative: true);
  }

  /// Records what the suggestion just applied put in the call field, so
  /// [_callIsUntouchedSuggestion] can tell it apart from an entry the operator
  /// composed. Read back off the field rather than out of the QSO map: the
  /// field is what every other reader of this panel sees.
  void _rememberSuggestedCall({required bool tentative}) {
    _suggestedCall = _call.isEmpty ? null : _call;
    _suggestionWasTentative = tentative;
  }

  /// A [LoggingSession.logRequest] that is waiting for an edit to be
  /// cancelled before it can be applied. `onEditCanceled` reaches the parent
  /// and comes back as a widget update, so the fields are not this panel's to
  /// fill until that lands.
  Map<String, dynamic>? _pendingLogRequest;

  /// Handles a log request from outside — the spots list's slide.
  ///
  /// Runs BEFORE `didUpdateWidget`'s editing guards, deliberately: those
  /// return early whenever a QSO is selected for editing, which is an ordinary
  /// two-pane state, and a request swallowed there is a contact the operator
  /// was told had been logged. The serial only changes once, so nothing
  /// retries it.
  Future<void> _handleLogRequest(Map<String, dynamic> qso) async {
    final editing = widget.session.editingQso != null;
    if (editing || _hasComposedCall) {
      // Something here would be destroyed. Never silently: the operator is
      // looking at the spots list, and the work at risk is on a surface they
      // cannot see from there.
      final clear = await _askOverwrite(editing: editing);
      if (!mounted || !clear) return;
      if (editing) {
        // Comes back as a widget update with `editingQso` null; the request
        // waits for it rather than filling fields that still belong to the edit.
        widget.session.onEditCanceled?.call();
        _pendingLogRequest = qso;
        return;
      }
      // Same reasoning as `_applyAndLog`'s own wipe: the operator answered a
      // dialog raised over another surface, and is still standing on it.
      _wipe(focusCall: false);
    }
    await _applyAndLog(qso);
  }

  /// Fills the fields from [qso] and submits them, in that order and with no
  /// frame between: `_log` reads the live field state, so anything that let a
  /// build in between would log what the fields held before the spot landed.
  Future<void> _applyAndLog(Map<String, dynamic> qso) async {
    _resetEditingSessionState();
    _applySuggestedQso(qso);
    await _log(focusCall: false);
  }

  /// Editing-session bookkeeping that must never leak from one QSO context
  /// into the next.
  ///
  /// Called wherever the fields are about to be written from a record: the
  /// editingQso and suggestedQso paths in `didUpdateWidget`, and Revert,
  /// which reloads the record the operator is already on. That last one is
  /// why anything cleared here has to be something `QsoDraft.applyData`
  /// puts back from the record — Revert is a reload, not a fresh start, and
  /// a field reset here and restored by nothing would go missing from the
  /// contact with nothing said.
  void _resetEditingSessionState() {
    _pendingDelete = false;
    // Dropped with the undo slot that `resetSession` clears, so the two
    // cannot drift apart: provenance outliving the draft it belongs to is
    // the shape of the bug this whole pairing exists to prevent.
    _undoGuesses = null;
    _draft.resetSession();
  }

  /// Populates controllers/state from an existing QSO selected for editing.
  /// Local-state only — never calls parent-notifying callbacks (this runs
  /// from `didUpdateWidget`, where a synchronous `setState` back up the
  /// tree could throw).
  void _populateFromEditingQso(Qso qso) {
    _suggestedCall = null;
    _suggestionWasTentative = false;
    _draft.populate(() {
      _applyFieldsFromData(qso.data);
      if (qso.isEvent) {
        _applyEventFieldsFromData(qso.data);
        // An event's own freq/band/mode are sentinels (freq 0, mode the event
        // kind) — showing them on the Radio control would be meaningless.
        // Feed it the radio's actual current conditions instead, same as
        // composing a new QSO; never saved either way (`_eventDataForSave`
        // never reads these controllers).
        _seedFromRadioService();
      }
      _time.manualStartAtMillis = null; // _time.effectiveStartAtMillis falls back to editingQso.startAtMillis
      setState(() {});
    });
    // Score the edited QSO (excluding itself) so its dupe/New-* pills show, the
    // same way they do while composing — populate suppressed _onCallChanged's
    // own trigger. The worked-before pill likewise: an edit runs no live
    // lookup (the saved guess stands), so the lookup path never fetches it.
    _lookup.scheduleScore();
    _lookup.refreshWorkedBefore();
    // A QSO logged before its online lookup ever ran (e.g. offline, or a
    // quick log with the runtime still booting) should get one now rather
    // than sit unenriched until the next background pass — `enqueueLookup`
    // already skips QSOs that already have real (non-annotation-only)
    // lookup data, so this is a no-op for anything already enriched.
    widget.lookups.enqueueLookup?.call(qso);
  }

  /// Populates controllers/state from a `suggestedQso` map (e.g. tapping a
  /// spot) — same wrapping as `_populateFromEditingQso`, for a QSO being
  /// composed rather than an existing one being edited.
  ///
  /// A suggestion that carries no RST (spots never do today) leaves the
  /// fields blank, which is the composing default — `_rstPlaceholder` shows
  /// through it. One that DOES carry RST (`our.sent`/`their.sent` — e.g. a
  /// deeplink) keeps it, matching `_applyFieldsFromData`'s own behavior for
  /// editingQso.
  ///
  /// A `startAtMillis` on the suggestion becomes the MANUAL time, exactly as
  /// if the operator had typed it: a `/qso` deep link reports when a contact
  /// actually happened (a WSJT-X bridge hands over a QSO already made), and
  /// composing it at "now" would file it minutes late. A suggestion without
  /// one still clears the manual time — a spot says nothing about when, and
  /// must not inherit the last link's timestamp.
  void _applySuggestedQso(Map<String, dynamic> data) {
    _draft.populate(() {
      _applyFieldsFromData(data);
      // Read from `data`, since `_applyFieldsFromData` strips the key rather
      // than carrying it into `_draft.extra`.
      final suggestedStart = data['startAtMillis'];
      _time.manualStartAtMillis = suggestedStart is int ? suggestedStart : null;
      setState(() {});
    });
    // A tapped spot starts a contact as surely as a typed call does, and it
    // bypasses `_onCallChanged` — so the serial number is taken here.
    unawaited(_exchange.refreshSerialPreviews());
    // Populating a suggestion sets the call without the user typing, so
    // [QsoDraft.populate] suppressed _onCallChanged's own lookup and score
    // scheduling. Any source that sets the current QSO's callsign must
    // still trigger a lookup — spots (#315) and a future deeplink both arrive
    // here — so run them explicitly, like `_restoreFromUndoSlot` does.
    // The lookup was reset above, so the "only when changed" guard won't
    // wrongly short-circuit. Guarded on
    // `_callInfoActive` (a real call is present) so both only schedule their
    // timers and never setState synchronously — this also runs from initState
    // for a deeplink cold-start (see the editingQso init path above).
    if (_callInfoActive) {
      _scheduleLookup();
      _lookup.scheduleScore();
    }
    // A suggestion is specific operator intent — "work THIS station" — so
    // unlike the ambient VFO seed it overrides, it moves the VFO, and with
    // a radio connected (CAT) that retunes the radio itself. Tapping a
    // spot is the main way this happens.
    //
    // Only when the suggestion actually carried radio state: a bare
    // callsign (a deeplink, say) must not retune anything. And the push is
    // immediate rather than debounced — the operator picked a specific
    // station, there is nothing more to wait for.
    if (widget.session.editingQso == null && (data['freq'] != null || data['band'] != null || data['mode'] != null)) {
      _radio.cancelPendingPush();
      // AFTER the frame, not now. Both callers — initState and
      // didUpdateWidget — run inside the build phase, and `setVfo` notifies
      // its listeners synchronously; SpotsPanel listens and calls setState,
      // which Flutter refuses mid-build ("cannot be marked as needing to
      // build because the framework is already in the process of building
      // widgets"). ErrorPolicy classes that as logOnly, so it costs the
      // operator nothing visible and would have gone unnoticed — but the
      // panel can silently miss its rebuild for that frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _radio.pushVfo();
      });
    }
  }

  /// Shared by `_populateFromEditingQso` (loading an existing record for
  /// editing) and `_restoreFromUndoSlot` (undoing a wipe) — both need to
  /// push a `data` map from a `Qso`/[QsoDraft.toData] shape back into the
  /// live controllers/state. The draft does the fields and the models; what
  /// stays here is the panel's own context — the lookup, the open control,
  /// the command line.
  void _applyFieldsFromData(Map<String, dynamic> data, {bool restoringDraft = false}) {
    _draft.applyData(data, restoringDraft: restoringDraft);
    _lookup.reset();
    _selectedControlKey = null;
    // Command state must never survive into a freshly populated QSO
    // context: this runs under [QsoDraft.populate], so _onCallChanged's own
    // per-keystroke reset is suppressed. Without this, typing "NOTE hi",
    // then tapping a spot, would leave the call field showing a real
    // callsign while still in the note's mixed-case free-text mode — and a
    // stale complete interpretation would make Space insert a literal
    // space (or Enter execute the old command) instead of acting on the
    // callsign.
    _command.reset();
  }

  void _applyEventFieldsFromData(Map<String, dynamic> data) {
    final fields = eventFieldsFromData(data);
    _eventTextController.text = fields.text;
    _eventTodoDone = fields.done;
  }

  Map<String, dynamic> _eventDataForSave(Qso editingQso) =>
      eventDataForSave(editingQso, text: _eventTextController.text, done: _eventTodoDone, startAtMillis: _time.effectiveStartAtMillis);

  /// One of the panel's models changed something it paints — a typed
  /// frequency, a resolved lookup, a command's describe preview. None of
  /// them notifies during build (the Radio control's one build-phase write
  /// defers itself a frame), so a direct `setState` here is safe.
  void _onModelChanged() {
    if (!mounted) return;
    setState(() {});
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

  /// Clears local fields when an editing session ends (mirrors the
  /// local-state portion of `_wipe()`, without `_wipe()`'s parent callback —
  /// see `didUpdateWidget`).
  void _resetLocalFields() {
    // Guards _onCallChanged (fired synchronously by _callController.clear()
    // below) from calling widget.commands.onCommandMessageChanged — a parent-state
    // setState — while still inside didUpdateWidget.
    _draft.populate(() {
      _callController.clear();
      _clearRSTs();
      _gridController.clear();
      _stateController.clear();
      _draft.clear();
      _lookup.cancelLookup();
      // `_radio.freqTouched` outlives this reset otherwise, and live radio follow
      // stays switched off for the rest of the session.
      _radio.settlePendingFreqEdit(flush: false);
      _lookup.reset();
      _refs.clear();
      _exchange.clear();
      _notesController.clear();
      _time.manualStartAtMillis = null;
      _radio.manualBand = null;
      _selectedControlKey = null;
      _radio.clearPowerEntry();
      // Back to composing a new QSO — the Radio control goes back to
      // mirroring the operation's VFO, not whatever the just-edited QSO's
      // own freq/band/mode happened to be.
      _seedFromRadioService();
      setState(_command.reset);
    });
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

  /// The call field as the panel reads it — see [CallFieldText] for the
  /// rules. A fresh snapshot of the text and the cursor on every read, so a
  /// rule never sees a cursor that moved after the text it was paired with.
  CallFieldText get _callText => CallFieldText(_callController.text, cursor: _callController.selection.baseOffset, stacking: widget.session.editingQso == null);

  String get _call => _callText.call;
  List<String> get _callList => _callText.callList;
  bool get _isCallStackField => _callText.isStack;
  Iterable<String> get _callsInField => _callText.callsInField;
  String get _callAtCursor => _callText.callAtCursor;

  /// [qso] as a template reads it: plus `callField`, the calls
  /// [CallFieldText.templateCalls] names, which `qso.call` / `qso.nextCall` /
  /// `qso.nextPartial` render from — and `call` split by whether it reads as a
  /// callsign yet, into `fullCall` and `partial`, so a message can answer a
  /// station and ask a partial back ("KR?") without keying one as the other.
  /// Only for a draft leaving the panel to be rendered — `callField` is not
  /// QSON, and a record never carries it.
  static Map<String, dynamic> _withCallField(Map<String, dynamic> qso, TemplateCalls calls) {
    final full = calls.call.isNotEmpty && looksLikeCallsign(calls.call);
    return {
      ...qso,
      'callField': {
        'call': calls.call,
        'fullCall': full ? calls.call : '',
        'partial': full ? '' : calls.call,
        'nextCall': calls.nextCall,
        'nextPartial': calls.nextPartial,
      },
    };
  }

  /// The one call in the field, or empty when there is none or there are
  /// several — which is when an exchange may be prefilled for it.
  String get _singleCallInField {
    final calls = _callText.callsInField.toList();
    return calls.length == 1 ? calls.single : '';
  }

  /// The operation QSON with `uuid` folded in — same shape as the Dart
  /// side's `qsonPayloadFor` gives every coarse hook call. Command hooks
  /// need the uuid to fetch log data through the runtime's
  /// `ctx.getOperation`/`ctx.getQsos` (e.g. dev-commands' SEED reading the
  /// existing log's time range); the QSON alone doesn't carry it.
  Map<String, dynamic> get _operationDataForCommands => {...widget.log.operation.data, 'uuid': widget.log.operation.uuid};

  bool get _canLog {
    // Call stacking (issue #7): "//" takes priority over a comma-separated
    // list — "//"-separated calls/fragments aren't a single valid callsign,
    // but log is still possible as long as one of the stacked segments is —
    // see [CallFieldText.pickStackedCall]. Only while composing a new QSO.
    if (_isCallStackField) {
      return _callText.pickStackedCall() != null;
    }
    return _callList.isNotEmpty && _callList.every(isLoggableCall);
  }

  /// Note expansion inside a stack (issue #17 × issue #7): asks the command
  /// hooks to expand the segment under the cursor, and splices the result
  /// back into just that segment — "KI2D//1AB" becomes "KI2D//W1AB,W1AC",
  /// which the NEXT Enter logs as a stacked call list. Returns whether it
  /// expanded anything, in which case this Enter logs nothing at all.
  ///
  /// This exists because the ordinary command path ([CommandInterpretationModel.runOnEnter]) only ever sees the
  /// WHOLE field, so a key stacked alongside other calls would never be
  /// offered for expansion at all. A whole-field "//KEY" that path already
  /// expanded never arrives here — it returned. One it could not expand does
  /// arrive, asks the identical question, and gets the identical no.
  Future<bool> _expandStackedNote() async {
    if (widget.session.editingQso != null || widget.commands.interpretCommand == null || !_isCallStackField) return false;
    // Captured BEFORE the round trips below and reused for the splice, never
    // recomputed after them: the cursor can move without the text changing
    // (a click, an arrow key), and offsets taken afterwards would splice the
    // answer for the segment the hook was asked about into whichever segment
    // the cursor had since wandered into — destroying a call that was never
    // part of this expansion.
    final stack = _callText.stackSegments();
    final input = _command.expansionInputFor(stack);
    if (input == null) return false;
    final before = _callController.text;

    // Preview first (`execute: false`), same discipline as the whole-field
    // command path: this probe runs on EVERY stacked Enter, the ordinary
    // "K1ABC//W1AW" that expands nothing included, and an execute-time
    // interpretation is allowed side effects of its own — a network fetch, a
    // batch of generated QSOs (see CommandHook.interpret's `execute` doc).
    // Only once the preview says this really is an expansion is it worth
    // asking for the executable one, whose `commands` are the real ones.
    final preview = await _command.interpret(input);
    if (!mounted || _callController.text != before) return false;
    if (CommandInterpretationModel.expandedCallText(preview) == null) return false;

    final executable = await _command.interpret(input, execute: true);
    // Stale — the field changed while awaiting a JS runtime round trip, so
    // the captured segment offsets no longer describe this text.
    if (!mounted || _callController.text != before) return false;
    final text = CommandInterpretationModel.expandedCallText(executable);
    if (text == null) return false;

    final segments = [...stack.segments];
    segments[stack.cursorIndex] = text;
    // The cursor stays on the segment it expanded, at its end — that's the
    // segment the next Enter has to pick, and [CallFieldText.pickStackedCall] reads the
    // cursor to decide. Focus goes with it for the same reason: an unfocused
    // field reports no selection at all, and the fallback there is the LAST
    // segment, which in a three-segment stack is a different call entirely.
    _callController.value = TextEditingValue(
      text: segments.join('//'),
      selection: TextSelection.collapsed(offset: stack.starts[stack.cursorIndex] + text.length),
    );
    _callFocus.requestFocus();
    _command.markExpanded(input);
    return true;
  }

  void _onSentOrRcvdChanged() => setState(() {});

  /// The length each report field held last time it was looked at, so a jump
  /// can tell "the operator just finished a report" from "a full report is
  /// already sitting there".
  final Map<FocusNode, int> _rstLengthSeen = {};

  /// `jumpAfterRST`: move on the moment a report reaches [rstLengthFor],
  /// so a full exchange costs no Spaces.
  ///
  /// Deliberately fires on the **upward crossing** only, not on every keystroke
  /// at or above the length: correcting a report that is already complete —
  /// one just typed, or one loaded from a saved QSO — must not throw the
  /// operator out of the field on their first character.
  ///
  /// Hung off the controller rather than the field's `onChanged` for the
  /// mobile numbers row, which writes the controller directly
  /// ([_handleNumberKey]) and never reaches `onChanged` — and that row is
  /// where a setting saving a keypress earns its keep. `hasFocus` is what
  /// keeps this to real typing: every programmatic write (a wipe, a
  /// suggestion, the blur-time [expandRST]) happens to a field the operator
  /// is not in.
  void _maybeJumpAfterRST(FocusNode focus, TextEditingController controller) {
    final length = controller.text.trim().length;
    final previous = _rstLengthSeen[focus] ?? 0;
    _rstLengthSeen[focus] = length;
    if (!widget.prefs.jumpAfterRST || _draft.isPopulating || !focus.hasFocus) return;
    // Null on the FT modes, whose report has no fixed length — there is no
    // moment to call "done", so the setting simply doesn't apply.
    final full = rstLengthFor(_radio.mode);
    if (full == null) return;
    if (previous < full && length >= full) _ladder.advancePrimaryFocus();
  }

  void _clearRSTs() {
    _sentController.clear();
    _rcvdController.clear();
  }

  /// The report a blank Sent/Rcvd stands for, shown as a faint placeholder
  /// while the field is empty rather than pre-filled as a real value — the
  /// same "a default is not something the operator typed" rule the Grid and
  /// State guesses follow, so overtyping it never means clearing it first.
  ///
  /// Null while editing a saved record: there a blank field is stored data,
  /// not a stand-in, and filling it in would rewrite a QSO the operator only
  /// opened to look at. [_rstPlaceholder] and [_rstOrDefault] read the same
  /// condition on purpose — a hint that promised a value the save didn't
  /// write would be worse than no hint.
  String? get _rstPlaceholder => widget.session.editingQso == null ? _defaultRST : null;

  String get _defaultRST => defaultRSTFor(_radio.mode, phone: widget.prefs.defaultReport, cw: widget.prefs.defaultReportCW, snr: widget.prefs.defaultReportFT8);

  /// Where a report becomes what actually gets stored: the placeholder if the
  /// field is blank, otherwise the operator's own shorthand completed by
  /// [expandRST] (`5` → `55`, `57` → `579` on CW). Every consumer — the log,
  /// scoring, dupe checks, spotting, export — reads the RSTs through here.
  ///
  /// The expansion has to happen here as well as on losing focus: Enter never
  /// blurs (§ "Enter and focus"), so the field the operator logs from is one
  /// that never left focus, and a bare `5` would otherwise reach the record.
  String _rstOrDefault(String text) => text.isEmpty ? (_rstPlaceholder ?? '') : expandRST(text, _radio.mode);

  /// The two report fields in display order, which `switchSentRcvd` reverses.
  ///
  /// Every surface that shows both reads the order from here — the main row,
  /// the keyboard's path through it, and the More pane — so the row can never
  /// disagree with the order Space and Tab actually walk. Which controller is
  /// Sent and which is Rcvd never changes; only where each is drawn does.
  List<RstFieldSlot> get _rstPair {
    final pair = [
      (focus: _sentFocus, controller: _sentController, label: t.loggingControls.sent),
      (focus: _rcvdFocus, controller: _rcvdController, label: t.loggingControls.rcvd),
    ];
    return widget.prefs.switchSentRcvd ? pair.reversed.toList() : pair;
  }

  /// The More pane's own report fields, keyed by the form's field names rather
  /// than by controller — the pane round-trips values through a `Map`, not
  /// through [_rstPair]'s controllers, so it needs the order in its own terms.
  List<String> get _rstPaneKeyOrder => widget.prefs.switchSentRcvd ? const ['rcvd', 'sent'] : const ['sent', 'rcvd'];

  // ---- Secondary control row ----

  /// An exchange field's focus node fired: the ladder notes it, and a gain of
  /// focus lands the caret — the same cursor-at-end-on-focus rule the fixed
  /// primary fields get in initState. An exchange field is a main logging
  /// field too, and `selectAllOnFocus: false` alone only stops the
  /// select-all; it leaves the caret wherever it happened to be last.
  void _onExchangeFocusChanged(FocusNode node, TextEditingController controller) {
    _ladder.notePrimaryFocus(node);
    if (node.hasFocus) {
      controller.selection = TextSelection.collapsed(offset: _ladder.takePendingCaretOffset(node, controller) ?? controller.text.length);
    }
  }

  /// A per-QSO refresh just installed its controls: any `suggestedValue` a
  /// lookup produced can now fill fields the operator hasn't typed into, and
  /// the refreshed controls may have introduced a serial field, or changed
  /// the band a per-band sequence keys off.
  void _onActivityControlsRefreshed() {
    _exchange.applySuggestedValues(call: _singleCallInField);
    unawaited(_exchange.refreshSerialPreviews());
  }

  /// The field a control expands *into* — what the operator opened it to type
  /// in. Null for a control with nothing to type (Spotting with its comment
  /// hidden is just a button; `more` opens a pane instead of expanding), which
  /// leaves focus alone rather than yanking it somewhere useless.
  FocusNode? _expandedFocusFor(String? key) {
    if (key == null) return null;
    switch (key) {
      case 'time':
        return _time.timeFocus;
      // Frequency, not the Band dropdown: it is the field you actually type
      // into, and on touch platforms the dropdowns refuse focus outright.
      case 'radio':
        return _radio.freqFocus;
      case 'power':
        return _radio.powerFocus;
      case 'spotting':
        return _spotting.state.showComment ? _spotting.commentFocus : null;
      case 'notes':
        return _notesFocus;
      default:
        // Every remaining control is an extension's. Only `refList` builds a
        // field to focus — the same condition that gave it a chip.
        return _refs.isRefListControl(key) ? _refs.focusFor(key) : null;
    }
  }

  /// Every focusable field inside [key]'s expanded content that Tab/Shift-Tab
  /// step through before moving on to a neighbouring control, in the same
  /// left-to-right order they're laid out on screen. Distinct from
  /// [_expandedFocusFor]: that one is the SINGLE field opening the control
  /// focuses (Radio's is Frequency, not first here — landing there on the
  /// way in from Tab would skip Band entirely).
  ///
  /// Cursor keys do NOT walk this list field by field — see
  /// the ladder's cursor-key crossing — so Band and Mode being here only matters for
  /// Tab/Shift-Tab, which do still visit them.
  List<(FocusNode, TextEditingController)> _expandedFieldOrderFor(String key) {
    switch (key) {
      case 'time':
        return [(_time.timeFocus, _time.timeController), (_time.dateFocus, _time.dateController)];
      case 'radio':
        return [(_radio.bandFocus, _radio.bandController), (_radio.freqFocus, _radio.freqController), (_radio.modeFocus, _radio.modeController)];
      case 'power':
        return [(_radio.powerFocus, _radio.powerController)];
      case 'spotting':
        return _spotting.state.showComment ? [(_spotting.commentFocus, _spotting.commentController)] : const [];
      case 'notes':
        return [(_notesFocus, _notesController)];
      default:
        return _refs.isRefListControl(key) ? [(_refs.focusFor(key), _refs.controllerFor(key))] : const [];
    }
  }

  // ── The focus ladder: [LoggingFocusLadder] (logging_controls_ladder.dart).
  // What stays here is what the ladder cannot know: which fields are on the
  // row, what each control opens into, and opening a control.

  /// Shows (or, with null, hides) a control without moving focus — the
  /// ladder's crossings land on the field they chose; [LoggingFocusLadder
  /// .openControl] focuses after this. An event row refuses every control but
  /// Time here as well as on a tap: a Tab across the strip must not expand a
  /// control whose chip is disabled.
  void _showControl(String? key) {
    if (_editingEvent && key != null && key != 'time') return;
    setState(() {
      if (key == 'time' && _selectedControlKey != 'time') _time.seedFields();
      _selectedControlKey = key;
    });
  }

  /// A tap on a chip, or the keyboard arriving on one: what a tap means is
  /// the panel's — `more` pops the full-edit pane instead of expanding, and
  /// the chip itself already refuses a tap on an event row
  /// (ChoiceChip.onSelected: null, see _ControlChip), which this repeats for
  /// the keyboard paths. Everything else is the ladder's open and close.
  void _onSelectControl(String? key) {
    if (_editingEvent && key != null && key != 'time') return;
    if (key == 'more') {
      _openMoreEditor();
      return;
    }
    if (key == null) {
      _ladder.closeControl();
    } else {
      _ladder.openControl(key);
    }
  }

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

  /// Something is logging power for this QSO: the operator put the control
  /// in the row, or the app is capturing it with the rest of the station
  /// info. This is what lets a composed QSO carry a power at all — without
  /// it the field stays empty and nothing is stamped.
  bool get _powerInPlay => _catalog.powerVisible || widget.radio.trackingPower;

  /// The strip's specs, in row order, each carrying the panel's keyboard
  /// policy. Which controls appear is [_catalog]'s call; what each one shows
  /// is its model's.
  List<SecondaryControlSpec> _buildSecondaryControls(ThemeData theme, HaLoColors poloColors, {bool Function(String key)? enabledFor}) {
    final specs = <SecondaryControlSpec>[];
    for (final descriptor in _catalog.visibleControls()) {
      switch (descriptor.key) {
        case 'time':
          specs.add(timeControlSpec(_time));
        case 'radio':
          specs.add(
            radioControlSpec(
              _radio,
              theme,
              selected: _selectedControlKey == 'radio',
              freqInputFormatters: [_virtualSpace],
              freqKeyboardType: _decimalKeyboardType,
              onFreqSubmitted: () => _ladder.closeExpandedControl('radio'),
              onPicked: _callFocus.requestFocus,
            ),
          );
        case 'power':
          specs.add(powerControlSpec(_radio, keyboardType: _decimalKeyboardType));
        case 'spotting':
          specs.add(spottingControlSpec(_spotting, theme, poloColors));
        case 'notes':
          specs.add(notesControlSpec(theme, controller: _notesController, focusNode: _notesFocus, onChanged: _onNotesChanged));
        case 'more':
          specs.add(moreControlSpec());
        default:
          if (descriptor.activityControl case final control?) {
            specs.add(activityControlSpec(_refs, control, onRefsChanged: _relookupForRefsChanged, decorate: widget.activities.decorateRef));
          }
      }
    }
    // The strip's keys, for the arrow keys to walk. Recorded from the list
    // actually handed to the row, so the two can't drift apart.
    _ladder.pillOrder = [for (final spec in specs) spec.key];
    return [for (final spec in specs) _ladder.withKeyboardNavigation(spec, enabled: enabledFor?.call(spec.key) ?? true)];
  }

  /// The contact's own note. Wider than the other controls' fields — a note
  /// is a sentence, not a value — and explicitly mixed-case, like Name and
  /// the spot comment: free prose, not logging data.
  /// Keeps the QSO's `notes` in step with the field ([QsoDraft.setNote]),
  /// and the chip's check mark in step with both. The `setState` is also
  /// what pushes the draft up to the host: the post-frame notify in [build]
  /// runs on every rebuild.
  void _onNotesChanged(String value) => setState(() => _draft.setNote(value));

  // ---- Command shortcuts ----
  //
  // Space in the call field first tries the text as an extension command
  // (band/frequency/mode shortcuts live in the `radio-commands` extension;
  // see docs/extensions/hooks.md's `command` category). This is a real bridge
  // round-trip, not a Dart regex — command matching and frequency parsing
  // are extension/domain-library territory, not core UI territory.

  Future<void> _handleSpace() async {
    if (_callFocus.hasFocus) {
      // A field that accepts literal spaces stays escapable by the
      // double-space, and the test is the SAME one that decides the field
      // accepts them at all (see the call field's inputFormatters) — not the
      // interpretation's flags. There is a third way into free-text mode:
      // the expects-params rule's second arm, text that already holds a space.
      // A complete command reached that way ("EXP LA") carries neither
      // `expectsParams` nor `mixedCase`, so keying the exit to those flags
      // advanced focus while leaving the trailing space in the value.
      //
      // Ahead of the interpret round-trip below because the answer never
      // depended on it, and leaving a field shouldn't wait on a bridge call.
      if (_command.fieldAcceptsSpaces && _atTrailingSpace(_callController)) {
        _removeTrailingSpace(_callController);
        _ladder.advancePrimaryFocus();
        return;
      }
      final call = _call;
      // An empty call can't be a command — nothing to interpret, just
      // advance like every other field does when it's empty.
      if (call.isNotEmpty) {
        // While a recognized command prefix is waiting on its parameters
        // (e.g. "RELOAD"), space is a literal character to type, not the
        // advance-focus shortcut — see the `expectsParams` field on
        // CommandInterpretation. Ask the same question _log() asks on Enter,
        // synchronously (awaited) rather than trusting whatever the debounced
        // describe-preview last resolved to: that state can lag up to 150ms
        // behind the latest keystroke, so typing "RELOAD" and hitting space
        // in one fluent motion could otherwise still see the pre-keystroke
        // (stale, not-yet-a-command) interpretation and silently swallow the
        // space by advancing focus instead of inserting it. Reuses the
        // answer the debounce already resolved for this exact text, so this
        // only adds a round trip when genuinely needed.
        if (widget.session.editingQso == null && widget.commands.interpretCommand != null) {
          final (interpretation: result, :stale) = await _command.interpretNow(applyToDisplay: true);
          if (stale || !mounted) return; // stale — the call changed while awaiting
          // A complete mixedCase command (e.g. "NOTE Hello") also keeps
          // space literal — its free-prose parameter is still being typed.
          if (result != null && (result['expectsParams'] == true || result['mixedCase'] == true)) {
            // The exit gesture was already handled above; anywhere else in the
            // value a space is a literal parameter character.
            _insertAtCursor(_callController, ' ');
            return;
          }
        }
      }

      _ladder.advancePrimaryFocus();
    } else if (_radio.freqFocus.hasFocus) {
      _callFocus.requestFocus();
    } else if (_ladder.primaryFocusOrder.any((node) => node.hasFocus)) {
      // An options field accepts the highlighted suggestion first, then advances
      // like everything else. The advance is unconditional either way: it is what
      // an operator's hands expect, and losing it to a field that happens to be
      // searchable would be worse than never suggesting at all.
      //
      // Having walked the highlight with the arrow keys IS a choice, so Space
      // then takes that row as-is; an untouched highlight is still the app
      // guessing, and stays held to the prefix rule.
      _exchange.acceptOnLeave();
      // Every primary field advances on Space, contest exchanges included —
      // asked against the same list the advance walks, so a newly added kind of
      // primary field can never end up in one and not the other. (Call and Freq
      // are caught above; neither is reachable here.)
      _ladder.advancePrimaryFocus();
    } else if (_spotting.commentFocus.hasFocus) {
      // Free prose, like NOTE's parameter: Space types a literal space —
      // the panel-wide shortcut would otherwise swallow it.
      _insertAtCursor(_spotting.commentController, ' ');
    } else if (_notesFocus.hasFocus) {
      // A note is a sentence, so the same applies with more force: without
      // this the panel's Space binding eats every word break and the operator
      // types "Ran5Wtoawire". Unlike the call field there is no advance
      // gesture to preserve — Notes is a secondary control, and the keyboard
      // leaves it by Tab, the arrows or Enter.
      _insertAtCursor(_notesController, ' ');
      _onNotesChanged(_notesController.text);
    }
    // Space is inert in any other field with no override of its own.
    // RefTextInput is the one exception — it binds Space locally to type a
    // literal separator instead, taking priority over this panel-wide
    // shortcut.
  }

  /// The primary fields currently on screen, in the left-to-right order
  /// they're laid out in — Call, Sent/Rcvd (when RST is on), the contest
  /// exchanges, then State/Grid (when their "..." menu toggles are on).
  ///
  /// The single source of truth for what "a primary field" means to the
  /// keyboard: [LoggingFocusLadder.advancePrimaryFocus] walks it, `_handleSpace`
  /// asks it whether Space should advance, and
  /// [LoggingFocusLadder.onPrimaryFieldKeyEvent] reads it for Tab's
  /// walk and the arrow keys' end-of-value traversal. Any new kind of
  /// primary field is in all of them the moment it appears here — an exchange
  /// field that cycled on Tab but sat inert on Space (because only Space's
  /// caller had a hardcoded list) is exactly the drift this prevents.
  ///
  /// Paired with each field's controller, since Tab and the arrows have to read
  /// the caret and the value, not just move focus.
  ///
  /// Rebuilt on every call: `showRSTFields`/`showStateField`/`showGridField`
  /// change at runtime, and so does the set of contest controls.
  List<PrimaryField> get _primaryFields => [
    (key: 'call', label: t.loggingControls.theirCall, focus: _callFocus, controller: _callController, hint: null, skipFocus: false),
    // Display order, not Sent-then-Rcvd: the keyboard walks the row the
    // operator is looking at (see [_rstPair]).
    if (widget.prefs.showRSTFields)
      for (final field in _rstPair)
        (
          key: identical(field.controller, _sentController) ? 'sent' : 'rcvd',
          label: field.label,
          focus: field.focus,
          controller: field.controller,
          hint: _rstPlaceholder,
          skipFocus: false,
        ),
    // Only nodes already attached to a built field: creating one here for a
    // control whose widget hasn't been built leaves an orphan with no
    // context, which Flutter's focus traversal null-checks while sorting —
    // taking down the whole frame rather than just misordering focus.
    for (final control in _textControls)
      if (_exchange.attachedFocusFor(control['key'] as String) case final focus?)
        (
          key: control['key'] as String,
          label: (control['label'] as String?) ?? control['key'] as String,
          focus: focus,
          controller: _exchange.controllerFor(control['key'] as String),
          hint: (control['input'] as Map?)?['placeholder'] as String?,
          skipFocus: control['skipFocus'] == true,
        ),
    if (widget.prefs.showStateField)
      (key: 'state', label: t.qsoEditForm.theirState, focus: _stateFocus, controller: _stateController, hint: _guessStateHint, skipFocus: false),
    if (widget.prefs.showGridField)
      (key: 'grid', label: t.qsoEditForm.theirGrid, focus: _gridFocus, controller: _gridController, hint: _guessGridHint, skipFocus: false),
  ];

  /// Whether the caret sits at the end of a value that already ends in a space
  /// — the double-space that exits a field which otherwise accepts spaces (see
  /// `_handleSpace`'s free-text branch and [VirtualSpaceFormatter]).
  static bool _atTrailingSpace(TextEditingController controller) {
    final selection = controller.selection;
    return controller.text.endsWith(' ') && selection.isCollapsed && selection.baseOffset == controller.text.length;
  }

  /// Drops the space [_atTrailingSpace] found, so the value the operator leaves
  /// behind carries neither it nor the one they just typed to get out.
  static void _removeTrailingSpace(TextEditingController controller) {
    final text = controller.text.substring(0, controller.text.length - 1);
    controller.value = controller.value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
  }

  /// Synthesizes typing [text] at the cursor — used for the literal space in
  /// _handleSpace's expectsParams branch, since that space is consumed by a
  /// CallbackShortcuts binding and never reaches the field as an ordinary
  /// keystroke. `composing` is deliberately reset to empty: this only runs
  /// while ASCII command text (a space) is being inserted, so there's no
  /// in-progress IME composition of our own to preserve, but explicitly
  /// clearing it (rather than leaving whatever the platform last reported)
  /// avoids carrying over a stale composing range from unrelated typing.
  void _insertAtCursor(TextEditingController controller, String text) {
    final value = controller.value;
    final selection = value.selection;
    final start = selection.start < 0 ? value.text.length : selection.start;
    final end = selection.end < 0 ? value.text.length : selection.end;
    final newText = value.text.replaceRange(start, end, text);
    controller.value = value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: start + text.length),
      composing: TextRange.empty,
    );
  }

  // ── Mobile numbers row (issue #27) ──────────────────────────────────────

  /// The logging fields the numbers row can type into, each paired with its
  /// controller. The primary text fields only — Freq/Time (behind the
  /// secondary control row) already raise their own numeric keyboards, where
  /// a digits row would be redundant. Fields that aren't currently shown
  /// never hold focus (their TextField isn't built), so listing them all
  /// unconditionally is safe. Built once — the FocusNode/controller
  /// references are stable; focus is read live via `.hasFocus`.
  late final List<(FocusNode, TextEditingController)> _numberKeyFields = [
    (_callFocus, _callController),
    (_sentFocus, _sentController),
    (_rcvdFocus, _rcvdController),
    (_stateFocus, _stateController),
    (_gridFocus, _gridController),
  ];

  /// Whichever numbers-row field currently holds focus, or null — the target
  /// for an inserted key and the gate for showing the bar at all.
  (FocusNode, TextEditingController)? get _focusedNumberField {
    for (final field in _numberKeyFields) {
      if (field.$1.hasFocus) return field;
    }
    return null;
  }

  /// The contextual extra key: "/" only while the call field holds a partial
  /// callsign (a letter present, not a bare number — a serial being typed
  /// ahead of letters still reads as numeric), the operator's own decimal
  /// separator for every numeric field. Null when the extra key is turned
  /// off. Mirrors app-polo's callsign vs numbers mode split
  /// (H2kCallsignInput / H2kRSTInput).
  ///
  /// It types whatever [parseFreq] will read back as a decimal point: a key
  /// that inserted a fixed "." under comma conventions would produce a
  /// frequency the field beneath it parses as grouping, silently landing the
  /// operator on a different band.
  String? get _numbersRowExtraKey {
    if (!widget.prefs.showExtraInNumbersRow) return null;
    if (_callFocus.hasFocus) {
      final text = _callController.text;
      final hasLetter = RegExp(r'[A-Za-z]').hasMatch(text);
      final onlyDigits = RegExp(r'^[0-9]+$').hasMatch(text);
      if (hasLetter && !onlyDigits) return '/';
    }
    return NumberFormatting.instance.decimalSeparator;
  }

  /// The Grid field's hint — see [guessGridDisplay], which the More pane's
  /// own Grid field hints through too so the two can never show different
  /// squares for one station.
  String? get _guessGridHint => guessGridDisplay(_currentGuess);

  /// The guessed state (e.g. from a callsign lookup), shown as a faint
  /// placeholder while the State field is empty — never pre-filled as a
  /// real value.
  String? get _guessStateHint => _currentGuess?['state'] as String?;

  /// Inserts a numbers-row key at the focused field's cursor. `_insertAtCursor`
  /// writes the controller value directly, which fires the controller
  /// listeners (lookup/dupe/rebuild) but NOT the TextField's `onChanged` — so
  /// the "touched" flags those onChanged handlers set are replicated here,
  /// else a tapped digit wouldn't mark Grid/State as user-edited.
  void _handleNumberKey(String key) {
    final field = _focusedNumberField;
    if (field == null || _fieldsLocked) return;
    final (focus, controller) = field;
    _insertAtCursor(controller, key);
    if (identical(focus, _callFocus)) {
      widget.session.onCallTyped?.call();
    } else if (identical(focus, _gridFocus)) {
      _draft.markGridTouched();
    } else if (identical(focus, _stateFocus)) {
      _draft.stateTouched = true;
    }
  }

  /// Rebuilds so the bar's visibility and contextual "/"→"." key track the
  /// focused field. Only runs while the feature is on, so it costs nothing
  /// otherwise.
  void _rebuildForNumbersRow() {
    if (!widget.prefs.showNumbersRow) return;
    rebuildBetweenFrames();
  }

  Future<void> _dispatchActions(List<dynamic> actions, {bool skipOnlineLookup = false}) async {
    // QSOs added by this batch of actions (e.g. one SEED run) — handed to
    // enqueueAllLookups as a single batch once every action has been
    // dispatched, rather than queued one at a time as they're added. Skipped
    // entirely when [skipOnlineLookup] is set (SEED).
    final addedQsos = <Qso>[];
    for (final action in actions) {
      if (action is! Map) continue;
      final map = action.cast<String, dynamic>();

      if (map.containsKey('setVfo')) {
        final params = map['setVfo'] as Map;
        // A command's setVfo is already validated by the extension — push
        // it to radioService immediately rather than debouncing like raw
        // frequency typing. [QsoDraft.populate] suppresses the frequency listener's own
        // (debounced) push, which would otherwise also fire from the
        // controller text assignment below.
        _draft.populate(() {
          setState(() {
            final freq = params['freq'];
            final band = params['band'];
            final mode = params['mode'];
            if (freq is num) {
              _radio.setFrequency(freq.toDouble());
            } else if (band is String) {
              _radio.setBand(band);
            }
            if (mode is String) {
              // Resolved like every other mode REQUEST. The command is the last
              // path that reached here raw, and while editing an existing QSO
              // `_onRadioVfoChanged` returns early, so nothing downstream would
              // have corrected a generic `SSB` before it was logged.
              _radio.mode = _radio.resolveMode(mode);
            } else if (freq is num) {
              // HALO-32: the frequency command (typing "14285 " into the call
              // field) doesn't carry a mode of its own — guess it from the
              // band plan, same as typing directly into the Frequency field.
              // Unlike that field, this fires once per dispatched command with
              // a final, already-complete frequency — no mid-typing prefix to
              // guard against — so a null guess simply leaves `_radio.mode` alone.
              final guess = modeForFrequency(freq.toDouble(), ituRegion: widget.radio.ourItuRegion, countryCode: widget.radio.ourCountryCode);
              if (guess != null) _radio.applyModeGuess(guess);
            }
          });
        });
        if (params['freq'] is num || params['band'] is String || params['mode'] is String) {
          _radio.pushVfo();
        }
        // The command changed band/mode/freq under [QsoDraft.populate], which
        // suppressed the field listeners' own rescore — refresh the call-info
        // notices (New Band / New Mode / dupe) for the new radio state.
        _lookup.scheduleScore();
      } else if (map.containsKey('updateQso')) {
        final params = (map['updateQso'] as Map).cast<String, dynamic>();
        setState(() {
          _draft.extra.addAll(params);
        });
      } else if (map.containsKey('addQso')) {
        final params = (map['addQso'] as Map).cast<String, dynamic>();
        final qso = await widget.log.qsosRepository.add(widget.log.operation.uuid, await _decorated(params));
        widget.log.onLogged?.call(qso);
        // Command-added QSOs (e.g. SEED's batch) carry at most the fast
        // offline guess the extension attached itself as part of adding
        // them — collected here for a single trailing enqueueAllLookups
        // call once the whole batch of actions has been dispatched.
        addedQsos.add(qso);
      } else if (map['updateSettings'] is Map) {
        // A settings write is the app's, like every other named action; the
        // panel holds no settings engine of its own.
        await widget.commands.onCommandAction?.call('updateSettings', (map['updateSettings'] as Map).cast<String, dynamic>());
      } else if (map['setCallField'] is Map) {
        // Note expansion (`//KEY`, issue #17): the interpreted command
        // replaces the call field wholesale. Set text and selection in one
        // assignment so the cursor lands at the end, and let the ordinary
        // _onCallChanged path react (lookup, dupe, comma-list handling) —
        // exactly as if the expansion had been typed.
        final params = (map['setCallField'] as Map).cast<String, dynamic>();
        final text = params['text'] as String? ?? '';
        _callController.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
        _callFocus.requestFocus();
      } else if (map.containsKey('syncAll')) {
        await widget.commands.onCommandAction?.call('syncAll');
      } else if (map['purgeTests'] is Map) {
        await widget.commands.onCommandAction?.call('purgeTests', (map['purgeTests'] as Map).cast<String, dynamic>());
      } else if (map['sendSpots'] is Map) {
        // Resolving *who* gets spotted stays here (this widget owns
        // `qsos`/`editingQso`/`radioService`) — the command hook only
        // parsed text into a comment + target. 'last' (SPOTLAST family)
        // spots the most recent real (non-event) QSO regardless of what's
        // being edited; 'self' (default) spots the operation itself at the
        // current VFO. `qsos` is oldest-first (see `watchForOperation`), so
        // the last real contact is `lastWhere`, not `firstWhere`.
        final params = (map['sendSpots'] as Map).cast<String, dynamic>();
        final target = params['target'] as String? ?? 'self';
        final comment = params['comment'] as String?;
        Qso? qso;
        if (target == 'last') {
          qso = widget.log.qsos.cast<Qso?>().lastWhere((q) => q!.isRealContact, orElse: () => null);
        }
        final vfo = widget.radio.radioService?.vfoA;
        await widget.commands.onCommandAction?.call('sendSpots', {
          'operation': _spotting.operationPayload,
          'target': target,
          if (qso != null) 'qso': qso.data,
          'comment': ?comment,
          if (qso == null) 'freq': vfo?.freq,
          if (qso == null) 'mode': vfo?.mode,
        });
      } else if (map['devNotice'] is Map) {
        await widget.commands.onCommandAction?.call('devNotice', (map['devNotice'] as Map).cast<String, dynamic>());
      } else if (map['devStatus'] is Map) {
        await widget.commands.onCommandAction?.call('devStatus', (map['devStatus'] as Map).cast<String, dynamic>());
      } else if (map['devProgress'] is Map) {
        await widget.commands.onCommandAction?.call('devProgress', (map['devProgress'] as Map).cast<String, dynamic>());
      } else if (map['devHammer'] is Map) {
        await widget.commands.onCommandAction?.call('devHammer', (map['devHammer'] as Map).cast<String, dynamic>());
      } else if (map['devSplash'] is Map) {
        await widget.commands.onCommandAction?.call('devSplash');
      } else if (map['devOnboard'] is Map) {
        await widget.commands.onCommandAction?.call('devOnboard');
      } else if (map['devTester'] is Map) {
        await widget.commands.onCommandAction?.call('devTester');
      } else if (map['devPopup'] is Map) {
        await widget.commands.onCommandAction?.call('devPopup');
      } else if (map['devTimeTravel'] is Map) {
        await widget.commands.onCommandAction?.call('devTimeTravel', (map['devTimeTravel'] as Map).cast<String, dynamic>());
      } else if (map['devBench'] is Map) {
        await widget.commands.onCommandAction?.call('devBench', (map['devBench'] as Map).cast<String, dynamic>());
      } else if (map['devLogCat'] is Map) {
        await widget.commands.onCommandAction?.call('devLogCat');
      } else if (map['devMapInfo'] is Map) {
        await widget.commands.onCommandAction?.call('devMapInfo');
      } else if (map['devIdle'] is Map) {
        await widget.commands.onCommandAction?.call('devIdle');
      } else if (map['reloadDataFiles'] is Map) {
        await widget.commands.onCommandAction?.call('reloadDataFiles', (map['reloadDataFiles'] as Map).cast<String, dynamic>());
      } else if (map['toggleExperiment'] is Map) {
        await widget.commands.onCommandAction?.call('toggleExperiment', (map['toggleExperiment'] as Map).cast<String, dynamic>());
      } else if (map['updateSetting'] is Map) {
        await widget.commands.onCommandAction?.call('updateSetting', (map['updateSetting'] as Map).cast<String, dynamic>());
      } else if (map['openSettings'] is Map) {
        await widget.commands.onCommandAction?.call('openSettings', (map['openSettings'] as Map).cast<String, dynamic>());
      } else if (map['updateOperation'] is Map) {
        // The uuid is added here because only this widget knows which
        // operation is open; the app owns the write, since the operator
        // callsign and the position land in different columns.
        await widget.commands.onCommandAction?.call('updateOperation', {
          ...(map['updateOperation'] as Map).cast<String, dynamic>(),
          'uuid': widget.log.operation.uuid,
        });
      } else if (map['markSegment'] is Map) {
        // Same shape as updateOperation: this widget names the open
        // operation, the app writes the event rows (and opens the location
        // screen for ROVERQTH).
        await widget.commands.onCommandAction?.call('markSegment', {...(map['markSegment'] as Map).cast<String, dynamic>(), 'uuid': widget.log.operation.uuid});
      } else if (map['setPower'] is Map) {
        // No QSO-scoped widget state of its own — same dispatch shape as
        // updateSetting/openSettings above, straight through to the app layer.
        await widget.commands.onCommandAction?.call('setPower', (map['setPower'] as Map).cast<String, dynamic>());
      } else if (map['setKeyerSpeed'] is Map) {
        // Same as setPower: radio1's keyer, nothing of this widget's.
        await widget.commands.onCommandAction?.call('setKeyerSpeed', (map['setKeyerSpeed'] as Map).cast<String, dynamic>());
      } else if (map['showKeyer'] is Map) {
        await widget.commands.onCommandAction?.call('showKeyer', null);
      } else if (map['setEnterSends'] is Map) {
        await widget.commands.onCommandAction?.call('setEnterSends', (map['setEnterSends'] as Map).cast<String, dynamic>());
      } else {
        // Nothing above recognized this action's key(s) — most likely a new
        // CommandAction field was added to the SDK (extensions/sdk/src/types.ts)
        // without a matching branch here, which otherwise fails completely
        // silently: the command interprets fine and this method just no-ops.
        // See the regression test for `reloadDataFiles` shipping without this
        // branch, above.
        debugPrint('[extensions] no dispatch branch for command action: ${map.keys}');
      }
    }
    if (addedQsos.isNotEmpty && !skipOnlineLookup) {
      widget.lookups.enqueueAllLookups?.call(addedQsos);
    }
  }

  // ---- "More" full-edit pane ----
  //
  // The form's shape — its sections, its fields and the rules about which of
  // them appear — lives in qso_edit_pane.dart. What is left here is applying
  // what comes back, which is the half that needs the controllers and the
  // override maps.

  Future<void> _openMoreEditor() async {
    final millis = _time.effectiveStartAtMillis;
    final dt = millis != null ? DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true) : nowUtc();
    // Captured so the Save handler below can tell "the user actually edited
    // Grid/State in this pane" from "the pane merely displayed whatever
    // was already there" — the latter must not turn a passive lookup guess
    // into a deliberately-touched, sticky value (see _draft.gridTouched's doc).
    final gridBeforePane = _gridController.text.trim();
    final stateBeforePane = _stateController.text.trim();
    // Same displayed-vs-edited distinction for date/time: while composing,
    // the pane shows the live clock, and saving an untouched value must
    // not turn it into a manual override that freezes auto-timestamping.
    final dateBeforePane = TimeControlModel.fmtDate(dt);
    final timeBeforePane = TimeControlModel.fmtTime(dt);
    // What the contact itself says, override included — never the operation's
    // stand-in, which is only ever a placeholder here.
    final ourBeforePane = {...?asQsonMap(widget.session.editingQso?.data['our']), ..._draft.ourExtra};
    final operatorBeforePane = (asQsonString(ourBeforePane['operatorCall']) ?? '').trim();
    final positionBeforePane = (asQsonString(ourBeforePane['multiIdentifier']) ?? '').trim();
    // The same displayed-vs-edited distinction once more, for every `their`
    // field the pane owns outright: a value merely shown must not be recorded
    // as an override, or a contact opened and saved would take its lookup's
    // guesses as entered values and stop tracking the lookup.
    final theirBeforePane = {...?asQsonMap(widget.session.editingQso?.data['their']), ..._draft.theirExtra};
    final theirValuesBeforePane = theirPaneValues(theirBeforePane);

    final result = await showQsoEditPane(
      context,
      gridBeforePane: gridBeforePane,
      formDefinition: buildQsoEditFormDefinition(
        defaultOperatorCall: widget.prefs.defaultOperatorCall,
        defaultPosition: widget.prefs.defaultPosition,
        showPositionField: widget.prefs.showPositionField,
        their: asQsonMap(widget.session.editingQso?.data['their']),
        guess: _currentGuess,
        rstPaneKeyOrder: _rstPaneKeyOrder,
        rstPlaceholder: _rstPlaceholder,
        powerShown: _draft.powerShown,
        composing: widget.session.editingQso == null,
        currentMode: _radio.modeForEditing,
      ),
      initialState: {
        'theirCall': _call,
        // Entered name only (not the `theirName` getter, which coalesces in the
        // guess) so a guessed-only name shows as the placeholder above instead
        // of being pre-filled — and merely viewing the pane never promotes a
        // passive guess to a sticky entered value.
        'theirName': _draft.theirNameOverride ?? asQsonString(asQsonMap(widget.session.editingQso?.data['their'])?['name']) ?? '',
        'theirGrid': gridBeforePane,
        'theirState': stateBeforePane,
        'sent': _sentController.text.trim(),
        'rcvd': _rcvdController.text.trim(),
        'freq': _radio.freq,
        'band': _radio.band ?? '',
        'mode': _radio.modeForEditing,
        'power': _draft.powerWatts,
        'date': TimeControlModel.fmtDate(dt),
        'time': TimeControlModel.fmtTime(dt),
        'notes': (_draft.extra['notes'] as String?) ?? '',
        'operatorCall': operatorBeforePane,
        if (widget.prefs.showPositionField) 'multiIdentifier': positionBeforePane,
        ...theirValuesBeforePane,
        // Shown, never taken: `theirEntity` is `disabled`, and the save
        // handler below reads nothing back out of it.
        'theirEntity': theirEntityDisplay(asQsonMap(widget.session.editingQso?.data['their']), _currentGuess) ?? '',
      },
    );
    if (result == null || !mounted) return;

    // Same as the setVfo command dispatch: a deliberate pane Save, not
    // raw typing — push immediately rather than via the frequency field's
    // debounce, and only while composing (rule: editing an existing QSO
    // applies changes to the QSO, never the VFO).
    _draft.populate(() {
      setState(() {
        _callController.text = ((result['theirCall'] as String?) ?? '').toUpperCase();
        final name = (result['theirName'] as String?)?.trim();
        _draft.theirNameOverride = (name == null || name.isEmpty) ? null : name;
        final grid = normalizeGrid(((result['theirGrid'] as String?) ?? '').trim());
        final state = ((result['theirState'] as String?) ?? '').trim().toUpperCase();
        // Normalized comparison, not raw string inequality: the pane's
        // uppercase formatter rewrites the WHOLE field on any keystroke, so
        // a net no-op edit over a lookup-guessed 'FN31pr' would come back
        // 'FN31PR' and a raw compare would falsely promote the passive guess
        // to a sticky touched override (see [QsoDraft.gridTouched]). Case is not
        // a deliberate edit; only a real value change is.
        // Through [QsoDraft.markGridTouched], not a bare flag: the pane's on-screen
        // coordinate clear runs on BLUR (`FormRenderer` hangs `onChange` off the
        // focus node), and `submit()` snapshots its values before the unfocus it
        // triggers has been delivered — so a grid typed and then saved with
        // Enter, or with the field still focused, reaches here with the
        // coordinate fields never blanked and no override recorded to blank
        // them. The drop has to happen on the value that was actually saved.
        if (grid != normalizeGrid(gridBeforePane)) _draft.markGridTouched();
        _draft.stateTouched = _draft.stateTouched || state != stateBeforePane.toUpperCase();
        _gridController.text = grid;
        _stateController.text = state;
        _sentController.text = (result['sent'] as String?) ?? '';
        _rcvdController.text = (result['rcvd'] as String?) ?? '';

        final freq = result['freq'];
        if (freq is num) {
          _radio.setFrequency(freq.toDouble());
        } else {
          final band = (result['band'] as String?)?.trim();
          _radio.setBand((band == null || band.isEmpty) ? null : band);
        }

        // Resolved against the freq/band the pane just wrote above, like every
        // other mode PICK, and never skipped for an untouched select: the pane
        // can move the frequency, and an untouched `SSB` has to re-derive
        // against where the contact now is. Lossless because the rule is total
        // — see docs/design/cat.md's "Showing it back".
        final panedMode = result['mode'] as String?;
        if (panedMode != null) _radio.mode = _radio.resolveMode(panedMode);

        // Written even when the pane didn't offer the field: absent means the
        // form dropped it, and `result` then carries a null this must not read
        // as the operator clearing a value they were never shown.
        if (result.containsKey('power')) {
          final power = result['power'];
          _radio.powerController.text = power is num ? '$power' : '';
        }

        final stamped = paneStartAtMillis(result, dateBeforePane, timeBeforePane);
        if (stamped != null) _time.manualStartAtMillis = stamped;

        final notes = ((result['notes'] as String?) ?? '').trim();
        _draft.setNote(notes);
        // The Notes control shows the same value; without this it would go on
        // showing what the contact said before the pane was opened.
        _notesController.text = notes;

        _draft.theirExtra.addAll(theirPaneOverrides(result, theirValuesBeforePane));

        // Recorded only where the pane actually changed them, so a contact
        // merely opened and saved keeps taking the operation's stamp — and an
        // emptied field records the empty string, which the stamp then leaves
        // alone (it fills what is absent).
        // Compared uppercased on both sides, like the grid two blocks up: the
        // pane's callsign field rewrites the whole field in uppercase, so a
        // record whose stored operator came in lowercase (an ADIF import's
        // OPERATOR, a peer from another client) would otherwise record an
        // override — and read as composed — from merely being opened.
        final operatorCall = ((result['operatorCall'] as String?) ?? '').trim().toUpperCase();
        if (operatorCall != operatorBeforePane.toUpperCase()) _draft.ourExtra['operatorCall'] = operatorCall;
        if (widget.prefs.showPositionField) {
          final position = panePosition(result['multiIdentifier']);
          if (position != positionBeforePane) _draft.ourExtra['multiIdentifier'] = position;
        }

        _time.seedFields();
      });
    });
    if (widget.session.editingQso == null) {
      // Power first: the frequency push notifies, and the seed that follows
      // rewrites the power field from the VFO — which would put the value
      // the pane just returned back to whatever it was before the pane
      // opened, and then commit THAT.
      _radio.commitPower();
      _radio.pushVfo();
    }
  }

  // ---- Secondary control settings (show/hide + reorder) ----

  Future<void> _openControlSettingsDialog() async {
    final result = await showControlSettingsDialog(context, _catalog);
    if (result == null) return;
    widget.strip.onControlsSettingsChanged?.call(result.$1, result.$2);
  }

  // ---- Lookup enrichment ----

  /// Alphanumeric length of the call about to be logged — the call-info panel
  /// and its live scoring switch on at ≥3 characters (issue #40).
  int get _callInfoAlnumLength => _callAtCursor.replaceAll(RegExp('[^A-Z0-9]'), '').length;
  bool get _callInfoActive => _callInfoAlnumLength >= 3;

  void _onCallChanged() {
    if (_draft.isPopulating) return;
    // Past the guard, the change is the operator's own — typing, or the clear
    // that `_wipe` does — which is exactly what the spots list wants to hear
    // about. A suggestion filling the field never reaches here.
    widget.session.onCallEdited?.call();
    // Before anything else reacts: a prefill made for the call that just
    // changed must not outlive it, whether or not the new call's lookup and
    // refresh ever land.
    _exchange.withdrawSuggestionsExcept(call: _singleCallInField);
    setState(() {});
    // The first character of a call is what takes a serial number.
    unawaited(_exchange.refreshSerialPreviews());
    _lookup.cancelLookup();
    // Whatever was shown for the previous text is gone, an execution
    // confirmation included.
    _command.keystroke();

    // Live scoring for the call-info notices line — independent of the lookup
    // and command paths below, so schedule it before their early returns.
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

  /// Schedules the lookup for the call at the cursor, first taking back the
  /// references a previous call's guess put on the entry.
  ///
  /// A guessed ref belongs to the call it was resolved for, and is taken
  /// back once the field no longer holds that call — including mid-edit,
  /// with what's left not yet a valid callsign. Waiting for a replacement
  /// lookup would leave it standing through the intervening keystrokes, and
  /// a lookup that resolves nothing would never clear it at all. Correcting
  /// KI2D to KI2E must not log KI2E at KI2D's park.
  ///
  /// Keyed on the whole field, NOT on the call at the cursor: adding a
  /// second call to a stack moves the cursor off the first without
  /// correcting it, and a reference one stacked call earned is kept for the
  /// whole stack (refs are shared across the stack anyway — two operators
  /// at one park is exactly the case that produces a stack in the first
  /// place).
  void _scheduleLookup() {
    _refs.takeBackGuessUnlessIn(_callsInField);
    _lookup.scheduleLookup();
  }

  /// What a resolved lookup does to the entry, per pass.
  ///
  /// Spot-derived refs land off the OFFLINE pass deliberately without a
  /// re-lookup: the online pass rebuilds its `qso` argument from scratch, so
  /// the POTA/SOTA hooks see the just-added park/summit on that pass and
  /// resolve its grid — a re-lookup here would instead race the online pass
  /// already in flight. Anything the online pass proposes that the offline
  /// one didn't (a spot fetched in between) has had no chance to reach the
  /// activity hooks, so that one does re-look-up. It cannot cycle: the refs
  /// it just applied are filtered out as already-claimed on the next pass,
  /// which then applies nothing and re-triggers nothing.
  ///
  /// QSO-scoped activity controls are refreshed off BOTH passes. The offline
  /// pass resolves the DXCC entity (POTA's prefix placeholder needs only
  /// that), but a caller's STATE arrives only with the online pass — and a
  /// QSO party's suggestion is the state: refreshed off the offline pass alone,
  /// the field stays blank until the call is retyped and hits the cache. The
  /// two refreshes are unawaited with no ordering between
  /// them; [ActivityRefsModel]'s refresh ticket makes the later-issued one win
  /// however they finish, so a slow offline refresh cannot overwrite a fast
  /// online one. A cache hit refreshes too: typing back to a call reaches the
  /// lookup only through the cache, and its guessed refs were just cleared.
  void _onLookupResolved(String call, Map<String, dynamic>? result, LookupPhase phase) {
    switch (phase) {
      case LookupPhase.cached:
      case LookupPhase.offline:
        _refs.applyGuessRefs(result, call);
        unawaited(_refs.refreshControlsFor(call));
      case LookupPhase.online:
        if (_refs.applyGuessRefs(result, call)) _relookupForRefsChanged();
        unawaited(_refs.refreshControlsFor(call));
    }
  }

  /// [CallLookupModel.relookupForRefsChanged], gated on this panel not being
  /// in the middle of writing the fields itself.
  void _relookupForRefsChanged() {
    if (_draft.isPopulating) return;
    _lookup.relookupForRefsChanged();
  }

  // ---- Logging ----

  /// Escape backs out of the innermost thing that's open, one layer per
  /// press: an options menu, then an expanded secondary control, then the
  /// editing session. It stops there: a QSO being composed is never wiped by
  /// Escape — that is Alt+W ([_handleChord]) or the wipe button.
  ///
  /// It must not blank the read-only view of a staged-delete or deleted QSO —
  /// the fields are the record's only display and can't be repopulated
  /// without reselecting it. When editing an existing QSO it discards any
  /// unsaved changes and ends the editing session entirely
  /// (ham2k/halo-dist#199), unlike Revert, which discards changes and
  /// stays in edit mode.
  void _handleEscape() {
    if (_fieldsLocked) return;
    if (widget.session.escapeClaimed?.call() ?? false) return;
    // An open exchange menu takes the first Escape, and takes it whether or not
    // the operator has touched the highlight: with a menu up, Escape means "not
    // that" — and what Escape does below throws away work (a discarded edit, a
    // deselected QSO). Losing a half-made correction to a keystroke aimed at a
    // dropdown is not a recoverable mistake.
    if (_exchange.menuOpen) {
      _exchange.dismissMenu();
      return;
    }
    // An open secondary control takes the next one, and goes all the way back
    // to the main fields — where Down and Enter stop at the pill, Escape is
    // the "out of here entirely" gesture. Nothing is thrown away by closing a
    // control (its value is already committed), so this is safe to take
    // priority over the destructive layers below.
    if (_selectedControlKey != null) {
      _onSelectControl(null);
      return;
    }
    if (widget.session.editingQso != null) widget.session.onEditCanceled?.call();
  }

  /// The panel's modifier chords, which are the second button's gestures on
  /// the keyboard: Alt+W wipes the QSO being composed, and Cmd/Ctrl+Z takes
  /// back a wipe (while its undo offer lasts) or a staged delete.
  ///
  /// A key handler rather than a `CallbackShortcuts` entry because Cmd/Ctrl+Z
  /// must stay the focused field's own text undo whenever there is nothing
  /// here to take back, and a shortcut binding claims its key unconditionally.
  /// Revert-changes is deliberately not on it for the same reason: while
  /// editing, the operator reaching for Cmd/Ctrl+Z means the last keystroke,
  /// not the whole record.
  ///
  /// Alt+W resets the whole draft either way: with something composed it is
  /// the wipe button's path and its undo offer, and with nothing composed it
  /// still clears what [QsoDraft.hasComposedValues] does not count — a report,
  /// a power entry, a pending frequency edit — which no other gesture resets.
  /// It is claimed in every state, and on key repeat too: unclaimed, macOS
  /// types Option+W into the focused field as "∑".
  ///
  /// Cmd/Ctrl+Z restores a wipe only onto a form with nothing composed since.
  /// The undo offer outlives the operator starting the next contact, and a
  /// Cmd/Ctrl+Z aimed at a typo in it would otherwise replace that contact
  /// with the wiped one, with nothing left to take THAT back.
  ///
  /// Also reachable through [LoggingControlsController.handleChord]: a staged
  /// delete disables every field here, so the event cannot arrive by focus.
  KeyEventResult _handleChord(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    final command = keyboard.isMetaPressed || keyboard.isControlPressed;
    final alt = keyboard.isAltPressed;
    if (keyboard.isShiftPressed || command == alt) return KeyEventResult.ignored;

    if (alt && event.logicalKey == LogicalKeyboardKey.keyW) {
      if (event is KeyDownEvent && widget.session.editingQso == null && !_fieldsLocked) {
        if (_draft.hasComposedValues) {
          _handleWipeTap();
        } else {
          _wipe();
        }
      }
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent && command && event.logicalKey == LogicalKeyboardKey.keyZ) {
      // Not while the staged delete is being committed: un-staging then would
      // show Delete again over a record that is already on its way out.
      if (_pendingDelete && !_isLogging) {
        setState(() => _pendingDelete = false);
        return KeyEventResult.handled;
      }
      if (widget.session.editingQso == null && _draft.undoSlot.value != null && !_draft.hasComposedValues) {
        _restoreFromUndoSlot();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  /// [focusCall] false leaves the focus where it is — for a wipe the operator
  /// did not ask for from this panel (a slid spot row closing, say), or one
  /// that ends a gesture made on another surface, where pulling focus here
  /// would raise the mobile keyboard over the list they are actually working.
  ///
  void _wipe({bool focusCall = true}) {
    // The draft is gone, and so is its hold on a number. After a commit this
    // is a no-op — the log path released with the committed numbers already.
    widget.log.serialNumbers?.release(widget.log.operation.uuid);
    _suggestedCall = null;
    _suggestionWasTentative = false;
    _esmAnsweredCall = null;
    _radio.settlePendingFreqEdit();
    _callController.clear();
    _clearRSTs();
    _gridController.clear();
    _stateController.clear();
    _draft.clear();
    _lookup.cancelLookup();
    _lookup.reset();
    _refs.clear();
    _exchange.clear();
    _notesController.clear();
    _time.manualStartAtMillis = null;
    _selectedControlKey = null;
    _radio.clearPowerEntry();
    // The VFO's power is ambient, not composed — a wipe drops what the entry
    // stated and goes back to mirroring it, the way the Radio control does.
    _seedFromRadioService();
    if (focusCall) _callFocus.requestFocus();
    setState(_command.reset);
    _command.keystroke();
  }

  // ---- Wipe/undo, delete/undo, revert-changes: the info row's second button ----

  /// The part of [QsoDraft.hasComposedValues] a spot slide may not overwrite. The
  /// slide is made on another surface, so what it would destroy has to be
  /// worth a prompt from over there: a station being composed is, while a
  /// frequency, a reference or a stray field with no call attached is
  /// scaffolding the incoming spot replaces anyway.
  ///
  /// A call a SUGGESTION put there is not composed at all — the operator chose
  /// a station, they did not compose an entry (see [_suggestedCall]). So the
  /// next spot, slid or tapped, replaces it silently, and the log request that
  /// ends a slide never asks permission to overwrite what that same slide
  /// filled in a moment earlier.
  bool get _hasComposedCall => _call.isNotEmpty && !_callIsUntouchedSuggestion;

  /// Stashes the in-progress new QSO into the undo slot (for 5 seconds,
  /// even if the user keeps typing — see `_buildWipeOrEditButton`), then
  /// wipes the form.
  void _handleWipeTap() {
    // Beside the draft, never inside it: [QsoDraft.toData] writes the refs
    // and not which of them a lookup proposed, and the wipe below is what
    // forgets that.
    _undoGuesses = _refs.takeGuessSnapshot();
    _draft.undoSlot.set(
      _draft.toData(),
      onExpire: () {
        _undoGuesses = null;
        if (mounted) setState(() {});
      },
    );
    _wipe();
  }

  void _restoreFromUndoSlot() {
    final data = _draft.undoSlot.take();
    if (data == null) return;
    final guesses = _undoGuesses;
    _undoGuesses = null;
    _restoreDraft(data, guesses: guesses);
  }

  /// Puts one of the draft's own records ([QsoDraft.toData]) back — a wipe
  /// undone, or a detour through an earlier contact returned from. One
  /// method for both, or the next rule added to one path is missed by the
  /// other.
  void _restoreDraft(Map<String, dynamic> data, {GuessProvenance? guesses}) {
    _draft.populate(() {
      _applyFieldsFromData(data, restoringDraft: true);
      // Before the lookup below, and before any correction to the callsign:
      // the refs are back but nothing yet says which of them a lookup put
      // there, and an unmarked guess is never taken back.
      if (guesses != null) _refs.restoreGuesses(guesses);
      _time.manualStartAtMillis = data['startAtMillis'] as int?;
      setState(() {});
    });
    // The populate bracket suppressed _onCallChanged's own _scheduleLookup()/
    // _lookup.scheduleScore() calls above (population isn't the user typing),
    // and the wipe or the reset before this cleared the lookup cache and score
    // notices — without these a restored call sits unlooked-up and without
    // its dupe/New-* pills until the operator edits the call field again.
    _scheduleLookup();
    _lookup.scheduleScore();
  }

  /// Restores (undeletes) the deleted QSO being viewed, then ends the
  /// editing session — the caller clears its selection and the list row
  /// loses its strikethrough via the repository watch.
  Future<void> _handleRestoreTap(Qso editingQso) async {
    // Restore sits OUTSIDE `_fieldsLocked` on purpose — a deleted QSO is
    // always locked, and undoing that is the button's whole job — so the
    // write policy has to be consulted here in its own right.
    final refusal = _writeRefusal;
    if (refusal != null) return;
    if (_isLogging) return;
    _isLogging = true;
    try {
      await widget.log.qsosRepository.undelete(editingQso);
      if (!mounted) return;
      widget.log.onQsoUndeleted?.call(editingQso);
      widget.session.onEditCanceled?.call();
    } finally {
      _isLogging = false;
    }
  }

  /// Whether the fields being edited differ from the stored record — drives
  /// the "revert changes" vs. "delete" state of the info row's second
  /// button while editing.
  bool _qsoDataChanged() {
    final editingQso = widget.session.editingQso;
    if (editingQso == null) return false;
    if (editingQso.isEvent) return !qsoDataEquivalent(_eventDataForSave(editingQso), editingQso.data);
    return _draft.differsFrom(editingQso);
  }

  /// HaLo's big light-blue log button — a circle as tall as the text fields
  /// beside it, which [LoggingEntryRow] places at either end of the row and
  /// keys there, since it is that row that moves it. (A LayoutBuilder here to
  /// size the icon off the button's resolved constraints would seem natural,
  /// but the row's IntrinsicHeight needs to query this subtree's intrinsic
  /// dimensions, which LayoutBuilder explicitly doesn't support — so the icon
  /// just uses a fixed, comfortable size.) #236: stable id for agent/browser
  /// tooling. [_submitButtonKey] is for the post-frame measurement.
  Widget _buildSubmitButton(ThemeData accentTheme, {required bool editing, required bool deletedQso}) => semanticId(
    'action.log',
    AspectRatio(
      key: _submitButtonKey,
      aspectRatio: 1,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: FilledButton(
          // Disabled while viewing a deleted QSO — there's nothing to
          // save; restore first. `_command.hasExecutableCommand` lets
          // the button accept a command too, matching Enter (a command
          // isn't a callsign, so `_canLog` alone would leave it
          // disabled — see that getter). `_editingEvent` skips both: an
          // event row has neither a callsign nor a command to accept.
          onPressed: (!deletedQso && (_pendingDelete || _canLog || _command.hasExecutableCommand || _editingEvent)) ? _log : null,
          style: FilledButton.styleFrom(
            backgroundColor: accentTheme.colorScheme.tertiary,
            foregroundColor: accentTheme.colorScheme.onTertiary,
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            shape: const CircleBorder(),
          ),
          child: Icon(
            _pendingDelete ? MdiIcons.trashCan : (editing ? MdiIcons.contentSave : MdiIcons.upload),
            size: 24 * 1.2 * MediaQuery.textScalerOf(context).scale(1.0),
          ),
        ),
      ),
    ),
  );

  /// Which action the info row's second button is right now — per the state
  /// machine in the class doc comment above — as a [LoggingActionButton]
  /// sized to the log button.
  Widget _buildWipeOrEditButton(ThemeData accentTheme) {
    final editingQso = widget.session.editingQso;
    final IconData icon;
    final String? actionLabel;
    final VoidCallback? onPressed;

    if (editingQso == null) {
      if (_draft.undoSlot.value != null) {
        icon = MdiIcons.undo;
        actionLabel = t.loggingControls.undo;
        onPressed = _restoreFromUndoSlot;
      } else {
        icon = MdiIcons.backspaceOutline;
        actionLabel = t.loggingControls.wipe;
        onPressed = _draft.hasComposedValues ? _handleWipeTap : null;
      }
    } else if (editingQso.deleted) {
      // An already-deleted QSO (selected via the "show deleted QSOs"
      // toggle) — one tap restores it immediately (ham2k/halo-dist#59);
      // no staged-until-save step, since restoring isn't destructive.
      icon = MdiIcons.deleteRestore;
      actionLabel = t.loggingControls.restore;
      // Disabled rather than merely refused: restore is the one action that
      // deliberately survives `_fieldsLocked` (a deleted QSO is always
      // locked), so without this it is the only enabled control on an
      // otherwise read-only form, and tapping it would do nothing.
      onPressed = _writeRefusal != null ? null : () => _handleRestoreTap(editingQso);
    } else if (_pendingDelete) {
      icon = MdiIcons.undo;
      actionLabel = t.loggingControls.undoDelete;
      onPressed = () => setState(() => _pendingDelete = false);
    } else if (_qsoDataChanged()) {
      icon = MdiIcons.undo;
      actionLabel = t.loggingControls.revert;
      // Reset THEN populate, the pairing every other load of a record uses:
      // the values alone are not the edit. A touched flag left standing is
      // still an edit as far as the record is concerned, so the button would
      // go on reading Revert and a save would write the field back — and for
      // the grid, the square's centre as a coordinate the operator never
      // entered.
      onPressed = () {
        _resetEditingSessionState();
        _populateFromEditingQso(editingQso);
      };
    } else {
      icon = MdiIcons.trashCanOutline;
      actionLabel = t.common.delete;
      onPressed = () => setState(() => _pendingDelete = true);
    }

    return LoggingActionButton(
      diameter: _editButtonDiameter ?? 44,
      icon: icon,
      label: actionLabel,
      onPressed: onPressed,
      color: accentTheme.colorScheme.tertiary,
    );
  }

  /// A QSO write threw: surface it in the info area (the same channel a
  /// command error uses — never a toast over the logging UI) and hand it to
  /// the host to report. The caller decides what field bookkeeping
  /// accompanies it; the fields themselves are never wiped on failure.
  ///
  /// The in-panel message is load-bearing, not a courtesy: the host's own
  /// notice for a write error shows at most once per session, so without it
  /// an operator on a full disk loses every QSO after the first in silence.
  void _reportWriteFailure(Object e, StackTrace stack, {bool delete = false}) {
    widget.log.onWriteError?.call(e, stack);
    if (!mounted) return;
    // A confirm-clear timer from an earlier command would wipe this message
    // moments after it appears — the failure owns the slot now.
    _command.showError(delete ? t.loggingControls.deleteFailed(error: e) : t.loggingControls.saveFailed(error: e));
  }

  /// [focusCall] false leaves the focus alone when the entry is wiped after
  /// logging — for a contact logged by a gesture made somewhere else (a spot
  /// row slid past the commit point). The operator is working the spots list,
  /// and taking focus here pops the on-screen keyboard up over it.
  ///
  /// [fromEnter] marks the keyboard's Enter, the only submit Enter Sends
  /// Messages speaks for.
  Future<void> _log({bool focusCall = true, bool fromEnter = false}) async {
    if (_isLogging) return; // already logging this entry; ignore the repeat
    // The write policy specifically, NOT `_fieldsLocked`: this method is also
    // how a staged delete is committed and a deleted QSO saved, both of which
    // lock the form on purpose and are handled by their own branches below.
    //
    // Fields being disabled is not enough on its own — the panel binds Enter
    // at its own level (`CallbackShortcuts`), so a contact still sitting in
    // the controllers can be submitted from anywhere in the subtree after the
    // form locks under the operator, which running DEVTT from the command bar
    // does exactly.
    if (_writeRefusal != null) return;

    // Check command — shortcuts (band/freq/mode, etc.) only apply while
    // composing a new QSO. A real callsign is exceedingly unlikely to
    // parse as one, but editing an existing entry shouldn't run it through
    // command interpretation at all, least of all while confirming a
    // staged delete.
    final call = _call;
    if (widget.session.editingQso == null) {
      // Enter inside the claim window would otherwise commit a blank serial
      // field, and the allocator's fallback knows nothing of the peers' holds.
      final settled = await _exchange.settleSerialClaims();
      if (!settled || !mounted || _call != call || _isLogging) return;
    }
    // The command line's own decision: whether the typed text is a command
    // at all, what it interprets to, and whether Enter ran it, showed why it
    // cannot, or falls through to logging. The panel supplies what is its own
    // — the double-log guard, the field, the actions.
    final consumed = await _command.runOnEnter(
      alreadyLogging: () => _isLogging,
      whileLogging: (body) async {
        _isLogging = true;
        try {
          await body();
        } finally {
          _isLogging = false;
        }
      },
      clearField: _callController.clear,
      dispatch: (commands, {required skipOnlineLookup}) async {
        try {
          await _dispatchActions(commands, skipOnlineLookup: skipOnlineLookup);
        } catch (e, stack) {
          // A command's actions can write QSOs (e.g. a SEED batch) — a
          // throw mid-dispatch must not vanish into the zone handler
          // while the panel looks like the command ran.
          _reportWriteFailure(e, stack);
        }
      },
    );
    if (consumed) return;

    // Note expansion inside a stack (see [_expandStackedNote]): "KI2D//1AB"
    // becomes "KI2D//W1AB,W1AC" and logs NOTHING this time round. Placed
    // above every gate below, including the band/frequency one, because an
    // expansion writes no QSO — there is nothing yet for a missing band to
    // spoil, and refusing here would leave the operator unable to even see
    // what the key expands to.
    if (await _expandStackedNote()) return;
    // That probe is a real suspension point (a JS runtime round trip) sitting
    // between the entry guard and `_isLogging = true` below — so a repeated
    // Enter that cleared the entry guard before it can now be inside the very
    // same window, and both would go on to log the same QSO. Exactly the race
    // the command path above re-checks for, for exactly the same reason: key
    // auto-repeat fires well inside an extension round trip.
    if (!mounted || _isLogging || _call != call) return;

    final editingQso = widget.session.editingQso;

    // Viewing a deleted QSO: the save button is disabled, but Enter is
    // also bound to _log — nothing to save until it's restored.
    if (editingQso != null && editingQso.deleted) return;

    if (editingQso != null && _pendingDelete) {
      await _commitStagedDelete(editingQso);
      return;
    }

    // Events have none of the callsign/band/mode fields the checks below
    // exist for — save them straight from the inline editor's state.
    if (editingQso != null && editingQso.isEvent) {
      await _saveEvent(editingQso);
      return;
    }

    // A contact needs a band or a frequency (HALO-24). On a fresh install
    // nothing has ever set either — `RadioService` has no stored VFO, so
    // `vfoA` is empty — and every gate below looks only at the callsign, so
    // the QSO would be written with both null. That is worse than an
    // incomplete record: the ADIF exporter emits BAND only when there is one
    // and FREQ only when it's non-zero, so the contact leaves carrying
    // neither, and LoTW, QRZ and POTA all reject it — which the operator
    // discovers long after the station is gone. The `Band???` pill summary is
    // the only existing signal, and it's passive.
    //
    // So refuse, say so, and open the Radio control, which focuses its
    // frequency field (`_expandedFocusFor`) — the answer is one number away,
    // and the focus ladder is unchanged. The message rides the same
    // `_command.message` channel a command's error does, so it renders in the
    // information area right above the fields (`_buildInfoArea`), never as a
    // toast over the logging UI (docs/design/user-interface.md).
    //
    // Placed here deliberately: below the delete branches, so a QSO already
    // logged without a band can still be deleted without first being
    // repaired; above the stacked-call branch, so that path is covered too;
    // and gated on `_canLog` so it only speaks up when there was actually
    // something to log rather than shouting at an empty or half-typed field.
    // Editing an existing QSO is covered on purpose — an edit is exactly the
    // moment to repair one of the bandless records this bug already created.
    if (_canLog && _radio.freq == null && _radio.band == null) {
      // A confirm-clear timer from an earlier command would wipe this moments
      // after it appears — same reasoning as the command error branches.
      _command.showError(t.loggingControls.bandOrFreqRequired);
      _onSelectControl('radio');
      return;
    }

    // Enter Sends Messages, after every gate a plain Enter would stop at —
    // so a thanks is never keyed for a contact the band check then refuses —
    // and only while composing: an edit is a correction, not an exchange.
    if (fromEnter && editingQso == null) {
      if (widget.session.enterSends?.call() case final esm? when _enterSendsMessages(esm)) return;
    }
    final logged = _esmLogged;
    _esmLogged = null;

    if (!_canLog) {
      logged?.complete(null);
      // Pointing the operator at the field they have to fix — but only when
      // they are here to see it. A spot that cannot be logged (no usable
      // callsign) must not answer a gesture made on the spots list by raising
      // a keyboard over it.
      if (focusCall) _callFocus.requestFocus();
      return;
    }
    var saved = false;
    try {
      saved = await _saveContact(editingQso, focusCall: focusCall);
    } finally {
      // The entry as the save left it: wiped, and the rest of a stack back in
      // the field — what an ESM thanks renders against. Completed whatever
      // happens, or the thanks waits on it forever.
      // A throw building it still goes up from here, after the completion.
      if (logged != null) {
        Map<String, dynamic>? after;
        try {
          if (saved && mounted) after = _withCallField(_draft.toData(), _callText.templateCalls);
        } finally {
          logged.complete(after);
        }
      }
    }
  }

  Future<void> _commitStagedDelete(Qso editingQso) async {
    _isLogging = true;
    try {
      await widget.log.qsosRepository.softDelete(editingQso);
    } catch (e, stack) {
      // The row is untouched and the delete stays staged — say so and let
      // the operator retry or cancel, instead of the editor silently
      // closing over a QSO that never actually deleted.
      _reportWriteFailure(e, stack, delete: true);
      return;
    } finally {
      _isLogging = false;
    }
    widget.log.onQsoDeleted?.call(editingQso);
    widget.session.onEditCanceled?.call();
  }

  /// An event row saved straight from the inline editor's state — events
  /// have none of the callsign/band/mode fields the contact path checks.
  Future<void> _saveEvent(Qso editingQso) async {
    _isLogging = true;
    try {
      await widget.log.qsosRepository.update(
        Qso(uuid: editingQso.uuid, operationUuid: widget.log.operation.uuid, data: _eventDataForSave(editingQso)),
        basedOn: editingQso,
      );
    } catch (e, stack) {
      // Editor stays open with the typed values — nothing committed.
      _reportWriteFailure(e, stack);
      return;
    } finally {
      _isLogging = false;
    }
    widget.session.onEditCanceled?.call();
  }

  /// The contact — one QSO per call of a list or a stack segment, or the
  /// edited record updated in place with any calls added to it logged
  /// fresh. Everything up to here has already refused what cannot log.
  /// Whether every contact was written — false when a write failed and the
  /// entry was left for the operator to retry.
  Future<bool> _saveContact(Qso? editingQso, {required bool focusCall}) async {
    _isLogging = true;
    try {
      // A comma-separated call list logs one QSO per call, all sharing the
      // same other attributes, with each successive one's time 5 seconds
      // after the last (issue #7) — a single call is just a one-item list,
      // so `baseData`'s own startAtMillis/editingQso.startAtMillis is
      // preserved exactly for that common case.
      //
      // Call stacking (issue #7) feeds the same path: "//" picks ONE segment
      // out of the stack (which may itself be a comma list) and logs only
      // its calls, then leaves the rest of the stack in the field below.
      // Everything else is identical to a typed list, deliberately — no
      // information carries over between stacked calls either way.
      final stacked = editingQso == null ? _callText.pickStackedCall() : null;
      final calls = stacked?.calls ?? _callList;
      final isList = calls.length > 1;
      // `their.call` for the whole batch comes from `dataFor` below, but the
      // cached lookup only rides along when [QsoDraft.toData] is asked
      // about the call it was made for — the raw stacked field text never
      // matches it.
      final baseData = _draft.toData(callOverride: stacked?.calls.first);
      final baseStartAtMillis = (baseData['startAtMillis'] as int?) ?? nowMillis();

      // The record being edited (index 0, when editing) survives untouched
      // even once more calls are added to its list — same as an ordinary
      // single-call edit, no fresh lookup, nothing suppressed. Every other,
      // newly-added entry in a multi-call list is saved bare and handed to
      // `enqueueLookup` (below) for its own fresh, independent background
      // lookup, instead of inheriting whatever single guessed/looked-up
      // name/grid was cached for a different call — and instead of blocking
      // the save on N sequential network lookups (a stall with no network).
      // A manually entered grid override is more often a station-wide
      // correction, so it's fine for that to still apply to every new
      // entry — but a manually entered name is specific to whoever the
      // override was actually typed for, so it isn't duplicated onto a
      // different, newly-added call.
      Map<String, dynamic> dataFor(String call, int index) {
        final keepOriginal = !isList || (editingQso != null && index == 0);
        return {
          ...baseData,
          // The displayed serial belongs to the FIRST call only — that is the
          // one number the operator actually read out. Everyone after it in the
          // list got the next numbers in the series, so strip the field and let
          // the sequence issue them at commit; without this the whole list logs
          // under one serial.
          if (index > 0) 'refs': _exchange.refsWithoutSerials(baseData['refs']),
          'their': {
            if (keepOriginal) ...?(baseData['their'] as Map<String, dynamic>?),
            'call': call,
            'sent': _rstOrDefault(_rcvdController.text.trim()),
            if (keepOriginal && _draft.theirNameOverride != null) 'name': _draft.theirNameOverride,
            // Same normalization as [QsoDraft.toData]: canonical Maidenhead
            // casing for grids, uppercase for states.
            if (_draft.gridTouched) 'grid': normalizeGrid(_gridController.text.trim()),
            if (_draft.stateTouched) 'state': _stateController.text.trim().toUpperCase(),
          },
          'startAtMillis': baseStartAtMillis + index * 5000,
        };
      }

      if (editingQso != null) {
        try {
          // `basedOn` is the snapshot this edit was composed from: if a sync
          // pull moved the row while the editor sat open, only the fields
          // actually edited here overwrite it (see mergeConcurrentEdit).
          await widget.log.qsosRepository.update(
            Qso(uuid: editingQso.uuid, operationUuid: widget.log.operation.uuid, data: await _decorated(dataFor(calls.first, 0))),
            basedOn: editingQso,
          );
        } catch (e, stack) {
          // Nothing committed — the editor stays open with every typed value.
          _reportWriteFailure(e, stack);
          return false;
        }
        for (var i = 1; i < calls.length; i++) {
          // The base data carries the edited QSO's own uuid (baseData came
          // from its record) — strip it so add() generates a fresh one for
          // this new QSO instead of colliding with the original.
          final data = dataFor(calls[i], i)..remove('uuid');
          final Qso qso;
          try {
            qso = await widget.log.qsosRepository.add(
              widget.log.operation.uuid,
              await _decorated(_exchange.withSerialConflicts(data)),
              serialSequences: _exchange.serialSequences,
            );
          } catch (e, stack) {
            // Calls before [i] are already committed: keep the edited
            // record's own call plus only the still-unlogged ones in the
            // field, so retrying the Enter can't log the committed ones
            // twice.
            _callController.text = [calls.first, ...calls.sublist(i)].join(',');
            _reportWriteFailure(e, stack);
            return false;
          }
          _exchange.releaseCommittedSerials(qso);
          widget.log.onLogged?.call(qso);
          widget.lookups.enqueueLookup?.call(qso);
        }
        widget.session.onEditCanceled?.call();
      } else {
        // Flush any pending debounced frequency push first, so a value
        // typed just before hitting Enter/Log is reflected in both the VFO
        // and this QSO, rather than only landing after the fact.
        _radio.flushPendingPush();
        for (var i = 0; i < calls.length; i++) {
          final Qso qso;
          try {
            qso = await widget.log.qsosRepository.add(
              widget.log.operation.uuid,
              await _decorated(_exchange.withSerialConflicts(dataFor(calls[i], i))),
              serialSequences: _exchange.serialSequences,
            );
          } catch (e, stack) {
            // Nothing is wiped on failure — the fields keep every typed
            // value. With calls already committed (i > 0), the field is
            // rewritten to only the unlogged ones (plus the untouched rest
            // of a stack), cursor on them, so retrying the Enter can't log
            // the committed calls twice.
            if (i > 0) {
              final unlogged = calls.sublist(i).join(',');
              final text = stacked == null || stacked.remainder.isEmpty ? unlogged : '$unlogged//${stacked.remainder}';
              _callController.value = TextEditingValue(
                text: text,
                selection: TextSelection.collapsed(offset: unlogged.length),
              );
            }
            _reportWriteFailure(e, stack);
            return false;
          }
          _exchange.releaseCommittedSerials(qso);
          widget.log.onLogged?.call(qso);
          widget.lookups.enqueueLookup?.call(qso);
        }
        _wipe(focusCall: focusCall);
        // The un-logged rest of the stack goes straight back into the
        // now-empty field, as if the operator had just typed it.
        if (stacked != null) _callController.text = stacked.remainder;
      }

      // A single rescoring pass after the whole batch, not a score check per
      // call — the on-screen scoring pills already only ever reflect the
      // cursor's own call (see `CallLookupModel.scheduleScore`/`_callAtCursor`).
      if (isList) widget.log.onCallListLogged?.call();
      return true;
    } finally {
      _isLogging = false;
    }
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
                              // Scored on (New State / New Province), so a typed
                              // state has to reach the scorer like a band or mode
                              // change does.
                              _lookup.scheduleScore();
                            },
                            grid: widget.prefs.showGridField ? (controller: _gridController, focus: _gridFocus) : null,
                            gridHint: _guessGridHint,
                            onGridChanged: (_) => _draft.markGridTouched(),
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

  /// How much to reserve below the fields: the bottom safe area (home
  /// indicator), or 0 off mobile / on a device without one (see the spacer in
  /// build).
  ///
  /// Deliberately NOT the keyboard: reserving that is [StatusBarOverlay]'s job,
  /// so the status footer can ride above the keyboard instead of hiding behind
  /// it. Reserving it here too would hold the same strip back twice and leave
  /// the fields floating in the gap.
  ///
  /// And nothing at all while the keyboard is up — the keyboard covers the home
  /// indicator, so the strip the overlay is already holding back IS that space.
  /// The keyboard question goes to the raw view because the overlay consumes
  /// that inset on the way down, leaving MediaQuery unable to tell the two
  /// states apart.
  ///
  /// The strip itself comes from MediaQuery, which is what a host that draws
  /// its own chrome over the bottom edge — the app's status footer, holding
  /// the safe area with a `SafeArea` of its own — takes it out of, so this
  /// panel does not reserve the same space a second time.
  double get _bottomReserve {
    if (!isMobilePlatform || widget.prefs.aboveLog) return 0;
    if (View.of(context).viewInsets.bottom > 0) return 0;
    return MediaQuery.paddingOf(context).bottom;
  }

  /// Whether to show the mobile numbers row right now — the setting is on,
  /// we're on a phone/tablet, the QSO isn't a read-only (staged/already
  /// deleted) view, the on-screen keyboard is up, and one of our logging
  /// fields actually holds the focus (issue #27).
  bool _shouldShowNumbersRow(BuildContext context) {
    return widget.prefs.showNumbersRow &&
        isMobilePlatform &&
        !_fieldsLocked &&
        // Focus is not enough: this panel keeps focus when it is tabbed away
        // from behind a keep-alive, and the row is drawn outside the tab
        // view, so it would hang over whatever replaced it.
        KeyboardAccessoryVisibility.of(context) &&
        virtualKeyboardIsUp(context) &&
        _focusedNumberField != null;
  }

  /// Publishes (or withdraws) the numbers row for this build. Called from
  /// `build` but never mutates during it — the notifier is only written after
  /// the frame, since the overlay that listens sits above this widget and
  /// rebuilding it mid-build would throw.
  void _syncNumbersRow(BuildContext context, ThemeData theme) {
    final accessory = widget.prefs.keyboardAccessory;
    if (accessory == null) return;
    final spec = _shouldShowNumbersRow(context)
        ? KeyboardAccessorySpec(
            onKey: _handleNumberKey,
            extraKey: _numbersRowExtraKey,
            vibrate: widget.prefs.vibrateNumbersRow,
            // The AppBar/footer colour — the app's chrome — deliberately NOT
            // the editing-swappable tertiary/secondary accent, so the row
            // reads as chrome in every mode. (appBarTheme isn't remapped by
            // the editing accent, so `theme` here being the accent theme is
            // fine.)
            backgroundColor: (theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary).toARGB32(),
            foregroundColor: (theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary).toARGB32(),
          )
        : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (spec == null) {
        accessory.clearIfOwner(this);
      } else {
        accessory.publish(this, spec);
      }
    });
  }

  /// The lookup `guess` for the call about to be logged. Prefers a live lookup
  /// result; when editing an existing QSO, uses the guess saved on the QSO at
  /// log time (`their.guess`) so its call-info shows without refetching — and
  /// while a fresh lookup for that same call is in flight (e.g. re-focusing the
  /// field), the saved fields fill any gaps the partial live result hasn't
  /// filled yet, so the panel updates in place instead of flashing to blank and
  /// back. The saved guess is only used while the call field still matches the
  /// QSO's own call. Empty map means "call known, nothing resolved yet."
  Map<String, dynamic>? get _currentGuess {
    final result = _lookup.resultForActiveCall;
    final liveGuess = result == null ? null : (result['guess'] as Map<String, dynamic>? ?? const {});

    Map<String, dynamic>? savedGuess;
    final editing = widget.session.editingQso;
    if (editing != null) {
      final their = asQsonMap(editing.data['their']);
      final savedCall = (their?['call'] as String?)?.toUpperCase();
      if (savedCall != null && savedCall == _callAtCursor && their?['guess'] is Map) {
        savedGuess = (their!['guess'] as Map).cast<String, dynamic>();
      }
    }

    if (liveGuess != null && savedGuess != null) return {...savedGuess, ...liveGuess};
    return liveGuess ?? savedGuess;
  }

  /// The call-info the area shows — null while the call-info panel is not
  /// showing: fewer than three characters typed, or an event row, whose
  /// `their.call` (e.g. "NOTE") is a sentinel rather than a real callsign —
  /// the operation stats are the only sensible default there, same as with
  /// nothing typed yet.
  ///
  /// When editing an existing QSO, the data is held until scoring has run
  /// (`_lookup.scoreFor == _callAtCursor`), so the saved lookup and the pills
  /// appear together in one update — otherwise the lookup text renders first
  /// and the pills pop in a moment later. Composing streams in as the user
  /// types.
  CallInfoData? get _callInfoForArea {
    if (!_callInfoActive || _editingEvent) return null;
    final ready = widget.session.editingQso == null || widget.lookups.scoreQso == null || _lookup.scoreIsCurrent;
    final guess = ready ? _currentGuess : null;
    return CallInfoData(
      call: _callAtCursor,
      guess: guess,
      lookups: _currentLookups,
      alertKeys: ready ? _lookup.currentAlertKeys : const [],
      noticeKeys: ready ? _lookup.currentNoticeKeys : const [],
      scoreSources: ready ? _lookup.currentScoreSources : const {},
      isEditing: widget.session.editingQso != null,
      workedBefore: _lookup.workedBefore,
    );
  }

  /// The info area (issue #40): [LoggingInfoArea] says what it shows and in
  /// what order; this is where the panel's state becomes its inputs. The
  /// distance line and the notice labels come from the app layer — only it
  /// knows the operation's own location and the current locale — and this
  /// panel is where they arrive.
  Widget _buildInfoArea(ThemeData theme) {
    final callInfo = _callInfoForArea;
    final guess = callInfo?.guess;
    final message = _command.message;
    return LoggingInfoArea(
      theme: theme,
      warnings: _missingRadioWarnings,
      message: message,
      callInfo: callInfo,
      locationLine: guess == null ? null : widget.lookups.callLocationLine?.call(guess),
      // Asked only when it would show: it walks the exchange fields.
      gridOnlyLine: message == null && callInfo == null ? _gridOnlyLine : null,
      statsLines: () => widget.lookups.operationStatsLines?.call(widget.log.qsos) ?? const <String>[],
      noticeLabel: widget.lookups.scoreNoticeLabel,
      workedBeforeLabel: widget.lookups.workedBeforeLabel,
      onCallInfoTap: widget.lookups.onCallInfoTap,
      onOperationInfoTap: widget.lookups.onOperationInfoTap,
      onOpenLink: widget.lookups.onOpenLink,
    );
  }

  /// What the locked form says in place of the info area (ham2k/halo-dist#59).
  /// The write refusal is checked first: a staged delete on a QSO whose
  /// operation is also unwritable would otherwise promise a deletion that
  /// cannot be saved.
  String _lockedWarningText(bool deletedQso) {
    final refusal = _writeRefusal;
    // Worded for the event row when there is one (`kind` is its uppercased
    // eventKind, e.g. "NOTE"/"BREAK") — "QSO" is wrong for a row that isn't one.
    final kind = widget.session.editingQso?.eventKind?.toUpperCase();
    return (refusal != null)
        ? refusal.reason
        : (kind != null)
        ? (deletedQso
              ? t.loggingControls.deletedEventWarning(kind: kind)
              : isMobilePlatform
              ? t.loggingControls.pendingDeleteEventTapWarning(kind: kind)
              : t.loggingControls.pendingDeleteEventClickWarning(kind: kind))
        : (deletedQso
              ? t.loggingControls.deletedQsoWarning
              : isMobilePlatform
              ? t.loggingControls.pendingDeleteTapWarning
              : t.loggingControls.pendingDeleteClickWarning);
  }

  /// What the contact in hand is missing from the radio state that every QSO
  /// needs: a band (or a frequency to derive one from) and a mode. Empty —
  /// the normal state — paints nothing.
  ///
  /// Never while editing an event row. A NOTE is not a contact and needs no
  /// band, and the `event` band sentinel it carries does not survive into
  /// `_radio.band`: the record's zero frequency sends [QsoDraft.applyData] down
  /// its frequency branch, which drops `_radio.manualBand`. On a tuned rig
  /// `_seedFromRadioService` then fills it from the VFO and the question never
  /// arises; on the untuned one these warnings exist for, this guard is all
  /// that stops an annotation being nagged about a field it will never have.
  List<String> get _missingRadioWarnings {
    if (_editingEvent) return const [];
    return [
      // The same condition [_log] refuses a submit on, so the two can never
      // name different things as missing. They are not the same test, though:
      // this one is additionally suppressed on an event row and wherever
      // `fieldsLocked` swaps the whole area for its own warning. Neither is
      // reachable with something loggable in hand today — an event's `NOTE`
      // is not a callsign, and a locked form cannot log — so nothing is lost
      // by staying quiet there.
      if (_radio.freq == null && _radio.band == null) t.loggingControls.missingBand,
      if (_radio.mode.trim().isEmpty) t.loggingControls.missingMode,
    ];
  }

  /// What the info area is showing, as the signature [LoggingInfoFrame] keys
  /// its cross-fade on — changes when the DISPLAYED content changes (mode,
  /// lookup result, notices), but is stable across the stats line's 1 Hz
  /// clock tick, so only real content changes cross-fade.
  ///
  /// The missing-band/mode warnings are deliberately outside it: they are a
  /// state of the radio, not of the area, and they come and go while the area
  /// is showing the same thing. They update in place, as lookup and score
  /// results do.
  String _infoAreaSignature({required bool fieldsLocked, required bool deletedQso}) {
    // The refusal is part of the signature because it can clear while the
    // form stays locked for another reason — travel ending over a staged
    // delete — and the warning text changes without `fieldsLocked` moving.
    if (fieldsLocked) return 'locked:$deletedQso:${_writeRefusal != null}';
    if (_command.message != null) return 'message'; // message text updates in place
    // Coarse on purpose: only the call itself keys the cross-fade. Lookup and
    // score results stream in as in-place updates (no switch), so the panel
    // fills smoothly instead of flashing empty between passes.
    if (_callInfoActive) return 'call:$_callAtCursor';
    if (_gridOnlyLine case final line?) return 'grid:$line';
    return 'stats'; // stable across the ticker
  }

  /// A complete Maidenhead locator (4, 6 or 8 characters) — the shortest
  /// form a distance can be taken from.
  static final _completeGrid = RegExp(r'^[A-R]{2}[0-9]{2}([A-X]{2}([0-9]{2})?)?$', caseSensitive: false);

  /// With no callsign in the field but a grid typed — a microwave operator
  /// lining up a dish on a square before the other station is even named —
  /// the grid alone is enough to show the distance and bearing to it. A
  /// contest's own grid exchange (`field: 'grid'`) counts, and so does the
  /// core Grid field. Null when there is nothing to point at, or nothing to
  /// say about it: the app composes the line, and answers null when the
  /// operation has no location of its own — then the stats stay, rather than
  /// a person icon over a blank line hiding that "set our grid" is what's
  /// missing.
  String? get _gridOnlyLine {
    final guess = _gridOnlyGuess;
    if (guess == null) return null;
    final line = widget.lookups.callLocationLine?.call(guess);
    return (line == null || line.isEmpty) ? null : line;
  }

  Map<String, dynamic>? get _gridOnlyGuess {
    if (_callInfoActive || _editingEvent) return null;
    var grid = _exchange.valueForField('grid');
    if (grid.isEmpty && widget.prefs.showGridField) grid = _gridController.text.trim();
    if (!_completeGrid.hasMatch(grid)) return null;
    // The fields uppercase as typed; the line reads better as FN20aa.
    return {'grid': normalizeGrid(grid)};
  }

  /// The lookup entries backing the current call-info — live results when
  /// available, else the entries saved on the QSO being edited (`their.lookups`,
  /// which carry the call-notes `notes` array the merge doesn't fold into
  /// `guess`).
  List<Map<String, dynamic>> get _currentLookups {
    final live = asQsonList(_lookup.resultForActiveCall?['lookups'])?.whereType<Map<String, dynamic>>().toList();
    if (live != null) return live;
    final their = asQsonMap(widget.session.editingQso?.data['their']);
    return asQsonList(their?['lookups'])?.whereType<Map<String, dynamic>>().toList() ?? const [];
  }

  /// The current call-info payload for the detail panel, or null when the
  /// call-info panel isn't showing.
  CallInfoData? get _currentCallInfoData {
    // Mirror the compact area's priority: a command message wins over call-info.
    if (!_callInfoActive || _command.message != null) return null;
    return CallInfoData(
      call: _callAtCursor,
      guess: _currentGuess,
      lookups: _currentLookups,
      alertKeys: _lookup.currentAlertKeys,
      noticeKeys: _lookup.currentNoticeKeys,
      scoreSources: _lookup.currentScoreSources,
      isEditing: widget.session.editingQso != null,
      workedBefore: _lookup.workedBefore,
    );
  }

  /// Pushes the current call-info up to the host (deduped) — the Info tab's
  /// detail panel mirrors it. Called post-build so it never setStates a parent
  /// mid-build.
  String? _lastCallInfoSig;
  void _notifyCallInfo() {
    if (widget.lookups.onCallInfoChanged == null) return;
    final data = _currentCallInfoData;
    final g = data?.guess;
    final sig = data == null
        ? null
        : '${data.call}|${_lookup.lookupFor}|${data.isEditing}|${g?['name']}|${g?['grid']}|${g?['image']}|${g?['note']}'
              '|${data.alertKeys.join(",")}|${data.noticeKeys.join(",")}|${data.scoreSources}';
    if (sig == _lastCallInfoSig) return;
    _lastCallInfoSig = sig;
    widget.lookups.onCallInfoChanged!(data);
  }

  /// Pushes the QSO being composed up to the host (deduped), for consumers
  /// that need the whole draft rather than the call-info summary above —
  /// extension panels declaring the `qso` trigger.
  ///
  /// Deep-compared, not signature-compared like call-info: the draft's
  /// interesting parts are nested (`their`, `our`, `refs`) and a flat
  /// signature over them would be the same code as an equality check, only
  /// wrong whenever a field is added. The cost is bounded by the null check
  /// at the call site — a host with no such consumer never gets here.
  ///
  /// A published draft is READ-ONLY to everyone downstream. [QsoDraft.toData]
  /// shares nested references with the QSO being edited and with the lookup
  /// result, and every map handed out below shares those nested maps with
  /// the one kept here (the peer's IS it) — so mutating a published draft in
  /// place moves both sides of the comparison together, and the panel
  /// watching it silently stops updating.
  Map<String, dynamic>? _lastPublishedQso;
  List<PeerDraftField>? _lastPublishedFields;
  TemplateCalls? _lastPublishedCalls;
  void _notifyQsoDraft() {
    final wantsDraft = widget.session.onQsoChanged != null;
    final wantsPeer = widget.session.onPeerDraftChanged != null;
    if (!wantsDraft && !wantsPeer) return;
    // Built once and handed to both — the deep compare below is the expensive
    // half, not this.
    final qso = _draft.toData();
    final unchanged = const DeepCollectionEquality().equals(qso, _lastPublishedQso);
    // Deduped separately, never on `unchanged` alone: a report the operator
    // types over its own placeholder leaves the draft identical and changes
    // only what [_peerDraftFields] answers (see `onPeerDraftChanged`).
    if (wantsPeer) {
      final fields = _peerDraftFields();
      if (!unchanged || !const DeepCollectionEquality().equals(fields, _lastPublishedFields)) {
        _lastPublishedFields = fields;
        widget.session.onPeerDraftChanged!(qso, fields);
      }
    }
    if (wantsDraft) {
      // Deduped on the calls too: moving the cursor between stacked segments
      // changes which call `qso.call` names while the draft stays the same.
      final calls = _callText.templateCalls;
      if (!unchanged || calls != _lastPublishedCalls) widget.session.onQsoChanged!(_withCallField(qso, calls));
      _lastPublishedCalls = calls;
    }
    _lastPublishedQso = qso;
  }

  /// The main logging row as a peer's panel renders it, in the order this
  /// operator sees it.
  ///
  /// Read straight off [_primaryFields], which IS the row — so a control an
  /// activity contributes or the operator switches on appears here with no
  /// second list to keep in step, and sent/rcvd come out whichever way this
  /// device draws them.
  ///
  /// The value is the CONTROLLER's, never the draft's. An untouched field is
  /// empty here and carries its suggestion in `hint`, which is the whole
  /// distinction the receiving panel draws; the draft cannot answer it,
  /// because a report reaches the draft with its placeholder already folded
  /// in by `_rstOrDefault`.
  List<PeerDraftField> _peerDraftFields() => [
    for (final field in _primaryFields) (key: field.key, label: field.label, value: field.controller.text.trim(), hint: field.hint?.trim()),
  ];
}
