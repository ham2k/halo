// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The lifecycle status an operation moves through, and the rules for moving
// it (docs/design/data-model.md §The Log Data).
//
// The STORED status is the truth. Nothing re-derives it from the event rows
// or from timestamps at read time: the time-driven transitions are applied by
// a periodic sweep ([sweptStatusFor]) and every other transition is written
// at the moment it happens, so every other query is a plain read of a column.
//
// ANY device may write the status. docs/design/shared-operations.md gives the
// rule a shared operation follows — a manager starts, pauses and restarts, only
// the owner ends the log or writes a status past that (§2), and a member's
// device skips the writes the app makes on its own (§6.2) — and that gate
// arrives with the membership it reads. Until then a shared operation's state
// is whatever the last writer said, the behaviour every other field in `data`
// already has.

import 'models.dart';

/// The seven states, as stored in `operation.data['status']` and mirrored to
/// the `status` column.
///
/// Strings rather than an enum: the value travels through QSON to app-polo
/// and to older builds, and a future build may write a state this one has
/// never heard of. An unrecognised status is treated exactly like an absent
/// one — see [statusIsKnown] — never as an error.
abstract final class OperationStatus {
  /// Created, before any setup.
  static const fresh = 'new';

  /// Setup accepted: references and callsigns assigned.
  static const ready = 'ready';

  /// Being logged. Entered explicitly, or by the first contact.
  static const active = 'active';

  /// Nothing is happening — an observation, which is why this is the state
  /// the sweep is allowed to infer and [completed] is not.
  static const paused = 'paused';

  /// The operator declared the work done. NOTHING infers this.
  static const completed = 'completed';

  /// At least one export or upload has left the app. Not a claim that
  /// everything owed has been sent — per-service upload records answer
  /// that; this only answers "has anything left yet", which is all
  /// [archived] keys off.
  static const processed = 'processed';

  /// Aged out of the working set, 7 days after [processed].
  static const archived = 'archived';

  static const all = [fresh, ready, active, paused, completed, processed, archived];
}

/// Whether [status] is one this build understands.
///
/// A value this build has never heard of — written by a newer one — is not
/// the same as an absent one: [sweptStatusFor] leaves it alone rather than
/// deriving over the top of a state it cannot reason about.
bool statusIsKnown(String? status) => status != null && OperationStatus.all.contains(status);

/// Whether [status] says the log has not been logged into yet: [OperationStatus.fresh],
/// [OperationStatus.ready], or none at all — an operation the sweep has not
/// reached, whose blob may carry the status as `''`. An unrecognised one is
/// NOT: a newer build wrote it, and this one cannot say it means unstarted.
bool statusIsUnstarted(String? status) => status == null || status.isEmpty || status == OperationStatus.fresh || status == OperationStatus.ready;

/// How long an operation may go without a contact before the sweep pauses it.
///
/// Fixed for now, and it WILL misfire on multi-day operations — Field Day's
/// overnight lull, a DXpedition's sleep cycle. Accepted: pausing is cheap and
/// the next contact restarts the operation on its own.
const operationPauseAfterSilence = Duration(hours: 12);

/// How long a processed operation waits before the sweep archives it.
const operationArchiveAfterProcessed = Duration(days: 7);

