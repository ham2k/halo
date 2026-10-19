// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Export flow: the extension runtime generates each file's content (export
// hooks are extension territory, one `suggestExportOptions` call lists what's
// available, one `generateExport` call per selection produces it), the core
// owns file I/O and the save dialog/share sheet. One coarse bridge call per
// hook carries the whole operation.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_extension_host/halo_extension_host.dart' show HookCalls;
import 'package:uuid/uuid.dart';

import 'android_file_save.dart';
import 'export_preferences.dart';
import 'extensions/extension_service.dart';
import 'hook_payloads.dart';
import 'settings_service.dart';
import 'web_download.dart';

const _uuidGenerator = Uuid();

/// How long a free account's undownloaded stash counts as still wanted. A
/// free account keeps only its latest group, so stashing again replaces it —
/// worth a question while the operator may not have fetched it yet, not a
/// day later. The same window app-polo uses.
const stashReplaceWindow = Duration(hours: 6);

/// What stashing would take or cost, as far as the account can tell.
///
/// [needsEmail] is true when the account has no confirmed email address.
/// stash.ham2k.net signs in by email, and the link the result dialog offers
/// goes to that address, so without one a stash is a file the operator has
/// no way to fetch. A pending address doesn't count: nothing reaches it until
/// it is confirmed.
///
/// [freeAccount] says the account keeps only its latest stash, as the free
/// tier does — null when the account couldn't be read. [replaces] names the
/// stash the next one would replace; it is set whenever the account isn't
/// known to keep more than one, unread included, since the listing alone is
/// enough to know there is something to lose. An account that couldn't be
/// read never [needsEmail] — refusing on a failed read would block a stash
/// the server may well accept.
typedef StashPreflight = ({bool needsEmail, bool? freeAccount, String? replaces});

/// [StashPreflight] from the sync account snapshot and the account's latest
/// stash files (the server's `{'stash_files': [...]}`), at [nowMillis].
StashPreflight stashPreflightFrom({Map<String, dynamic>? accountData, Map<String, dynamic>? stashFiles, required int nowMillis}) {
  final account = accountData?['current_account'];
  final email = account is Map ? account['email'] : null;
  final needsEmail = accountData != null && (email is! String || email.trim().isEmpty);
  final freeAccount = accountData == null ? null : !_keepsEveryStash(accountData['subscription'], nowMillis);
  if (freeAccount == false) return (needsEmail: needsEmail, freeAccount: false, replaces: null);

  final files = stashFiles?['stash_files'];
  for (final file in files is List ? files : const []) {
    if (file is! Map || file['status'] == 'downloaded') continue;
    final createdAt = DateTime.tryParse('${file['created_at']}');
    if (createdAt == null || nowMillis - createdAt.millisecondsSinceEpoch > stashReplaceWindow.inMilliseconds) continue;
    final title = file['group_title'];
    return (needsEmail: needsEmail, freeAccount: freeAccount, replaces: title is String && title.isNotEmpty ? title : '${file['filename']}');
  }
  return (needsEmail: needsEmail, freeAccount: freeAccount, replaces: null);
}

/// Whether the server keeps every stash this account sends, rather than only
/// the latest — api-lofi's `Account#visible_stash_files`, which asks for a
/// paid subscription (`Account#paid_subscription?`) on a plan that retains
/// stashes at all.
///
/// Paid means a saved subscription (the free tier's default one never is, so
/// has no id) whose status is active or unverified and whose `ends_at`, if
/// any, is still ahead: a lapsed subscription stays on the account with its
/// id, and is answered as free. A plan naming no retention falls back to the
/// server's default, which keeps stashes; only a retention of 0 or less
/// keeps the latest alone.
bool _keepsEveryStash(Object? subscription, int nowMillis) {
  if (subscription is! Map || subscription['id'] == null) return false;
  if (subscription['status'] != 'active' && subscription['status'] != 'unverified') return false;
  final endsAt = subscription['ends_at'];
  if (endsAt != null) {
    final parsed = DateTime.tryParse('$endsAt');
    if (parsed == null || parsed.millisecondsSinceEpoch <= nowMillis) return false;
  }
  final plan = subscription['plan'];
  final retention = plan is Map ? plan['stash_retention_in_days'] : null;
  return retention is! num || retention > 0;
}

class ExportException implements Exception {
  final String message;
  ExportException(this.message);

  @override
  String toString() => message;
}

class ExportService {
  final ExtensionService extensions;
  final QsosRepository qsos;
  final SettingsService settings;

  /// Android's save flow, injectable so tests can drive it without a platform
  /// channel.
  final AndroidFileSave androidFileSave;

