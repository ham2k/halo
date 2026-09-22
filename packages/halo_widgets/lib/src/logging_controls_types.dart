// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the logging panel is wired up with: the callbacks the app hands
// `LoggingControls` so the panel can look a callsign up, run a command, score
// a contact, spot it, and tell the app what the operator is composing — and
// the groups those arrive in, one per concern the panel has.
//
// Their own file because they are the panel's INTERFACE rather than any of its
// behaviour — the app reads these to know what it owes the panel, and reading
// them should not mean opening the panel itself.

import 'package:flutter/widgets.dart';
import 'package:halo_core/halo_core.dart';

import 'call_info_summary.dart';
import 'inline_markdown.dart';
import 'keyboard_accessory.dart';
import 'logging_controls_controller.dart';
import 'logging_controls_esm.dart';
import 'ref_text_input.dart';

/// Async callsign enrichment (name, location, grid…) from lookup sources —
/// the hardcoded callsign-annotation pre-step plus every registered
/// `lookup` hook, merged with locationScope-aware rules. `qso`/`operation`
/// give QSO-scoped hooks (e.g. POTA) access to refs already on the
/// in-progress QSO; `online: false` asks every hook to skip network access,
/// for a fast local-data-only preview pass. Returns `{lookups, guess}`, or
/// null meaning "nothing known". Must never throw.
///
/// `recentContext` additionally runs the lookup sources whose answer only
/// makes sense for a contact being composed right now — spot history, and
/// whatever else comes to describe what a station is doing at this moment.
/// Optional (defaulting to false in implementations) so a caller that only
/// wants to know who a callsign belongs to needn't say so.
typedef CallLookup = Future<Map<String, dynamic>?> Function(
  String call, {
  required Map<String, dynamic> qso,
  required Map<String, dynamic> operation,
  required bool online,
  bool recentContext,
});

/// When the log's earlier contacts with [call] started (epoch millis) — the
/// compact call-info's worked-before pill. [excludingQsoUuid] is the QSO
/// being edited, when there is one, so its own row is not a prior contact.
/// Fetched by the app layer, which owns the log; the widget only asks.
typedef WorkedBefore = Future<List<int>> Function(String call, {String? excludingQsoUuid});

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
/// [CommandHooks.onDispatcherChanged] for callers outside the logging
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

/// Fires when the current call-info changes (call/lookup/score), or null when
/// the call-info panel isn't showing. Deduped by the widget.
typedef CallInfoChanged = void Function(CallInfoData? info);

/// The QSO being composed, in QSON, as it stands right now — the same shape
/// that would be logged if the operator hit Enter.
typedef QsoDraftChanged = void Function(Map<String, dynamic> qso);

/// One main logging field, as a peer's panel renders it: what it is called,
/// what the operator typed, and the suggestion standing in while they have
/// not. An empty [value] beside a [hint] is the app's answer; a non-empty
/// [value] is the operator's own.
typedef PeerDraftField = ({String key, String label, String value, String? hint});

/// The draft, plus the main logging fields in the order the sender's own row
/// shows them — see [LoggingSession.onPeerDraftChanged].
typedef PeerDraftChanged = void Function(Map<String, dynamic> qso, List<PeerDraftField> fields);

/// The log the panel writes to and reads: the operation, its repository and
/// QSOs, and what the app hears when a contact lands, is deleted or restored,
/// or fails to write.
class LogHooks {
  const LogHooks({
    required this.operation,
    required this.qsosRepository,
    this.serialNumbers,
    this.qsos = const [],
    this.onLogged,
    this.onQsoDeleted,
    this.onQsoUndeleted,
    this.onCallListLogged,
    this.decorateQsoBeforeSave,
    this.onWriteError,
  });

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

  /// A QSO write failed. The panel has already shown its own failure message
  /// in the info area; this is the host's hook to report the error
  /// (Sentry/console). The error does NOT also escape to the zone handler,
  /// so a host that leaves this unwired records nothing.
  final void Function(Object error, StackTrace stackTrace)? onWriteError;

