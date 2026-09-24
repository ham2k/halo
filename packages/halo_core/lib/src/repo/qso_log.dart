// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:collection';

import '../models/models.dart';

/// An operation's log as the log stream emits it: the rows, oldest first, and
/// the digest of the ones that are not deleted — every uuid with its stamp,
/// summed so that order does not matter ([qsoLogDigestOf]).
///
/// The digest is what a scoring pass stamps its checkpoint with and what the
/// Operation View fingerprints the log by. Computed on demand it costs a walk
/// of every row, on the UI isolate, per emission and per keystroke. Carried
/// here it is maintained by the stream in the cost of each patch, and a
/// consumer that knows the type reads it in one step; one that does not sees
/// a list.
///
/// Unmodifiable: every emission is a new list, and a consumer keeping an
/// earlier one relies on nobody writing into it.
class QsoLog extends UnmodifiableListView<Qso> {
  /// [digest] and [unstamped] are trusted as read: they must describe
  /// exactly [rows], never a list they were carried over from.
  QsoLog(super.rows, {required this.digest, required this.unstamped});

  /// [qsoLogDigestOf] over the rows that are not deleted.
  final int digest;

  /// How many rows that are not deleted carry no `updatedAtMillis`. Such a
  /// row's term cannot move when its content does, so no digest can prove
  /// the row unchanged; a consumer proving anything by [digest] refuses
  /// while this is not zero.
  final int unstamped;
}

/// One row's term in the digest. Not a secure hash — it only has to notice a
/// stamp that moved or a contact that came or went. Built by hand rather than
/// with `Object.hash`, whose seed changes per run: the digest is persisted in
/// the checkpoint stamp, and one that never matched after a relaunch would
/// fold every keystroke cold until the first rescore. Each term and the sum
/// stay under 2^53 so the web build's integers carry them.
int qsoDigestTerm(Qso qso) => ((qso.uuid.hashCode & 0xFFFFFFFF) * 31 + (qso.updatedAtMillis ?? 0)) & 0xFFFFFFFF;

/// The digest of [rows] that are not deleted, as [QsoLog.digest] carries it.
int qsoLogDigestOf(Iterable<Qso> rows) {
  var digest = 0;
  for (final qso in rows) {
    if (!qso.deleted) digest += qsoDigestTerm(qso);
  }
  return digest;
}

/// The count of [rows] that are not deleted and carry no stamp, as
/// [QsoLog.unstamped] carries it.
int qsoLogUnstampedOf(Iterable<Qso> rows) => rows.where((qso) => !qso.deleted && qso.updatedAtMillis == null).length;
