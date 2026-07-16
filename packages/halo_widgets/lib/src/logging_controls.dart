// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The QSO entry controls — the hottest path in the whole app. Keyboard
// ergonomics are the contract (DESIGN.md §7), ported from app-polo:
//   Enter   logs the QSO from anywhere in the controls
//   Esc     wipes the current entry
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
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:halo_core/halo_core.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'form_renderer.dart';
import 'icon_resolver.dart';
import 'mdi_icons.dart';
import 'platform_chrome.dart';
import 'ref_chips_input.dart';
import 'secondary_control_row.dart';
import 'text_formatters.dart';
import 'theme.dart';

/// Async callsign enrichment (name, location, grid…) from lookup sources —
/// the hardcoded callsign-annotation pre-step plus every registered
/// `lookup` hook, merged with locationScope-aware rules. `qso`/`operation`
/// give QSO-scoped hooks (e.g. POTA) access to refs already on the
/// in-progress QSO; `online: false` asks every hook to skip network access,
/// for a fast local-data-only preview pass. Returns `{lookups, guess}`, or
/// null meaning "nothing known". Must never throw.
typedef CallLookup = Future<Map<String, dynamic>?> Function(
  String call, {
  required Map<String, dynamic> qso,
  required Map<String, dynamic> operation,
  required bool online,
});

/// Tries the input as an extension-registered command (band/freq/mode
/// shortcuts, and eventually spotting/operator commands). Returns a
/// field-change map (`{freq?, band?, mode?}`) or a named `{action: ...}`
/// (e.g. `SYNCALL`), or null for "not a command". Must never throw.
/// [execute] is true only for the final call made right before actually
/// running a complete interpretation — see CommandHook.interpret's `execute`
/// doc (extensions/sdk/src/types.ts): a hook whose `commands` are expensive
/// to compute (e.g. SEED) may return a cheap describe-only result otherwise,
/// since this is also the function called on every typing-debounce preview.
typedef CommandInterpreter = Future<Map<String, dynamic>?> Function(
  String input, [
  Map<String, dynamic>? operation,
  Map<String, dynamic>? qso,
  bool execute,
]);

/// Handles a named command action — a closed set the core recognizes, not
/// arbitrary state (DESIGN.md §4). `params` carries whatever JSON payload
/// came with that action (e.g. `devNotice`'s icon/title/text).
typedef CommandActionHandler = Future<void> Function(String action, [Map<String, dynamic>? params]);

/// Which `spots` hooks currently offer self- or other-spotting — `qso: null`
/// asks about self-spotting the operation, `qso` set asks about spotting
/// that QSO's station. Mirrors `ExtensionService.suggestSpotSources`.
typedef SuggestSpotSources = Future<List<Map<String, dynamic>>> Function({
  required Map<String, dynamic> operation,
  Map<String, dynamic>? qso,
});

/// Posts a spot via every hook in `sources` and returns `{hookKey:
/// PostResult}`. Mirrors `ExtensionService.sendSpot`.
typedef SendSpot = Future<Map<String, Map<String, dynamic>>> Function({
  required List<Map<String, dynamic>> sources,
  required Map<String, dynamic> operation,
  Map<String, dynamic>? qso,
  double? freq,
  String? mode,
  String? comment,
  String? spotterCall,
});

/// A secondary control's identity for ordering/visibility purposes — the
/// settings dialog's list and `_effectiveControlOrder` deal in these; the
/// actual `SecondaryControlSpec` (which carries the live summary and
/// expanded-input builder) is only built for controls that end up visible.
class _ControlDescriptor {
  final String key;
  final IconData icon;
  final String label;

  /// Time and Radio — can't be hidden, so the settings dialog shows their
  /// checkbox permanently checked and disabled.
  final bool mandatory;

  const _ControlDescriptor({
    required this.key,
    required this.icon,
    required this.label,
    this.mandatory = false,
  });
}

/// Horizontal padding around the panel's fields — also handed to
/// [SecondaryControlRow] so its expanded control panel can bleed past it
/// and reach the view's true edges.
const _secondaryPanelHorizontalInset = 12.0;

class LoggingControls extends StatefulWidget {
  final Operation operation;
  final QsosRepository qsosRepository;

  /// Current QSOs in the operation, used for dupe hints.
  final List<Qso> qsos;
  final void Function(Qso qso)? onLogged;

  /// Fires once after a comma-separated call list (issue #7) finishes
  /// saving all its QSOs — never for an ordinary single-call log, which
  /// already gets its (cheap, cached) dupe/lookup handling inline. Intended
  /// for the caller to trigger a single rescoring pass for the whole batch,
  /// rather than scoring each call as it's added.
  final VoidCallback? onCallListLogged;

  /// Optional lookup enrichment; fired debounced, off the keystroke path.
  final CallLookup? lookup;

  /// Declarative activity control descriptors from extensions (UI catalog).
  /// v0 supports `input.kind == 'refList'`; each becomes a chip in the
  /// secondary control row alongside the built-in Time and Radio controls.
  final List<Map<String, dynamic>> activityControls;

  /// Re-fetches `activityControls` scoped to the given in-progress QSO —
  /// called once the debounced callsign lookup's fast, local-data-only
  /// offline pass resolves (not on every keystroke, and deliberately not
  /// fired again after the slower online pass — see the call site's
  /// comment), so an extension can key a QSO-scoped `placeholder`/
  /// `transforms` (e.g. a DXCC-derived reference prefix) off
  /// `qso.their.guess`. When null, or while a refresh is pending,
  /// `activityControls` is used as-is.
  final Future<List<Map<String, dynamic>>> Function(Map<String, dynamic> qso)? refreshActivityControls;

  /// Async ref decoration via the extension runtime.
  final RefDecorator? decorateRef;

  /// Extension-backed command shortcuts, tried on space in the call field.
  /// When null, space in the call field just advances focus.
  final CommandInterpreter? interpretCommand;

  final void Function(String? message)? onCommandMessageChanged;

  /// Handles a command's named `action` (e.g. `SYNCALL`), when the command
  /// returns one instead of a field change. When null, actions are ignored.
  final CommandActionHandler? onCommandAction;

  /// When set, the controls are editing this already-logged QSO rather than
  /// composing a new one — fields are populated from it, saving calls
  /// `qsosRepository.update` instead of `.add`, and Delete/Revert become
  /// available. The Time control's behavior already depended on the
  /// distinction before this: editing an existing entry shows *its*
  /// recorded time instead of a live clock, and has no "Now" reset (there's
  /// no "automatic" time to reset back to for a historical record).
  final Qso? editingQso;

  /// A QSON-shaped `{their: {call}, freq?, band?, mode?, refs?}` map to
  /// prefill a new QSO's fields from — e.g. tapping a spot in the Spots
  /// Panel. Applied via the same field-population path as `editingQso`
  /// (`_applyFieldsFromData`), but never switches this widget into editing
  /// mode: Save still calls `.add`, not `.update`, and a suggestion arriving
  /// while `editingQso` is already set is ignored rather than overwriting
  /// that edit. Re-applies whenever a NEW map (by identity, not deep
  /// equality — same convention as `operation.data['refs']` change
  /// detection below) is passed in.
  final Map<String, dynamic>? suggestedQso;

  /// Fires when an editing session ends without necessarily going through
  /// `onLogged` — a save of an existing QSO, a delete, or an explicit
  /// revert. The caller (which owns the selected-QSO state) clears its
  /// selection in response; this widget's own fields reset via
  /// `didUpdateWidget` once `editingQso` becomes null on the next build.
  final VoidCallback? onEditCanceled;

  /// Settings engine interface.
  final SyncSettings? settings;

  /// Holds the radio's VFO state (`vfoA`) — device-global, shared by every
  /// operation, not scoped to this one. Used to seed the Radio control for
  /// a new QSO instead of resetting to a hardcoded default, and as the
  /// destination for its edits. When null, the Radio control behaves as it
  /// did before this state existed — purely local to this widget.
  final VfoStore? radioService;

  /// The user's preferred order for the secondary control chips, by key
  /// (`'time'`, `'radio'`, an activity control's own key, `'more'`). Keys
  /// this doesn't mention are appended in their default order; keys it
  /// mentions that no longer exist (e.g. an uninstalled extension) are
  /// ignored. Persisted by the caller — see `_effectiveControlOrder`.
  final List<String> controlOrder;

  /// Control keys hidden from the row. Time and Radio are never hidden
  /// regardless of what's in here — enforced by this widget, not the
  /// caller, so a corrupted/stale preference can't hide either.
  final Set<String> hiddenControlKeys;

  /// Fires when the user changes order or visibility in the controls
  /// settings dialog. The caller owns persisting it and feeding it back as
  /// `controlOrder`/`hiddenControlKeys` on the next build.
  final void Function(List<String> order, Set<String> hidden)? onControlsSettingsChanged;

  final String? timeLabel;
  final String? dateLabel;
  final String? nowLabel;
  final String? freqLabel;
  final String? modeLabel;
  final String? dupeLabel;
  final String? theirCallLabel;
  final String? sentLabel;
  final String? rcvdLabel;
  final String? moreLabel;
  final String? revertLabel;
  final String? deleteLabel;
  final String? undoDeleteLabel;
  final String? restoreLabel;
  final String? wipeLabel;
  final String? undoLabel;
  final String? pendingDeleteWarning;
  final String? deletedQsoWarning;
  final String? qsoEditFormTitle;
  final String? theirNameLabel;
  final String? theirGridLabel;
  final String? theirStateLabel;
  final String? notesLabel;
  final String? bandLabel;
  final String? timeControlLabel;
  final String? radioControlLabel;
  final String? controlSettingsTitle;
  final String? saveLabel;
  final String? cancelLabel;

  /// Spotting control (ham2k/app-halo-dist#10) — null (either) disables the
  /// control's icon-row/send-button UI, matching how `radioService: null`
  /// degrades the Radio control elsewhere in this widget.
  final SuggestSpotSources? suggestSpotSources;
  final SendSpot? sendSpot;
  final String? spottingControlLabel;
  /// Collapsed-pill label while spotting the QSO being edited — "Spotting".
  final String? spottingLabel;
  /// Collapsed-pill label otherwise (composing, or nothing selected) —
  /// "Self-spotting". Distinct from `spotSelfLabel`, the longer dynamic
  /// button text shown only in the expanded panel.
  final String? spottingSelfLabel;
  final String Function(String freq)? spotSelfLabel;
  final String Function(String call, String freq)? spotOtherLabel;
  final String Function(String call)? spotTooLateLabel;
  final String? spotNoFreqLabel;
  final String? spotCommentHint;

  /// Logging view "..." menu toggles (ham2k/app-halo-dist#1) — gate the
  /// Sent/Rcvd RST fields and add optional inline State/Grid fields. The
  /// underlying data (State/Grid) is always editable via the "More" pane
  /// regardless of these flags; they only control the primary controls'
  /// permanent footprint.
  final bool showRSTFields;
  final bool showStateField;
  final bool showGridField;

  const LoggingControls({
    super.key,
    required this.operation,
    required this.qsosRepository,
    this.qsos = const [],
    this.onLogged,
    this.onCallListLogged,
    this.lookup,
    this.activityControls = const [],
    this.refreshActivityControls,
    this.decorateRef,
    this.interpretCommand,
    this.onCommandMessageChanged,
    this.onCommandAction,
    this.editingQso,
    this.suggestedQso,
    this.onEditCanceled,
    this.settings,
    this.radioService,
    this.controlOrder = const [],
    this.hiddenControlKeys = const {},
    this.onControlsSettingsChanged,
    this.timeLabel,
    this.dateLabel,
    this.nowLabel,
    this.freqLabel,
    this.modeLabel,
    this.dupeLabel,
    this.theirCallLabel,
    this.sentLabel,
    this.rcvdLabel,
    this.moreLabel,
    this.revertLabel,
    this.deleteLabel,
    this.undoDeleteLabel,
    this.restoreLabel,
    this.wipeLabel,
    this.undoLabel,
    this.pendingDeleteWarning,
    this.deletedQsoWarning,
    this.qsoEditFormTitle,
    this.theirNameLabel,
    this.theirGridLabel,
    this.theirStateLabel,
    this.notesLabel,
    this.bandLabel,
    this.timeControlLabel,
    this.radioControlLabel,
    this.controlSettingsTitle,
    this.saveLabel,
    this.cancelLabel,
    this.suggestSpotSources,
    this.sendSpot,
    this.spottingControlLabel,
    this.spottingLabel,
    this.spottingSelfLabel,
    this.spotSelfLabel,
    this.spotOtherLabel,
    this.spotTooLateLabel,
    this.spotNoFreqLabel,
    this.spotCommentHint,
    this.showRSTFields = true,
    this.showStateField = false,
    this.showGridField = false,
  });

  @override
  State<LoggingControls> createState() => _LoggingControlsState();
}

class _LoggingControlsState extends State<LoggingControls> {
  final _callController = TextEditingController();
  final _sentController = TextEditingController();
  final _rcvdController = TextEditingController();
  final _freqController = TextEditingController();
  final _timeController = TextEditingController();
  final _dateController = TextEditingController();
  final _gridController = TextEditingController();
  final _stateController = TextEditingController();
  final _callFocus = FocusNode();
  final _sentFocus = FocusNode();
  final _rcvdFocus = FocusNode();
  final _freqFocus = FocusNode();
  final _timeFocus = FocusNode();
  final _gridFocus = FocusNode();
  final _stateFocus = FocusNode();

  String _mode = 'SSB';

  /// Band set via a "20m " command when no frequency is entered.
  String? _manualBand;
  bool _rstsTouched = false;

  /// Which secondary control (if any) currently has its input expanded.
  String? _selectedControlKey;

