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

import 'flags.dart';
import 'form_renderer.dart';
import 'icon_resolver.dart';
import 'keyboard_dismiss.dart';
import 'logging_controls_controller.dart';
import 'mdi_icons.dart';
import 'number_keys.dart';
import 'option_matching.dart';
import 'platform_chrome.dart';
import 'resizable_split_view.dart' show PaneSafeArea;
import 'semantic_id.dart';
import 'ref_text_input.dart';
import 'secondary_control_row.dart';
import 'text_formatters.dart';
import 'theme.dart';
import 'timed_undo_slot.dart';
import 'wall_clock.dart';

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

/// Applies a command's `CommandAction`s. This widget's own dispatcher is the
/// only one that can service the QSO-scoped fields — `setVfo`, `addQso`,
/// `updateQso`, `setCallField`, `sendSpots` all need the live in-progress QSO
/// and controllers — so it hands this out via
/// [LoggingControls.onDispatcherChanged] for callers outside the logging
/// panel (the ⌘K command dialog) to route through instead of reimplementing.
typedef CommandActionsDispatcher = Future<void> Function(
  List<dynamic> actions, {
  bool skipOnlineLookup,
});

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
  List<Map<String, dynamic>>? segments,
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

/// The floating pills a `kind: 'options'` exchange field offers. Named because a
/// focused TextField carries a `CompositedTransformFollower` of its own for
/// selection handles, so "the follower" is ambiguous without it.
const exchangeSuggestionsKey = ValueKey('exchange.suggestions');

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
  /// QSO — single calls, comma-list entries, and stacked ("//") calls — but
  /// never for the record being edited (its stored data is deliberately left
  /// alone) and never for command actions (e.g. SEED), which batch through
  /// [enqueueAllLookups] instead. The queue itself skips QSOs that already
  /// carry online lookup data (e.g. a single call whose debounced preview
  /// resolved before Enter), so handing over everything is safe and lets a
  /// fast Enter that beat the preview still get enriched.
  ///
  /// Deliberately silent in the caller's status bar — a single Enter's own
  /// lookup shouldn't flash a "Callsign lookups" bar for one QSO, even when
  /// several land close together.
  final void Function(Qso qso)? enqueueLookup;

  /// Hands every QSO added by a single command action to the caller's
  /// background lookup queue as one batch, fired once all of a command's
  /// `addQso` actions have been dispatched. Reuses the same always-on
  /// status-bar progress as the explicit "Lookup all QSOs" action, since a
  /// command batch is exactly that kind of bulk insert. Skipped entirely
  /// when the command's interpretation set `skipOnlineLookup` — SEED does,
  /// since its QSOs are fabricated test data and only ever carry the
  /// offline-only guess `lookupGuessFor` already attached extension-side.
  final void Function(Iterable<Qso> qsos)? enqueueAllLookups;

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

  /// Last chance for an activity to shape a QSO before it is written, via the
  /// extension runtime's `processQsoBeforeSave` — a contest mirroring the
  /// exchange it keeps on its own ref into the generic `their.exchange` that
  /// the QSO row and a plain ADIF export read.
  ///
  /// Applied on EVERY save path (single, call list, call stack, edit), because
  /// a QSO decorated only when logged one way would export differently
  /// depending on how it was entered. When null the data is saved as-is.
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> qso)? decorateQsoBeforeSave;

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

  /// Called with this widget's action dispatcher when it mounts, and with
  /// null when it goes away, so a command typed somewhere else (the ⌘K
  /// dialog) can be applied to the live logging panel exactly as if it had
  /// been typed into the call field. See [CommandActionsDispatcher].
  final void Function(CommandActionsDispatcher?)? onDispatcherChanged;

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

  /// Arrow Up on a secondary control pill walks off the top of this panel —
  /// the caller (which owns the QSO list and its selection) takes the
  /// keyboard from there. Unset means the panel is the top of the ladder and
  /// Up simply stops at the pills. See APP-19.
  final VoidCallback? onNavigateToQsoList;

  /// Settings engine interface.
  final SyncSettings? settings;

  /// Holds the radio's VFO state (`vfoA`) — device-global, shared by every
  /// operation, not scoped to this one. Used to seed the Radio control for
  /// a new QSO instead of resetting to a hardcoded default, and as the
  /// destination for its edits. When null, the Radio control behaves as it
  /// did before this state existed — purely local to this widget.
  final VfoStore? radioService;

  /// Fires when [radioService]'s state changes — so the Radio control can
  /// follow a connected rig (GATO), or any other writer, live.
  ///
  /// Separate from [radioService] rather than folded into it because
  /// `VfoStore` lives in pure-Dart halo_core, which has no Flutter
  /// dependency and therefore no `Listenable`. In the app both are the same
  /// object (`RadioService`); when null the control behaves as it always
  /// did, reading the VFO only when it seeds.
  final Listenable? radioUpdates;

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

  /// Accessible names for the secondary control row's grid expand/collapse
  /// caret (icon-only, and the app has no hover tooltips).
  final String? expandControlsLabel;
  final String? collapseControlsLabel;

  /// Localized chrome for the "More" full-edit pane's form renderer
  /// (Cancel/Save buttons, close button, error prefixes — see
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
    this.enqueueAllLookups,
    this.activityControls = const [],
    this.refreshActivityControls,
    this.decorateQsoBeforeSave,
    this.decorateRef,
    this.interpretCommand,
    this.interpretationUpdates,
    this.onCommandMessageChanged,
    this.onCommandAction,
    this.onDispatcherChanged,
    this.editingQso,
    this.suggestedQso,
    this.onEditCanceled,
    this.onNavigateToQsoList,
    this.settings,
    this.radioService,
    this.radioUpdates,
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
    this.expandControlsLabel,
    this.collapseControlsLabel,
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

  /// The operator has typed a frequency the VFO hasn't been told about
  /// yet, so their intent is newer than anything the VFO reports. Set on a
  /// real edit, cleared whenever the field and the VFO are back in sync
  /// (pushed to it, or seeded from it).
  ///
  /// Deliberately not a focus check: `_onSelectControl` focuses the
  /// frequency field when the Radio control is expanded, so refusing to
  /// follow while focused would refuse exactly when the operator is
  /// watching the radio.
  bool _freqTouched = false;

  /// The frequency text as of the last notification — the baseline that
  /// tells a real edit from a bare cursor move. Same idiom, and the same
  /// reason, as `_lastTimeDateText`.
  String _lastFreqText = '';
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

  /// The operation resolved into its segments. `widget.qsos` is the whole log,
  /// which is what carries the `break`/`start` event rows; an unsegmented
  /// operation resolves to a single segment that is its own data, unchanged.
  SegmentedOperation get _segmented =>
      SegmentedOperation.from(operation: widget.operation.data, qsos: widget.qsos);

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
      for (final ref in ((current['refs'] as List?) ?? const []).whereType<Map>())
        if (ref['type'] case final String type) type,
    };
  }

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

  /// Whether the call field is currently taking spaces as literal characters
  /// rather than as "next field". The single source of truth for that question:
  /// the field's `inputFormatters` pick the space-accepting interceptor on
  /// exactly this condition, and `_handleSpace` decides the double-space exit
  /// on it, so the two can't drift into disagreeing about which mode the field
  /// is in.
  bool get _fieldAcceptsSpaces => _commandMixedCase || _commandExpectsParams;

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

  /// Values typed into `kind: 'text'` activity controls (contest exchanges),
  /// keyed by control key. Kept apart from [_controlRefs] because several text
  /// controls can share one `refType` while writing different `field`s of it —
  /// they're merged back into one ref per type on save.
  final Map<String, String> _controlTextValues = {};

  /// One controller per text control, created on demand and disposed with the
  /// widget.
  final Map<String, TextEditingController> _controlTextControllers = {};

  /// Text controls the operator has actually typed into. A `suggestedValue`
  /// from a callsign lookup fills a field only while it is untouched, so a
  /// lookup resolving late can never clobber what someone already keyed in
  /// (docs/design/contests.md §5.3).
  final Set<String> _touchedTextControls = {};

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
    return _effectiveActivityControls.where((c) {
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

  /// The exchange options a `kind: 'options'` control declares, parsed once per
  /// build from the descriptor. Malformed entries are dropped rather than
  /// crashing the entry row — options cross the bridge from third-party code.
  List<ExchangeOption> _optionsFor(Map control) => [
        for (final raw in ((control['input'] as Map?)?['options'] as List?) ?? const [])
          if (raw is Map)
            if (ExchangeOption.fromMap(raw.cast<String, dynamic>()) case final option?) option,
      ];

  /// The `kind: 'options'` control that currently has focus, if any.
  ///
  /// Read straight from the focus map rather than tracked in state: the
  /// suggestion line and the SPACE handler then compute from the same inputs at
  /// the same moment, so neither can act on a stale copy of the other's idea of
  /// what the operator is looking at. `_controlTextFocus[key]` is read without
  /// creating a node, so this never conjures one for a field that hasn't built.
  Map<String, dynamic>? get _focusedOptionsControl {
    for (final control in _textControls) {
      if ((control['input'] as Map?)?['kind'] != 'options') continue;
      if (_controlTextFocus[control['key']]?.hasFocus == true) return control;
    }
    return null;
  }

  /// Suggestions for the focused options field, best first — empty when no
  /// options field has focus, the set is empty, or it declares a
  /// `minCharsForSuggestions` the operator hasn't reached.
  ///
  /// Cheap by construction: the set is inline in the descriptor (§5.3's
  /// `optionSet` was deferred for want of a consumer big enough to need it), so
  /// this is a list scan and not a query.
  /// Set by Escape and cleared by the next keystroke, a focus change or an
  /// accept: "I've seen the offer, get it out of the way".
  ///
  /// Not a per-value memory on purpose. The operator dismissed THIS offer, and
  /// typing another character is a new question — anything longer-lived would
  /// have them wondering why the menu stopped coming back.
  bool _optionsMenuDismissed = false;

  List<ExchangeOption> get _optionSuggestions {
    if (_optionsMenuDismissed) return const [];
    final control = _focusedOptionsControl;
    if (control == null) return const [];
    final input = control['input'] as Map;
    final options = _optionsFor(control);
    if (options.isEmpty) return const [];

    final typed = _controlTextValues[control['key']] ?? '';
    final minChars = input['minCharsForSuggestions'];
    if (minChars is int && typed.trim().length < minChars) return const [];

    final matchOn = {
      for (final m in (input['matchOn'] as List?) ?? const ['code', 'name'])
        if (m is String) m,
    };
    return matchExchangeOptions(
      typed,
      options,
      matchOn: matchOn.isEmpty ? const {'code', 'name'} : matchOn,
      preferred: [
        for (final c in (input['preferredCodes'] as List?) ?? const [])
          if (c is String) c,
      ],
    );
  }

  /// Which suggestion the operator has walked to with the arrow keys, or null
  /// while they haven't touched the selection.
  ///
  /// Null is not the same as 0. An untouched selection means Space is still just
  /// "next field" and the accept is a GUESS on the app's part, so it is held to
  /// the prefix rule below; once the operator has moved the highlight, or tapped
  /// a row, they have chosen, and what they chose is taken as-is.
  int? _optionSelection;

  /// Index into [_optionSuggestions] of the highlighted row.
  int _selectedOptionIndex(int length) => length == 0 ? 0 : (_optionSelection ?? 0).clamp(0, length - 1);

  void _moveOptionSelection(int delta) {
    final suggestions = _optionSuggestions;
    if (suggestions.isEmpty) return;
    final current = _selectedOptionIndex(suggestions.length);
    final next = (current + delta).clamp(0, suggestions.length - 1);
    // An arrow that CANNOT move the highlight is not a choice. The menu is drawn
    // best-at-the-bottom, so ↓ from an untouched selection is already at the end
    // of the list (as is either arrow on a one-row menu): nothing moves on
    // screen. Arming "the operator chose this" on a keystroke with no visible
    // effect let the next Space rewrite what they typed with a match the prefix
    // rule exists to refuse — type `SH`, press ↓, press Space, and the field
    // became `ASD`, a county nobody worked.
    if (next == current && _optionSelection == null) return;
    setState(() => _optionSelection = next);
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
    if (_optionSelection != null && _acceptOptionSuggestion(explicit: true)) {
      setState(() {});
      return;
    }
    _log();
  }

  /// Writes a suggestion into the focused options field, as though it had been
  /// typed. Returns false when there was nothing to accept.
  ///
  /// [index] names the row (a tap); otherwise the highlighted one. [explicit]
  /// marks a choice the operator made — a tap, or Space after arrowing — which
  /// skips the prefix guard that keeps a plain Space from swapping in a
  /// substring match.
  ///
  /// Two traps this has to cover. A controller write does NOT fire `onChanged`,
  /// so `_controlTextValues` and the touched set are updated by hand — the same
  /// trap the numbers row documents. And on mobile the space arrives through
  /// `_VirtualSpaceFormatter`, which rejects the edit and schedules this in a
  /// microtask, so it must be safe to run when the field already holds the
  /// value: accepting the same code twice is a no-op rather than a second
  /// write.
  bool _acceptOptionSuggestion({int? index, bool explicit = false}) {
    final control = _focusedOptionsControl;
    if (control == null) return false;
    final suggestions = _optionSuggestions;
    if (suggestions.isEmpty) return false;

    final key = control['key'] as String;
    final typed = _controlTextValues[key] ?? '';
    final chosen = suggestions[(index ?? _selectedOptionIndex(suggestions.length)).clamp(0, suggestions.length - 1)];

    if (!explicit) {
      // Nothing typed, nothing to accept. An empty field's suggestion list is the
      // whole SET (`matchExchangeOptions` answers an empty query with everything
      // in declaration order), so without this, Space in an empty exchange field
      // — which is just how an operator skips past one they haven't been given
      // yet — logged whichever park happened to be declared first.
      if (typed.trim().isEmpty) return false;
      // And only a suggestion the typed text is the START of: accepting a
      // substring hit replaces what they typed with something it isn't a prefix
      // of. See `isAcceptableExchangeMatch`.
      final input = control['input'] as Map;
      final matchOn = {
        for (final m in (input['matchOn'] as List?) ?? const ['code', 'name'])
          if (m is String) m,
      };
      if (!isAcceptableExchangeMatch(typed, chosen, matchOn: matchOn.isEmpty ? const {'code', 'name'} : matchOn)) {
        return false;
      }
    }

    if (typed == chosen.code) return false;

    _controlTextValues[key] = chosen.code;
    _textControllerFor(key).text = chosen.code;
    _touchedTextControls.add(key);
    // The menu closes on the accepted value, so the highlight it belonged to
    // goes with it.
    _optionSelection = null;
    return true;
  }

  /// The serial number each `kind: 'serial'` control will send, as last peeked
  /// from the sequence — shown so the operator can read it off while typing the
  /// callsign, but NOT written to the QSO: the number is allocated at commit
  /// (docs/design/contests.md §5.8), so a peek that goes stale (another window
  /// logged in between) costs nothing.
  final Map<String, int> _serialPreviews = {};

  /// The sequences this operation's contests declared, resolved from the
  /// current controls. Passed to `add` so the repository can allocate against
  /// the QSO as committed — and so a number the operator was shown raises the
  /// counter past itself rather than being handed out twice.
  List<SequenceDescriptor> get _serialSequences => [
        for (final control in _textControls)
          if (_serialDescriptorFor(control) case final descriptor?) descriptor,
      ];

  /// Runs `widget.decorateQsoBeforeSave` if wired, so an activity can project
  /// its ref data into generic QSON fields. Identity when no callback is
  /// supplied, which is every test and tooling path.
  Future<Map<String, dynamic>> _decorated(Map<String, dynamic> data) async {
    final decorate = widget.decorateQsoBeforeSave;
    if (decorate == null) return data;
    return decorate(data);
  }

  /// [refs] with every declared serial field removed, so the sequence issues a
  /// fresh number at commit instead of the one already on the ref. Only for the
  /// second and later calls of a call list — see `dataFor`.
  List<Map<String, dynamic>> _refsWithoutSerials(Object? refs) {
    final descriptors = _serialSequences;
    final list = [
      for (final ref in (refs as List?) ?? const [])
        if (ref is Map) ref.cast<String, dynamic>(),
    ];
    if (descriptors.isEmpty) return list;
    return [
      for (final ref in list)
        {
          ...ref,
        }..removeWhere((field, _) => descriptors.any((d) => d.refType == ref['type'] && d.field == field)),
    ];
  }

  SequenceDescriptor? _serialDescriptorFor(Map<String, dynamic> control) {
    final key = control['key'] as String? ?? '';
    final slash = key.indexOf('/');
    return SequenceDescriptor.fromInput(
      (control['input'] as Map).cast<String, dynamic>(),
      // Control keys are `<extensionKey>/<name>` by convention; the prefix is
      // what keeps two contests' counters apart.
      extensionKey: slash > 0 ? key.substring(0, slash) : key,
    );
  }

  /// What the previews were last computed against — which sequences exist, and
  /// the band/mode a scoped one keys off. The parent hands down a fresh
  /// controls list on most rebuilds, so without this the peek would re-query
  /// the log every frame.
  String? _serialPreviewSignature;

  /// Refreshes the previewed next number for each serial control — one query
  /// per sequence, and only when the declarations or their scope changed.
  ///
  /// Never while editing an existing QSO. That record's number was sent long
  /// ago and is restored from the ref by `_applyFieldsFromData`; the sequence's
  /// *next* number has nothing to do with it. Filling it here would overwrite a
  /// logged serial on a record that merely had its RST corrected, or invent one
  /// for a QSO that never carried a contest ref at all.
  Future<void> _refreshSerialPreviews() async {
    final sequences = widget.qsosRepository.sequences;
    if (sequences == null || widget.editingQso != null) return;

    final data = _getCurrentQsoData();
    final descriptors = <String, SequenceDescriptor>{};
    for (final control in _textControls) {
      final descriptor = _serialDescriptorFor(control);
      if (descriptor != null) descriptors[control['key'] as String] = descriptor;
    }

    final signature = '${descriptors.keys.join(',')}|${data['band']}|${data['mode']}';
    if (signature == _serialPreviewSignature && _serialPreviews.isNotEmpty) return;
    _serialPreviewSignature = signature;
    if (descriptors.isEmpty) return;

    final qso = Qso(uuid: '', operationUuid: widget.operation.uuid, data: data);
    var changed = false;
    for (final entry in descriptors.entries) {
      final next = await sequences.peek(widget.operation.uuid, entry.value.requestFor(qso));
      if (_serialPreviews[entry.key] == next) continue;
      _serialPreviews[entry.key] = next;
      changed = true;
      // The preview fills the field itself so the number is readable at a
      // glance, but the control stays untouched — only a number the operator
      // actually edits overrides the commit-time allocation.
      if (!_touchedTextControls.contains(entry.key)) {
        _controlTextValues[entry.key] = '$next';
        _textControllerFor(entry.key).text = '$next';
      }
    }
    if (changed && mounted) setState(() {});
  }

  TextEditingController _textControllerFor(String key) =>
      _controlTextControllers[key] ??= TextEditingController(text: _controlTextValues[key] ?? '');

  /// One focus node per text control, so Space and Tab cycle through the
  /// exchange fields the same way they cycle Call → Sent → Rcvd.
  final Map<String, FocusNode> _controlTextFocus = {};

  /// One per exchange field, so the `options` suggestion pills can be anchored
  /// to the field they belong to rather than to the panel. Keyed the same way as
  /// the controllers and focus nodes, and just as long-lived.
  final Map<String, LayerLink> _controlTextLinks = {};

  LayerLink _textLinkFor(String key) => _controlTextLinks[key] ??= LayerLink();

  /// A node per exchange field, created on first build, listened to, and given a
  /// key handler for Tab.
  ///
  /// The listener is what makes the `options` suggestion menu appear: the menu is
  /// derived from which field has focus, and focus alone rebuilds nothing. On a
  /// new QSO the panel is repainting anyway (the callsign is being typed), which
  /// is why this looked like it worked — but on an existing QSO opened for
  /// editing, tabbing into a searchable exchange showed no offer at all while
  /// Space would still have rewritten the field.
  FocusNode _textFocusFor(String key) => _controlTextFocus[key] ??= (FocusNode(
        debugLabel: 'exchange:$key',
        onKeyEvent: _onExchangeKeyEvent,
      )..addListener(() {
        _notePrimaryFocus(_controlTextFocus[key]!);
        // Same cursor-at-end-on-focus rule the fixed primary fields get in
        // initState — an exchange field is a main logging field too, and
        // `selectAllOnFocus: false` alone only stops the select-all; it leaves
        // the caret wherever it happened to be last.
        if (_controlTextFocus[key]!.hasFocus) {
          final controller = _textControllerFor(key);
          controller.selection = TextSelection.collapsed(
            offset: _takePendingCaretOffset(_controlTextFocus[key]!, controller) ?? controller.text.length,
          );
        }
        // A dismissal and a highlight both belong to the field that had focus
        // when they were made, so leaving or entering a field clears them.
        if (mounted) {
          setState(() {
            _optionsMenuDismissed = false;
            _optionSelection = null;
          });
        }
      }));

  /// Tab out of an exchange field takes the offer on the way, exactly as Space
  /// does — leaving the field forward is the same statement either way, and an
  /// operator who tabs rather than spaces shouldn't lose the suggestion for it.
  ///
  /// Shift+Tab is going BACK, so it takes nothing: it isn't leaving the field
  /// behind, it is stepping away from a field the operator may be about to
  /// return to.
  ///
  /// On the node itself rather than as a panel-wide shortcut: binding Tab in
  /// `CallbackShortcuts` would take it away from Flutter's traversal for the
  /// whole panel, which would then have to be reimplemented here. This only
  /// ADDS the accept, then hands the event to [_onPrimaryFieldKeyEvent] — an
  /// exchange is a main logging field, so it gets the same edge-wrap and arrow
  /// traversal as the rest, and everything those two decline stays with the
  /// ordinary traversal.
  KeyEventResult _onExchangeKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.tab &&
        !HardwareKeyboard.instance.isShiftPressed) {
      // Same reading of the highlight as Space: an untouched one is still the
      // app guessing, and stays held to the prefix rule.
      if (_acceptOptionSuggestion(explicit: _optionSelection != null)) setState(() {});
    }
    return _onPrimaryFieldKeyEvent(node, event);
  }

  void _clearTextControls() {
    _controlTextValues.clear();
    _touchedTextControls.clear();
    // Dropped, not kept: a wipe must let the next refresh re-fill the serial
    // fields, and the change-detection in `_refreshSerialPreviews` would
    // otherwise see the same declarations and leave them blank.
    _serialPreviews.clear();
    _serialPreviewSignature = null;
    for (final controller in _controlTextControllers.values) {
      controller.clear();
    }
    unawaited(_refreshSerialPreviews());
  }

  /// Applies each text control's `suggestedValue` — a callsign-lookup-derived
  /// prefill — to fields the operator hasn't touched. Called when the controls
  /// are re-fetched after a lookup resolves.
  void _applySuggestedTextValues() {
    for (final control in _textControls) {
      final key = control['key'] as String;
      if (_touchedTextControls.contains(key)) continue;
      final suggested = (control['input'] as Map)['suggestedValue'] as String?;
      if (suggested == null || suggested.isEmpty) continue;
      if (_controlTextValues[key] == suggested) continue;
      _controlTextValues[key] = suggested;
      _textControllerFor(key).text = suggested;
    }
  }

  /// Merges the text controls' values into one ref per `refType`, folded in
  /// with any ref of that type already held by a refList control — so a
  /// contest's exchange and its refList-entered references coexist.
  List<Map<String, dynamic>> _refsWithTextValues(List<Map<String, dynamic>> refs) {
    if (_textControls.isEmpty) return refs;

    // Values to write, and — separately — fields to REMOVE. An emptied field
    // has to be an active removal, not just an absent value: skipping it would
    // leave the old exchange on the ref, so clearing one while editing a QSO
    // wouldn't stick. Same reasoning as the unconditional `refs`/`freq` writes
    // in `_getCurrentQsoData`.
    final byType = <String, Map<String, dynamic>>{};
    final clearedByType = <String, Set<String>>{};
    for (final control in _textControls) {
      final input = control['input'] as Map;
      final refType = input['refType'] as String?;
      final field = input['field'] as String?;
      if (refType == null || field == null) continue;
      final key = control['key'] as String;
      // A serial's displayed number is NOT a suggestion — it is what the
      // operator read off the screen and sent on the air, so it is written to
      // the ref exactly like something typed. Nobody re-keys it, and the log
      // must agree with what went out. (The sequence is what guarantees the
      // number was theirs to send; see `SequencesRepository`.)
      final value = (_controlTextValues[key] ?? '').trim();
      if (value.isEmpty) {
        // An empty field means one of two different things, and a contest has
        // to be able to tell them apart: it either was never filled in, or the
        // operator deliberately emptied it. Only the operator touching it
        // distinguishes the two.
        //
        // A DELIBERATE blank is recorded as `field: ''` rather than dropped, so
        // it survives as a decision — `processQsoBeforeSave` stamps a guessed
        // exchange onto an ABSENT field, and would otherwise put back the value
        // the operator just removed (docs/design/contests.md §8).
        //
        // Serials are exempt: the sequence owns the number, "no serial" isn't a
        // thing an operator records, and an empty string on the field would
        // confuse the allocator that reads it at commit.
        if (_touchedTextControls.contains(key) && input['kind'] != 'serial') {
          (byType[refType] ??= {'type': refType})[field] = '';
        } else {
          (clearedByType[refType] ??= {}).add(field);
        }
      } else {
        // A serial is stored as an int, matching what `_withAllocatedSerial`
        // writes — normalized HERE so the edit path agrees, since
        // `QsosRepository.update` deliberately never allocates and so never
        // passes through that method.
        (byType[refType] ??= {'type': refType})[field] =
            input['kind'] == 'serial' ? (int.tryParse(value) ?? value) : value;
      }
    }
    if (byType.isEmpty && clearedByType.isEmpty) return refs;

    final merged = <Map<String, dynamic>>[];
    for (final ref in refs) {
      final type = ref['type'];
      final extra = byType.remove(type);
      final cleared = clearedByType[type];
      if (extra == null && cleared == null) {
        merged.add(ref);
        continue;
      }
      final next = {...ref, ...?extra};
      for (final field in cleared ?? const <String>{}) {
        next.remove(field);
      }
      // A ref left with nothing but its type carried no information to begin
      // with — drop it rather than persisting an empty shell.
      if (next.length > 1 || next['ref'] != null) merged.add(next);
    }
    merged.addAll(byType.values);
    return merged;
  }

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

  /// The call field's variant for command free-text mode, where a space is a
  /// parameter character rather than "next field". Without it that mode has no
  /// on-screen-keyboard exit at all: the hardware Space shortcut never fires
  /// for a virtual keyboard, so the double-space would just type a second
  /// literal space and the operator would be stuck in the field.
  late final _VirtualSpaceFormatter _commandVirtualSpace = _VirtualSpaceFormatter(
    _handleSpace,
    shouldIntercept: (old) =>
        old.text.endsWith(' ') && old.selection.isCollapsed && old.selection.baseOffset == old.text.length,
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
    _advancePrimaryFocus();
  }

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
    // Publish the dispatcher while this panel is live, so a command run from
    // the ⌘K dialog lands on THIS logging panel's state.
    widget.onDispatcherChanged?.call(_dispatchActions);
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
    _callController.addListener(_onCallChanged);
    _interpretationUpdatesSub = widget.interpretationUpdates?.listen(_onInterpretationUpdate);
    _freqController.addListener(_onFreqChanged);
    _timeController.addListener(_onTimeOrDateFieldChanged);
    _dateController.addListener(_onTimeOrDateFieldChanged);
    // After the seed above, so the initial state doesn't arrive twice.
    widget.radioUpdates?.addListener(_onRadioVfoChanged);
    // Start in sync with whatever the fields already hold: an initial seed
    // that ran before these listeners existed notified nobody, and an
    // out-of-date baseline reads the first cursor move as an edit.
    //
    // The frequency needs this most: a `suggestedQso` applied above (a spot
    // deeplinked into a cold start) writes the field before this listener
    // exists, so `_onFreqChanged` never fires to move the baseline itself.
    _recordTimeDateText();
    _recordFreqText();
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
          _notePrimaryFocus(focus);
          controller.selection = TextSelection.collapsed(
            offset: _takePendingCaretOffset(focus, controller) ?? controller.text.length,
          );
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
    // Tab's edge-wrap, the arrow keys' end-of-value traversal, and Arrow Up out
    // to the pills, on the fixed primary fields. The exchange fields get the
    // same handler through [_onExchangeKeyEvent], which their nodes are built
    // with; Freq and Time are secondary-control fields and deliberately keep
    // the default (they're a rung up already — their way out is Down/Enter,
    // see [_onExpandedKeyEvent]).
    for (final node in [_callFocus, _sentFocus, _rcvdFocus, _stateFocus, _gridFocus]) {
      node.onKeyEvent = _onPrimaryFieldKeyEvent;
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
    widget.controller?.attach(
      setField: _devSetField,
      submit: _log,
      wipe: _wipe,
      isFieldsLocked: () => _fieldsLocked,
      focusCall: _callFocus.requestFocus,
      focusSecondaryControls: _focusPill,
    );
    // Show the next serial number straight away — an operator opening a WPX
    // operation needs to know where the series stands before the first QSO,
    // not after it.
    unawaited(_refreshSerialPreviews());
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
    // The controls a contest contributes arrive asynchronously, after this
    // widget first builds — so a serial field is typically declared here
    // rather than in initState, and this is where its first preview comes
    // from. The operation's own refs matter just as much, since they decide
    // which primary controls survive `_textControls` at all: adding the
    // activity is what makes the serial field appear. Deliberately outside the
    // editingQso guards below: showing the right number never depends on what
    // is being composed.
    if (!identical(oldWidget.activityControls, widget.activityControls) ||
        !identical(oldWidget.operation.data['refs'], widget.operation.data['refs'])) {
      unawaited(_refreshSerialPreviews());
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach();
      widget.controller?.attach(
        setField: _devSetField,
        submit: _log,
        wipe: _wipe,
        isFieldsLocked: () => _fieldsLocked,
        focusCall: _callFocus.requestFocus,
        focusSecondaryControls: _focusPill,
      );
    }
    // The VFO notifier can be swapped with the widget (a different
    // HaLoServices in a harness, a future per-profile RadioService). Without
    // this the listener stays on the OLD notifier and `dispose` removes it
    // from the new one, so following dies and the old notifier keeps this
    // State alive.
    //
    // Above the editingQso guards below, alongside `controller` and for the
    // same reason: re-subscribing is bookkeeping about which notifier this
    // State is attached to, not something a QSO being edited gets a say in.
    // Below them it simply never ran while an edit was open.
    if (!identical(oldWidget.radioUpdates, widget.radioUpdates)) {
      oldWidget.radioUpdates?.removeListener(_onRadioVfoChanged);
      widget.radioUpdates?.addListener(_onRadioVfoChanged);
    }
    if (oldWidget.editingQso?.uuid != widget.editingQso?.uuid) {
      _resetEditingSessionState();
      if (widget.editingQso != null) {
        _populateFromEditingQso(widget.editingQso!);
      } else {
        _resetLocalFields();
      }
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
    // A suggestion is specific operator intent — "work THIS station" — so
    // unlike the ambient VFO seed it overrides, it moves the VFO, and with
    // a radio connected (GATO) that retunes the radio itself. Tapping a
    // spot is the main way this happens.
    //
    // Only when the suggestion actually carried radio state: a bare
    // callsign (a deeplink, say) must not retune anything. And the push is
    // immediate rather than debounced — the operator picked a specific
    // station, there is nothing more to wait for.
    if (widget.editingQso == null &&
        (data['freq'] != null || data['band'] != null || data['mode'] != null)) {
      _vfoDebounce?.cancel();
      // AFTER the frame, not now. Both callers — initState and
      // didUpdateWidget — run inside the build phase, and `setVfo` notifies
      // its listeners synchronously; SpotsPanel listens and calls setState,
      // which Flutter refuses mid-build ("cannot be marked as needing to
      // build because the framework is already in the process of building
      // widgets"). ErrorPolicy classes that as logOnly, so it costs the
      // operator nothing visible and would have gone unnoticed — but the
      // panel can silently miss its rebuild for that frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pushVfoToRadioService();
      });
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
    _clearTextControls();
    final refs = (data['refs'] as List?)?.whereType<Map>().map((r) => r.cast<String, dynamic>()) ?? const [];
    for (final ref in refs) {
      String? key;
      for (final control in _effectiveActivityControls) {
        final input = control['input'] as Map?;
        if (input?['refType'] != ref['type']) continue;
        // A primary field reads ONE field out of the ref rather than owning the
        // whole ref, and several may share a type — so it never claims the ref,
        // which must still round-trip through a refList control or
        // `_unmatchedRefs`. `serial` counts here exactly as `text` does: it is
        // one field of the ref, and skipping it would both leave the number
        // unrestored and `break` before any sibling field of the same ref
        // (cqwpx declares `ourSerial` before `theirSerial`), silently clearing
        // that sibling on the next save.
        if (input?['kind'] == 'text' || input?['kind'] == 'serial' || input?['kind'] == 'options') {
          final field = input?['field'] as String?;
          // Serials are stored as ints (see `_withAllocatedSerial`), exchanges
          // as strings — read either.
          final raw = field == null ? null : ref[field];
          final value = raw is num ? '$raw' : (raw is String ? raw : '');
          // PRESENT, not non-empty: an explicit `field: ''` is the operator
          // having emptied it on purpose (see `_refsWithTextValues`), and
          // restoring it as touched-but-blank is what keeps a lookup from
          // helpfully filling it back in the moment the record opens.
          if (field != null && ref.containsKey(field)) {
            final controlKey = control['key'] as String;
            _controlTextValues[controlKey] = value;
            _textControllerFor(controlKey).text = value;
            // A value loaded off a saved QSO is what actually went over the
            // air, so it counts as operator input: without this a lookup
            // resolving after the record opens would overwrite it with a
            // suggestion — or, for a serial, the sequence's NEXT number would
            // overwrite the one that was really sent.
            _touchedTextControls.add(controlKey);
          }
          continue;
        }
        key = control['key'] as String?;
        break;
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
  /// [skipFrequency] leaves the frequency field (and its band) alone while
  /// taking the mode: a pending edit is the operator's and newer, but only
  /// as far as the field they are actually typing in.
  void _seedFromRadioService({bool skipFrequency = false}) {
    final vfo = widget.radioService?.vfoA;
    if (vfo == null) return;
    if (!skipFrequency) {
      final freq = vfo.freq;
      final text = freq != null ? fmtFreqInput(freq) : '';
      // Only when it differs: assigning `text` collapses the selection, so an
      // unconditional write would move the caret every time a connected radio
      // restated the frequency it is already on.
      if (_freqController.text != text) _freqController.text = text;
      _recordFreqText();
      _manualBand = freq == null ? vfo.band : null;
      _freqTouched = false;
    }
    if (vfo.mode != null && vfo.mode != _mode) {
      _mode = vfo.mode!;
      // What `_setMode` and the setVfo command both do. Seeding skipped it,
      // so a CW radio left the default RSTs at 59 — invisible until a
      // connected rig started changing the mode on its own.
      if (!_rstsTouched) _applyDefaultRSTs();
    }
  }

  /// The VFO moved underneath us — a connected radio was tuned, or
  /// something else in the app wrote to it. Mirror it into the Radio
  /// control, but never over the operator.
  void _onRadioVfoChanged() {
    if (!mounted) return;
    // An existing QSO's own recorded freq/band/mode always wins; ambient
    // radio state must not rewrite something already logged.
    if (widget.editingQso != null) return;
    final previousBand = _band;
    final previousMode = _mode;
    setState(() {
      // Suppresses `_onFreqChanged`'s push-back. Without it, seeding a
      // value the radio just reported arms the 5s debounce and sends it
      // straight back at the radio, forever.
      final wasPopulating = _populating;
      _populating = true;
      // A pending frequency edit used to suppress the whole seed. That
      // dropped a mode the rig reported meanwhile, and the pending push
      // then sent the panel's stale mode back — taking a rig the operator
      // had just put into CW back out of it, and logging USB at 59.
      _seedFromRadioService(skipFrequency: _freqTouched);
      _populating = wasPopulating;
    });
    // `_populating` above suppressed `_onFreqChanged`'s own rescore, and the
    // mode never had one. The dupe / New Band / New Mode pills are scored
    // against band and mode, so without this a rig retuned at its own front
    // panel left them describing the band the operator has left. Debounced
    // and gated on a plausible callsign, so a spun VFO knob costs nothing.
    if (_band != previousBand || _mode != previousMode) _scheduleScore();
  }

  /// Ends a pending frequency edit at a QSO boundary — logging, wiping, or
  /// an editing session closing.
  ///
  /// `_freqTouched` switches live radio follow off, and nothing else ever
  /// reset it: a partial entry of three characters or fewer arms no
  /// debounce, so the Radio control stopped following the rig for the rest
  /// of the session. A push that is still pending is flushed rather than
  /// dropped — the operator typed it, and the field still shows it.
  ///
  /// [flush] is false on the one caller that runs inside `didUpdateWidget`:
  /// `setVfo` notifies, and a listener calling `setState` during the build
  /// phase is exactly the error class the earlier review turned up. That
  /// caller is discarding the composing form anyway.
  void _settlePendingFreqEdit({bool flush = true}) {
    if (flush && (_vfoDebounce?.isActive ?? false)) {
      _vfoDebounce!.cancel();
      _pushVfoToRadioService();
      return;
    }
    _freqTouched = false;
    _recordFreqText();
  }

  /// Pushes the current freq/band/mode to `widget.radioService` as `vfoA`.
  void _pushVfoToRadioService() {
    widget.radioService?.setVfo('vfoA', freq: _freq, band: _band, mode: _mode);
    // The field and the VFO agree again: not a pending edit, and the
    // baseline moves with it.
    _freqTouched = false;
    _recordFreqText();
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
    // `_freqTouched` outlives this reset otherwise, and live radio follow
    // stays switched off for the rest of the session.
    _settlePendingFreqEdit(flush: false);
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
    _clearTextControls();
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
    widget.onDispatcherChanged?.call(null);
    widget.controller?.detach();
    widget.radioUpdates?.removeListener(_onRadioVfoChanged);
    WidgetsBinding.instance.removeObserver(this);
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
    for (final controller in _controlTextControllers.values) {
      controller.dispose();
    }
    for (final node in _controlRefFocus.values) {
      node.dispose();
    }
    for (final node in _controlTextFocus.values) {
      node.dispose();
    }
    for (final node in _pillFocus.values) {
      node.dispose();
    }
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
    // A TextEditingController notifies on SELECTION changes too, and
    // expanding the Radio control focuses this field (`_expandedFocusFor`),
    // which moves the cursor. Without this guard merely opening the control
    // would look like an edit: live follow would switch itself off, and a
    // pointless push to the radio would be armed. Same trap, and the same
    // fix, as `_onTimeOrDateFieldChanged`.
    //
    // The baseline moves BEFORE the guards below — exactly as
    // `_onTimeOrDateFieldChanged` does it, and for the same reason. A
    // programmatic write (a suggestion, an editing session ending) runs
    // under `_populating`; if the baseline didn't move with it, the next
    // bare cursor click would compare against a stale value, read as an
    // edit, and silently switch live follow off.
    final text = _freqController.text;
    final changed = text != _lastFreqText;
    _lastFreqText = text;
    if (_populating || widget.editingQso != null) return;
    if (!changed) return;
    // The operator's own edit — newer than whatever the VFO says, so live
    // follow must leave it alone until it's been pushed.
    _freqTouched = true;
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
      _freqTouched = false;
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

  /// The primary field the cursor was in most recently, so collapsing a
  /// secondary control puts the operator back where they left off rather than
  /// always at Call. Null until one has been focused at all.
  ///
  /// Tracked continuously, NOT sampled when a chip is tapped: by the time the
  /// tap reaches [_onSelectControl] the field has usually already been blurred
  /// (the app root's TapToDismissEmptyField drops focus on any tap outside a
  /// field), so "which field has focus right now" reads as none and every
  /// collapse fell back to Call.
  FocusNode? _lastPrimaryFocus;

  /// Only [_primaryFocusOrder]'s own nodes reach here — a secondary control's
  /// field (Frequency, Time, a ref) must never become the place we return to.
  void _notePrimaryFocus(FocusNode node) {
    if (_primaryFocusOrder.any((f) => identical(f, node))) _lastPrimaryFocus = node;
  }

  /// One focus node per activity ref control, owned here rather than inside
  /// [RefTextInput] so expanding the control can move the cursor into it —
  /// the field itself is rebuilt on every expand, the node outlives it.
  final Map<String, FocusNode> _controlRefFocus = {};

  FocusNode _refFocusFor(String key) =>
      _controlRefFocus[key] ??= FocusNode(debugLabel: 'ref:$key');

  /// The field a control expands *into* — what the operator opened it to type
  /// in. Null for a control with nothing to type (Spotting with its comment
  /// hidden is just a button; `more` opens a pane instead of expanding), which
  /// leaves focus alone rather than yanking it somewhere useless.
  FocusNode? _expandedFocusFor(String? key) {
    if (key == null) return null;
    switch (key) {
      case 'time':
        return _timeFocus;
      // Frequency, not the Band dropdown: it is the field you actually type
      // into, and on touch platforms the dropdowns refuse focus outright.
      case 'radio':
        return _freqFocus;
      case 'spotting':
        return _spotState.showComment ? _spotCommentFocus : null;
      default:
        // Every remaining control is an extension's. Only `refList` builds a
        // field to focus — the same condition that gave it a chip.
        final control = _effectiveActivityControls
            .where((c) => c['key'] == key && (c['input'] as Map?)?['kind'] == 'refList')
            .firstOrNull;
        return control == null ? null : _refFocusFor(key);
    }
  }

  // ── The focus ladder (APP-19) ─────────────────────────────────────────────
  //
  //     QSO list  ──▲──  secondary pills  ──▲──  main logging fields
  //               ──▼──                   ──▼──
  //
  // Arrow Up walks outward from the fields, Arrow Down walks back in, so the
  // whole panel is reachable without leaving the home row. Every rung hangs
  // its handling off a FocusNode's own `onKeyEvent` rather than the panel-wide
  // `CallbackShortcuts` in `build`: a node handler only sees keys aimed at
  // that rung, while a panel-wide arrow binding would swallow the arrow keys
  // for everything in the panel — including a text field's own caret movement
  // (the same reason the options menu binds its arrows only while it's open).
  //
  // Crossing out of the panel is the host's business, not this widget's:
  // `onNavigateToQsoList` hands the keyboard up, and `LoggingControlsController`
  // hands it back.

  /// One node per secondary control pill, so the keyboard can sit on a pill
  /// the way it sits on a field. Owned here rather than inside
  /// [SecondaryControlRow] so all of the panel's keyboard policy stays in one
  /// place; the row just passes it to the chip. Long-lived — the chips
  /// themselves are rebuilt constantly and animate in and out.
  final Map<String, FocusNode> _pillFocus = {};

  FocusNode _pillFocusFor(String key) => _pillFocus[key] ??= FocusNode(
        debugLabel: 'pill:$key',
        onKeyEvent: (node, event) => _onPillKeyEvent(key, event),
      );

  /// The pill keys on the strip, in display order — recorded by
  /// [_buildSecondaryControls] as it assembles the specs, so the arrow keys
  /// walk exactly what is on screen (hidden controls, an activity that
  /// stopped applying, a reorder from the settings dialog) instead of a
  /// second list that could drift from it.
  List<String> _pillOrder = const [];

  /// The pill the keyboard was last on, so stepping down to a field and back
  /// up returns to where you were rather than to the start of the strip.
  String? _lastPillKey;

  /// Moves the keyboard onto the pill strip — at [key] when given, else the
  /// pill it was last on, else the first. A no-op when there are no pills.
  ///
  /// The strip scrolls horizontally and can hold more pills than fit, so a
  /// focused pill also has to be scrolled into view: focus alone doesn't move
  /// a viewport.
  void _focusPill([String? key]) {
    final order = _pillOrder;
    if (order.isEmpty) return;
    final remembered = _lastPillKey;
    final target = (key != null && order.contains(key))
        ? key
        : (remembered != null && order.contains(remembered) ? remembered : order.first);
    _lastPillKey = target;
    final node = _pillFocusFor(target);
    node.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = node.context;
      if (context == null || !mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    });
  }

  /// Back to the field the operator was last in, with Call as the fallback
  /// for a remembered node whose field is gone (the contest changed, RSTs
  /// were hidden) — such a node has no context and would swallow the request
  /// silently.
  void _focusLastPrimaryField() {
    final remembered = _lastPrimaryFocus;
    ((remembered?.context != null) ? remembered! : _callFocus).requestFocus();
  }

  /// Whether a modifier is held that makes this keystroke somebody else's.
  ///
  /// The ladder claims only bare keys. Cmd/Ctrl/Option combinations are
  /// platform gestures — caret jumps, pane switches, system shortcuts — and
  /// Shift+arrow is a text selection; taking any of them would teleport the
  /// operator instead of doing what they asked. Same rule
  /// [_onPrimaryFieldKeyEvent] applies inside the entry row, kept identical on
  /// purpose so the whole panel answers modifiers the same way.
  static bool get _modified {
    final keyboard = HardwareKeyboard.instance;
    return keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed ||
        keyboard.isShiftPressed;
  }

  KeyEventResult _onPillKeyEvent(String key, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (_modified) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.arrowRight:
        final order = _pillOrder;
        final index = order.indexOf(key);
        // Wraps at both ends: the strip is a short ring, and running off it
        // into the fields would make Left/Right two different gestures
        // depending on where you happened to be standing.
        //
        // With nowhere to go (one pill, or a key that has just left the strip)
        // the keystroke is passed on rather than swallowed — a handler that
        // silently eats keys it does nothing with is how a strip ends up
        // blocking a shortcut nobody remembers binding.
        if (index < 0 || order.length < 2) return KeyEventResult.ignored;
        final delta = event.logicalKey == LogicalKeyboardKey.arrowRight ? 1 : -1;
        _focusPill(order[(index + delta) % order.length]);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        // Off the top of the panel, into the QSO list — when the host has one.
        // Without a host to take it, the pills are simply the top rung.
        widget.onNavigateToQsoList?.call();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _focusLastPrimaryField();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        // Same as a tap: opens the control and puts the cursor in whatever
        // field it expanded into.
        _onSelectControl(key);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        // Same "out of here entirely" meaning Escape has inside an open
        // control, from one rung further out. Handled here rather than left to
        // `_handleEscape` because that one would read a merely-parked keyboard
        // as a cue to wipe the form the operator hasn't touched.
        _focusLastPrimaryField();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Down (or Enter) inside an open secondary control closes it and puts the
  /// keyboard back on its pill — the way out of a control Enter opened.
  ///
  /// This does mean Enter no longer logs the QSO from ANY expanded control's
  /// fields. Every one of them used to log, by one of two routes: the Radio
  /// control's own `onSubmitted`, or — for the activity reference controls and
  /// the spot comment, which declare none — the panel's root Enter shortcut,
  /// which this handler now intercepts below. APP-19 asks for close-first, and
  /// Enter logs again one rung down, from any main field.
  KeyEventResult _onExpandedKeyEvent(String key, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    // Cmd+Down is "caret to the end of the text" on macOS and Shift+Down
    // extends a selection — closing the control on either would take a real
    // editing gesture away from the field the operator is typing in.
    if (_modified) return KeyEventResult.ignored;
    final logicalKey = event.logicalKey;
    if (logicalKey != LogicalKeyboardKey.arrowDown &&
        logicalKey != LogicalKeyboardKey.enter &&
        logicalKey != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    _collapseToPill(key);
    return KeyEventResult.handled;
  }

  /// Closes the open control, leaving the keyboard on its pill rather than
  /// back in the fields (which is where [_onSelectControl]'s own collapse
  /// hands it) — you arrived from the pill, so that's where "back" is.
  ///
  /// Idempotent, because Enter can arrive twice for one keypress: as a key
  /// event, and again through a field's `onSubmitted` once the platform turns
  /// it into a text-input action.
  void _collapseToPill(String key) {
    if (_selectedControlKey != key) return;
    setState(() => _selectedControlKey = null);
    _focusPill(key);
  }

  void _onSelectControl(String? key) {
    if (key == 'more') {
      _openMoreEditor();
      return;
    }
    setState(() {
      if (key == 'time' && _selectedControlKey != 'time') _seedTimeFields();
      _selectedControlKey = key;
    });
    final target = _expandedFocusFor(key);
    if (target != null) {
      // After the frame, not during: the panel's field doesn't exist yet at
      // this point, and a node with no context silently drops the request.
      // (app-polo does the same thing with a 200ms timer; a post-frame
      // callback is the same idea without guessing at a duration.)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedControlKey == key) target.requestFocus();
      });
    }
    if (key == null) {
      // Collapsing hands the cursor back so logging continues without a tap.
      // (Keyboard collapse goes to the pill instead — see `_collapseToPill`.)
      _focusLastPrimaryField();
    }
  }

  /// Shared look for the primary logging row (Their call/Sent/Rcvd) — same
  /// font size and field padding across all three, and the label always
  /// pinned to the top-left corner (not the "large placeholder until
  /// focused" default) so the row's shape doesn't shift as you type. Built
  /// on the app-wide poloFieldDecoration (theme.dart), tinted to read
  /// against this panel's tertiaryContainer background.
  TextStyle _primaryFieldStyle(BuildContext context, {required FontWeight fontWeight}) =>
      haloMonoStyle(context, fontSize: 15, fontWeight: fontWeight);

  /// The underline an exchange field wears while its value isn't one this
  /// contest recognizes. Same weights as the normal borders (1 idle, 2 focused,
  /// matching Material's own focused default), so the tint costs no layout.
  UnderlineInputBorder _invalidUnderline(BuildContext context, {required double width}) =>
      UnderlineInputBorder(
        borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: width),
      );

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
    _recordTimeDateText();
    _populating = wasPopulating;
  }

  /// The time/date text as of the last notification, so a selection-only one
  /// can be told apart from a real edit. Kept current even while [_populating]
  /// — a seeded value that never got recorded here would look like an edit the
  /// next time the cursor moved.
  String _lastTimeDateText = '';

  /// Re-baselines [_lastTimeDateText] after a programmatic write. Needed even
  /// when the write notified (the listener records it anyway) because an
  /// assignment of the SAME text notifies nothing at all — and a seed that
  /// happens before the listeners are attached notifies nobody either.
  void _recordTimeDateText() => _lastTimeDateText = '${_timeController.text} ${_dateController.text}';

  /// Re-baselines the frequency edit detector. Call wherever the field is
  /// written by something other than the operator, or the next bare cursor
  /// move is misread as an edit and live follow switches itself off.
  void _recordFreqText() => _lastFreqText = _freqController.text;

  void _onTimeOrDateFieldChanged() {
    // A TextEditingController notifies on SELECTION changes too, not just
    // text. Focusing a field moves the cursor to the end (see the focus
    // listeners in initState), so without this guard merely EXPANDING the
    // Time control would read its own seeded value back as a manual override:
    // auto-timestamping would freeze and the "Now" button would appear,
    // without the operator typing anything.
    final text = '${_timeController.text} ${_dateController.text}';
    final changed = text != _lastTimeDateText;
    _lastTimeDateText = text;
    if (_populating || !changed) return;
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
    });
  }

  void _resetTimeToNow() {
    setState(() {
      _manualStartAtMillis = null;
      _seedTimeFields();
    });
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
          // `text` controls are primary fields (see `_textControls`), so only
          // refList contributes a secondary chip.
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
    // The strip's keys, for the arrow keys to walk. Recorded from the list
    // actually handed to the row, so the two can't drift apart.
    _pillOrder = [for (final spec in specs) spec.key];
    return [for (final spec in specs) _withKeyboardNavigation(spec)];
  }

  /// Adds this panel's keyboard policy to a control spec: a focus node for its
  /// pill, and a non-focusable ancestor over its expanded content that watches
  /// for the keys which close it again. Applied once, over the assembled list,
  /// so a newly added kind of control can't arrive without it.
  SecondaryControlSpec _withKeyboardNavigation(SecondaryControlSpec spec) => SecondaryControlSpec(
        key: spec.key,
        icon: spec.icon,
        summary: spec.summary,
        liveSummary: spec.liveSummary,
        iconColor: spec.iconColor,
        focusNode: _pillFocusFor(spec.key),
        expandedBuilder: (context) => Focus(
          // Not a stop on the way anywhere: it exists only to see key events
          // on their way up from whatever inside the control has focus.
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: (node, event) => _onExpandedKeyEvent(spec.key, event),
          child: spec.expandedBuilder(context),
        ),
      );

  SecondaryControlSpec _timeControlSpec() => SecondaryControlSpec(
        key: 'time',
        icon: MdiIcons.clockOutline,
        summary: _timeSummary,
        // Live clock only while nothing overrides the timestamp (a manually
        // set time, or editing an existing — necessarily historical — QSO);
        // the chip re-reads this once per second without rebuilding the
        // panel (the old approach — a panel-level ticker calling setState on
        // all of _LoggingControlsState — cost a full panel rebuild per tick).
        liveSummary: _effectiveStartAtMillis == null ? () => _timeSummary : null,
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
                  // Enter closes the control rather than logging (APP-19) —
                  // the same thing `_onExpandedKeyEvent` does with the raw
                  // key, for the platforms where the engine turns Enter into
                  // a text-input action before the framework sees it.
                  onSubmitted: (_) => _collapseToPill('radio'),
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
      // (e.g. a 5-park POTA rove would otherwise be "✓✓✓✓✓ POTA"). The plain
      // check mark (U+2713) has no emoji presentation, so it always renders
      // in the label's own text color instead of a fixed emoji color.
      summary: switch (refCount) {
        0 => label,
        1 => '✓ $label',
        2 => '✓✓ $label',
        _ => '✓×$refCount $label',
      },
      // Accent the icon (issue #187) only once the field actually holds a
      // reference — an active-but-empty control stays the default color.
      iconColor: refCount > 0 ? resolveExtensionColor(control['color'] as String?) : null,
      expandedBuilder: (context) => SizedBox(
        width: 160,
        child: RefTextInput(
          focusNode: _refFocusFor(control['key'] as String),
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

  /// A `kind: 'text'` control rendered as a primary entry field — a contest
  /// exchange, sitting inline with Call and the RSTs.
  ///
  /// A `pattern` mismatch tints the field but never blocks the keystroke:
  /// contest rules don't always anticipate what the other station actually
  /// sends, and refusing input mid-QSO is worse than accepting an oddity.
  Widget _exchangeField(BuildContext context, Map<String, dynamic> control, {required bool enabled}) {
    final key = control['key'] as String;
    final input = control['input'] as Map;
    final label = (control['label'] as String?) ?? key;
    final value = (_controlTextValues[key] ?? '').trim();

    // A serial is digits, never uppercased. The number shown is the one the
    // sequence will issue; typing over it is an override, which the extension
    // can disallow with `editable: false`.
    final isSerial = input['kind'] == 'serial';
    final numeric = input['numeric'] == true || isSerial;

    final regex = compileRefPattern(input['pattern'] as String?);
    var isInvalid = value.isNotEmpty && regex != null && !regex.hasMatch(value);

    // An `options` field validates against its SET as well as any pattern: a
    // county that isn't in the party's list is a lost multiplier, and the
    // operator can still fix it while the QSO is in front of them. A contest
    // whose exchange is genuinely open-ended says `allowFreeform: true`.
    final isOptions = input['kind'] == 'options';
    final options = isOptions ? _optionsFor(control) : const <ExchangeOption>[];
    if (isOptions && value.isNotEmpty && input['allowFreeform'] != true && options.isNotEmpty) {
      isInvalid = isInvalid || !isKnownExchangeOption(value, options);
    }
    final uppercase = !isSerial && input['uppercase'] != false;
    final transforms = [
      for (final t in (input['transforms'] as List?) ?? const [])
        RefTransform.fromMap((t as Map).cast<String, dynamic>()),
    ];

    return SizedBox(
      // Wider than an RST, narrower than the callsign: an exchange is usually
      // a zone, a serial or a state abbreviation.
      width: 76,
      // Linked so the `options` suggestion pills can hang off this field's own
      // top-right corner — they are right-aligned to the field, wherever the
      // row happens to put it (RSTs on or off, a state field, several
      // exchanges).
      child: CompositedTransformTarget(
        link: _textLinkFor(key),
        child: TextField(
        controller: _textControllerFor(key),
        focusNode: _textFocusFor(key),
        selectAllOnFocus: false,
        enabled: enabled,
        readOnly: isSerial && input['editable'] == false,
        style: _primaryFieldStyle(context, fontWeight: FontWeight.w500),
        keyboardType: numeric ? _numbersAndPunctuationOnIOS : null,
        textCapitalization: TextCapitalization.characters,
        autocorrect: false,
        inputFormatters: [
          // FIRST, exactly as every other primary field installs it: on an
          // on-screen keyboard there is no hardware Space to hit the panel
          // shortcut, so without this the space is just swallowed by the
          // formatters below and the field becomes a dead end. Mobile is where
          // most contest logging happens.
          _virtualSpace,
          if (numeric) FilteringTextInputFormatter.digitsOnly,
          if (uppercase) const UpperCaseTextFormatter(),
          if (transforms.isNotEmpty) RefTransformFormatter(transforms),
          if (input['maxLength'] is int) LengthLimitingTextInputFormatter(input['maxLength'] as int),
        ],
        // An unrecognized value tints the field's own underline rather than
        // going through `errorText`. A decorator with an error — even an empty
        // one styled to zero height — still reserves its error slot, which made
        // the field 5px taller and, through the row's IntrinsicHeight, moved
        // every primary control and the submit button DOWN as the operator
        // typed. A contest exchange is invalid for most of the keystrokes it
        // takes to type it, so that was a jump per QSO.
        decoration: _primaryFieldDecoration(context, label).copyWith(
          hintText: input['placeholder'] as String?,
          enabledBorder: isInvalid ? _invalidUnderline(context, width: 1) : null,
          focusedBorder: isInvalid ? _invalidUnderline(context, width: 2) : null,
        ),
        onChanged: (text) {
          setState(() {
            _controlTextValues[key] = text;
            // Once typed, a later lookup-derived suggestion must not overwrite
            // it (docs/design/contests.md §5.3).
            _touchedTextControls.add(key);
            // A new character is a new question: the offer comes back even if
            // the last one was dismissed, and the highlight starts over at the
            // best match rather than pointing at a row that may no longer be
            // in the list.
            _optionsMenuDismissed = false;
            _optionSelection = null;
          });
        },
        onSubmitted: (_) => _handleEnter(),
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
      // A field that accepts literal spaces stays escapable by the
      // double-space, and the test is the SAME one that decides the field
      // accepts them at all (see the call field's inputFormatters) — not the
      // interpretation's flags. There is a third way into free-text mode:
      // _commandExpectsParams' second arm, text that already holds a space.
      // A complete command reached that way ("EXP LA") carries neither
      // `expectsParams` nor `mixedCase`, so keying the exit to those flags
      // advanced focus while leaving the trailing space in the value.
      //
      // Ahead of the interpret round-trip below because the answer never
      // depended on it, and leaving a field shouldn't wait on a bridge call.
      if (_fieldAcceptsSpaces && _atTrailingSpace(_callController)) {
        _removeTrailingSpace(_callController);
        _advancePrimaryFocus();
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
            // The exit gesture was already handled above; anywhere else in the
            // value a space is a literal parameter character.
            _insertAtCursor(_callController, ' ');
            return;
          }
        }
      }

      _advancePrimaryFocus();
    } else if (_freqFocus.hasFocus) {
      _callFocus.requestFocus();
    } else if (_primaryFocusOrder.any((node) => node.hasFocus)) {
      // An options field accepts the highlighted suggestion first, then advances
      // like everything else. The advance is unconditional either way: it is what
      // an operator's hands expect, and losing it to a field that happens to be
      // searchable would be worse than never suggesting at all.
      //
      // Having walked the highlight with the arrow keys IS a choice, so Space
      // then takes that row as-is; an untouched highlight is still the app
      // guessing, and stays held to the prefix rule.
      if (_acceptOptionSuggestion(explicit: _optionSelection != null)) setState(() {});
      // Every primary field advances on Space, contest exchanges included —
      // asked against the same list the advance walks, so a newly added kind of
      // primary field can never end up in one and not the other. (Call and Freq
      // are caught above; neither is reachable here.)
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

  /// The primary fields currently on screen, in the left-to-right order
  /// they're laid out in — Call, Sent/Rcvd (when RST is on), the contest
  /// exchanges, then State/Grid (when their "..." menu toggles are on).
  ///
  /// The single source of truth for what "a primary field" means to the
  /// keyboard: [_advancePrimaryFocus] walks it, `_handleSpace` asks it whether
  /// Space should advance, and [_onPrimaryFieldKeyEvent] reads it for Tab's
  /// edge-wrap and the arrow keys' end-of-value traversal. Any new kind of
  /// primary field is in all of them the moment it appears here — an exchange
  /// field that cycled on Tab but sat inert on Space (because only Space's
  /// caller had a hardcoded list) is exactly the drift this prevents.
  ///
  /// Paired with each field's controller, since Tab and the arrows have to read
  /// the caret and the value, not just move focus.
  ///
  /// Rebuilt on every call: `showRSTFields`/`showStateField`/`showGridField`
  /// change at runtime, and so does the set of contest controls.
  List<(FocusNode, TextEditingController)> get _primaryFields => [
        (_callFocus, _callController),
        if (widget.showRSTFields) (_sentFocus, _sentController),
        if (widget.showRSTFields) (_rcvdFocus, _rcvdController),
        // Only nodes already attached to a built field: creating one here for a
        // control whose widget hasn't been built leaves an orphan with no
        // context, which Flutter's focus traversal null-checks while sorting —
        // taking down the whole frame rather than just misordering focus.
        for (final control in _textControls)
          if (_controlTextFocus[control['key'] as String]?.context != null)
            (
              _controlTextFocus[control['key'] as String]!,
              _textControllerFor(control['key'] as String),
            ),
        if (widget.showStateField) (_stateFocus, _stateController),
        if (widget.showGridField) (_gridFocus, _gridController),
      ];

  /// Just the nodes of [_primaryFields], for the callers that only move focus
  /// and never read a value.
  List<FocusNode> get _primaryFocusOrder => [for (final (node, _) in _primaryFields) node];

  /// Moves focus to the next primary field, wrapping back to Call after the
  /// last one.
  void _advancePrimaryFocus() {
    final order = _primaryFocusOrder;
    final current = order.indexWhere((f) => f.hasFocus);
    final next = order[(current + 1) % order.length];
    next.requestFocus();
  }

  /// Where the next primary field to gain focus should put its caret, and the
  /// node that instruction belongs to.
  ///
  /// Set ONLY for a rightward arrow move — the single path that wants anything
  /// other than the end-of-value default the focus listeners already apply. A
  /// leftward move and both Tab wraps want the end, so they set nothing; an
  /// earlier version wrote `text.length` for them too, which meant Tab onto an
  /// already-focused node (a row with one primary field) left an instruction
  /// nobody collected, and the next field to focus — Frequency, say — took it
  /// and put its caret at 0.
  ///
  /// Keyed to the node because `requestFocus` does NOT deliver focus
  /// synchronously: `FocusManager` applies it on a microtask, so another node
  /// can reach the listeners first.
  ({FocusNode node, int offset})? _pendingCaret;

  /// The pending caret offset for [node], if it is the node the instruction was
  /// meant for.
  ///
  /// Only a PRIMARY field resolves an instruction: Freq and Time share these
  /// focus listeners but are secondary-control fields, so they must neither
  /// consume one nor discard one in passing. Any other primary field arriving
  /// first DOES clear it — by then it is stale, and leaving it set would
  /// misplace the caret the next time its target happened to take focus.
  int? _takePendingCaretOffset(FocusNode node, TextEditingController controller) {
    final pending = _pendingCaret;
    if (pending == null) return null;
    if (!_primaryFocusOrder.any((f) => identical(f, node))) return null;
    _pendingCaret = null;
    return identical(pending.node, node) ? pending.offset.clamp(0, controller.text.length) : null;
  }

  /// Moves focus to [index] in [_primaryFields] (wrapping at either end) and
  /// says where the caret should land — the start of the value for a rightward
  /// move, the end for a leftward one, so the caret keeps travelling in the
  /// direction the arrow key was pushing it.
  void _movePrimaryFocus(int index, {required bool caretAtStart}) {
    final fields = _primaryFields;
    final (node, _) = fields[(index + fields.length) % fields.length];
    // Assigning null on the end-of-value path also clears any instruction left
    // over from a move whose target never arrived.
    _pendingCaret = caretAtStart ? (node: node, offset: 0) : null;
    node.requestFocus();
  }

  /// Tab and the arrow keys inside a main logging field.
  ///
  /// Only the EDGES are intercepted. Tab in the middle of the row, and an arrow
  /// key anywhere but the end of a value, stay with Flutter's own traversal and
  /// caret handling — the entry row is laid out left-to-right in
  /// [_primaryFields]' order, so the default already agrees with us there and
  /// reimplementing it would only be a way to disagree later. What the default
  /// gets wrong is only the two ends: Tab off the last field walks on into the
  /// chips and the Log button, and Shift-Tab off the callsign walks backwards
  /// out of the row entirely. The entry row is a loop, not a waypoint.
  KeyEventResult _onPrimaryFieldKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final fields = _primaryFields;
    final index = fields.indexWhere((f) => identical(f.$1, node));
    // A node that isn't currently a primary field (its control stopped being
    // rendered, say) keeps whatever the platform would do.
    if (index < 0) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    final shift = keyboard.isShiftPressed;
    // Shift is the only modifier that means anything to us (it reverses Tab).
    // Everything else belongs to the platform or the field: Cmd/Option+arrow
    // are line- and word-wise caret moves, and Ctrl+Tab is a pane switch on
    // every desktop — claiming them would take real editing gestures away and
    // teleport the operator to another field instead.
    if (keyboard.isControlPressed || keyboard.isMetaPressed || keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }

    // Arrow Up leaves the row upward, for the secondary control pills — the
    // keyboard-only way out that the Tab loop above deliberately doesn't
    // provide (APP-19). Inert while an options suggestion menu is open, since
    // Up and Down belong to its highlight for as long as it is showing, and
    // while the fields are locked: a staged-delete or deleted QSO's secondary
    // controls are pointer-blocked and dimmed, and the keyboard shouldn't
    // reach past that either.
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_optionSuggestions.isNotEmpty || _fieldsLocked) return KeyEventResult.ignored;
      _focusPill();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.tab) {
      if (!shift && index == fields.length - 1) {
        _movePrimaryFocus(0, caretAtStart: false);
        return KeyEventResult.handled;
      }
      if (shift && index == 0) {
        _movePrimaryFocus(fields.length - 1, caretAtStart: false);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (key != LogicalKeyboardKey.arrowRight && key != LogicalKeyboardKey.arrowLeft) {
      return KeyEventResult.ignored;
    }
    // Shift-arrow is selecting text, and a non-collapsed selection means the
    // arrow collapses it rather than leaving the field. Only a bare caret
    // sitting against an edge is asking to travel.
    if (shift || fields.length < 2) return KeyEventResult.ignored;
    final controller = fields[index].$2;
    final selection = controller.selection;
    if (!selection.isCollapsed || selection.baseOffset < 0) return KeyEventResult.ignored;

    if (key == LogicalKeyboardKey.arrowRight && selection.baseOffset >= controller.text.length) {
      _movePrimaryFocus(index + 1, caretAtStart: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft && selection.baseOffset == 0) {
      _movePrimaryFocus(index - 1, caretAtStart: false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Whether the caret sits at the end of a value that already ends in a space
  /// — the double-space that exits a field which otherwise accepts spaces (see
  /// `_handleSpace`'s free-text branch and [_VirtualSpaceFormatter]).
  static bool _atTrailingSpace(TextEditingController controller) {
    final selection = controller.selection;
    return controller.text.endsWith(' ') &&
        selection.isCollapsed &&
        selection.baseOffset == controller.text.length;
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
        final qso = await widget.qsosRepository.add(widget.operation.uuid, await _decorated(params));
        widget.onLogged?.call(qso);
        // Command-added QSOs (e.g. SEED's batch) carry at most the fast
        // offline guess the extension attached itself as part of adding
        // them — collected here for a single trailing enqueueAllLookups
        // call once the whole batch of actions has been dispatched.
        addedQsos.add(qso);
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
    if (addedQsos.isNotEmpty && !skipOnlineLookup) {
      widget.enqueueAllLookups?.call(addedQsos);
    }
  }

  /// [callOverride] lets call stacking (_pickStackedCall) supply the one
  /// segment it picked out of the "//"-separated field, instead of the raw
  /// (still-stacked) field text.
  Map<String, dynamic> _getCurrentQsoData({String? callOverride}) {
    final base = widget.editingQso?.data ?? const <String, dynamic>{};
    final call = callOverride ?? _call;
    final refs = _refsWithTextValues([
      for (final list in _controlRefs.values) ...list,
      ..._unmatchedRefs,
    ]);
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
      // Scored against the CURRENT segment, matching the entry row's own gate
      // (`_activeRefTypes`): the pills and the fields have to agree about which
      // activities are running. The timeline goes along so the log the
      // candidate is judged against is folded per-segment too — otherwise a
      // contest that started at a break calls a pre-contest contact a dupe.
      final segmented = _segmented;
      final result = await scoreFn(
        operation: {...segmented.current, 'uuid': widget.operation.uuid},
        qso: _getCurrentQsoData(callOverride: activeCall),
        excludeUuid: widget.editingQso?.uuid,
        segments: segmented.isSegmented ? segmented.payload : null,
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
    setState(() {
      _refreshedActivityControls = controls;
      // A lookup just resolved, so any suggestedValue it produced can now fill
      // fields the operator hasn't typed into.
      _applySuggestedTextValues();
    });
    // The refreshed controls may have introduced a serial field, or changed the
    // band a per-band sequence keys off.
    unawaited(_refreshSerialPreviews());
  }

  // ---- Logging ----

  /// Escape backs out of the innermost thing that's open, one layer per
  /// press: an options menu, then an expanded secondary control, then the
  /// editing session, then the composed QSO.
  ///
  /// It must not blank the read-only view of a staged-delete or deleted QSO —
  /// the fields are the record's only display and can't be repopulated
  /// without reselecting it. When editing an existing QSO it discards any
  /// unsaved changes and ends the editing session entirely
  /// (ham2k/app-halo-dist#199), unlike Revert, which discards changes and
  /// stays in edit mode. When composing a new QSO it goes through the wipe
  /// button's path, so the 5-second undo offer applies to Esc too.
  void _handleEscape() {
    if (_fieldsLocked) return;
    // An open exchange menu takes the first Escape, and takes it whether or not
    // the operator has touched the highlight: with a menu up, Escape means "not
    // that" — and everything else Escape does here throws away work (a wipe, a
    // discarded edit, a deselected QSO). Losing a half-typed contact to a
    // keystroke aimed at a dropdown is not a recoverable mistake.
    if (_optionSuggestions.isNotEmpty) {
      setState(() {
        _optionsMenuDismissed = true;
        _optionSelection = null;
      });
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
    if (widget.editingQso != null) {
      widget.onEditCanceled?.call();
    } else if (_hasComposedValues) {
      _handleWipeTap();
    } else if (_wipeUndoSlot.value != null) {
      _restoreFromUndoSlot();
    } else {
      _wipe();
    }
  }

  void _wipe() {
    _settlePendingFreqEdit();
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
    _clearTextControls();
    _currentQsoExtra.clear();
    _manualStartAtMillis = null;
    _selectedControlKey = null;
    _callFocus.requestFocus();
    setState(() {
      _commandMessage = null;
      _currentInterpretation = null;
      _retainedInterpretation = null;
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
      _controlTextValues.values.any((v) => v.trim().isNotEmpty) ||
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
    setState(() {});
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
    final String? actionLabel;
    final VoidCallback? onPressed;

    if (editingQso == null) {
      if (_wipeUndoSlot.value != null) {
        icon = resolveIconName('undo');
        actionLabel = widget.undoLabel ?? 'Undo';
        onPressed = _restoreFromUndoSlot;
      } else {
        icon = resolveIconName('backspace-outline');
        actionLabel = widget.wipeLabel ?? 'Wipe';
        onPressed = _hasComposedValues ? _handleWipeTap : null;
      }
    } else if (editingQso.deleted) {
      // An already-deleted QSO (selected via the "show deleted QSOs"
      // toggle) — one tap restores it immediately (ham2k/app-halo-dist#59);
      // no staged-until-save step, since restoring isn't destructive.
      icon = resolveIconName('delete-restore');
      actionLabel = widget.restoreLabel ?? 'Restore';
      onPressed = () => _handleRestoreTap(editingQso);
    } else if (_pendingDelete) {
      icon = resolveIconName('undo');
      actionLabel = widget.undoDeleteLabel ?? 'Undo delete';
      onPressed = () => setState(() => _pendingDelete = false);
    } else if (_qsoDataChanged()) {
      icon = resolveIconName('undo');
      actionLabel = widget.revertLabel ?? 'Revert';
      onPressed = () => _populateFromEditingQso(editingQso);
    } else {
      icon = resolveIconName('trash-can-outline');
      actionLabel = widget.deleteLabel ?? 'Delete';
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
        onPressed: onPressed,
        // Screen-reader name only — no hover tooltip (user-interface.md).
        icon: Icon(icon, semanticLabel: actionLabel),
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
            await _dispatchActions(commands, skipOnlineLookup: executable['skipOnlineLookup'] == true);
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
            await _decorated(_getCurrentQsoData(callOverride: stacked.call)),
            serialSequences: _serialSequences,
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
          // The displayed serial belongs to the FIRST call only — that is the
          // one number the operator actually read out. Everyone after it in the
          // list got the next numbers in the series, so strip the field and let
          // the sequence issue them at commit; without this the whole list logs
          // under one serial.
          if (index > 0) 'refs': _refsWithoutSerials(baseData['refs']),
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
            data: await _decorated(dataFor(calls.first, 0)),
          ),
        );
        for (var i = 1; i < calls.length; i++) {
          // The base data carries the edited QSO's own uuid (baseData came
          // from its record) — strip it so add() generates a fresh one for
          // this new QSO instead of colliding with the original.
          final data = dataFor(calls[i], i)..remove('uuid');
          final qso = await widget.qsosRepository
              .add(widget.operation.uuid, await _decorated(data), serialSequences: _serialSequences);
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
          final qso = await widget.qsosRepository
              .add(widget.operation.uuid, await _decorated(dataFor(calls[i], i)), serialSequences: _serialSequences);
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
        // Enter picks a highlighted suggestion instead of logging — see
        // `_handleEnter`. Bound here AND on the exchange field's own
        // `onSubmitted`, because a single-line TextField consumes Enter itself
        // and never lets it reach an ancestor Shortcuts.
        const SingleActivator(LogicalKeyboardKey.enter): _handleEnter,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _handleEnter,
        const SingleActivator(LogicalKeyboardKey.space): _handleSpace,
        // Only while an exchange menu is actually open. Bound unconditionally,
        // these would swallow the arrow keys everywhere else in the panel —
        // including a text field's own caret movement.
        if (_optionSuggestions.isNotEmpty) ...{
          // The menu is drawn best-at-the-bottom, so Up walks up the screen,
          // away from the field, which is +1 in rank order.
          const SingleActivator(LogicalKeyboardKey.arrowUp): () => _moveOptionSelection(1),
          const SingleActivator(LogicalKeyboardKey.arrowDown): () => _moveOptionSelection(-1),
        },
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
                            expandLabel: widget.expandControlsLabel,
                            collapseLabel: widget.collapseControlsLabel,
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
                      // A Stack so the `options` suggestion pills can float over
                      // the info area above instead of pushing the fields down
                      // under the operator's cursor. Clip.none: the pills are
                      // deliberately painted outside this box, and the row itself
                      // is what gives the Stack its size (the pills are
                      // positioned, so they never enlarge it).
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
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
                              // In command free-text modes a space is a literal
                              // parameter character, so those modes take the
                              // narrower interceptor: it stands aside for every
                              // space but the double-space that leaves the
                              // field. Normal callsign mode routes every space
                              // to focus/command handling. Asked via
                              // [_fieldAcceptsSpaces], the same getter
                              // `_handleSpace` uses to decide the exit — the two
                              // must never disagree about the field's mode.
                              inputFormatters: !_fieldAcceptsSpaces
                                  ? [
                                      _virtualSpace,
                                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9/.,]')),
                                      if (isMobilePlatform) MobileDotToSlashFormatter(),
                                      const UpperCaseTextFormatter(),
                                    ]
                                  : _commandMixedCase
                                      ? [_commandVirtualSpace]
                                      : [_commandVirtualSpace, const UpperCaseTextFormatter()],
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
                          // Contest exchanges, inline right after the RSTs —
                          // see `_textControls` for why these are primary.
                          for (final control in _textControls) ...[
                            const SizedBox(width: 8),
                            _exchangeField(context, control, enabled: !fieldsLocked),
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
                          if (_buildOptionSuggestionMenu(accentTheme) case final menu?) menu,
                        ],
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
  ///
  /// The `options` exchange suggestions are NOT here. They started out as a line
  /// in this area, which cost the call-info panel — the DUPE warning with it —
  /// its space for as long as an exchange field had focus. They are a menu
  /// floating over the fields instead (`_buildOptionSuggestionMenu`), so this
  /// area keeps saying what it always said.
  Widget _buildInfoArea(ThemeData theme) {
    final message = _commandMessage;
    if (message != null) {
      return MarkdownBody(
        data: flagsInMarkdown(message, fontSize: theme.textTheme.bodyMedium?.fontSize ?? 14),
        sizedImageBuilder: flagMarkdownImageBuilder,
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

  /// The searchable-exchange suggestions, as a menu floating over the fields.
  ///
  /// Anchored so the CODE column lines up with the exchange field's left edge —
  /// the codes are the column the operator is comparing against what they typed,
  /// so they sit directly above the field the value lands in, and the names hang
  /// off to the left where there is room for them. Hung off the field itself
  /// through a [LayerLink], so that holds wherever the row puts the field: RSTs
  /// on or off, a state field, two exchanges side by side.
  ///
  /// Ordered BOTTOM-UP: the best match is the row nearest the field, and it is
  /// the row Space takes. Rows are tappable and the arrow keys walk the highlight
  /// (see [_moveOptionSelection]); all three go through
  /// [_acceptOptionSuggestion], so a tap, an arrow-then-Space and a plain Space
  /// are one path.
  ///
  /// Both columns are sized from the widest value measured in BOLD, so the menu
  /// keeps its shape as the highlight moves — a menu that resized under the
  /// arrow keys would be the same jump the fields themselves used to have.
  ///
  /// Colours are the dialog scheme, not the panel's: this is a surface floating
  /// over the panel rather than part of it, so it reads like every other thing
  /// the app puts on top — `surface` for the rows, the dialog band tone for the
  /// value column, and a plain onSurface wash for the highlighted row.
  ///
  /// Floating, not laid out, so nothing moves as the operator types: it paints
  /// over the info area above rather than pushing the fields down under the
  /// cursor. It is inside the panel's own subtree — not an `Overlay` — so it
  /// rebuilds with the panel and needs no entry to insert, update or dispose.
  ///
  /// COVERING the info area while it is open — the DUPE warning and the rest of
  /// the scoring notices with it — is a SETTLED decision rather than an oversight
  /// (Sebastian, 2026-07-26): it is the price of not pushing the fields down under
  /// the operator's hands mid-exchange, and polo made the opposite trade. Two
  /// separate reviews have raised it as a defect; it isn't one.
  Widget? _buildOptionSuggestionMenu(ThemeData theme) {
    final control = _focusedOptionsControl;
    if (control == null) return null;
    final suggestions = _optionSuggestions;
    if (suggestions.isEmpty) return null;

    final colors = theme.colorScheme;
    final selected = _selectedOptionIndex(suggestions.length);

    // Monospace for the codes: they are log data, read as a column and compared
    // character by character against what is in the field — the same reason the
    // QSO list and the spots panel set callsigns in it.
    // Weights are explicit on both variants: the regular one has to SAY it is
    // regular, or a row inherits whatever weight the ambient text theme brought
    // and the highlight stops being the only difference between rows.
    final codeStyle = haloMonoStyle(context, color: colors.onSurface, fontWeight: FontWeight.w400);
    final boldCode = codeStyle.copyWith(fontWeight: FontWeight.w700);
    final nameStyle = (theme.textTheme.bodyMedium ?? const TextStyle())
        .copyWith(color: colors.onSurface, fontWeight: FontWeight.w400);
    final boldName = nameStyle.copyWith(fontWeight: FontWeight.w700);

    // Measured in BOLD even for the rows that aren't: the highlight moves with
    // the arrow keys, and a column sized to the regular weight would have to
    // grow the moment its row became the selected one.
    var codeText = 0.0;
    var nameText = 0.0;
    for (final option in suggestions) {
      codeText = math.max(codeText, textWidth(context, option.code, boldCode));
      nameText = math.max(nameText, textWidth(context, option.name ?? option.code, boldName));
    }
    const namePadding = 10.0;
    const codePadding = 8.0;
    // A long name is ellipsized rather than allowed to push the menu off the
    // side of a narrow window; the code column, which is the point, is never cut.
    final nameWidth = math.min(nameText, 220.0) + namePadding * 2;
    final codeWidth = codeText + codePadding * 2;

    Widget row(int index, ExchangeOption option) {
      final isSelected = index == selected;
      return InkWell(
        // The field keeps focus: this is a value picker, not somewhere to land.
        // Without this, tapping a row moves focus out of the exchange field and
        // the menu it belongs to closes under the operator's finger.
        canRequestFocus: false,
        onTap: () => setState(() => _acceptOptionSuggestion(index: index, explicit: true)),
        child: DecoratedBox(
          // In FRONT, so the wash covers the value column too and the whole row
          // reads as one selected thing.
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            color: isSelected ? colors.onSurface.withValues(alpha: 0.10) : Colors.transparent,
          ),
          child: Row(
            children: [
              SizedBox(
                width: nameWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: namePadding, vertical: 5),
                  child: Text(
                    option.name ?? option.code,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: isSelected ? boldName : nameStyle,
                  ),
                ),
              ),
              Container(
                width: codeWidth,
                color: haloDialogBandColor(context),
                padding: const EdgeInsets.symmetric(vertical: 5),
                alignment: Alignment.center,
                child: Text(
                  option.code,
                  maxLines: 1,
                  style: isSelected ? boldCode : codeStyle,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Positioned(
      left: 0,
      top: 0,
      child: CompositedTransformFollower(
        // A focused TextField has a follower of its own (selection handles), so
        // this one is named — for tests, and for the same agent/browser tooling
        // `semanticId` serves elsewhere in this panel.
        key: exchangeSuggestionsKey,
        link: _textLinkFor(control['key'] as String),
        // The menu's bottom-LEFT corner against the field's top-left, then shifted
        // left by exactly the name column: that puts the code column's left edge
        // on the field's own left edge.
        targetAnchor: Alignment.topLeft,
        followerAnchor: Alignment.bottomLeft,
        offset: Offset(-nameWidth, -6),
        child: Material(
          // A menu, so it casts a shadow over what it covers rather than looking
          // like part of the panel underneath.
          elevation: 8,
          color: colors.surface,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reversed: worst at the top, best at the bottom against the field.
              for (final entry in suggestions.indexed.toList().reversed) row(entry.$1, entry.$2),
            ],
          ),
        ),
      ),
    );
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
  /// layer's `operationStatsLines`, behind a timer icon. The rate lines are
  /// time-relative, so they re-derive once per second — scoped to this row
  /// via [OncePerSecond] rather than ticking the whole panel.
  Widget _buildOperationStats(ThemeData theme) => OncePerSecond(builder: (context, _) {
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
  });

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
        flagGlyph(flag, fontSize: theme.textTheme.bodyMedium?.fontSize ?? 14, shadows: _glyphGlow(theme)),
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
            data: flagsInMarkdown(rest, fontSize: textStyle?.fontSize ?? 14),
            sizedImageBuilder: flagMarkdownImageBuilder,
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
        // A flag decodes and gets the same Windows image fallback as every
        // other flag site; any other pictographic emoji still needs
        // emojiFontFamily (via flagGlyph's non-flag branch) instead of
        // textStyle's Roboto, or it renders as nothing at all — same gap
        // #451's review found and fixed at call_info_panel.dart's flag Text.
        flagGlyph(leadMatch.group(0)!, fontSize: textStyle?.fontSize ?? 14, shadows: _glyphGlow(theme)),
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

  /// When set, decides whether a given edit's space is ours to take. A field
  /// that accepts literal spaces passes this in so only the double-space that
  /// EXITS the field is intercepted; every other space is typed as normal.
  /// Absent means every lone space is ours — the plain callsign/RST/State/Grid
  /// case, where a space has no meaning other than "next field".
  final bool Function(TextEditingValue oldValue)? shouldIntercept;

  /// Called instead of [onSpace] when iOS's "." shortcut is recognized, with
  /// the text as it stood BEFORE the whole gesture (the value minus its
  /// trailing space). The exit can't be expressed as "strip what's there now":
  /// by the time this runs iOS's second edit has already re-added the space
  /// after the period, so the only reliable target is the text we saw going in.
  final void Function(String baseText)? onPeriodShortcut;

  const _VirtualSpaceFormatter(this.onSpace, {this.shouldIntercept, this.onPeriodShortcut});

  /// iOS's "." shortcut, which fires exactly where our exit gesture does: with
  /// a space already in the text, a second space-bar press is turned into a
  /// period. It never arrives as a space insertion, so the check below can't
  /// see it and a period lands in the field instead.
  ///
  /// It arrives as TWO edits, and this matches the first: the trailing space is
  /// REPLACED BY A PERIOD, same length, caret still at the end — the space that
  /// iOS then re-adds is a separate edit. Both were traced landing in the SAME
  /// event-loop turn, which the exit depends on: [onPeriodShortcut] runs on a
  /// microtask, so it sees the finished text and restores the pre-gesture value
  /// over it. Were iOS ever to send the second edit a turn later, it would
  /// arrive after the restore and put the period back — the symptom to look for
  /// if this regresses on a future iOS is "focus moves but '.' is left behind".
  /// Traced on an iPhone 17 Pro simulator, iOS 26.5:
  ///
  ///     old="NOTE HI " sel=8,8  ->  new="NOTE HI."  sel=8,8   <- this
  ///     old="NOTE HI." sel=8,8  ->  new="NOTE HI. " sel=9,9
  ///
  /// Only reachable in a space-accepting field: everywhere else the first space
  /// is consumed before it enters the text, leaving iOS nothing to convert.
  /// A human can't produce this edit — typing "." with the caret at the end of
  /// "NOTE HI " gives "NOTE HI ." (longer, space intact), never "NOTE HI." — so
  /// matching it can't swallow a period somebody meant. The cost is that the
  /// shortcut is unavailable in these fields: to get a period, type one.
  ///
  /// The traits are NOT the lever here, tempting as it looks: this was traced
  /// with `autocorrect: false` live on the field and the shortcut still fired.
  /// It follows the system-wide "." Shortcut setting, which an app cannot turn
  /// off — recognizing the edit is the only option.
  static bool _isIOSPeriodShortcut(TextEditingValue oldValue, TextEditingValue newValue) {
    // iOS only. The shape is generic enough that an Android IME doing its own
    // smart punctuation could produce it, and there a deliberately typed "."
    // would be swallowed as the exit gesture — a silent edit to the operator's
    // text. Android's own double-space-period is a Gboard setting nobody has
    // traced here, so it stays out until someone does.
    if (!isIOSPlatform) return false;
    if (!oldValue.text.endsWith(' ')) return false;
    final replaced = '${oldValue.text.substring(0, oldValue.text.length - 1)}.';
    return newValue.text == replaced && newValue.selection.end == replaced.length;
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // The exit gesture, arriving disguised as punctuation. Gated on the same
    // predicate as a real space, so it stays confined to the fields that opted
    // into space-accepting behavior.
    if (shouldIntercept != null &&
        onPeriodShortcut != null &&
        _isIOSPeriodShortcut(oldValue, newValue) &&
        shouldIntercept!(oldValue)) {
      // The text as it was before the gesture — see [onPeriodShortcut]. Both of
      // iOS's edits are applied synchronously before any microtask runs, so a
      // handler that looked at the controller instead would find "NOTE HI. "
      // and strip only the space, leaving the period behind.
      final base = oldValue.text.substring(0, oldValue.text.length - 1);
      scheduleMicrotask(() => onPeriodShortcut!(base));
      return oldValue;
    }
    // Only a genuine single-space insertion at the cursor — not a paste that
    // merely contains a space, and not a selection replacement.
    if (newValue.text.length == oldValue.text.length + 1) {
      final caret = newValue.selection.end;
      if (caret > 0 &&
          caret <= newValue.text.length &&
          newValue.text[caret - 1] == ' ' &&
          newValue.text.substring(0, caret - 1) + newValue.text.substring(caret) == oldValue.text &&
          (shouldIntercept?.call(oldValue) ?? true)) {
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