  ExportService({required this.extensions, required this.qsos, required this.settings, this.androidFileSave = const AndroidFileSave()});

  /// Raw QSON dump of the whole operation ([_qsonDumpFor]), offered only in
  /// developer mode — same as app-polo's devMode extension. Generated here in
  /// Dart, no extension involved.
  static const _qsonHookKey = 'core-devmode';
  static const _qsonExportType = 'devmode-qson';

  /// Whether [option] is that dump. Public because the panel marks it in the
  /// dev-mode accent, which is a theme colour rather than the hex string an
  /// extension declares — so the option map can't carry it.
  bool isQsonOption(Map<String, dynamic> option) => option['hookKey'] == _qsonHookKey && option['exportType'] == _qsonExportType;

  Map<String, dynamic> _qsonOptionFor(Operation operation) {
    final date = (operation.startAtMax ?? nowUtc()).toIso8601String().substring(0, 10);
    // The FIRST call, not the raw `stationCall` field: a multi-operator
    // operation holds "N0CALL, W1AW" there, and the comma and space would
    // land verbatim in the filename.
    final call = operation.stationCalls.first.replaceAll('/', '-');
    final shortUuid = operation.uuid.split('-').first;
    // The two forms the extension SDK's `exportFilename` produces, spelled
    // out here because this option never crosses the bridge. The uuid stays
    // in both: two dumps of the same operation on the same day are exactly
    // what a developer comparing them needs to tell apart.
    final filename = settings.useCompactFileNames ? '$call-${date.replaceAll('-', '')}-$shortUuid.qson' : '$date $call $shortUuid.qson';
    return {
      'hookKey': _qsonHookKey,
      'exportType': _qsonExportType,
      // Tagged with a callsign like every other option, even though the dump
      // itself is the whole operation. Untagged, it lands in a group of its
      // own keyed '' — which makes a perfectly ordinary single-station
      // operation look multi-station to the panel the moment developer mode
      // is on: callsign headers appear, the batch button moves, and the dump
      // gets a header of its own titled "Export".
      'stationCall': operation.stationCalls.first,
      'label': 'Developer Mode: QSON Export',
      'filename': filename,
      'icon': 'briefcase-upload',
      'priority': -100,
      'selectedByDefault': false,
    };
  }

  /// The developer QSON dump: the operation as this device stores it, whole,
  /// as app-polo's dump is — and what `importQsonOperation` takes back.
  ///
  /// Every row, not [_logFor]'s contacts: the `break`/`start` event rows ARE
  /// the segments, and a dump without them imports as one unsegmented
  /// operation whose later contacts take the base operation's refs and
  /// location. Unsliced and unstamped, so the file states what is stored, not
  /// what one hook was handed.
  ///
  /// Deleted contacts travel as tombstones, flagged the way sync sends them,
  /// because the flag is a row column and not in `data`. Purged ones are on
  /// their way out of the database, and stay out.
  ///
  /// The operation is its stored `data`, not the hook payload
  /// ([operationQsonFor]): that one resolves the operator for THIS device's
  /// seat and writes it over the positionless slot, so a copy of a
  /// multi-station log would name the second seat's operator as everyone's.
  /// The positionless operator is restated under `local`, the one place
  /// app-polo reads it.
  Future<Map<String, dynamic>> _qsonDumpFor(Operation operation) async {
    final rows = await qsos.forOperation(operation.uuid, includeDeleted: true);
    final operatorCall = asQsonString(operation.data['operatorCall']) ?? '';
    return {
      'operation': {
        ...operation.data,
        'uuid': operation.uuid,
        if (operatorCall.isNotEmpty) 'local': {'operatorCall': operatorCall},
      },
      'qsos': [
        for (final qso in rows)
          if (!qso.purged) {...qso.data, 'uuid': qso.uuid, if (qso.deleted) 'deleted': true},
      ],
    };
  }

  /// The operation's contacts, its event rows, and its segments.
  ///
  /// The segments are resolved from the FULL list, because the `break`/`start`
  /// event rows carrying the overrides are exactly what the contact list
  /// filters out (docs/design/contests.md §5.1.3) — the same trap
  /// `ScoringService.rescoreOperation` documents.
  Future<({List<Qso> qsos, List<Qso> events, SegmentedOperation segmented})> _logFor(Operation operation) async {
    final log = await _logOrNothing(operation);
    if (log == null) {
      throw ExportException('Nothing to export: this operation has no QSOs.');
    }
    return log;
  }