  /// The last command message pushed to the parent via
  /// `onCommandMessageChanged`. Every keystroke used to fire that callback
  /// with `null` unconditionally, and the parent (LoggingPanel) answered
  /// with a setState that rebuilds the whole QsoList — day-bucketing,
  /// per-column TextPainter measurement, the scores map, all O(n) over the
  /// log, per keystroke. Deduping here means the callback only fires on a
  /// real change. Starts null, matching the parent's own initial "no
  /// message" state, so a redundant null is a no-op.
  String? _lastSentCommandMessage;

  /// Overrides the QSO's timestamp when set via the Time control; null
  /// means "use the current time at the moment of logging."
  int? _manualStartAtMillis;

  /// Ticks once a second so the Time chip shows a live clock while nothing
  /// overrides it — only runs while it's actually needed (see
  /// _updateClockTicker), not for the whole panel's lifetime.
  Timer? _clockTicker;

  Timer? _lookupDebounce;
  String? _lookupFor;
  Map<String, dynamic>? _lookupResult;

  /// `widget.activityControls`, re-fetched for the current QSO once its
  /// callsign lookup resolves — see `widget.refreshActivityControls`. Reset
  /// to null (falling back to `widget.activityControls`) whenever the call
  /// field is cleared, so a stale QSO-scoped placeholder/transform doesn't
  /// linger onto the next entry.
  List<Map<String, dynamic>>? _refreshedActivityControls;

  List<Map<String, dynamic>> get _effectiveActivityControls => _refreshedActivityControls ?? widget.activityControls;

  /// Pending push of a manually-typed frequency to `widget.radioService` —
  /// see `_onFreqChanged` and `_pushVfoToRadioService`.
  Timer? _vfoDebounce;

  Map<String, dynamic>? _currentInterpretation;
  Timer? _commandDescribeDebounce;

  /// The last interpret() result retained for the call field's INPUT MODE —
  /// deliberately a separate field from [_currentInterpretation], which
  /// resets synchronously on every keystroke (for the describe-message UI):
  /// the field's formatters/capitalization must not flicker back to
  /// uppercase-only between keystrokes while a command's parameters are
  /// still being typed. Updated only through [_retainInterpretation]; reset
  /// when the field empties, on log/wipe, and whenever a QSO context is
  /// populated (spot tap, edit selection, undo restore). One retained map
  /// instead of parallel per-flag booleans, so a reset site can't clear one
  /// flag and miss another.
  Map<String, dynamic>? _retainedInterpretation;

  /// Whether the retained command is a recognized prefix still awaiting its
  /// parameters ("RELOAD" before its target) — space is a literal character
  /// and the callsign character filter is lifted, but input stays
  /// uppercase-only unless [_commandMixedCase] also holds.
  bool get _commandExpectsParams => _retainedInterpretation?['expectsParams'] == true;

  /// Whether the retained command declared `mixedCase: true` — only such
  /// commands (e.g. NOTE, whose parameter is free prose) release the call
  /// field from its uppercase-only rule. Extensions return it on BOTH the
  /// bare-prefix and complete results (see CommandInterpretation in the SDK
  /// types), so it stays in effect while "NOTE Hello…" keeps being typed.
  bool get _commandMixedCase => _retainedInterpretation?['mixedCase'] == true;

  /// Matches text the callsign-mode formatters would pass through except
  /// for case — see [_retainInterpretation].
  static final _callsignModeSafeText = RegExp(r'^[a-zA-Z0-9/.,]*$');

  /// Folds a fresh interpret() result into [_retainedInterpretation]. A
  /// non-null result always replaces the previous one. A null result (the
  /// text no longer matches any command) only clears it when the current
  /// text would survive the returning callsign formatters: those rewrite
  /// the ENTIRE field on the next keystroke, so snapping back while it
  /// holds free prose ("NOT Called Bob" after backspacing a typo in
  /// "NOTE") would irrecoverably strip every space. Uppercasing alone is
  /// the field's normal behavior, so case differences don't block the
  /// reset — only characters the filter would delete do. The retained mode
  /// then clears via the empty-field/log/wipe/populate resets instead.
  void _retainInterpretation(Map<String, dynamic>? result) {
    if (result != null) {
      _retainedInterpretation = result;
    } else if (_callsignModeSafeText.hasMatch(_callController.text)) {
      _retainedInterpretation = null;
    }
  }

  Timer? _executeMessageTimer;
  String? _commandMessage;
  final Map<String, dynamic> _currentQsoExtra = {};

  /// Refs entered via activity controls for the QSO being composed,
  /// keyed by control key.
  final Map<String, List<Map<String, dynamic>>> _controlRefs = {};

  /// Refs from `editingQso.refs` whose `type` matched no currently
  /// registered activity control — round-tripped back into `refs` on save
  /// rather than silently dropped, even though no UI can show them.
  List<Map<String, dynamic>> _unmatchedRefs = const [];

  /// Set while editing an existing QSO and Delete has been tapped but not
  /// yet saved — mirrors app-polo's `_willBeDeleted` staged-delete flag.
  bool _pendingDelete = false;

  /// Whether the form is a read-only view: a staged delete, or an
  /// already-deleted QSO awaiting restore (ham2k/app-halo-dist#59). Every
  /// input path — fields, save, keyboard shortcuts — must consult this,
  /// not `_pendingDelete` alone.
  bool get _fieldsLocked => _pendingDelete || (widget.editingQso?.deleted ?? false);

  /// Their name override, settable only via the "More" edit pane —
  /// deliberately not a full inline field, to avoid growing the primary
  /// controls' footprint for rarely-edited data. Grid/State have their own
  /// controllers (`_gridController`/`_stateController`) instead, since they
  /// can also appear as optional primary fields (`showGridField`/
  /// `showStateField`).
  String? _theirNameOverride;

  /// Whether the user has actually edited Grid/State (inline field or the
  /// "More" pane) for the QSO currently being composed/edited — as
  /// opposed to `_gridController`/`_stateController` merely displaying a
  /// value populated from `editingQso.theirGrid`/`theirState` on load. Only
  /// a deliberate edit is sticky across a comma-separated call list (see
  /// `dataFor` below); an untouched, merely-displayed value must not
  /// clobber a fresh per-call lookup's own grid/state.
  bool _gridTouched = false;
  bool _stateTouched = false;

  /// Spotting control state (ham2k/app-halo-dist#10) — lives here, not in
  /// `expandedBuilder`'s closure, since that's a plain render function
  /// re-invoked on every build, not a separately-stateful widget.
  final _spotCommentController = TextEditingController();
  List<Map<String, dynamic>> _spotSources = const [];
  final Map<String, bool?> _spotStatus = {}; // hookKey -> ok/failed/neutral(null)
  Timer? _spotStatusClearTimer;
  bool _spotSending = false;

  /// True while `didUpdateWidget` is populating controllers from a newly
  /// selected `editingQso` — suppresses `_onCallChanged`'s lookup/command
  /// side effects, which would otherwise re-query and overwrite stored
  /// `their.*` fields for a call that's already known.
  bool _populating = false;

  /// A wiped-but-not-yet-lost new QSO, stashed by the wipe button so the
  /// same button can flip to "undo" for a few seconds afterward. Only
  /// meaningful while composing a new QSO (`editingQso == null`).
  Map<String, dynamic>? _undoQsoData;
  Timer? _undoExpireTimer;

  /// Guards against double-logging: Enter is bound both as a keyboard
  /// shortcut and as every field's onSubmitted, and can also auto-repeat.
  bool _isLogging = false;

