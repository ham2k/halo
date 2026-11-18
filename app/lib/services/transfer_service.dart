// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Pushing contacts to other services through `transfer` hooks
// (docs/design/transfer.md): which pushes are on offer for a scope, and
// running one — building each record, sending what changed, and writing back
// what the service said.

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import '../config/experiments.dart';
import 'error_reporting_service.dart';
import 'export_service.dart';
import 'extensions/extension_service.dart';
import 'hook_payloads.dart';
import 'settings_service.dart';

/// One operation as a push reads it, once: the operation, its live
/// contacts, their segments, whether it was on the air under several station
/// calls ([allStationCallsOf]), and the [TransferService.operationHash] of
/// what it writes into each record (null outside any operation).
typedef _PushLog = ({Operation operation, List<Qso> qsos, SegmentedOperation segmented, bool perCall, String? hash});

/// What a push is asked about (transfer.md §4).
sealed class PushScope {
  const PushScope();
  Map<String, dynamic> toJson();
}

final class OperationPushScope extends PushScope {
  final Operation operation;
  const OperationPushScope(this.operation);
  @override
  Map<String, dynamic> toJson() => {'kind': 'operation', 'operation': operationQsonFor(operation)};
}

/// One place a hook offers to send a scope's contacts on a service: a
/// logbook, a folder, a station location (transfer.md §6).
class TransferDestination {
  final String id;
  final String label;

  /// The station callsign whose contacts go there, each written as that
  /// call's log writes it; null for every contact in the scope.
  final String? stationCall;

  const TransferDestination({required this.id, required this.label, this.stationCall});

  factory TransferDestination.fromJson(Map<String, dynamic> json) {
    final id = asQsonString(json['id']) ?? '';
    final call = asQsonString(json['stationCall'])?.trim().toUpperCase();
    return TransferDestination(id: id, label: asQsonString(json['label']) ?? id, stationCall: call == null || call.isEmpty ? null : call);
  }

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'stationCall': ?stationCall};
}

/// One push on offer, with the contacts it would send and the deletes it owes.
class PushSuggestion {
  final String hookKey;
  final String key;
  final String service;
  final String label;
  final String? description;
  final String? emphasis;
  final bool selectedByDefault;
  final Map<String, dynamic> payload;
  final List<Qso> contacts;
  final List<Qso> deletes;

  const PushSuggestion({
    required this.hookKey,
    required this.key,
    required this.service,
    required this.label,
    required this.payload,
    required this.contacts,
    required this.deletes,
    this.description,
    this.emphasis,
    this.selectedByDefault = false,
  });

  /// At most this many go: a record unchanged since it was sent is skipped
  /// at push time (transfer.md §5).
  int get count => contacts.length + deletes.length;
}

/// One suggestion as a hook made it, before it is counted for a destination.
typedef _Offer = ({String hookKey, Map<String, dynamic> item, String service, QsoSelector selector});

/// One destination's standing for a scope: what is due to it, and what it
/// holds. Or, with no [destination], the [problem] that kept a hook from
/// naming any.
class PushServiceStatus {
  final String hookKey;
  final String service;

  /// The first suggestion's label: the push the hook names first.
  final String label;

  final TransferDestination? destination;
  final String? problem;

  /// The suggestions that select something for [destination], in the
  /// hook's order. Pushing the row pushes them all, a contact two select
  /// going with the first.
  final List<PushSuggestion> due;

  /// Live contacts in the scope [destination] holds.
  final int sent;

  const PushServiceStatus({
    required this.hookKey,
    required this.service,
    required this.label,
    required this.due,
    required this.sent,
    this.destination,
    this.problem,
  });

  /// One row per service and destination.
  String get key => '$service\u0000${destination?.id}';

  /// Nothing due, and a destination to have sent it to: a hook that could
  /// not name one still owes the operator an answer.
  bool get completed => problem == null && due.isEmpty;

  /// Contacts to send, each once however many suggestions select it.
  int get toSend => {for (final s in due) ...s.contacts.map((q) => q.uuid)}.length;
  int get toDelete => {for (final s in due) ...s.deletes.map((q) => q.uuid)}.length;
}

/// A push the service took too long to answer. The push stops there: the
/// chunk it was sending may have landed or not, and the hook may still be
/// sending it.
class PushTimedOut implements Exception {
  const PushTimedOut();
  @override
  String toString() => 'The service took too long to answer';
}

/// What one push did.
class PushOutcome {
  int sent = 0;
  int deleted = 0;
  int unchanged = 0;
  final failures = <String, String>{};
}