  /// The same log, with an empty one reported as null rather than thrown.
  ///
  /// Asking what an operation COULD export is a question an empty log
  /// answers — with nothing — where actually exporting one is a request it
  /// has to refuse. Thrown for both, the panel greets an operator whose only
  /// mistake was opening it before their first contact with "Export failed".
  Future<({List<Qso> qsos, List<Qso> events, SegmentedOperation segmented})?> _logOrNothing(Operation operation) async {
    final all = await qsos.forOperation(operation.uuid);
    final qsoList = all.where((q) => !q.isEvent).toList();
    if (qsoList.isEmpty) return null;
    return (qsos: qsoList, events: all.where((q) => q.isEvent).toList(), segmented: SegmentedOperation.from(operation: operation.data, qsos: all));
  }

  /// The QSOs one export is responsible for.
  ///
  /// An option naming a `refType` covers only the stretches where that activity
  /// was actually running — the segments carrying a ref of that type (§5.1.4).
  /// A contest that started at a break would otherwise put the whole operation
  /// into its Cabrillo, including the contacts made before it began: a false
  /// claim in a submitted file, and the same mistake the scorer made before
  /// §5.1.3 gated it.
  ///
  /// An option with no `refType` — the full ADIF — takes the whole log. So does
  /// an unsegmented operation, where every QSO is in the one segment and this
  /// is identity.
  ///
  /// An option naming one reference of that type — one park's file — takes
  /// only the segments carrying THAT reference (§5.1.4): a park activated
  /// after a break claims none of the contacts made at the park before it.
  /// `ref` names it; an activity bundle built before the field existed names
  /// it only as `templateData.ref`, which every per-reference option already
  /// carries for its filename. One naming none, naming a reference the
  /// segments never carried, or naming one with no contacts that the log did
  /// not move to from another, covers every reference of the type rather than
  /// quietly dropping half the log.
  List<Qso> _qsosForOption(Map<String, dynamic> option, List<Qso> qsoList, SegmentedOperation segmented) {
    final refType = option['refType'];
    if (refType is! String || refType.isEmpty) return qsoList;

    final refs = segmented.allRefs.where((ref) => ref['type'] == refType).toList();
    // Offered for an operation that doesn't carry the ref at all: leave the log
    // alone rather than writing an empty file over a hook's own judgement.
    if (refs.isEmpty) return qsoList;

    List<Qso> sliceFor(List<Map<String, dynamic>> carried) {
      final keep = <String>{
        for (final ref in carried)
          for (final qso in segmented.qsosFor(qsoList, ref)) qso.uuid,
      };
      return [
        for (final qso in qsoList)
          if (keep.contains(qso.uuid)) qso,
      ];
    }

    // A `ref` that is not a reference's code — a whole ref map, say — falls
    // through to `templateData.ref` rather than widening the file to the type.
    final ownRef = option['ref'];
    final named = ownRef is String && ownRef.isNotEmpty ? ownRef : asQsonMap(option['templateData'])?['ref'];
    final one = [
      for (final ref in refs)
        if (named is String && ref['ref'] == named) ref,
    ];
    if (one.isNotEmpty) {
      final scoped = sliceFor(one);
      // The log moved between references of this type, and a segment of its
      // own names this one: an empty slice is a park switched to with nothing
      // logged there yet. Widened to the type, it would claim every contact
      // made at the previous park for this one.
      final movedHere =
          refs.length > one.length && segmented.segments.skip(1).any((segment) => segment.refs.any((ref) => ref['type'] == refType && ref['ref'] == named));
      if (scoped.isNotEmpty || movedHere) return scoped;
    }

    final scoped = sliceFor(refs);
    // Same promise as the bail-out above, and it has to be made here too: a ref
    // can be on the operation while every segment override omits it, and then
    // the slice comes back EMPTY rather than absent.
    //
    // That state means the segments and the operation disagree, and today it
    // comes from HaLo itself — a save restamps only the LATEST segment, and
    // there is no segment UI yet (§5.1.3), so turning an activity on after a
    // break leaves every earlier stretch without it. An empty submission file
    // is the worse failure of the two: the operator gets a Cabrillo with no
    // QSOs in it and no indication why, while an over-broad one is visible in
    // the file and can be pruned. So the whole log wins until segments are
    // something the app maintains rather than only imports.
    return scoped.isEmpty ? qsoList : scoped;
  }

