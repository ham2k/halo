// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Which of an operation's station calls are on the air, and which of them
// each contact was made under.
//
// An operation run under several calls (`stationCall`, one comma-separated
// field) owes each call its own submission. Who is present changes during
// the operation — an operator leaves for an hour, a third joins late — and
// that is a fact about each CONTACT, the same way the operator is
// (`operation_operator.dart`): a contact records the calls on the air as it
// is logged, in `our.stationCalls`, and a call's export takes exactly the
// contacts that list it.
//
// The operation keeps the full list in `stationCall`; the calls currently
// off the air are `stationCallsOff`, synced, so every device logging the
// operation stamps the same set. Unchecking a call writes only that key —
// nothing in the log changes.
//
// A contact WITHOUT the list was made under its segment's calls
// (`segments.dart`) — every contact on a one-call operation, every one made
// in a stretch whose calls differ from today's, and every one a client that
// does not stamp the list wrote. That fallback is why a
// change to the list from the logging controls stamps those contacts first
// ([freezeStationCallsUpdates]): otherwise a call added now would claim
// contacts made before it was there.

import 'models.dart';
import 'qson_values.dart';
import 'segments.dart';

/// The operation `data` key listing the calls of `stationCall` that are not
/// on the air right now.
const stationCallsOffKey = 'stationCallsOff';

/// The contact's `our` key listing the station calls it was made under.
const ourStationCallsKey = 'stationCalls';

/// The calls in [operation]'s `stationCall` that are on the air — every one
/// that [stationCallsOffKey] doesn't name.
///
/// Never empty: with every call marked off — a stale key synced from a device
/// that saw a different list — all of them are on the air, because a contact
/// made under no call at all belongs in no submission.
List<String> onAirStationCalls(Operation operation) {
  final off = stationCallsOffFor(operation);
  final on = [
    for (final call in operation.stationCalls)
      if (!off.contains(call)) call,
  ];
  return on.isEmpty ? operation.stationCalls : on;
}

/// The calls marked off the air, uppercased. Only the ones still in the list
/// count; [onAirStationCalls] is the reader.
Set<String> stationCallsOffFor(Operation operation) => {...?_callList(operation.data[stationCallsOffKey])};

/// [data] with `stationCall` set to [calls] and [stationCallsOffKey] kept to
/// the calls still in it — a call taken off the list and typed back later
/// joins on the air, not silently off. The key goes away when nothing is off,
/// and with a single call there is nothing to be off.
Map<String, dynamic> withStationCalls(Map<String, dynamic> data, List<String> calls, {Iterable<String>? off}) {
  final listed = {for (final call in calls) call.trim().toUpperCase()};
  final keptOff = [
    for (final call in off ?? stationCallsOffFor(Operation(uuid: '', data: data)))
      if (listed.contains(call)) call,
  ];
  final result = {...data, 'stationCall': calls.join(', ')}..remove(stationCallsOffKey);
  if (listed.length > 1 && keptOff.isNotEmpty && keptOff.length < listed.length) result[stationCallsOffKey] = keptOff;
  return result;
}

/// [data] with [stationCallsOffKey] set to [off] and nothing else changed —
/// what a checkbox writes. `stationCall` is left exactly as stored: rewritten,
/// even only respaced, it reads as a changed segment, and the save restamps
/// the log (`segmentOverrideDiffers`).
Map<String, dynamic> withStationCallsOff(Map<String, dynamic> data, Iterable<String> off) {
  final listed = Operation(uuid: '', data: data).stationCalls;
  final kept = [
    for (final call in listed)
      if (off.contains(call)) call,
  ];
  final result = {...data}..remove(stationCallsOffKey);
  if (kept.isNotEmpty && kept.length < listed.length) result[stationCallsOffKey] = kept;
  return result;
}

/// When the latest segment of the log in [qsos] starts — 0 for a log with
/// none, whose one implicit segment covers everything.
int latestSegmentStart(Iterable<Qso> qsos) {
  var from = 0;
  for (final qso in qsos) {
    if (qso.isEvent && !qso.deleted && eventKindOpensSegment(qso.eventKind) && (qso.startAtMillis ?? 0) > from) from = qso.startAtMillis ?? 0;
  }
  return from;
}

/// The station calls a contact's `our` block says it was made under, or null
/// when it names none — the contact then belongs to its segment's calls.
List<String>? stationCallsOfOur(Map<String, dynamic>? our) {
  final calls = _callList(our?[ourStationCallsKey]);
  return calls == null || calls.isEmpty ? null : calls;
}

List<String>? _callList(Object? raw) {
  if (raw is! List) return null;
  final seen = <String>{};
  return [
    for (final entry in raw)
      if (entry is String && entry.trim().isNotEmpty && seen.add(entry.trim().toUpperCase())) entry.trim().toUpperCase(),
  ];
}