/// The status [operation] should hold at [nowMillis], or null when the stored
/// one already stands.
///
/// This is the whole of the sweep's judgement, as a pure function. Two rules
/// are time-driven and one is a migration:
///
/// - no status at all — every operation that exists today, and everything
///   app-polo writes, forever. An absent status is DERIVED, never an error.
/// - [OperationStatus.fresh] or [OperationStatus.ready] with contacts in it
///   is derived again. A log does not reach either state by being logged
///   into, so contacts in one mean the status was decided without them:
///   a bulk import that never went through the per-contact path, or a
///   derivation made while an operation had synced ahead of its own QSOs.
///   Without this the operation is stranded — those two states are otherwise
///   terminal, and nothing else would ever move it.
/// - [OperationStatus.active] falls to [OperationStatus.paused] after
///   [operationPauseAfterSilence] with nothing logged.
/// - [OperationStatus.processed] falls to [OperationStatus.archived] after
///   [operationArchiveAfterProcessed].
///
/// Apply it repeatedly until it answers null: an app closed for a fortnight
/// has operations that crossed several thresholds at once, and one step per
/// tick would leave them short.
String? sweptStatusFor(Operation operation, {required int nowMillis}) {
  final status = operation.status;
  // Absent gets derived; UNRECOGNISED does not. A status a newer build wrote
  // means something this one cannot evaluate, and replacing it with a guess
  // would undo that build's decision on every tick.
  if (status == null || status.isEmpty) return _derivedStatusFor(operation, nowMillis: nowMillis);
  if (!statusIsKnown(status)) return null;

  switch (status) {
    case OperationStatus.fresh:
    case OperationStatus.ready:
      if (operation.qsoCount > 0) return _derivedStatusFor(operation, nowMillis: nowMillis);
    case OperationStatus.active:
      final since = operationLastActivityMillis(operation);
      if (since != null && nowMillis - since >= operationPauseAfterSilence.inMilliseconds) {
        return OperationStatus.paused;
      }
    case OperationStatus.processed:
      final since = operation.processedAtMillis;
      if (since != null && nowMillis - since >= operationArchiveAfterProcessed.inMilliseconds) {
        return OperationStatus.archived;
      }
  }
  return null;
}

/// What an operation that has never carried a status is worth calling now.
///
/// Never [OperationStatus.completed] or later: those are claims about the
/// operator's intent and about what has left the app, and nothing here can
/// know either.
String _derivedStatusFor(Operation operation, {required int nowMillis}) {
  if (operation.qsoCount == 0) {
    // Setup having been accepted is the whole difference between the two,
    // and a pre-lifecycle operation carrying references had it accepted.
    return operation.refs.isEmpty ? OperationStatus.fresh : OperationStatus.ready;
  }
  // The last contact alone: a `new` or `ready` stamp records when the log was
  // created or set up — an import's creation is today, whatever its contacts
  // say — and is no sign of anyone at the radio.
  final since = operation.startAtMillisMax;
  if (since == null || nowMillis - since >= operationPauseAfterSilence.inMilliseconds) {
    return OperationStatus.paused;
  }
  return OperationStatus.active;
}

/// When this operation last showed a sign of life.
///
/// The later of the last contact and the moment the status was last written.
/// Both are needed, and taking only the first is the bug to guard against:
/// RESTART writes `statusAtMillis` and NEVER `startAtMillisMax` — event rows
/// are excluded from the operation counters — so a rule that watched only the
/// last contact would leave a reopened operation looking as silent as it was
/// a moment before, and the operator locked out of a log they had just asked
/// to reopen.
///
/// The creation date is the LAST resort, not a third candidate — an ADIF
/// import into a fresh operation is created now and carries contacts from
/// years ago, and folding creation into the maximum would call that log
/// active for twelve hours after the import.
///
/// Nullable throughout on purpose: `startAtMillisMax` is NULL, not zero, for
/// a QSO-less operation, and a comparison against NULL is neither true nor
/// false.
///
/// The logging panel measures its own, much shorter, silence with this too:
/// the window differs, the rule does not. [seenMillis] is a sign of life the
/// record does not hold — the panel's own last contact, which an old log
/// being typed in dates hours back.
int? operationLastActivityMillis(Operation operation, {int? seenMillis}) {
  final candidates = [operation.startAtMillisMax, operation.statusAtMillis, seenMillis].whereType<int>();
  if (candidates.isEmpty) return operation.createdAtMillis;
  return candidates.reduce((a, b) => a > b ? a : b);
}
