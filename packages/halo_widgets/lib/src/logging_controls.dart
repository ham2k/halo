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
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:halo_core/halo_core.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'form_renderer.dart';
import 'icon_resolver.dart';
import 'keyboard_dismiss.dart';
import 'logging_controls_controller.dart';
import 'mdi_icons.dart';
import 'number_keys.dart';
import 'platform_chrome.dart';
import 'resizable_split_view.dart' show PaneSafeArea;
import 'semantic_id.dart';
import 'ref_text_input.dart';
import 'secondary_control_row.dart';
import 'text_formatters.dart';
import 'theme.dart';
import 'timed_undo_slot.dart';

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

/// Builds the info area's default (no-call) statistics — 0–2 preformatted
/// lines ("{n} QSOs in {time}", "{rate} Q/h for last 10"). The app layer owns
/// the i18n and number/duration formatting; it reads the current time itself,
/// so the widget's 1 Hz clock ticker keeps a live "since last" figure fresh.
/// An empty list renders nothing.
typedef OperationStatsLines = List<String> Function(List<Qso> qsos);

/// Formats the call-info panel's line-1 location string from a lookup `guess`
/// — distance (and bearing, if the setting is on) plus a location label — or
/// null when there's nothing to show. The app layer owns the distance units,
/// the bearing setting, and the operation's own grid; the widget renders the
/// entity flag (`guess['flag']`) alongside whatever this returns.
typedef CallLocationLine = String? Function(Map<String, dynamic> guess);

/// Scores the in-progress QSO for the call-info notices line — returns
/// `{notices, alerts}` lists of scoring keys, or null. Mirrors
/// `ExtensionService.scoreQso`.
typedef ScoreQso = Future<Map<String, dynamic>?> Function({
  required Map<String, dynamic> operation,
  required Map<String, dynamic> qso,
  String? excludeUuid,
});

/// A snapshot of the current call-info for the detail panel (the Info tab on
/// wide layouts, a modal on narrow) — the same data the compact call-info line
/// renders, handed up so a richer view can present it. Immutable value.
class CallInfoData {
  final String call;
  final Map<String, dynamic>? guess;
  final List<Map<String, dynamic>> lookups;
  final List<String> alertKeys;
  final List<String> noticeKeys;

  /// Whether this call-info is for an existing QSO being edited (vs a new one
  /// being composed) — the map uses it to pick the highlight colour (blue
  /// editing, orange composing), the same new-vs-editing accent the logging
  /// panel itself uses.
  final bool isEditing;

  const CallInfoData({
    required this.call,
    this.guess,
    this.lookups = const [],
    this.alertKeys = const [],
    this.noticeKeys = const [],
    this.isEditing = false,
  });
}

/// Fires when the current call-info changes (call/lookup/score), or null when
/// the call-info panel isn't showing. Deduped by the widget.
typedef CallInfoChanged = void Function(CallInfoData? info);

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

  /// Fired after a QSO is soft-deleted / restored here (the pending-delete
  /// save path and the deleted-QSO restore button) — deletes don't go
  /// through [onLogged], so callers that track or react to them need their
  /// own signal.
  final void Function(Qso qso)? onQsoDeleted;
  final void Function(Qso qso)? onQsoUndeleted;

  /// Fires once after a comma-separated call list (issue #7) finishes
  /// saving all its QSOs — never for an ordinary single-call log, which
  /// already gets its (cheap, cached) dupe/lookup handling inline. Intended
  /// for the caller to trigger a single rescoring pass for the whole batch,
  /// rather than scoring each call as it's added.
  final VoidCallback? onCallListLogged;

  /// Optional lookup enrichment; fired debounced, off the keystroke path.
  final CallLookup? lookup;

  /// Hands a just-saved QSO to the caller's background lookup queue, so
  /// online enrichment happens after the record is on screen instead of
  /// delaying the save (no network ⇒ no stall). Fired for every newly ADDED
  /// QSO — single calls, comma-list entries, stacked ("//") calls, and
  /// command actions (e.g. SEED) — but never for the record being edited
  /// (its stored data is deliberately left alone). The queue itself skips
  /// QSOs that already carry online lookup data (e.g. a single call whose
  /// debounced preview resolved before Enter), so handing over everything
  /// is safe and lets a fast Enter that beat the preview still get
  /// enriched.
  final void Function(Qso qso)? enqueueLookup;

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

  /// A command hook pushing a later CommandInterpretation for an `input` it
  /// was already asked to interpret (issue #189) — e.g. SOLAR/WEATHER's
  /// background fetch resolving after their own describe-preview call
  /// already returned. `{'input': String, 'interpretation': Map}` per
  /// event; applied only while `input` still matches the live call field —
  /// see `host.updateInterpretation`'s SDK doc. Never dispatches `commands`
  /// itself; only Enter (via [interpretCommand]'s `execute:true` call) logs
  /// anything.
  final Stream<Map<String, dynamic>>? interpretationUpdates;

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

  /// Escape's own way of ending an editing session (ham2k/app-halo-dist#199
  /// follow-up) — called instead of [onEditCanceled] so the caller can offer
  /// to undo it (re-select the QSO on a second Escape), unlike Save/Delete/
  /// Restore/Revert, which end the session for good. Falls back to
  /// [onEditCanceled] when unset.
  final VoidCallback? onEscapeDeselect;

  /// Escape, with nothing composed and no wipe to undo, asks the caller
  /// whether *it* has something to undo instead — a QSO [onEscapeDeselect]
  /// just deselected. Returns whether it actually undid something; when
  /// false (or unset), Escape falls through to its normal empty-form wipe.
  final bool Function()? onUndoDeselect;

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

  /// The info area's three collaborators (issue #40). All optional — when
  /// null the area degrades gracefully: no stats lines, no location line, no
  /// scoring notices. See `_buildInfoArea`.
  final OperationStatsLines? operationStatsLines;
  final CallLocationLine? callLocationLine;
  final ScoreQso? scoreQso;

  /// Maps a scoring notice/alert key (`duplicate`, `newBand`, `newMode`,
  /// `newDXCC`) to its localized pill text; falls back to the raw key.
  final String Function(String noticeKey)? scoreNoticeLabel;

  /// Notifies the host of the current call-info (for the detail panel — the
  /// Info tab on wide layouts), null when the call-info panel isn't showing.
  final CallInfoChanged? onCallInfoChanged;

  /// Fires when the user taps the compact call-info area — the host opens the
  /// detail panel (a modal on narrow layouts, or focuses the Info tab on wide).
  final VoidCallback? onCallInfoTap;

  final String? timeLabel;
  final String? dateLabel;
  final String? nowLabel;
  final String? freqLabel;
  final String? modeLabel;
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

  /// The secondary control row's grid expand/collapse caret tooltips.
  final String? expandControlsTooltip;
  final String? collapseControlsTooltip;

  /// Localized chrome for the "More" full-edit pane's form renderer
  /// (Cancel/Save buttons, close tooltip, error prefixes — see
  /// FormRendererLabels). Null keeps the English defaults.
  final FormRendererLabels? formLabels;

  /// The band/mode options offered by the Radio control's dropdowns — the
  /// user's enabled lists from Settings (Logging → Bands/Modes). Null falls
  /// back to the full catalogs from halo_core; empty falls back to the
  /// "common" tier (`popularBands`/`mainModes`, the same subset the settings
  /// multiselect flags common) — the multiselect enforces no minimum, and
  /// deselecting everything must not leave the Band dropdown with zero
  /// entries. The current QSO's value is always offered even when it's not
  /// in the list, so editing a QSO logged on a since-disabled band/mode
  /// doesn't show an empty control.
  final List<String>? enabledBands;
  final List<String>? enabledModes;

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

  /// The mobile numbers row (issue #27) — a bar of digit keys floated above
  /// the on-screen keyboard while a logging field has focus. Only ever shown
  /// on mobile platforms with the keyboard up (see `_buildNumberKeys`).
  /// [showExtraInNumbersRow] adds the contextual "/" (callsign) / "."
  /// (numeric) key; [vibrateNumbersRow] toggles the key-press haptic.
  final bool showNumbersRow;
  final bool showExtraInNumbersRow;
  final bool vibrateNumbersRow;

  /// Optional imperative handle for driving the controls from outside (set the
  /// call, log, wipe) — used by the app's dev bridge. Attached on mount.
  final LoggingControlsController? controller;

  const LoggingControls({
    super.key,
    required this.operation,
    required this.qsosRepository,
    this.controller,
    this.qsos = const [],
    this.onLogged,
    this.onQsoDeleted,
    this.onQsoUndeleted,
    this.onCallListLogged,
    this.lookup,
    this.enqueueLookup,
    this.activityControls = const [],
    this.refreshActivityControls,
    this.decorateRef,
    this.interpretCommand,
    this.interpretationUpdates,
    this.onCommandMessageChanged,
    this.onCommandAction,
    this.editingQso,
    this.suggestedQso,
    this.onEditCanceled,
    this.onEscapeDeselect,
    this.onUndoDeselect,
    this.settings,
    this.radioService,
    this.controlOrder = const [],
    this.hiddenControlKeys = const {},
    this.onControlsSettingsChanged,
    this.operationStatsLines,
    this.callLocationLine,
    this.scoreQso,
    this.scoreNoticeLabel,
    this.onCallInfoChanged,
    this.onCallInfoTap,
    this.timeLabel,
    this.dateLabel,
    this.nowLabel,
    this.freqLabel,
    this.modeLabel,
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
    this.expandControlsTooltip,
    this.collapseControlsTooltip,
    this.formLabels,
    this.enabledBands,
    this.enabledModes,
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
    this.showNumbersRow = false,
    this.showExtraInNumbersRow = true,
    this.vibrateNumbersRow = true,
  });

  @override
  State<LoggingControls> createState() => _LoggingControlsState();
}