class TransferService {
  TransferService({required this.extensions, required this.qsos, required this.operations, required this.exports, required this.settings});

  final ExtensionService extensions;
  final QsosRepository qsos;
  final OperationsRepository operations;
  final ExportService exports;
  final SettingsService settings;

  /// Contacts per call to a hook's `push`: one bounded crossing each, so an
  /// interrupted push keeps what already landed.
  static const chunkSize = 25;

  /// How long one chunk's `push` may take before the push stops
  /// ([PushTimedOut]).
  @visibleForTesting
  static Duration pushTimeout = const Duration(seconds: 60);

  /// Whether pushing is on at all: behind `EXP PUSH` ([kPushExperiment]),
  /// and with it off no `transfer` hook is asked anything.
  bool get enabled => settings.experimentEnabled(kPushExperiment);

  /// A row per destination a hook offers for [scope] on each service it
  /// suggests a push to, whether anything is due there or not, in the order
  /// the hooks offered them; then a row with its problem for each hook that
  /// could not say what it offers. None while [enabled] is false.
  Future<List<PushServiceStatus>> servicesFor(OperationPushScope scope) async {
    if (!enabled) return [];
    final (contacts, refsOf) = await _contactsOf(scope);
    final byService = <String, List<_Offer>>{};
    final (:offers, :problems) = await _offered(scope);
    for (final offer in offers) {
      byService.putIfAbsent(offer.service, () => []).add(offer);
    }
    final logOf = _logReader(seed: (operation: scope.operation, qsos: [...contacts.where((qso) => !qso.deleted)]));
    // Deleted contacts too: a delete still owed goes to a station call's
    // destination after its last live contact is gone.
    final callsOf = <String, List<String>>{};
    final hashOf = <String, String?>{};
    for (final qso in contacts) {
      if (qso.isEvent) continue;
      final log = await logOf(qso.operationUuid);
      callsOf[qso.uuid] = _stationCallsOf(qso, log);
      hashOf[qso.operationUuid] = log.hash;
    }
    final services = byService.entries.toList();
    final asked = await Future.wait([
      for (final MapEntry(key: service, value: offers) in services)
        _destinationsFor(offers.first.hookKey, service, scope, {for (final calls in callsOf.values) ...calls}),
    ]);
    final rows = <PushServiceStatus>[];
    for (final (index, MapEntry(key: service, value: offers)) in services.indexed) {
      final (destinations, problem) = asked[index];
      final hookKey = offers.first.hookKey;
      final label = asQsonString(offers.first.item['label']) ?? service;
      if (problem != null) {
        rows.add(PushServiceStatus(hookKey: hookKey, service: service, label: label, due: const [], sent: 0, problem: problem));
        continue;
      }
      for (final destination in destinations) {
        final recordKey = transferKey(service, destination.id);
        final goes = [
          for (final qso in contacts)
            if (destination.stationCall == null || (callsOf[qso.uuid]?.contains(destination.stationCall) ?? false)) qso,
        ];
        final due = <PushSuggestion>[];
        for (final offer in offers) {
          final suggestion = _counted(offer, goes, refsOf, (qso) => hashOf[qso.operationUuid], destination);
          if (suggestion.count > 0) due.add(suggestion);
        }
        rows.add(
          PushServiceStatus(
            hookKey: hookKey,
            service: service,
            label: label,
            destination: destination,
            due: due,
            sent: goes.where((qso) => !qso.deleted && !qso.isEvent && transferRecordOf(qso.data, recordKey) != null).length,
          ),
        );
      }
    }
    return [...rows, ...problems];
  }

  /// [offer] counted against the contacts going to [destination].
  PushSuggestion _counted(
    _Offer offer,
    List<Qso> contacts,
    List<Map<String, dynamic>> Function(Qso) refsOf,
    String? Function(Qso) hashOf,
    TransferDestination destination,
  ) {
    final (:hookKey, :item, :service, :selector) = offer;
    return PushSuggestion(
      hookKey: hookKey,
      key: asQsonString(item['key']) ?? service,
      service: service,
      label: asQsonString(item['label']) ?? service,
      description: asQsonString(item['description']),
      emphasis: asQsonString(item['emphasis']),
      selectedByDefault: item['selectedByDefault'] == true,
      payload: asQsonMap(item['payload']) ?? const {'full': true},
      contacts: [
        for (final qso in contacts)
          if (selector.matches(qso, destination: destination.id, operationHash: hashOf(qso), operationRefs: refsOf(qso))) qso,
      ],
      deletes: [
        for (final qso in contacts)
          if (selector.matchesDelete(qso, service, destination: destination.id, operationRefs: refsOf(qso))) qso,
      ],
    );
  }