  /// The log as ONE station callsign sees it.
  ///
  /// A multi-operator station is logged once and owes each of its callsigns
  /// its own submission, so within a stretch run under several calls every
  /// QSO is claimed by whichever call is exporting — `our.call` is rewritten
  /// rather than filtered, which is what app-polo does
  /// (`generateExports.js:26`) and the only reading that produces a complete
  /// log per operator.
  ///
  /// ACROSS segments it is the opposite: a log that changed call at a `break`
  /// made those contacts under the call its own segment names, so a call takes
  /// only the segments naming it. Claiming the whole log for each would put
  /// contacts into a submission by a station that was not on the air for them.
  ///
  /// The exception is two of them working each other: after the rewrite that
  /// QSO says N0DEV worked N0DEV, which no program will accept and which polo
  /// drops for the same reason.
  /// [stationCall] null means the log is already one station's: nothing is
  /// reassigned and nothing is left out, and the pass runs only to stamp the
  /// segments below.
  List<Map<String, dynamic>> _qsosAs(String? stationCall, List<Qso> qsoList, SegmentedOperation segmented) {
    return [
      for (final qso in qsoList)
        () {
          if (stationCall != null && !segmented.segmentUses(qso.startAtMillis, stationCall)) return null;
          final data = {...qso.data};
          final our = {...?asQsonMap(data['our'])};
          final theirCall = asQsonString(asQsonMap(data['their'])?['call'])?.toUpperCase();
          if (stationCall != null) our['call'] = stationCall;
          if (segmented.isSegmented) _stampSegment(our, segmented.effectiveAt(qso.startAtMillis));
          data['our'] = our;
          if (stationCall != null && theirCall == stationCall.toUpperCase()) return null;
          return data;
        }(),
    ].whereType<Map<String, dynamic>>().toList();
  }

  /// What the segment a contact falls in says about OUR station, written onto
  /// its `our` map.
  ///
  /// An export hook is handed one operation for the whole file, so a segment's
  /// own state, county and location reach it only per contact — and `our` is
  /// exactly where a hook already looks first for them, because QSON lets the
  /// station move mid-operation and a contact records where it was made from.
  /// Without this a rover who changed county at a `break` exports the base
  /// operation's county on every record of the log.
  ///
  /// Never OVER a value the contact carries: that one is what was actually
  /// recorded at the key, and the segment is only the default for a stretch.
  ///
  /// `grid`/`lat`/`lon` travel as ONE group, taken only when the contact has
  /// none of the three (docs/design/locations.md: a coordinate outranks a
  /// grid, so filling a grid from the segment beside a coordinate from the
  /// contact would state a location neither of them claims). `state` and
  /// `county` are independent of it and of each other.
  void _stampSegment(Map<String, dynamic> our, Map<String, dynamic> segment) {
    for (final key in const ['state', 'county']) {
      if (our[key] == null && segment[key] != null) our[key] = segment[key];
    }
    if (our['grid'] != null || our['lat'] != null || our['lon'] != null) return;
    for (final key in const ['grid', 'lat', 'lon']) {
      if (segment[key] != null) our[key] = segment[key];
    }
  }

  /// The QSON payload for one station callsign.
  ///
  /// With ONE callsign — the overwhelming case — this is exactly
  /// [qsonPayloadFor] and nothing else: the log is already that station's, so
  /// there is nothing to reassign and nothing to leave out. Claiming and
  /// filtering here would mean a QSO the operator made with their own other
  /// rig silently vanishing from every file, the whole-log backup included.
  ///
  /// With SEVERAL, the operation is cloned to carry only the one call so the
  /// hooks see a single-station operation — every filename, ADIF
  /// `STATION_CALLSIGN` and Cabrillo `CALLSIGN` then names the call whose
  /// file it is, and none of them need to know about the fan-out.
  ///
  /// A SEGMENTED log is rewritten either way, whatever its calls, so that each
  /// contact carries its own segment's answer for everything a hook would
  /// otherwise read off the base operation ([_stampSegment]) — and carries the
  /// segments themselves, for what a contact's `our` block cannot say.
  ///
  /// [events] go with the stretches the payload's contacts were made in, the
  /// one rule for every slice — by call or by activity. Each file is a log of
  /// those stretches, and another's breaks and notes would land among
  /// contacts it does not hold.
  Map<String, dynamic> _payloadAs(String stationCall, Operation operation, List<Qso> qsoList, SegmentedOperation segmented, {List<Qso> events = const []}) {
    final payload = qsonPayloadFor(operation: operation, qsos: qsoList);
    // The calls of every SEGMENT, not the base operation's: a log that changed
    // call at a `break` has more than one even when the operation itself names
    // exactly one, and short-circuiting on the base would hand each file the
    // whole log under the last call.
    final perCall = segmented.allStationCalls.length >= 2;
    if (perCall || segmented.isSegmented) {
      if (perCall) (payload['operation'] as Map<String, dynamic>)['stationCall'] = stationCall;
      payload['qsos'] = _qsosAs(perCall ? stationCall : null, qsoList, segmented);
      // The segments themselves, as the scoring pass sends them
      // (`ExportRequest.segments`): [_stampSegment] covers what a contact's
      // `our` block can carry, but a contest's setup — a rover's county, a sent
      // exchange — lives on a REF the segments restate, and only the resolved
      // timeline lets a hook read that per contact.
      if (segmented.isSegmented) payload['segments'] = segmented.payload;
    }
    _stampSpan(payload);
    if (events.isNotEmpty) {
      final stretches = {for (final qso in payload['qsos'] as List) segmented.segmentIndexAt(asQsonNum((qso as Map)['startAtMillis'])?.toInt())};
      final ours = [
        for (final event in events)
          if (stretches.contains(segmented.segmentIndexAt(event.startAtMillis))) event.data,
      ];
      // Beside the contacts rather than among them, where every hook that
      // counts or files `qsos` would take a break for a contact
      // (`ExportRequest.events`).
      if (ours.isNotEmpty) payload['events'] = ours;
    }
    return payload;
  }