  /// The log with some of it replaced — what a caller holding one of these
  /// writes to vary a field instead of restating the rest. A null argument
  /// keeps what is here, so nothing can be cleared through it. Offered for
  /// the panel's own test helper, which merges its defaults into whatever
  /// groups a test hands it; the app builds each group outright. Construct a
  /// fresh [LogHooks] for that.
  @visibleForTesting
  LogHooks copyWith({
    Operation? operation,
    QsosRepository? qsosRepository,
    SerialNumberSource? serialNumbers,
    List<Qso>? qsos,
    void Function(Qso qso)? onLogged,
    void Function(Qso qso)? onQsoDeleted,
    void Function(Qso qso)? onQsoUndeleted,
    VoidCallback? onCallListLogged,
    Future<Map<String, dynamic>> Function(Map<String, dynamic> qso, Map<String, dynamic> operation)? decorateQsoBeforeSave,
    void Function(Object error, StackTrace stackTrace)? onWriteError,
  }) =>
      LogHooks(
        operation: operation ?? this.operation,
        qsosRepository: qsosRepository ?? this.qsosRepository,
        serialNumbers: serialNumbers ?? this.serialNumbers,
        qsos: qsos ?? this.qsos,
        onLogged: onLogged ?? this.onLogged,
        onQsoDeleted: onQsoDeleted ?? this.onQsoDeleted,
        onQsoUndeleted: onQsoUndeleted ?? this.onQsoUndeleted,
        onCallListLogged: onCallListLogged ?? this.onCallListLogged,
        decorateQsoBeforeSave: decorateQsoBeforeSave ?? this.decorateQsoBeforeSave,
        onWriteError: onWriteError ?? this.onWriteError,
      );
}

/// What the app is doing with the panel right now: the QSO it is editing, a
/// spot it is offering or asking to log outright, how the panel tells it what
/// the operator composes, and the keyboard's way out to the QSO list.
class LoggingSession {
  const LoggingSession({
    this.editingQso,
    this.suggestedQso,
    this.logRequest,
    this.confirmLogOverwrite,
    this.suggestedQsoIsTentative = false,
    this.onCallEdited,
    this.suggestionSettledSerial = 0,
    this.onEditCanceled,
    this.onNavigateToQsoList,
    this.escapeClaimed,
    this.enterSends,
    this.onQsoChanged,
    this.onPeerDraftChanged,
    this.controller,
  });

  /// When set, the controls are editing this already-logged QSO rather than
  /// composing a new one — fields are populated from it, saving calls
  /// `qsosRepository.update` instead of `.add`, and Delete/Revert become
  /// available. The Time control runs on the same distinction: editing an
  /// existing entry shows *its* recorded time instead of a live clock, and
  /// has no "Now" reset (there's no "automatic" time to reset back to for a
  /// historical record).
  final Qso? editingQso;

  /// A QSON-shaped `{their: {call}, freq?, band?, mode?, refs?}` map to
  /// prefill a new QSO's fields from — e.g. tapping a spot in the Spots
  /// Panel. Applied via the same field-population path as `editingQso`
  /// (`_applyFieldsFromData`), but never switches the panel into editing
  /// mode: Save still calls `.add`, not `.update`, and a suggestion arriving
  /// while `editingQso` is already set is ignored rather than overwriting
  /// that edit. Re-applies whenever a NEW map (by identity, not deep
  /// equality — the same convention the panel applies to
  /// [LogHooks.operation]'s `data['refs']`) is passed in.
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
  /// selection in response; the panel's own fields reset via
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

  /// Asked before Escape does anything here. True means the app has just
  /// used the key for something that outranks a wipe — stopping a CW
  /// message going out — and the fields are left alone. A HardwareKeyboard
  /// handler's own "handled" answer cannot do this: the focus tree is
  /// dispatched to regardless, so the app's Escape and the panel's would
  /// otherwise both fire on one keystroke.
  final bool Function()? escapeClaimed;

  /// Asked at each keyboard Enter composing a new contact: Enter Sends
  /// Messages as it stands right now, or null when it is off. While on, the
  /// Enter keys the messages [esmStep] picks and may stop short of logging
  /// (docs/design/logging-fields.md § Enter Sends Messages). Asked rather
  /// than passed, like [escapeClaimed]: whether anything can key changes
  /// with the radio, which rebuilds nothing here. The submit button never
  /// asks — it is a deliberate "log this", not the keyboard's rhythm through
  /// an exchange.
  final EnterSends? Function()? enterSends;

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

  /// Optional imperative handle for driving the controls from outside (set the
  /// call, log, wipe) — used by the app's dev bridge. Attached on mount.
  final LoggingControlsController? controller;
}