  /// What [hookKey] offers on [service] for [scope], or the problem it
  /// names instead.
  Future<(List<TransferDestination>, String?)> _destinationsFor(String hookKey, String service, PushScope scope, Set<String> calls) async {
    try {
      final offered = await extensions.suggestTransferDestinations(hookKey, {
        'service': service,
        'scope': scope.toJson(),
        'stationCalls': [...calls],
      });
      return ([for (final json in offered) TransferDestination.fromJson(json)], null);
    } on ExtensionHostException catch (e) {
      return (const <TransferDestination>[], e.message);
    }
  }

  /// Every suggestion the hooks make for [scope], each to a service its hook
  /// declared and can push to, the service's label and description standing
  /// in for ones it leaves out.
  ///
  /// A hook that fails to list its services, or to suggest, is a row with
  /// its error, per service it would have pushed to: dropped, it would read
  /// as nothing to push.
  Future<({List<_Offer> offers, List<PushServiceStatus> problems})> _offered(PushScope scope) async {
    final (byKey: services, failed: unlisted) = await extensions.transferServices();
    final (:items, failed: unsuggested) = await extensions.suggestPushes({
      'scope': scope.toJson(),
      if (scope is OperationPushScope) 'sent': ?asQsonMap(scope.operation.data[qsoTransferKey]),
    });
    final problems = <String, PushServiceStatus>{};
    void problem(String hookKey, String service, String label, String error) => problems.putIfAbsent(
      '$hookKey\u0000$service',
      () => PushServiceStatus(hookKey: hookKey, service: service, label: label, due: const [], sent: 0, problem: error),
    );
    for (final MapEntry(key: hookKey, value: error) in unsuggested.entries) {
      final declared = [
        for (final info in services.values)
          if (info.hookKey == hookKey && info.pushes) info,
      ];
      if (declared.isEmpty && unlisted.containsKey(hookKey)) problem(hookKey, hookKey, hookKey, error);
      for (final info in declared) {
        problem(hookKey, info.key, info.label, error);
      }
    }
    final result = <_Offer>[];
    for (final item in items) {
      final hookKey = item['hookKey'] as String;
      final service = asQsonString(item['service']) ?? '';
      if (unlisted[hookKey] case final error?) {
        problem(hookKey, service, asQsonString(item['label']) ?? service, error);
        continue;
      }
      // A hook pushes only to a service it declared: the write-back lands
      // under that key, and another hook's records live there.
      final info = services[service];
      if (info?.hookKey != hookKey) {
        debugPrint('[transfer] "$hookKey" suggested a push to "$service", a service it does not declare');
        continue;
      }
      // A hook that only pulls has no push to run.
      if (!info!.pushes) continue;
      final selector = QsoSelector.fromJson(asQsonMap(item['select']) ?? const {});
      // A suggestion stops selecting a contact once the push writes its
      // record, which lands under its own service: one naming no record, or
      // another service's, selects it again after every push, and its row is
      // never done.
      bool own(String? name) => name == null || name.toLowerCase() == service || name.toLowerCase().startsWith('$service:');
      if ((selector.notSentTo == null && selector.changedSince == null) || !own(selector.notSentTo) || !own(selector.changedSince)) {
        debugPrint('[transfer] "$hookKey" suggested "${item['key']}" without a notSentTo or changedSince of "$service"; it is ignored');
        continue;
      }
      result.add((
        hookKey: hookKey,
        item: {...item, 'label': asQsonString(item['label']) ?? info.label, 'description': asQsonString(item['description']) ?? info.description},
        service: service,
        selector: selector,
      ));
    }
    return (offers: result, problems: [...problems.values]);
  }

  /// The station callsigns a contact was made under, as the exporter files
  /// it ([contactUsesStationCall]): the calls it lists, else its segment's.
  /// A contact outside any operation has its own.
  List<String> _stationCallsOf(Qso qso, _PushLog log) {
    final listed = stationCallsOfOur(asQsonMap(qso.data['our']));
    if (listed != null) return listed;
    if (log.operation.uuid.isNotEmpty) {
      final calls = [
        for (final call in splitStationCalls(asQsonString(log.segmented.effectiveAt(qso.startAtMillis)['stationCall']) ?? ''))
          if (call.isNotEmpty) call,
      ];
      if (calls.isNotEmpty) return calls;
    }
    return [if (qso.ourCall.isNotEmpty) qso.ourCall.toUpperCase()];
  }