  /// The submit button's rendered diameter, measured post-frame (its own
  /// size comes from IntrinsicHeight/AspectRatio further down the tree, so
  /// it isn't known until after layout) and reused to size the info row's
  /// second button identically — see _buildWipeOrEditButton.
  final GlobalKey _submitButtonKey = GlobalKey();
  double? _editButtonDiameter;

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
    _applyDefaultRSTs();
    // Population normally happens in didUpdateWidget, as editingQso
    // transitions from null to a selected QSO — but if this widget is ever
    // constructed with editingQso already set (rather than transitioning
    // into it), that transition never fires. Applying it here too, before
    // any listeners are attached below, covers that case for free with no
    // risk of triggering their side effects.
    if (widget.editingQso != null) {
      _applyFieldsFromData(widget.editingQso!.data);
    } else {
      _seedFromRadioService();
      // Wins over the generic VFO seed above — a suggestion is specific
      // operator intent ("log THIS call"), the VFO seed is just ambient
      // radio state.
      if (widget.suggestedQso != null) _applySuggestedQso(widget.suggestedQso!);
    }
    _seedTimeFields();
    _updateClockTicker();
    _callController.addListener(_onCallChanged);
    _freqController.addListener(_onFreqChanged);
    _timeController.addListener(_onTimeOrDateFieldChanged);
    _dateController.addListener(_onTimeOrDateFieldChanged);
    // Sent/Rcvd don't otherwise need a rebuild on every keystroke, but the
    // info row's second button (_buildWipeOrEditButton) re-evaluates
    // _qsoDataChanged() on every build, which reads these controllers —
    // without a rebuild, editing just the RST wouldn't flip that button
    // from "delete" to "revert changes".
    _sentController.addListener(_onSentOrRcvdChanged);
    _rcvdController.addListener(_onSentOrRcvdChanged);
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
      (_freqFocus, _freqController),
      (_timeFocus, _timeController),
      (_gridFocus, _gridController),
      (_stateFocus, _stateController),
    ]) {
      focus.addListener(() {
        if (focus.hasFocus) {
          controller.selection = TextSelection.collapsed(offset: controller.text.length);
        } else if (identical(focus, _freqFocus)) {
          // Flush a pending debounced push immediately on blur, rather than
          // making the user wait out the rest of the 5s window. Never fires
          // while editing an existing QSO — see _onFreqChanged.
          _vfoDebounce?.cancel();
          if (widget.editingQso == null && _freqController.text.trim().length > 3) {
            _pushVfoToRadioService();
          }
        }
      });
    }
    _refreshSpotSources();
  }

  @override
  void didUpdateWidget(LoggingControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editingQso?.uuid != widget.editingQso?.uuid) {
      _resetEditingSessionState();
      if (widget.editingQso != null) {
        _populateFromEditingQso(widget.editingQso!);
      } else {
        _resetLocalFields();
      }
      _updateClockTicker();
      // Self- vs other-spot eligibility can differ per extension (e.g. only
      // self-spotting an operation with an activation ref) — re-fetch
      // whenever what's being spotted changes.
      _spotSources = const [];
      _spotStatus.clear();
      _refreshSpotSources();
      return;
    }
    // Nothing below applies while editing an existing QSO — a suggestion or
    // a refs change must never clobber an in-progress edit.
    if (widget.editingQso != null) return;

    // While composing a new QSO, self-spot eligibility depends on the
    // operation's own activation refs (not editingQso, which stays null
    // throughout) — refresh when those refs change too.
    if (!identical(oldWidget.operation.data['refs'], widget.operation.data['refs'])) {
      _refreshSpotSources();
    }

    // A new suggestion (e.g. tapping a different spot) — same reset scope
    // as the editingQso-change branch above, applied for it instead.
    // Deliberately independent from the refs check above (not `else if`),
    // so both can fire in the same call — e.g. an operation-refs change and
    // a spot tap landing in the same frame would otherwise let one silently
    // suppress the other.
    if (widget.suggestedQso != null && !identical(oldWidget.suggestedQso, widget.suggestedQso)) {
      _resetEditingSessionState();
      _applySuggestedQso(widget.suggestedQso!);
      _updateClockTicker();
      _spotSources = const [];
      _spotStatus.clear();
      _refreshSpotSources();
    }
  }

  /// Editing-session bookkeeping that must never leak from one QSO context
  /// into the next — shared by the editingQso-change and suggestedQso-change
  /// paths in `didUpdateWidget`, which both start a fresh context.
  void _resetEditingSessionState() {
    _pendingDelete = false;
    _theirNameOverride = null;
    _gridTouched = false;
    _stateTouched = false;
    _undoExpireTimer?.cancel();
    _undoExpireTimer = null;
    _undoQsoData = null;
  }

  /// Which `spots` hooks currently offer self- or other-spotting, for the
  /// Spotting control's icon row — shown before sending, not just after.
  Future<void> _refreshSpotSources() async {
    final suggest = widget.suggestSpotSources;
    if (suggest == null) return;
    final sources = await suggest(operation: widget.operation.data, qso: widget.editingQso?.data);
    if (mounted) setState(() => _spotSources = sources);
  }

  /// Populates controllers/state from an existing QSO selected for editing.
  /// Local-state only — never calls parent-notifying callbacks (this runs
  /// from `didUpdateWidget`, where a synchronous `setState` back up the
  /// tree could throw).
  void _populateFromEditingQso(Qso qso) {
    _populating = true;
    _applyFieldsFromData(qso.data);
    _manualStartAtMillis = null; // _effectiveStartAtMillis falls back to editingQso.startAtMillis
    setState(() {});
    _populating = false;
  }

  /// Populates controllers/state from a `suggestedQso` map (e.g. tapping a
  /// spot) — same wrapping as `_populateFromEditingQso`, for a QSO being
  /// composed rather than an existing one being edited.
  ///
  /// Unlike `editingQso` (a real saved record, where a blank Sent/Rcvd
  /// faithfully represents stored data), a suggestion composes a NEW QSO —
  /// `_applyFieldsFromData` unconditionally blanks Sent/Rcvd when the
  /// suggestion doesn't carry RST (spots never do today), which would
  /// wipe out the normal new-QSO default RST and — via `_rstsTouched` —
  /// suppress it from ever coming back on a mode change. If the suggestion
  /// DID carry RST (`our.sent`/`their.sent` — e.g. a future deeplink), keep
  /// it, matching `_applyFieldsFromData`'s own behavior for editingQso.
  void _applySuggestedQso(Map<String, dynamic> data) {
    _populating = true;
    _applyFieldsFromData(data);
    final our = data['our'] as Map<String, dynamic>? ?? const {};
    final their = data['their'] as Map<String, dynamic>? ?? const {};
    final hasRst = (our['sent'] as String?)?.isNotEmpty == true || (their['sent'] as String?)?.isNotEmpty == true;
    if (!hasRst) _applyDefaultRSTs();
    _manualStartAtMillis = null;
    setState(() {});
    _populating = false;
  }

  /// Shared by `_populateFromEditingQso` (loading an existing record for
  /// editing) and `_restoreFromUndoSlot` (undoing a wipe) — both need to
  /// push a `data` map from a `Qso`/`_getCurrentQsoData()` shape back into
  /// the live controllers/state.
  void _applyFieldsFromData(Map<String, dynamic> data) {
    final our = data['our'] as Map<String, dynamic>? ?? const {};
    final their = data['their'] as Map<String, dynamic>? ?? const {};
    _callController.text = (their['call'] as String?) ?? '';
    _sentController.text = (our['sent'] as String?) ?? '';
    _rcvdController.text = (their['sent'] as String?) ?? '';
    _rstsTouched = true;
    final theirGuess = their['guess'] as Map<String, dynamic>? ?? const {};
    _gridController.text = (their['grid'] as String?) ?? (theirGuess['grid'] as String?) ?? '';
    _stateController.text = (their['state'] as String?) ?? (theirGuess['state'] as String?) ?? '';
    // Restore the name override too, or wipe-then-undo would silently drop a
    // name set via the "More" pane (it round-trips as `their.name`).
    final theirName = (their['name'] as String?)?.trim();
    _theirNameOverride = (theirName == null || theirName.isEmpty) ? null : theirName;
    final freq = (data['freq'] as num?)?.toDouble();
    // Full precision (not fmtFreq's 100Hz display rounding): selecting a QSO
    // logged at 14074.25 must not flag it as changed or save "14074.3" back.
    _freqController.text = freq != null ? fmtFreqInput(freq) : '';
    _mode = data['mode'] as String? ?? _mode;
    _manualBand = freq == null ? data['band'] as String? : null;
    _currentQsoExtra
      ..clear()
      ..addAll(data)
      ..remove('refs')
      ..remove('our')
      ..remove('their')
      ..remove('freq')
      ..remove('band')
      ..remove('mode')
      ..remove('startAtMillis');
    _controlRefs.clear();
    _unmatchedRefs = [];
    final refs = (data['refs'] as List?)?.whereType<Map>().map((r) => r.cast<String, dynamic>()) ?? const [];
    for (final ref in refs) {
      String? key;
      for (final control in _effectiveActivityControls) {
        if ((control['input'] as Map?)?['refType'] == ref['type']) {
          key = control['key'] as String?;
          break;
        }
      }
      if (key != null) {
        (_controlRefs[key] ??= []).add(ref);
      } else {
        _unmatchedRefs.add(ref);
      }
    }
    _lookupFor = null;
    _lookupResult = null;
    _refreshedActivityControls = null;
    _selectedControlKey = null;
    // Command state must never survive into a freshly populated QSO
    // context: this runs under `_populating`, so _onCallChanged's own
    // per-keystroke reset is suppressed. Without this, typing "NOTE hi",
    // then tapping a spot, would leave the call field showing a real
    // callsign while still in the note's mixed-case free-text mode — and a
    // stale complete interpretation would make Space insert a literal
    // space (or Enter execute the old command) instead of acting on the
    // callsign.
    _currentInterpretation = null;
    _retainedInterpretation = null;
    _commandMessage = null;
  }

  /// Seeds freq/band/mode from the operation's `vfoA` when composing a new
  /// QSO — the operation's last-known radio state, rather than a hardcoded
  /// default. Never called while editing an existing QSO, whose own
  /// recorded freq/band/mode always takes priority (`_applyFieldsFromData`).
  void _seedFromRadioService() {
    final vfo = widget.radioService?.vfoA;
    if (vfo == null) return;
    final freq = vfo.freq;
    _freqController.text = freq != null ? fmtFreqInput(freq) : '';
    _manualBand = freq == null ? vfo.band : null;
    if (vfo.mode != null) _mode = vfo.mode!;
  }

  /// Pushes the current freq/band/mode to `widget.radioService` as `vfoA`.
  void _pushVfoToRadioService() {
    widget.radioService?.setVfo('vfoA', freq: _freq, band: _band, mode: _mode);
  }

  /// Clears local fields when an editing session ends (mirrors the
  /// local-state portion of `_wipe()`, without `_wipe()`'s parent callback —
  /// see `didUpdateWidget`).
  void _resetLocalFields() {
    // Guards _onCallChanged (fired synchronously by _callController.clear()
    // below) from calling widget.onCommandMessageChanged — a parent-state
    // setState — while still inside didUpdateWidget.
    _populating = true;
    _callController.clear();
    _applyDefaultRSTs();
    _gridController.clear();
    _stateController.clear();
    _gridTouched = false;
    _stateTouched = false;
    _lookupDebounce?.cancel();
    _vfoDebounce?.cancel();
    _commandDescribeDebounce?.cancel();
    _executeMessageTimer?.cancel();
    _lookupFor = null;
    _lookupResult = null;
    _refreshedActivityControls = null;
    _controlRefs.clear();
    _unmatchedRefs = [];
    _currentQsoExtra.clear();
    _manualStartAtMillis = null;
    _manualBand = null;
    _selectedControlKey = null;
    // Back to composing a new QSO — the Radio control goes back to
    // mirroring the operation's VFO, not whatever the just-edited QSO's
    // own freq/band/mode happened to be.
    _seedFromRadioService();
    setState(() {
      _commandMessage = null;
      _currentInterpretation = null;
      _retainedInterpretation = null;
    });
    _populating = false;
  }

  @override
  void dispose() {
    _clockTicker?.cancel();
    _lookupDebounce?.cancel();
    _vfoDebounce?.cancel();
    _commandDescribeDebounce?.cancel();
    _executeMessageTimer?.cancel();
    _undoExpireTimer?.cancel();
    _spotStatusClearTimer?.cancel();
    _spotCommentController.dispose();
    _callController.dispose();
    _sentController.dispose();
    _rcvdController.dispose();
    _freqController.dispose();
    _timeController.dispose();
    _dateController.dispose();
    _gridController.dispose();
    _stateController.dispose();
    _callFocus.dispose();
    _sentFocus.dispose();
    _rcvdFocus.dispose();
    _freqFocus.dispose();
    _gridFocus.dispose();
    _stateFocus.dispose();
    _timeFocus.dispose();
    super.dispose();
  }

  String get _call => _callController.text.trim().toUpperCase();

  /// Trimmed call-field text WITHOUT forcing uppercase — used only for
  /// command interpretation, so free-text parameters (e.g. NOTE's captured
  /// text) keep the case the user actually typed. Command prefixes
  /// themselves are matched case-insensitively by every extension, so this
  /// is safe to use in place of `_call` for that one purpose.
  String get _commandInput => _callController.text.trim();

  /// The operation QSON with `uuid` folded in — same shape as the Dart
  /// side's `qsonPayloadFor` gives every coarse hook call. Command hooks
  /// need the uuid to fetch log data through the runtime's
  /// `ctx.getOperation`/`ctx.getQsos` (e.g. dev-commands' SEED reading the
  /// existing log's time range); the QSON alone doesn't carry it.
  Map<String, dynamic> get _operationDataForCommands => {
        ...widget.operation.data,
        'uuid': widget.operation.uuid,
      };

  /// Comma-separated calls typed into the call field — "W1AW, K1ABC" logs
  /// one QSO per call (issue #7) rather than one QSO whose call is the
  /// literal joined string. A single call with no comma is just a one-item
  /// list, so this also covers the common case.
  List<String> get _callList => _call.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  /// The single call that's actually relevant right now — the whole field
  /// for a plain callsign, whichever "//"-stacked segment
  /// `_pickStackedCall` would pick (issue #7's call stacking, new QSOs
  /// only), or whichever comma-separated segment the cursor sits in (issue
  /// #7's call lists, new or editing). Neither the on-screen lookup
  /// preview nor the DUPE chip make sense against the raw, multi-call
  /// field text, so both key off this instead. "//" takes priority over
  /// "," — a field can't meaningfully be both a stack and a list at once,
  /// and "//" is the more specific syntax.
  String get _callAtCursor {
    final text = _callController.text;
    if (widget.editingQso == null && text.contains('//')) {
      return _pickStackedCall()?.call ?? _call;
    }
    if (!text.contains(',')) return _call;
    final segments = text.split(',');
    final cursor = _callController.selection.baseOffset;
    var index = segments.length - 1;
    if (cursor >= 0) {
      var offset = 0;
      for (var i = 0; i < segments.length; i++) {
        offset += segments[i].length;
        if (cursor <= offset) {
          index = i;
          break;
        }
        offset += 1; // the "," separator
      }
    }
    return segments[index].trim().toUpperCase();
  }

  double? get _freq => parseFreq(_freqController.text);
  String? get _band => _freq != null ? bandForFrequency(_freq!) : _manualBand;
  bool get _canLog {
    // Call stacking (issue #7): "//" takes priority over a comma-separated
    // list — "//"-separated calls/fragments aren't a single valid callsign,
    // but log is still possible as long as one of the stacked segments is —
    // see _pickStackedCall. Only while composing a new QSO.
    if (widget.editingQso == null && _callController.text.contains('//')) {
      return _pickStackedCall() != null;
    }
    return _callList.isNotEmpty && _callList.every(looksLikeCallsign);
  }

  /// Call stacking (issue #7): the call field holds "//"-separated calls or
  /// fragments (e.g. "K1ABC//W1AW" — a second call typed in while the first
  /// is still queued up). Scanning left from the cursor, picks the first
  /// segment that's a valid callsign and returns it alongside the remaining
  /// segments (still "//"-joined) to leave in the field for the next QSO.
  /// Only applies to new QSOs, not editing an existing one. Takes priority
  /// over the comma-separated call list (issue #7) — a field can't
  /// meaningfully be both a stack and a list at once, and "//" is the more
  /// specific syntax.
  ({String call, String remainder})? _pickStackedCall() {
    final text = _callController.text;
    if (!text.contains('//')) return null;
    final segments = text.split('//');

    final cursor = _callController.selection.baseOffset;
    var cursorSegment = segments.length - 1;
    if (cursor >= 0) {
      var offset = 0;
      for (var i = 0; i < segments.length; i++) {
        offset += segments[i].length;
        if (cursor <= offset) {
          cursorSegment = i;
          break;
        }
        offset += 2; // the "//" separator
      }
    }

    for (var i = cursorSegment; i >= 0; i--) {
      final candidate = segments[i].trim().toUpperCase();
      if (looksLikeCallsign(candidate)) {
        final remainder = [...segments]..removeAt(i);
        return (call: candidate, remainder: remainder.join('//'));
      }
    }
    return null;
  }

  // Excludes the QSO currently being edited — otherwise, since its call/
  // mode/band are exactly what populated the fields in the first place,
  // editing any existing QSO would immediately flag itself as its own
  // duplicate.
  bool get _isDupe => widget.qsos.any(
    (qso) =>
        qso.uuid != widget.editingQso?.uuid &&
        qso.theirCall == _callAtCursor &&
        qso.mode == _mode &&
        (qso.band ?? '') == (_band ?? ''),
  );

  void _onFreqChanged() {
    if (_freq != null) _manualBand = null;
    setState(() {});
    // Editing an existing QSO applies changes to the QSO, never the VFO —
    // only a new (composing) QSO's Radio control mirrors/edits the VFO.
    if (_populating || widget.editingQso != null) return;
    // Only push once there's enough digits to plausibly be a real
    // frequency (mirrors the frequency command's own `length < 3` reject),
    // debounced so we're not writing to the operation on every keystroke.
    _vfoDebounce?.cancel();
    if (_freqController.text.trim().length > 3) {
      _vfoDebounce = Timer(const Duration(seconds: 5), _pushVfoToRadioService);
    } else if (_freqController.text.trim().isEmpty) {
      // Clearing the field is unambiguous — push it immediately rather than
      // debouncing, so dependents reading radioService.vfoA (e.g. the
      // Spotting control) drop the stale frequency right away.
      widget.radioService?.setVfo('vfoA', clearFreq: true, band: _manualBand, mode: _mode);
    }
  }

  void _onSentOrRcvdChanged() => setState(() {});

  void _applyDefaultRSTs() {
    _sentController.text = defaultRSTFor(_mode);
    _rcvdController.text = defaultRSTFor(_mode);
    _rstsTouched = false;
  }

  void _setMode(String mode) {
    setState(() {
      _mode = mode;
      if (!_rstsTouched) _applyDefaultRSTs();
    });
    if (widget.editingQso == null) widget.radioService?.setVfo('vfoA', mode: mode);
  }

  // ---- Secondary control row ----

  void _onSelectControl(String? key) {
    if (key == 'more') {
      _openMoreEditor();
      return;
    }
    setState(() {
      if (key == 'time' && _selectedControlKey != 'time') _seedTimeFields();
      _selectedControlKey = key;
    });
  }

  /// Shared look for the primary logging row (Their call/Sent/Rcvd) — same
  /// font size and field padding across all three, and the label always
  /// pinned to the top-left corner (not the "large placeholder until
  /// focused" default) so the row's shape doesn't shift as you type. Built
  /// on the app-wide poloFieldDecoration (theme.dart), tinted to read
  /// against this panel's tertiaryContainer background.
  TextStyle _primaryFieldStyle(BuildContext context, {required FontWeight fontWeight}) =>
      haloMonoStyle(context, fontSize: 15, fontWeight: fontWeight);

  InputDecoration _primaryFieldDecoration(BuildContext context, String label) => poloFieldDecoration(
        context,
        label,
        labelColor: Theme.of(context).colorScheme.onTertiaryContainer,
      );

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  String _fmtTimeWithSeconds(DateTime dt) =>
      '${_fmtTime(dt)}:${dt.second.toString().padLeft(2, '0')}';
  String _fmtDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// The best-known timestamp for the entry being composed/edited: a manual
  /// override if one's been set, else the existing QSO's recorded time when
  /// editing one, else null — meaning "still automatic, tracks live now."
  int? get _effectiveStartAtMillis => _manualStartAtMillis ?? widget.editingQso?.startAtMillis;

  /// (Re-)populates the time/date fields from [_effectiveStartAtMillis], or
  /// from the current time if that's null — called whenever the Time
  /// control is opened, so it never shows a stale snapshot from an earlier
  /// open.
  void _seedTimeFields() {
    final millis = _effectiveStartAtMillis;
    final dt = millis != null
        ? DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true)
        : DateTime.now().toUtc();
    // Display-only refresh: without the _populating guard, these programmatic
    // sets fire _onTimeOrDateFieldChanged, which would read the seeded value
    // back as a manual override — freezing auto-timestamping just for opening
    // the Time chip, and making "Now" re-freeze the clock it just released.
    final wasPopulating = _populating;
    _populating = true;
    _timeController.text = _fmtTime(dt);
    _dateController.text = _fmtDate(dt);
    _populating = wasPopulating;
  }

  void _onTimeOrDateFieldChanged() {
    if (_populating) return;
    final time = _timeController.text.split(':');
    final date = _dateController.text.split('-');
    if (time.length != 2 || date.length != 3) return;
    final hour = int.tryParse(time[0]);
    final minute = int.tryParse(time[1]);
    final year = int.tryParse(date[0]);
    final month = int.tryParse(date[1]);
    final day = int.tryParse(date[2]);
    if (hour == null || minute == null || year == null || month == null || day == null) {
      return;
    }
    setState(() {
      _manualStartAtMillis = DateTime.utc(year, month, day, hour, minute).millisecondsSinceEpoch;
      _updateClockTicker();
    });
  }

  void _resetTimeToNow() {
    setState(() {
      _manualStartAtMillis = null;
      _seedTimeFields();
      _updateClockTicker();
    });
  }

  /// Starts or stops the live-clock ticker to match whether the Time chip
  /// currently needs one — only while nothing overrides the timestamp and
  /// we're not editing an existing (necessarily historical) QSO.
  void _updateClockTicker() {
    final needsTicking = _effectiveStartAtMillis == null;
    if (needsTicking && _clockTicker == null) {
      _clockTicker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    } else if (!needsTicking && _clockTicker != null) {
      _clockTicker!.cancel();
      _clockTicker = null;
    }
  }

  String get _timeSummary {
    final millis = _effectiveStartAtMillis;
    final dt = millis == null ? DateTime.now().toUtc() : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    // Always shows seconds, even when they're not meaningful (a manually
    // entered/edited time has none — it comes from a plain HH:MM field —
    // so it's always :00 rather than the pill silently switching formats).
    return '${_fmtTimeWithSeconds(dt)}z';
  }

  String get _radioSummary {
    final parts = <String>[
      _freq != null ? fmtFreq(_freq!) : (_band ?? 'Band???'),
    ];
    parts.add(_mode);
    return parts.join(' • ');
  }

  // ---- Control identity, order and visibility ----
  //
  // Descriptors carry just enough for the settings dialog and ordering
  // (key/icon/label/mandatory) — the actual SecondaryControlSpec (live
  // summary + expanded-input builder) is only built for controls that end
  // up visible, in _buildSecondaryControls below.

  List<_ControlDescriptor> _controlDescriptors() => [
        _ControlDescriptor(
          key: 'time',
          icon: MdiIcons.clockOutline,
          label: widget.timeControlLabel ?? 'Time',
          mandatory: true,
        ),
        _ControlDescriptor(
          key: 'radio',
          icon: MdiIcons.radio,
          label: widget.radioControlLabel ?? 'Radio',
          mandatory: true,
        ),
        if (widget.suggestSpotSources != null && widget.sendSpot != null)
          _ControlDescriptor(
            key: 'spotting',
            icon: resolveIconName('hand-wave'),
            label: widget.spottingControlLabel ?? 'Spotting',
          ),
        for (final control in _effectiveActivityControls)
          if ((control['input'] as Map?)?['kind'] == 'refList')
            _ControlDescriptor(
              key: control['key'] as String,
              icon: resolveIconName(control['icon'] as String?),
              label: (control['label'] as String?) ?? control['key'] as String,
            ),
        _ControlDescriptor(
          key: 'more',
          icon: resolveIconName('pencil'),
          label: widget.moreLabel ?? 'More',
        ),
      ];

  /// `widget.controlOrder`, filtered to keys that still exist and
  /// de-duplicated, with any remaining known keys appended in their default
  /// order — so a fresh install (empty order) or a newly-added extension
  /// control both fall back to sane placement.
  List<String> _effectiveControlOrder(List<_ControlDescriptor> descriptors) {
    final allKeys = descriptors.map((d) => d.key).toSet();
    final order = <String>[];
    for (final key in widget.controlOrder) {
      if (allKeys.contains(key) && !order.contains(key)) order.add(key);
    }
    for (final descriptor in descriptors) {
      if (!order.contains(descriptor.key)) order.add(descriptor.key);
    }
    return order;
  }

  List<SecondaryControlSpec> _buildSecondaryControls(
    ThemeData theme,
    HaLoColors poloColors,
  ) {
    final descriptors = _controlDescriptors();
    final byKey = {for (final d in descriptors) d.key: d};
    final specs = <SecondaryControlSpec>[];
    for (final key in _effectiveControlOrder(descriptors)) {
      final descriptor = byKey[key];
      if (descriptor == null) continue;
      if (!descriptor.mandatory && widget.hiddenControlKeys.contains(key)) continue;
      switch (key) {
        case 'time':
          specs.add(_timeControlSpec());
        case 'radio':
          specs.add(_radioControlSpec(theme, poloColors));
        case 'spotting':
          specs.add(_spottingControlSpec(theme, poloColors));
        case 'more':
          specs.add(_moreControlSpec());
        default:
          for (final control in _effectiveActivityControls) {
            if (control['key'] == key) {
              specs.add(_activityControlSpec(control));
              break;
            }
          }
      }
    }
    return specs;
  }

  SecondaryControlSpec _timeControlSpec() => SecondaryControlSpec(
        key: 'time',
        icon: MdiIcons.clockOutline,
        summary: _timeSummary,
        expandedBuilder: (context) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              // Same width as the date field below — wide enough to fit a
              // full "2026-07-11", even though the time value itself
              // ("16:54") is shorter.
              width: 120,
              child: TextField(
                controller: _timeController,
                focusNode: _timeFocus,
                selectAllOnFocus: false,
                style: haloMonoStyle(
                  context,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: poloFieldDecoration(
                  context,
                  widget.timeLabel ?? 'Time (UTC)',
                  labelColor: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _dateController,
                style: haloMonoStyle(
                  context,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: poloFieldDecoration(
                  context,
                  widget.dateLabel ?? 'Date',
                  labelColor: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                ],
              ),
            ),
            // Only offer to reset back to automatic timestamping while
            // composing a new QSO with a manual override in effect — there's
            // no "automatic" time to reset to when editing an existing,
            // necessarily historical, entry.
            if (widget.editingQso == null && _manualStartAtMillis != null) ...[
              const SizedBox(width: 8),
              TextButton(onPressed: _resetTimeToNow, child: Text(widget.nowLabel ?? 'Now')),
            ],
          ],
        ),
      );

  SecondaryControlSpec _radioControlSpec(ThemeData theme, HaLoColors poloColors) => SecondaryControlSpec(
        key: 'radio',
        icon: MdiIcons.radio,
        summary: _radioSummary,
        expandedBuilder: (context) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownMenu<String>(
              initialSelection: _band,
              label: Text(widget.bandLabel ?? 'Band'),
              width: 104,
              textStyle: haloMonoStyle(
                context,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              inputDecorationTheme: InputDecorationTheme(
                isDense: true,
                filled: true,
                fillColor: theme.colorScheme.surface,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                floatingLabelStyle: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                contentPadding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
              ),
              dropdownMenuEntries: [
                for (final b in bands)
                  DropdownMenuEntry(
                    value: b.name,
                    label: b.name,
                    style: MenuItemButton.styleFrom(
                      foregroundColor: poloColors.bandColor(b.name),
                    ),
                  ),
              ],
              onSelected: (value) {
                if (value == null) return;
                setState(() {
                  // Matches the `setVfo{band: ...}` command action's
                  // convention (see `_dispatchActions`): picking a band
                  // directly is mutually exclusive with a manual frequency,
                  // since `_band` prefers the freq-derived value whenever
                  // `_freq` is set.
                  _manualBand = value;
                  _freqController.clear();
                });
                // A discrete dropdown pick, not a keystroke — push
                // immediately rather than debouncing like frequency typing.
                // Only while composing — editing an existing QSO applies
                // changes to the QSO, never the VFO.
                if (widget.editingQso == null) widget.radioService?.setVfo('vfoA', band: value);
                _callFocus.requestFocus();
              },
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _freqController,
                focusNode: _freqFocus,
                selectAllOnFocus: false,
                style: haloMonoStyle(
                  context,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: poloFieldDecoration(
                  context,
                  widget.freqLabel ?? 'Frequency',
                  labelColor: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                onSubmitted: (_) => _log(),
              ),
            ),
            const SizedBox(width: 6),
            DropdownMenu<String>(
              initialSelection: _mode,
              label: Text(widget.modeLabel ?? 'Mode'),
              width: 104,
              textStyle: haloMonoStyle(
                context,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              inputDecorationTheme: InputDecorationTheme(
                isDense: true,
                filled: true,
                fillColor: theme.colorScheme.surface,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                floatingLabelStyle: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                contentPadding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
              ),
              dropdownMenuEntries: [
                for (final m in modes) DropdownMenuEntry(value: m, label: m),
              ],
              onSelected: (value) {
                if (value == null) return;
                _setMode(value);
                _callFocus.requestFocus();
              },
            ),
          ],
        ),
      );

  /// UI-level policy, not a per-source value: how recently a QSO must have
  /// started for the button to offer spotting it at all. This is deliberately
  /// NOT part of `SpotEligibility` — no spots source today needs a different
  /// tolerance (POTA is the only `postOtherSpot` implementation; SOTA has no
  /// posting support yet, see DESIGN notes on ham2k/app-halo-dist#10), so
  /// making it hook-reported would be speculative. Revisit if a second
  /// source ever needs its own window.
  static const Duration _spotStaleAfter = Duration(minutes: 5);

  /// Resolves the Spotting control's summary/button text and enabled state
  /// per the issue's exact state machine (ham2k/app-halo-dist#10): no VFO
  /// frequency disables self-spotting; editing a QSO switches to spotting
  /// that QSO's station instead, only while it's recent enough (5min).
  /// `summary` (the collapsed pill) is always one of the two short, fixed
  /// labels — "Self-spotting"/"Spotting" — never the longer dynamic
  /// messages, which are reserved for the button inside the expanded panel.
  ({String summary, String buttonLabel, bool enabled, bool showComment}) get _spotState {
    final editingQso = widget.editingQso;
    if (editingQso != null) {
      final call = (editingQso.data['their'] as Map?)?['call'] as String? ?? '?';
      final ageMillis =
          editingQso.startAtMillis == null ? null : DateTime.now().millisecondsSinceEpoch - editingQso.startAtMillis!;
      final tooOld = ageMillis == null || ageMillis > _spotStaleAfter.inMilliseconds;
      final summary = widget.spottingLabel ?? 'Spotting';
      if (tooOld) {
        return (
          summary: summary,
          buttonLabel: widget.spotTooLateLabel?.call(call) ?? 'Too late to spot $call',
          enabled: false,
          showComment: false,
        );
      }
      final freqLabel = editingQso.freq == null ? '' : fmtFreq(editingQso.freq!);
      return (
        summary: summary,
        buttonLabel: widget.spotOtherLabel?.call(call, freqLabel) ?? 'Spot $call at $freqLabel',
        enabled: true,
        showComment: true,
      );
    }

    final summary = widget.spottingSelfLabel ?? 'Self-spotting';
    final vfoFreq = widget.radioService?.vfoA.freq;
    if (vfoFreq == null) {
      return (
        summary: summary,
        buttonLabel: widget.spotNoFreqLabel ?? 'First set a frequency to spot',
        enabled: false,
        showComment: false,
      );
    }
    final freqLabel = fmtFreq(vfoFreq);
    return (
      summary: summary,
      buttonLabel: widget.spotSelfLabel?.call(freqLabel) ?? 'Self-spot at $freqLabel',
      enabled: true,
      showComment: true,
    );
  }

  Future<void> _sendSpot() async {
    final sendSpot = widget.sendSpot;
    if (sendSpot == null || _spotSending) return;
    final editingQso = widget.editingQso;
    final vfo = widget.radioService?.vfoA;
    // Snapshot the sources being spotted now — `_spotSources` can be reset
    // and repopulated by `didUpdateWidget` (e.g. the user switches to
    // editing a different QSO) while this send is still in flight, and the
    // status-coloring below must key off what was actually sent, not
    // whatever `_spotSources` holds once the await resolves.
    final sentSources = _spotSources;
    setState(() => _spotSending = true);
    try {
      final comment = _spotCommentController.text.trim();
      final results = await sendSpot(
        sources: sentSources,
        operation: widget.operation.data,
        qso: editingQso?.data,
        freq: editingQso == null ? vfo?.freq : null,
        mode: editingQso == null ? vfo?.mode : null,
        comment: comment.isEmpty ? null : comment,
      );
      if (!mounted) return;
      setState(() {
        for (final source in sentSources) {
          final hookKey = source['hookKey'] as String? ?? '';
          final result = results[hookKey];
          _spotStatus[hookKey] = result == null ? null : result['ok'] == true;
        }
        _spotCommentController.clear();
      });
      _spotStatusClearTimer?.cancel();
      // Explicit 3-minute color-clear (no app-polo equivalent to diverge
      // from — its own SpotterControl only resets colors on the next
      // attempt).
      _spotStatusClearTimer = Timer(const Duration(minutes: 3), () {
        if (mounted) setState(_spotStatus.clear);
      });
    } finally {
      if (mounted) setState(() => _spotSending = false);
    }
  }

  SecondaryControlSpec _spottingControlSpec(ThemeData theme, HaLoColors poloColors) {
    final state = _spotState;
    return SecondaryControlSpec(
      key: 'spotting',
      icon: resolveIconName('hand-wave'),
      summary: state.summary,
      expandedBuilder: (context) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (state.showComment)
            SizedBox(
              width: 160,
              child: TextField(
                controller: _spotCommentController,
                // Explicitly mixed-case, like Name/Notes: a spot comment is
                // free prose for other operators, not logging data.
                style: haloMonoStyle(context, fontSize: 15, fontWeight: FontWeight.w500),
                decoration: poloFieldDecoration(
                  context,
                  widget.spotCommentHint ?? 'Comment',
                  labelColor: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          const SizedBox(width: 6),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.tertiaryContainer,
              foregroundColor: theme.colorScheme.onTertiaryContainer,
              disabledBackgroundColor: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.4),
            ),
            onPressed: state.enabled && !_spotSending ? _sendSpot : null,
            icon: _spotSending
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(resolveIconName('hand-wave-outline')),
            label: Text(state.buttonLabel),
          ),
          // Up to 3 source-status icons per column, wrapping into another
          // column to the right once a column fills up.
          for (var i = 0; i < _spotSources.length; i += 3)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final source in _spotSources.skip(i).take(3))
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
                    child: Icon(
                      resolveIconName(source['icon'] as String? ?? 'radio-tower'),
                      size: 16,
                      color: switch (_spotStatus[source['hookKey'] as String? ?? '']) {
                        true => poloColors.important,
                        false => theme.colorScheme.error,
                        null => theme.colorScheme.onTertiaryContainer,
                      },
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  SecondaryControlSpec _activityControlSpec(Map<String, dynamic> control) => SecondaryControlSpec(
        key: control['key'] as String,
        icon: resolveIconName(control['icon'] as String?),
        summary: (control['label'] as String?) ?? control['key'] as String,
        expandedBuilder: (context) => SizedBox(
          width: 160,
          child: RefTextInput(
            refType: (control['input'] as Map)['refType'] as String,
            label: (control['label'] as String?) ?? '',
            placeholder: (control['input'] as Map)['placeholder'] as String?,
            pattern: (control['input'] as Map)['pattern'] as String?,
            transforms: [
              for (final t in ((control['input'] as Map)['transforms'] as List?) ?? const [])
                RefTransform.fromMap((t as Map).cast<String, dynamic>()),
            ],
            refs: _controlRefs[control['key']] ?? const [],
            onChanged: (refs) =>
                setState(() => _controlRefs[control['key'] as String] = refs),
            decorate: widget.decorateRef,
            labelColor: Theme.of(context).colorScheme.onTertiaryContainer,
          ),
        ),
      );

  SecondaryControlSpec _moreControlSpec() => SecondaryControlSpec(
        key: 'more',
        icon: resolveIconName('pencil'),
        summary: widget.moreLabel ?? 'More',
        // Never actually shown — _onSelectControl special-cases 'more' to
        // open the full-edit pane instead of expanding inline.
        expandedBuilder: (context) => const SizedBox.shrink(),
      );

  // ---- Command shortcuts ----
  //
  // Space in the call field first tries the text as an extension command
  // (band/frequency/mode shortcuts live in the `radio-commands` extension;
  // see docs/extensions/hooks.md's `command` category). This is a real bridge
  // round-trip, not a Dart regex — command matching and frequency parsing
  // are extension/domain-library territory, not core UI territory.

  Future<void> _handleSpace() async {
    if (_callFocus.hasFocus) {
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
        // space by advancing focus instead of inserting it. Reuses
        // _currentInterpretation when the debounce already resolved for this
        // exact text, so this only adds a round trip when genuinely needed.
        if (widget.editingQso == null && widget.interpretCommand != null) {
          var result = _currentInterpretation;
          if (result == null) {
            _commandDescribeDebounce?.cancel();
            final qsoData = _getCurrentQsoData();
            result = await widget.interpretCommand!(_commandInput, _operationDataForCommands, qsoData);
            if (!mounted || _call != call) return; // stale — the call changed while awaiting
            setState(() {
              _currentInterpretation = result;
              _retainInterpretation(result);
              _commandMessage = (result != null && result['describe'] is String)
                  ? result['describe'] as String
                  : (result != null && result['error'] is String)
                      ? result['error'] as String
                      : null;
            });
            _notifyCommandMessage(_commandMessage);
          }
          // A complete mixedCase command (e.g. "NOTE Hello") also keeps
          // space literal — its free-prose parameter is still being typed.
          if (result != null && (result['expectsParams'] == true || result['mixedCase'] == true)) {
            _insertAtCursor(_callController, ' ');
            return;
          }
        }
      }

      _advancePrimaryFocus();
    } else if (_freqFocus.hasFocus) {
      _callFocus.requestFocus();
    } else if (_stateFocus.hasFocus || _gridFocus.hasFocus || _sentFocus.hasFocus || _rcvdFocus.hasFocus) {
      _advancePrimaryFocus();
    }
    // Space is inert in any other field with no override of its own. Ref
    // inputs (RefTextInput, RefChipsInput) are the one exception — they bind
    // Space locally to type a literal separator instead, taking priority
    // over this panel-wide shortcut.
  }

  /// Space cycles through whichever primary exchange fields are currently
  /// visible, in the same left-to-right order they're laid out in —
  /// Sent/Rcvd (when RST is on) right after Call, then State/Grid (when
  /// their "..." menu toggles are on) — wrapping back to Call after the
  /// last one. Rebuilt on every call since `showRSTFields`/`showStateField`/
  /// `showGridField` can change at runtime.
  void _advancePrimaryFocus() {
    final order = [
      _callFocus,
      if (widget.showRSTFields) _sentFocus,
      if (widget.showRSTFields) _rcvdFocus,
      if (widget.showStateField) _stateFocus,
      if (widget.showGridField) _gridFocus,
    ];
    final current = order.indexWhere((f) => f.hasFocus);
    final next = order[(current + 1) % order.length];
    next.requestFocus();
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

  Future<void> _dispatchActions(List<dynamic> actions) async {
    for (final action in actions) {
      if (action is! Map) continue;
      final map = action.cast<String, dynamic>();

      if (map.containsKey('setVfo')) {
        final params = map['setVfo'] as Map;
        // A command's setVfo is already validated by the extension — push
        // it to radioService immediately rather than debouncing like raw
        // frequency typing. _populating suppresses _onFreqChanged's own
        // (debounced) push, which would otherwise also fire from the
        // controller text assignment below.
        _populating = true;
        setState(() {
          final freq = params['freq'];
          final band = params['band'];
          final mode = params['mode'];
          if (freq is num) {
            _freqController.text = fmtFreqInput(freq.toDouble());
            _manualBand = null;
          } else if (band is String) {
            _manualBand = band;
            _freqController.clear();
          }
          if (mode is String) {
            _mode = mode;
            if (!_rstsTouched) _applyDefaultRSTs();
          }
        });
        _populating = false;
        if (params['freq'] is num || params['band'] is String || params['mode'] is String) {
          _pushVfoToRadioService();
        }
      } else if (map.containsKey('updateQso')) {
        final params = (map['updateQso'] as Map).cast<String, dynamic>();
        setState(() {
          _currentQsoExtra.addAll(params);
        });
      } else if (map.containsKey('addQso')) {
        final params = (map['addQso'] as Map).cast<String, dynamic>();
        final qso = await widget.qsosRepository.add(widget.operation.uuid, params);
        widget.onLogged?.call(qso);
      } else if (map.containsKey('updateSettings')) {
        final params = (map['updateSettings'] as Map).cast<String, dynamic>();
        if (widget.settings != null) {
          if (params.containsKey('developerMode')) {
            await widget.settings!.setDeveloperMode(params['developerMode'] as bool);
          }
        }
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
        await widget.onCommandAction?.call('syncAll');
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
          qso = widget.qsos.cast<Qso?>().lastWhere((q) => q!.isRealContact, orElse: () => null);
        }
        final vfo = widget.radioService?.vfoA;
        await widget.onCommandAction?.call('sendSpots', {
          'operation': widget.operation.data,
          'target': target,
          if (qso != null) 'qso': qso.data,
          if (comment != null) 'comment': comment,
          if (qso == null) 'freq': vfo?.freq,
          if (qso == null) 'mode': vfo?.mode,
        });
      } else if (map['devNotice'] is Map) {
        await widget.onCommandAction?.call('devNotice', (map['devNotice'] as Map).cast<String, dynamic>());
      } else if (map['devStatus'] is Map) {
        await widget.onCommandAction?.call('devStatus', (map['devStatus'] as Map).cast<String, dynamic>());
      } else if (map['devProgress'] is Map) {
        await widget.onCommandAction?.call('devProgress', (map['devProgress'] as Map).cast<String, dynamic>());
      } else if (map['reloadDataFiles'] is Map) {
        await widget.onCommandAction?.call('reloadDataFiles', (map['reloadDataFiles'] as Map).cast<String, dynamic>());
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
  }

  /// [callOverride] lets call stacking (_pickStackedCall) supply the one
  /// segment it picked out of the "//"-separated field, instead of the raw
  /// (still-stacked) field text.
  Map<String, dynamic> _getCurrentQsoData({String? callOverride}) {
    final base = widget.editingQso?.data ?? const <String, dynamic>{};
    final call = callOverride ?? _call;
    final refs = [
      for (final list in _controlRefs.values) ...list,
      ..._unmatchedRefs,
    ];
    return {
      ...base,
      // Unconditional (not `if (refs.isNotEmpty)`/`if (_freq != null)`):
      // `base` may already carry a non-empty value for these from the
      // record being edited, and a merge-style `...base` above won't drop
      // a stale one just because the live value is now empty/null — these
      // have to actively overwrite every time, including with null/empty,
      // for clearing a ref/freq/band during an edit to actually stick.
      'refs': refs,
      'our': {
        ...?(base['our'] as Map<String, dynamic>?),
        'call': widget.operation.stationCall,
        'sent': _sentController.text.trim(),
      },
      'their': {
        ...?(base['their'] as Map<String, dynamic>?),
        if (_theirNameOverride != null) 'name': _theirNameOverride,
        // Conditional on `_gridTouched`/`_stateTouched`, not just "is the
        // controller non-empty": the controller may just be *displaying* a
        // value populated from `editingQso.theirGrid`/`theirState` on load,
        // which must NOT clobber `their.guess`'s fallback for a call this
        // record hasn't actually been edited for (see `dataFor` below).
        // Once touched, though, write it unconditionally — including empty
        // — so deliberately clearing the field actually clears the stored
        // value instead of leaving the old one from `...?(base['their'])`.
        // Grid input is uppercase-only like every logging control, but the
        // stored value gets the conventional Maidenhead casing back
        // (FN31pr) via normalizeGrid; states are plain uppercase.
        if (_gridTouched) 'grid': normalizeGrid(_gridController.text.trim()),
        if (_stateTouched) 'state': _stateController.text.trim().toUpperCase(),
        'call': call,
        'sent': _rcvdController.text.trim(),
        // Matches the `AnnotatedCallInfo` TS type (`CallInfo & {guess?:
        // CallInfo, lookups?: CallInfoLookup[]}`, @ham2k/lib-qson-tools) and
        // app-polo's convention: the merged lookup guess stays NESTED under
        // `guess`/`lookups`, never flattened onto `their`'s own fields —
        // readers fall back to `their.guess.x` when `their.x` isn't set.
        if (_lookupFor == call && _lookupResult != null) 'guess': _lookupResult!['guess'],
        if (_lookupFor == call && _lookupResult != null) 'lookups': _lookupResult!['lookups'],
      },
      'freq': _freq,
      'band': _band,
      'mode': _mode,
      if (_effectiveStartAtMillis != null) 'startAtMillis': _effectiveStartAtMillis,
      ..._currentQsoExtra,
    };
  }

  // ---- "More" full-edit pane ----
  //
  // A secondary control that bypasses the usual inline-expand behavior
  // (special-cased in _onSelectControl) to open a Modal Pane covering
  // fields the primary/secondary controls don't otherwise expose: their
  // name, grid, and notes. Reuses the existing FormRenderer engine via
  // showFormPane (see form_renderer.dart) rather than a new navigation
  // route. Fields are `uppercase: true` per the logging-wide rule —
  // uppercase unless explicitly mixed-case: Name and Notes are free prose,
  // and Band's canonical names are lowercase ("20m", matching the `bands`
  // table, which is compared by exact equality).

  Map<String, dynamic> _buildQsoEditFormDefinition() {
    return {
      'title': widget.qsoEditFormTitle ?? 'Edit QSO',
      'elements': [
        {'type': 'field', 'key': 'theirCall', 'fieldType': 'callsign', 'label': widget.theirCallLabel ?? 'Their call'},
        {'type': 'field', 'key': 'theirName', 'fieldType': 'text', 'label': widget.theirNameLabel ?? 'Name'},
        {'type': 'field', 'key': 'theirGrid', 'fieldType': 'text', 'label': widget.theirGridLabel ?? 'Grid', 'uppercase': true},
        {'type': 'field', 'key': 'theirState', 'fieldType': 'text', 'label': widget.theirStateLabel ?? 'State', 'uppercase': true},
        {'type': 'field', 'key': 'sent', 'fieldType': 'text', 'label': widget.sentLabel ?? 'Sent', 'uppercase': true},
        {'type': 'field', 'key': 'rcvd', 'fieldType': 'text', 'label': widget.rcvdLabel ?? 'Rcvd', 'uppercase': true},
        {'type': 'field', 'key': 'freq', 'fieldType': 'number', 'label': widget.freqLabel ?? 'Frequency'},
        {'type': 'field', 'key': 'band', 'fieldType': 'text', 'label': widget.bandLabel ?? 'Band'},
        {
          'type': 'field',
          'key': 'mode',
          'fieldType': 'select',
          'label': widget.modeLabel ?? 'Mode',
          'options': [for (final m in modes) {'value': m, 'label': m}],
        },
        {'type': 'field', 'key': 'date', 'fieldType': 'text', 'label': widget.dateLabel ?? 'Date'},
        {'type': 'field', 'key': 'time', 'fieldType': 'text', 'label': widget.timeLabel ?? 'Time (UTC)'},
        {'type': 'field', 'key': 'notes', 'fieldType': 'multiline', 'label': widget.notesLabel ?? 'Notes'},
      ],
    };
  }

  Future<void> _openMoreEditor() async {
    final millis = _effectiveStartAtMillis;
    final dt = millis != null
        ? DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true)
        : DateTime.now().toUtc();
    // Captured so the Save handler below can tell "the user actually edited
    // Grid/State in this pane" from "the pane merely displayed whatever
    // was already there" — the latter must not turn a passive lookup guess
    // into a deliberately-touched, sticky value (see _gridTouched's doc).
    final gridBeforePane = _gridController.text.trim();
    final stateBeforePane = _stateController.text.trim();
    // Same displayed-vs-edited distinction for date/time: while composing,
    // the pane shows the live clock, and saving an untouched value must
    // not turn it into a manual override that freezes auto-timestamping.
    final dateBeforePane = _fmtDate(dt);
    final timeBeforePane = _fmtTime(dt);

    final result = await showFormPane(
      context,
      formDefinition: _buildQsoEditFormDefinition(),
      initialState: {
        'theirCall': _call,
        'theirName': _theirNameOverride ?? widget.editingQso?.theirName ?? '',
        'theirGrid': gridBeforePane,
        'theirState': stateBeforePane,
        'sent': _sentController.text.trim(),
        'rcvd': _rcvdController.text.trim(),
        'freq': _freq,
        'band': _band ?? '',
        'mode': _mode,
        'date': _fmtDate(dt),
        'time': _fmtTime(dt),
        'notes': (_currentQsoExtra['notes'] as String?) ?? '',
      },
      onChange: (key, value, state) async {
        // Freq wins over a manually-typed band, matching _onFreqChanged's
        // existing precedence for the inline Radio control.
        if (key == 'freq' && value is num) {
          final band = bandForFrequency(value.toDouble());
          if (band != null) return {'band': band};
        }
        return null;
      },
    );
    if (result == null || !mounted) return;

    // Same as the setVfo command dispatch: a deliberate pane Save, not
    // raw typing — push immediately rather than via _onFreqChanged's
    // debounce, and only while composing (rule: editing an existing QSO
    // applies changes to the QSO, never the VFO).
    _populating = true;
    setState(() {
      _callController.text = ((result['theirCall'] as String?) ?? '').toUpperCase();
      final name = (result['theirName'] as String?)?.trim();
      _theirNameOverride = (name == null || name.isEmpty) ? null : name;
      final grid = normalizeGrid(((result['theirGrid'] as String?) ?? '').trim());
      final state = ((result['theirState'] as String?) ?? '').trim().toUpperCase();
      // Normalized comparison, not raw string inequality: the pane's
      // uppercase formatter rewrites the WHOLE field on any keystroke, so
      // a net no-op edit over a lookup-guessed 'FN31pr' would come back
      // 'FN31PR' and a raw compare would falsely promote the passive guess
      // to a sticky touched override (see _gridTouched's doc). Case is not
      // a deliberate edit; only a real value change is.
      _gridTouched = _gridTouched || grid != normalizeGrid(gridBeforePane);
      _stateTouched = _stateTouched || state != stateBeforePane.toUpperCase();
      _gridController.text = grid;
      _stateController.text = state;
      _sentController.text = (result['sent'] as String?) ?? '';
      _rcvdController.text = (result['rcvd'] as String?) ?? '';
      _rstsTouched = true;

      final freq = result['freq'];
      if (freq is num) {
        _freqController.text = fmtFreqInput(freq.toDouble());
        _manualBand = null;
      } else {
        _freqController.clear();
        final band = (result['band'] as String?)?.trim();
        _manualBand = (band == null || band.isEmpty) ? null : band;
      }

      _mode = (result['mode'] as String?) ?? _mode;

      final dateParts = ((result['date'] as String?) ?? '').split('-');
      final timeParts = ((result['time'] as String?) ?? '').split(':');
      final dateOrTimeEdited = result['date'] != dateBeforePane || result['time'] != timeBeforePane;
      if (dateOrTimeEdited && dateParts.length == 3 && timeParts.length == 2) {
        final year = int.tryParse(dateParts[0]);
        final month = int.tryParse(dateParts[1]);
        final day = int.tryParse(dateParts[2]);
        final hour = int.tryParse(timeParts[0]);
        final minute = int.tryParse(timeParts[1]);
        if (year != null && month != null && day != null && hour != null && minute != null) {
          _manualStartAtMillis = DateTime.utc(year, month, day, hour, minute).millisecondsSinceEpoch;
        }
      }

      final notes = ((result['notes'] as String?) ?? '').trim();
      if (notes.isEmpty) {
        _currentQsoExtra.remove('notes');
      } else {
        _currentQsoExtra['notes'] = notes;
      }

      _seedTimeFields();
      _updateClockTicker();
    });
    _populating = false;
    if (widget.editingQso == null) _pushVfoToRadioService();
  }

  // ---- Secondary control settings (show/hide + reorder) ----

  Future<void> _openControlSettingsDialog() async {
    final descriptors = _controlDescriptors();
    final byKey = {for (final d in descriptors) d.key: d};
    var order = _effectiveControlOrder(descriptors);
    var hidden = Set<String>.from(widget.hiddenControlKeys);

    final result = await showDialog<(List<String>, Set<String>)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(widget.controlSettingsTitle ?? 'Logging Controls'),
          content: SizedBox(
            width: 360,
            child: ReorderableListView(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              onReorderItem: (oldIndex, newIndex) => setDialogState(() {
                final reordered = List<String>.from(order);
                final key = reordered.removeAt(oldIndex);
                reordered.insert(newIndex, key);
                order = reordered;
              }),
              children: [
                for (final (index, key) in order.indexed)
                  if (byKey[key] case final descriptor?)
                    ListTile(
                      key: ValueKey(key),
                      leading: ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle),
                      ),
                      title: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(descriptor.icon, size: 18),
                          const SizedBox(width: 12),
                          Text(descriptor.label),
                        ],
                      ),
                      trailing: Checkbox(
                        value: descriptor.mandatory || !hidden.contains(key),
                        onChanged: descriptor.mandatory
                            ? null
                            : (checked) => setDialogState(() {
                                  final updated = Set<String>.from(hidden);
                                  if (checked == true) {
                                    updated.remove(key);
                                  } else {
                                    updated.add(key);
                                  }
                                  hidden = updated;
                                }),
                      ),
                    ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(widget.cancelLabel ?? 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop((order, hidden)),
              child: Text(widget.saveLabel ?? 'Save'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    widget.onControlsSettingsChanged?.call(result.$1, result.$2);
  }

  // ---- Lookup enrichment ----

  /// Pushes a command message to the parent, but only when it actually
  /// changed — see `_lastSentCommandMessage`.
  void _notifyCommandMessage(String? message) {
    if (_lastSentCommandMessage == message) return;
    _lastSentCommandMessage = message;
    widget.onCommandMessageChanged?.call(message);
  }

  void _onCallChanged() {
    if (_populating) return;
    setState(() {});
    _lookupDebounce?.cancel();
    _commandDescribeDebounce?.cancel();
    
    // Clear any active execution confirmation message when the user types
    _executeMessageTimer?.cancel();
    _currentInterpretation = null;
    _commandMessage = null;
    _notifyCommandMessage(null);

    final call = _call;
    if (call.isEmpty) {
      if (_lookupFor != null || _retainedInterpretation != null) {
        setState(() {
          _lookupFor = null;
          _lookupResult = null;
          _refreshedActivityControls = null;
          _retainedInterpretation = null;
        });
      }
      return;
    }

    // Command shortcuts only apply while composing a new QSO — see _log().
    if (widget.editingQso == null && widget.interpretCommand != null) {
      final rawInput = _commandInput;
      _commandDescribeDebounce = Timer(const Duration(milliseconds: 150), () async {
        final qsoData = _getCurrentQsoData();
        final result = await widget.interpretCommand!(
          rawInput,
          _operationDataForCommands,
          qsoData,
        );
        if (!mounted || _call != call) return;
        setState(() {
          _currentInterpretation = result;
          _retainInterpretation(result);
          if (result != null && result['describe'] is String) {
            _commandMessage = result['describe'] as String;
          } else if (result != null && result['error'] is String) {
            _commandMessage = result['error'] as String;
          } else {
            _commandMessage = null;
          }
        });
        _notifyCommandMessage(_commandMessage);
      });
    }

    if (widget.lookup == null) return;
    // Preview lookup keys off whichever call is actually about to be logged
    // (issue #7's call stacking) or the segment the cursor is on within a
    // comma-separated list — the whole joined field text is never itself a
    // callsign once there's more than one call or stacked segment.
    final activeCall = _callAtCursor;
    if (_lookupFor == activeCall) return;
    if (!looksLikeCallsign(activeCall)) {
      setState(() {
        _lookupFor = null;
        _lookupResult = null;
        _refreshedActivityControls = null;
      });
      return;
    }

    _lookupDebounce = Timer(const Duration(milliseconds: 300), () async {
      // Offline pass first: fast, local-data-only, so the user sees
      // whatever's cheaply available (e.g. the callsign-annotation
      // pre-step) almost instantly. Then an online pass fills in
      // network-sourced data (QRZ/HamDB/etc) as soon as it resolves — no
      // extra artificial delay beyond its own network latency.
      final offlineResult = await widget.lookup!(
        activeCall,
        qso: _getCurrentQsoData(callOverride: activeCall),
        operation: widget.operation.data,
        online: false,
      );
      if (!mounted || _callAtCursor != activeCall) return; // stale — the active call changed
      setState(() {
        _lookupFor = activeCall;
        _lookupResult = offlineResult;
      });
      // QSO-scoped activity controls (e.g. POTA's DXCC-derived placeholder)
      // are refreshed off the offline pass ONLY, deliberately not fired
      // again after the online pass below. Two reasons: (1) the offline
      // pass's callsign-annotation pre-step already resolves the DXCC
      // entity a placeholder/prefix depends on — the online pass adds
      // QRZ/HamDB detail that doesn't change that entity, so a second
      // refresh would almost always re-fetch the same descriptors; (2) two
      // independent unawaited refreshes for the same call, with no ordering
      // guarantee between them, could race — a slower offline-triggered
      // refresh resolving after a faster online-triggered one would
      // overwrite the fresher result with a stale one. A single refresh
      // point sidesteps that entirely.
      unawaited(_refreshActivityControlsFor(activeCall));

      final onlineResult = await widget.lookup!(
        activeCall,
        qso: _getCurrentQsoData(callOverride: activeCall),
        operation: widget.operation.data,
        online: true,
      );
      if (!mounted || _callAtCursor != activeCall) return; // stale — the active call changed
      // A failed/timed-out online pass (host down, network error) must not
      // erase an already-shown, still-valid offline preview — keep it.
      if (onlineResult == null) return;
      setState(() {
        _lookupFor = activeCall;
        _lookupResult = onlineResult;
      });
    });
  }

  /// Re-fetches `activityControls` for [activeCall]'s QSO via
  /// `widget.refreshActivityControls`, discarding the result if the active
  /// call moved on (or the widget was disposed) while awaiting — the same
  /// staleness guard the lookup itself uses.
  Future<void> _refreshActivityControlsFor(String activeCall) async {
    final refresh = widget.refreshActivityControls;
    if (refresh == null) return;
    final controls = await refresh(_getCurrentQsoData(callOverride: activeCall));
    if (!mounted || _callAtCursor != activeCall) return;
    setState(() => _refreshedActivityControls = controls);
  }

  String? get _lookupLine {
    final result = _lookupResult;
    if (result == null || _lookupFor != _callAtCursor) return null;
    final guess = result['guess'] as Map<String, dynamic>? ?? const {};
    // A callsign note (issue #17) takes the name's slot outright rather
    // than joining it — the note usually already names the operator, and
    // one line can't fit both (same precedence app-polo gives it).
    final note = guess['note'] as String?;
    final parts = [
      (note != null && note.isNotEmpty) ? note : guess['name'],
      guess['location'],
      guess['country'],
      guess['grid'],
    ].whereType<String>().where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(' • ');
  }

  // ---- Logging ----

  /// Escape wipes the compose form, but must not blank the read-only view
  /// of a staged-delete or deleted QSO — the fields are the record's only
  /// display and can't be repopulated without reselecting it.
  void _handleEscape() {
    if (_fieldsLocked) return;
    _wipe();
  }

  void _wipe() {
    _callController.clear();
    _applyDefaultRSTs();
    _gridController.clear();
    _stateController.clear();
    _theirNameOverride = null;
    _unmatchedRefs = [];
    _gridTouched = false;
    _stateTouched = false;
    _lookupDebounce?.cancel();
    _commandDescribeDebounce?.cancel();
    _executeMessageTimer?.cancel();
    _lookupFor = null;
    _lookupResult = null;
    _refreshedActivityControls = null;
    _controlRefs.clear();
    _currentQsoExtra.clear();
    _manualStartAtMillis = null;
    _selectedControlKey = null;
    _callFocus.requestFocus();
    setState(() {
      _commandMessage = null;
      _currentInterpretation = null;
      _retainedInterpretation = null;
      _updateClockTicker();
    });
    _notifyCommandMessage(null);
  }

  // ---- Wipe/undo, delete/undo, revert-changes: the info row's second button ----

  /// Whether the in-progress new QSO has anything actually worth wiping —
  /// the wipe button stays visible but disabled when this is false. With a
  /// `radioService`, freq/band merely mirror the operation's VFO (seeded on
  /// entry, not something the operator composed for this specific QSO) and
  /// don't count; without one, they fall back to the pre-VFO behavior.
  bool get _hasComposedValues =>
      _call.isNotEmpty ||
      (widget.radioService == null && (_freqController.text.trim().isNotEmpty || _manualBand != null)) ||
      _manualStartAtMillis != null ||
      _theirNameOverride != null ||
      _controlRefs.values.any((refs) => refs.isNotEmpty) ||
      _unmatchedRefs.isNotEmpty ||
      _currentQsoExtra.isNotEmpty ||
      _gridController.text.trim().isNotEmpty ||
      _stateController.text.trim().isNotEmpty;

  /// Stashes the in-progress new QSO into the undo slot (for 5 seconds,
  /// even if the user keeps typing — see `_buildWipeOrEditButton`), then
  /// wipes the form.
  void _handleWipeTap() {
    _undoQsoData = _getCurrentQsoData();
    _undoExpireTimer?.cancel();
    _undoExpireTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _undoQsoData = null);
    });
    _wipe();
  }

  void _restoreFromUndoSlot() {
    final data = _undoQsoData;
    if (data == null) return;
    _undoExpireTimer?.cancel();
    _undoExpireTimer = null;
    _populating = true;
    _applyFieldsFromData(data);
    _manualStartAtMillis = data['startAtMillis'] as int?;
    _undoQsoData = null;
    setState(() => _updateClockTicker());
    _populating = false;
  }

  /// Restores (undeletes) the deleted QSO being viewed, then ends the
  /// editing session — the caller clears its selection and the list row
  /// loses its strikethrough via the repository watch.
  Future<void> _handleRestoreTap(Qso editingQso) async {
    if (_isLogging) return;
    _isLogging = true;
    try {
      await widget.qsosRepository.undelete(editingQso);
      if (!mounted) return;
      widget.onEditCanceled?.call();
    } finally {
      _isLogging = false;
    }
  }

  /// Deep, order-insensitive-for-lists equality — used to detect whether
  /// the fields being edited still match the stored record. Lists compare
  /// as multisets (via sorted JSON) rather than element-by-element, since
  /// `refs` is the only list-valued field here and its order is an
  /// artifact of how `_controlRefs` iterates, not a meaningful edit. A key
  /// missing entirely, an empty Map/List/String, and an explicit null all
  /// count as equivalent — `_getCurrentQsoData()` always emits fields like
  /// `their.sent`/`mode`/`freq`/`band`/`refs`, even when blank/null/empty,
  /// but a record with nothing recorded there yet might simply lack the
  /// key, which isn't a meaningful edit either.
  bool _deepEquals(dynamic a, dynamic b) {
    if (_isEmptyish(a) && _isEmptyish(b)) return true;
    if (a is Map || b is Map) {
      final ma = a is Map ? a : const {};
      final mb = b is Map ? b : const {};
      for (final key in {...ma.keys, ...mb.keys}) {
        if (!_deepEquals(ma[key], mb[key])) return false;
      }
      return true;
    }
    if (a is List || b is List) {
      final la = a is List ? a : const [];
      final lb = b is List ? b : const [];
      if (la.length != lb.length) return false;
      final sa = la.map(jsonEncode).toList()..sort();
      final sb = lb.map(jsonEncode).toList()..sort();
      for (var i = 0; i < sa.length; i++) {
        if (sa[i] != sb[i]) return false;
      }
      return true;
    }
    return a == b;
  }

  bool _isEmptyish(dynamic v) =>
      v == null ||
      (v is String && v.isEmpty) ||
      (v is Map && v.isEmpty) ||
      (v is List && v.isEmpty);

  /// Whether the fields being edited differ from the stored record — drives
  /// the "revert changes" vs. "delete" state of the info row's second
  /// button while editing.
  bool _qsoDataChanged() {
    final editingQso = widget.editingQso;
    if (editingQso == null) return false;
    return !_deepEquals(_getCurrentQsoData(), editingQso.data);
  }

  /// The info row's second (no-background) button — a single control whose
  /// icon/action depends on whether we're composing a new QSO or editing
  /// an existing one, per the state machine in the class doc comment above.
  Widget _buildWipeOrEditButton(ThemeData accentTheme) {
    final editingQso = widget.editingQso;
    final IconData icon;
    final String? tooltip;
    final VoidCallback? onPressed;

    if (editingQso == null) {
      if (_undoQsoData != null) {
        icon = resolveIconName('undo');
        tooltip = widget.undoLabel ?? 'Undo';
        onPressed = _restoreFromUndoSlot;
      } else {
        icon = resolveIconName('backspace-outline');
        tooltip = widget.wipeLabel ?? 'Wipe';
        onPressed = _hasComposedValues ? _handleWipeTap : null;
      }
    } else if (editingQso.deleted) {
      // An already-deleted QSO (selected via the "show deleted QSOs"
      // toggle) — one tap restores it immediately (ham2k/app-halo-dist#59);
      // no staged-until-save step, since restoring isn't destructive.
      icon = resolveIconName('delete-restore');
      tooltip = widget.restoreLabel ?? 'Restore';
      onPressed = () => _handleRestoreTap(editingQso);
    } else if (_pendingDelete) {
      icon = resolveIconName('undo');
      tooltip = widget.undoDeleteLabel ?? 'Undo delete';
      onPressed = () => setState(() => _pendingDelete = false);
    } else if (_qsoDataChanged()) {
      icon = resolveIconName('undo');
      tooltip = widget.revertLabel ?? 'Revert';
      onPressed = () => _populateFromEditingQso(editingQso);
    } else {
      icon = resolveIconName('trash-can-outline');
      tooltip = widget.deleteLabel ?? 'Delete';
      onPressed = () => setState(() => _pendingDelete = true);
    }

    // Same footprint as the submit button (measured post-frame, since that
    // button's own size is layout-derived — see _editButtonDiameter), no
    // background of its own, and its icon tinted with the color the submit
    // button uses as its *background*, tying the two together visually.
    final diameter = _editButtonDiameter ?? 44;
    return SizedBox(
      width: diameter,
      height: diameter,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
        color: accentTheme.colorScheme.tertiary,
        padding: EdgeInsets.zero,
        iconSize: diameter * 0.5 * 1.2,
      ),
    );
  }

  Future<void> _log() async {
    if (_isLogging) return; // already logging this entry; ignore the repeat

    // Check command — shortcuts (band/freq/mode, etc.) only apply while
    // composing a new QSO. A real callsign is exceedingly unlikely to
    // parse as one, but editing an existing entry shouldn't run it through
    // command interpretation at all, least of all while confirming a
    // staged delete.
    final call = _call;
    if (widget.editingQso == null && call.isNotEmpty && widget.interpretCommand != null) {
      _commandDescribeDebounce?.cancel();
      final qsoData = _getCurrentQsoData();
      var interpretation = _currentInterpretation;
      if (interpretation == null) {
        interpretation = await widget.interpretCommand!(
          _commandInput,
          _operationDataForCommands,
          qsoData,
        );
        if (!mounted || _call != call) return; // stale — the call changed while awaiting
      }
      // A recognized command that can't run in this context (its `error`
      // field is set — see CommandInterpretation) — surface the message,
      // keep the typed input for editing, and execute nothing.
      if (interpretation != null && interpretation['error'] is String) {
        setState(() {
          _commandMessage = interpretation!['error'] as String;
        });
        _notifyCommandMessage(_commandMessage);
        return;
      }
      // A command still awaiting parameters (expectsParams) isn't complete
      // — Enter shouldn't execute or clear the field, just fall through to
      // ordinary logging (which _canLog below will normally reject, since
      // it isn't a callsign either).
      if (interpretation != null && interpretation['expectsParams'] != true) {
        _isLogging = true;
        try {
          // The interpretation above may just be the debounce-time preview,
          // whose `commands` a hook like SEED deliberately left cheap/empty
          // (see CommandHook.interpret's `execute` doc) — re-interpret with
          // execute:true now that we're actually about to run it, so those
          // hooks generate the real commands instead of a stale preview's.
          final executable = await widget.interpretCommand!(
            _commandInput,
            _operationDataForCommands,
            qsoData,
            true,
          );
          if (!mounted || _call != call) return; // stale — the call changed while awaiting
          if (executable == null) return;

          _callController.clear();
          _currentInterpretation = null;
          _executeMessageTimer?.cancel();

          final confirmMarkdown = executable['confirm'];
          setState(() {
            _currentInterpretation = null;
            if (confirmMarkdown is String) {
              _commandMessage = confirmMarkdown;
              _executeMessageTimer = Timer(const Duration(seconds: 5), () {
                if (mounted) {
                  setState(() {
                    _commandMessage = null;
                  });
                  _notifyCommandMessage(null);
                }
              });
            } else {
              _commandMessage = null;
            }
          });
          _notifyCommandMessage(_commandMessage);

          final commands = executable['commands'];
          if (commands is List) {
            await _dispatchActions(commands);
          }
        } finally {
          _isLogging = false;
        }
        return;
      }
    }

    final editingQso = widget.editingQso;

    // Viewing a deleted QSO: the save button is disabled, but Enter is
    // also bound to _log — nothing to save until it's restored.
    if (editingQso != null && editingQso.deleted) return;

    if (editingQso != null && _pendingDelete) {
      _isLogging = true;
      try {
        await widget.qsosRepository.softDelete(editingQso);
        widget.onEditCanceled?.call();
      } finally {
        _isLogging = false;
      }
      return;
    }

    // Call stacking (issue #7): "//" picks one callsign out of the stack and
    // logs just that one. No information carries over between stacked
    // calls — this wipes exactly like an ordinary log (refs, notes,
    // overrides, RSTs, manual time all reset), then restores the rest of
    // the stack into the now-empty call field, same as if the operator had
    // just typed it. Only while composing a new QSO — same restriction as
    // command shortcuts above.
    if (editingQso == null) {
      final stacked = _pickStackedCall();
      if (stacked != null) {
        _isLogging = true;
        try {
          if (_vfoDebounce != null) {
            _vfoDebounce!.cancel();
            _vfoDebounce = null;
            _pushVfoToRadioService();
          }
          final qso = await widget.qsosRepository.add(
            widget.operation.uuid,
            _getCurrentQsoData(callOverride: stacked.call),
          );
          widget.onLogged?.call(qso);

          _wipe();
          _callController.text = stacked.remainder;
        } finally {
          _isLogging = false;
        }
        return;
      }
    }

    if (!_canLog) {
      _callFocus.requestFocus();
      return;
    }
    _isLogging = true;
    try {
      // A comma-separated call list logs one QSO per call, all sharing the
      // same other attributes, with each successive one's time 5 seconds
      // after the last (issue #7) — a single call is just a one-item list,
      // so `baseData`'s own startAtMillis/editingQso.startAtMillis is
      // preserved exactly for that common case.
      final calls = _callList;
      final isList = calls.length > 1;
      final baseData = _getCurrentQsoData();
      final baseStartAtMillis =
          (baseData['startAtMillis'] as int?) ?? DateTime.now().toUtc().millisecondsSinceEpoch;

      // The record being edited (index 0, when editing) survives untouched
      // even once more calls are added to its list — same as an ordinary
      // single-call edit, no fresh lookup, nothing suppressed. Every other,
      // newly-added entry in a multi-call list gets its own fresh,
      // independent lookup instead of inheriting whatever single
      // guessed/looked-up name/grid was cached for a different call. A
      // manually entered grid override is more often a station-wide
      // correction, so it's fine for that to still apply to every new
      // entry — but a manually entered name is specific to whoever the
      // override was actually typed for, so it isn't duplicated onto a
      // different, newly-added call.
      Future<Map<String, dynamic>> dataFor(String call, int index) async {
        final keepOriginal = !isList || (editingQso != null && index == 0);
        // Online only — this is about to be written to the record, not a
        // UI preview, so there's no value in a separate fast offline pass.
        final freshLookup = !keepOriginal && widget.lookup != null
            ? await widget.lookup!(
                call,
                qso: {...baseData, 'their': {'call': call}},
                operation: widget.operation.data,
                online: true,
              )
            : null;
        return {
          ...baseData,
          'their': {
            if (keepOriginal) ...?(baseData['their'] as Map<String, dynamic>?),
            // Nested, per the `AnnotatedCallInfo` TS convention — see the
            // matching comment in `_getCurrentQsoData`.
            if (freshLookup != null) 'guess': freshLookup['guess'],
            if (freshLookup != null) 'lookups': freshLookup['lookups'],
            'call': call,
            'sent': _rcvdController.text.trim(),
            if (keepOriginal && _theirNameOverride != null) 'name': _theirNameOverride,
            // Same normalization as _getCurrentQsoData: canonical Maidenhead
            // casing for grids, uppercase for states.
            if (_gridTouched) 'grid': normalizeGrid(_gridController.text.trim()),
            if (_stateTouched) 'state': _stateController.text.trim().toUpperCase(),
          },
          'startAtMillis': baseStartAtMillis + index * 5000,
        };
      }

      if (editingQso != null) {
        await widget.qsosRepository.update(
          Qso(
            uuid: editingQso.uuid,
            operationUuid: widget.operation.uuid,
            data: await dataFor(calls.first, 0),
          ),
        );
        for (var i = 1; i < calls.length; i++) {
          // The base data carries the edited QSO's own uuid (baseData came
          // from its record) — strip it so add() generates a fresh one for
          // this new QSO instead of colliding with the original.
          final data = await dataFor(calls[i], i)
            ..remove('uuid');
          final qso = await widget.qsosRepository.add(widget.operation.uuid, data);
          widget.onLogged?.call(qso);
        }
        widget.onEditCanceled?.call();
      } else {
        // Flush any pending debounced frequency push first, so a value
        // typed just before hitting Enter/Log is reflected in both the VFO
        // and this QSO, rather than only landing after the fact.
        if (_vfoDebounce != null) {
          _vfoDebounce!.cancel();
          _vfoDebounce = null;
          _pushVfoToRadioService();
        }
        for (var i = 0; i < calls.length; i++) {
          final qso = await widget.qsosRepository.add(widget.operation.uuid, await dataFor(calls[i], i));
          widget.onLogged?.call(qso);
        }
        _wipe();
      }

      // A single rescoring pass after the whole batch, not a dupe/score
      // check per call — the on-screen dupe hint already only ever reflects
      // the cursor's own call (_isDupe/_callAtCursor above).
      if (isList) widget.onCallListLogged?.call();
    } finally {
      _isLogging = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    _scheduleSubmitButtonMeasurement();
    final theme = Theme.of(context);
    final poloColors = HaLoColors.of(context);

    // While editing an existing QSO, the panel swaps its tertiary ("new
    // QSO") accent for the secondary ("editing") accent — mirrors
    // app-polo's `themeColor` switching. Only the tertiary* tokens are
    // remapped (not a full ColorScheme swap), so unrelated colors
    // (primary, error) are unaffected. `accentTheme` carries the remapped
    // HaLoColors extension too, so SecondaryControlRow's chips (which read
    // HaLoColors.of(context)/Theme.of(context) ambiently) pick it up.
    final editing = widget.editingQso != null;
    // Viewing an already-deleted QSO: fields are read-only, same as a
    // staged delete — the only actions are restoring it (the second
    // button) or selecting away (ham2k/app-halo-dist#59).
    final deletedQso = widget.editingQso?.deleted ?? false;
    final fieldsLocked = _fieldsLocked;
    final accentPoloColors = editing
        ? poloColors.copyWith(tertiaryLight: poloColors.secondaryLight)
        : poloColors;
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

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _handleEscape,
        const SingleActivator(LogicalKeyboardKey.enter): _log,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _log,
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
              Container(height: 2, color: accentPoloColors.tertiaryLight),
              Padding(
                // No top inset at all — SecondaryControlRow's expanded
                // panel slides out flush against the divider above, and the
                // row itself animates the border→pills gap, so any padding
                // here would show as bare panel background above the
                // panel's dark area.
                padding: EdgeInsets.fromLTRB(
                  _secondaryPanelHorizontalInset,
                  0,
                  _secondaryPanelHorizontalInset,
                  8,
                ),
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
                      labelStyle: TextStyle(
                        color: accentTheme.colorScheme.onTertiaryContainer.withValues(
                          alpha: 0.85,
                        ),
                      ),
                      floatingLabelStyle: TextStyle(
                        color: accentTheme.colorScheme.onTertiaryContainer,
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: accentTheme.colorScheme.onTertiaryContainer
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: accentTheme.colorScheme.tertiary,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AbsorbPointer(
                        absorbing: fieldsLocked,
                        child: Opacity(
                          opacity: fieldsLocked ? 0.5 : 1,
                          child: SecondaryControlRow(
                            controls: _buildSecondaryControls(accentTheme, accentPoloColors),
                            selectedKey: _selectedControlKey,
                            onSelect: _onSelectControl,
                            onOpenSettings: _openControlSettingsDialog,
                            horizontalBleed: _secondaryPanelHorizontalInset,
                            trailing: _isDupe
                                ? Chip(
                                    label: Text(widget.dupeLabel ?? 'DUPE'),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor:
                                        theme.colorScheme.errorContainer,
                                    labelStyle: TextStyle(
                                      color: theme.colorScheme.onErrorContainer,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // A fixed-height container to prevent layout shifting.
                      // Sized to the second edit button's own diameter (see
                      // _buildWipeOrEditButton) — that button is the same
                      // size as the submit button, well over the 36px this
                      // row used to be, and a shorter row would have it
                      // overflowing upward into the secondary control row's
                      // chips above.
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          SizedBox(
                            height: _editButtonDiameter ?? 44,
                            width: double.infinity,
                            // Reserves room for the button positioned on
                            // top of this box (below), so text truncates
                            // before it rather than rendering underneath.
                            child: Padding(
                              padding: EdgeInsets.only(right: (_editButtonDiameter ?? 44) + 8),
                              child: fieldsLocked
                                  ? Align(
                                      alignment: Alignment.centerLeft,
                                      child: Row(
                                        children: [
                                          Icon(
                                            resolveIconName('alert'),
                                            size: 16,
                                            color: theme.colorScheme.error,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              deletedQso
                                                  ? (widget.deletedQsoWarning ?? 'Deleted QSO')
                                                  : (widget.pendingDeleteWarning ?? 'QSO will be deleted when you save'),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                color: theme.colorScheme.error,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : _buildInfoArea(theme),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: _buildWipeOrEditButton(accentTheme),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // IntrinsicHeight + stretch, rather than a guessed
                      // pixel height, so the submit button (an AspectRatio
                      // circle) is guaranteed to exactly match whatever
                      // height the text fields actually render at — not an
                      // eyeballed constant that drifts if their font size,
                      // padding, or text scale ever changes.
                      IntrinsicHeight(
                        child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _callController,
                              focusNode: _callFocus,
                              // Desktop platforms (see selectAllOnFocus's
                              // default) select-all on focus by default,
                              // which runs *after* our own focus listener
                              // above and silently overwrites its
                              // cursor-at-end placement — this is the only
                              // way to actually suppress it.
                              selectAllOnFocus: false,
                              enabled: !fieldsLocked,
                              autofocus: true,
                              autocorrect: _commandMixedCase,
                              enableSuggestions: _commandMixedCase,
                              // A command awaiting parameters (expectsParams)
                              // switches the field to free-text entry —
                              // spaces allowed, no callsign character
                              // restriction — but stays uppercase-only
                              // unless the command itself declared
                              // `mixedCase: true` (e.g. NOTE, whose
                              // parameter is free prose): all logging input
                              // is uppercase unless explicitly mixed-case.
                              textCapitalization: _commandMixedCase
                                  ? TextCapitalization.sentences
                                  : TextCapitalization.characters,
                              inputFormatters: _commandMixedCase
                                  ? null
                                  : _commandExpectsParams
                                      ? const [UpperCaseTextFormatter()]
                                      : [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'[a-zA-Z0-9/.,]'),
                                          ),
                                          if (isMobilePlatform) MobileDotToSlashFormatter(),
                                          const UpperCaseTextFormatter(),
                                        ],
                              style: _primaryFieldStyle(context, fontWeight: FontWeight.w500),
                              decoration: _primaryFieldDecoration(context, widget.theirCallLabel ?? 'Their call'),
                              onSubmitted: (_) => _log(),
                            ),
                          ),
                          if (widget.showRSTFields) ...[
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 64,
                              child: TextField(
                                controller: _sentController,
                                focusNode: _sentFocus,
                                selectAllOnFocus: false,
                                enabled: !fieldsLocked,
                                style: _primaryFieldStyle(context, fontWeight: FontWeight.w500),
                                // Letters are legitimate in RSTs (CW's "5NN"
                                // shorthand, aurora "59A") and the Edit QSO
                                // pane accepts them — a digits-only filter
                                // here would silently strip a pane-saved
                                // letter on the next keystroke, since
                                // filtering formatters re-run over the whole
                                // text. Uppercased like all logging input.
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9a-zA-Z+\-]'),
                                  ),
                                  const UpperCaseTextFormatter(),
                                ],
                                decoration: _primaryFieldDecoration(context, widget.sentLabel ?? 'Sent'),
                                onChanged: (_) => _rstsTouched = true,
                                onSubmitted: (_) => _log(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 64,
                              child: TextField(
                                controller: _rcvdController,
                                focusNode: _rcvdFocus,
                                selectAllOnFocus: false,
                                enabled: !fieldsLocked,
                                style: _primaryFieldStyle(context, fontWeight: FontWeight.w500),
                                // Same letter-friendly rule as Sent above.
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9a-zA-Z+\-]'),
                                  ),
                                  const UpperCaseTextFormatter(),
                                ],
                                decoration: _primaryFieldDecoration(context, widget.rcvdLabel ?? 'Rcvd'),
                                onChanged: (_) => _rstsTouched = true,
                                onSubmitted: (_) => _log(),
                              ),
                            ),
                          ],
                          if (widget.showStateField) ...[
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 64,
                              child: TextField(
                                controller: _stateController,
                                focusNode: _stateFocus,
                                selectAllOnFocus: false,
                                enabled: !fieldsLocked,
                                textCapitalization: TextCapitalization.characters,
                                inputFormatters: const [UpperCaseTextFormatter()],
                                style: _primaryFieldStyle(context, fontWeight: FontWeight.w500),
                                decoration: _primaryFieldDecoration(context, widget.theirStateLabel ?? 'State'),
                                onChanged: (_) => _stateTouched = true,
                                onSubmitted: (_) => _log(),
                              ),
                            ),
                          ],
                          if (widget.showGridField) ...[
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 64,
                              child: TextField(
                                controller: _gridController,
                                focusNode: _gridFocus,
                                selectAllOnFocus: false,
                                enabled: !fieldsLocked,
                                textCapitalization: TextCapitalization.characters,
                                inputFormatters: const [UpperCaseTextFormatter()],
                                style: _primaryFieldStyle(context, fontWeight: FontWeight.w500),
                                decoration: _primaryFieldDecoration(context, widget.theirGridLabel ?? 'Grid'),
                                onChanged: (_) => _gridTouched = true,
                                onSubmitted: (_) => _log(),
                              ),
                            ),
                          ],
                          const SizedBox(width: 12),
                          // HaLo's big light-blue log button — a circle as
                          // tall as the text fields beside it. (A
                          // LayoutBuilder here to size the icon off the
                          // button's resolved constraints would seem
                          // natural, but IntrinsicHeight above needs to
                          // query this subtree's intrinsic dimensions, which
                          // LayoutBuilder explicitly doesn't support — so
                          // the icon just uses a fixed, comfortable size.)
                          AspectRatio(
                            key: _submitButtonKey,
                            aspectRatio: 1,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: FilledButton(
                                // Disabled while viewing a deleted QSO —
                                // there's nothing to save; restore first.
                                onPressed: (!deletedQso && (_pendingDelete || _canLog)) ? _log : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      accentTheme.colorScheme.tertiary,
                                  foregroundColor:
                                      accentTheme.colorScheme.onTertiary,
                                  minimumSize: Size.zero,
                                  padding: EdgeInsets.zero,
                                  shape: const CircleBorder(),
                                ),
                                child: Icon(
                                  _pendingDelete
                                      ? resolveIconName('trash-can')
                                      : (editing ? resolveIconName('content-save') : Icons.upload),
                                  size: 24 * 1.2 * MediaQuery.textScalerOf(context).scale(1.0),
                                ),
                              ),
                            ),
                          ),
                        ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoArea(ThemeData theme) {
    final message = _commandMessage;
    final lookup = _lookupLine;

    if (message != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: MarkdownBody(
          data: message,
          styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
            p: theme.textTheme.bodyMedium?.copyWith(
              // The info area sits on the panel's tertiaryContainer fill —
              // hardcoded black rendered black-on-dark-brown in dark mode.
              color: theme.colorScheme.onTertiaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    if (lookup != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(
              MdiIcons.accountSearch,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                lookup,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// On mobile, "." often gets typed where "/" was meant — portable/mobile
/// suffixes like "/P" or "/QRP" sit behind an extra keyboard layer, while
/// "." is right on the main keys (issue #7). Converts every "." to "/", but
/// only once the text looks like the start of a callsign (a letter, or a
/// digit then a letter) rather than digits alone, so typing a plain
/// frequency ("14.285") keeps its decimal point. See isMobilePlatform.
///
/// Public (not `_`-prefixed) so other callsign-entry fields — e.g.
/// HomeQuickLookup in app/lib/views/home_view.dart — can reuse it instead
/// of leaving the same mobile keyboard quirk unhandled there.
class MobileDotToSlashFormatter extends TextInputFormatter {
  static final _callsignPrefix = RegExp(r'^([A-Z]|[0-9][A-Z])', caseSensitive: false);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (!text.contains('.') || !_callsignPrefix.hasMatch(text)) {
      return newValue;
    }
    return newValue.copyWith(text: text.replaceAll('.', '/'));
  }
}