/// The rig the panel mirrors: the VFO store and its notifications, the
/// transceiver's status as the app resolves it, the operator's own region for
/// the band plan, and which bands and modes the dropdowns offer.
class RadioHookup {
  const RadioHookup({
    this.radioService,
    this.radioUpdates,
    this.hasConfiguredRadio = false,
    this.radioConnected = false,
    this.onOpenStationConfig,
    this.radioName,
    this.ourItuRegion,
    this.ourCountryCode,
    this.enabledBands,
    this.enabledModes,
    this.trackingPower = false,
  });

  /// Holds the radio's VFO state (`vfoA`) — device-global, shared by every
  /// operation, not scoped to this one. Used to seed the Radio control for
  /// a new QSO instead of resetting to a hardcoded default, and as the
  /// destination for its edits. When null, the Radio control is purely local
  /// to the panel.
  final VfoStore? radioService;

  /// Fires when [radioService]'s state changes — so the Radio control can
  /// follow a connected rig (CAT), or any other writer, live.
  ///
  /// Separate from [radioService] rather than folded into it because
  /// `VfoStore` lives in pure-Dart halo_core, which has no Flutter
  /// dependency and therefore no `Listenable`. In the app both are the same
  /// object (`RadioService`); when null the control reads the VFO only when
  /// it seeds.
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

  /// The operator's own ITU region (1/2/3) and lowercase ISO country code,
  /// from the callsign-annotation guess — see
  /// `operation_view.dart`'s `_resolveOurEntityPrefix`, which resolves both
  /// the same way it already resolves `ourEntityPrefix`. Passed straight
  /// through to [modeForFrequency] so a typed/commanded frequency gets a
  /// mode guess scoped to where the operator actually is, not just whatever
  /// generic segment happens to cover the frequency. Null (the default)
  /// leaves the guess to [modeForFrequency]'s own default — see its doc
  /// comment.
  final int? ourItuRegion;
  final String? ourCountryCode;

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

  /// The app is capturing the current power onto every QSO it saves
  /// (Station Configuration's "Track Station Info", with `power` among the
  /// tracked fields). The panel doesn't do that capture — the app does, at
  /// save — but it has to know, because a power that is being logged has to
  /// be visible and editable whether or not the Power control is in the row.
  final bool trackingPower;

  /// The rig with some of it replaced — what a caller holding one of these
  /// writes to vary a field instead of restating the rest. A null argument
  /// keeps what is here, so nothing can be cleared through it. Offered for
  /// the panel's own test helper, which merges its defaults into whatever
  /// groups a test hands it; the app builds each group outright. Construct a
  /// fresh [RadioHookup] for that.
  @visibleForTesting
  RadioHookup copyWith({
    VfoStore? radioService,
    Listenable? radioUpdates,
    bool? hasConfiguredRadio,
    bool? radioConnected,
    VoidCallback? onOpenStationConfig,
    String? radioName,
    int? ourItuRegion,
    String? ourCountryCode,
    List<String>? enabledBands,
    List<String>? enabledModes,
    bool? trackingPower,
  }) =>
      RadioHookup(
        radioService: radioService ?? this.radioService,
        radioUpdates: radioUpdates ?? this.radioUpdates,
        hasConfiguredRadio: hasConfiguredRadio ?? this.hasConfiguredRadio,
        radioConnected: radioConnected ?? this.radioConnected,
        onOpenStationConfig: onOpenStationConfig ?? this.onOpenStationConfig,
        radioName: radioName ?? this.radioName,
        ourItuRegion: ourItuRegion ?? this.ourItuRegion,
        ourCountryCode: ourCountryCode ?? this.ourCountryCode,
        enabledBands: enabledBands ?? this.enabledBands,
        enabledModes: enabledModes ?? this.enabledModes,
        trackingPower: trackingPower ?? this.trackingPower,
      );
}

/// Where the panel learns about a callsign and what it shows about one: the
/// lookup and its background queue, scoring and worked-before, the info
/// area's lines and labels, and the host's detail panel.
class LookupHooks {
  const LookupHooks({
    this.lookup,
    this.enqueueLookup,
    this.enqueueAllLookups,
    this.operationStatsLines,
    this.callLocationLine,
    this.scoreQso,
    this.scoreNoticeLabel,
    this.workedBefore,
    this.workedBeforeLabel,
    this.onCallInfoChanged,
    this.onCallInfoTap,
    this.onOperationInfoTap,
    this.onOpenLink,
  });

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

  /// The info area's three collaborators (issue #40). All optional — when
  /// null the area degrades gracefully: no stats lines, no location line, no
  /// scoring notices. See `LoggingControls`'s `_buildInfoArea`.
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