  /// The operations [uuid]s name, each read once with its live contacts and
  /// segments; the empty uuid, or one gone, reads as an empty operation.
  /// [seed] is one already read.
  Future<_PushLog> Function(String uuid) _logReader({({Operation operation, List<Qso> qsos})? seed}) {
    _PushLog logOf(Operation operation, List<Qso> all) {
      final segmented = SegmentedOperation.from(operation: operation.data, qsos: all);
      return (
        operation: operation,
        qsos: all,
        segmented: segmented,
        perCall: allStationCallsOf(segmented, all.where((qso) => !qso.isEvent)).length >= 2,
        hash: operation.uuid.isEmpty ? null : operationHash(operation, all.where((qso) => qso.isEvent)),
      );
    }

    final byUuid = <String, Future<_PushLog>>{if (seed case (:final operation, :final qsos)) operation.uuid: Future.value(logOf(operation, qsos))};
    return (uuid) => byUuid[uuid] ??= () async {
      final operation = (uuid.isEmpty ? null : await operations.get(uuid)) ?? Operation(uuid: '', data: const {});
      return logOf(operation, operation.uuid.isEmpty ? const <Qso>[] : await qsos.forOperation(operation.uuid));
    }();
  }

  /// The scope's contacts, live and deleted, with a reader for the
  /// references each one's operation carries.
  Future<(List<Qso>, List<Map<String, dynamic>> Function(Qso))> _contactsOf(OperationPushScope scope) async {
    final all = await qsos.forOperation(scope.operation.uuid, includeDeleted: true);
    final refs = SegmentedOperation.from(operation: scope.operation.data, qsos: all).allRefs;
    return (all, (Qso _) => refs);
  }

  /// Sends everything due in [row], one suggestion after another, adding
  /// to [outcome] as it goes, so a caller holding it knows what went before
  /// a throw. A contact two suggestions select goes with the first only.
  /// Only a push that ends with every record accepted marks [scope]'s
  /// operation processed (transfer.md §7).
  Future<PushOutcome> push(OperationPushScope scope, PushServiceStatus row, {PushOutcome? outcome, void Function(int done, int total)? onProgress}) async {
    if (!enabled) throw StateError('Pushing is off (EXP PUSH)');
    final destination = row.destination;
    if (destination == null) throw StateError('"${row.service}" names no destination to push to');
    // Refused before anything is sent: refused at the write-back instead, the
    // service would hold contacts with no id saved here, and the next push
    // would make copies.
    if (WritePolicy.forQso(operation: scope.operation) case final refusal?) throw refusal;
    final result = outcome ?? PushOutcome();
    final service = (await extensions.transferServices()).byKey[row.service];
    if (service == null || service.hookKey != row.hookKey || !service.pushes) {
      throw StateError('No extension sends to "${row.service}" any more');
    }
    final logOf = _logReader();
    final recordKey = transferKey(row.service, destination.id);
    final total = row.toSend + row.toDelete;
    final seen = <String>{};
    final touched = <String>{};
    var done = 0;
    // What already went is at the service, so its summary is recorded even
    // when a chunk throws; a failure recording it then must not replace the
    // chunk's own error.
    Future<void> recordSummaries() async {
      for (final uuid in touched) {
        if (uuid.isEmpty) continue;
        final held = (await qsos.forOperation(uuid)).where((qso) => !qso.isEvent && transferRecordOf(qso.data, recordKey) != null).length;
        await operations.recordTransfer(uuid, recordKey, {'key': row.hookKey, 'sentAtMillis': realNowMillis(), 'sentCount': held});
      }
    }

    try {
      for (final suggestion in row.due) {
        final contacts = [
          for (final qso in [...suggestion.contacts, ...suggestion.deletes])
            if (seen.add(qso.uuid)) qso,
        ];
        await _push(suggestion, destination, recordKey, contacts, logOf, result, touched, (count) => onProgress?.call(done += count, total));
      }
    } catch (_) {
      await recordSummaries().catchError((Object e, StackTrace stack) => ErrorReportingService.report(e, stack, context: 'transfer summary'));
      rethrow;
    }
    await recordSummaries();
    if (result.failures.isEmpty) await operations.markExported(scope.operation.uuid);
    return result;
  }