class _LoggingControlsState extends State<LoggingControls> with WidgetsBindingObserver {
  final _callController = TextEditingController();
  final _sentController = TextEditingController();
  final _rcvdController = TextEditingController();
  final _freqController = TextEditingController();
  final _timeController = TextEditingController();
  final _dateController = TextEditingController();
  final _gridController = TextEditingController();
  final _stateController = TextEditingController();
  // The Radio control's Band/Mode dropdown text. Owned here (not left to
  // DropdownMenu's internal controller) so typed text can drive the entry
  // filter and be committed to the first match — see
  // `_commitBandDropdownText` / `_commitModeDropdownText`.
  final _bandDropdownController = TextEditingController();
  final _modeDropdownController = TextEditingController();
  final _bandMenuController = MenuController();
  final _modeMenuController = MenuController();
  // The active menu filter — what the user actually typed — kept separate
  // from the field's display text, which arrow navigation overwrites with
  // full option labels. Reset when a field gains focus, so each fresh
  // interaction starts unfiltered.
  String _bandFilter = '';
  String _modeFilter = '';
  // True while an arrow key is stepping/walking the selection, so the
  // resulting display-text write (ours when the menu is closed,
  // DropdownMenu's own when it's open) is not mistaken for typed input and
  // does not clobber the filter.
  bool _navigatingDropdown = false;
  // Built in initState (not a `late final` initializer), so `dispose` never
  // forces their construction just to tear them down when the Radio control
  // was never expanded.
  late final FocusNode _bandDropdownFocus;
  late final FocusNode _modeDropdownFocus;
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

  /// The band of the most recent non-empty frequency, remembered so that
  /// clearing the frequency field keeps that band ([_onFreqChanged]) rather
  /// than dropping to no band.
  String? _lastBandFromFreq;
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

  /// Lookups resolved during the current compose session, keyed by call, so
  /// re-typing a call already looked up this session (KI2D → KI2DX → KI2D)
  /// shows its result instantly with no refetch. Cleared on wipe/log/populate.
  /// A cached `null` (a call that resolved to nothing) is distinct from absent.
  final Map<String, Map<String, dynamic>?> _lookupCache = {};

  /// Live scoring for the call-info notices line (issue #40) — debounced like
  /// the lookup. `_scoreFor` is the call the current keys belong to, so a
  /// stale result from a call the user has since edited past is ignored.
  Timer? _scoreDebounce;
  String? _scoreFor;
  List<String> _scoreAlertKeys = const [];
  List<String> _scoreNoticeKeys = const [];

  /// Drives the info area's cross-fade (issue #40): `_infoGeneration` bumps
  /// only when `_infoAreaSignature` changes, giving the AnimatedSwitcher a
  /// never-repeating key (see build).
  String? _lastInfoSignature;
  int _infoGeneration = 0;

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
  StreamSubscription<Map<String, dynamic>>? _interpretationUpdatesSub;

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

  /// Whether the call field is in command free-text mode — space is a
  /// literal character and the callsign character filter is lifted, but
  /// input stays uppercase-only unless [_commandMixedCase] also holds.
  /// Two ways in, both requiring a retained command:
  /// - the command is a recognized prefix still awaiting its parameters
  ///   ("RELOAD" before its target — `expectsParams`), or
  /// - the text already holds characters the callsign formatters would
  ///   destroy (a space, mid-parameter). Without this, a typing pause after
  ///   "EXP L" lets the debounced interpret retain a COMPLETE
  ///   interpretation (token "L"), and the returning callsign filter would
  ///   rewrite the whole field on the very next keystroke — "EXP LA"
  ///   snapping to "EXPLA". Same guard [_retainInterpretation] applies to
  ///   the null-result path, for the same reason.
  bool get _commandExpectsParams =>
      _retainedInterpretation != null &&
      (_retainedInterpretation!['expectsParams'] == true || !_callsignModeSafeText.hasMatch(_callController.text));

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
  final _spotCommentFocus = FocusNode();
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
  final _wipeUndoSlot = TimedUndoSlot<Map<String, dynamic>>();

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
  /// shortcut does — see [_VirtualSpaceFormatter]. One shared instance since it
  /// only closes over the stable [_handleSpace] tear-off.
  late final _VirtualSpaceFormatter _virtualSpace = _VirtualSpaceFormatter(_handleSpace);