  /// Fires when the user taps the info area while it shows the call-info
  /// content — the host opens the detail panel (a modal on narrow layouts, or
  /// focuses the Info tab on wide).
  final VoidCallback? onCallInfoTap;

  /// Fires when the user taps the info area while it shows anything else —
  /// the statistics, a grid alone, a command's message — the host opens the
  /// operation's own info the same two ways, as it does for a QSO-list day
  /// header.
  final VoidCallback? onOperationInfoTap;

  /// Opens a link tapped in a call note. Null leaves the note's links styled
  /// but inert; the controls stay free of any url_launcher dependency either
  /// way — the app decides how links open.
  final InlineMarkdownOpenLink? onOpenLink;

  /// The lookups with some of it replaced — what a caller holding one of these
  /// writes to vary a field instead of restating the rest. A null argument
  /// keeps what is here, so nothing can be cleared through it. Offered for
  /// the panel's own test helper, which merges its defaults into whatever
  /// groups a test hands it; the app builds each group outright. Construct a
  /// fresh [LookupHooks] for that.
  @visibleForTesting
  LookupHooks copyWith({
    CallLookup? lookup,
    void Function(Qso qso)? enqueueLookup,
    void Function(Iterable<Qso> qsos)? enqueueAllLookups,
    OperationStatsLines? operationStatsLines,
    CallLocationLine? callLocationLine,
    ScoreQso? scoreQso,
    String Function(String noticeKey)? scoreNoticeLabel,
    WorkedBefore? workedBefore,
    String? Function(List<int> startTimes)? workedBeforeLabel,
    CallInfoChanged? onCallInfoChanged,
    VoidCallback? onCallInfoTap,
    VoidCallback? onOperationInfoTap,
    InlineMarkdownOpenLink? onOpenLink,
  }) =>
      LookupHooks(
        lookup: lookup ?? this.lookup,
        enqueueLookup: enqueueLookup ?? this.enqueueLookup,
        enqueueAllLookups: enqueueAllLookups ?? this.enqueueAllLookups,
        operationStatsLines: operationStatsLines ?? this.operationStatsLines,
        callLocationLine: callLocationLine ?? this.callLocationLine,
        scoreQso: scoreQso ?? this.scoreQso,
        scoreNoticeLabel: scoreNoticeLabel ?? this.scoreNoticeLabel,
        workedBefore: workedBefore ?? this.workedBefore,
        workedBeforeLabel: workedBeforeLabel ?? this.workedBeforeLabel,
        onCallInfoChanged: onCallInfoChanged ?? this.onCallInfoChanged,
        onCallInfoTap: onCallInfoTap ?? this.onCallInfoTap,
        onOperationInfoTap: onOperationInfoTap ?? this.onOperationInfoTap,
        onOpenLink: onOpenLink ?? this.onOpenLink,
      );
}

/// The activities' contribution to the panel: their declarative controls, a
/// per-QSO refresh of them, and reference decoration.
class ActivityHooks {
  const ActivityHooks({
    this.activityControls = const [],
    this.refreshActivityControls,
    this.decorateRef,
  });

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

  /// Async ref decoration via the extension runtime.
  final RefDecorator? decorateRef;
}

/// The command shortcuts typed into the call field: who interprets them, who
/// runs their actions, and how a command typed elsewhere reaches this panel.
class CommandHooks {
  const CommandHooks({
    this.interpretCommand,
    this.interpretationUpdates,
    this.onCommandMessageChanged,
    this.onCommandAction,
    this.onDispatcherChanged,
  });

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

  /// Called with the panel's action dispatcher when it mounts, and with
  /// null when it goes away, so a command typed somewhere else (the ⌘K
  /// dialog) can be applied to the live logging panel exactly as if it had
  /// been typed into the call field. See [CommandActionsDispatcher].
  final void Function(CommandActionsDispatcher?)? onDispatcherChanged;
}

/// The secondary control strip as the operator arranged it, and what the app
/// lays between the info area and the entry row.
class ControlStripSettings {
  const ControlStripSettings({
    this.controlOrder = const [],
    this.hiddenControlKeys = const {},
    this.onControlsSettingsChanged,
    this.aboveEntryRow,
  });

  /// The user's preferred order for the secondary control chips, by key
  /// (`'time'`, `'radio'`, an activity control's own key, `'more'`). Keys
  /// this doesn't mention are appended in their default order; keys it
  /// mentions that no longer exist (e.g. an uninstalled extension) are
  /// ignored. Persisted by the caller — see `SecondaryControlCatalog.effectiveOrder`.
  final List<String> controlOrder;

