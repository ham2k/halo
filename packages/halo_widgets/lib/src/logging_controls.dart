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

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';

import 'call_field_text.dart';
import 'call_info_summary.dart';
import 'halo_dialog.dart';
import 'icon_resolver.dart';
import 'inline_markdown.dart';
import 'keyboard_accessory.dart';
import 'keyboard_dismiss.dart';
import 'logging_controls_command.dart';
import 'logging_controls_controller.dart';
import 'logging_controls_focus.dart';
import 'logging_controls_lookup.dart';
import 'logging_controls_radio.dart';
import 'logging_controls_metrics.dart';
import 'logging_controls_spotting.dart';
import 'logging_controls_time.dart';
import 'logging_controls_types.dart';
import 'logging_info_area.dart';
import 'mdi_icons.g.dart';
import 'modal_pane.dart' show showHaloDialog;
import 'option_matching.dart';
import 'platform_chrome.dart';
import 'qso_edit_pane.dart';
import 'resizable_split_view.dart' show PaneSafeArea;
import 'semantic_id.dart';
import 'ref_text_input.dart';
import 'secondary_control_row.dart';
import 'spacing.dart';
import 'text_formatters.dart';
import 'theme.dart';
import 'timed_undo_slot.dart';
import 'wall_clock.dart';


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

  /// Off until the operator asks for it. The operator's own decision is
  /// recorded the moment they save the settings dialog — which always
  /// writes the full order — so "this key is not in `controlOrder` yet" is
  /// what distinguishes "never decided" from "decided against", and is why
  /// a default-hidden control needs no second stored set of its own.
  final bool defaultHidden;

  const _ControlDescriptor({
    required this.key,
    required this.icon,
    required this.label,
    this.mandatory = false,
    this.defaultHidden = false,
  });
}


/// The floating pills a `kind: 'options'` exchange field offers. Named because a
/// focused TextField carries a `CompositedTransformFollower` of its own for
/// selection handles, so "the follower" is ambiguous without it.
const exchangeSuggestionsKey = ValueKey('exchange.suggestions');

class LoggingControls extends StatefulWidget {
  final Operation operation;
  final QsosRepository qsosRepository;

  /// Where a `kind: 'serial'` control gets the number it shows while a
  /// contact is composed (docs/design/contests.md §5.8.1). Null falls back to
  /// the sequence's `peek` — the single-device answer, and every test's.
  final SerialNumberSource? serialNumbers;

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
  ///
  /// Answering null means "I could not fetch them" — distinct from an empty
  /// list, which means the activities genuinely want no controls for this
  /// QSO. A refresh that fails must keep whatever is already displayed: an
  /// empty list installed mid-QSO takes every activity field off the panel
  /// while the operator is typing into it.
  final Future<List<Map<String, dynamic>>?> Function(Map<String, dynamic> qso)? refreshActivityControls;

  /// Last chance for an activity to shape a QSO before it is written, via the
  /// extension runtime's `processQsoBeforeSave` — a contest mirroring the
  /// exchange it keeps on its own ref into the generic `their.exchange` that
  /// the QSO row and a plain ADIF export read.
  ///
  /// Applied on EVERY save path (single, call list, call stack, edit), because
  /// a QSO decorated only when logged one way would export differently
  /// depending on how it was entered. When null the data is saved as-is.
  ///
  /// [operation] is the SEGMENT-EFFECTIVE one for the contact's own time, not
  /// the operation as it stands now: an edit of a contact made before a
  /// `break` projects the county, call and setup that were true when it was
  /// made, so a hook need not stamp anything onto a contact to keep a later
  /// edit from moving it.
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> qso, Map<String, dynamic> operation)?
      decorateQsoBeforeSave;

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

  /// A request to log a QSO outright, as if the submit button had been
  /// pressed — the spots list's slid-right action, which ends in a logged
  /// contact without the logging panel being looked at.
  ///
  /// Carries the QSO rather than relying on [suggestedQso] having been applied
  /// first: when the operator is mid-edit the suggestion is suppressed, so a
  /// request that trusted the fields would log whatever they happened to hold.
  /// The serial is what makes a repeat of the same spot a new request.
  final ({int serial, Map<String, dynamic> qso})? logRequest;

  /// Asked before a [logRequest] destroys work in this panel — an edit in
  /// progress ([editingQso]) or a part-typed entry. True means "clear it and
  /// log the spot"; false means the operator chose to go back to what they
  /// had, and the caller has surfaced this panel for them.
  ///
  /// The dialog belongs to the caller: this file holds no strings, and where
  /// "go back" NAVIGATES to is a question only the app can answer.
  final Future<bool> Function({required bool editing})? confirmLogOverwrite;

  /// Whether [suggestedQso] is a tentative offer rather than a choice already
  /// made — a spot row slid open far enough to peek, which the operator may
  /// still drag back. It fills the fields like any other suggestion, but it
  /// belongs to the open row rather than to the operator: [suggestedQso]
  /// going null takes it back out again, and nothing it put there counts as
  /// work when the next one arrives.
  ///
  /// Over an edit or a part-typed callsign it is HELD instead of applied —
  /// applying it moves the VFO (retuning a connected radio) and replaces the
  /// fields, neither of which may happen behind the operator's back — and put
  /// to them at [suggestionSettledSerial].
  final bool suggestedQsoIsTentative;

  /// The operator has changed the call field themselves — typed into it, or
  /// wiped it. Never fired for a suggestion filling it: a spot arriving is not
  /// the operator composing anything.
  ///
  /// What listens is the surface the suggestion came FROM. A slid row is an
  /// open question about which station to work, and an operator who has gone
  /// to the fields and started typing has answered it somewhere else.
  final VoidCallback? onCallEdited;

  /// Bumped when the gesture behind a tentative [suggestedQso] comes to rest:
  /// the row is open and the finger is off it. A suggestion held back over
  /// work in progress is put to the operator here, and never earlier — a
  /// dialog raised mid-drag takes the pointer while the drag runs on
  /// underneath it, and the release still commits.
  final int suggestionSettledSerial;

  /// Fires when an editing session ends without necessarily going through
  /// `onLogged` — a save of an existing QSO, a delete, or an explicit
  /// revert. The caller (which owns the selected-QSO state) clears its
  /// selection in response; this widget's own fields reset via
  /// `didUpdateWidget` once `editingQso` becomes null on the next build.
  final VoidCallback? onEditCanceled;

  /// Arrow Up on a secondary control pill walks off the top of this panel —
  /// the caller (which owns the QSO list and its selection) takes the
  /// keyboard from there. Returns whether it actually did (false when the
  /// list has nothing navigable — an empty operation, or one holding only
  /// event markers) so a caller that already gave up its own focus can fall
  /// back instead of leaving the keyboard stranded. Unset means the panel is
  /// the top of the ladder and Up simply stops at the pills. See APP-19.
  final bool Function()? onNavigateToQsoList;

  /// Settings engine interface.
  final SyncSettings? settings;

  /// Holds the radio's VFO state (`vfoA`) — device-global, shared by every
  /// operation, not scoped to this one. Used to seed the Radio control for
  /// a new QSO instead of resetting to a hardcoded default, and as the
  /// destination for its edits. When null, the Radio control behaves as it
  /// did before this state existed — purely local to this widget.
  final VfoStore? radioService;

  /// Fires when [radioService]'s state changes — so the Radio control can
  /// follow a connected rig (CAT), or any other writer, live.
  ///
  /// Separate from [radioService] rather than folded into it because
  /// `VfoStore` lives in pure-Dart halo_core, which has no Flutter
  /// dependency and therefore no `Listenable`. In the app both are the same
  /// object (`RadioService`); when null the control behaves as it always
  /// did, reading the VFO only when it seeds.
  final Listenable? radioUpdates;

  /// Whether a transceiver is configured to drive this control via CAT — the
  /// Radio control's icon shows a cat glyph instead of a plain radio when so,
  /// the same pun the Station settings panel makes at its own entry.
  /// halo_widgets has no CatService of its own to ask (docs/design/cat.md),
  /// so the app resolves this and passes it straight through.
  final bool hasConfiguredRadio;

  /// Whether the [hasConfiguredRadio] radio is actually connected right now,
  /// as opposed to merely configured — the Station Configuration button's
  /// green (connected) vs red (configured but not connected). Meaningless
  /// when [hasConfiguredRadio] is false.
  final bool radioConnected;

  /// Opens the Station Configuration quick-access dialog (current radio pick
  /// plus the equipment inventory) from inside the expanded Radio control.
  /// Building the dialog itself is the app's job, same reasoning as
  /// [hasConfiguredRadio].
  final VoidCallback? onOpenStationConfig;

  /// [hasConfiguredRadio]'s display name — shown in small type below the
  /// Station Configuration icon, past the Mode dropdown, ellipsized past 3x
  /// the icon's own width. Null when there's no radio (nothing to name) or
  /// [onOpenStationConfig] is null (nothing for tapping it to do).
  final String? radioName;

  /// Asked before Escape does anything here. True means the app has just
  /// used the key for something that outranks a wipe — stopping a CW
  /// message going out — and the fields are left alone. A HardwareKeyboard
  /// handler's own "handled" answer cannot do this: the focus tree is
  /// dispatched to regardless, so the app's Escape and this widget's would
  /// otherwise both fire on one keystroke.
  final bool Function()? escapeClaimed;

  /// Laid between the info area and the entry row — the app's keyer
  /// area (docs/design/cat.md § CW keying), which halo_widgets has no CAT
  /// types to build itself. The widget owns its own size and animation, and
  /// takes no room at all while it has nothing to show, so the row above and
  /// below sit exactly as they do with it null.
  final Widget? aboveEntryRow;

  /// The operator's own ITU region (1/2/3) and lowercase ISO country code
  /// (HALO-52), from the callsign-annotation guess — see
  /// `operation_view.dart`'s `_resolveOurEntityPrefix`, which resolves both
  /// the same way it already resolves `ourEntityPrefix`. Passed straight
  /// through to [modeForFrequency] so a typed/commanded frequency gets a
  /// mode guess scoped to where the operator actually is, not just whatever
  /// generic segment happens to cover the frequency. Null (the default)
  /// leaves the guess exactly as it was before HALO-52 — see that
  /// function's doc comment.
  final int? ourItuRegion;
  final String? ourCountryCode;

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
  /// `newDXCC`, `newState`, `newProvince`, and any a contest scorer adds) to
  /// its localized pill text; falls back to the raw key.
  final String Function(String noticeKey)? scoreNoticeLabel;

  /// Fetches the station's prior contacts' start times for the call-info's
  /// worked-before pill. Asked once per active-call change alongside the
  /// lookup (so only when [lookup] is set, the pill being part of the
  /// call-info the lookup fills), and once when a QSO is opened for editing,
  /// with that QSO excluded. Null shows no pill.
  final WorkedBefore? workedBefore;

  /// The worked-before pill's text for those times — bucketed and
  /// pluralized by the app layer, which owns the clock. No pill without it.
  final String? Function(List<int> startTimes)? workedBeforeLabel;

  /// Notifies the host of the current call-info (for the detail panel — the
  /// Info tab on wide layouts), null when the call-info panel isn't showing.
  final CallInfoChanged? onCallInfoChanged;

  /// Notifies the host that the QSO being composed changed — every field,
  /// not just the callsign, and no more than once per distinct draft.
  ///
  /// Expensive by nature: it fires as fast as the operator types, and the
  /// draft is rebuilt and compared to decide whether it did. A host that has
  /// nothing to tell must pass **null**, which is what keeps the whole path
  /// off the keystroke route rather than merely making it cheap.
  final QsoDraftChanged? onQsoChanged;

  /// The same draft, plus the main logging fields in the order this
  /// operator's own row shows them — what a device sharing this operation
  /// sends its peers, so their panel reproduces the row rather than guessing
  /// at it.
  ///
  /// The fields are what make a block faithful to an operation the reader
  /// renders differently, or cannot render at all: a contest exchange arrives
  /// under the label its extension gave it, and the sent/rcvd order is the
  /// SENDER's, since the point is showing what they are looking at.
  ///
  /// Separate from [onQsoChanged] rather than an argument to it, for a reason
  /// that outlives the plumbing: these change INDEPENDENTLY of the draft.
  /// Typing `59` into a report whose placeholder already read `59` moves
  /// nothing in the draft — `_rstOrDefault` substitutes the placeholder for
  /// an empty field — while turning that report from the app's answer into
  /// the operator's. One shared dedupe would swallow exactly the change this
  /// callback exists to report.
  ///
  /// Null-gated like [onQsoChanged], and for the same reason.
  final PeerDraftChanged? onPeerDraftChanged;

  /// Fires when the user taps the compact call-info area — the host opens the
  /// detail panel (a modal on narrow layouts, or focuses the Info tab on wide).
  final VoidCallback? onCallInfoTap;

  /// The app is capturing the current power onto every QSO it saves
  /// (Station Configuration's "Track Station Info", with `power` among the
  /// tracked fields). The panel doesn't do that capture — the app does, at
  /// save — but it has to know, because a power that is being logged has to
  /// be visible and editable whether or not the Power control is in the row.
  final bool trackingPower;

  /// Who the operation says is at the key, and which position this device is
  /// logging as — what the full-edit pane offers as the placeholder for a
  /// contact that carries neither, since that is what the stamp at save time
  /// would put on it.
  final String defaultOperatorCall;
  final String defaultPosition;

  /// Whether the pane offers a Position field at all. Only an operation
  /// actually run by operating positions has seats to choose between; on any
  /// other, the field is a number that means nothing.
  final bool showPositionField;

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

  /// Spotting control (ham2k/halo-dist#10) — null (either) disables the
  /// control's icon-row/send-button UI, matching how `radioService: null`
  /// degrades the Radio control elsewhere in this widget.
  final SuggestSpotSources? suggestSpotSources;
  final SendSpot? sendSpot;

  /// A QSO write failed. The panel has already shown its own failure message
  /// in the info area; this is the host's hook to report the error
  /// (Sentry/console). The error does NOT also escape to the zone handler,
  /// so a host that leaves this unwired records nothing.
  final void Function(Object error, StackTrace stackTrace)? onWriteError;

  /// Logging view "..." menu toggles (ham2k/halo-dist#1) — gate the
  /// Sent/Rcvd RST fields and add optional inline State/Grid fields. The
  /// underlying data (State/Grid) is always editable via the "More" pane
  /// regardless of these flags; they only control the primary controls'
  /// permanent footprint.
  final bool showRSTFields;
  final bool showStateField;
  final bool showGridField;

  /// What an untouched Sent/Rcvd stands for, per mode band — the operator's
  /// own overrides from Logging settings ([defaultReport] for phone,
  /// [defaultReportCW] for CW/RTTY and the other data modes,
  /// [defaultReportFT8] for the FT modes).
  ///
  /// Empty means "the standard report", which is [defaultRSTFor]'s own
  /// fallback, so an unconfigured app and one whose settings were cleared
  /// behave identically and neither has to name `59`/`599`/`+0` here.
  final String defaultReport;
  final String defaultReportCW;
  final String defaultReportFT8;

  /// Rcvd before Sent, for an operator who takes the report before giving one.
  ///
  /// Swaps the pair everywhere it appears — the main row, the keyboard's own
  /// order through it, the QSO list and the More pane — so no surface disagrees
  /// with the one the operator is typing into.
  final bool switchSentRcvd;

  /// Move focus on once a report is complete, so a full exchange takes no
  /// Spaces at all. "Complete" is [rstLengthFor]: two characters on phone,
  /// three elsewhere.
  final bool jumpAfterRST;

  /// The mobile numbers row (issue #27) — a bar of digit keys floated above
  /// the on-screen keyboard while a logging field has focus. Only ever shown
  /// on mobile platforms with the keyboard up (see `_buildNumberKeys`).
  /// [showExtraInNumbersRow] adds the contextual "/" (callsign) / "."
  /// (numeric) key; [vibrateNumbersRow] toggles the key-press haptic.
  final bool showNumbersRow;
  final bool showExtraInNumbersRow;
  final bool vibrateNumbersRow;

  /// When true, the submit button is rendered on the left of the main logging
  /// controls row and the text fields on the right.
  final bool leftieMode;

  /// Where the numbers row is published for drawing. The row has to be painted
  /// below the status footer and directly on the keyboard, which is one level
  /// up from here — see [KeyboardAccessoryController]. Null (tests, and any
  /// host that doesn't draw one) simply means no row appears.
  final KeyboardAccessoryController? keyboardAccessory;

  /// Optional imperative handle for driving the controls from outside (set the
  /// call, log, wipe) — used by the app's dev bridge. Attached on mount.
  final LoggingControlsController? controller;

  /// Opens a link tapped in a call note. Null leaves the note's links styled
  /// but inert; the controls stay free of any url_launcher dependency either
  /// way — the app decides how links open.
  final InlineMarkdownOpenLink? onOpenLink;

  const LoggingControls({
    super.key,
    required this.operation,
    required this.qsosRepository,
    this.serialNumbers,
    this.controller,
    this.onOpenLink,
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
    this.logRequest,
    this.confirmLogOverwrite,
    this.suggestedQsoIsTentative = false,
    this.suggestionSettledSerial = 0,
    this.onCallEdited,
    this.onEditCanceled,
    this.onNavigateToQsoList,
    this.settings,
    this.radioService,
    this.radioUpdates,
    this.hasConfiguredRadio = false,
    this.radioConnected = false,
    this.onOpenStationConfig,
    this.radioName,
    this.aboveEntryRow,
    this.escapeClaimed,
    this.leftieMode = false,
    this.ourItuRegion,
    this.ourCountryCode,
    this.controlOrder = const [],
    this.hiddenControlKeys = const {},
    this.onControlsSettingsChanged,
    this.operationStatsLines,
    this.callLocationLine,
    this.scoreQso,
    this.scoreNoticeLabel,
    this.workedBefore,
    this.workedBeforeLabel,
    this.onCallInfoChanged,
    this.onQsoChanged,
    this.onPeerDraftChanged,
    this.onCallInfoTap,
    this.defaultOperatorCall = '',
    this.defaultPosition = '',
    this.showPositionField = false,
    this.trackingPower = false,
    this.enabledBands,
    this.enabledModes,
    this.suggestSpotSources,
    this.sendSpot,
    this.onWriteError,
    this.showRSTFields = true,
    this.showStateField = false,
    this.showGridField = false,
    this.defaultReport = '',
    this.defaultReportCW = '',
    this.defaultReportFT8 = '',
    this.switchSentRcvd = false,
    this.jumpAfterRST = false,
    this.keyboardAccessory,
    this.showNumbersRow = false,
    this.showExtraInNumbersRow = true,
    this.vibrateNumbersRow = true,
  });

  @override
  State<LoggingControls> createState() => _LoggingControlsState();
}

class _LoggingControlsState extends State<LoggingControls> with WidgetsBindingObserver {
  final _callController = TextEditingController();

  /// The Radio control's state — frequency, band and mode, the Band/Mode
  /// dropdowns, and the VFO mirror. See [RadioControlModel]; what stays here
  /// is when it moves and what moves with it.
  late final _radio = RadioControlModel(
    config: () => (
      radioService: widget.radioService,
      editingQso: widget.editingQso,
      ituRegion: widget.ourItuRegion,
      countryCode: widget.ourCountryCode,
      enabledBands: widget.enabledBands,
      enabledModes: widget.enabledModes,
    ),
    isPopulating: () => _populating,
    onRescore: _lookup.scheduleScore,
  );
  final _sentController = TextEditingController();
  final _rcvdController = TextEditingController();
  final _gridController = TextEditingController();
  final _stateController = TextEditingController();
  /// The Power control's watts. Mirrors the VFO's power while composing
  /// (seeded by [_seedFromRadioService]) and the QSO's own while editing
  /// one, exactly as the frequency field mirrors [Vfo.freq].
  final _powerController = TextEditingController();
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
  final _powerFocus = FocusNode();



  /// Which secondary control (if any) currently has its input expanded.
  String? _selectedControlKey;

  /// The callsign lookup, the worked-before answer and the live score for the
  /// call at the cursor — see [CallLookupModel]. What stays here is what a
  /// resolved lookup does to the entry ([_onLookupResolved]) and when the
  /// whole thing is forgotten.
  late final _lookup = CallLookupModel(
    config: () => (
      lookup: widget.lookup,
      workedBefore: widget.workedBefore,
      scoreQso: widget.scoreQso,
      editingQso: widget.editingQso,
      operation: widget.operation,
    ),
    activeCall: () => _callAtCursor,
    isCallInfoActive: () => _callInfoActive,
    qsoData: (call) => _getCurrentQsoData(callOverride: call),
    segmented: () => _segmented,
    onResolved: _onLookupResolved,
    // A stale QSO-scoped placeholder/transform must not linger onto the next
    // entry — see [_refreshedActivityControls].
    onCleared: () => _refreshedActivityControls = null,
  );

  /// The command being typed into the call field — see
  /// [CommandInterpretationModel]. Running one is still this panel's
  /// ([_log] dispatches the actions), and so is the field's own reading
  /// ([_callText]).
  late final _command = CommandInterpretationModel(
    config: () => (
      interpretCommand: widget.interpretCommand,
      editingQso: widget.editingQso,
      operationData: () => _operationDataForCommands,
      onMessageChanged: widget.onCommandMessageChanged,
    ),
    callText: () => _callText,
    qsoData: _getCurrentQsoData,
  );

  /// The Time control — when the entry is stamped. See [TimeControlModel].
  late final _time = TimeControlModel(
    config: () => (editingQso: widget.editingQso),
    isPopulating: () => _populating,
  );

  /// The Spotting control — see [SpottingControlModel].
  late final _spotting = SpottingControlModel(
    config: () => (
      sendSpot: widget.sendSpot,
      suggestSpotSources: widget.suggestSpotSources,
      radioService: widget.radioService,
      editingQso: widget.editingQso,
      operation: widget.operation,
    ),
  );

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