  /// The span of the contacts [payload] holds, as the operation's
  /// `startAtMillisMin`/`startAtMillisMax` — what the SDK's `op.startDate`…
  /// `op.endTime` render, and empty without.
  ///
  /// The file's own contacts, not the operation row's columns: a file holding
  /// one park of a two-park log would otherwise say it ran until the other
  /// park's last contact. Over any pair `data` carries too, which app-polo
  /// writes for the whole log.
  static void _stampSpan(Map<String, dynamic> payload) {
    final starts = [for (final qso in payload['qsos'] as List) ?asQsonNum((qso as Map)['startAtMillis'])?.toInt()]..sort();
    final operation = payload['operation'] as Map<String, dynamic>
      ..remove('startAtMillisMin')
      ..remove('startAtMillisMax');
    if (starts.isEmpty) return;
    operation['startAtMillisMin'] = starts.first;
    operation['startAtMillisMax'] = starts.last;
  }

  /// Every export option offered by every extension for this operation, for
  /// the Exports Panel's checkbox list.
  ///
  /// Asked once PER STATION CALLSIGN ([SegmentedOperation.allStationCalls] —
  /// base and segments both, since a `break` can change the call), because each
  /// call owes its own set of files; every option is tagged with the call it
  /// belongs to so the panel can group them and `generateExports` can rebuild
  /// the same payload.
  Future<List<Map<String, dynamic>>> getExportOptions(Operation operation) async {
    final log = await _logOrNothing(operation);
    // GROWABLE, not `const []`: the panel sorts what it gets by priority, and
    // `sort` on an unmodifiable list throws whatever its length — turning the
    // empty answer this exists to give into a worse failure than the one it
    // replaced.
    if (log == null) return <Map<String, dynamic>>[];
    final calls = log.segmented.allStationCalls;
    final types = await extensions.exportTypeSettings(settings.exportGlobalSettings, settings.exportTypeOverrides);
    final settingsByType = {for (final type in types) type['exportType']: type['settings']};

    final perCall = await Future.wait(
      calls.map((call) async {
        final payload = _payloadAs(call, operation, log.qsos, log.segmented, events: log.events);

        // Hooks are asked about every ref ANY segment carries, not just the base's.
        // Each contest's `suggestExportOptions` opens with
        // `if (!refOfType(args.operation, TYPE)) return []`, so a contest that
        // ended at a break — its ref living on in the segments while the operation
        // has moved on — would otherwise be offered no Cabrillo at all, for a log
        // that is half contest QSOs.
        //
        // The same asymmetry `ScoringService` fixed for scorers by handing
        // `scorersFor` the segments (§5.1.3): an operation is scored as a contest
        // it can no longer be exported as, which is worse than either alone.
        if (log.segmented.isSegmented) {
          (payload['operation'] as Map<String, dynamic>)['refs'] = log.segmented.allRefs;
        }

        var options = await extensions.getExportOptions({...payload, 'compactFilenames': settings.useCompactFileNames});
        final registered = [
          for (final option in options)
            if (settingsByType.containsKey(option['exportType']))
              {
                ...option,
                'exportSettings': settingsByType[option['exportType']],
                // Match generation's activity and station scope. A hook may
                // narrow it further, as a hunter log does, and supplies its count.
                'qsoCount':
                    option['qsoCount'] ?? (_payloadAs(call, operation, _qsosForOption(option, log.qsos, log.segmented), log.segmented)['qsos'] as List).length,
              },
        ];
        if (registered.isNotEmpty) {
          final prepared = await extensions.prepareExports({...payload, 'options': registered, 'compactFilenames': settings.useCompactFileNames});
          var index = 0;
          options = [
            for (final option in options)
              if (settingsByType.containsKey(option['exportType'])) prepared[index++] else option,
          ];
        }
        return [
          for (final option in options) {...option, 'stationCall': call},
        ];
      }),
    );

    final options = [for (final group in perCall) ...group];
    if (settings.developerMode) {
      // ONE dump for the whole operation, not one per call: it is the
      // operation as stored, and the fan-out is a reading of it.
      return [...options, _qsonOptionFor(operation)];
    }
    return options;
  }

