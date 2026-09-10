// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The callbacks the logging panel is wired up with: what the app hands
// `LoggingControls` so the panel can look a callsign up, run a command, score
// a contact, spot it, and tell the app what the operator is composing.
//
// Their own file because they are the panel's INTERFACE rather than any of its
// behaviour — the app reads these to know what it owes the panel, and reading
// them should not mean opening the panel itself.

import 'package:halo_core/halo_core.dart';

import 'call_info_summary.dart';

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
/// shows them — see [LoggingControls.onPeerDraftChanged].
typedef PeerDraftChanged = void Function(Map<String, dynamic> qso, List<PeerDraftField> fields);
