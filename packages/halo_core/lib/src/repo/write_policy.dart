// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one place that decides whether the app may write to a record.
//
// One seam rather than a check at each write site. The travelled clock is the
// only reason today and a shared operation this device may only read is the
// next one — both answer the same question at the same moment, and a second
// reason added at nine call sites is a reason that gets missed at one of them.

import '../app_clock.dart';
import '../models/models.dart';

/// Thrown when a write is refused.
///
/// An exception rather than a `bool` return: a refused write must reach the
/// operator. A write that quietly does nothing is the failure this exists to
/// prevent, and the one a caller is most likely to write by accident.
///
/// [reason] is operator-facing text. Travel requires developer mode, so it is
/// plain English with no i18n catalog — the same call the DEVTT command's own
/// notices make.
class WriteRefused implements Exception {
  final String reason;

  const WriteRefused(this.reason);

  @override
  String toString() => reason;
}

/// [stationCall] with `/TEST` added to every callsign in it that is not
/// already a test call, while the clock is travelled — unchanged otherwise.
///
/// This is what makes the write gate escapable: an operation is judged by its
/// STORED callsign, so one created during travel has to arrive already marked
/// or the operator could never write to it. Applied per comma-separated call
/// rather than to the string as a whole, so a multi-operator `KI2D, W1AW`
/// reads as marked throughout rather than only on its last entry.
///
/// An empty call becomes `/TEST`, which is deliberately still a test call —
/// an operation created before its callsign is known must not be born
/// unwritable.
String markedForTravel(String stationCall) {
  if (!AppClock.instance.isTravelling) return stationCall;
  return stationCall
      .split(',')
      .map((part) => part.trim())
      .map((call) => isTestCall(call) ? call : '$call/TEST')
      .join(', ');
}

/// Whether a record may be written right now.
///
/// While the clock is travelled only TEST data may be written, so everything a
/// travelled session produces is identifiable and purgeable — which is what
/// lets LoFi and peer sync keep running instead of being barred outright
/// (docs/design/time.md §4). Revision stamps are on the real clock either way
/// (`realNowMillis`), so what this protects is the QSO's own times: a
/// travelled `startAtMillis` on a REAL contact is indistinguishable from a
/// genuine one once it reaches another device.
class WritePolicy {
  /// Refusal for a write to [operation], or null when it may proceed.
  ///
  /// Judged on the operation ALREADY STORED, never on the incoming edit — an
  /// edit that adds `/TEST` to a real operation's callsign would otherwise be
  /// its own escape hatch, admitting every write after it.
  ///
  /// A null [operation] is refused while travelling: it means the row could
  /// not be read, and "unknown" read as "test" is the same wrong answer as no
  /// check at all. Creating an operation does not come through here — it
  /// cannot, having nothing stored yet — and is handled instead by seeding the
  /// station call with `/TEST` while travelling.
  static WriteRefused? forOperation(Operation? operation) {
    if (!AppClock.instance.isTravelling) return null;
    if (operation?.isTestOperation ?? false) return null;
    return const WriteRefused(_travelMessage);
  }

  /// Refusal for a write to a QSO in [operation], or null when it may proceed.
  ///
  /// A contact inside an operation is made with that operation's station call,
  /// so the operation is the whole answer and [ourCall] must be left empty:
  /// the contact's own call is not an independent identity, and treating it as
  /// one lets a `/TEST` call carry a contact INTO a real operation, where
  /// every cleanup path — all of which work per operation — is blind to it.
  ///
  /// [ourCall] decides only for a contact with no operation at all, which has
  /// nothing else to be identified by. Callers pass the STORED call for an
  /// existing contact; taking the caller's would let an edit declare itself
  /// test data and rewrite a real contact's times in one step.
  static WriteRefused? forQso({required Operation? operation, String ourCall = ''}) {
    if (!AppClock.instance.isTravelling) return null;
    if (operation?.isTestOperation ?? false) return null;
    if (operation == null && isTestCall(ourCall)) return null;
    return const WriteRefused(_travelMessage);
  }

  /// Refusal for an edit that would take an operation OUT of test data while
  /// the clock is travelled, or null when it may proceed.
  ///
  /// The mirror of [forOperation]'s escape hatch, and it exists for the
  /// operator's sake rather than the log's: clearing `/TEST` from an operation
  /// they are currently allowed to edit would lock them out of it on the very
  /// next write, with the edit that caused it already committed. Ending travel
  /// is the way to reclassify an operation.
  static WriteRefused? forOperationStayingTest(Operation updated) {
    if (!AppClock.instance.isTravelling) return null;
    if (updated.isTestOperation) return null;
    return const WriteRefused(
      'The clock is time travelling, so /T or /TEST cannot be removed from a station callsign — '
      'the operation would become unwritable. Run DEVTT to return to real time first.',
    );
  }

  static const _travelMessage =
      'The clock is time travelling, so only test operations and contacts can be changed. '
      'Add /T or /TEST to the station callsign, or run DEVTT to return to real time.';
}