  /// Generates file content for the given (previously listed) options.
  /// Returns one `{filename, mimeType, content}` map per option, in the same
  /// order.
  Future<List<Map<String, dynamic>>> generateExports(Operation operation, List<Map<String, dynamic>> selectedOptions) async {
    final host = extensions.host;
    if (host == null && selectedOptions.any((o) => !isQsonOption(o))) {
      throw ExportException('Extension runtime is not ready yet — try again in a moment.');
    }
    final log = await _logFor(operation);

    // Independent per-option calls (each produces its own file) — no
    // ordering dependency, so run them concurrently rather than paying for
    // N sequential bridge round-trips.
    final results = await Future.wait(
      selectedOptions.map((option) async {
        if (isQsonOption(option)) {
          return {'filename': _qsonOptionFor(operation)['filename'], 'mimeType': 'application/json', 'content': jsonEncode(await _qsonDumpFor(operation))};
        }
        final scoped = _qsosForOption(option, log.qsos, log.segmented);
        // Rebuilt for the SAME call the option was listed under, so the file
        // matches what the panel offered. Falling back to the operation's first
        // call covers an option that predates the fan-out (or a caller passing
        // one by hand, as the tests do).
        final call = option['stationCall'] as String? ?? operation.stationCalls.first;
        final args = _payloadAs(call, operation, scoped, log.segmented, events: log.events);
        // Same reason `getExportOptions` patches the refs above: a hook offered an
        // option off a ref that lives only in a segment has to be able to READ
        // that ref when it writes the file. Without it the two halves of one
        // contract see different operations — the option is offered, then
        // generated against a base operation that no longer carries the activity.
        // For a contest that produced a file with no content and no name; for
        // `activityExportHook`, which throws when it can't find the reference its
        // exportKey names, it produces an outright export failure.
        //
        // NARROWER than the options call, deliberately. That one has to show every
        // hook every ref, since it is asking who has anything to offer. Here the
        // option has already named the type it covers, so only that type's segment
        // refs are added, on top of the operation's own. Swapping in the whole set
        // would hand a plain ADIF — no refType at all — every segment's refs, and
        // `adifFields` would stamp a later segment's park onto every earlier QSO.
        final optionRefType = option['refType'];
        if (log.segmented.isSegmented && optionRefType is String && optionRefType.isNotEmpty) {
          final refs = [...?(args['operation'] as Map<String, dynamic>)['refs'] as List?];
          final present = {
            for (final ref in refs)
              if (ref is Map) '${ref['type']}\u0000${ref['ref']}',
          };
          for (final ref in log.segmented.allRefs.where((r) => r['type'] == optionRefType)) {
            if (present.add('${ref['type']}\u0000${ref['ref']}')) refs.add(ref);
          }
          (args['operation'] as Map<String, dynamic>)['refs'] = refs;
        }
        final result =
            await host!.invoke(
                  Hooks.exportGenerateExport,
                  key: option['hookKey'] as String?,
                  args: {
                    ...args,
                    'exportType': option['exportType'],
                    'exportKey': option['exportKey'] ?? option['exportType'],
                    'compactFilenames': settings.useCompactFileNames,
                    'exportSettings': option['exportSettings'],
                    'exportData': option['exportData'],
                    'exportTitle': option['exportTitle'],
                    if (option['format'] == null || option['format'] == 'adif') ...{
                      'includeLookupData': (option['exportSettings'] as Map?)?['includeLookupData'] ?? true,
                      'includePrivateData':
                          (option['exportSettings'] as Map?)?['includePrivateData'] ??
                          (option['alwaysIncludePrivateData'] == true || settings.includePrivateData),
                    },
                  },
                  timeout: const Duration(seconds: 30),
                )
                as Map;
        final file = result.cast<String, dynamic>();

        // The panel already showed the operator a filename — the one the option
        // carried — so that is the name the file gets. A hook recomputing it
        // sees a DIFFERENT input: `generateExport` is handed only the QSOs its
        // refType (and ref) covers, so a park activated after a break dates its file from
        // the first contact after the break, while the listing dated it from the
        // start of the log. Both are defensible; disagreeing in front of the
        // user is not.
        final offered = option['filename'];
        if (offered is String && offered.isNotEmpty) {
          return {...file, 'filename': offered};
        }
        return file;
      }),
    );
    return results;
  }