/// [qso] stamped with the station calls on the air as it is logged.
///
/// The same rules as `qsoWithOperator`, for the same reasons: only a contact
/// being LOGGED (no `uuid` yet) is stamped, a value already on it wins, and
/// event rows are left alone. Only an operation with two or more calls
/// stamps — on a one-call operation the segment's call says everything, and
/// the list would be a copy of `our.call` on every contact.
///
/// A call the contact already names as `our.call` is the station that made
/// it — what WSJT-X or N1MM reported, or the first on the air as the
/// logging panel composes it — so it stays `our.call`, goes first, and is in
/// the list even when it is unchecked here: the other program logged under
/// it, and the checkboxes do not govern that program. A call that is not
/// one of the operation's is left alone, unstamped: it is another station's
/// contact, which the import panels flag, and stamping would hide it.
///
/// [segment] is the operation as it stood at the contact's own time, when
/// the caller has it. A contact timed in a stretch run under other calls —
/// back-dated past a `break` that changed them — is left unstamped, to follow
/// that stretch's calls: today's on-air set says nothing about it.
Map<String, dynamic> qsoWithStationCalls(Map<String, dynamic> qso, Operation operation, {Map<String, dynamic>? segment}) {
  if (qso['band'] == 'event') return qso;
  if ((asQsonString(qso['uuid']) ?? '').isNotEmpty) return qso;
  if (operation.stationCalls.length < 2) return qso;
  if (segment != null && splitStationCalls(asQsonString(segment['stationCall']) ?? '').join(',') != operation.stationCalls.join(',')) return qso;
  final our = {...?asQsonMap(qso['our'])};
  if (stationCallsOfOur(our) != null) return qso;
  final named = (asQsonString(our['call']) ?? '').trim().toUpperCase();
  if (named.isNotEmpty && !operation.stationCalls.contains(named)) return qso;
  final onAir = onAirStationCalls(operation);
  final calls = named.isEmpty
      ? onAir
      : [
          named,
          for (final call in onAir)
            if (call != named) call,
        ];
  our[ourStationCallsKey] = calls;
  our['call'] = calls.first;
  return {...qso, 'our': our};
}

/// Whether [qso] belongs in [stationCall]'s submission: the calls it lists,
/// or — when it lists none — the calls of the segment it was made in.
bool contactUsesStationCall(Qso qso, SegmentedOperation segmented, String stationCall) {
  final calls = stationCallsOfOur(asQsonMap(qso.data['our']));
  if (calls == null) return segmented.segmentUses(qso.startAtMillis, stationCall);
  return calls.contains(stationCall.trim().toUpperCase());
}

/// Every station call the log was made under — [SegmentedOperation
/// .allStationCalls] followed by any call only the contacts still name.
///
/// A call taken off the operation's list keeps the contacts stamped with it,
/// and those are still that call's submission: reading the segments alone
/// would drop its files without a word.
List<String> allStationCallsOf(SegmentedOperation segmented, Iterable<Qso> qsos) {
  final calls = [
    for (final call in segmented.allStationCalls)
      if (call.isNotEmpty) call,
  ];
  final seen = {...calls};
  for (final qso in qsos) {
    if (!qso.isRealContact) continue;
    for (final call in stationCallsOfOur(asQsonMap(qso.data['our'])) ?? const <String>[]) {
      if (seen.add(call)) calls.add(call);
    }
  }
  return calls.isEmpty ? const [''] : calls;
}

/// The writes that pin every contact WITHOUT a list to the calls it was made
/// under, before the operation's list changes from the logging controls.
///
/// "From now on" is what that change means: a call added there joins for the
/// contacts that follow, and one removed keeps the contacts it already has.
/// A contact without a list follows its segment, so it would follow the
/// change too — this stamps it with what its segment says today.
///
/// Every unstamped contact, not only the latest segment's: an operation with
/// no `start` row reads its first stretch off the base operation, which the
/// change rewrites. The write happens once per contact; a stamped contact is
/// never touched again.
List<Qso> freezeStationCallsUpdates(Map<String, dynamic> operationData, List<Qso> qsos) {
  final segmented = SegmentedOperation.from(operation: operationData, qsos: qsos);
  return [
    for (final qso in qsos)
      if (qso.isRealContact && stationCallsOfOur(asQsonMap(qso.data['our'])) == null)
        if (splitStationCalls(asQsonString(segmented.effectiveAt(qso.startAtMillis)['stationCall']) ?? '') case final calls when calls.first.isNotEmpty)
          Qso(
            uuid: qso.uuid,
            operationUuid: qso.operationUuid,
            data: {
              ...qso.data,
              'our': {...?asQsonMap(qso.data['our']), ourStationCallsKey: calls},
            },
          ),
  ];
}

/// The writes that carry an Operation Details edit of the station calls onto
/// the contacts that list them, from [fromMillis] on — the stretch the edit
/// restates.
///
/// Operation Details is where the log's calls are CORRECTED, as unstamped
/// contacts already are by their segment: [removed] comes out of every list.
/// [added] goes into the lists that lost a call — a call typed wrong is
/// fixed where it was, and not handed contacts made while it was off the
/// air — or into every list when nothing was removed, which is a call that
/// was there all along. A list left empty is taken off the contact, which
/// then follows its segment again. `our.call` follows the list's first call.
List<Qso> respreadStationCallsUpdates(List<Qso> qsos, {required Set<String> removed, required List<String> added, required int fromMillis}) {
  if (removed.isEmpty && added.isEmpty) return const [];
  final updates = <Qso>[];
  for (final qso in qsos) {
    if (!qso.isRealContact || (qso.startAtMillis ?? 0) < fromMillis) continue;
    final our = {...?asQsonMap(qso.data['our'])};
    final before = stationCallsOfOur(our);
    if (before == null) continue;
    final lostOne = before.any(removed.contains);
    final replacements = [
      for (final call in added)
        if (!before.contains(call)) call,
    ];
    // In place: a corrected FIRST call stays first, so `our.call` names it,
    // as the segment restamp names it on the contacts that list nothing.
    final after = <String>[
      for (final call in before)
        if (!removed.contains(call)) call else if (replacements.isNotEmpty) replacements.removeAt(0),
      if (removed.isEmpty || lostOne) ...replacements,
    ];
    if (after.length == before.length && after.indexed.every((entry) => before[entry.$1] == entry.$2)) continue;
    if (after.isEmpty) {
      our.remove(ourStationCallsKey);
    } else {
      our[ourStationCallsKey] = after;
      our['call'] = after.first;
    }
    updates.add(Qso(uuid: qso.uuid, operationUuid: qso.operationUuid, data: {...qso.data, 'our': our}));
  }
  return updates;
}