  /// Control keys hidden from the row. Time and Radio are never hidden
  /// regardless of what's in here — enforced by the panel, not the
  /// caller, so a corrupted/stale preference can't hide either.
  final Set<String> hiddenControlKeys;

  /// Fires when the user changes order or visibility in the controls
  /// settings dialog. The caller owns persisting it and feeding it back as
  /// `controlOrder`/`hiddenControlKeys` on the next build.
  final void Function(List<String> order, Set<String> hidden)? onControlsSettingsChanged;

  /// Laid between the info area and the entry row — the app's keyer
  /// area (docs/design/cat.md § CW keying), which halo_widgets has no CAT
  /// types to build itself. The widget owns its own size and animation, and
  /// takes no room at all while it has nothing to show, so the row above and
  /// below sit exactly as they do with it null.
  final Widget? aboveEntryRow;
}

/// The Spotting control's way out to the spotting networks.
class SpottingHooks {
  const SpottingHooks({
    this.suggestSpotSources,
    this.sendSpot,
  });

  /// Spotting control (ham2k/halo-dist#10) — null (either) disables the
  /// control's icon-row/send-button UI, matching how a null
  /// [RadioHookup.radioService] degrades the Radio control.
  final SuggestSpotSources? suggestSpotSources;
  final SendSpot? sendSpot;
}

/// The operator's logging preferences — which fields the row shows, what an
/// untouched report stands for, how the keyboard moves, and the mobile
/// affordances.
class LoggingPreferences {
  const LoggingPreferences({
    this.defaultOperatorCall = '',
    this.defaultPosition = '',
    this.showPositionField = false,
    this.showRSTFields = true,
    this.showStateField = false,
    this.showGridField = false,
    this.defaultReport = '',
    this.defaultReportCW = '',
    this.defaultReportFT8 = '',
    this.switchSentRcvd = false,
    this.jumpAfterRST = false,
    this.showNumbersRow = false,
    this.showExtraInNumbersRow = true,
    this.vibrateNumbersRow = true,
    this.leftieMode = false,
    this.keyboardAccessory,
  });

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
  /// on mobile platforms with the keyboard up (the panel's
  /// `_shouldShowNumbersRow` is the gate, `_syncNumbersRow` the publisher).
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

  /// The preferences with some of it replaced — what a caller holding one of these
  /// writes to vary a field instead of restating the rest. A null argument
  /// keeps what is here, so nothing can be cleared through it. Offered for
  /// the panel's own test helper, which merges its defaults into whatever
  /// groups a test hands it; the app builds each group outright. Construct a
  /// fresh [LoggingPreferences] for that.
  @visibleForTesting
  LoggingPreferences copyWith({
    String? defaultOperatorCall,
    String? defaultPosition,
    bool? showPositionField,
    bool? showRSTFields,
    bool? showStateField,
    bool? showGridField,
    String? defaultReport,
    String? defaultReportCW,
    String? defaultReportFT8,
    bool? switchSentRcvd,
    bool? jumpAfterRST,
    bool? showNumbersRow,
    bool? showExtraInNumbersRow,
    bool? vibrateNumbersRow,
    bool? leftieMode,
    KeyboardAccessoryController? keyboardAccessory,
  }) =>
      LoggingPreferences(
        defaultOperatorCall: defaultOperatorCall ?? this.defaultOperatorCall,
        defaultPosition: defaultPosition ?? this.defaultPosition,
        showPositionField: showPositionField ?? this.showPositionField,
        showRSTFields: showRSTFields ?? this.showRSTFields,
        showStateField: showStateField ?? this.showStateField,
        showGridField: showGridField ?? this.showGridField,
        defaultReport: defaultReport ?? this.defaultReport,
        defaultReportCW: defaultReportCW ?? this.defaultReportCW,
        defaultReportFT8: defaultReportFT8 ?? this.defaultReportFT8,
        switchSentRcvd: switchSentRcvd ?? this.switchSentRcvd,
        jumpAfterRST: jumpAfterRST ?? this.jumpAfterRST,
        showNumbersRow: showNumbersRow ?? this.showNumbersRow,
        showExtraInNumbersRow: showExtraInNumbersRow ?? this.showExtraInNumbersRow,
        vibrateNumbersRow: vibrateNumbersRow ?? this.vibrateNumbersRow,
        leftieMode: leftieMode ?? this.leftieMode,
        keyboardAccessory: keyboardAccessory ?? this.keyboardAccessory,
      );
}