  /// Sends [contacts] of [suggestion] to [destination] in chunks, one station
  /// callsign at a time (the destination's, or each contact's own when it
  /// names none); records unchanged since they were sent are skipped, and
  /// every result the service gives is written back under [recordKey]
  /// (transfer.md §5–§7). The operations whose contacts it wrote go into
  /// [touched].
  Future<void> _push(
    PushSuggestion suggestion,
    TransferDestination destination,
    String recordKey,
    List<Qso> contacts,
    Future<_PushLog> Function(String uuid) logOf,
    PushOutcome outcome,
    Set<String> touched,
    void Function(int count) advanced,
  ) async {
    final byCall = <String, List<Qso>>{};
    for (final qso in contacts) {
      final call = destination.stationCall ?? _stationCallsOf(qso, await logOf(qso.operationUuid)).firstOrNull ?? '';
      byCall.putIfAbsent(call, () => []).add(qso);
    }
    for (final MapEntry(key: call, value: contacts) in byCall.entries) {
      for (var start = 0; start < contacts.length; start += chunkSize) {
        final chunk = contacts.sublist(start, (start + chunkSize).clamp(0, contacts.length));
        // As stored now, not as the suggestion read them: a push run just
        // before this one may have sent these contacts and saved their ids,
        // and sending them again without one makes a copy at the service.
        final stored = {
          for (final qso in await qsos.getMany([for (final qso in chunk) qso.uuid])) qso.uuid: qso,
        };
        final fresh = [for (final qso in chunk) ?stored[qso.uuid]];
        // The revision each record is built from: an edit landing before
        // the write-back leaves its record behind, to go next time.
        final sentFrom = {for (final qso in fresh) qso.uuid: asQsonNum(qso.data['updatedAtMillis'])?.toInt()};
        final current = <String, Map<String, dynamic>>{};
        final records = await _recordsFor(suggestion, fresh, call, recordKey, logOf, outcome, current);
        // An unchanged record is not sent, but its revision moves forward,
        // or `changedSince` selects the contact again on every count.
        if (current.isNotEmpty) await qsos.writeTransfers(recordKey, current, sentFrom: sentFrom);
        if (records.isNotEmpty) {
          touched.addAll(await _send(suggestion, call, destination, recordKey, records, outcome, sentFrom));
        }
        advanced(chunk.length);
      }
    }
  }

  /// [chunk]'s `PushRecord`s: deletes by id, and each live contact's ADIF
  /// unless its hash matches its record under [recordKey], what that
  /// destination was last sent. A matching record that is behind the
  /// contact goes into [current], to be written back as it is.
  Future<List<Map<String, dynamic>>> _recordsFor(
    PushSuggestion suggestion,
    List<Qso> chunk,
    String call,
    String recordKey,
    Future<_PushLog> Function(String uuid) logOf,
    PushOutcome outcome,
    Map<String, Map<String, dynamic>> current,
  ) async {
    final payload = suggestion.payload;
    final records = <Map<String, dynamic>>[];
    final live = <String, List<Qso>>{};
    for (final qso in chunk) {
      if (qso.deleted) {
        // A record already cleared has nothing left to delete at the service.
        final sent = transferRecordOf(qso.data, recordKey);
        if (sent == null) {
          outcome.unchanged++;
          continue;
        }
        records.add({'uuid': qso.uuid, 'adif': const <String>[], 'deleted': true, 'id': ?sent['id'], '_operation': qso.operationUuid});
      } else {
        live.putIfAbsent(qso.operationUuid, () => []).add(qso);
      }
    }
    for (final MapEntry(key: operationUuid, value: contacts) in live.entries) {
      final log = await logOf(operationUuid);
      final errors = <String, String>{};
      final adif = await exports.adifRecordsByQso(
        log.operation,
        contacts,
        stationCall: call,
        log: log.operation.uuid.isEmpty ? null : (qsos: log.qsos, segmented: log.segmented, perCall: log.perCall),
        mainHandler: asQsonString(payload['mainHandler']),
        includeFieldsFrom: [...?asQsonList(payload['includeFieldsFrom'])?.whereType<String>()],
        includePrivateData: payload['includePrivateData'] == true,
        omit: [...?asQsonList(payload['omit'])?.whereType<String>()],
        errors: errors,
      );
      for (final qso in contacts) {
        final lines = adif[qso.uuid];
        if (lines == null) {
          outcome.failures[qso.uuid] = errors[qso.uuid] ?? 'No ADIF record could be written for this contact';
          continue;
        }
        final sent = transferRecordOf(qso.data, recordKey);
        final hash = recordHash(lines);
        if (sent != null && sent['hash'] == hash) {
          if (transferIsBehind(qso.data, recordKey) || sent['operationHash'] != log.hash) {
            current[qso.uuid] = {...sent, 'operationHash': ?log.hash};
          }
          outcome.unchanged++;
          continue;
        }
        records.add({'uuid': qso.uuid, 'adif': lines, 'id': ?sent?['id'], '_hash': hash, '_operation': qso.operationUuid, '_operationHash': log.hash});
      }
    }
    return records;
  }