  /// Disambiguates filenames that collide (two selected results sharing a
  /// name, or both missing one) before writing — a later hook's export
  /// would otherwise silently overwrite an earlier one on disk.
  List<String> _uniqueFilenames(List<Map<String, dynamic>> files) {
    final seen = <String, int>{};
    return [
      for (final file in files)
        () {
          final base = (file['filename'] as String?)?.isNotEmpty == true ? file['filename'] as String : 'export.txt';
          final count = seen.update(base, (n) => n + 1, ifAbsent: () => 1);
          if (count == 1) return base;
          final ext = p.extension(base);
          final stem = base.substring(0, base.length - ext.length);
          return '$stem-$count$ext';
        }(),
    ];
  }

  /// Save flow: on desktop a single file opens a save dialog for that file and
  /// multiple files open a directory picker; on Android every file gets its own
  /// dialog (see below). Returns where the files went — a path, a directory,
  /// or the names Android reported — with HOW MANY actually landed, or null if
  /// the operator saved nothing.
  ///
  /// The count comes from here rather than from the caller's list because only
  /// this knows: Android's per-file dialogs can be cancelled partway, and a
  /// caller announcing "4 files saved" over two filenames sends the operator
  /// looking for two that do not exist.
  ///
  /// `namesFiles` says what `location` IS. Android's SAF never tells the app
  /// where the operator put anything, so there it is the list of FILENAMES —
  /// and a caller phrasing that as a destination says the files went to their
  /// own names. Everywhere else it is a path or a directory.
  Future<({String location, int count, bool namesFiles})?> saveToDisk(List<Map<String, dynamic>> files) async {
    if (files.isEmpty) return null;

    // Android has no `file_selector` save at all — `getSaveLocation` throws
    // `UnimplementedError` there, and the raw path its directory picker
    // returns is not writable under scoped storage — so the flow goes through
    // the Storage Access Framework instead ([AndroidFileSave]).
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return _saveOnAndroid(files);
    }

    if (files.length == 1) {
      final file = files.first;
      final filename = file['filename'] as String? ?? 'export.txt';
      final location = await getSaveLocation(
        suggestedName: filename,
        acceptedTypeGroups: [
          XTypeGroup(label: filename, extensions: [p.extension(filename).replaceFirst('.', '')]),
        ],
      );
      if (location == null) return null;
      // Translated the way the Android loop translates its own: a full disk or
      // a read-only folder is an answer the platform gave, which the caller
      // reports and spends. Left raw it is an unclassified FileSystemException,
      // which ErrorPolicy uploads as a crash on every retry.
      try {
        await File(location.path).writeAsString(file['content'] as String);
      } catch (e) {
        throw ExportException('$e');
      }
      return (location: location.path, count: 1, namesFiles: false);
    }