  /// Bumped whenever `widget.activityControls`/`operation.refs` change (see
  /// `didUpdateWidget`) — a per-QSO refresh in flight from BEFORE that change
  /// captures the generation it started against, and drops its own result on
  /// return if the generation has since moved on. A callsign lookup that
  /// started before a ref was added and resolves after must not overwrite
  /// the fresh operation-level controls with its own stale snapshot.
  int _activityControlsGeneration = 0;

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
      for (final ref in ((current['refs'] as List?) ?? const []).whereType<Map<dynamic, dynamic>>())
        if (ref['type'] case final String type) type,
    };
  }


  final Map<String, dynamic> _currentQsoExtra = {};

  /// Fields of the contact's `our` block the full-edit pane overrides — who
  /// was at the key, and which position logged it. Kept apart from
  /// [_currentQsoExtra], which carries only TOP-LEVEL keys: these two live
  /// inside `our`, beside the station call the controls own.
  ///
  /// An override is written only when the pane's field was actually edited,
  /// so a contact left alone still takes the stamp the save path applies
  /// (`qsoWithOperator`), and an emptied field stays empty rather than being
  /// re-stamped — the stamp fills what is ABSENT, and this key is present.
  final Map<String, dynamic> _ourExtra = {};

  /// Fields of the contact's `their` block the full-edit pane overrides —
  /// everything about the other station that no primary or secondary control
  /// owns: city, county, the zones, the ARRL section, a coordinate, and the
  /// power they were running. Same shape and same rule as [_ourExtra]: a key
  /// lands here only where the pane actually CHANGED it, so opening a
  /// contact and saving it never promotes a lookup guess into an entered
  /// value the way `their.grid` would (see [_gridTouched]).
  ///
  /// Never `call`, `sent`, `name`, `grid` or `state` — those have their own
  /// fields in the row, and their own touched-tracking above.
  final Map<String, dynamic> _theirExtra = {};

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
  List<ExchangeOption> _optionsFor(Map<dynamic, dynamic> control) => [
        for (final raw in ((control['input'] as Map?)?['options'] as List?) ?? const [])
          if (raw is Map)
            ?ExchangeOption.fromMap(raw.cast<String, dynamic>()),
      ];

  /// The separator a `kind: 'options'` control accepts several values with —
  /// a QSO party's county line, `ORDES/JEF` — or `''` for the single-value
  /// fields every other contest declares.
  String _optionSeparatorFor(Map<dynamic, dynamic> control) {
    final separator = ((control['input'] as Map?)?['multiValue'] as Map?)?['separator'];
    return separator is String ? separator : '';
  }

  /// What the operator is typing RIGHT NOW in [control] — the whole field for a
  /// single-value one, and the value the cursor is in for a multi-value one.
  ///
  /// The cursor comes from the controller rather than being tracked in state, so
  /// the SPACE handler and the accept read it at the moment they act and cannot
  /// disagree about which county the operator is in.
  ///
  /// The suggestion LINE is repainted by the ordinary rebuilds — a keystroke, a
  /// focus change — and nothing listens to the caret on its own, so moving it
  /// back into an earlier value leaves the offers showing for the value just
  /// left until the next keystroke. Accepting one is still correct, because the
  /// accept recomputes; the alternative is a listener that rebuilds the whole
  /// panel on every caret move, mid-QSO, for a line the operator is not reading.
  String _typedOptionValue(Map<dynamic, dynamic> control) {
    final key = control['key'] as String;
    final text = _controlTextValues[key] ?? '';
    final separator = _optionSeparatorFor(control);
    if (separator.isEmpty) return text;
    final controller = _textControllerFor(key);
    final cursor = controller.selection.baseOffset;
    return exchangeValueAt(text, cursor < 0 ? text.length : cursor, separator);
  }

  /// What the value being typed might be SHORT for, where a control lets a later
  /// value borrow the first one's prefix — `JEF` after `ORDES/` may mean
  /// `ORJEF`. Null when there is no such reading.
  ///
  /// Offered ALONGSIDE the literal reading, never instead of it: the suggestion
  /// line searches for what was typed first and falls back to this only when
  /// that finds nothing, so typing a code out in full suggests as it always did.
  String? _inheritedOptionValue(Map<dynamic, dynamic> control) {
    final inherit = _optionInheritPrefixFor(control);
    final separator = _optionSeparatorFor(control);
    if (inherit <= 0 || separator.isEmpty) return null;
    final key = control['key'] as String;
    final text = _controlTextValues[key] ?? '';
    final typed = _typedOptionValue(control);
    final values = splitExchangeValues(text, separator);
    if (values.length < 2 || typed.isEmpty || values.first == typed) return null;
    return inheritedCandidate(values.first, typed, inherit);
  }

  /// How many of the first value's characters a later one may borrow — the
  /// multi-state QSO parties' county-line shorthand, 0 everywhere else.
  int _optionInheritPrefixFor(Map<dynamic, dynamic> control) {
    final value = ((control['input'] as Map?)?['multiValue'] as Map?)?['inheritPrefix'];
    return value is int ? value : 0;
  }

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

    final typed = _typedOptionValue(control);
    final minChars = input['minCharsForSuggestions'];
    if (minChars is int && typed.trim().length < minChars) return const [];

    final matchOn = {
      for (final m in (input['matchOn'] as List?) ?? const ['code', 'name'])
        if (m is String) m,
    };
    final preferred = [
      for (final c in (input['preferredCodes'] as List?) ?? const [])
        if (c is String) c,
    ];
    final on = matchOn.isEmpty ? const {'code', 'name'} : matchOn;
    final matches = matchExchangeOptions(typed, options, matchOn: on, preferred: preferred);

    // What the value may be SHORT for, where a later value borrows the first
    // one's prefix. When that reading names a real code it goes FIRST — ahead
    // of anything the literal text matched.
    //
    // Consulting it only when the literal matched nothing was the bug: in 7QP,
    // `ORDES/JEF` matches `IDJEF`, `MTJEF`, `ORJEF` and `WAJEF` by NAME
    // ("Jefferson …"), so the literal always matched and Space took the first —
    // logging Idaho's Jefferson for a shorthand that unambiguously means
    // Oregon's. The shorthand is not a guess: the first value says which state.
    final inherited = _inheritedOptionValue(control);
    if (inherited == null) return matches;
    final exact = options.where((o) => o.code.toUpperCase() == inherited.toUpperCase()).toList();
    if (exact.isEmpty) {
      return matches.isNotEmpty
          ? matches
          : matchExchangeOptions(inherited, options, matchOn: on, preferred: preferred);
    }
    return [
      ...exact,
      ...matches.where((o) => o.code.toUpperCase() != inherited.toUpperCase()),
    ];
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
  /// `VirtualSpaceFormatter`, which rejects the edit and schedules this in a
  /// microtask, so it must be safe to run when the field already holds the
  /// value: accepting the same code twice is a no-op rather than a second
  /// write.
  bool _acceptOptionSuggestion({int? index, bool explicit = false}) {
    final control = _focusedOptionsControl;
    if (control == null) return false;
    final suggestions = _optionSuggestions;
    if (suggestions.isEmpty) return false;

    final key = control['key'] as String;
    final typed = _typedOptionValue(control);
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
      // The typed text, or what it may be short for: the suggestion line offers
      // `ORJEF` for a typed `JEF` (a borrowed county-line prefix), and testing
      // only the literal text refused every one of those — the menu showed a
      // row that Space could never take.
      final on = matchOn.isEmpty ? const {'code', 'name'} : matchOn;
      final inherited = _inheritedOptionValue(control);
      final acceptable = isAcceptableExchangeMatch(typed, chosen, matchOn: on) ||
          (inherited != null && isAcceptableExchangeMatch(inherited, chosen, matchOn: on));
      if (!acceptable) return false;
    }

    if (typed == chosen.code) return false;

    // A multi-value field keeps the values the operator has already entered:
    // only the one the cursor is in is replaced, and the cursor lands at the
    // end of it so typing the separator carries straight on to the next.
    final separator = _optionSeparatorFor(control);
    final controller = _textControllerFor(key);
    if (separator.isEmpty) {
      _controlTextValues[key] = chosen.code;
      controller.text = chosen.code;
    } else {
      final text = _controlTextValues[key] ?? '';
      final cursor = controller.selection.baseOffset;
      final replaced = replaceExchangeValueAt(
        text,
        cursor < 0 ? text.length : cursor,
        separator,
        chosen.code,
      );
      _controlTextValues[key] = replaced.text;
      controller.value = TextEditingValue(
        text: replaced.text,
        selection: TextSelection.collapsed(offset: replaced.cursor),
      );
    }
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
          ?_serialDescriptorFor(control),
      ];

  /// Runs `widget.decorateQsoBeforeSave` if wired, so an activity can project
  /// its ref data into generic QSON fields. Identity when no callback is
  /// supplied, which is every test and tooling path.
  Future<Map<String, dynamic>> _decorated(Map<String, dynamic> data) async {
    final decorate = widget.decorateQsoBeforeSave;
    if (decorate == null) return data;
    // A new contact has no `startAtMillis` yet (its time is automatic) and
    // belongs to the CURRENT segment — not the base, which is what
    // `effectiveAt(null)` answers.
    final at = data['startAtMillis'] as int?;
    return decorate(data, at == null ? _segmented.current : _segmented.effectiveAt(at));
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

  /// The sequence labels the previews were last claimed under. A band or mode
  /// change moves a scoped sequence to another label; the label it left is
  /// released, the rest keep their numbers.
  Set<String> _serialPreviewLabels = const {};

  /// The claims still settling, by control key — what a commit waits on.
  final Map<String, Future<int>> _pendingSerialClaims = {};

  /// Refreshes the previewed next number for each serial control — one query
  /// per sequence, and only when the declarations or their scope changed.
  ///
  /// Never while editing an existing QSO. That record's number was sent long
  /// ago and is restored from the ref by `_applyFieldsFromData`; the sequence's
  /// *next* number has nothing to do with it. Filling it here would overwrite a
  /// logged serial on a record that merely had its RST corrected, or invent one
  /// for a QSO that never carried a contest ref at all.
  ///
  /// Nor before the operator has put anything into the draft. A number is
  /// held against the other positions from the moment it is shown
  /// (docs/design/contests.md §5.8.1), so an idle panel holds nothing and
  /// shows nothing — a blank, never a tentative number that might move. The
  /// first edit — a typed call, a tapped spot, an exchange field touched —
  /// is what takes the number; a band or mode change from the radio is not
  /// an edit, and only moves a claim already held to its new label.
  Future<void> _refreshSerialPreviews() async {
    final sequences = widget.qsosRepository.sequences;
    if (sequences == null || widget.editingQso != null) return;

    final descriptors = <String, SequenceDescriptor>{};
    for (final control in _textControls) {
      final descriptor = _serialDescriptorFor(control);
      if (descriptor != null) descriptors[control['key'] as String] = descriptor;
    }
    if (descriptors.isEmpty) return;

    final hasContent = _call.trim().isNotEmpty || _touchedTextControls.isNotEmpty;
    if (!hasContent) {
      // Nothing composed — never started, or backspaced to nothing. An idle
      // panel holds nothing, so a number taken earlier goes back, and off the
      // screen with it.
      if (_serialPreviews.isEmpty && _serialPreviewLabels.isEmpty) return;
      _serialPreviews.clear();
      _serialPreviewLabels = const {};
      _serialPreviewSignature = null;
      _pendingSerialClaims.clear();
      widget.serialNumbers?.release(widget.operation.uuid);
      for (final key in descriptors.keys) {
        if (_touchedTextControls.contains(key)) continue;
        _controlTextValues.remove(key);
        _textControllerFor(key).clear();
      }
      if (mounted) setState(() {});
      return;
    }

    final qso = Qso(uuid: '', operationUuid: widget.operation.uuid, data: _getCurrentQsoData());
    final requests = {for (final entry in descriptors.entries) entry.key: entry.value.requestFor(qso)};
    final labels = {for (final request in requests.values) request.label};
    final signature = '${descriptors.keys.join(',')}|${labels.join(',')}';
    if (signature == _serialPreviewSignature && _serialPreviews.isNotEmpty) return;
    _serialPreviewSignature = signature;

    final source = widget.serialNumbers ?? LocalSerialNumberSource(sequences);
    // A scoped sequence keys off the band or mode: a label the draft has moved
    // off is let go — and only that one. An unscoped sequence beside it keeps
    // the number the operator may already have read.
    final moved = _serialPreviewLabels.difference(labels);
    if (moved.isNotEmpty) source.release(widget.operation.uuid, labels: moved);
    _serialPreviewLabels = labels;

    var changed = false;
    for (final entry in requests.entries) {
      final pending = source.claim(widget.operation.uuid, entry.value);
      _pendingSerialClaims[entry.key] = pending;
      final next = await pending;
      // A wipe or a scope change while the claim was settling: that answer is
      // for a draft that no longer exists, and the refresh it triggered fills
      // the field for the current one.
      if (!mounted || _serialPreviewSignature != signature) return;
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

  /// Waits for every serial claim still settling, so a commit never runs
  /// ahead of the number it is about to write. Needing the number is what
  /// settles it (docs/design/contests.md §5.8.1); the wait is bounded by the
  /// source's own cap. False when a claim failed and the commit must not go
  /// ahead.
  Future<bool> _settleSerialClaims() async {
    final pending = _pendingSerialClaims.values.toList();
    if (pending.isEmpty) return true;
    try {
      await Future.wait(pending);
      return true;
    } on Exception {
      // Already reported by the refresh that owns the claim (it awaits the
      // same future unguarded). Here it means the number never settled, and
      // a commit without it would be allocated blind to the peers — refused,
      // like a locked form: the fields keep everything typed.
      return false;
    }
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
  /// masks its absence — but on an existing QSO opened for editing, tabbing
  /// into a searchable exchange would show no offer at all while Space still
  /// rewrote the field.
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
    _serialPreviewLabels = const {};
    _pendingSerialClaims.clear();
    // Deliberately NOT releasing the held number here: an undo-wipe and an
    // edit opening over the draft pass through this too, and both put the
    // draft back. Only `_wipe` and a commit let a number go.
    for (final controller in _controlTextControllers.values) {
      controller.clear();
    }
    unawaited(_refreshSerialPreviews());
  }

  /// [data] with the duplicate-serial mark set wherever the number on a ref
  /// is one another position is known to have shown too
  /// (docs/design/contests.md §5.8.1). The number is written regardless —
  /// it went on the air — and the record says so.
  Map<String, dynamic> _withSerialConflicts(Map<String, dynamic> data) {
    final source = widget.serialNumbers;
    if (source == null) return data;
    final qso = Qso(uuid: '', operationUuid: widget.operation.uuid, data: data);
    for (final descriptor in _serialSequences) {
      final request = descriptor.requestFor(qso);
      final number = request.serialOn(qso);
      if (number != null && source.isConflicted(widget.operation.uuid, request, number)) {
        return {...data, Qso.serialConflictKey: true};
      }
    }
    return data;
  }

  /// Tells the number source the committed QSO's numbers are now in the log,
  /// so its hold on them ends without handing them out again meanwhile.
  void _releaseCommittedSerials(Qso qso) {
    final source = widget.serialNumbers;
    if (source == null) return;
    final committed = <SequenceRequest, int>{};
    for (final descriptor in _serialSequences) {
      final request = descriptor.requestFor(qso);
      final number = request.serialOn(qso);
      if (number != null) committed[request] = number;
    }
    source.release(widget.operation.uuid, committed: committed);
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

  /// Why this operation may not be written right now, or null when it may —
  /// a travelled clock over a non-test operation today, a shared operation
  /// this device only reads later (`WritePolicy`).
  ///
  /// Live rather than cached: the answer changes when the clock does, and
  /// `ClockTravel` is what rebuilds this widget when it happens.
  WriteRefused? get _writeRefusal => WritePolicy.forOperation(widget.operation);

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
  bool get _fieldsLocked =>
      _pendingDelete || (widget.editingQso?.deleted ?? false) || _writeRefusal != null;

  /// The default-focus rule's backstop (docs/design/logging-fields.md
  /// § Which field has focus), which owns the panel's Tab-trapping scope.
  late final _focusBackstop = DefaultFocusBackstop(
    target: () => _editingEvent ? _eventTextFocus : _callFocus,
    // `isCurrentOf`, not `of`: the latter would have every change to the
    // route's status rebuild the panel, not just push and pop over it.
    routeIsCurrent: () => ModalRoute.isCurrentOf(context) != false,
  );

  /// Editing an event/annotation row (NOTE, TODO, BREAK, …) rather than a
  /// contact — the main fields swap for [_buildEventFields], built from the
  /// same field primitives so the row's shape doesn't change, and every
  /// secondary control but Time is disabled (not hidden — see
  /// `SecondaryControlSpec.enabled`), since nothing else applies to a
  /// non-contact row.
  bool get _editingEvent => widget.editingQso?.isEvent ?? false;

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

  /// The Notes control's field. The value itself lives in
  /// [_currentQsoExtra] under `notes`, which is where the More pane reads
  /// and writes it and how it round-trips through [_applyFieldsFromData] — this
  /// controller is a second view onto that one value, not a second copy of
  /// it, so the two surfaces can never disagree about what the contact says.
  final _notesController = TextEditingController();
  final _notesFocus = FocusNode();

  /// True while `didUpdateWidget` is populating controllers from a newly
  /// selected `editingQso` — suppresses `_onCallChanged`'s lookup/command
  /// side effects, which would otherwise re-query and overwrite stored
  /// `their.*` fields for a call that's already known.
  bool _populating = false;

  /// A wiped-but-not-yet-lost new QSO, stashed by the wipe button so the
  /// same button can flip to "undo" for a few seconds afterward. Only
  /// meaningful while composing a new QSO (`editingQso == null`).
  final _wipeUndoSlot = TimedUndoSlot<Map<String, dynamic>>();

  /// The new QSO being composed, captured the instant the operator steps
  /// away to browse/edit an earlier one (`editingQso` going null → non-null)
  /// — restored in `didUpdateWidget` when they come back (non-null → null),
  /// whether that's Escape, Down off the list, or saving the edit. Unlike
  /// [_wipeUndoSlot] this never expires: it's not a "did you mean to lose
  /// this" offer, it's the draft's own state while attention is elsewhere.
  Map<String, dynamic>? _composingSnapshot;

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
    // Population normally happens in didUpdateWidget, as editingQso
    // transitions from null to a selected QSO — but if this widget is ever
    // constructed with editingQso already set (rather than transitioning
    // into it), that transition never fires. Applying it here too, before
    // any listeners are attached below, covers that case for free with no
    // risk of triggering their side effects.
    if (widget.editingQso != null) {
      _applyFieldsFromData(widget.editingQso!.data);
      if (widget.editingQso!.isEvent) {
        _applyEventFieldsFromData(widget.editingQso!.data);
        _seedFromRadioService();
      }
    } else {
      _seedFromRadioService();
      // Wins over the generic VFO seed above — a suggestion is specific
      // operator intent ("log THIS call"), the VFO seed is just ambient
      // radio state.
      if (widget.suggestedQso != null) {
        _applySuggestedQso(widget.suggestedQso!);
        // Remembered here as much as in didUpdateWidget: a panel built with a
        // suggestion already in hand — a cold start on a deeplink, a pane
        // remounted while a spot row is open — otherwise starts life believing
        // the call it was handed is an entry somebody composed, and refuses
        // every spot after it.
        _rememberSuggestedCall(tentative: widget.suggestedQsoIsTentative);
      }
    }
    _time.seedFields();
    _callController.addListener(_onCallChanged);
    _command.bind(widget.interpretationUpdates);
    _radio.bind();
    _time.bind();
    // After the seed above, so the initial state doesn't arrive twice.
    widget.radioUpdates?.addListener(_onRadioVfoChanged);
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
    // Same reason again, plus the Power chip's own summary, which reads the
    // field rather than the VFO (blur is what commits one to the other).
    _powerController.addListener(_onSentOrRcvdChanged);
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
      (_powerFocus, _powerController),
    ]) {
      focus.addListener(() {
        if (focus.hasFocus) {
          _notePrimaryFocus(focus);
          controller.selection = TextSelection.collapsed(
            offset: _takePendingCaretOffset(focus, controller) ?? controller.text.length,
          );
          if (identical(focus, _radio.freqFocus)) _radio.onFreqFocusChanged(hasFocus: true);
        } else if (identical(focus, _radio.freqFocus)) {
          _radio.onFreqFocusChanged(hasFocus: false);
        } else if (identical(focus, _powerFocus)) {
          // Committed on blur rather than on every keystroke: typing "100"
          // passes through 1 and 10, and each would be a power command sent
          // to the radio. Blur covers Enter too — it closes the control
          // (_onExpandedKeyEvent) and takes the focus with it.
          _commitPower();
        } else if (identical(focus, _sentFocus) || identical(focus, _rcvdFocus)) {
          // Show the operator what their shorthand became, at the moment they
          // are done with the field — the save expands it either way
          // (`_rstOrDefault`), so without this the record would carry a
          // report the field never displayed.
          final expanded = expandRST(controller.text, _radio.mode);
          if (expanded != controller.text) controller.text = expanded;
        }
        // A squeezed row hands the focused field its full width back
        // (`resolveMainFieldLayout`), which can only happen if a focus change
        // rebuilds. Off a squeezed row it would be a rebuild that changes
        // nothing, so it's gated on that — focus alone rebuilds nothing here
        // otherwise (see [_textFocusFor], where the exchange fields' own
        // listener has always had to setState for the same reason).
        if (_mainFieldsSqueezed) _rebuildBetweenFrames();
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
    _spotting.refreshSources();
    // Constructed already editing a QSO (rather than transitioning into it via
    // didUpdateWidget): score it so its pills show, and enqueue it for a
    // background lookup if it never got one — same as _populateFromEditingQso
    // does for the transition case. Scoring is guarded on _callInfoActive so
    // it only schedules a timer here — never setStates during initState;
    // enqueueLookup needs no such guard, it's fire-and-forget into the
    // caller's own queue.
    if (widget.editingQso != null) {
      if (_callInfoActive) {
        _lookup.scheduleScore();
        _lookup.refreshWorkedBefore();
      }
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
      focusSecondaryControls: _focusPillAndOpen,
      focusLastPrimaryField: _focusLastPrimaryField,
    );
    // Settles the serial previews' baseline: an idle panel shows no number
    // (docs/design/contests.md §5.8.1), but a panel constructed mid-contact —
    // a rebuild with the call already typed — takes its number now.
    unawaited(_refreshSerialPreviews());
    // A station that has never been set up has nothing in its VFO. Open the
    // Radio control so the operator is looking at the fields that need
    // answering, instead of finding out at log time that the contact can't be
    // written (HALO-24). Only while composing — an existing QSO carries its
    // own recorded band and mode — and only once per mount, so an operator who
    // closes it isn't fought by the next rebuild. Post-frame because
    // `_onSelectControl` calls setState, which initState cannot.
    if (widget.editingQso == null) {
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
    // First, before any of the guards below can return: see [_handleLogRequest].
    final request = widget.logRequest;
    final logRequested = request != null && request.serial != oldWidget.logRequest?.serial;
    if (logRequested) {
      // The commit asks its own question, about the same gesture — so a peek
      // held from the way in has nothing left to say.
      _heldSuggestion = null;
      unawaited(_handleLogRequest(request.qso));
    }
    // Power may have just come into play — the operator added the control to
    // the row, or switched station-info tracking on. The field is seeded from
    // the VFO only while power IS in play, so without this it stays empty
    // until the next VFO notification, and a QSO logged in between carries
    // none. Decided from the inputs rather than a remembered flag: a `late`
    // field's initializer runs on its first READ, which is here, and would
    // simply record the new state and see no change.
    final controlsChanged = oldWidget.trackingPower != widget.trackingPower ||
        !const ListEquality<String>().equals(oldWidget.controlOrder, widget.controlOrder) ||
        !const SetEquality<String>().equals(oldWidget.hiddenControlKeys, widget.hiddenControlKeys);
    if (controlsChanged && _powerInPlay && widget.editingQso == null && !_powerFocus.hasFocus) {
      final power = widget.radioService?.vfoA.power;
      _powerController.text = power == null ? '' : '$power';
    }
    // The rest of the slide's lifecycle, up here for the same reason: an edit
    // in progress is exactly when a tentative suggestion has something to say,
    // and the guards below would swallow all three of these.
    if (oldWidget.suggestedQso != null && widget.suggestedQso == null) _withdrawTentativeSuggestion();
    if (!logRequested &&
        widget.suggestedQsoIsTentative &&
        widget.suggestedQso != null &&
        !identical(oldWidget.suggestedQso, widget.suggestedQso) &&
        (widget.editingQso != null || _hasComposedCall)) {
      // Held rather than applied — and rather than dropped: the operator gets
      // it back the moment the gesture settles.
      //
      // Never on the frame a log request lands. A commit carries a fresh
      // suggestion of its own alongside the request, and holding THAT arms a
      // question about a gesture that has already finished: it survives the
      // log, and the next row to settle raises a prompt about a station the
      // operator dealt with long ago — which, accepted, replaces the one they
      // are working and retunes the radio to it.
      _heldSuggestion = widget.suggestedQso;
    }
    if (widget.suggestionSettledSerial != oldWidget.suggestionSettledSerial) {
      final held = _heldSuggestion;
      if (held != null) {
        _heldSuggestion = null;
        unawaited(_confirmHeldSuggestion(held));
      }
    }
    // Withdraw from the controller we actually published to. `deactivate` only
    // ever sees the CURRENT one, so without this a swapped controller keeps a
    // row nothing can ever take back.
    if (!identical(oldWidget.keyboardAccessory, widget.keyboardAccessory)) {
      oldWidget.keyboardAccessory?.clearIfOwner(this);
    }
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
      // A per-QSO callsign-lookup refresh (`_refreshActivityControlsFor`) can
      // have cached a snapshot of `activityControls` from BEFORE this ref was
      // added — `_effectiveActivityControls` prefers that cache over
      // `widget.activityControls`, so without this a contest's exchange field
      // stays invisible for the rest of the composing session even after the
      // operation-level refresh above lands, until something else (a wipe, an
      // edit ending) happens to clear it. The generation bump additionally
      // catches a refresh that was ALREADY IN FLIGHT when this change
      // happened — see `_activityControlsGeneration`'s own doc comment.
      _refreshedActivityControls = null;
      _activityControlsGeneration++;
      // `_scheduleLookup` only re-fetches per-QSO controls when the active
      // call CHANGES (`_lookup.lookupFor == activeCall` short-circuits it) — so
      // clearing the cache here would otherwise silently drop an
      // already-resolved lookup's guessed field (a suggested grid, say)
      // for the rest of the composing session, with nothing left to bring
      // it back except retyping the callsign.
      if (_lookup.lookupFor != null) unawaited(_refreshActivityControlsFor(_lookup.lookupFor!));
      unawaited(_refreshSerialPreviews());
    }
    // The source is the panel's only handle on its held number: a source
    // swapped out (sharing switched off) or an operation swapped under the
    // panel would otherwise leave that number held with nothing left to
    // release it — and served again the moment the source came back.
    if (widget.editingQso == null &&
        (oldWidget.serialNumbers != widget.serialNumbers || oldWidget.operation.uuid != widget.operation.uuid)) {
      oldWidget.serialNumbers?.release(oldWidget.operation.uuid);
      _serialPreviews.clear();
      _serialPreviewSignature = null;
      _serialPreviewLabels = const {};
      _pendingSerialClaims.clear();
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
        focusSecondaryControls: _focusPillAndOpen,
        focusLastPrimaryField: _focusLastPrimaryField,
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
      // Captured before _resetEditingSessionState() below, which clears
      // _theirNameOverride — a snapshot taken after that would silently drop
      // a name entered via the More pane.
      if (oldWidget.editingQso == null && widget.editingQso != null) {
        _composingSnapshot = _getCurrentQsoData(composing: true);
      }
      _resetEditingSessionState();
      if (widget.editingQso != null) {
        _populateFromEditingQso(widget.editingQso!);
      } else {
        final composingSnapshot = _composingSnapshot;
        _composingSnapshot = null;
        _resetLocalFields();
        if (composingSnapshot != null) {
          // Same restore idiom as _restoreFromUndoSlot: overlay the draft
          // back on top of the blank fields _resetLocalFields just seeded.
          _populating = true;
          _applyFieldsFromData(composingSnapshot);
          _time.manualStartAtMillis = composingSnapshot['startAtMillis'] as int?;
          // _applyFieldsFromData only sets the controllers' text — it never
          // touches these, and _resetLocalFields just cleared them. A
          // grid/state the operator had typed (present in the snapshot only
          // because it was touched — see _getCurrentQsoData's `composing`
          // branch) would otherwise show on screen but silently drop out of
          // the saved record, since _getCurrentQsoData gates their.grid/
          // their.state on the flag, not on the controller text.
          final theirSnapshot = composingSnapshot['their'] as Map<String, dynamic>?;
          _gridTouched = theirSnapshot?.containsKey('grid') ?? false;
          _stateTouched = theirSnapshot?.containsKey('state') ?? false;
          setState(() {});
          _populating = false;
          // Same reasoning as _restoreFromUndoSlot: _populating suppressed
          // _onCallChanged's own _scheduleLookup()/_lookup.scheduleScore(), and
          // _resetLocalFields already cleared the lookup cache and score
          // notices — without this the restored callsign sits unenriched,
          // without its dupe/New-* pills, until the operator edits the call
          // field again.
          _scheduleLookup();
          _lookup.scheduleScore();
        }
      }
      // Self- vs other-spot eligibility can differ per extension (e.g. only
      // self-spotting an operation with an activation ref) — re-fetch
      // whenever what's being spotted changes.
      _spotting.forgetSources();
      _spotting.refreshSources();
      // The fields are this panel's own again, which is exactly what anything
      // parked was waiting for — and this branch returns, so it has to drain
      // here rather than leave it to the bottom of the method.
      _drainPending();
      return;
    }
    // Nothing below applies while editing an existing QSO — a suggestion or
    // a refs change must never clobber an in-progress edit.
    if (widget.editingQso != null) return;

    // While composing a new QSO, self-spot eligibility depends on the
    // operation's own activation refs (not editingQso, which stays null
    // throughout) — refresh when those refs change too.
    if (!identical(oldWidget.operation.data['refs'], widget.operation.data['refs'])) {
      _spotting.refreshSources();
    }

    // A new suggestion (e.g. tapping a different spot) — same reset scope
    // as the editingQso-change branch above, applied for it instead.
    // Deliberately independent from the refs check above (not `else if`),
    // so both can fire in the same call — e.g. an operation-refs change and
    // a spot tap landing in the same frame would otherwise let one silently
    // suppress the other.
    if (widget.suggestedQso != null && !identical(oldWidget.suggestedQso, widget.suggestedQso)) {
      // A gesture the operator can still drag back may not take the fields or
      // the VFO from work already in progress — it was held above instead.
      if (widget.suggestedQsoIsTentative && _hasComposedCall) return;
      _resetEditingSessionState();
      _applySuggestedQso(widget.suggestedQso!);
      _rememberSuggestedCall(tentative: widget.suggestedQsoIsTentative);
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
  /// Called from BOTH ends of `didUpdateWidget`, because the update that
  /// clears the edit is the editing-change branch, and that branch returns
  /// before the bottom of the method ever runs. Draining only at the bottom
  /// leaves the work parked until some unrelated rebuild — a spot poll, a
  /// clock tick — picks it up seconds later, on top of whatever the operator
  /// has typed since, moving the VFO with it.
  void _drainPending() {
    if (widget.editingQso != null) return;
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
    // over the list the operator is still working. And behind `_populating`,
    // which is what stops the clear from reaching `onCallEdited`: this runs
    // from didUpdateWidget, so the listener would report the operator editing
    // the field — from inside a build, to a view that has already built. Any
    // OTHER callback this wipe fires is under the same constraint.
    _populating = true;
    _wipe(focusCall: false);
    _populating = false;
  }

  /// Puts a held suggestion to the operator, and applies it if they clear the
  /// way. Declining keeps their work — [confirmLogOverwrite] surfaces this
  /// panel so they land on it — and leaves the row to ask again if the
  /// gesture is carried through to a commit.
  Future<void> _confirmHeldSuggestion(Map<String, dynamic> qso) async {
    final editing = widget.editingQso != null;
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
    if (!identical(widget.suggestedQso, qso)) return;
    if (editing) {
      // Comes back as a widget update with `editingQso` null; the suggestion
      // waits for it rather than filling fields that still belong to the edit.
      widget.onEditCanceled?.call();
      _pendingSuggestion = qso;
      return;
    }
    _applyTentativeSuggestion(qso);
  }

  /// Puts [LoggingControls.confirmLogOverwrite]'s question to the operator,
  /// from OUTSIDE the frame that decided to ask it.
  ///
  /// Both askers run from `didUpdateWidget` — deliberately, so neither is
  /// swallowed by the editing guards there — which is the build phase, with
  /// the Navigator mid-flush. A route pushed into it from there trips the
  /// Navigator's own `!_debugLocked` assertion when the push animation lands,
  /// and what reaches the operator is a crash where the question should be.
  Future<bool> _askOverwrite({required bool editing}) {
    final confirm = widget.confirmLogOverwrite;
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

  /// A [LoggingControls.logRequest] that is waiting for an edit to be
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
    final editing = widget.editingQso != null;
    if (editing || _hasComposedCall) {
      // Something here would be destroyed. Never silently: the operator is
      // looking at the spots list, and the work at risk is on a surface they
      // cannot see from there.
      final clear = await _askOverwrite(editing: editing);
      if (!mounted || !clear) return;
      if (editing) {
        // Comes back as a widget update with `editingQso` null; the request
        // waits for it rather than filling fields that still belong to the edit.
        widget.onEditCanceled?.call();
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
  /// into the next — shared by the editingQso-change and suggestedQso-change
  /// paths in `didUpdateWidget`, which both start a fresh context.
  void _resetEditingSessionState() {
    _pendingDelete = false;
    _theirNameOverride = null;
    _gridTouched = false;
    _stateTouched = false;
    _wipeUndoSlot.clear();
  }

  /// Populates controllers/state from an existing QSO selected for editing.
  /// Local-state only — never calls parent-notifying callbacks (this runs
  /// from `didUpdateWidget`, where a synchronous `setState` back up the
  /// tree could throw).
  void _populateFromEditingQso(Qso qso) {
    _suggestedCall = null;
    _suggestionWasTentative = false;
    _populating = true;
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
    _populating = false;
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
    widget.enqueueLookup?.call(qso);
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
    _populating = true;
    _applyFieldsFromData(data);
    // Read from `data`, since `_applyFieldsFromData` strips the key rather
    // than carrying it into `_currentQsoExtra`.
    final suggestedStart = data['startAtMillis'];
    _time.manualStartAtMillis = suggestedStart is int ? suggestedStart : null;
    setState(() {});
    _populating = false;
    // A tapped spot starts a contact as surely as a typed call does, and it
    // bypasses `_onCallChanged` — so the serial number is taken here.
    unawaited(_refreshSerialPreviews());
    // Populating a suggestion sets the call without the user typing, so
    // `_populating` suppressed _onCallChanged's own lookup and score
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
    if (widget.editingQso == null &&
        (data['freq'] != null || data['band'] != null || data['mode'] != null)) {
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
  /// push a `data` map from a `Qso`/`_getCurrentQsoData()` shape back into
  /// the live controllers/state.
  void _applyFieldsFromData(Map<String, dynamic> data) {
    final our = asQsonMap(data['our']) ?? const {};
    final their = asQsonMap(data['their']) ?? const {};
    _callController.text = asQsonString(their['call']) ?? '';
    _sentController.text = asQsonString(our['sent']) ?? '';
    _rcvdController.text = asQsonString(their['sent']) ?? '';
    // Only the entered value fills the field; a guess (their.guess) stays a
    // faint placeholder (see the Grid/State decorations) instead of being
    // pre-filled as if it were a confirmed value.
    _gridController.text = asQsonString(their['grid']) ?? '';
    _stateController.text = asQsonString(their['state']) ?? '';
    // Restore the name override too, or wipe-then-undo would silently drop a
    // name set via the "More" pane (it round-trips as `their.name`).
    final theirName = asQsonString(their['name'])?.trim();
    _theirNameOverride = (theirName == null || theirName.isEmpty) ? null : theirName;
    final freq = asQsonNum(data['freq'])?.toDouble();
    if (freq != null) {
      _radio.setFrequency(freq);
    } else {
      _radio.setBand(asQsonString(data['band']));
    }
    _radio.mode = asQsonString(data['mode']) ?? _radio.mode;
    final power = asQsonNum(data['power']);
    _powerOnRecord = power != null;
    _powerController.text = power == null ? '' : '$power';
    // A wholesale repopulate — a spot tapped, a QSO opened for editing —
    // replaces every field, so nothing in a dropdown survives it either.
    _radio.resyncDropdownFields();
    // Restore the More pane's operator/position overrides for the same reason
    // the name above is restored: wipe-then-undo, and stepping into an edit
    // and back out, both round-trip the draft through here, and a dropped
    // override would silently hand the contact back to the operation's stamp.
    //
    // Only for a DRAFT (no `uuid`). A record already in the log carries its
    // own `our` block, which `_getCurrentQsoData` reads straight from
    // `editingQso` — recording it as an override too would mark an untouched
    // record as composed.
    _ourExtra.clear();
    _theirExtra.clear();
    if ((asQsonString(data['uuid']) ?? '').isEmpty) {
      for (final key in const ['operatorCall', 'multiIdentifier']) {
        if (our.containsKey(key)) _ourExtra[key] = asQsonString(our[key]) ?? '';
      }
      // Raw, not coerced: these are a mix of strings and numbers, and
      // `normalizeQsoQson` has already given each one the type its table
      // names. A null is kept as a null — that is a coordinate the pane
      // deliberately cleared, and dropping it would let the old one return.
      for (final key in theirPaneKeys) {
        if (their.containsKey(key)) _theirExtra[key] = their[key];
      }
    }
    _currentQsoExtra
      ..clear()
      ..addAll(data)
      ..remove('refs')
      ..remove('our')
      ..remove('their')
      ..remove('freq')
      ..remove('band')
      ..remove('mode')
      ..remove('power')
      ..remove('startAtMillis');
    // The Notes control's second view onto `notes`, re-seeded with it. Read
    // back out of the map rather than from `data`, so the two can only ever
    // show the same string.
    _notesController.text = (_currentQsoExtra['notes'] as String?) ?? '';
    _controlRefs.clear();
    _guessedRefs = const [];
    _guessedRefsForCall = null;
    _unmatchedRefs = [];
    _clearTextControls();
    final refs = (asQsonList(data['refs']))?.whereType<Map<dynamic, dynamic>>().map((r) => r.cast<String, dynamic>()) ?? const [];
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
    _lookup.reset();
    _selectedControlKey = null;
    // Command state must never survive into a freshly populated QSO
    // context: this runs under `_populating`, so _onCallChanged's own
    // per-keystroke reset is suppressed. Without this, typing "NOTE hi",
    // then tapping a spot, would leave the call field showing a real
    // callsign while still in the note's mixed-case free-text mode — and a
    // stale complete interpretation would make Space insert a literal
    // space (or Enter execute the old command) instead of acting on the
    // callsign.
    _command.reset();
  }

  /// Populates the NOTE/TODO inline editor from an event row's `event` map
  /// — the only kinds with editable free text. Reads `note` with the same
  /// `description` fallback [AnnotationRow] displays with, and a TODO's
  /// `data.done` with the same bare-`done` fallback for older synced logs.
  void _applyEventFieldsFromData(Map<String, dynamic> data) {
    final event = data['event'] as Map<String, dynamic>?;
    // Same `description` before `note` precedence [AnnotationRow] displays
    // with — `_eventDataForSave` writes back to whichever one this reads,
    // so a NOTE/TODO synced from elsewhere under `description` keeps
    // agreeing with what the log shows for it. Deliberately NOT trimmed:
    // `_eventDataForSave` isn't either (see its own note), so a row loaded
    // and saved untouched round-trips exactly — trimming just this side
    // would make selecting a row with incidental whitespace read as
    // "changed" on its own, with no edit made.
    _eventTextController.text =
        (event?['description'] as String?) ?? (event?['note'] as String?) ?? '';
    final eventData = event?['data'];
    _eventTodoDone =
        (eventData is Map && eventData['done'] == true) || event?['done'] == true;
  }

  /// The `data` to save for an edited event row: the original payload with
  /// only the Time control's timestamp and, for a NOTE/TODO, the inline
  /// editor's text/done state overlaid on top. BREAK/START/END/SOLAR/WEATHER
  /// carry no other editable field yet, so only the timestamp moves for them.
  Map<String, dynamic> _eventDataForSave(Qso editingQso) {
    final data = Map<String, dynamic>.from(editingQso.data);
    final startAtMillis = _time.effectiveStartAtMillis;
    if (startAtMillis != null) data['startAtMillis'] = startAtMillis;
    final kind = editingQso.eventKind;
    if (kind == 'note' || kind == 'todo') {
      final event = Map<String, dynamic>.from(editingQso.event ?? const {});
      // Not trimmed — see `_applyEventFieldsFromData`'s matching note; the
      // two must read and write the exact same string or an untouched
      // field falsely reads as edited.
      final text = _eventTextController.text;
      // Write back to whichever key `_applyEventFieldsFromData` actually
      // read this from — a row synced in under `description` must keep
      // agreeing with what AnnotationRow displays for it, not silently
      // gain a `note` nothing reads while the old `description` lingers.
      if (event.containsKey('description')) {
        event['description'] = text;
      } else {
        event['note'] = text;
      }
      if (kind == 'todo') {
        // `is Map`, not a cast — same guard as the sibling reads of this
        // field (`_applyEventFieldsFromData` above, `AnnotationRow._iconName`
        // in qso_list.dart): a malformed/cross-client value here must not
        // crash the panel just because this row got selected.
        final rawEventData = event['data'];
        final eventData = Map<String, dynamic>.from(
          rawEventData is Map ? rawEventData.cast<String, dynamic>() : const {},
        );
        eventData['done'] = _eventTodoDone;
        event['data'] = eventData;
        // Older synced logs may also carry a bare `event.done` (the fallback
        // `_applyEventFieldsFromData` reads) — clear it, or a saved
        // `false` here would keep losing to a stale `true` there forever.
        event.remove('done');
      }
      data['event'] = event;
    }
    return data;
  }

  /// One of the panel's models changed something it paints — a typed
  /// frequency, a resolved lookup, a command's describe preview. None of
  /// them notifies during build (the Radio control's one build-phase write
  /// defers itself a frame), so a direct `setState` here is safe.
  void _onModelChanged() {
    if (!mounted) return;
    setState(() {});
  }

  /// Seeds the Radio control from the operation's `vfoA`
  /// ([RadioControlModel.seedFromVfo]), and the Power field with it — that
  /// one is the panel's, with its own rule about whose typing it may
  /// overwrite. Never called while editing an existing *contact*, whose own
  /// recorded values always take priority (`_applyFieldsFromData`); an
  /// event's freq/mode are sentinels instead of a record, so
  /// `_populateFromEditingQso` calls this for one anyway, same as composing.
  void _seedFromRadioService({bool skipFrequency = false}) {
    final vfo = widget.radioService?.vfoA;
    if (vfo == null) return;
    _radio.seedFromVfo(skipFrequency: skipFrequency);
    // Never over the operator's own typing, and never over a QSO already
    // logged — an existing record's power is its own (`_applyFieldsFromData`
    // seeds it), not whatever the rig happens to be set to now.
    if (_powerInPlay && widget.editingQso == null && !_powerFocus.hasFocus) {
      final text = vfo.power == null ? '' : '${vfo.power}';
      if (_powerController.text != text) _powerController.text = text;
    }
  }

  /// The VFO moved underneath us — a connected radio was tuned, or
  /// something else in the app wrote to it. Mirror it into the Radio
  /// control, but never over the operator.
  void _onRadioVfoChanged() {
    if (!mounted) return;
    // An existing QSO's own recorded freq/band/mode always wins; ambient
    // radio state must not rewrite something already logged. An event's
    // freq/mode are sentinels, not a record — its Radio control keeps
    // following the live VFO the whole time it's open, same as composing.
    if (widget.editingQso != null && !widget.editingQso!.isEvent) return;
    final previousBand = _radio.band;
    final previousMode = _radio.mode;
    setState(() {
      // Suppresses the frequency listener's push-back. Without it, seeding a
      // value the radio just reported arms the 5s debounce and sends it
      // straight back at the radio, forever.
      final wasPopulating = _populating;
      _populating = true;
      // Skip only the frequency, never the whole seed: suppressing it
      // entirely would drop a mode the rig reported meanwhile, and the
      // pending push would then send the panel's stale mode back — taking a
      // rig the operator had just put into CW back out of it, and logging
      // USB at 59.
      _seedFromRadioService(skipFrequency: _radio.freqTouched);
      _populating = wasPopulating;
    });
    // `_populating` above suppressed the frequency listener's own rescore, and the
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
    // below) from calling widget.onCommandMessageChanged — a parent-state
    // setState — while still inside didUpdateWidget.
    _populating = true;
    _callController.clear();
    _clearRSTs();
    _gridController.clear();
    _stateController.clear();
    _gridTouched = false;
    _stateTouched = false;
    _lookup.cancelLookup();
    // `_radio.freqTouched` outlives this reset otherwise, and live radio follow
    // stays switched off for the rest of the session.
    _radio.settlePendingFreqEdit(flush: false);
    _lookup.reset();
    _controlRefs.clear();
    _guessedRefs = const [];
    _guessedRefsForCall = null;
    _unmatchedRefs = [];
    _clearTextControls();
    _currentQsoExtra.clear();
    _notesController.clear();
    _ourExtra.clear();
    _theirExtra.clear();
    _time.manualStartAtMillis = null;
    _radio.manualBand = null;
    _selectedControlKey = null;
    _clearPowerEntry();
    // Back to composing a new QSO — the Radio control goes back to
    // mirroring the operation's VFO, not whatever the just-edited QSO's
    // own freq/band/mode happened to be.
    _seedFromRadioService();
    setState(_command.reset);
    _populating = false;
  }

  @override
  void dispose() {
    // Leaving the operation lets its number go (docs/design/contests.md
    // §5.8.1): a hold with no panel behind it would block the other
    // positions for as long as the operator stays away.
    if (widget.editingQso == null) widget.serialNumbers?.release(widget.operation.uuid);
    // A published row would otherwise outlive this panel, hanging over
    // whatever replaced it with a handler that types into nothing. The
    // controller defers the write when the tree is locked, which it is here
    // (dispose runs inside `finalizeTree`) — and `deactivate` is no better,
    // since that runs during build.
    widget.keyboardAccessory?.clearIfOwner(this);
    widget.onDispatcherChanged?.call(null);
    widget.controller?.detach();
    widget.radioUpdates?.removeListener(_onRadioVfoChanged);
    ClockTravel.instance.removeListener(_onClockTravelChanged);
    WidgetsBinding.instance.removeObserver(this);
    _lookup.dispose();
    _command.dispose();
    _wipeUndoSlot.dispose();
    _spotting.dispose();
    _notesController.dispose();
    _notesFocus.dispose();
    for (final controller in _controlTextControllers.values) {
      controller.dispose();
    }
    for (final node in _controlRefFocus.values) {
      node.dispose();
    }
    for (final controller in _controlRefController.values) {
      controller.dispose();
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
    _gridController.dispose();
    _stateController.dispose();
    _powerController.dispose();
    _eventTextController.dispose();
    _focusBackstop.dispose();
    _eventTextFocus.dispose();
    _callFocus.dispose();
    _sentFocus.dispose();
    _rcvdFocus.dispose();
    _gridFocus.dispose();
    _stateFocus.dispose();
    _powerFocus.dispose();
    _time.dispose();
    _radio.dispose();
    super.dispose();
  }

  /// The call field as the panel reads it — see [CallFieldText] for the
  /// rules. A fresh snapshot of the text and the cursor on every read, so a
  /// rule never sees a cursor that moved after the text it was paired with.
  CallFieldText get _callText => CallFieldText(
        _callController.text,
        cursor: _callController.selection.baseOffset,
        stacking: widget.editingQso == null,
      );

  String get _call => _callText.call;
  List<String> get _callList => _callText.callList;
  bool get _isCallStackField => _callText.isStack;
  Iterable<String> get _callsInField => _callText.callsInField;
  String get _callAtCursor => _callText.callAtCursor;

  /// The operation QSON with `uuid` folded in — same shape as the Dart
  /// side's `qsonPayloadFor` gives every coarse hook call. Command hooks
  /// need the uuid to fetch log data through the runtime's
  /// `ctx.getOperation`/`ctx.getQsos` (e.g. dev-commands' SEED reading the
  /// existing log's time range); the QSON alone doesn't carry it.
  Map<String, dynamic> get _operationDataForCommands => {
        ...widget.operation.data,
        'uuid': widget.operation.uuid,
      };

  bool get _canLog {
    // Call stacking (issue #7): "//" takes priority over a comma-separated
    // list — "//"-separated calls/fragments aren't a single valid callsign,
    // but log is still possible as long as one of the stacked segments is —
    // see [CallFieldText.pickStackedCall]. Only while composing a new QSO.
    if (_isCallStackField) {
      return _callText.pickStackedCall() != null;
    }
    return _callList.isNotEmpty && _callList.every(looksLikeCallsign);
  }

  /// Note expansion inside a stack (issue #17 × issue #7): asks the command
  /// hooks to expand the segment under the cursor, and splices the result
  /// back into just that segment — "KI2D//1AB" becomes "KI2D//W1AB,W1AC",
  /// which the NEXT Enter logs as a stacked call list. Returns whether it
  /// expanded anything, in which case this Enter logs nothing at all.
  ///
  /// This exists because [_log]'s ordinary command path only ever sees the
  /// WHOLE field, so a key stacked alongside other calls would never be
  /// offered for expansion at all. A whole-field "//KEY" that path already
  /// expanded never arrives here — it returned. One it could not expand does
  /// arrive, asks the identical question, and gets the identical no.
  Future<bool> _expandStackedNote() async {
    if (widget.editingQso != null || widget.interpretCommand == null || !_isCallStackField) return false;
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
    if (!widget.jumpAfterRST || _populating || !focus.hasFocus) return;
    // Null on the FT modes, whose report has no fixed length — there is no
    // moment to call "done", so the setting simply doesn't apply.
    final full = rstLengthFor(_radio.mode);
    if (full == null) return;
    if (previous < full && length >= full) _advancePrimaryFocus();
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
  String? get _rstPlaceholder => widget.editingQso == null ? _defaultRST : null;

  String get _defaultRST => defaultRSTFor(
        _radio.mode,
        phone: widget.defaultReport,
        cw: widget.defaultReportCW,
        snr: widget.defaultReportFT8,
      );

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
  List<({FocusNode focus, TextEditingController controller, String label})> get _rstPair {
    final pair = [
      (focus: _sentFocus, controller: _sentController, label: t.loggingControls.sent),
      (focus: _rcvdFocus, controller: _rcvdController, label: t.loggingControls.rcvd),
    ];
    return widget.switchSentRcvd ? pair.reversed.toList() : pair;
  }

  /// The More pane's own report fields, keyed by the form's field names rather
  /// than by controller — the pane round-trips values through a `Map`, not
  /// through [_rstPair]'s controllers, so it needs the order in its own terms.
  List<String> get _rstPaneKeyOrder => widget.switchSentRcvd ? const ['rcvd', 'sent'] : const ['sent', 'rcvd'];

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

  /// One text controller per activity ref control, same reasoning as
  /// [_controlRefFocus] — owned here so cursor-key field-hopping can read the
  /// caret position without reaching into [RefTextInput]'s own State.
  final Map<String, TextEditingController> _controlRefController = {};

  TextEditingController _refControllerFor(String key) => _controlRefController[key] ??= TextEditingController();

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
        return _powerFocus;
      case 'spotting':
        return _spotting.state.showComment ? _spotting.commentFocus : null;
      case 'notes':
        return _notesFocus;
      default:
        // Every remaining control is an extension's. Only `refList` builds a
        // field to focus — the same condition that gave it a chip.
        final control = _effectiveActivityControls
            .where((c) => c['key'] == key && (c['input'] as Map?)?['kind'] == 'refList')
            .firstOrNull;
        return control == null ? null : _refFocusFor(key);
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
  /// [_crossToNextControl] — so Band and Mode being here only matters for
  /// Tab/Shift-Tab, which do still visit them.
  List<(FocusNode, TextEditingController)> _expandedFieldOrderFor(String key) {
    switch (key) {
      case 'time':
        return [(_time.timeFocus, _time.timeController), (_time.dateFocus, _time.dateController)];
      case 'radio':
        return [
          (_radio.bandFocus, _radio.bandController),
          (_radio.freqFocus, _radio.freqController),
          (_radio.modeFocus, _radio.modeController),
        ];
      case 'power':
        return [(_powerFocus, _powerController)];
      case 'spotting':
        return _spotting.state.showComment ? [(_spotting.commentFocus, _spotting.commentController)] : const [];
      case 'notes':
        return [(_notesFocus, _notesController)];
      default:
        final control = _effectiveActivityControls
            .where((c) => c['key'] == key && (c['input'] as Map?)?['kind'] == 'refList')
            .firstOrNull;
        return control == null ? const [] : [(_refFocusFor(key), _refControllerFor(key))];
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
  /// Returns the pill it landed on (null when there were none), so callers
  /// that also need to open it don't have to re-derive the same target.
  ///
  /// The strip scrolls horizontally and can hold more pills than fit, so a
  /// focused pill also has to be scrolled into view: focus alone doesn't move
  /// a viewport.
  String? _focusPill([String? key]) {
    final order = _pillOrder;
    if (order.isEmpty) return null;
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
    return target;
  }

  /// [_focusPill], then opens whatever it landed on — the single motion that
  /// replaces the old separate "land on the pill, then Enter to open" steps.
  /// Skips `more`: it pops a dialog rather than expanding inline, and arriving
  /// by keyboard shouldn't trigger that on its own (Enter still does, same as
  /// a tap).
  void _focusPillAndOpen([String? key]) {
    final target = _focusPill(key);
    if (target == null) return;
    if (target == 'more') {
      // more never opens, but whatever WAS open (a control left visibly
      // expanded from before this Up, e.g. a mouse click into a main field)
      // still needs to close.
      if (_selectedControlKey != null) setState(() => _selectedControlKey = null);
      return;
    }
    _onSelectControl(target);
  }

  /// Crosses onto [key]'s pill for Tab/Shift-Tab — opens its control (unless
  /// `more`, which pops a dialog rather than expanding) and lands on its own
  /// first (`fromStart: true`) or last field, NOT the one field it opens into
  /// on a tap or on arrival via Up (`_focusPillAndOpen`'s target — Radio's
  /// Frequency, the field the operator actually types into). Landing there
  /// from a Tab crossing in from Time would skip Band entirely. A fieldless
  /// control just leaves the keyboard on its own chip, same as
  /// `_focusPillAndOpen`.
  ///
  /// Left/Right go through [_crossToNextControl] instead, which always lands
  /// on the canonical field regardless of direction — see its own doc for why.
  void _crossToPill(String key, {required bool fromStart}) {
    _focusPill(key);
    if (key == 'more') {
      // more never opens, but whatever WAS open (crossed in from) still
      // needs to close — otherwise its panel is left rendered under a
      // keyboard that already moved on.
      if (_selectedControlKey != null) setState(() => _selectedControlKey = null);
      return;
    }
    setState(() {
      if (key == 'time' && _selectedControlKey != 'time') _time.seedFields();
      _selectedControlKey = key;
    });
    final fields = _expandedFieldOrderFor(key);
    if (fields.isEmpty) return;
    final target = fromStart ? fields.first.$1 : fields.last.$1;
    _requestFocusOnceBuilt(key, target);
  }

  /// Requests focus for [target], a field belonging to [key]'s control,
  /// retrying one extra frame later if it can't take focus yet.
  ///
  /// A DropdownMenu field (Band/Mode) re-entered after being closed needs a
  /// frame of its own beyond the rebuild that reopens it: closing disables
  /// the supplied FocusNode's `canRequestFocus` as part of tearing the
  /// internal widget down, and DropdownMenu restores it (our own
  /// `expandedBuilder` sets it back to `typeable`) only once ITS rebuild has
  /// run — which can land one frame after ours. A single post-frame
  /// callback can lose that race and silently do nothing (`requestFocus()`
  /// on a non-requestable node is a no-op), so this retries once rather than
  /// leaving the keyboard nowhere.
  void _requestFocusOnceBuilt(String key, FocusNode target) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedControlKey != key) return;
      if (target.canRequestFocus) {
        target.requestFocus();
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedControlKey == key) target.requestFocus();
      });
    });
  }

  /// Moves from field [currentIndex] of [key]'s own field list (`-1` when it
  /// can't be determined) to the next (`forward`) or previous one, or — once
  /// [key]'s own fields are exhausted — across to the neighbouring pill via
  /// [_crossToPill], wrapping at both ends of the strip. Tab and Shift-Tab's
  /// own move — a control with several fields (Time's Date, Radio's Band and
  /// Mode) is walked in full before the strip moves on. Cursor keys use
  /// [_crossToNextControl] instead: they treat a whole control as one stop,
  /// same as they treat one main field.
  void _stepSecondaryField(String key, int currentIndex, {required bool forward}) {
    final fields = _expandedFieldOrderFor(key);
    final next = forward ? currentIndex + 1 : currentIndex - 1;
    if (next >= 0 && next < fields.length) {
      fields[next].$1.requestFocus();
      return;
    }
    final order = _pillOrder;
    final pillIndex = order.indexOf(key);
    if (pillIndex < 0 || order.isEmpty) return;
    _crossToPill(order[(pillIndex + (forward ? 1 : -1)) % order.length], fromStart: forward);
  }

  /// Crosses straight to the next (`forward`) or previous pill, wrapping at
  /// both ends of the strip, and lands on ITS `_expandedFocusFor` target —
  /// the one field a tap or arriving via Up focuses (Radio's Frequency) —
  /// rather than a first-or-last pick from [_expandedFieldOrderFor]. Unlike
  /// [_stepSecondaryField] (Tab's own move), this never stops at a sibling
  /// field within [key]'s own control first, and unlike [_crossToPill] it
  /// doesn't care which direction it arrived from either: Left/Right treat
  /// the whole neighbouring control as one stop with one entry point, the
  /// way they treat one main field, rather than a first-field-forward /
  /// last-field-backward pair that would put Left on Mode and Right on Band.
  void _crossToNextControl(String key, {required bool forward}) {
    final order = _pillOrder;
    final pillIndex = order.indexOf(key);
    if (pillIndex < 0 || order.isEmpty) return;
    _focusPillAndOpen(order[(pillIndex + (forward ? 1 : -1)) % order.length]);
  }

  /// Back to the field the operator was last in, with Call as the fallback
  /// for a remembered node whose field is gone (the contest changed, RSTs
  /// were hidden) — such a node has no context and would swallow the request
  /// silently.
  void _focusLastPrimaryField() {
    if (_editingEvent) {
      // Neither the callsign field nor a remembered primary field exists
      // while an event is loaded — NOTE/TODO's own text is the only
      // focusable main field, if this event even has one.
      if (_eventTextFocus.context != null) _eventTextFocus.requestFocus();
      return;
    }
    final remembered = _lastPrimaryFocus;
    ((remembered?.context != null) ? remembered! : _callFocus).requestFocus();
  }

  KeyEventResult _onPillKeyEvent(String key, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    final shift = keyboard.isShiftPressed;
    // Ctrl/Meta/Alt are always someone else's (platform gestures). Shift is
    // checked per key below instead of folded in here, because Tab needs it
    // for its own reversal — the same split [_onExpandedKeyEvent] and
    // [_onPrimaryFieldKeyEvent] make.
    if (keyboard.isControlPressed || keyboard.isMetaPressed || keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }
    // Tab/Shift-Tab walk the same strip Left/Right do, chip to chip, opening
    // whatever they land on — but not quite the same landing: Tab picks a
    // first-or-last FIELD ([_crossToPill]'s `fromStart`), Left/Right always
    // land on the control's one canonical field ([_crossToNextControl]).
    // Checked first since nothing past this point answers Shift.
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      final order = _pillOrder;
      final index = order.indexOf(key);
      if (index < 0 || order.length < 2) return KeyEventResult.ignored;
      final forward = !shift;
      _crossToPill(order[(index + (forward ? 1 : -1)) % order.length], fromStart: forward);
      return KeyEventResult.handled;
    }
    if (shift) return KeyEventResult.ignored;
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
        // Opens the pill it steps to, same as Tab — a chip is never a
        // resting stop of its own now, it's just what a fieldless control
        // (More, Spotting without a comment) leaves the keyboard on. Goes
        // through _crossToNextControl, not _crossToPill directly, so the
        // landing field matches [_onExpandedKeyEvent]'s cursor-key move.
        _crossToNextControl(key, forward: event.logicalKey == LogicalKeyboardKey.arrowRight);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        // Off the top of the panel, into the QSO list — when the host has one.
        // Without a host to take it, the pills are simply the top rung.
        widget.onNavigateToQsoList?.call();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        // Closes whatever this pill has open (a fieldless control — one with
        // a field parked the keyboard inside it instead, on `_onExpandedKeyEvent`'s
        // turf) on the way back to the main field, same as Escape below.
        _onSelectControl(null);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        // A pill's control opens the moment the keyboard lands on it, so by
        // the time Enter is pressed here it's normally already open — Enter
        // then closes it, same as it does from inside the field. `more` never
        // auto-opens (see `_focusPillAndOpen`/`_crossToPill`), so this still
        // opens it fresh, same as a tap.
        _onSelectControl(_selectedControlKey == key ? null : key);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        // Same "out of here entirely" meaning Escape has inside an open
        // control, from one rung further out. Handled here rather than left to
        // `_handleEscape` because that one would read a merely-parked keyboard
        // as a cue to wipe the form the operator hasn't touched.
        _onSelectControl(null);
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Down or Enter inside an open secondary control's field closes it and
  /// puts the keyboard straight back on the main field the operator was in —
  /// the control opened itself on arrival (`_focusPillAndOpen`), so there's no
  /// pill stop to return to on the way out either.
  ///
  /// Up closes it too, but keeps going one rung further, the way Up already
  /// does from a bare pill — straight on to the QSO list rather than
  /// stopping at the main fields.
  ///
  /// Escape does the Down/Enter thing too, via the panel-wide shortcut
  /// (`_handleEscape`) rather than here — it needs to fire even when nothing
  /// in the control has focus to bubble an event up from.
  ///
  /// Tab/Shift-Tab move within this control's own fields, then across to the
  /// next/previous pill once they're exhausted (`_stepSecondaryField`) — a
  /// control with several fields (Time's Date, Radio's Band and Mode) is
  /// walked in full before the strip moves on. An edge-of-value cursor key
  /// skips straight to the next/previous pill instead (`_crossToNextControl`)
  /// — Left/Right treat a whole control as one stop, the way they treat one
  /// main field.
  ///
  /// A dropdown's own arrow handling (the Band/Mode fields, or an open
  /// suggestion menu) already claims and consumes Up/Down before it gets
  /// here, so this only ever sees the ones meant for us.
  ///
  /// Enter deliberately does NOT log the QSO from ANY expanded control's
  /// fields — without this handler it would, via the Radio control's own
  /// `onSubmitted` or, for the activity reference controls and the spot
  /// comment (which declare none), the panel's root Enter shortcut this
  /// handler intercepts below. APP-19 asks for close-first, and Enter logs
  /// again one rung down, from any main field.
  KeyEventResult _onExpandedKeyEvent(String key, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final logicalKey = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    final shift = keyboard.isShiftPressed;
    // Ctrl/Meta/Alt are always someone else's (platform gestures) — Cmd+Down
    // is "caret to the end of the text" on macOS, for instance. Shift is
    // checked per key below instead, since Tab needs it for its own
    // reversal while the others treat it as "text selection, leave it alone"
    // (same split [_onPillKeyEvent] and [_onPrimaryFieldKeyEvent] make).
    if (keyboard.isControlPressed || keyboard.isMetaPressed || keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }

    if (logicalKey == LogicalKeyboardKey.tab) {
      final fields = _expandedFieldOrderFor(key);
      final currentIndex = fields.indexWhere((f) => f.$1.hasFocus);
      _stepSecondaryField(key, currentIndex, forward: !shift);
      return KeyEventResult.handled;
    }

    if (logicalKey == LogicalKeyboardKey.arrowLeft || logicalKey == LogicalKeyboardKey.arrowRight) {
      // Shift-arrow is selecting text, and a non-collapsed selection means
      // the arrow collapses it rather than leaving the field — only a bare
      // caret sitting against an edge is asking to travel. Same rule the
      // main fields' own Left/Right apply.
      if (shift) return KeyEventResult.ignored;
      final fields = _expandedFieldOrderFor(key);
      final currentIndex = fields.indexWhere((f) => f.$1.hasFocus);
      if (currentIndex < 0) return KeyEventResult.ignored;
      final selection = fields[currentIndex].$2.selection;
      if (!selection.isCollapsed || selection.baseOffset < 0) return KeyEventResult.ignored;
      final forward = logicalKey == LogicalKeyboardKey.arrowRight;
      final atEdge = forward ? selection.baseOffset >= fields[currentIndex].$2.text.length : selection.baseOffset == 0;
      if (!atEdge) return KeyEventResult.ignored;
      _crossToNextControl(key, forward: forward);
      return KeyEventResult.handled;
    }

    if (shift) return KeyEventResult.ignored;
    if (logicalKey == LogicalKeyboardKey.arrowUp) {
      _closeExpandedControlToQsoList(key);
      return KeyEventResult.handled;
    }
    if (logicalKey == LogicalKeyboardKey.arrowDown ||
        logicalKey == LogicalKeyboardKey.enter ||
        logicalKey == LogicalKeyboardKey.numpadEnter) {
      // Spotting's Send button has no FocusNode of its own — Tab never
      // reaches it, the same accepted gap the main Log button has (see
      // logging-fields.md). Enter from its comment field is the substitute,
      // same as Enter from any main field reaches Log.
      if (key == 'spotting' &&
          (logicalKey == LogicalKeyboardKey.enter || logicalKey == LogicalKeyboardKey.numpadEnter) &&
          _spotting.commentFocus.hasFocus &&
          _spotting.state.enabled &&
          !_spotting.sending) {
        unawaited(_spotting.send());
      }
      _closeExpandedControl(key);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Closes [key]'s control and returns the keyboard to the main field the
  /// operator was in before, but only if that control is still the one open —
  /// idempotent, because Enter can arrive twice for one keypress: once as a
  /// raw key event here, and again through a field's `onSubmitted` once the
  /// platform turns it into a text-input action (see the Frequency field's
  /// own `onSubmitted`, which calls this directly for that second route).
  void _closeExpandedControl(String key) {
    if (_selectedControlKey != key) return;
    setState(() => _selectedControlKey = null);
    _focusLastPrimaryField();
  }

  /// Closes [key]'s control and hands the keyboard on to the QSO list —
  /// Up's own close, one rung further out than Down/Enter/Escape's: leaving
  /// a control by Up keeps walking outward past the main fields, the same
  /// direction Up already takes from a bare pill, rather than stopping at
  /// them.
  void _closeExpandedControlToQsoList(String key) {
    if (_selectedControlKey != key) return;
    setState(() => _selectedControlKey = null);
    // Nothing navigable (an empty operation, or one holding only event
    // markers) leaves the callback with nowhere to put the keyboard — this
    // control just collapsed, so without a fallback focus would be left on
    // no field at all rather than merely stuck where it started.
    if (widget.onNavigateToQsoList?.call() != true) _focusLastPrimaryField();
  }

  void _onSelectControl(String? key) {
    // The chip itself already refuses a tap (ChoiceChip.onSelected: null,
    // see _ControlChip) — this covers the keyboard paths, which call here
    // directly rather than through the chip.
    if (_editingEvent && key != null && key != 'time') return;
    if (key == 'more') {
      _openMoreEditor();
      return;
    }
    setState(() {
      if (key == 'time' && _selectedControlKey != 'time') _time.seedFields();
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
      _focusLastPrimaryField();
    }
  }

  /// Whether the last layout couldn't give every main field its declared
  /// minimum ([resolveMainFieldLayout]). Read by the focus listeners: the
  /// focused field renders at full width, which only happens if a focus
  /// change rebuilds — and off a squeezed row it would be a rebuild that
  /// changes nothing.
  bool _mainFieldsSqueezed = false;

  /// The geometry the row was last laid out against, so a change in the space
  /// available can be told apart from a change in what wants it — see
  /// [_mainFieldWidthDuration].
  (double, double)? _lastRowGeometry;

  /// How long the fields take to reach a new width: [fieldWidthDuration] when
  /// the space available hasn't changed, and **instantly** when it has.
  ///
  /// Animating a resize would be worse, not better. The callsign is `Expanded`
  /// and so is never animated — it takes whatever the others leave, the moment
  /// they leave it. Animate the others through a window drag and the callsign
  /// spends the whole gesture absorbing their lag, jittering while every field
  /// beside it glides. A focus change is the opposite case: nothing else about
  /// the row is moving, so the one field that is should be followed rather than
  /// snapped at.
  ///
  /// [buttonWidth] counts as much as [rowWidth]: it is measured off the
  /// rendered row, so the first frame of a freshly opened panel always resolves
  /// against the fallback and the second against the real thing. Left out, that
  /// correction would animate — the whole row visibly gliding a few pixels
  /// every time the panel appears.
  Duration _mainFieldWidthDuration(double rowWidth, double buttonWidth) {
    final geometry = (rowWidth, buttonWidth);
    final changed = _lastRowGeometry != geometry;
    _lastRowGeometry = geometry;
    return changed ? Duration.zero : fieldWidthDuration;
  }

  /// One of the narrow secondary logging fields — Sent, Rcvd, State, Grid —
  /// which share everything but their controller/label and a couple of
  /// input-shaping knobs. Amateur-radio codes, not prose: stop the
  /// soft keyboard from autocorrecting, spell-checking, suggesting, or
  /// smart-punctuating the value into garbage (autocorrect:false also turns
  /// off iOS spell check; the smart types stop "-" → "–"). Uppercased like
  /// all logging input, and Enter logs.
  ///
  /// [width] and [padding] are resolved by [resolveMainFieldLayout], not
  /// chosen here: [fixedFieldMinWidth] whenever the row has room, and less
  /// when it doesn't.
  Widget _fixedField(
    BuildContext context, {
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool enabled,
    required String label,
    required double width,
    required double padding,
    required Duration duration,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputFormatter? filter,
    String? hintText,
    /// Only for a field that tracks whether the operator has touched it.
    /// Typing already reaches the controller's own listeners, so a field with
    /// nothing extra to record omits this rather than passing a no-op.
    ValueChanged<String>? onChanged,
  }) {
    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOut,
      width: width,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        selectAllOnFocus: false,
        enabled: enabled,
        style: mainFieldStyle(context, fontWeight: FontWeight.w500),
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        autocorrect: false,
        enableSuggestions: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        inputFormatters: [_virtualSpace, ?filter, const UpperCaseTextFormatter()],
        decoration: mainFieldDecoration(context, label, hintText: hintText, horizontalPadding: padding),
        onChanged: onChanged,
        onEditingComplete: () => _finishEditingWithoutBlur(controller),
        onSubmitted: (_) => _log(),
      ),
    );
  }

  /// What every main logging field does instead of `EditableText`'s default
  /// end-of-editing behavior.
  ///
  /// That default **unfocuses the field before it calls `onSubmitted`** — so
  /// left alone, every Enter blurs the field that submitted it, and the entry
  /// row only looked like it kept focus because the ordinary logging paths
  /// happen to re-focus afterwards (`_wipe` after a logged QSO, the `!_canLog`
  /// guard otherwise). Any path that didn't — running a command, saving an
  /// edit, a second Enter while one is still in flight — left the operator
  /// with nothing focused at all.
  ///
  /// Here Enter means "log", never "done editing": the entry row is a loop the
  /// keyboard stays inside (docs/design/logging-fields.md § "Enter and focus"),
  /// so the field that submitted keeps focus unless something downstream
  /// deliberately moves it. Suppressing the blur at the three build sites fixes
  /// every submit path at once, rather than making each new branch of [_log]
  /// remember to put focus back.
  ///
  /// Supplying `onEditingComplete` replaces the branch that did BOTH of those,
  /// so the composing-region cleanup is reinstated here by hand. It does not
  /// replace everything: `_finalizeEditing`'s trailing
  /// `if (shouldUnfocus) _scheduleRestartConnection()` still runs, and
  /// actually restarts the platform input connection rather than finding it
  /// already closed — which is what keeps the keyboard from blinking per QSO.
  ///
  /// Secondary controls are deliberately not covered — they keep their widget
  /// defaults (docs/design/logging-fields.md § "The three parts"), and the
  /// radio control's field moves focus to its pill itself on submit.
  ///
  void _finishEditingWithoutBlur(TextEditingController controller) => controller.clearComposing();

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
          label: t.loggingControls.timeControl,
          mandatory: true,
        ),
        _ControlDescriptor(
          key: 'radio',
          icon: _radioChipIcon,
          label: t.loggingControls.radioControl,
          mandatory: true,
        ),
        // Only with somewhere to keep the value: power lives on the VFO
        // ([Vfo.power]), and without a store the control would edit nothing.
        if (widget.radioService != null)
          _ControlDescriptor(
            key: 'power',
            icon: MdiIcons.flash,
            label: t.loggingControls.powerControl,
            defaultHidden: true,
          ),
        if (widget.suggestSpotSources != null && widget.sendSpot != null)
          _ControlDescriptor(
            key: 'spotting',
            icon: MdiIcons.handWave,
            label: t.loggingControls.spottingControl,
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
        // Beside More, and off until the operator has been asked: a note
        // per contact is a thing few operators keep, and the ones who do
        // know to go looking for it. The More pane edits the same value for
        // everyone else.
        _ControlDescriptor(
          key: 'notes',
          icon: MdiIcons.noteOutline,
          label: t.loggingControls.notesControl,
          defaultHidden: true,
        ),
        _ControlDescriptor(
          key: 'more',
          icon: MdiIcons.pencil,
          label: t.loggingControls.more,
        ),
      ];

  /// Whether this control stays out of the row. A [_ControlDescriptor
  /// .defaultHidden] control is out until the operator has been asked —
  /// which the saved order records, since the settings dialog writes every
  /// key it offered whether or not it was checked.
  bool _descriptorHidden(_ControlDescriptor descriptor) {
    if (descriptor.mandatory) return false;
    if (widget.hiddenControlKeys.contains(descriptor.key)) return true;
    return descriptor.defaultHidden && !widget.controlOrder.contains(descriptor.key);
  }

  /// Whether the Power control is in the row.
  bool get _powerControlVisible =>
      _controlDescriptors().where((d) => d.key == 'power').map(_descriptorHidden).firstOrNull == false;

  /// Something is logging power for this QSO: the operator put the control
  /// in the row, or the app is capturing it with the rest of the station
  /// info. This is what lets a composed QSO carry a power at all — without
  /// it the field stays empty and nothing is stamped.
  bool get _powerInPlay => _powerControlVisible || widget.trackingPower;

  /// The record being edited arrived carrying a power. Read from the record,
  /// never from the field: with the field as the test, emptying it would take
  /// the power OUT of the entry — and the write below would then omit the key
  /// and leave the old value standing, so a wrong power could never be
  /// cleared. It also survives past the record, so it is cleared with the
  /// rest of the entry ([_resetLocalFields], [_wipe]) — otherwise a value
  /// left over from an edit goes on stamping every QSO logged afterwards.
  bool _powerOnRecord = false;

  /// Whether power is part of THIS entry — in play, or already on the record
  /// being edited. A QSO that carries a power keeps showing it after the
  /// control is switched back off: it went out on the air that way, and a
  /// value nothing displays is a value nothing can correct.
  bool get _powerShown => _powerInPlay || _powerOnRecord;

  /// `widget.controlOrder`, filtered to keys that still exist and
  /// de-duplicated, with any remaining known keys slotted in where the
  /// descriptor list puts them — so a fresh install (empty order) or a
  /// newly-added control both land in their intended place.
  ///
  /// Slotted rather than appended: every operator who has ever saved the
  /// settings dialog has a stored order, and appending puts a new control
  /// at the very end of the row — past More — however deliberately the
  /// descriptor list placed it beside its neighbour. A key with no earlier
  /// descriptor already in the order still goes last, which is what the
  /// append did for all of them.
  List<String> _effectiveControlOrder(List<_ControlDescriptor> descriptors) {
    final allKeys = descriptors.map((d) => d.key).toSet();
    final order = <String>[];
    for (final key in widget.controlOrder) {
      if (allKeys.contains(key) && !order.contains(key)) order.add(key);
    }
    for (final (index, descriptor) in descriptors.indexed) {
      if (order.contains(descriptor.key)) continue;
      // Immediately after the nearest preceding descriptor that IS placed —
      // walking backwards, so a run of new keys keeps its own relative order.
      var insertAt = order.length;
      for (var previous = index - 1; previous >= 0; previous--) {
        final at = order.indexOf(descriptors[previous].key);
        if (at >= 0) {
          insertAt = at + 1;
          break;
        }
      }
      order.insert(insertAt, descriptor.key);
    }
    return order;
  }

  SecondaryControlSpec _timeControlSpec() => SecondaryControlSpec(
        key: 'time',
        icon: MdiIcons.clockOutline,
        summary: _time.summary,
        // Live clock only while nothing overrides the timestamp (a manually
        // set time, or editing an existing — necessarily historical — QSO);
        // the chip re-reads this once per second without rebuilding the
        // panel (a panel-level ticker calling setState on all of
        // _LoggingControlsState would cost a full panel rebuild per tick).
        liveSummary: _time.isLive ? () => _time.summary : null,
        expandedBuilder: (context) => TimeControlFields(
          model: _time,
        ),
      );

  SecondaryControlSpec _spottingControlSpec(ThemeData theme, HaLoColors poloColors) {
    final state = _spotting.state;
    return SecondaryControlSpec(
      key: 'spotting',
      icon: MdiIcons.handWave,
      summary: state.summary,
      expandedBuilder: (context) => SpottingControlFields(
        model: _spotting,
        state: state,
        theme: theme,
        colors: poloColors,
      ),
    );
  }

  List<SecondaryControlSpec> _buildSecondaryControls(
    ThemeData theme,
    HaLoColors poloColors, {
    bool Function(String key)? enabledFor,
  }) {
    final descriptors = _controlDescriptors();
    final byKey = {for (final d in descriptors) d.key: d};
    final specs = <SecondaryControlSpec>[];
    for (final key in _effectiveControlOrder(descriptors)) {
      final descriptor = byKey[key];
      if (descriptor == null) continue;
      if (_descriptorHidden(descriptor)) continue;
      switch (key) {
        case 'time':
          specs.add(_timeControlSpec());
        case 'radio':
          specs.add(_radioControlSpec(theme));
        case 'power':
          specs.add(_powerControlSpec());
        case 'spotting':
          specs.add(_spottingControlSpec(theme, poloColors));
        case 'notes':
          specs.add(notesControlSpec(theme,
              controller: _notesController, focusNode: _notesFocus, onChanged: _onNotesChanged));
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
    return [
      for (final spec in specs) _withKeyboardNavigation(spec, enabled: enabledFor?.call(spec.key) ?? true),
    ];
  }

  /// The main-fields row while editing an event/annotation: the kind is
  /// plain text — not a value the operator edits, so it gets no field
  /// chrome — baseline-aligned with whatever sits beside it. That's
  /// NOTE/TODO's real, editable text field; everything else (SOLAR/
  /// WEATHER's fetched description, or nothing at all for BREAK/START/END,
  /// whose grid/contest-exchange segment override has no editing UI yet —
  /// docs/design/contests.md §5.1.3) goes through [_chromelessValueField]
  /// instead of a plain `Text`, so the row reaches a real field's height by
  /// construction rather than by approximating it: `TextField` and `Text`
  /// size themselves through different render objects (`RenderEditable` vs
  /// `RenderParagraph`), which don't agree to the pixel even given the same
  /// decoration.
  Widget _buildEventFields(BuildContext context, ThemeData theme, bool fieldsLocked) {
    final editingQso = widget.editingQso!;
    final kind = editingQso.eventKind;
    final event = editingQso.event;
    final label = kind?.toUpperCase() ?? 'EVENT';
    final textStyle = mainFieldStyle(context, fontWeight: FontWeight.w500)
        .copyWith(color: theme.colorScheme.onTertiaryContainer);

    Widget trailing;
    if (kind == 'note' || kind == 'todo') {
      final decoration = mainFieldDecoration(
        context,
        kind == 'todo' ? t.loggingControls.todoField : t.loggingControls.noteField,
        horizontalPadding: materialFilledInputGap,
      );
      trailing = TextField(
        controller: _eventTextController,
        focusNode: _eventTextFocus,
        enabled: !fieldsLocked,
        style: mainFieldStyle(context, fontWeight: FontWeight.w400),
        // The done checkbox rides in the field's own prefixIcon slot rather
        // than sitting beside it in the row: a Checkbox can't answer the
        // dry-baseline query `IntrinsicHeight`/`CrossAxisAlignment.baseline`
        // need (its check mark paints through a `RenderCustomPaint`, which
        // doesn't implement one) — the decorator already knows how to place
        // a prefix icon without asking it for a baseline.
        decoration: kind == 'todo'
            ? decoration.copyWith(
                prefixIcon: Checkbox(
                  value: _eventTodoDone,
                  onChanged:
                      fieldsLocked ? null : (value) => setState(() => _eventTodoDone = value ?? false),
                ),
              )
            : decoration,
        onSubmitted: (_) => _log(),
      );
    } else {
      trailing = _chromelessValueField(
        context,
        keySuffix: kind ?? 'event',
        value: (kind == 'solar' || kind == 'weather') ? (event?['description'] as String?) ?? '' : '',
        style: textStyle,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(label, style: textStyle),
        const SizedBox(width: Space.md),
        Expanded(child: trailing),
      ],
    );
  }

  /// A read-only, chrome-less field standing in for plain text wherever
  /// [_buildEventFields] has no editable value: same decoration function
  /// NOTE/TODO's real field uses (so it claims the identical vertical
  /// space), with everything that paints stripped off (`filled: false`, no
  /// border, no label) — a real `TextField` under the hood so its height
  /// matches one exactly, but nothing on screen betrays that it is one.
  /// Keyed on its own value: `initialValue` only applies once per State, so
  /// a field showing a different event's text after a selection change
  /// (same widget position, new `editingQso`) needs a new key to pick it up.
  Widget _chromelessValueField(
    BuildContext context, {
    required String keySuffix,
    required String value,
    required TextStyle style,
  }) =>
      TextFormField(
        key: ValueKey('event-$keySuffix-$value'),
        initialValue: value,
        readOnly: true,
        enabled: false,
        maxLines: 1,
        style: style,
        decoration: mainFieldDecoration(context, '', horizontalPadding: materialFilledInputGap).copyWith(
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      );

  /// Adds this panel's keyboard policy to a control spec: a focus node for its
  /// pill, and a non-focusable ancestor over its expanded content that watches
  /// for the keys which close it again. Applied once, over the assembled list,
  /// so a newly added kind of control can't arrive without it.
  ///
  /// Through `copyWith` rather than a fresh [SecondaryControlSpec]:
  /// re-listing the fields here drops any the spec grows later, and a chip
  /// rendering the default is not a failure anything reports.
  SecondaryControlSpec _withKeyboardNavigation(SecondaryControlSpec spec, {bool enabled = true}) => spec.copyWith(
        focusNode: _pillFocusFor(spec.key),
        enabled: enabled,
        expandedBuilder: (context) => Focus(
          // Not a stop on the way anywhere: it exists only to see key events
          // on their way up from whatever inside the control has focus.
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: (node, event) => _onExpandedKeyEvent(spec.key, event),
          child: spec.expandedBuilder(context),
        ),
      );

  /// The glyph both the Radio chip and its settings-dialog entry use — a
  /// transceiver should look like one thing throughout this row.
  IconData get _radioChipIcon => widget.hasConfiguredRadio ? MdiIcons.cat : MdiIcons.radio;

  SecondaryControlSpec _radioControlSpec(ThemeData theme) => SecondaryControlSpec(
        key: 'radio',
        icon: _radioChipIcon,
        iconColor: radioStatusColor(
          theme,
          hasConfiguredRadio: widget.hasConfiguredRadio,
          connected: widget.radioConnected,
          selected: _selectedControlKey == 'radio',
        ),
        // `band` is null both when nothing is tuned at all and when the
        // frequency in the field falls outside every ham band; `outOfBand`
        // catches the case a band name can't — a frequency inside a ham band
        // that the operator's own region or country doesn't allocate to
        // amateurs (e.g. 7250 kHz in ITU Region 1).
        alert: _radio.band == null || _radio.outOfBand,
        summary: _radio.summary,
        summaryParts: _radio.summaryParts(errorColor: theme.colorScheme.error),
        expandedBuilder: (context) => RadioControlFields(
          model: _radio,
          theme: theme,
          hasConfiguredRadio: widget.hasConfiguredRadio,
          radioConnected: widget.radioConnected,
          radioName: widget.radioName,
          onOpenStationConfig: widget.onOpenStationConfig,
          freqInputFormatters: [_virtualSpace],
          // iOS: NumbersAndPunctuation (has the decimal separators, the
          // symbols, and a space bar for Space-to-advance); other platforms
          // keep the decimal pad.
          freqKeyboardType: _numbersAndPunctuationOnIOS ?? const TextInputType.numberWithOptions(decimal: true),
          onFreqSubmitted: () => _closeExpandedControl('radio'),
          onPicked: _callFocus.requestFocus,
        ),
      );

  /// The watts in the Power field, or null when it is empty (or holds
  /// nothing parseable — a lone "." mid-typing).
  num? get _powerWatts => num.tryParse(_powerController.text.trim());

  String get _powerSummary {
    final watts = _powerWatts;
    return watts == null ? '—' : '$watts ${t.loggingControls.powerUnit}';
  }

  /// Takes power back out of the entry: the field, and the record's own
  /// value. Whatever the field holds belonged to the QSO just closed, and
  /// [_seedFromRadioService] only refills it while power is in play.
  void _clearPowerEntry() {
    _powerOnRecord = false;
    _powerController.clear();
  }

  /// Pushes the field to the VFO, which is where every power surface reads
  /// it from and how a connected radio hears about it (CAT forwards it the
  /// way it forwards a typed frequency). Never while editing an existing
  /// QSO: that applies changes to the QSO, never the VFO — the same rule the
  /// Radio control follows.
  void _commitPower() {
    if (widget.editingQso != null) return;
    final watts = _powerWatts;
    widget.radioService?.setVfo('vfoA', power: watts, clearPower: watts == null);
  }

  SecondaryControlSpec _powerControlSpec() => SecondaryControlSpec(
        key: 'power',
        icon: MdiIcons.flash,
        summary: _powerSummary,
        expandedBuilder: (context) => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              // Four digits is every legal amateur power, the same width the
              // Station Configuration field is sized to.
              width: 72,
              child: TextField(
                controller: _powerController,
                focusNode: _powerFocus,
                selectAllOnFocus: false,
                style: haloMonoStyle(context, fontSize: 15, fontWeight: FontWeight.w500),
                decoration: poloFieldDecoration(
                  context,
                  t.loggingControls.power,
                  labelColor: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
                keyboardType: _numbersAndPunctuationOnIOS ?? const TextInputType.numberWithOptions(decimal: true),
                autocorrect: false,
                enableSuggestions: false,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                // A decimal point earns its place at the QRPp end (0.5 W);
                // everything else a keyboard can offer here is noise.
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                onSubmitted: (_) => _commitPower(),
              ),
            ),
            const SizedBox(width: Space.sm),
            Text(
              t.loggingControls.powerUnit,
              style: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer),
            ),
          ],
        ),
      );

  /// Applies references a `lookup` hook proposed for this call — the park or
  /// summit `spot-history` mined out of a recent spot — onto the QSO being
  /// composed. Returns whether anything actually landed.
  ///
  /// A proposed ref is only ever ADDED, never allowed to replace a ref whose
  /// type the QSO already carries: the operator's own entry outranks a
  /// guess, and re-proposing an existing type on every pass is exactly what
  /// would make the ref-change re-lookup (see `_relookupForRefsChanged`)
  /// cycle forever.
  ///
  /// Skipped entirely while editing a saved QSO — refs describe where the
  /// station is *now*, which says nothing about where it was when a contact
  /// already in the log was made.
  bool _applyGuessRefs(Map<String, dynamic>? result, String forCall) {
    if (widget.editingQso != null || _fieldsLocked || _populating) return false;
    final guess = result?['guess'];
    if (guess is! Map) return false;
    final proposed = asQsonList(guess['refs'])?.whereType<Map<dynamic, dynamic>>().map((r) => r.cast<String, dynamic>()) ?? const [];
    if (proposed.isEmpty) return false;

    final claimedTypes = <Object?>{
      for (final list in _controlRefs.values)
        for (final ref in list) ref['type'],
      for (final ref in _unmatchedRefs) ref['type'],
    };
    final added = <String, List<Map<String, dynamic>>>{};
    final addedUnmatched = <Map<String, dynamic>>[];
    for (final ref in proposed) {
      final type = ref['type'];
      if (type is! String || type.isEmpty || ref['ref'] == null) continue;
      if (!claimedTypes.add(type)) continue;
      final key = _refListControlKeyForType(type);
      if (key != null) {
        (added[key] ??= []).add(ref);
      } else {
        addedUnmatched.add(ref);
      }
    }
    if (added.isEmpty && addedUnmatched.isEmpty) return false;

    setState(() {
      added.forEach((key, refs) => (_controlRefs[key] ??= []).addAll(refs));
      // Rebuilt rather than mutated: `_unmatchedRefs` starts life as a const
      // literal, which cannot be added to.
      if (addedUnmatched.isNotEmpty) _unmatchedRefs = [..._unmatchedRefs, ...addedUnmatched];
      // Remembered so they can be taken back when the call changes — see
      // [_guessedRefs]. Appended, not replaced: the offline pass and the
      // online pass both contribute for the same call.
      _guessedRefsForCall = forCall;
      _guessedRefs = [
        ..._guessedRefs,
        for (final refs in added.values) ...refs,
        ...addedUnmatched,
      ];
    });
    return true;
  }

  /// References put on the QSO by a lookup guess rather than by the operator,
  /// and the callsign they were resolved for.
  ///
  /// A guessed ref answers "where is THIS station right now", so it must not
  /// outlive the call that was asked about: correcting KI2D to KI2E would
  /// otherwise log the second station at the first one's park. Only refs this
  /// widget actually inserted are tracked, and [_clearGuessedRefs] removes
  /// them BY IDENTITY — an operator-typed ref that happens to equal one of
  /// these is not ours to take back.
  String? _guessedRefsForCall;
  List<Map<String, dynamic>> _guessedRefs = const [];

  /// Removes every ref a previous call's guess contributed, leaving the
  /// operator's own untouched. Returns whether anything was removed; the
  /// caller owns the `setState`.
  bool _clearGuessedRefs() {
    _guessedRefsForCall = null;
    if (_guessedRefs.isEmpty) return false;
    final stale = _guessedRefs;
    _guessedRefs = const [];
    bool isStale(Map<String, dynamic> ref) => stale.any((s) => identical(s, ref));

    var removed = false;
    for (final list in _controlRefs.values) {
      final before = list.length;
      list.removeWhere(isStale);
      removed |= list.length != before;
    }
    if (_unmatchedRefs.any(isStale)) {
      _unmatchedRefs = [
        for (final ref in _unmatchedRefs)
          if (!isStale(ref)) ref,
      ];
      removed = true;
    }
    return removed;
  }

  /// The activity control that would own a ref of [type] — the refList
  /// control whose `refType` matches. Primary fields (`text`/`serial`/
  /// `options`) read one field out of a ref rather than owning it and several
  /// may share a type, so they never claim one; a ref they match still has to
  /// reach a refList control or fall through to `_unmatchedRefs` (same rule
  /// `_applyFieldsFromData` follows when loading a saved QSO).
  String? _refListControlKeyForType(String type) {
    for (final control in _effectiveActivityControls) {
      final input = control['input'] as Map?;
      if (input?['refType'] != type) continue;
      final kind = input?['kind'];
      if (kind == 'text' || kind == 'serial' || kind == 'options') continue;
      return control['key'] as String?;
    }
    return null;
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
      // A reference the pattern rejects is KEPT, so the chip counts it and reads
      // "✓ POTA" like any other — and the field's own tint is gone the moment
      // the control is shut, which is how it spends most of a QSO and all of
      // the instant the contact is logged. So the chip carries the mark too, in
      // the error pair the Radio chip wears with no band to log on and for the
      // same reason: what is wrong is only cheap to fix while the station is
      // still there. It outranks the extension's accent, which has no
      // guaranteed contrast against the error fill.
      alert: anyRefFailsPattern(
        _controlRefs[control['key']] ?? const [],
        (control['input'] as Map?)?['pattern'] as String?,
      ),
      expandedBuilder: (context) => SizedBox(
        width: 160,
        child: RefTextInput(
          focusNode: _refFocusFor(control['key'] as String),
          controller: _refControllerFor(control['key'] as String),
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
  Widget _exchangeField(
    BuildContext context,
    Map<String, dynamic> control, {
    required bool enabled,
    required double width,
    required double padding,
    required Duration duration,
  }) {
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
      // Every value, not just the last one: a county line whose second county
      // is a typo claims a multiplier that isn't there, and the field is the
      // only place that can say so while the QSO is still in front of the
      // operator.
      isInvalid = isInvalid || !areKnownExchangeOptions(
        value,
        options,
        separator: _optionSeparatorFor(control),
        inheritPrefix: _optionInheritPrefixFor(control),
      );
    }
    final uppercase = !isSerial && input['uppercase'] != false;
    final transforms = [
      for (final t in (input['transforms'] as List?) ?? const [])
        RefTransform.fromMap((t as Map).cast<String, dynamic>()),
    ];

    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOut,
      // Wider than an RST, narrower than the callsign: an exchange is usually
      // a zone, a serial or a state abbreviation. Resolved by
      // [resolveMainFieldLayout] — [exchangeFieldMinWidth] when the row has
      // room, and less when it doesn't.
      width: width,
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
        style: mainFieldStyle(context, fontWeight: FontWeight.w500),
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
        // going through `errorText` — see [haloInvalidInputBorder] for why the
        // error slot is not an option in this row.
        decoration: mainFieldDecoration(context, label, horizontalPadding: padding).copyWith(
          hintText: input['placeholder'] as String?,
          enabledBorder: isInvalid ? haloInvalidInputBorder(context, width: 1) : null,
          focusedBorder: isInvalid ? haloInvalidInputBorder(context, width: 2) : null,
        ),
        onChanged: (text) {
          setState(() {
            _controlTextValues[key] = text;
            // Once typed, a later lookup-derived suggestion must not overwrite
            // it (docs/design/contests.md §5.3).
            _touchedTextControls.add(key);
            // An exchange typed before the call starts the contact just as a
            // call would, and takes the serial number with it (§5.8.1).
            unawaited(_refreshSerialPreviews());
            // A new character is a new question: the offer comes back even if
            // the last one was dismissed, and the highlight starts over at the
            // best match rather than pointing at a row that may no longer be
            // in the list.
            _optionsMenuDismissed = false;
            _optionSelection = null;
          });
        },
        onEditingComplete: () => _finishEditingWithoutBlur(_textControllerFor(key)),
        onSubmitted: (_) => _handleEnter(),
      ),
      ),
    );
  }

  /// Sent and Rcvd, in the order the operator reads them — reversed by
  /// `switchSentRcvd`, which [_rstPair] resolves once for every surface.
  ///
  /// The gaps belong to the POSITION, not to the field: whichever report comes
  /// first opens the group after the callsign, and the second sits a plain
  /// field gap along from it. Reversing the pair alone would carry the wide
  /// gap into the middle of it.
  List<MainField> _rstMainFields(BuildContext context, {required bool enabled}) => [
        for (final (index, field) in _rstPair.indexed)
          (
            gapBefore: index == 0 ? mainFieldGroupGap : mainFieldGap,
            minWidth: fixedFieldMinWidth,
            focusNode: field.focus,
            build: (width, padding, duration) => _fixedField(
              context,
              controller: field.controller,
              focusNode: field.focus,
              enabled: enabled,
              label: field.label,
              width: width,
              padding: padding,
              duration: duration,
              // Letters are legitimate in RSTs (CW's "5NN" shorthand, aurora
              // "59A") and the Edit QSO pane accepts them — a digits-only
              // filter here would silently strip a pane-saved letter on the
              // next keystroke, since filtering formatters re-run over the
              // whole text.
              keyboardType: _numbersAndPunctuationOnIOS,
              filter: FilteringTextInputFormatter.allow(RegExp(r'[0-9a-zA-Z+\-]')),
              hintText: _rstPlaceholder,
            ),
          ),
      ];

  /// The main logging fields that follow the callsign, in row order.
  ///
  /// The single source of truth for both [resolveMainFieldLayout] and the row
  /// that renders them in [build], so a field can never be in the layout
  /// arithmetic and missing from the row (or the reverse) — the same drift
  /// [_primaryFields] exists to prevent for the keyboard, and the same order.
  ///
  /// The callsign is deliberately not here: it is `Expanded` over whatever
  /// these leave it, and it is never squeezed.
  List<MainField> _trailingMainFields(BuildContext context, {required bool enabled}) => [
        if (widget.showRSTFields) ..._rstMainFields(context, enabled: enabled),
        // Contest exchanges, inline right after the RSTs — see `_textControls`
        // for why these are primary.
        for (final control in _textControls)
          (
            gapBefore: mainFieldGap,
            minWidth: exchangeFieldMinWidth,
            focusNode: _textFocusFor(control['key'] as String),
            build: (width, padding, duration) => _exchangeField(context, control,
                enabled: enabled, width: width, padding: padding, duration: duration),
          ),
        if (widget.showStateField)
          (
            gapBefore: mainFieldGroupGap,
            minWidth: fixedFieldMinWidth,
            focusNode: _stateFocus,
            build: (width, padding, duration) => _fixedField(
              context,
              controller: _stateController,
              focusNode: _stateFocus,
              enabled: enabled,
              label: t.qsoEditForm.theirState,
              width: width,
              padding: padding,
              duration: duration,
              textCapitalization: TextCapitalization.characters,
              // The guessed state (e.g. from a callsign lookup) shows as a
              // faint placeholder while the field is empty — never pre-filled
              // as a real value.
              hintText: _currentGuess?['state'] as String?,
              onChanged: (_) {
                _stateTouched = true;
                // Scored on (New State / New Province), so a typed state has
                // to reach the scorer like a band or mode change does.
                _lookup.scheduleScore();
              },
            ),
          ),
        if (widget.showGridField)
          (
            gapBefore: mainFieldGroupGap,
            minWidth: fixedFieldMinWidth,
            focusNode: _gridFocus,
            build: (width, padding, duration) => _fixedField(
              context,
              controller: _gridController,
              focusNode: _gridFocus,
              enabled: enabled,
              label: t.qsoEditForm.theirGrid,
              width: width,
              padding: padding,
              duration: duration,
              textCapitalization: TextCapitalization.characters,
              hintText: _guessGridHint,
              onChanged: (_) => _markGridTouched(),
            ),
          ),
      ];

  /// The contact's own note. Wider than the other controls' fields — a note
  /// is a sentence, not a value — and explicitly mixed-case, like Name and
  /// the spot comment: free prose, not logging data.
  /// Keeps the QSO's `notes` in step with the field, and the chip's check
  /// mark in step with both. An empty note is REMOVED rather than stored as
  /// an empty string: [_currentQsoExtra] being non-empty is one of the
  /// signals that says a draft is worth keeping ([_hasComposedValues]), so a
  /// note typed and then deleted would otherwise leave an empty entry looking
  /// like a started one. What the SAVE writes for an empty note is a separate
  /// question — see [_getCurrentQsoData]. The `setState` is also what pushes
  /// the draft up to the host: the post-frame notify in [build] runs on every
  /// rebuild.
  void _onNotesChanged(String value) {
    final notes = value.trim();
    setState(() {
      if (notes.isEmpty) {
        _currentQsoExtra.remove('notes');
      } else {
        _currentQsoExtra['notes'] = notes;
      }
    });
  }

  SecondaryControlSpec _moreControlSpec() => SecondaryControlSpec(
        key: 'more',
        icon: MdiIcons.pencil,
        summary: t.loggingControls.more,
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
      // the expects-params rule's second arm, text that already holds a space.
      // A complete command reached that way ("EXP LA") carries neither
      // `expectsParams` nor `mixedCase`, so keying the exit to those flags
      // advanced focus while leaving the trailing space in the value.
      //
      // Ahead of the interpret round-trip below because the answer never
      // depended on it, and leaving a field shouldn't wait on a bridge call.
      if (_command.fieldAcceptsSpaces && _atTrailingSpace(_callController)) {
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
        // space by advancing focus instead of inserting it. Reuses the
        // answer the debounce already resolved for this exact text, so this
        // only adds a round trip when genuinely needed.
        if (widget.editingQso == null && widget.interpretCommand != null) {
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

      _advancePrimaryFocus();
    } else if (_radio.freqFocus.hasFocus) {
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
  List<PrimaryField> get _primaryFields => [
        (
          key: 'call',
          label: t.loggingControls.theirCall,
          focus: _callFocus,
          controller: _callController,
          hint: null,
        ),
        // Display order, not Sent-then-Rcvd: the keyboard walks the row the
        // operator is looking at (see [_rstPair]).
        if (widget.showRSTFields)
          for (final field in _rstPair)
            (
              key: identical(field.controller, _sentController) ? 'sent' : 'rcvd',
              label: field.label,
              focus: field.focus,
              controller: field.controller,
              hint: _rstPlaceholder,
            ),
        // Only nodes already attached to a built field: creating one here for a
        // control whose widget hasn't been built leaves an orphan with no
        // context, which Flutter's focus traversal null-checks while sorting —
        // taking down the whole frame rather than just misordering focus.
        for (final control in _textControls)
          if (_controlTextFocus[control['key'] as String]?.context != null)
            (
              key: control['key'] as String,
              label: (control['label'] as String?) ?? control['key'] as String,
              focus: _controlTextFocus[control['key'] as String]!,
              controller: _textControllerFor(control['key'] as String),
              hint: (control['input'] as Map?)?['placeholder'] as String?,
            ),
        if (widget.showStateField)
          (
            key: 'state',
            label: t.qsoEditForm.theirState,
            focus: _stateFocus,
            controller: _stateController,
            hint: _currentGuess?['state'] as String?,
          ),
        if (widget.showGridField)
          (
            key: 'grid',
            label: t.qsoEditForm.theirGrid,
            focus: _gridFocus,
            controller: _gridController,
            hint: _guessGridHint,
          ),
      ];

  /// Just the nodes of [_primaryFields], for the callers that only move focus
  /// and never read a value.
  List<FocusNode> get _primaryFocusOrder => [for (final field in _primaryFields) field.focus];

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
  /// leftward move and both Tab wraps want the end, so they set nothing:
  /// writing `text.length` for them too means Tab onto an already-focused node
  /// (a row with one primary field) leaves an instruction nobody collects, and
  /// the next field to focus — Frequency, say — takes it and puts its caret
  /// at 0.
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
    final node = fields[(index + fields.length) % fields.length].focus;
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
    final index = fields.indexWhere((f) => identical(f.focus, node));
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
    // provide (APP-19), opening the pill it lands on immediately rather than
    // waiting for a separate Enter. Inert while an options suggestion menu is
    // open, since Up and Down belong to its highlight for as long as it is
    // showing, and while the fields are locked: a staged-delete or deleted
    // QSO's secondary controls are pointer-blocked and dimmed, and the
    // keyboard shouldn't reach past that either.
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_optionSuggestions.isNotEmpty || _fieldsLocked) return KeyEventResult.ignored;
      _focusPillAndOpen();
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
    final controller = fields[index].controller;
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
  /// `_handleSpace`'s free-text branch and [VirtualSpaceFormatter]).
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
    if (!widget.showExtraInNumbersRow) return null;
    if (_callFocus.hasFocus) {
      final text = _callController.text;
      final hasLetter = RegExp(r'[A-Za-z]').hasMatch(text);
      final onlyDigits = RegExp(r'^[0-9]+$').hasMatch(text);
      if (hasLetter && !onlyDigits) return '/';
    }
    return NumberFormatting.instance.decimalSeparator;
  }

  /// The operator has stated a locator — from the row's Grid field, the
  /// numbers row above it, or the More pane. Every one of them goes through
  /// here rather than setting the flag itself, because a typed grid also
  /// takes the contact's coordinate out of the entry: a pair the pane
  /// recorded earlier in this visit would otherwise survive and outrank the
  /// grid everywhere it is read (docs/design/locations.md), silently
  /// discarding the correction just made. A coordinate the operator types
  /// AFTER this, in the same pane visit, is recorded after it and still wins
  /// — that is the intended precedence.
  void _markGridTouched() {
    _gridTouched = true;
    _theirExtra
      ..remove('lat')
      ..remove('lon');
  }

  /// The Grid field's hint — see [guessGridDisplay], which the More pane's
  /// own Grid field hints through too so the two can never show different
  /// squares for one station.
  String? get _guessGridHint => guessGridDisplay(_currentGuess);

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
    if (identical(focus, _gridFocus)) {
      _markGridTouched();
    } else if (identical(focus, _stateFocus)) {
      _stateTouched = true;
    }
  }

  /// Rebuilds so the bar's visibility and contextual "/"→"." key track the
  /// focused field. Only runs while the feature is on, so it costs nothing
  /// otherwise.
  void _rebuildForNumbersRow() {
    if (!widget.showNumbersRow) return;
    _rebuildBetweenFrames();
  }

  /// A rebuild requested from a focus notification, which can arrive mid-build
  /// (autofocus on the first frame): synchronous only when we're safely
  /// between frames, otherwise deferred to the end of the frame in progress.
  void _rebuildBetweenFrames() {
    if (!mounted) return;
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
        // frequency typing. _populating suppresses the frequency listener's own
        // (debounced) push, which would otherwise also fire from the
        // controller text assignment below.
        _populating = true;
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
            final guess = modeForFrequency(
              freq.toDouble(),
              ituRegion: widget.ourItuRegion,
              countryCode: widget.ourCountryCode,
            );
            if (guess != null) _radio.applyModeGuess(guess);
          }
        });
        _populating = false;
        if (params['freq'] is num || params['band'] is String || params['mode'] is String) {
          _radio.pushVfo();
        }
        // The command changed band/mode/freq under `_populating`, which
        // suppressed the field listeners' own rescore — refresh the call-info
        // notices (New Band / New Mode / dupe) for the new radio state.
        _lookup.scheduleScore();
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
      } else if (map['purgeTests'] is Map) {
        await widget.onCommandAction?.call('purgeTests', (map['purgeTests'] as Map).cast<String, dynamic>());
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
          'operation': _spotting.operationPayload,
          'target': target,
          if (qso != null) 'qso': qso.data,
          'comment': ?comment,
          if (qso == null) 'freq': vfo?.freq,
          if (qso == null) 'mode': vfo?.mode,
        });
      } else if (map['devNotice'] is Map) {
        await widget.onCommandAction?.call('devNotice', (map['devNotice'] as Map).cast<String, dynamic>());
      } else if (map['devStatus'] is Map) {
        await widget.onCommandAction?.call('devStatus', (map['devStatus'] as Map).cast<String, dynamic>());
      } else if (map['devProgress'] is Map) {
        await widget.onCommandAction?.call('devProgress', (map['devProgress'] as Map).cast<String, dynamic>());
      } else if (map['devHammer'] is Map) {
        await widget.onCommandAction?.call('devHammer', (map['devHammer'] as Map).cast<String, dynamic>());
      } else if (map['devSplash'] is Map) {
        await widget.onCommandAction?.call('devSplash');
      } else if (map['devOnboard'] is Map) {
        await widget.onCommandAction?.call('devOnboard');
      } else if (map['devTester'] is Map) {
        await widget.onCommandAction?.call('devTester');
      } else if (map['devPopup'] is Map) {
        await widget.onCommandAction?.call('devPopup');
      } else if (map['devTimeTravel'] is Map) {
        await widget.onCommandAction?.call('devTimeTravel', (map['devTimeTravel'] as Map).cast<String, dynamic>());
      } else if (map['devBench'] is Map) {
        await widget.onCommandAction?.call('devBench', (map['devBench'] as Map).cast<String, dynamic>());
      } else if (map['reloadDataFiles'] is Map) {
        await widget.onCommandAction?.call('reloadDataFiles', (map['reloadDataFiles'] as Map).cast<String, dynamic>());
      } else if (map['toggleExperiment'] is Map) {
        await widget.onCommandAction?.call('toggleExperiment', (map['toggleExperiment'] as Map).cast<String, dynamic>());
      } else if (map['updateSetting'] is Map) {
        await widget.onCommandAction?.call('updateSetting', (map['updateSetting'] as Map).cast<String, dynamic>());
      } else if (map['openSettings'] is Map) {
        await widget.onCommandAction?.call('openSettings', (map['openSettings'] as Map).cast<String, dynamic>());
      } else if (map['updateOperation'] is Map) {
        // The uuid is added here because only this widget knows which
        // operation is open; the app owns the write, since the operator
        // callsign and the position land in different columns.
        await widget.onCommandAction?.call('updateOperation', {
          ...(map['updateOperation'] as Map).cast<String, dynamic>(),
          'uuid': widget.operation.uuid,
        });
      } else if (map['markSegment'] is Map) {
        // Same shape as updateOperation: this widget names the open
        // operation, the app writes the event rows (and opens the location
        // screen for ROVERQTH).
        await widget.onCommandAction?.call('markSegment', {
          ...(map['markSegment'] as Map).cast<String, dynamic>(),
          'uuid': widget.operation.uuid,
        });
      } else if (map['setPower'] is Map) {
        // No QSO-scoped widget state of its own — same dispatch shape as
        // updateSetting/openSettings above, straight through to the app layer.
        await widget.onCommandAction?.call('setPower', (map['setPower'] as Map).cast<String, dynamic>());
      } else if (map['setKeyerSpeed'] is Map) {
        // Same as setPower: radio1's keyer, nothing of this widget's.
        await widget.onCommandAction?.call('setKeyerSpeed', (map['setKeyerSpeed'] as Map).cast<String, dynamic>());
      } else if (map['showKeyer'] is Map) {
        await widget.onCommandAction?.call('showKeyer', null);
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

  /// [callOverride] lets call stacking (`CallFieldText.pickStackedCall`) supply the one
  /// segment it picked out of the "//"-separated field, instead of the raw
  /// (still-stacked) field text.
  ///
  /// [composing] describes the new-QSO draft regardless of what
  /// `widget.editingQso` currently is — needed to snapshot it for
  /// [_composingSnapshot] from inside `didUpdateWidget`, where `widget`
  /// already reflects the QSO about to be edited by the time this runs, and
  /// `base`/`_time.effectiveStartAtMillis` would otherwise pull from THAT record
  /// instead of from the still-blank-base draft being stepped away from.
  Map<String, dynamic> _getCurrentQsoData({String? callOverride, bool composing = false}) {
    final base = composing ? const <String, dynamic>{} : (widget.editingQso?.data ?? const <String, dynamic>{});
    final call = callOverride ?? _call;
    final startAtMillis = composing ? _time.manualStartAtMillis : _time.effectiveStartAtMillis;
    final refs = _refsWithTextValues([
      for (final list in _controlRefs.values) ...list,
      ..._unmatchedRefs,
    ]);
    return {
      ...base,
      // Unconditional (not `if (refs.isNotEmpty)`/`if (_radio.freq != null)`):
      // `base` may already carry a non-empty value for these from the
      // record being edited, and a merge-style `...base` above won't drop
      // a stale one just because the live value is now empty/null — these
      // have to actively overwrite every time, including with null/empty,
      // for clearing a ref/freq/band during an edit to actually stick.
      'refs': refs,
      'our': {
        ...?(base['our'] as Map<String, dynamic>?),
        // The FIRST of the operation's callsigns, not the field: several
        // callsigns live in it as one comma-separated string, and a contact
        // holds exactly one. Stamping the field puts "N0DEV,KI2D" — which is
        // not a callsign — on every contact and into the `our_call` column
        // the cross-operation Logs view groups by. Which of several calls
        // made a given contact is not recorded here (app-polo doesn't record
        // it either); the exports fan out per call and restamp each file's
        // records themselves (`ExportService._qsosAs`).
        'call': widget.operation.stationCalls.first,
        'sent': _rstOrDefault(_sentController.text.trim()),
        ..._ourExtra,
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
        ..._theirExtra,
        // A typed locator replaces whatever coordinate the record arrived with
        // by its own square's center — a leftover pair outranks the grid
        // everywhere it is read. After `_theirExtra`, so a pair typed into the
        // More pane still wins, and tested AS a pair: the pane records its two
        // fields apart, and a typed latitude beside a center's longitude is a
        // point nobody stated. `locSource` goes too — app-polo sends it tagging
        // a pair a west-positive centroid, and it would tag this center.
        if (_gridTouched && locationFromLatLon(_theirExtra['lat'], _theirExtra['lon']) == null) ...{
          'lat': locationForStatedGrid(_gridController.text)?.latitude,
          'lon': locationForStatedGrid(_gridController.text)?.longitude,
          'locSource': null,
        },
        'call': call,
        'sent': _rstOrDefault(_rcvdController.text.trim()),
        // Matches the `AnnotatedCallInfo` TS type (`CallInfo & {guess?:
        // CallInfo, lookups?: CallInfoLookup[]}`, @ham2k/lib-qson-tools) and
        // app-polo's convention: the merged lookup guess stays NESTED under
        // `guess`/`lookups`, never flattened onto `their`'s own fields —
        // readers fall back to `their.guess.x` when `their.x` isn't set.
        if (_lookup.resultFor(call) case final result?) ...{'guess': result['guess'], 'lookups': result['lookups']},
      },
      'freq': _radio.freq,
      'band': _radio.band,
      'mode': _radio.mode,
      // The field owns the QSO's power whenever power is part of the entry
      // at all ([_powerShown]) — which is what keeps a record's own power
      // from being dropped by a save that only corrected its RST. Written
      // unconditionally then, INCLUDING null, exactly as refs/freq/band are
      // above: this map is merged over the record, so an omitted key leaves
      // the stored value standing and a wrong power could never be cleared.
      if (_powerShown) 'power': _powerWatts,
      'startAtMillis': ?startAtMillis,
      ..._currentQsoExtra,
      // The same active-overwrite rule as refs/freq/band/power above, and it
      // has to be stated separately because [_currentQsoExtra] DROPS an empty
      // note rather than holding one: an entry carrying nothing but a note
      // that was typed and deleted again must not read as composed
      // ([_hasComposedValues]). So the key is absent exactly when the note is
      // empty, and this map is merged over the record — leaving a note
      // deleted from a saved contact standing, with the field empty and the
      // save reporting success.
      //
      // Only where there is something to clear, though: `mergeConcurrentEdit`
      // reads what this map writes as an edit, so stamping an empty note on
      // every save would let a contact merely opened and re-saved overwrite
      // one another device added while the editor sat open. An empty string,
      // not null, because that is what a deliberate clear stores everywhere
      // else here — a stamp fills what is ABSENT, and this key is present.
      if (_currentQsoExtra.containsKey('notes') || (asQsonString(base['notes']) ?? '').isNotEmpty)
        'notes': (_currentQsoExtra['notes'] as String?) ?? '',
    };
  }

  // ---- "More" full-edit pane ----
  //
  // The form's shape — its sections, its fields and the rules about which of
  // them appear — lives in qso_edit_pane.dart. What is left here is applying
  // what comes back, which is the half that needs the controllers and the
  // override maps.

  Future<void> _openMoreEditor() async {
    final millis = _time.effectiveStartAtMillis;
    final dt = millis != null
        ? DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true)
        : nowUtc();
    // Captured so the Save handler below can tell "the user actually edited
    // Grid/State in this pane" from "the pane merely displayed whatever
    // was already there" — the latter must not turn a passive lookup guess
    // into a deliberately-touched, sticky value (see _gridTouched's doc).
    final gridBeforePane = _gridController.text.trim();
    final stateBeforePane = _stateController.text.trim();
    // Same displayed-vs-edited distinction for date/time: while composing,
    // the pane shows the live clock, and saving an untouched value must
    // not turn it into a manual override that freezes auto-timestamping.
    final dateBeforePane = TimeControlModel.fmtDate(dt);
    final timeBeforePane = TimeControlModel.fmtTime(dt);
    // What the contact itself says, override included — never the operation's
    // stand-in, which is only ever a placeholder here.
    final ourBeforePane = {...?asQsonMap(widget.editingQso?.data['our']), ..._ourExtra};
    final operatorBeforePane = (asQsonString(ourBeforePane['operatorCall']) ?? '').trim();
    final positionBeforePane = (asQsonString(ourBeforePane['multiIdentifier']) ?? '').trim();
    // The same displayed-vs-edited distinction once more, for every `their`
    // field the pane owns outright: a value merely shown must not be recorded
    // as an override, or a contact opened and saved would take its lookup's
    // guesses as entered values and stop tracking the lookup.
    final theirBeforePane = {...?asQsonMap(widget.editingQso?.data['their']), ..._theirExtra};
    final theirValuesBeforePane = theirPaneValues(theirBeforePane);

    final result = await showQsoEditPane(
      context,
      gridBeforePane: gridBeforePane,
      formDefinition: buildQsoEditFormDefinition(
        defaultOperatorCall: widget.defaultOperatorCall,
        defaultPosition: widget.defaultPosition,
        showPositionField: widget.showPositionField,
        their: asQsonMap(widget.editingQso?.data['their']),
        guess: _currentGuess,
        rstPaneKeyOrder: _rstPaneKeyOrder,
        rstPlaceholder: _rstPlaceholder,
        powerShown: _powerShown,
        composing: widget.editingQso == null,
        currentMode: _radio.modeForEditing,
      ),
      initialState: {
        'theirCall': _call,
        // Entered name only (not the `theirName` getter, which coalesces in the
        // guess) so a guessed-only name shows as the placeholder above instead
        // of being pre-filled — and merely viewing the pane never promotes a
        // passive guess to a sticky entered value.
        'theirName': _theirNameOverride ?? asQsonString(asQsonMap(widget.editingQso?.data['their'])?['name']) ?? '',
        'theirGrid': gridBeforePane,
        'theirState': stateBeforePane,
        'sent': _sentController.text.trim(),
        'rcvd': _rcvdController.text.trim(),
        'freq': _radio.freq,
        'band': _radio.band ?? '',
        'mode': _radio.modeForEditing,
        'power': _powerWatts,
        'date': TimeControlModel.fmtDate(dt),
        'time': TimeControlModel.fmtTime(dt),
        'notes': (_currentQsoExtra['notes'] as String?) ?? '',
        'operatorCall': operatorBeforePane,
        if (widget.showPositionField) 'multiIdentifier': positionBeforePane,
        ...theirValuesBeforePane,
        // Shown, never taken: `theirEntity` is `disabled`, and the save
        // handler below reads nothing back out of it.
        'theirEntity': theirEntityDisplay(asQsonMap(widget.editingQso?.data['their']), _currentGuess) ?? '',
      },
    );
    if (result == null || !mounted) return;

    // Same as the setVfo command dispatch: a deliberate pane Save, not
    // raw typing — push immediately rather than via the frequency field's
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
      // Through [_markGridTouched], not a bare flag: the pane's on-screen
      // coordinate clear runs on BLUR (`FormRenderer` hangs `onChange` off the
      // focus node), and `submit()` snapshots its values before the unfocus it
      // triggers has been delivered — so a grid typed and then saved with
      // Enter, or with the field still focused, reaches here with the
      // coordinate fields never blanked and no override recorded to blank
      // them. The drop has to happen on the value that was actually saved.
      if (grid != normalizeGrid(gridBeforePane)) _markGridTouched();
      _stateTouched = _stateTouched || state != stateBeforePane.toUpperCase();
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
        _powerController.text = power is num ? '$power' : '';
      }

      final stamped = paneStartAtMillis(result, dateBeforePane, timeBeforePane);
      if (stamped != null) _time.manualStartAtMillis = stamped;

      final notes = ((result['notes'] as String?) ?? '').trim();
      if (notes.isEmpty) {
        _currentQsoExtra.remove('notes');
      } else {
        _currentQsoExtra['notes'] = notes;
      }
      // The Notes control shows the same value; without this it would go on
      // showing what the contact said before the pane was opened.
      _notesController.text = notes;

      _theirExtra.addAll(theirPaneOverrides(result, theirValuesBeforePane));

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
      if (operatorCall != operatorBeforePane.toUpperCase()) _ourExtra['operatorCall'] = operatorCall;
      if (widget.showPositionField) {
        final position = panePosition(result['multiIdentifier']);
        if (position != positionBeforePane) _ourExtra['multiIdentifier'] = position;
      }

      _time.seedFields();
    });
    _populating = false;
    if (widget.editingQso == null) {
      // Power first: the frequency push notifies, and the seed that follows
      // rewrites the power field from the VFO — which would put the value
      // the pane just returned back to whatever it was before the pane
      // opened, and then commit THAT.
      _commitPower();
      _radio.pushVfo();
    }
  }

  // ---- Secondary control settings (show/hide + reorder) ----

  Future<void> _openControlSettingsDialog() async {
    final descriptors = _controlDescriptors();
    final byKey = {for (final d in descriptors) d.key: d};
    var order = _effectiveControlOrder(descriptors);
    // The stored set FIRST, and kept whole: the descriptors are what this
    // operation offers, so rebuilding the set from them alone would drop a
    // control hidden while some other activity was running — saving the
    // dialog here would then un-hide it everywhere. On top of that, the
    // never-decided default-hidden controls, which must arrive unchecked;
    // saving is what turns that into a recorded decision.
    var hidden = {
      ...widget.hiddenControlKeys,
      for (final descriptor in descriptors)
        if (_descriptorHidden(descriptor)) descriptor.key,
    };

    final result = await showHaloDialog<(List<String>, Set<String>)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => HaloDialog(
          title: Text(t.loggingControls.controlSettings),
          // The ReorderableListView scrolls itself, so the shell must not:
          // nesting two scrollables on one axis leaves the inner list with no
          // scroll extent, and a drag toward the edge has nothing to
          // auto-scroll. `wide` because this carries a list, not a prompt.
          scrollable: false,
          wide: true,
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
                        child: const Icon(MdiIcons.dragHorizontalVariant),
                      ),
                      title: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(descriptor.icon, size: 18),
                          const SizedBox(width: Space.lg),
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
          cancel: TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t.common.cancel),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop((order, hidden)),
              child: Text(t.common.save),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    widget.onControlsSettingsChanged?.call(result.$1, result.$2);
  }

  // ---- Lookup enrichment ----

  /// Alphanumeric length of the call about to be logged — the call-info panel
  /// and its live scoring switch on at ≥3 characters (issue #40).
  int get _callInfoAlnumLength => _callAtCursor.replaceAll(RegExp('[^A-Z0-9]'), '').length;
  bool get _callInfoActive => _callInfoAlnumLength >= 3;

  void _onCallChanged() {
    if (_populating) return;
    // Past the guard, the change is the operator's own — typing, or the clear
    // that `_wipe` does — which is exactly what the spots list wants to hear
    // about. A suggestion filling the field never reaches here.
    widget.onCallEdited?.call();
    setState(() {});
    // The first character of a call is what takes a serial number.
    unawaited(_refreshSerialPreviews());
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
    if (_guessedRefsForCall != null && !_callsInField.contains(_guessedRefsForCall) && _clearGuessedRefs()) {
      setState(() {});
    }
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
  /// QSO-scoped activity controls (e.g. POTA's DXCC-derived placeholder)
  /// are refreshed off the offline pass ONLY, deliberately not again after
  /// the online pass. Two reasons: (1) the offline pass's callsign-annotation
  /// pre-step already resolves the DXCC entity a placeholder/prefix depends
  /// on — the online pass adds QRZ/HamDB detail that doesn't change that
  /// entity, so a second refresh would almost always re-fetch the same
  /// descriptors; (2) two independent unawaited refreshes for the same call,
  /// with no ordering guarantee between them, could race — a slower
  /// offline-triggered refresh resolving after a faster online-triggered one
  /// would overwrite the fresher result with a stale one. A single refresh
  /// point sidesteps that entirely. A cache hit refreshes too: typing back to
  /// a call reaches the lookup only through the cache, and its guessed refs
  /// were just cleared.
  void _onLookupResolved(String call, Map<String, dynamic>? result, LookupPhase phase) {
    switch (phase) {
      case LookupPhase.cached:
      case LookupPhase.offline:
        _applyGuessRefs(result, call);
        unawaited(_refreshActivityControlsFor(call));
      case LookupPhase.online:
        if (_applyGuessRefs(result, call)) _relookupForRefsChanged();
    }
  }

  /// [CallLookupModel.relookupForRefsChanged], gated on this panel not being
  /// in the middle of writing the fields itself.
  void _relookupForRefsChanged() {
    if (_populating) return;
    _lookup.relookupForRefsChanged();
  }

  /// Re-fetches `activityControls` for [activeCall]'s QSO via
  /// `widget.refreshActivityControls`, discarding the result if the active
  /// call moved on (or the widget was disposed) while awaiting — the same
  /// staleness guard the lookup itself uses.
  Future<void> _refreshActivityControlsFor(String activeCall) async {
    final refresh = widget.refreshActivityControls;
    if (refresh == null) return;
    final requestGeneration = _activityControlsGeneration;
    final controls = await refresh(_getCurrentQsoData(callOverride: activeCall));
    if (!mounted || _callAtCursor != activeCall) return;
    // The operation's own activity/ref set changed while this was in
    // flight — that fetch was issued against the OLD set, and applying it
    // now would silently reshadow the fresh `widget.activityControls`
    // `didUpdateWidget` already installed (see `_activityControlsGeneration`).
    if (requestGeneration != _activityControlsGeneration) return;
    // Null is "the fetch failed", so the panel keeps the controls it is
    // already showing rather than blanking the QSO in progress.
    if (controls == null) return;
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
  /// (ham2k/halo-dist#199), unlike Revert, which discards changes and
  /// stays in edit mode. When composing a new QSO it goes through the wipe
  /// button's path, so the 5-second undo offer applies to Esc too.
  void _handleEscape() {
    if (_fieldsLocked) return;
    if (widget.escapeClaimed?.call() ?? false) return;
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

  /// [focusCall] false leaves the focus where it is — for a wipe the operator
  /// did not ask for from this panel (a slid spot row closing, say), or one
  /// that ends a gesture made on another surface, where pulling focus here
  /// would raise the mobile keyboard over the list they are actually working.
  ///
  void _wipe({bool focusCall = true}) {
    // The draft is gone, and so is its hold on a number. After a commit this
    // is a no-op — the log path released with the committed numbers already.
    widget.serialNumbers?.release(widget.operation.uuid);
    _suggestedCall = null;
    _suggestionWasTentative = false;
    _radio.settlePendingFreqEdit();
    _callController.clear();
    _clearRSTs();
    _gridController.clear();
    _stateController.clear();
    _theirNameOverride = null;
    _unmatchedRefs = [];
    _gridTouched = false;
    _stateTouched = false;
    _lookup.cancelLookup();
    _lookup.reset();
    _controlRefs.clear();
    _guessedRefs = const [];
    _guessedRefsForCall = null;
    _clearTextControls();
    _currentQsoExtra.clear();
    _notesController.clear();
    _ourExtra.clear();
    _theirExtra.clear();
    _time.manualStartAtMillis = null;
    _selectedControlKey = null;
    _clearPowerEntry();
    // The VFO's power is ambient, not composed — a wipe drops what the entry
    // stated and goes back to mirroring it, the way the Radio control does.
    _seedFromRadioService();
    if (focusCall) _callFocus.requestFocus();
    setState(_command.reset);
    _command.keystroke();
  }

  // ---- Wipe/undo, delete/undo, revert-changes: the info row's second button ----

  /// The part of [_hasComposedValues] a spot slide may not overwrite. The
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

  /// Whether the in-progress new QSO has anything actually worth wiping —
  /// the wipe button stays visible but disabled when this is false. With a
  /// `radioService`, freq/band merely mirror the operation's VFO (seeded on
  /// entry, not something the operator composed for this specific QSO) and
  /// don't count; without one, they fall back to the pre-VFO behavior.
  bool get _hasComposedValues =>
      _call.isNotEmpty ||
      (widget.radioService == null && (_radio.freqController.text.trim().isNotEmpty || _radio.manualBand != null)) ||
      _time.manualStartAtMillis != null ||
      _theirNameOverride != null ||
      _controlRefs.values.any((refs) => refs.isNotEmpty) ||
      _controlTextValues.values.any((v) => v.trim().isNotEmpty) ||
      _unmatchedRefs.isNotEmpty ||
      _currentQsoExtra.isNotEmpty ||
      _ourExtra.isNotEmpty ||
      // A VALUE, not merely a key: a draft restored after a field was cleared
      // in the More pane carries that field's null in the snapshot, and
      // counting those would leave a visibly empty row guarding itself
      // against a wipe and asking before a spot overwrites it.
      _theirExtra.values.any((value) => value != null) ||
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
    _time.manualStartAtMillis = data['startAtMillis'] as int?;
    setState(() {});
    _populating = false;
    // _populating suppressed _onCallChanged's own _scheduleLookup()/
    // _lookup.scheduleScore() calls above (population isn't the user typing) —
    // the wipe this undoes already cleared the lookup cache and score
    // notices, so a restored call would otherwise sit there unlooked-up
    // and without its dupe/New-* pills until the user edited the field
    // themselves.
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
      final ma = a is Map ? a : const <dynamic, dynamic>{};
      final mb = b is Map ? b : const <dynamic, dynamic>{};
      for (final key in {...ma.keys, ...mb.keys}) {
        if (!_deepEquals(ma[key], mb[key])) return false;
      }
      return true;
    }
    if (a is List || b is List) {
      final la = a is List ? a : const <dynamic>[];
      final lb = b is List ? b : const <dynamic>[];
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
    if (editingQso.isEvent) return !_deepEquals(_eventDataForSave(editingQso), editingQso.data);
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
        icon = MdiIcons.undo;
        actionLabel = t.loggingControls.undo;
        onPressed = _restoreFromUndoSlot;
      } else {
        icon = MdiIcons.backspaceOutline;
        actionLabel = t.loggingControls.wipe;
        onPressed = _hasComposedValues ? _handleWipeTap : null;
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
      onPressed = () => _populateFromEditingQso(editingQso);
    } else {
      icon = MdiIcons.trashCanOutline;
      actionLabel = t.common.delete;
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

  /// A QSO write threw: surface it in the info area (the same channel a
  /// command error uses — never a toast over the logging UI) and hand it to
  /// the host to report. The caller decides what field bookkeeping
  /// accompanies it; the fields themselves are never wiped on failure.
  ///
  /// The in-panel message is load-bearing, not a courtesy: the host's own
  /// notice for a write error shows at most once per session, so without it
  /// an operator on a full disk loses every QSO after the first in silence.
  void _reportWriteFailure(Object e, StackTrace stack, {bool delete = false}) {
    widget.onWriteError?.call(e, stack);
    if (!mounted) return;
    // A confirm-clear timer from an earlier command would wipe this message
    // moments after it appears — the failure owns the slot now.
    _command.showError(delete ? t.loggingControls.deleteFailed(error: e) : t.loggingControls.saveFailed(error: e));
  }

  /// [focusCall] false leaves the focus alone when the entry is wiped after
  /// logging — for a contact logged by a gesture made somewhere else (a spot
  /// row slid past the commit point). The operator is working the spots list,
  /// and taking focus here pops the on-screen keyboard up over it.
  Future<void> _log({bool focusCall = true}) async {
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
    if (widget.editingQso == null) {
      // Enter inside the claim window would otherwise commit a blank serial
      // field, and the allocator's fallback knows nothing of the peers' holds.
      final settled = await _settleSerialClaims();
      if (!settled || !mounted || _call != call || _isLogging) return;
    }
    if (widget.editingQso == null && call.isNotEmpty && widget.interpretCommand != null) {
      final (:interpretation, :stale) = await _command.interpretNow(applyToDisplay: false);
      {
        // Stale — the call changed while awaiting. `_isLogging` is re-checked
        // for a different reason: the entry guard above ran BEFORE this await,
        // and the flag isn't set until one of the branches below commits to
        // logging, so a second Enter arriving inside this window passed that
        // guard too and is now racing us to the same QSO. This is the ordinary
        // path, not an edge case — a plain callsign interprets to null, so
        // nothing is ever cached and every logging Enter awaits here. The
        // window is real: `interpretCommand` and `_decorated` are both JS
        // runtime round-trips, and key auto-repeat fires well inside them.
        if (stale || !mounted || _call != call || _isLogging) return;
      }
      // A recognized command that can't run in this context (its `error`
      // field is set — see CommandInterpretation) — surface the message,
      // keep the typed input for editing, and execute nothing.
      if (interpretation != null && interpretation['error'] is String) {
        _command.showError(interpretation['error'] as String);
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
          final executable = await _command.interpretForExecution();
          if (!mounted || _call != call) return; // stale — the call changed while awaiting
          if (executable == null) return;

          // A command can also fail at execute time (e.g. SOLAR/WEATHER's
          // network fetch, or the hook timing out entirely — see
          // interpretCommand) — surface the message and keep the typed
          // input, same treatment as the preview-time `error` branch above,
          // including cancelling any pending confirm-clear timer that would
          // otherwise wipe the error moments after it appears.
          if (executable['error'] is String) {
            _command.showError(executable['error'] as String);
            return;
          }

          _callController.clear();
          _command.commandExecuted(confirm: executable['confirm']);

          final commands = executable['commands'];
          if (commands is List) {
            try {
              await _dispatchActions(commands, skipOnlineLookup: executable['skipOnlineLookup'] == true);
            } catch (e, stack) {
              // A command's actions can write QSOs (e.g. a SEED batch) — a
              // throw mid-dispatch must not vanish into the zone handler
              // while the panel looks like the command ran.
              _reportWriteFailure(e, stack);
            }
          }
        } finally {
          _isLogging = false;
        }
        return;
      }
    }

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

    final editingQso = widget.editingQso;

    // Viewing a deleted QSO: the save button is disabled, but Enter is
    // also bound to _log — nothing to save until it's restored.
    if (editingQso != null && editingQso.deleted) return;

    if (editingQso != null && _pendingDelete) {
      _isLogging = true;
      try {
        await widget.qsosRepository.softDelete(editingQso);
      } catch (e, stack) {
        // The row is untouched and the delete stays staged — say so and let
        // the operator retry or cancel, instead of the editor silently
        // closing over a QSO that never actually deleted.
        _reportWriteFailure(e, stack, delete: true);
        return;
      } finally {
        _isLogging = false;
      }
      widget.onQsoDeleted?.call(editingQso);
      widget.onEditCanceled?.call();
      return;
    }

    // Events have none of the callsign/band/mode fields the checks below
    // exist for — save them straight from the inline editor's state.
    if (editingQso != null && editingQso.isEvent) {
      _isLogging = true;
      try {
        await widget.qsosRepository.update(
          Qso(
            uuid: editingQso.uuid,
            operationUuid: widget.operation.uuid,
            data: _eventDataForSave(editingQso),
          ),
          basedOn: editingQso,
        );
      } catch (e, stack) {
        // Editor stays open with the typed values — nothing committed.
        _reportWriteFailure(e, stack);
        return;
      } finally {
        _isLogging = false;
      }
      widget.onEditCanceled?.call();
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

    if (!_canLog) {
      // Pointing the operator at the field they have to fix — but only when
      // they are here to see it. A spot that cannot be logged (no usable
      // callsign) must not answer a gesture made on the spots list by raising
      // a keyboard over it.
      if (focusCall) _callFocus.requestFocus();
      return;
    }
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
      // cached lookup only rides along when `_getCurrentQsoData` is asked
      // about the call it was made for — the raw stacked field text never
      // matches it.
      final baseData = _getCurrentQsoData(callOverride: stacked?.calls.first);
      final baseStartAtMillis =
          (baseData['startAtMillis'] as int?) ?? nowMillis();

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
            'sent': _rstOrDefault(_rcvdController.text.trim()),
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
        try {
          // `basedOn` is the snapshot this edit was composed from: if a sync
          // pull moved the row while the editor sat open, only the fields
          // actually edited here overwrite it (see mergeConcurrentEdit).
          await widget.qsosRepository.update(
            Qso(
              uuid: editingQso.uuid,
              operationUuid: widget.operation.uuid,
              data: await _decorated(dataFor(calls.first, 0)),
            ),
            basedOn: editingQso,
          );
        } catch (e, stack) {
          // Nothing committed — the editor stays open with every typed value.
          _reportWriteFailure(e, stack);
          return;
        }
        for (var i = 1; i < calls.length; i++) {
          // The base data carries the edited QSO's own uuid (baseData came
          // from its record) — strip it so add() generates a fresh one for
          // this new QSO instead of colliding with the original.
          final data = dataFor(calls[i], i)..remove('uuid');
          final Qso qso;
          try {
            qso = await widget.qsosRepository.add(widget.operation.uuid, await _decorated(_withSerialConflicts(data)),
                serialSequences: _serialSequences);
          } catch (e, stack) {
            // Calls before [i] are already committed: keep the edited
            // record's own call plus only the still-unlogged ones in the
            // field, so retrying the Enter can't log the committed ones
            // twice.
            _callController.text = [calls.first, ...calls.sublist(i)].join(',');
            _reportWriteFailure(e, stack);
            return;
          }
          _releaseCommittedSerials(qso);
          widget.onLogged?.call(qso);
          widget.enqueueLookup?.call(qso);
        }
        widget.onEditCanceled?.call();
      } else {
        // Flush any pending debounced frequency push first, so a value
        // typed just before hitting Enter/Log is reflected in both the VFO
        // and this QSO, rather than only landing after the fact.
        _radio.flushPendingPush();
        for (var i = 0; i < calls.length; i++) {
          final Qso qso;
          try {
            qso = await widget.qsosRepository.add(
                widget.operation.uuid, await _decorated(_withSerialConflicts(dataFor(calls[i], i))),
                serialSequences: _serialSequences);
          } catch (e, stack) {
            // Nothing is wiped on failure — the fields keep every typed
            // value. With calls already committed (i > 0), the field is
            // rewritten to only the unlogged ones (plus the untouched rest
            // of a stack), cursor on them, so retrying the Enter can't log
            // the committed calls twice.
            if (i > 0) {
              final unlogged = calls.sublist(i).join(',');
              final text = stacked == null || stacked.remainder.isEmpty
                  ? unlogged
                  : '$unlogged//${stacked.remainder}';
              _callController.value = TextEditingValue(
                text: text,
                selection: TextSelection.collapsed(offset: unlogged.length),
              );
            }
            _reportWriteFailure(e, stack);
            return;
          }
          _releaseCommittedSerials(qso);
          widget.onLogged?.call(qso);
          widget.enqueueLookup?.call(qso);
        }
        _wipe(focusCall: focusCall);
        // The un-logged rest of the stack goes straight back into the
        // now-empty field, as if the operator had just typed it.
        if (stacked != null) _callController.text = stacked.remainder;
      }

      // A single rescoring pass after the whole batch, not a score check per
      // call — the on-screen scoring pills already only ever reflect the
      // cursor's own call (see `CallLookupModel.scheduleScore`/`_callAtCursor`).
      if (isList) widget.onCallListLogged?.call();
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
    if (widget.onCallInfoChanged != null || widget.onQsoChanged != null || widget.onPeerDraftChanged != null) {
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
    final editing = widget.editingQso != null;
    // Viewing an already-deleted QSO: fields are read-only, same as a
    // staged delete — the only actions are restoring it (the second
    // button) or selecting away (ham2k/halo-dist#59).
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

    _syncNumbersRow(context, accentTheme);

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
                // (ham2k/halo-dist#205) — SecondaryControlRow's own
                // `horizontalBleed` stays keyed to the fixed
                // `secondaryPanelHorizontalInset` only, so its expanded
                // panel still stops short of the physical edge by that
                // device inset instead of bleeding into it.
                padding: PaneSafeArea.symmetricOf(context, horizontal: secondaryPanelHorizontalInset)
                    .add(const EdgeInsets.only(bottom: Space.md)),
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
                            // Every pill still shows while editing an event —
                            // just disabled but Time, so the row's shape
                            // doesn't change between editing a contact and an
                            // event. A BREAK's grid/contest-exchange segment
                            // override has no editing UI yet either
                            // (docs/design/contests.md §5.1.3), so it stays
                            // disabled along with the rest.
                            controls: _buildSecondaryControls(
                              accentTheme,
                              accentPoloColors,
                              enabledFor: _editingEvent ? (key) => key == 'time' : null,
                            ),
                            selectedKey: _selectedControlKey,
                            onSelect: _onSelectControl,
                            onOpenSettings: _openControlSettingsDialog,
                            horizontalBleed: secondaryPanelHorizontalInset,
                            // The dupe warning (and the other scoring notices)
                            // live on the info area's third line — see
                            // `_buildInfoArea` (issue #40).
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.md),
                      // A min-height container: at least the second edit
                      // button's own diameter (see _buildWipeOrEditButton) so a
                      // one-line info area can't leave the button overflowing
                      // upward into the secondary control chips above, but free
                      // to grow taller for the call-info panel's up-to-three
                      // lines (issue #40).
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(minHeight: _editButtonDiameter ?? 44),
                            child: SizedBox(
                              width: double.infinity,
                              // Reserves room for the button positioned on
                              // top of this box (below), so text truncates
                              // before it rather than rendering underneath.
                              child: Padding(
                                padding: widget.leftieMode
                                    ? EdgeInsets.only(left: (_editButtonDiameter ?? 44) + Space.md)
                                    : EdgeInsets.only(right: (_editButtonDiameter ?? 44) + Space.md),
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
                                      ?currentChild,
                                    ],
                                  ),
                                  child: KeyedSubtree(
                                    key: ValueKey(_infoGeneration),
                                    // The tap-to-open-the-detail-panel gesture
                                    // is applied inside `_buildInfoArea`, to
                                    // the call-info content alone — the
                                    // missing-band/mode row above it is about
                                    // this station's radio, and must not answer
                                    // a tap with a panel about the other one.
                                    child: fieldsLocked
                                        ? LockedFormWarning(theme: theme, text: _lockedWarningText(deletedQso))
                                        : _buildInfoArea(accentTheme),
                                  ),
                                ),
                              ),
                            ),
                            ),
                          ),
                          // In the same stack as the info area, under it, so
                          // the wipe/undo button below pins to the bottom of
                          // BOTH — directly over the log button — rather than
                          // floating above the strip. Kept off the log button's
                          // column: the strip ends over the rightmost field
                          // (its close button sits there). Same reserve the
                          // entry row makes — the button's diameter plus gap.
                          if (widget.aboveEntryRow case final strip?)
                            Padding(
                              // No top inset of its own: the strip pads itself
                              // inside its slide, so nothing is spent while it
                              // is not showing.
                              padding: EdgeInsets.only(
                                right: widget.leftieMode ? 0 : (_editButtonDiameter ?? 44) + logButtonGap,
                                left: widget.leftieMode ? (_editButtonDiameter ?? 44) + logButtonGap : 0,
                              ),
                              child: strip,
                            ),
                            ],
                          ),
                          Positioned(
                            left: widget.leftieMode ? 0 : null,
                            right: widget.leftieMode ? null : 0,
                            bottom: 0,
                            child: _buildWipeOrEditButton(accentTheme),
                          ),
                        ],
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
                      // OUTSIDE the IntrinsicHeight below, never within it: a
                      // LayoutBuilder cannot answer an intrinsic-dimension
                      // query, and IntrinsicHeight asks its whole subtree one.
                      // Out here it sees exactly the width the Row will get,
                      // which is all `resolveMainFieldLayout` needs.
                      LayoutBuilder(builder: (context, constraints) {
                      // The log button is a circle as tall as the row, so the
                      // height already measured for it is also its width. The
                      // 44 fallback (first frame, before that measurement
                      // lands) matches the info area's own above. Read ONCE
                      // and handed to both: the row is reserved against it and
                      // a change in it counts as a re-layout, and those two
                      // must never disagree about which frame's value they saw.
                      final buttonWidth = _editButtonDiameter ?? 44;
                      // HaLo's big light-blue log button — a circle as
                      // tall as the text fields beside it. (A
                      // LayoutBuilder here to size the icon off the
                      // button's resolved constraints would seem
                      // natural, but IntrinsicHeight above needs to
                      // query this subtree's intrinsic dimensions, which
                      // LayoutBuilder explicitly doesn't support — so
                      // the icon just uses a fixed, comfortable size.)
                      // #236: stable id for agent/browser tooling.
                      //
                      // Keyed at this outer level (not just _submitButtonKey
                      // on the AspectRatio inside) because leftieMode moves
                      // this same widget between the Row's first and last
                      // slot below — without a key on the widget actually
                      // sitting in Row.children, Flutter's positional
                      // matching sees a plain, unkeyed Semantics widget at
                      // each slot and treats the move as two unrelated
                      // widgets (drop one, mount another) rather than one
                      // widget relocating. That's harmless on its own, but
                      // doing it while a Dialog route is simultaneously open
                      // above this screen (HALO-55's settings dialog, for
                      // one) corrupts the semantics tree —
                      // `identical(childRenderObject, parentRenderObject)`
                      // asserting in RenderObject.computeChildGeometry — a
                      // live crash toggling Leftie Mode from that dialog.
                      final submitButtonWidget = KeyedSubtree(
                        key: const ValueKey('logging-controls-submit-button'),
                        child: semanticId(
                          'action.log',
                          AspectRatio(
                            key: _submitButtonKey,
                            aspectRatio: 1,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: FilledButton(
                                // Disabled while viewing a deleted QSO —
                                // there's nothing to save; restore first.
                                // `_command.hasExecutableCommand` lets the button
                                // accept a command too, matching Enter (a
                                // command isn't a callsign, so `_canLog` alone
                                // would leave it disabled — see that getter).
                                // `_editingEvent` skips both: an event row has
                                // neither a callsign nor a command to accept.
                                onPressed: (!deletedQso &&
                                        (_pendingDelete || _canLog || _command.hasExecutableCommand || _editingEvent))
                                    ? _log
                                    : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: accentTheme.colorScheme.tertiary,
                                  foregroundColor: accentTheme.colorScheme.onTertiary,
                                  minimumSize: Size.zero,
                                  padding: EdgeInsets.zero,
                                  shape: const CircleBorder(),
                                ),
                                child: Icon(
                                  _pendingDelete
                                      ? MdiIcons.trashCan
                                      : (editing ? MdiIcons.contentSave : MdiIcons.upload),
                                  size: 24 * 1.2 * MediaQuery.textScalerOf(context).scale(1.0),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );

                      // An event/annotation row has no callsign or exchange —
                      // just a kind label and, for NOTE/TODO, the text (and
                      // done state) the annotation commands wrote. Swap the
                      // whole main-fields row for that instead of running it
                      // through `_trailingMainFields`/`resolveMainFieldLayout`,
                      // which only make sense for a QSO's field set.
                      if (_editingEvent) {
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (widget.leftieMode) ...[
                                submitButtonWidget,
                                SizedBox(width: logButtonGap),
                              ],
                              Expanded(
                                child: _buildEventFields(context, accentTheme, fieldsLocked),
                              ),
                              if (!widget.leftieMode) ...[
                                SizedBox(width: logButtonGap),
                                submitButtonWidget,
                              ],
                            ],
                          ),
                        );
                      }

                      final trailingFields = _trailingMainFields(context, enabled: !fieldsLocked);
                      final (layout: fieldLayout, :squeezed) = resolveMainFieldLayout(
                        fields: trailingFields,
                        maxWidth: constraints.maxWidth,
                        buttonWidth: buttonWidth,
                        floors: mainFieldFloors(context),
                      );
                      _mainFieldsSqueezed = squeezed;
                      final widthDuration =
                          _mainFieldWidthDuration(constraints.maxWidth, buttonWidth);
                      final logButtonGapBox = SizedBox(width: logButtonGap * fieldLayout.gapScale);

                      // IntrinsicHeight + stretch, rather than a guessed
                      // pixel height, so the submit button (an AspectRatio
                      // circle) is guaranteed to exactly match whatever
                      // height the text fields actually render at — not an
                      // eyeballed constant that drifts if their font size,
                      // padding, or text scale ever changes.
                      return IntrinsicHeight(
                        child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.leftieMode) ...[
                            submitButtonWidget,
                            logButtonGapBox,
                          ],
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
                              // The callsign field is the default focus —
                              // except on mobile with no physical keyboard,
                              // where the view starts unfocused so the
                              // operator isn't met with a virtual keyboard
                              // covering half the screen
                              // (docs/design/logging-fields.md). Read per
                              // build, not watched: the channel's answer
                              // normally beats navigation into an operation,
                              // and losing that race only costs one tap.
                              autofocus: !isMobilePlatform || hardwareKeyboardAttached.value,
                              autocorrect: _command.mixedCase,
                              enableSuggestions: _command.mixedCase,
                              // A command awaiting parameters (expectsParams)
                              // switches the field to free-text entry —
                              // spaces allowed, no callsign character
                              // restriction — but stays uppercase-only
                              // unless the command itself declared
                              // `mixedCase: true` (e.g. NOTE, whose
                              // parameter is free prose): all logging input
                              // is uppercase unless explicitly mixed-case.
                              textCapitalization: _command.mixedCase
                                  ? TextCapitalization.sentences
                                  : TextCapitalization.characters,
                              // In command free-text modes a space is a literal
                              // parameter character, so those modes take the
                              // narrower interceptor: it stands aside for every
                              // space but the double-space that leaves the
                              // field. Normal callsign mode routes every space
                              // to focus/command handling. Asked via
                              // [_command.fieldAcceptsSpaces], the same getter
                              // `_handleSpace` uses to decide the exit — the two
                              // must never disagree about the field's mode.
                              inputFormatters: !_command.fieldAcceptsSpaces
                                  ? [
                                      _virtualSpace,
                                      FilteringTextInputFormatter.allow(RegExp('[$callsignCharacters]')),
                                      if (isMobilePlatform) MobileDotToSlashFormatter(),
                                      const UpperCaseTextFormatter(),
                                    ]
                                  : _command.mixedCase
                                      ? [_commandVirtualSpace]
                                      : [_commandVirtualSpace, const UpperCaseTextFormatter()],
                              style: mainFieldStyle(context, fontWeight: FontWeight.w500),
                              decoration: mainFieldDecoration(
                                context,
                                t.loggingControls.theirCall,
                                horizontalPadding: fieldLayout.fieldPadding,
                              ),
                              onEditingComplete: () => _finishEditingWithoutBlur(_callController),
                              onSubmitted: (_) => _log(),
                            )),
                          ),
                          // Declared and sized in `_trailingMainFields` /
                          // `resolveMainFieldLayout` above, so the row and the
                          // width arithmetic can't disagree about which fields
                          // are on and how much room they take. The gaps carry
                          // the same scale as the padding inside the fields —
                          // they are given up together, as one concession.
                          for (var i = 0; i < trailingFields.length; i++) ...[
                            SizedBox(width: trailingFields[i].gapBefore * fieldLayout.gapScale),
                            trailingFields[i]
                                .build(fieldLayout.widths[i], fieldLayout.fieldPadding, widthDuration),
                          ],
                          if (!widget.leftieMode) ...[
                            logButtonGapBox,
                            submitButtonWidget,
                          ],
                        ],
                        ),
                      );
                      }),
                          ?_buildOptionSuggestionMenu(accentTheme),
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
              if (_bottomReserve > 0)
                SizedBox(
                  width: double.infinity,
                  height: _bottomReserve,
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
    return FocusScope(node: _focusBackstop.panelScope, child: panel);
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
    if (!isMobilePlatform) return 0;
    if (View.of(context).viewInsets.bottom > 0) return 0;
    return MediaQuery.paddingOf(context).bottom;
  }

  /// Whether to show the mobile numbers row right now — the setting is on,
  /// we're on a phone/tablet, the QSO isn't a read-only (staged/already
  /// deleted) view, the on-screen keyboard is up, and one of our logging
  /// fields actually holds the focus (issue #27).
  bool _shouldShowNumbersRow(BuildContext context) {
    return widget.showNumbersRow &&
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
    final accessory = widget.keyboardAccessory;
    if (accessory == null) return;
    final spec = _shouldShowNumbersRow(context)
        ? KeyboardAccessorySpec(
            onKey: _handleNumberKey,
            extraKey: _numbersRowExtraKey,
            vibrate: widget.vibrateNumbersRow,
            // The AppBar/footer colour — the app's chrome — deliberately NOT
            // the editing-swappable tertiary/secondary accent, so the row
            // reads as chrome in every mode. (appBarTheme isn't remapped by
            // the editing accent, so `theme` here being the accent theme is
            // fine.)
            backgroundColor:
                (theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary).toARGB32(),
            foregroundColor:
                (theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary).toARGB32(),
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
    final editing = widget.editingQso;
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
    final ready = widget.editingQso == null || widget.scoreQso == null || _lookup.scoreIsCurrent;
    final guess = ready ? _currentGuess : null;
    return CallInfoData(
      call: _callAtCursor,
      guess: guess,
      lookups: _currentLookups,
      alertKeys: ready ? _lookup.currentAlertKeys : const [],
      noticeKeys: ready ? _lookup.currentNoticeKeys : const [],
      isEditing: widget.editingQso != null,
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
      locationLine: guess == null ? null : widget.callLocationLine?.call(guess),
      // Asked only when it would show: it walks the exchange fields.
      gridOnlyLine: message == null && callInfo == null ? _gridOnlyLine : null,
      statsLines: () => widget.operationStatsLines?.call(widget.qsos) ?? const <String>[],
      noticeLabel: widget.scoreNoticeLabel,
      workedBeforeLabel: widget.workedBeforeLabel,
      onCallInfoTap: widget.onCallInfoTap,
      onOpenLink: widget.onOpenLink,
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
    final kind = widget.editingQso?.eventKind?.toUpperCase();
    return (refusal != null)
        ? refusal.reason
        : (kind != null)
        ? (deletedQso
            ? t.loggingControls.deletedEventWarning(kind: kind)
            : t.loggingControls.pendingDeleteEventWarning(kind: kind))
        : (deletedQso ? t.loggingControls.deletedQsoWarning : t.loggingControls.pendingDeleteWarning);
  }

  /// What the contact in hand is missing from the radio state that every QSO
  /// needs: a band (or a frequency to derive one from) and a mode. Empty —
  /// the normal state — paints nothing.
  ///
  /// Never while editing an event row. A NOTE is not a contact and needs no
  /// band, and the `event` band sentinel it carries does not survive into
  /// `_radio.band`: the record's zero frequency sends `_applyFieldsFromData` down
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
  /// arrow keys would jump under the operator's hands.
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
                  padding: const EdgeInsets.symmetric(horizontal: namePadding, vertical: Space.xs),
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
                padding: const EdgeInsets.symmetric(vertical: Space.xs),
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
    final line = widget.callLocationLine?.call(guess);
    return (line == null || line.isEmpty) ? null : line;
  }

  Map<String, dynamic>? get _gridOnlyGuess {
    if (_callInfoActive || _editingEvent) return null;
    var grid = '';
    for (final control in _textControls) {
      if ((control['input'] as Map?)?['field'] != 'grid') continue;
      grid = (_controlTextValues[control['key'] as String] ?? '').trim();
      if (grid.isNotEmpty) break;
    }
    if (grid.isEmpty && widget.showGridField) grid = _gridController.text.trim();
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
    final their = asQsonMap(widget.editingQso?.data['their']);
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
      isEditing: widget.editingQso != null,
      workedBefore: _lookup.workedBefore,
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
        : '${data.call}|${_lookup.lookupFor}|${data.isEditing}|${g?['name']}|${g?['grid']}|${g?['image']}|${g?['note']}'
            '|${data.alertKeys.join(",")}|${data.noticeKeys.join(",")}';
    if (sig == _lastCallInfoSig) return;
    _lastCallInfoSig = sig;
    widget.onCallInfoChanged!(data);
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
  /// A published draft is READ-ONLY to everyone downstream. `_getCurrentQsoData`
  /// shares nested references with the QSO being edited and with the lookup
  /// result, and the map handed out below is the same one kept here — so
  /// mutating a published draft in place moves both sides of the comparison
  /// together, and the panel watching it silently stops updating.
  Map<String, dynamic>? _lastPublishedQso;
  List<PeerDraftField>? _lastPublishedFields;
  void _notifyQsoDraft() {
    final wantsDraft = widget.onQsoChanged != null;
    final wantsPeer = widget.onPeerDraftChanged != null;
    if (!wantsDraft && !wantsPeer) return;
    // Built once and handed to both — the deep compare below is the expensive
    // half, not this.
    final qso = _getCurrentQsoData();
    final unchanged = const DeepCollectionEquality().equals(qso, _lastPublishedQso);
    // Deduped separately, never on `unchanged` alone: a report the operator
    // types over its own placeholder leaves the draft identical and changes
    // only what [_peerDraftFields] answers (see `onPeerDraftChanged`).
    if (wantsPeer) {
      final fields = _peerDraftFields();
      if (!unchanged || !const DeepCollectionEquality().equals(fields, _lastPublishedFields)) {
        _lastPublishedFields = fields;
        widget.onPeerDraftChanged!(qso, fields);
      }
    }
    if (wantsDraft && !unchanged) widget.onQsoChanged!(qso);
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
        for (final field in _primaryFields)
          (
            key: field.key,
            label: field.label,
            value: field.controller.text.trim(),
            hint: field.hint?.trim(),
          ),
      ];

}