  /// Sends [records] and writes back what the service said; answers the
  /// operations whose contacts it changed.
  Future<Set<String>> _send(
    PushSuggestion suggestion,
    String call,
    TransferDestination destination,
    String recordKey,
    List<Map<String, dynamic>> records,
    PushOutcome outcome,
    Map<String, int?> sentFrom,
  ) async {
    final List<Map<String, dynamic>> results;
    try {
      results = await extensions.pushRecords(suggestion.hookKey, timeout: pushTimeout, {
        'service': suggestion.service,
        'stationCall': call,
        'destination': destination.toJson(),
        'records': [
          for (final record in records)
            {...record}
              ..remove('_hash')
              ..remove('_operation')
              ..remove('_operationHash'),
        ],
      });
    } on HookTimeoutException {
      // The hook may still be sending this chunk, and the service may hold
      // some of it with no id saved here: sending the next chunk, or this
      // one again, before it answers is how copies are made. A hook that
      // throws stops the push for the same reason, as it is: it may have
      // sent part of the chunk before it did.
      throw const PushTimedOut();
    }
    final byUuid = {for (final result in results) ?asQsonString(result['uuid']): result};
    final writes = <String, Map<String, dynamic>?>{};
    final touched = <String>{};
    for (final record in records) {
      final uuid = record['uuid'] as String;
      final result = byUuid[uuid];
      // Any `error` at all, not only a string: a JS Error crosses the bridge
      // as `{}`, and read as no error it records a refused contact as sent.
      final error = switch (result?['error']) {
        _ when result == null => 'The service gave no answer for this contact',
        null => null,
        final String text => text,
        final other => 'The service refused this contact ($other)',
      };
      if (error != null) {
        outcome.failures[uuid] = error;
        continue;
      }
      if (record['deleted'] == true) {
        writes[uuid] = null;
        outcome.deleted++;
      } else {
        writes[uuid] = {
          'key': suggestion.hookKey,
          'id': ?(asQsonString(result!['id']) ?? record['id']),
          'sentAtMillis': realNowMillis(),
          'hash': record['_hash'],
          'operationHash': ?record['_operationHash'],
        };
        outcome.sent++;
      }
      touched.add(record['_operation'] as String);
    }
    await qsos.writeTransfers(recordKey, writes, sentFrom: sentFrom);
    return touched;
  }

  /// What [operation] writes into its contacts' records beyond their own
  /// data: its fields and its segments' [events], without the bookkeeping
  /// that moves on every status change (status, transfer summaries,
  /// timestamps), which would make every contact read as changed after each.
  ///
  /// Keys are sorted, and null or empty values dropped, at every depth: a
  /// status change rewrites the events with empty fields filled in, and a
  /// copy sync brings back may hold its keys in another order, neither of
  /// which is an edit.
  static String operationHash(Operation operation, Iterable<Qso> events) {
    Object? normal(Object? value) => switch (value) {
      Map() => {
        for (final key in value.keys.map((k) => '$k').toList()..sort())
          if (normal(value[key]) case final item? when item != '' && (item is! Map || item.isNotEmpty)) key: item,
      },
      List() => [for (final item in value) normal(item)],
      _ => value,
    };
    final canonical = jsonEncode(
      normal({
        'operation': {
          for (final MapEntry(:key, :value) in operation.data.entries)
            if (key != 'status' && key != qsoTransferKey && !key.endsWith('Millis')) key: value,
        },
        'segments': [
          for (final event in events)
            {
              'startAtMillis': event.startAtMillis,
              'event': asQsonString(asQsonMap(event.data['event'])?['event']),
              'operation': asQsonMap(event.data['event'])?['operation'],
            },
        ],
      }),
    );
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  /// What a record set is compared by: the hash of exactly the lines sent.
  static String recordHash(List<String> lines) => sha256.convert(utf8.encode(lines.join('\n'))).toString();
}