  /// Keyboard for the numeric-leaning primary fields (RST, frequency) on iOS.
  /// `numberWithOptions(signed: true)` selects iOS's NumbersAndPunctuation
  /// keyboard: numbers up front, but WITH a space bar (so Space still rotates
  /// focus — see [_VirtualSpaceFormatter]) and the symbols these fields use —
  /// an RST like "5NN"/"59A" reaches letters via its ABC key, and +/- and the
  /// frequency separators sit on the primary page. Without it these fields get
  /// the letter-first default keyboard, which buries digits behind the "123"
  /// key for input that's mostly numeric.
  ///
  /// Null off iOS: Android's default keyboard already has both letters and a
  /// space bar, and a signed-number type there would instead drop to a numeric
  /// pad that loses the letters RSTs occasionally need — so each field keeps
  /// its existing keyboard on other platforms.
  TextInputType? get _numbersAndPunctuationOnIOS =>
      isIOSPlatform ? const TextInputType.numberWithOptions(signed: true) : null;

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
    // Observe metrics so the numbers row appears/disappears with the on-screen
    // keyboard — MediaQuery can't tell us (Scaffold strips the inset, see
    // `virtualKeyboardIsUp`), so `didChangeMetrics` is the rebuild trigger.
    WidgetsBinding.instance.addObserver(this);
    _bandDropdownFocus = _dropdownCommitFocusNode(
      commit: _commitBandDropdownText,
      clearFilter: () => _bandFilter = '',
      menu: _bandMenuController,
      step: _stepBandSelection,
    );
    _modeDropdownFocus = _dropdownCommitFocusNode(
      commit: _commitModeDropdownText,
      clearFilter: () => _modeFilter = '',
      menu: _modeMenuController,
      step: _stepModeSelection,
    );
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
    _interpretationUpdatesSub = widget.interpretationUpdates?.listen(_onInterpretationUpdate);
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
    _bandDropdownController.addListener(_onBandDropdownTextChanged);
    _modeDropdownController.addListener(_onModeDropdownTextChanged);
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
        // Keep the mobile numbers row in sync with which field has focus.
        _rebuildForNumbersRow();
      });
    }
    _refreshSpotSources();
    // Constructed already editing a QSO (rather than transitioning into it via
    // didUpdateWidget): score it so its pills show, and enqueue it for a
    // background lookup if it never got one — same as _populateFromEditingQso
    // does for the transition case. Scoring is guarded on _callInfoActive so
    // it only schedules a timer here — never setStates during initState;
    // enqueueLookup needs no such guard, it's fire-and-forget into the
    // caller's own queue.
    if (widget.editingQso != null) {
      if (_callInfoActive) _scheduleScore();
      widget.enqueueLookup?.call(widget.editingQso!);
    }
    // Wire the imperative handle (used by the app's dev bridge) so the call
    // field / Log / Wipe can be driven from outside the widget.
    widget.controller?.attach(setField: _devSetField, submit: _log, wipe: _wipe, isFieldsLocked: () => _fieldsLocked);
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
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach();
      widget.controller?.attach(setField: _devSetField, submit: _log, wipe: _wipe, isFieldsLocked: () => _fieldsLocked);
    }
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
    _wipeUndoSlot.clear();
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
    // Score the edited QSO (excluding itself) so its dupe/New-* pills show, the
    // same way they do while composing — populate suppressed _onCallChanged's
    // own trigger.
    _scheduleScore();
    // A QSO logged before its online lookup ever ran (e.g. offline, or a
    // quick log with the runtime still booting) should get one now rather
    // than sit unenriched until the next background pass — `enqueueLookup`
    // already skips QSOs that already have real (non-annotation-only)
    // lookup data, so this is a no-op for anything already enriched.
    widget.enqueueLookup?.call(qso);
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
    // Populating a suggestion sets the call without the user typing, so
    // `_populating` suppressed _onCallChanged's own _scheduleLookup()/
    // _scheduleScore(). Any source that sets the current QSO's callsign must
    // still trigger a lookup — spots (#315) and a future deeplink both arrive
    // here — so run them explicitly, like `_restoreFromUndoSlot` does.
    // `_applyFieldsFromData` cleared `_lookupFor`/`_lookupCache` above, so the
    // "only when changed" guard won't wrongly short-circuit. Guarded on
    // `_callInfoActive` (a real call is present) so both only schedule their
    // timers and never setState synchronously — this also runs from initState
    // for a deeplink cold-start (see the editingQso init path above).
    if (_callInfoActive) {
      _scheduleLookup();
      _scheduleScore();
    }
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
    // Only the entered value fills the field; a guess (their.guess) stays a
    // faint placeholder (see the Grid/State decorations) instead of being
    // pre-filled as if it were a confirmed value.
    _gridController.text = (their['grid'] as String?) ?? '';
    _stateController.text = (their['state'] as String?) ?? '';
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
    _clearScoreNotices();
    _lookupCache.clear();
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
    _clearScoreNotices();
    _lookupCache.clear();
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
    widget.controller?.detach();
    WidgetsBinding.instance.removeObserver(this);
    _clockTicker?.cancel();
    _lookupDebounce?.cancel();
    _scoreDebounce?.cancel();
    _vfoDebounce?.cancel();
    _commandDescribeDebounce?.cancel();
    _interpretationUpdatesSub?.cancel();
    _executeMessageTimer?.cancel();
    _wipeUndoSlot.dispose();
    _spotStatusClearTimer?.cancel();
    _spotCommentController.dispose();
    _spotCommentFocus.dispose();
    _callController.dispose();
    _sentController.dispose();
    _rcvdController.dispose();
    _freqController.dispose();
    _timeController.dispose();
    _dateController.dispose();
    _gridController.dispose();
    _stateController.dispose();
    _bandDropdownController.dispose();
    _modeDropdownController.dispose();
    _bandDropdownFocus.dispose();
    _modeDropdownFocus.dispose();
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

  /// Whether the call field holds a recognized command that [_log] would act
  /// on — as opposed to a callsign, an incomplete command still awaiting its
  /// parameters (`expectsParams`), or plain text. Drives the submit button so
  /// it accepts a command the same way Enter already does (the field's
  /// `onSubmitted` and the panel's Enter/numpadEnter shortcut both call
  /// [_log]). The button is otherwise gated on [_canLog], which is false for a
  /// command because a command isn't a valid callsign — so on mobile, where
  /// this button is the primary submit affordance, a command could only be run
  /// from the on-screen keyboard's return key.
  ///
  /// Reads the same interpretation state the describe-message UI does, so the
  /// button enables in step with the command preview appearing. [_log]
  /// re-interprets the live text when actually run, so a momentarily stale
  /// retained value here at worst enables the button for an
  /// interpret-and-fall-through no-op, never a wrong action.
  bool get _hasExecutableCommand {
    if (widget.editingQso != null || widget.interpretCommand == null || _call.isEmpty) {
      return false;
    }
    final interpretation = _currentInterpretation ?? _retainedInterpretation;
    return interpretation != null && interpretation['expectsParams'] != true;
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

  void _onFreqChanged() {
    final freq = _freq;
    if (freq != null) {
      _manualBand = null;
      // Remember the band so clearing the frequency can fall back to it.
      _lastBandFromFreq = bandForFrequency(freq);
    } else if (_freqController.text.trim().isEmpty) {
      // Frequency cleared: stay on the band it was last, rather than dropping
      // to no band. Deferential (`??=`) so a band the user set by hand wins.
      _manualBand ??= _lastBandFromFreq;
    }
    setState(() {});
    // Band (derived from frequency) drives the New Band notice — rescore.
    if (!_populating) _scheduleScore();
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
    // New Mode / New Band notices depend on the mode — rescore the candidate.
    _scheduleScore();
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

  InputDecoration _primaryFieldDecoration(BuildContext context, String label, {String? hintText}) =>
      poloFieldDecoration(
        context,
        label,
        labelColor: Theme.of(context).colorScheme.onTertiaryContainer,
        hintText: hintText,
      );

  /// One of the fixed-width (64px) secondary logging fields — Sent, Rcvd,
  /// State, Grid — which share everything but their controller/label and a
  /// couple of input-shaping knobs. Amateur-radio codes, not prose: stop the
  /// soft keyboard from autocorrecting, spell-checking, suggesting, or
  /// smart-punctuating the value into garbage (autocorrect:false also turns
  /// off iOS spell check; the smart types stop "-" → "–"). Uppercased like
  /// all logging input, and Enter logs.
  Widget _fixedField(
    BuildContext context, {
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool enabled,
    required String label,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputFormatter? filter,
    String? hintText,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: 64,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        selectAllOnFocus: false,
        enabled: enabled,
        style: _primaryFieldStyle(context, fontWeight: FontWeight.w500),
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        autocorrect: false,
        enableSuggestions: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        inputFormatters: [_virtualSpace, ?filter, const UpperCaseTextFormatter()],
        decoration: _primaryFieldDecoration(context, label, hintText: hintText),
        onChanged: onChanged,
        onSubmitted: (_) => _log(),
      ),
    );
  }

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
          specs.add(_radioControlSpec(theme));
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

  /// The Band dropdown's options: the enabled list ([LoggingControls.enabledBands]),
  /// the common tier when that's empty, the full catalog when null — with
  /// the current value appended when it's not in the list (see the field's
  /// doc for why each fallback exists).
  List<String> _bandDropdownOptions() {
    final enabled = widget.enabledBands;
    final options = enabled == null
        ? [for (final b in bands) b.name]
        : enabled.isEmpty
            ? popularBands
            : enabled;
    final band = _band;
    return [...options, if (band != null && !options.contains(band)) band];
  }

  List<String> _modeDropdownOptions() {
    final enabled = widget.enabledModes;
    final options = enabled == null
        ? modes
        : enabled.isEmpty
            ? mainModes
            : enabled;
    return [...options, if (!options.contains(_mode)) _mode];
  }

  /// Menu entries for the active [filter]: a case-insensitive contains
  /// match. An empty filter (nothing typed, or cleared on focus) and a
  /// filter matching nothing both mean "no filter" — the latter so a typo
  /// shows the full menu rather than an empty one. The filter only ever
  /// holds genuinely typed text (see [_onDropdownTextChanged]), so typing a
  /// complete short name like "2m" narrows to it rather than showing all.
  List<String> _filteredOptions(List<String> options, String filter) {
    final typed = filter.trim();
    if (typed.isEmpty) return options;
    final q = typed.toLowerCase();
    final matches = [for (final o in options) if (o.toLowerCase().contains(q)) o];
    return matches.isEmpty ? options : matches;
  }

  /// An exact (case-insensitive) match wins over the first contains-match,
  /// so e.g. "2m" can never resolve to another band that merely contains
  /// it as a substring.
  String? _firstMatch(List<String> options, String text) {
    final q = text.toLowerCase();
    for (final o in options) {
      if (o.toLowerCase() == q) return o;
    }
    for (final o in options) {
      if (o.toLowerCase().contains(q)) return o;
    }
    return null;
  }

  // The menu-entry lists are memoized on the joined option values and reused
  // while unchanged: DropdownMenu compares entries by LIST IDENTITY in
  // didUpdateWidget and resets its highlight state on any change, so passing
  // a freshly built list on every rebuild (this widget rebuilds each second
  // for the clock alone) would break walking the open menu with the arrow
  // keys. Keyed on the values rather than deep-compared, so re-deriving the
  // entries costs one join, not an element-wise scan.
  String? _bandMenuKey;
  String? _modeMenuKey;
  List<DropdownMenuEntry<String>> _bandMenuEntries = const [];
  List<DropdownMenuEntry<String>> _modeMenuEntries = const [];

  /// Returns [cache] unchanged when [values] matches [cacheKey], else
  /// rebuilds the entries and updates [cacheKey] via [setKey]. `\x00`
  /// joins the values — a separator that can't appear in a band/mode name,
  /// so distinct value lists never collide on the same key.
  List<DropdownMenuEntry<String>> _memoEntries(
    String? cacheKey,
    List<DropdownMenuEntry<String>> cache,
    List<String> values,
    void Function(String key) setKey,
  ) {
    final key = values.join('\x00');
    if (key == cacheKey) return cache;
    setKey(key);
    return [for (final v in values) DropdownMenuEntry(value: v, label: v)];
  }

  void _onBandDropdownTextChanged() =>
      _onDropdownTextChanged((f) => _bandFilter = f, _bandDropdownController.text, _band ?? '');
  void _onModeDropdownTextChanged() =>
      _onDropdownTextChanged((f) => _modeFilter = f, _modeDropdownController.text, _mode);

  /// Captures genuinely typed text as the menu [filter] and rebuilds so the
  /// menu re-filters. Two kinds of controller write must NOT become a
  /// filter: arrow navigation ([_navigatingDropdown]), and the full-label
  /// writes a pick / external selection change / commit push through the
  /// controller — those equal the current [selection], and treating them as
  /// a filter would narrow the menu down to just the selected entry (and,
  /// for the arrow-step's rebuild-time [DropdownMenu.initialSelection] sync,
  /// strand the stepping on a single entry). The rebuild is deferred when
  /// the change lands during build — DropdownMenu writes to the controller
  /// from its own initState/didUpdateWidget, where a synchronous setState
  /// would throw.
  void _onDropdownTextChanged(ValueChanged<String> setFilter, String text, String selection) {
    if (!mounted) return;
    if (!_navigatingDropdown && text != selection) setFilter(text);
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  /// Applies typed-but-not-picked Band text: the first matching option
  /// becomes the selection, exactly as if picked from the menu; no match
  /// reverts the text to the current selection. Runs on Enter (before the
  /// root CallbackShortcuts logs the QSO, so the QSO gets the new band) and
  /// when focus leaves the dropdown. The `mounted` guard matters because
  /// this is invoked from a `scheduleMicrotask` in the blur handler, which
  /// can outlive the widget (e.g. the operation view closing while a
  /// dropdown holds focus) — `setState` on a defunct State would throw.
  void _commitBandDropdownText() {
    if (!mounted) return;
    final text = _bandDropdownController.text.trim();
    if (text.isNotEmpty && text != (_band ?? '')) {
      final match = _firstMatch(_bandDropdownOptions(), text);
      if (match != null && match != _band) _applyBandPick(match);
    }
    _bandFilter = '';
    _bandDropdownController.text = _band ?? '';
  }

  void _commitModeDropdownText() {
    if (!mounted) return;
    final text = _modeDropdownController.text.trim();
    if (text.isNotEmpty && text != _mode) {
      final match = _firstMatch(_modeDropdownOptions(), text);
      if (match != null && match != _mode) _setMode(match);
    }
    _modeFilter = '';
    _modeDropdownController.text = _mode;
  }

  /// A dropdown field's focus node, wired to [commit] typed text on Enter
  /// (letting the event continue toward the root Enter-logs-the-QSO
  /// shortcut, so a logged QSO gets the just-committed value) and on focus
  /// leaving the field — which also closes [menu], so the overlay doesn't
  /// linger after a Tab or a click elsewhere. The focus-loss commit is
  /// deferred a microtask: clicking a menu entry can move focus out before
  /// onSelected fires, and the pick must win over the typed text. Gaining
  /// focus [clearFilter]s, so each fresh interaction starts unfiltered.
  ///
  /// Arrow keys with the menu CLOSED [step] the actual selection directly;
  /// with the menu open they're left to DropdownMenu's own shortcuts, which
  /// walk the highlight and write each entry into the field. Either way the
  /// stepping stays within the current filter — [_navigatingDropdown]
  /// guards the resulting text write from resetting it.
  FocusNode _dropdownCommitFocusNode({
    required VoidCallback commit,
    required VoidCallback clearFilter,
    required MenuController menu,
    required void Function(int delta) step,
  }) {
    final node = FocusNode();
    node.addListener(() {
      if (node.hasFocus) {
        clearFilter();
      } else {
        if (menu.isOpen) menu.close();
        scheduleMicrotask(commit);
      }
    });
    node.onKeyEvent = (n, event) {
      if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
        commit();
        return KeyEventResult.ignored;
      }
      if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
        // The upcoming display-text write — ours below, or DropdownMenu's
        // own when the menu is open — must not be read back as a new
        // filter. Cleared next microtask, once this event is fully handled.
        _navigatingDropdown = true;
        scheduleMicrotask(() => _navigatingDropdown = false);
        if (!menu.isOpen) {
          step(key == LogicalKeyboardKey.arrowDown ? 1 : -1);
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    return node;
  }

  /// The Band dropdown's onSelected effect, shared with the typed-text
  /// commit and the arrow-key step: picking a band directly is mutually
  /// exclusive with a manual frequency, since `_band` prefers the
  /// freq-derived value whenever `_freq` is set (matches the
  /// `setVfo{band: ...}` command action's convention — see
  /// `_dispatchActions`). Only while composing — editing an existing QSO
  /// applies changes to the QSO, never the VFO.
  void _applyBandPick(String value) {
    setState(() {
      _manualBand = value;
      _freqController.clear();
    });
    if (widget.editingQso == null) widget.radioService?.setVfo('vfoA', band: value);
  }

  void _stepBandSelection(int delta) {
    final next = _steppedOption(_filteredOptions(_bandDropdownOptions(), _bandFilter), _band, delta);
    if (next == null) return;
    _applyBandPick(next);
    _bandDropdownController.text = next;
  }

  void _stepModeSelection(int delta) {
    final next = _steppedOption(_filteredOptions(_modeDropdownOptions(), _modeFilter), _mode, delta);
    if (next == null) return;
    _setMode(next);
    _modeDropdownController.text = next;
  }

  /// The option [delta] steps away from [current], wrapping like the open
  /// menu's own highlight does. No current value: down starts at the first
  /// option, up at the last.
  String? _steppedOption(List<String> options, String? current, int delta) {
    if (options.isEmpty) return null;
    final i = current == null ? -1 : options.indexOf(current);
    if (i < 0) return delta > 0 ? options.first : options.last;
    return options[(i + delta) % options.length];
  }

  SecondaryControlSpec _radioControlSpec(ThemeData theme) => SecondaryControlSpec(
        key: 'radio',
        icon: MdiIcons.radio,
        summary: _radioSummary,
        expandedBuilder: (context) {
          final band = _band;
          _bandMenuEntries = _memoEntries(_bandMenuKey, _bandMenuEntries,
              _filteredOptions(_bandDropdownOptions(), _bandFilter), (k) => _bandMenuKey = k);
          _modeMenuEntries = _memoEntries(_modeMenuKey, _modeMenuEntries,
              _filteredOptions(_modeDropdownOptions(), _modeFilter), (k) => _modeMenuKey = k);
          // DropdownMenu treats an explicit focusNode's canRequestFocus as
          // overriding its per-platform requestFocusOnTap default, so
          // restore that default here: type-to-filter is a keyboard
          // (desktop) affordance; on touch platforms tapping stays a plain
          // pick, without popping the on-screen keyboard.
          final typeable = switch (Theme.of(context).platform) {
            TargetPlatform.iOS || TargetPlatform.android || TargetPlatform.fuchsia => false,
            _ => true,
          };
          _bandDropdownFocus.canRequestFocus = typeable;
          _modeDropdownFocus.canRequestFocus = typeable;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownMenu<String>(
                controller: _bandDropdownController,
                focusNode: _bandDropdownFocus,
                menuController: _bandMenuController,
                initialSelection: band,
                label: Text(widget.bandLabel ?? 'Band'),
                width: 104,
                menuHeight: dropdownMenuMaxHeight(context),
                // Pick-only menus. With search on (the default), every
                // rebuild whose field text matches an entry re-runs
                // scrollToHighlight — and this widget rebuilds every second
                // (the Time chip's clock), so an open menu kept snapping
                // back to the selected item while the user scrolled.
                enableSearch: false,
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
                  // Without this the trailing arrow's 48px min tap target
                  // makes the field taller (56px) than the sibling
                  // poloFieldDecoration TextFields (53px); the whole field
                  // is tappable, so the shrunken icon target costs nothing.
                  suffixIconConstraints: const BoxConstraints(maxHeight: 38, maxWidth: 40),
                ),
                dropdownMenuEntries: _bandMenuEntries,
                onSelected: (value) {
                  if (value == null) return;
                  // A discrete dropdown pick, not a keystroke — push to the
                  // VFO immediately rather than debouncing like frequency
                  // typing (see _applyBandPick).
                  _applyBandPick(value);
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
                  // iOS: NumbersAndPunctuation (has the decimal separators, the
                  // symbols, and a space bar for Space-to-advance); other
                  // platforms keep the decimal pad.
                  keyboardType: _numbersAndPunctuationOnIOS ?? const TextInputType.numberWithOptions(decimal: true),
                  // No autocorrect/suggestions/smart punctuation — see Sent.
                  autocorrect: false,
                  enableSuggestions: false,
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  inputFormatters: [
                    _virtualSpace,
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  onSubmitted: (_) => _log(),
                ),
              ),
              const SizedBox(width: 6),
              DropdownMenu<String>(
                controller: _modeDropdownController,
                focusNode: _modeDropdownFocus,
                menuController: _modeMenuController,
                initialSelection: _mode,
                label: Text(widget.modeLabel ?? 'Mode'),
                width: 104,
                menuHeight: dropdownMenuMaxHeight(context),
                // See the Band dropdown: search off so rebuilds don't
                // re-scroll the open menu to the selection.
                enableSearch: false,
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
                  // Same height trim as the Band dropdown above.
                  suffixIconConstraints: const BoxConstraints(maxHeight: 38, maxWidth: 40),
                ),
                dropdownMenuEntries: _modeMenuEntries,
                onSelected: (value) {
                  if (value == null) return;
                  _setMode(value);
                  _callFocus.requestFocus();
                },
              ),
            ],
          );
        },
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
    // Colors from a previous attempt would misread as THIS attempt's
    // results while the send is in flight — back to neutral gray first.
    setState(() {
      _spotSending = true;
      _spotStatus.clear();
    });
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
                focusNode: _spotCommentFocus,
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
                : Icon(resolveIconName('hand-wave')),
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
                      shadows: _glyphGlow(theme),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// Re-runs the callsign lookup after the QSO's refs change (e.g. adding a
  /// hunted POTA park or SOTA summit). The POTA/SOTA `lookup` hooks read the
  /// QSO's refs to resolve a park/summit grid, but the lookup is otherwise
  /// keyed and cached by callsign alone — so a ref added after the call would
  /// never reach the guess. Invalidate the cache entry for the active call and
  /// re-schedule (ham2k/app-halo-dist#185).
  void _relookupForRefsChanged() {
    if (_populating || widget.lookup == null) return;
    final activeCall = _callAtCursor;
    if (!looksLikeCallsign(activeCall)) return;
    _lookupCache.remove(activeCall);
    _lookupFor = null;
    _scheduleLookup();
  }

  SecondaryControlSpec _activityControlSpec(Map<String, dynamic> control) {
    final refCount = _controlRefs[control['key']]?.length ?? 0;
    final label = (control['label'] as String?) ?? control['key'] as String;
    return SecondaryControlSpec(
      key: control['key'] as String,
      icon: resolveIconName(control['icon'] as String?),
      // A check per reference marks a park-and-summit-style "twofer"; beyond
      // two, a single check plus the count keeps the label from running long
      // (e.g. a 5-park POTA rove would otherwise be "✔️✔️✔️✔️✔️ POTA").
      summary: switch (refCount) {
        0 => label,
        1 => '✔️ $label',
        2 => '✔️✔️ $label',
        _ => '✔️×$refCount $label',
      },
      // Accent the icon (issue #187) only once the field actually holds a
      // reference — an active-but-empty control stays the default color.
      iconColor: refCount > 0 ? resolveExtensionColor(control['color'] as String?) : null,
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
          // Re-run the lookup so a park/summit ref added after the call reaches
          // the guess (POTA/SOTA lookup hooks key off the QSO's refs).
          onChanged: (refs) {
            setState(() => _controlRefs[control['key'] as String] = refs);
            _relookupForRefsChanged();
          },
          decorate: widget.decorateRef,
          labelColor: Theme.of(context).colorScheme.onTertiaryContainer,
        ),
      ),
    );
  }

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
    } else if (_spotCommentFocus.hasFocus) {
      // Free prose, like NOTE's parameter: Space types a literal space —
      // the panel-wide shortcut would otherwise swallow it.
      _insertAtCursor(_spotCommentController, ' ');
    }
    // Space is inert in any other field with no override of its own.
    // RefTextInput is the one exception — it binds Space locally to type a
    // literal separator instead, taking priority over this panel-wide
    // shortcut.
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
  /// ahead of letters still reads as numeric), "." for every numeric field.
  /// Null when the extra key is turned off. Mirrors app-polo's callsign vs
  /// numbers mode split (H2kCallsignInput / H2kRSTInput).
  String? get _numbersRowExtraKey {
    if (!widget.showExtraInNumbersRow) return null;
    if (_callFocus.hasFocus) {
      final text = _callController.text;
      final hasLetter = RegExp(r'[A-Za-z]').hasMatch(text);
      final onlyDigits = RegExp(r'^[0-9]+$').hasMatch(text);
      if (hasLetter && !onlyDigits) return '/';
    }
    return '.';
  }

  /// Inserts a numbers-row key at the focused field's cursor. `_insertAtCursor`
  /// writes the controller value directly, which fires the controller
  /// listeners (lookup/dupe/rebuild) but NOT the TextField's `onChanged` — so
  /// the "touched" flags those onChanged handlers set are replicated here,
  /// else a tapped digit wouldn't mark RST/Grid/State as user-edited.
  void _handleNumberKey(String key) {
    final field = _focusedNumberField;
    if (field == null || _fieldsLocked) return;
    final (focus, controller) = field;
    _insertAtCursor(controller, key);
    if (identical(focus, _sentFocus) || identical(focus, _rcvdFocus)) {
      _rstsTouched = true;
    } else if (identical(focus, _gridFocus)) {
      _gridTouched = true;
    } else if (identical(focus, _stateFocus)) {
      _stateTouched = true;
    }
  }

  /// Rebuilds so the bar's visibility and contextual "/"→"." key track the
  /// focused field. Focus notifications can arrive mid-build (autofocus on
  /// the first frame), so a rebuild is only requested synchronously when
  /// we're safely between frames; otherwise it's deferred to the frame in
  /// progress. Only runs while the feature is on, so it costs nothing
  /// otherwise.
  void _rebuildForNumbersRow() {
    if (!widget.showNumbersRow || !mounted) return;
    final phase = WidgetsBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks) {
      setState(() {});
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
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
        // The command changed band/mode/freq under `_populating`, which
        // suppressed the field listeners' own rescore — refresh the call-info
        // notices (New Band / New Mode / dupe) for the new radio state.
        _scheduleScore();
      } else if (map.containsKey('updateQso')) {
        final params = (map['updateQso'] as Map).cast<String, dynamic>();
        setState(() {
          _currentQsoExtra.addAll(params);
        });
      } else if (map.containsKey('addQso')) {
        final params = (map['addQso'] as Map).cast<String, dynamic>();
        final qso = await widget.qsosRepository.add(widget.operation.uuid, params);
        widget.onLogged?.call(qso);
        // Command-added QSOs (e.g. SEED's batch) carry at most the fast
        // offline guess the extension attached itself — queue each for a
        // full online lookup in the background.
        widget.enqueueLookup?.call(qso);
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
      } else if (map['devSplash'] is Map) {
        await widget.onCommandAction?.call('devSplash');
      } else if (map['devOnboard'] is Map) {
        await widget.onCommandAction?.call('devOnboard');
      } else if (map['reloadDataFiles'] is Map) {
        await widget.onCommandAction?.call('reloadDataFiles', (map['reloadDataFiles'] as Map).cast<String, dynamic>());
      } else if (map['toggleExperiment'] is Map) {
        await widget.onCommandAction?.call('toggleExperiment', (map['toggleExperiment'] as Map).cast<String, dynamic>());
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
    // Guessed values ride along as faint placeholders (the FormRenderer maps a
    // field's `placeholder` to poloFieldDecoration's hintText) — same "guess as
    // a hint, never a pre-filled value" behaviour as the primary Grid/State.
    final guess = _currentGuess;
    return {
      'title': widget.qsoEditFormTitle ?? 'Edit QSO',
      'elements': [
        {'type': 'field', 'key': 'theirCall', 'fieldType': 'callsign', 'label': widget.theirCallLabel ?? 'Their call'},
        {'type': 'field', 'key': 'theirName', 'fieldType': 'text', 'label': widget.theirNameLabel ?? 'Name', 'placeholder': guess?['name'] as String?},
        {'type': 'field', 'key': 'theirGrid', 'fieldType': 'text', 'label': widget.theirGridLabel ?? 'Grid', 'uppercase': true, 'placeholder': guess?['grid'] as String?},
        {'type': 'field', 'key': 'theirState', 'fieldType': 'text', 'label': widget.theirStateLabel ?? 'State', 'uppercase': true, 'placeholder': guess?['state'] as String?},
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
      labels: widget.formLabels ?? FormRendererLabels.english,
      formDefinition: _buildQsoEditFormDefinition(),
      initialState: {
        'theirCall': _call,
        // Entered name only (not the `theirName` getter, which coalesces in the
        // guess) so a guessed-only name shows as the placeholder above instead
        // of being pre-filled — and merely viewing the pane never promotes a
        // passive guess to a sticky entered value.
        'theirName': _theirNameOverride ?? (widget.editingQso?.data['their'] as Map<String, dynamic>?)?['name'] as String? ?? '',
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

  /// Applies an interpret() result (or an [_onInterpretationUpdate] push) to
  /// the retained/displayed state — describe preview or error only, never
  /// `commands`: dispatching those is [_log]'s job alone, gated on the user
  /// actually pressing Enter, not on a command merely being interpreted.
  void _applyInterpretationResult(Map<String, dynamic>? result) {
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
  }

  /// A command hook pushed a later interpretation for an input it was
  /// already asked to interpret (issue #189) — see [LoggingControls.
  /// interpretationUpdates]'s doc. Applied only while `input` still matches
  /// the live call field; a push for input the user has since typed past is
  /// silently dropped, same staleness idiom [_onCallChanged]'s own debounce
  /// callback uses for its awaited result.
  void _onInterpretationUpdate(Map<String, dynamic> event) {
    if (!mounted || widget.editingQso != null) return;
    if (event['input'] != _commandInput) return;
    final interpretation = (event['interpretation'] as Map?)?.cast<String, dynamic>();
    _applyInterpretationResult(interpretation);
  }

  /// Alphanumeric length of the call about to be logged — the call-info panel
  /// and its live scoring switch on at ≥3 characters (issue #40).
  int get _callInfoAlnumLength => _callAtCursor.replaceAll(RegExp('[^A-Z0-9]'), '').length;
  bool get _callInfoActive => _callInfoAlnumLength >= 3;

  /// Clears the live scoring notices — on wipe/reset/populate, or when the
  /// call drops below the call-info threshold.
  void _clearScoreNotices() {
    _scoreDebounce?.cancel();
    if (_scoreFor == null && _scoreAlertKeys.isEmpty && _scoreNoticeKeys.isEmpty) return;
    _scoreFor = null;
    _scoreAlertKeys = const [];
    _scoreNoticeKeys = const [];
  }

  /// (Re)schedules a debounced live-scoring pass for the call-info notices
  /// line — call/band/mode all feed New Band / New Mode / New DXCC / Dupe, so
  /// this is fired whenever any of them changes (and when an existing QSO is
  /// selected for editing). Debounced on the same 300ms as the offline lookup,
  /// so the scoring pills land alongside the offline lookup's data rather than
  /// lagging it. No-op (and clears) below the call-info threshold or with no
  /// `scoreQso` wired.
  void _scheduleScore() {
    final scoreFn = widget.scoreQso;
    if (scoreFn == null) return;
    _scoreDebounce?.cancel();
    final activeCall = _callAtCursor;
    // Only score a plausible callsign — the same gate the lookup uses. Without
    // it, command input ("RELOAD", "NOTE hi") and non-callsign junk would each
    // fire a whole-log getQsos read in the runtime for nothing.
    if (!_callInfoActive || !looksLikeCallsign(activeCall)) {
      setState(_clearScoreNotices);
      return;
    }
    _scoreDebounce = Timer(const Duration(milliseconds: 300), () async {
      final result = await scoreFn(
        operation: _operationDataForCommands,
        qso: _getCurrentQsoData(callOverride: activeCall),
        excludeUuid: widget.editingQso?.uuid,
      );
      if (!mounted || _callAtCursor != activeCall) return; // stale — the active call moved on
      setState(() {
        _scoreFor = activeCall;
        _scoreAlertKeys = ((result?['alerts'] as List?) ?? const []).whereType<String>().toList();
        _scoreNoticeKeys = ((result?['notices'] as List?) ?? const []).whereType<String>().toList();
      });
    });
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

    // Live scoring for the call-info notices line — independent of the lookup
    // and command paths below, so schedule it before their early returns.
    _scheduleScore();

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
        _applyInterpretationResult(result);
      });
    }

    _scheduleLookup();
  }

  /// Schedules the debounced callsign lookup for the active call. Split out of
  /// `_onCallChanged` so it can also be re-run when the QSO's refs change — a
  /// hunted POTA/SOTA ref feeds the POTA/SOTA `lookup` hooks, changing what the
  /// lookup resolves. See `_relookupForRefsChanged`.
  void _scheduleLookup() {
    _lookupDebounce?.cancel();
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

    // Already looked up this call this session — show it instantly, no refetch.
    if (_lookupCache.containsKey(activeCall)) {
      setState(() {
        _lookupFor = activeCall;
        _lookupResult = _lookupCache[activeCall];
      });
      unawaited(_refreshActivityControlsFor(activeCall));
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
      _lookupCache[activeCall] = offlineResult;
      setState(() {
        _lookupFor = activeCall;
        _lookupResult = offlineResult;
      });
      _logLookup('offline', activeCall, offlineResult);
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
      _lookupCache[activeCall] = onlineResult;
      setState(() {
        _lookupFor = activeCall;
        _lookupResult = onlineResult;
      });
      _logLookup('online', activeCall, onlineResult);
    });
  }

  /// Structured dev event (#237) for a resolved call lookup — a compact summary
  /// of the guess so agents can watch `[lookup]` in the console / recentLog().
  void _logLookup(String phase, String call, Map<String, dynamic>? result) {
    DevLog.instance.log('lookup', {
      'call': call,
      'phase': phase,
      'name': result?['name'],
      'grid': result?['grid'],
      'entity': result?['entityName'],
      'source': result?['matchSource'] ?? result?['source'],
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

  // ---- Logging ----

  /// Escape wipes the compose form, but must not blank the read-only view
  /// of a staged-delete or deleted QSO — the fields are the record's only
  /// display and can't be repopulated without reselecting it. When editing
  /// an existing QSO, it discards any unsaved changes and ends the editing
  /// session entirely (ham2k/app-halo-dist#199) — via [onEscapeDeselect]
  /// rather than [onEditCanceled] directly, so the caller can offer to undo
  /// it (Revert only discards changes and stays in edit mode; this is the
  /// "never mind, close it" gesture). When composing a new QSO it goes
  /// through the wipe button's path, so the 5-second undo offer applies to
  /// Esc too. With nothing composed and no wipe left to undo, a second
  /// Escape asks the caller if *it* has something to undo instead — a QSO
  /// this same gesture just deselected (issue #199 follow-up) — before
  /// finally wiping (a no-op on an already-empty form).
  void _handleEscape() {
    if (_fieldsLocked) return;
    if (widget.editingQso != null) {
      (widget.onEscapeDeselect ?? widget.onEditCanceled)?.call();
    } else if (_hasComposedValues) {
      _handleWipeTap();
    } else if (_wipeUndoSlot.value != null) {
      _restoreFromUndoSlot();
    } else if (widget.onUndoDeselect?.call() ?? false) {
      // handled — a deselected QSO was restored by the caller
    } else {
      _wipe();
    }
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
    _clearScoreNotices();
    _lookupCache.clear();
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
    _wipeUndoSlot.set(_getCurrentQsoData(), onExpire: () {
      if (mounted) setState(() {});
    });
    _wipe();
  }

  void _restoreFromUndoSlot() {
    final data = _wipeUndoSlot.take();
    if (data == null) return;
    _populating = true;
    _applyFieldsFromData(data);
    _manualStartAtMillis = data['startAtMillis'] as int?;
    setState(() => _updateClockTicker());
    _populating = false;
    // _populating suppressed _onCallChanged's own _scheduleLookup()/
    // _scheduleScore() calls above (population isn't the user typing) —
    // the wipe this undoes already cleared the lookup cache and score
    // notices, so a restored call would otherwise sit there unlooked-up
    // and without its dupe/New-* pills until the user edited the field
    // themselves.
    _scheduleLookup();
    _scheduleScore();
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
      widget.onQsoUndeleted?.call(editingQso);
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
      if (_wipeUndoSlot.value != null) {
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
    // #236: stable id for agent/browser tooling. Named for its default role
    // (Wipe) even though it also serves Undo/Delete/Restore/Revert — it's the
    // one secondary action slot, and the dev bridge drives it as `wipe`.
    return semanticId('action.wipe', SizedBox(
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
    ));
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
        // A confirm-clear timer from a previous command would wipe this
        // message moments after it appears — the error owns the slot now.
        _executeMessageTimer?.cancel();
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

          // A command can also fail at execute time (e.g. SOLAR/WEATHER's
          // network fetch, or the hook timing out entirely — see
          // interpretCommand) — surface the message and keep the typed
          // input, same treatment as the preview-time `error` branch above,
          // including cancelling any pending confirm-clear timer that would
          // otherwise wipe the error moments after it appears.
          if (executable['error'] is String) {
            _executeMessageTimer?.cancel();
            setState(() {
              _commandMessage = executable['error'] as String;
            });
            _notifyCommandMessage(_commandMessage);
            return;
          }

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
        widget.onQsoDeleted?.call(editingQso);
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
          widget.enqueueLookup?.call(qso);

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
          'their': {
            if (keepOriginal) ...?(baseData['their'] as Map<String, dynamic>?),
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
            data: dataFor(calls.first, 0),
          ),
        );
        for (var i = 1; i < calls.length; i++) {
          // The base data carries the edited QSO's own uuid (baseData came
          // from its record) — strip it so add() generates a fresh one for
          // this new QSO instead of colliding with the original.
          final data = dataFor(calls[i], i)..remove('uuid');
          final qso = await widget.qsosRepository.add(widget.operation.uuid, data);
          widget.onLogged?.call(qso);
          widget.enqueueLookup?.call(qso);
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
          final qso = await widget.qsosRepository.add(widget.operation.uuid, dataFor(calls[i], i));
          widget.onLogged?.call(qso);
          widget.enqueueLookup?.call(qso);
        }
        _wipe();
      }

      // A single rescoring pass after the whole batch, not a score check per
      // call — the on-screen scoring pills already only ever reflect the
      // cursor's own call (see `_scheduleScore`/`_callAtCursor`).
      if (isList) widget.onCallListLogged?.call();
    } finally {
      _isLogging = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    _scheduleSubmitButtonMeasurement();
    // Push the current call-info up to the host (Info tab / modal) after this
    // build settles, so it never setStates a parent mid-build.
    if (widget.onCallInfoChanged != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notifyCallInfo();
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

    // Bump a monotonic generation whenever the info area's displayed content
    // changes, and key the AnimatedSwitcher by it below. A content-derived key
    // that can repeat (stats→call→stats) would collide with a still-fading
    // outgoing child of the same key and crash the switcher's Stack; a
    // never-repeating generation can't. Identical content (e.g. the stats
    // line's 1 Hz tick) leaves the signature unchanged, so it updates in place.
    final infoSignature = _infoAreaSignature(fieldsLocked: fieldsLocked, deletedQso: deletedQso);
    if (infoSignature != _lastInfoSignature) {
      _lastInfoSignature = infoSignature;
      _infoGeneration++;
    }

    final panel = CallbackShortcuts(
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
                // panel's dark area. Left/right add the real device inset
                // (ham2k/app-halo-dist#205) — SecondaryControlRow's own
                // `horizontalBleed` stays keyed to the fixed
                // `_secondaryPanelHorizontalInset` only, so its expanded
                // panel still stops short of the physical edge by that
                // device inset instead of bleeding into it.
                padding: PaneSafeArea.symmetricOf(context, horizontal: _secondaryPanelHorizontalInset)
                    .add(const EdgeInsets.only(bottom: 8)),
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
                            expandTooltip: widget.expandControlsTooltip,
                            collapseTooltip: widget.collapseControlsTooltip,
                            // The dupe warning (and the other scoring notices)
                            // now live on the info area's third line — see
                            // `_buildInfoArea` (issue #40).
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // A min-height container: at least the second edit
                      // button's own diameter (see _buildWipeOrEditButton) so a
                      // one-line info area can't leave the button overflowing
                      // upward into the secondary control chips above, but free
                      // to grow taller for the call-info panel's up-to-three
                      // lines (issue #40).
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(minHeight: _editButtonDiameter ?? 44),
                            child: SizedBox(
                              width: double.infinity,
                              // Reserves room for the button positioned on
                              // top of this box (below), so text truncates
                              // before it rather than rendering underneath.
                              child: Padding(
                              padding: EdgeInsets.only(right: (_editButtonDiameter ?? 44) + 8),
                              // Top-aligned, with the height animating as the
                              // content grows/shrinks and content swaps
                              // cross-fading (issue #40). AnimatedSize drives the
                              // height; AnimatedSwitcher fades between distinct
                              // states, keyed by a signature that's stable
                              // across the stats line's 1 Hz tick.
                              child: AnimatedSize(
                                duration: const Duration(milliseconds: 120),
                                curve: Curves.easeOut,
                                alignment: Alignment.topLeft,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 120),
                                  layoutBuilder: (currentChild, previousChildren) => Stack(
                                    alignment: Alignment.topLeft,
                                    children: [
                                      ...previousChildren,
                                      if (currentChild != null) currentChild,
                                    ],
                                  ),
                                  child: KeyedSubtree(
                                    key: ValueKey(_infoGeneration),
                                    child: fieldsLocked
                                        ? _buildLockedWarning(theme, deletedQso)
                                        : (_callInfoActive && widget.onCallInfoTap != null)
                                            // Tap the call-info area to open the
                                            // detail panel (modal on narrow).
                                            ? GestureDetector(
                                                behavior: HitTestBehavior.opaque,
                                                onTap: widget.onCallInfoTap,
                                                child: _buildInfoArea(accentTheme),
                                              )
                                            : _buildInfoArea(accentTheme),
                                  ),
                                ),
                              ),
                            ),
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
                            // #236: stable id for agent/browser tooling.
                            child: semanticId('field.call', TextField(
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
                              // In command free-text modes (mixedCase /
                              // expectsParams) a space is a literal parameter
                              // character, so the interceptor is deliberately
                              // absent there — only normal callsign mode routes
                              // Space to focus/command handling.
                              inputFormatters: _commandMixedCase
                                  ? null
                                  : _commandExpectsParams
                                      ? const [UpperCaseTextFormatter()]
                                      : [
                                          _virtualSpace,
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'[a-zA-Z0-9/.,]'),
                                          ),
                                          if (isMobilePlatform) MobileDotToSlashFormatter(),
                                          const UpperCaseTextFormatter(),
                                        ],
                              style: _primaryFieldStyle(context, fontWeight: FontWeight.w500),
                              decoration: _primaryFieldDecoration(context, widget.theirCallLabel ?? 'Their call'),
                              onSubmitted: (_) => _log(),
                            )),
                          ),
                          if (widget.showRSTFields) ...[
                            const SizedBox(width: 10),
                            _fixedField(
                              context,
                              controller: _sentController,
                              focusNode: _sentFocus,
                              enabled: !fieldsLocked,
                              label: widget.sentLabel ?? 'Sent',
                              // Letters are legitimate in RSTs (CW's "5NN"
                              // shorthand, aurora "59A") and the Edit QSO
                              // pane accepts them — a digits-only filter
                              // here would silently strip a pane-saved
                              // letter on the next keystroke, since
                              // filtering formatters re-run over the whole
                              // text.
                              keyboardType: _numbersAndPunctuationOnIOS,
                              filter: FilteringTextInputFormatter.allow(RegExp(r'[0-9a-zA-Z+\-]')),
                              onChanged: (_) => _rstsTouched = true,
                            ),
                            const SizedBox(width: 8),
                            _fixedField(
                              context,
                              controller: _rcvdController,
                              focusNode: _rcvdFocus,
                              enabled: !fieldsLocked,
                              label: widget.rcvdLabel ?? 'Rcvd',
                              // Same letter-friendly rule as Sent above.
                              keyboardType: _numbersAndPunctuationOnIOS,
                              filter: FilteringTextInputFormatter.allow(RegExp(r'[0-9a-zA-Z+\-]')),
                              onChanged: (_) => _rstsTouched = true,
                            ),
                          ],
                          if (widget.showStateField) ...[
                            const SizedBox(width: 10),
                            _fixedField(
                              context,
                              controller: _stateController,
                              focusNode: _stateFocus,
                              enabled: !fieldsLocked,
                              label: widget.theirStateLabel ?? 'State',
                              textCapitalization: TextCapitalization.characters,
                              // The guessed state (e.g. from a callsign lookup)
                              // shows as a faint placeholder while the field is
                              // empty — never pre-filled as a real value.
                              hintText: _currentGuess?['state'] as String?,
                              onChanged: (_) => _stateTouched = true,
                            ),
                          ],
                          if (widget.showGridField) ...[
                            const SizedBox(width: 10),
                            _fixedField(
                              context,
                              controller: _gridController,
                              focusNode: _gridFocus,
                              enabled: !fieldsLocked,
                              label: widget.theirGridLabel ?? 'Grid',
                              textCapitalization: TextCapitalization.characters,
                              hintText: _currentGuess?['grid'] as String?,
                              onChanged: (_) => _gridTouched = true,
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
                          // #236: stable id for agent/browser tooling.
                          semanticId('action.log', AspectRatio(
                            key: _submitButtonKey,
                            aspectRatio: 1,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: FilledButton(
                                // Disabled while viewing a deleted QSO —
                                // there's nothing to save; restore first.
                                // `_hasExecutableCommand` lets the button
                                // accept a command too, matching Enter (a
                                // command isn't a callsign, so `_canLog` alone
                                // would leave it disabled — see that getter).
                                onPressed: (!deletedQso && (_pendingDelete || _canLog || _hasExecutableCommand))
                                    ? _log
                                    : null,
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
                          )),
                        ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // The numbers row, when a field has focus and the keyboard is
              // up (mobile only). See `_shouldShowNumbersRow`.
              if (_shouldShowNumbersRow(context))
                _buildNumberKeys(accentTheme),
              // Reserve space at the bottom so the fields (and numbers row)
              // clear whatever is down there — the Scaffold no longer resizes
              // for the keyboard, it extends full height so each pane fills
              // behind it, and the status footer no longer reserves the home
              // indicator globally. That's the larger of the keyboard inset and
              // the bottom safe area (a MAX — the keyboard covers the indicator
              // when up). The spacer takes the numbers row's colour when it's
              // showing (so the row reads as continuing behind the keyboard);
              // otherwise it's the panel's own background (Material above), so
              // the home-indicator strip matches the panel.
              if (_bottomReserve > 0)
                SizedBox(
                  width: double.infinity,
                  height: _bottomReserve,
                  child: _shouldShowNumbersRow(context)
                      ? ColoredBox(
                          color: accentTheme.appBarTheme.backgroundColor ?? accentTheme.colorScheme.primary,
                        )
                      : null,
                ),
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
    return FocusScope(child: panel);
  }

  /// Rebuilds when the on-screen keyboard opens or closes. The operation
  /// Scaffold no longer resizes for the keyboard (it extends full height so
  /// each pane paints its own bottom) — this panel keeps its own fields above
  /// it with a bottom spacer (see build), whose height tracks the keyboard.
  /// `didChangeMetrics` is the trigger: the raw view inset ([_keyboardInset])
  /// has no MediaQuery dependency to rebuild on.
  @override
  void didChangeMetrics() {
    if (isMobilePlatform && mounted) setState(() {});
  }

  /// The on-screen keyboard's height in logical pixels, or 0 off mobile /
  /// keyboard down. Read from the raw `FlutterView` (see [virtualKeyboardIsUp]).
  /// The panel reserves this much at its bottom so the fields and numbers row
  /// stay above the keyboard.
  double get _keyboardInset {
    if (!isMobilePlatform) return 0;
    final view = View.of(context);
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  /// The bottom safe area (home indicator) in logical pixels, or 0 off mobile
  /// / on a device without one. Read from the raw `FlutterView` like
  /// [_keyboardInset]; `viewPadding` (unlike `MediaQuery.padding`) keeps the
  /// indicator's height even while the keyboard is up, which is why the two
  /// combine as a MAX.
  double get _bottomSafeInset {
    if (!isMobilePlatform) return 0;
    final view = View.of(context);
    return view.viewPadding.bottom / view.devicePixelRatio;
  }

  /// How much to reserve below the fields: the keyboard when it's up, the home
  /// indicator when it's down (see the spacer in build).
  double get _bottomReserve => math.max(_keyboardInset, _bottomSafeInset);

  /// Whether to show the mobile numbers row right now — the setting is on,
  /// we're on a phone/tablet, the QSO isn't a read-only (staged/already
  /// deleted) view, the on-screen keyboard is up, and one of our logging
  /// fields actually holds the focus (issue #27).
  bool _shouldShowNumbersRow(BuildContext context) {
    return widget.showNumbersRow &&
        isMobilePlatform &&
        !_fieldsLocked &&
        virtualKeyboardIsUp(context) &&
        _focusedNumberField != null;
  }

  Widget _buildNumberKeys(ThemeData theme) {
    return NumberKeys(
      onKey: _handleNumberKey,
      extraKey: _numbersRowExtraKey,
      vibrate: widget.vibrateNumbersRow,
      // The AppBar/footer colour — the app's chrome — deliberately NOT the
      // editing-swappable tertiary/secondary accent, so the row reads as
      // chrome in every mode. (appBarTheme isn't remapped by the editing
      // accent, so `theme` here being the accent theme is fine.)
      backgroundColor: theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary,
      foregroundColor: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary,
    );
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
    final result = _lookupResult;
    final liveGuess = (result != null && _lookupFor == _callAtCursor)
        ? (result['guess'] as Map<String, dynamic>? ?? const {})
        : null;

    Map<String, dynamic>? savedGuess;
    final editing = widget.editingQso;
    if (editing != null) {
      final their = editing.data['their'] as Map<String, dynamic>?;
      final savedCall = (their?['call'] as String?)?.toUpperCase();
      if (savedCall != null && savedCall == _callAtCursor && their?['guess'] is Map) {
        savedGuess = (their!['guess'] as Map).cast<String, dynamic>();
      }
    }

    if (liveGuess != null && savedGuess != null) return {...savedGuess, ...liveGuess};
    return liveGuess ?? savedGuess;
  }

  /// The call-info panel's line 2: a callsign note (issue #17), which takes the
  /// slot outright and renders as markdown, else the plain name. Null when the
  /// guess has neither.
  ({String text, bool isNote})? _stationNameOrNote(Map<String, dynamic>? guess) {
    if (guess == null) return null;
    final note = guess['note'] as String?;
    if (note != null && note.isNotEmpty) return (text: note, isNote: true);
    final name = guess['name'] as String?;
    if (name != null && name.isNotEmpty) return (text: name, isNote: false);
    return null;
  }

  /// The info area has three states (issue #40): a command message (markdown)
  /// takes priority; otherwise, once a callsign of ≥3 letters/digits is in the
  /// field, the call-info panel; otherwise the operation-statistics default.
  Widget _buildInfoArea(ThemeData theme) {
    final message = _commandMessage;
    if (message != null) {
      return MarkdownBody(
        data: message,
        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
          p: theme.textTheme.bodyMedium?.copyWith(
            // The info area sits on the panel's tertiaryContainer fill.
            color: theme.colorScheme.onTertiaryContainer,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    if (_callInfoActive) return _buildCallInfo(theme);
    return _buildOperationStats(theme);
  }

  /// AnimatedSwitcher key for the info area — changes when the DISPLAYED
  /// content changes (mode, lookup result, notices), but is stable across the
  /// stats line's 1 Hz clock tick, so only real content changes cross-fade.
  String _infoAreaSignature({required bool fieldsLocked, required bool deletedQso}) {
    if (fieldsLocked) return 'locked:$deletedQso';
    if (_commandMessage != null) return 'message'; // message text updates in place
    // Coarse on purpose: only the call itself keys the cross-fade. Lookup and
    // score results stream in as in-place updates (no switch), so the panel
    // fills smoothly instead of flashing empty between passes.
    if (_callInfoActive) return 'call:$_callAtCursor';
    return 'stats'; // stable across the ticker
  }

  /// The read-only warning shown in place of the info area for a staged-delete
  /// or already-deleted QSO (ham2k/app-halo-dist#59).
  Widget _buildLockedWarning(ThemeData theme, bool deletedQso) {
    return Row(
      children: [
        Icon(resolveIconName('alert'), size: 16, color: theme.colorScheme.error),
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
    );
  }

  /// Default state: operation statistics (QSO count, rates) from the app
  /// layer's `operationStatsLines`, behind a timer icon. Refreshes live via
  /// the panel's 1 Hz clock ticker while composing (see `_updateClockTicker`).
  Widget _buildOperationStats(ThemeData theme) {
    final lines = widget.operationStatsLines?.call(widget.qsos) ?? const <String>[];
    if (lines.isEmpty) return const SizedBox.shrink();
    return _iconRows(
      theme,
      // Filled icon in the same accent as the main buttons (tertiary, or
      // secondary while editing — see `accentTheme`).
      icon: resolveIconName('timer-outline'),
      iconColor: theme.colorScheme.tertiary,
      children: [
        for (final line in lines)
          Text(
            line,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onTertiaryContainer),
          ),
      ],
    );
  }

  /// Call-info state: line 1 flag + location, line 2 note/name, line 3 scoring
  /// notices — all in a column aligned past the leading person icon.
  Widget _buildCallInfo(ThemeData theme) {
    // When editing an existing QSO, hold the panel's data until scoring has run
    // (`_scoreFor == _callAtCursor`), so the saved lookup and the pills appear
    // together in one update — otherwise the lookup text renders first and the
    // pills pop in a moment later. Composing streams in as the user types.
    final ready = widget.editingQso == null || widget.scoreQso == null || _scoreFor == _callAtCursor;
    final guess = ready ? _currentGuess : null;
    final flag = guess?['flag'] as String?;
    final location = guess == null ? null : widget.callLocationLine?.call(guess);
    final nameInfo = _stationNameOrNote(guess);
    final notices = ready ? _scoringNotices() : const <({String label, bool alert})>[];

    // Line 1: optional flag, then the location slot — which is always present
    // (a blank space when there's no location) so the line keeps a consistent
    // height whether or not a location resolved.
    final firstLine = <Widget>[
      if (flag != null && flag.isNotEmpty) ...[
        Text(flag, style: theme.textTheme.bodyMedium?.copyWith(shadows: _glyphGlow(theme))),
        const SizedBox(width: 6),
      ],
      Expanded(
        child: Text(
          (location != null && location.isNotEmpty) ? location : ' ',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onTertiaryContainer),
        ),
      ),
    ];

    // Always render the panel (at least the person icon + the reserved first
    // line) once a call is active, so the lookup and score data fill it in
    // place rather than the panel flashing between empty and full — the switcher
    // keys only on the call, so this whole subtree updates without a re-fade.
    return _iconRows(
      theme,
      // Filled icon in the same accent as the main buttons (tertiary, or
      // secondary while editing — see `accentTheme`).
      icon: resolveIconName('account'),
      iconColor: theme.colorScheme.tertiary,
      children: [
        // Line 1 — flag + distance/location (blank until the lookup resolves),
        // keeping the pills and note on the second line even before it appears.
        Row(children: firstLine),
        // Line 2 (+ 3 when they don't fit): scoring pills and the note/name.
        if (nameInfo != null || notices.isNotEmpty) _buildNoticesAndNote(theme, notices, nameInfo),
      ],
    );
  }

  /// Shared layout for the stats and call-info states: a top-aligned leading
  /// icon with a column of lines to its right (which naturally indents lines 2+
  /// past the icon, per issue #40's "align past the icon" requirement).
  Widget _iconRows(
    ThemeData theme, {
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    // No Align: the info-area container top-left-aligns and animates this
    // (see the AnimatedSize/AnimatedSwitcher in build).
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ],
    );
  }

  /// The lookup entries backing the current call-info — live results when
  /// available, else the entries saved on the QSO being edited (`their.lookups`,
  /// which carry the call-notes `notes` array the merge doesn't fold into
  /// `guess`).
  List<Map<String, dynamic>> get _currentLookups {
    final live = (_lookupResult?['lookups'] as List?)?.whereType<Map<String, dynamic>>().toList();
    if (live != null && _lookupFor == _callAtCursor) return live;
    final their = widget.editingQso?.data['their'] as Map<String, dynamic>?;
    return (their?['lookups'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? const [];
  }

  /// The current call-info payload for the detail panel, or null when the
  /// call-info panel isn't showing.
  CallInfoData? get _currentCallInfoData {
    // Mirror the compact area's priority: a command message wins over call-info.
    if (!_callInfoActive || _commandMessage != null) return null;
    final fresh = _scoreFor == _callAtCursor;
    return CallInfoData(
      call: _callAtCursor,
      guess: _currentGuess,
      lookups: _currentLookups,
      alertKeys: fresh ? _scoreAlertKeys : const [],
      noticeKeys: fresh ? _scoreNoticeKeys : const [],
      isEditing: widget.editingQso != null,
    );
  }

  /// Pushes the current call-info up to the host (deduped) — the Info tab's
  /// detail panel mirrors it. Called post-build so it never setStates a parent
  /// mid-build.
  String? _lastCallInfoSig;
  void _notifyCallInfo() {
    if (widget.onCallInfoChanged == null) return;
    final data = _currentCallInfoData;
    final g = data?.guess;
    final sig = data == null
        ? null
        : '${data.call}|$_lookupFor|${data.isEditing}|${g?['name']}|${g?['grid']}|${g?['image']}|${g?['note']}'
            '|${data.alertKeys.join(",")}|${data.noticeKeys.join(",")}';
    if (sig == _lastCallInfoSig) return;
    _lastCallInfoSig = sig;
    widget.onCallInfoChanged!(data);
  }

  /// The scoring notices for the call-info line — from the scoring hook only
  /// (dupe included: whether a QSO is a dupe depends on the operation's
  /// activities, which the hook knows and a client-side check can't). Alerts
  /// (red) first, then notices (green); each carries its localized label.
  List<({String label, bool alert})> _scoringNotices() {
    if (_scoreFor != _callAtCursor) return const [];
    final labelOf = widget.scoreNoticeLabel ?? (key) => key;
    return [
      for (final key in _scoreAlertKeys) (label: labelOf(key), alert: true),
      for (final key in _scoreNoticeKeys) (label: labelOf(key), alert: false),
    ];
  }

  /// Line 2 (and, when it doesn't fit, line 3): the scoring pills and the
  /// note/name. When pills + note fit the available width, the pills lead and
  /// the note trails on one line; otherwise the note takes line 2 and the pills
  /// stack below on line 3 (measured with a TextPainter — the app scales at the
  /// root, so logical-pixel measurements match what's painted).
  Widget _buildNoticesAndNote(
    ThemeData theme,
    List<({String label, bool alert})> notices,
    ({String text, bool isNote})? nameInfo,
  ) {
    final pillsRow = <Widget>[
      for (var i = 0; i < notices.length; i++) ...[
        if (i > 0) const SizedBox(width: 4),
        _noticePill(theme, notices[i].label, alert: notices[i].alert),
      ],
    ];
    final note = nameInfo == null ? null : _buildNoteOrName(theme, nameInfo);

    if (notices.isEmpty) return note ?? const SizedBox.shrink();
    if (note == null) return Row(children: pillsRow);

    return LayoutBuilder(
      builder: (context, constraints) {
        final pillStyle = theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600);
        final noteStyle = theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
        var pillsWidth = 0.0;
        for (var i = 0; i < notices.length; i++) {
          pillsWidth += _measureTextWidth(notices[i].label, pillStyle) + 12; // 6px h-padding each side
          if (i > 0) pillsWidth += 4; // inter-pill gap
        }
        final noteWidth = _measureTextWidth(_stripMarkdownForWidth(nameInfo!.text), noteStyle);
        const gap = 8.0;

        if (pillsWidth + gap + noteWidth <= constraints.maxWidth) {
          // Fits: pills lead, note trails.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [...pillsRow, const SizedBox(width: gap), Flexible(child: note)],
          );
        }
        // Doesn't fit: note on its own line, pills stacked below.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [note, const SizedBox(height: 3), Row(children: pillsRow)],
        );
      },
    );
  }

  double _measureTextWidth(String text, TextStyle? style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  /// Rough plain-text of markdown for width estimation — unwraps `[text](url)`
  /// links and drops emphasis markers so the estimate matches the rendered text.
  static String _stripMarkdownForWidth(String s) => s
      .replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m[1] ?? '')
      .replaceAll(RegExp(r'[*_`~]'), '');

  /// A soft halo behind small glyphs (the call-info flag/note emoji, the
  /// spotting control's source-status icons) so they stay legible against a
  /// tinted fill — white on light themes, dark on dark themes.
  List<Shadow> _glyphGlow(ThemeData theme) {
    final color = theme.brightness == Brightness.dark ? Colors.black : Colors.white;
    return [Shadow(color: color.withValues(alpha: 0.6), blurRadius: 6)];
  }

  /// The leading emoji cluster of a call note — call notes always prefix their
  /// emoji (see the call-notes extension's `combineNotes`), so isolating this
  /// run lets the glow ride only the emoji, not the note's prose. Covers the
  /// common pictographic ranges plus ZWJ / variation-selector / keycap /
  /// regional-indicator (flag) code points; deliberately not exhaustive.
  static final _leadingEmoji = RegExp(
    r'^[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{1F1E6}-\u{1F1FF}\u{200D}\u{FE0F}\u{20E3}]+',
    unicode: true,
  );

  /// Line 2 of the call-info panel: the plain name, or the note rendered as
  /// markdown with its leading emoji cluster glowed (emoji only, not the prose).
  Widget _buildNoteOrName(ThemeData theme, ({String text, bool isNote}) info) {
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onTertiaryContainer,
      fontWeight: FontWeight.w600,
    );
    if (!info.isNote) {
      return Text(info.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: textStyle);
    }

    final leadMatch = _leadingEmoji.firstMatch(info.text);
    final rest = leadMatch == null ? info.text : info.text.substring(leadMatch.end).trimLeft();
    final markdown = rest.isEmpty
        ? null
        : MarkdownBody(
            data: rest,
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: textStyle,
              // A link blue tuned per theme so the note's socials/URLs read
              // clearly on the panel's fill — darker on light, lighter on dark.
              a: TextStyle(
                color: theme.brightness == Brightness.dark ? Colors.blue.shade200 : Colors.blue.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          );

    if (leadMatch == null) return markdown ?? const SizedBox.shrink();

    // Leading emoji (glowed) + the rest of the note (markdown, no glow).
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(leadMatch.group(0)!, style: textStyle?.copyWith(shadows: _glyphGlow(theme))),
        if (markdown != null) ...[
          const SizedBox(width: 4),
          Flexible(child: markdown),
        ],
      ],
    );
  }

  Widget _noticePill(ThemeData theme, String label, {required bool alert}) {
    // Alerts are the error color; notices a positive green (matching app-polo's
    // red/green pill convention) — the panel's own tertiaryContainer fill rules
    // out relying on the neutral scheme containers for contrast.
    final background = alert ? theme.colorScheme.error : const Color(0xFF2E7D32);
    final foreground = alert ? theme.colorScheme.onError : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(3)),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
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

/// Routes a space typed on an on-screen keyboard to [onSpace] — the same
/// handler the panel's hardware Space shortcut ([_LoggingControlsState._handleSpace])
/// uses to rotate focus / run call-field command shortcuts.
///
/// A virtual keyboard sends a space as a text edit, not a key event, so the
/// panel's `SingleActivator(LogicalKeyboardKey.space)` never fires for it: the
/// space is instead inserted (State/Grid, which allow it) or silently stripped
/// by a field's character filter (Call/Sent/Rcvd/Freq). Either way Space
/// couldn't rotate focus on mobile. This formatter, placed first, drops a lone
/// inserted space and invokes the shared handler after the edit resolves.
///
/// On a hardware keyboard the shortcut consumes the key before it reaches text
/// input, so this never triggers there — the two paths don't double-fire.
class _VirtualSpaceFormatter extends TextInputFormatter {
  final VoidCallback onSpace;

  const _VirtualSpaceFormatter(this.onSpace);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // Only a genuine single-space insertion at the cursor — not a paste that
    // merely contains a space, and not a selection replacement.
    if (newValue.text.length == oldValue.text.length + 1) {
      final caret = newValue.selection.end;
      if (caret > 0 &&
          caret <= newValue.text.length &&
          newValue.text[caret - 1] == ' ' &&
          newValue.text.substring(0, caret - 1) + newValue.text.substring(caret) == oldValue.text) {
        // Deferred: mutating focus or a controller synchronously from inside a
        // formatter (mid-text-input) is unsafe. The microtask runs right after
        // this edit applies and before the next frame.
        scheduleMicrotask(onSpace);
        return oldValue;
      }
    }
    return newValue;
  }
}
