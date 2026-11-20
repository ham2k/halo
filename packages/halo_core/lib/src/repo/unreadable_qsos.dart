// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Stored QSO rows whose `data` does not decode, as a read that leaves them
// out describes them. Only the reads an operator LOOKS at leave a row out
// (`QsosRepository.watchForAnyOurCall`, `watchForOurCalls`); an export, a
// transfer, an import's duplicate check and the claims scans still fail on
// one, since working on a log quietly missing a contact is worse than not
// working at all.

import '../models/models.dart';

/// Why a stored row's `data` is not a QSO.
enum UnreadableQsoProblem {
  /// Not JSON at all.
  notJson,

  /// JSON, but not an object: `null`, a list, a string, a number.
  notAnObject,
}

/// A stored QSO row a read left out, with everything the row still holds —
/// the indexed columns survive a `data` that does not, and are often enough
/// to say which contact it was.
class UnreadableQso {
  const UnreadableQso({
    required this.uuid,
    required this.operationUuid,
    required this.problem,
    required this.detail,
    required this.data,
    required this.deleted,
    required this.synced,
    this.ourCall,
    this.theirCall,
    this.band,
    this.mode,
    this.startAtMillis,
    this.updatedAtMillis,
  });

  final String uuid;
  final String operationUuid;
  final UnreadableQsoProblem problem;

  /// What the decoder said, in its own words: the parser's message and
  /// where it stopped, or the JSON type the row holds instead (`null`,
  /// `array`, `string`, `number`, `boolean`).
  final String detail;

  /// The stored text, whole: what someone reconstructing the contact needs.
  final String data;

  final bool deleted;
  final bool synced;
  final String? ourCall;
  final String? theirCall;
  final String? band;
  final String? mode;
  final int? startAtMillis;
  final int? updatedAtMillis;
}

/// A read that leaves unreadable rows out: the QSOs it could read, and the
/// rows it could not.
class QsoLogRead {
  const QsoLogRead(this.qsos, this.unreadable);
  final List<Qso> qsos;
  final List<UnreadableQso> unreadable;
}

/// An [UnreadableQso] as uploaded to the crash backend: the row's uuid and
/// the kind of problem, never the detail or the data, which quote the
/// stored text and so hold callsigns, names and notes.
class UnreadableQsoRowException implements Exception {
  UnreadableQsoRowException(this.uuid, this.problem);
  final String uuid;
  final UnreadableQsoProblem problem;

  /// No uuid: a report without a stack is grouped by its message, and one
  /// per row would scatter what is one problem across as many issues.
  @override
  String toString() => 'UnreadableQsoRowException: a stored QSO could not be read (${problem.name})';
}

/// Called for each row a read left out. Null until the app wires it up at
/// boot; `halo_core` is pure Dart and cannot reach the app's crash backend
/// itself. Called again on every read that meets the row — a live list
/// re-reads on every write — so the wiring dedupes.
void Function(UnreadableQsoRowException row)? onUnreadableQsoRow;