    final directory = await getDirectoryPath();
    if (directory == null) return null;
    final filenames = _uniqueFilenames(files);
    final written = <String>[];
    for (var i = 0; i < files.length; i++) {
      try {
        await File(p.join(directory, filenames[i])).writeAsString(files[i]['content'] as String);
      } catch (e) {
        // Names what already landed, as the Android loop does: a failure on
        // the third of four leaves two on disk, and an error mentioning only
        // the third sends the operator looking for files they already have.
        throw ExportException(written.isEmpty ? '$e' : '$e — ${written.join(', ')} had already been saved');
      }
      written.add(filenames[i]);
    }
    return (location: directory, count: files.length, namesFiles: false);
  }

  /// One "create document" dialog per file, in order — app-polo's Save loop
  /// (`OperationDataScreen.jsx`), and the only shape the SAF offers that lets
  /// the operator save straight into Downloads: `ACTION_OPEN_DOCUMENT_TREE`
  /// refuses to grant that folder from Android 12 on, so a single folder
  /// picker would make them create a subfolder to get there.
  ///
  /// Reports only what actually landed. Cancelling the third of four dialogs
  /// saved three files, and a write that fails on the third leaves two on
  /// disk — the operator has to be told which, in both cases, or they go
  /// looking for files that aren't there and re-export ones that are.
  Future<({String location, int count, bool namesFiles})?> _saveOnAndroid(List<Map<String, dynamic>> files) async {
    final names = _uniqueFilenames(files);
    final saved = <String>[];
    for (var i = 0; i < files.length; i++) {
      final String? name;
      try {
        name = await androidFileSave.saveFile(filename: names[i], content: files[i]['content'] as String);
      } catch (e) {
        throw ExportException(saved.isEmpty ? '$e' : '$e — ${saved.join(', ')} had already been saved');
      }
      // Cancelling one dialog abandons the files still to come, rather than
      // asking again for every one of them.
      if (name == null) break;
      saved.add(name);
    }
    return saved.isEmpty ? null : (location: saved.join(', '), count: saved.length, namesFiles: true);
  }

  /// Web download flow: hands each file to the browser as its own download.
  ///
  /// Nothing here touches `dart:io` or `path_provider`, neither of which
  /// works on web — which is why this can't reuse [saveToDisk] or
  /// [shareFiles]: on web those either throw (one file: `File('')` on the
  /// dummy location `file_selector_web` returns) or silently do nothing at
  /// all (several: a null directory, which reads as a user cancel).
  ///
  /// One download per file rather than a zip: a browser will ask about the
  /// second and subsequent downloads from a page, which is a prompt the
  /// operator can answer, whereas an archive is a step they'd have to undo.
  Future<void> downloadFiles(List<Map<String, dynamic>> files) async {
    if (files.isEmpty) return;
    final filenames = _uniqueFilenames(files);
    for (var i = 0; i < files.length; i++) {
      downloadFile(filename: filenames[i], content: files[i]['content'] as String, mimeType: files[i]['mimeType'] as String?);
    }
  }

  /// Whether stashing now would replace an undownloaded stash — see
  /// [stashPreflightFrom]. Two reads of the account, made together.
  ///
  /// Given the room [ExtensionService.submitReport] gets rather than the
  /// host's default: a phone in the field is who stashes, and a read that
  /// times out answers "nothing to replace" — the one wrong answer that
  /// loses files.
  ///
  /// The REAL clock: the window is measured against the server's own
  /// `created_at`, which developer time travel does not move.
  Future<StashPreflight> stashPreflight() async {
    const timeout = Duration(seconds: 30);
    final (accountData, stashFiles) = await (extensions.syncAccountData(timeout: timeout), extensions.listStashFiles(timeout: timeout)).wait;
    return stashPreflightFrom(accountData: accountData, stashFiles: stashFiles, nowMillis: realNowMillis());
  }

  /// Stash flow: sends every file to Ham2K's File Stash as ONE group, titled
  /// [groupTitle], under the same disambiguated names a save would give
  /// them — the stash page lists them side by side, and two files named
  /// alike there are two the operator can't tell apart.
  ///
  /// One call per file, so a slow upload costs its own file rather than the
  /// batch's count. Stops at the first [ExtensionService.uploadStashFile]
  /// failure marked fatal, naming every file it never tried, so [errors]
  /// always accounts for each file that did not arrive.
  Future<({int uploaded, List<String> errors})> stashFiles(List<Map<String, dynamic>> files, {String? groupTitle}) async {
    final filenames = _uniqueFilenames(files);
    final groupUuid = _uuidGenerator.v4();
    var uploaded = 0;
    final errors = <String>[];
    for (var i = 0; i < files.length; i++) {
      final result = await extensions.uploadStashFile(file: {...files[i], 'filename': filenames[i]}, groupUuid: groupUuid, groupTitle: groupTitle);
      if (result.uploaded) {
        uploaded++;
        continue;
      }
      errors.add('${filenames[i]}: ${result.error ?? t.extensionService.stashUnavailable}');
      if (result.fatal) {
        errors.addAll([for (final name in filenames.skip(i + 1)) '$name: ${t.operation.export.stash.notSent}']);
        break;
      }
    }
    return (uploaded: uploaded, errors: errors);
  }

  /// Mobile share flow: writes every file to a temp directory, then opens
  /// the native share sheet with all of them at once.
  ///
  /// Returns whether the operator actually shared. `dismissed` is the one
  /// answer that means they didn't — `unavailable` is what Android returns
  /// when the share succeeded but the chosen target can't be named, so it
  /// counts as success rather than as a failure to report.
  ///
  /// [sharePositionOrigin] anchors the share sheet, which on iPadOS is a
  /// popover: without an anchor rect, share_plus throws a PlatformException
  /// there instead of presenting anything. Other platforms ignore it.
  Future<bool> shareFiles(List<Map<String, dynamic>> files, {Rect? sharePositionOrigin}) async {
    if (files.isEmpty) return false;
    final tempDir = await getTemporaryDirectory();
    final filenames = _uniqueFilenames(files);
    final paths = <XFile>[];
    for (var i = 0; i < files.length; i++) {
      final path = p.join(tempDir.path, filenames[i]);
      await File(path).writeAsString(files[i]['content'] as String);
      paths.add(XFile(path, mimeType: files[i]['mimeType'] as String?));
    }
    final result = await SharePlus.instance.share(ShareParams(files: paths, sharePositionOrigin: sharePositionOrigin));
    return result.status != ShareResultStatus.dismissed;
  }
}
