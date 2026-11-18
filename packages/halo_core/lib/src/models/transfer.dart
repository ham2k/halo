// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Where a copy of a contact was sent: `qso.transfer["<service>:<destination>"]`
// (docs/design/transfer.md §2). Confirmation is `qso.qsl` and never written
// here.

import 'models.dart';
import 'qson_values.dart';

/// The QSON key holding a contact's transfer records, one per service and
/// destination.
const qsoTransferKey = 'transfer';

/// The key of the record a contact keeps for [destination] on [service]:
/// `qrz:ki2d`, in lower case, so a destination's capitals never make a second
/// record. A service key never contains `:`, so the key splits at its first.
String transferKey(String service, String destination) => '$service:$destination'.toLowerCase();

/// The record under [key] on the contact whose QSON is [qsoData], or null
/// when the contact was never sent there.
Map<String, dynamic>? transferRecordOf(Map<String, dynamic> qsoData, String key) => asQsonMap(asQsonMap(qsoData[qsoTransferKey])?[key]);

/// Whether the contact changed after its record under [key] was written —
/// false for one never sent there, which is [transferRecordOf] being null.
///
/// An upper bound, not the answer: the per-record ADIF hash decides what a
/// push actually sends (transfer.md §5).
bool transferIsBehind(Map<String, dynamic> qsoData, String key) {
  final record = transferRecordOf(qsoData, key);
  if (record == null) return false;
  final revision = asQsonNum(record['sentRevision'])?.toInt() ?? 0;
  final updated = asQsonNum(qsoData['updatedAtMillis'])?.toInt() ?? 0;
  return updated > revision;
}

/// [qsoData] with the record under [key] set to [record], or removed when it
/// is null, as written at [revision] — which becomes the contact's
/// `updatedAtMillis` and the record's `sentRevision`.
///
/// [sentFrom] is the `updatedAtMillis` of the copy the record was built
/// from. When the contact has moved since (an edit landing while the push
/// was out), the record keeps that older revision instead, and stays behind:
/// stamped [revision], the edit would read as sent and never go.
///
/// Every OTHER record whose `sentRevision` equals the contact's previous
/// `updatedAtMillis` moves to [revision] too: that destination was up to
/// date, and the only change since is this bookkeeping. Without it, pushing
/// to one destination makes every contact read as changed for every other
/// (transfer.md §7). A record already behind stays behind.
Map<String, dynamic> withTransferRecord(Map<String, dynamic> qsoData, String key, Map<String, dynamic>? record, {required int revision, int? sentFrom}) {
  final previous = asQsonNum(qsoData['updatedAtMillis'])?.toInt();
  final transfers = <String, dynamic>{};
  final existing = asQsonMap(qsoData[qsoTransferKey]) ?? const <String, dynamic>{};
  for (final MapEntry(key: otherKey, :value) in existing.entries) {
    if (otherKey == key) continue;
    final other = asQsonMap(value);
    if (other == null) continue;
    final upToDate = previous != null && asQsonNum(other['sentRevision'])?.toInt() == previous;
    transfers[otherKey] = upToDate ? {...other, 'sentRevision': revision} : other;
  }
  if (record != null) transfers[key] = {...record, 'sentRevision': sentFrom == null || sentFrom == previous ? revision : sentFrom};

  final result = {...qsoData, 'updatedAtMillis': revision};
  if (transfers.isEmpty) {
    result.remove(qsoTransferKey);
  } else {
    result[qsoTransferKey] = transfers;
  }
  return result;
}

/// Which contacts a push suggestion covers (docs/design/transfer.md §4).
/// Every condition given must hold; one left out is no condition.
///
/// [notSentTo] and [changedSince] name a service or a whole record key. A
/// service (`qrz`) is read against the destination being counted, so a
/// contact sent to one QRZ logbook is still unsent for another; a record key
/// (`sota:chase`) names that record whatever the destination.
class QsoSelector {
  /// A reference type the contact itself carries: one it hunted.
  final String? hunted;

  /// A reference type the contact's OPERATION carries: one it activated.
  final String? activated;

  /// A record the contact does not have.
  final String? notSentTo;

  /// A record the contact has moved past ([transferIsBehind]), or one
  /// written from different operation content (`operationHash`).
  final String? changedSince;

  const QsoSelector({this.hunted, this.activated, this.notSentTo, this.changedSince});

  factory QsoSelector.fromJson(Map<String, dynamic> json) => QsoSelector(
    hunted: asQsonString(json['hunted']),
    activated: asQsonString(json['activated']),
    notSentTo: asQsonString(json['notSentTo']),
    changedSince: asQsonString(json['changedSince']),
  );

  /// Whether the live contact [qso] is selected for [destination], the id of
  /// the destination being counted; [operationRefs] are its operation's
  /// references, empty for one logged outside any operation. An event row is
  /// never a contact to send.
  ///
  /// [operationHash] is the content its operation writes into each record
  /// now, null outside any operation. An operation edit (a park, a grid, a
  /// segment's call) rewrites its contacts' records without touching them,
  /// so a record written from other content is behind as well.
  bool matches(Qso qso, {required String destination, String? operationHash, List<Map<String, dynamic>> operationRefs = const []}) {
    if (qso.isEvent || qso.deleted) return false;
    if (!_refsMatch(qso, operationRefs)) return false;
    if (notSentTo case final name? when transferRecordOf(qso.data, _keyFor(name, destination)) != null) return false;
    if (changedSince case final name?) {
      final key = _keyFor(name, destination);
      final record = transferRecordOf(qso.data, key);
      if (record == null) return false;
      if (!transferIsBehind(qso.data, key) && (operationHash == null || record['operationHash'] == operationHash)) return false;
    }
    return true;
  }

  /// Whether the tombstone [qso] is a delete owed to [destination] on
  /// [service]: the destination holds it (a record remains) and it is of the
  /// kind this selector covers. Being deleted is a change since it was sent,
  /// so [changedSince] holds; [notSentTo] is asked as for a live contact, so
  /// a push of what was never sent owes no deletes.
  bool matchesDelete(Qso qso, String service, {required String destination, List<Map<String, dynamic>> operationRefs = const []}) {
    if (!qso.deleted || qso.isEvent || transferRecordOf(qso.data, transferKey(service, destination)) == null) return false;
    if (notSentTo case final name? when transferRecordOf(qso.data, _keyFor(name, destination)) != null) return false;
    return _refsMatch(qso, operationRefs);
  }

  static String _keyFor(String name, String destination) => name.contains(':') ? name.toLowerCase() : transferKey(name, destination);

  bool _refsMatch(Qso qso, List<Map<String, dynamic>> operationRefs) {
    if (hunted case final type? when !qso.refs.any((ref) => ref['type'] == type)) return false;
    if (activated case final type? when !operationRefs.any((ref) => ref['type'] == type)) return false;
    return true;
  }
}
