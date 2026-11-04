// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the logging panel needs to show an operation's lifecycle and move it.
// One spec rather than a dozen loose parameters, the way
// `SecondaryControlSpec` carries a control's whole description.
//
// The panel decides nothing about the model: it is handed the stored status
// and it calls back. Nothing here
// writes, and nothing downstream may derive a stored status from what this
// renders — see [operationQuietAfter].

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

/// How long an `active` operation goes without a contact before the PANEL
/// presents it as paused.
///
/// Deliberately far shorter than the record's own
/// [operationPauseAfterSilence]: the two answer different questions. The
/// stored status says whether the log may still change, which is what an
/// uploader needs and what a Field Day overnight lull must not disturb; this
/// says whether the operator is sitting at the radio right now, which is what
/// decides whether the entry row is worth the space it occupies.
///
/// So an operation can read "Paused" here while its record still says
/// `active`, and both are true. Nothing may write a status from this. The one
/// thing it dates is the panel's own Finish: pressed on a log shown as
/// paused, the finish lands where that pause began.
const operationQuietAfter = Duration(minutes: 30);

/// How long an `active` operation goes without a contact before the panel's
/// ⏸ grows its "Pause" label.
///
/// Short on purpose, and far short of [operationQuietAfter]: three minutes of
/// nothing logged is not a claim that the operator has left, it is the point
/// at which stepping away becomes a likely next move and worth spelling out.
/// Before it the glyph alone is enough for an operator between contacts.
///
/// The row stays live throughout. An operator calling CQ into a dead band has
/// not paused, and nothing about this writes a status — only the operator
/// pressing the button does.
const operationPauseLabelledAfter = Duration(minutes: 3);

/// The lifecycle half of the logging panel's inputs.
@immutable
class OperationLifecycleSpec {
  /// The operation's stored status, or null before anything has derived one.
  /// A null reads as "not started", the same as [OperationStatus.fresh].
  final String? status;

  /// The last contact's time, or when the operation went active if it has no
  /// contacts. What [operationQuietAfter] measures from. Null leaves the
  /// panel's quiet presentation off entirely.
  final int? lastActivityMillis;

  /// When the stored status was entered — for [OperationStatus.paused], when
  /// the pause began. Null for a record that predates the stamp.
  final int? statusAtMillis;

  /// What to call a closed state, localized by the app. Called with the
  /// stored status — and with [OperationStatus.paused] for a quiet-but-active
  /// operation, which is the one place the panel substitutes a state of its
  /// own.
  final String Function(String status) statusLabel;

  /// When the log was last sent out, for the note beside Exports — composed
  /// by the app, which has the locale, at the moment given. Null for a log
  /// never sent, which shows no note.
  final String Function(int nowMillis)? lastExportNote;

  /// The operation's date range, on the read's second line. Formatted by the
  /// app: this package has no locale.
  final String? dateRange;

  final String startLabel;
  final String pauseLabel;

  /// [onReopen]'s label: [continueLabel] while the operation is paused,
  /// [restartLabel] once it is finished. Both write the same `restart` row.
  final String continueLabel;
  final String restartLabel;
  final String endLabel;
  final String exportsLabel;

  /// Null disables the corresponding control. [onStart] is offered on a
  /// not-yet-started operation; [onReopen] sits beside the status read
  /// whenever one is showing; [onEnd] and [onExports] share the corner slot,
  /// the first until the log is declared finished and the second after.
  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onReopen;
  final VoidCallback? onEnd;
  final VoidCallback? onExports;

  const OperationLifecycleSpec({
    this.status,
    this.lastActivityMillis,
    this.statusAtMillis,
    required this.statusLabel,
    this.lastExportNote,
    this.dateRange,
    this.startLabel = 'Mark the start',
    this.pauseLabel = 'Pause',
    this.continueLabel = 'Continue',
    this.restartLabel = 'Restart',
    this.endLabel = 'Finish operation',
    this.exportsLabel = 'Exports',
    this.onStart,
    this.onPause,
    this.onReopen,
    this.onEnd,
    this.onExports,
  });

  /// True while the operation has not been logged into yet — the state that
  /// offers START — see [statusIsUnstarted].
  bool get notStarted => statusIsUnstarted(status);

  /// True when the RECORD says the log is no longer being written.
  bool get closed =>
      status == OperationStatus.paused || status == OperationStatus.completed || status == OperationStatus.processed || status == OperationStatus.archived;

  /// True once the operator has declared the log done, or sending it out has
  /// declared it for them. The difference from [closed] is what the corner
  /// slot offers: a paused log still has DONE ahead of it, a finished one has
  /// only its exports left.
  bool get finished => status == OperationStatus.completed || status == OperationStatus.processed || status == OperationStatus.archived;

  /// True when the record says `active` but nothing has been logged for
  /// [operationQuietAfter] — the operator has left the radio without saying
  /// so. Presented exactly as [OperationStatus.paused] is, and stored as
  /// nothing at all.
  bool quietAt(int nowMillis) {
    if (status != OperationStatus.active) return false;
    final since = lastActivityMillis;
    return since != null && nowMillis - since >= operationQuietAfter.inMilliseconds;
  }

  /// Whether the corner slot's ⏸ should carry its label.
  ///
  /// The narrow band between "logging" and "gone": nothing logged for
  /// [operationPauseLabelledAfter], but not yet long enough for the read to
  /// take the row ([quietAt]) — past that the slot has Finish to offer and
  /// the read has Continue.
  bool pauseLabelledAt(int nowMillis) {
    if (status != OperationStatus.active || quietAt(nowMillis)) return false;
    final since = lastActivityMillis;
    return since != null && nowMillis - since >= operationPauseLabelledAfter.inMilliseconds;
  }

  /// Whether the panel presents the operation as paused: stored that way, or
  /// [quietAt].
  bool presentsPausedAt(int nowMillis) => status == OperationStatus.paused || quietAt(nowMillis);

  /// When the pause the panel is presenting began, or null when it is not
  /// presenting one or cannot date it: the stored pause's own stamp, or for a
  /// quiet-but-active operation the last sign of life its silence is
  /// measured from.
  int? pausedSinceAt(int nowMillis) {
    if (status == OperationStatus.paused) return statusAtMillis ?? lastActivityMillis;
    if (quietAt(nowMillis)) return lastActivityMillis;
    return null;
  }

  /// What the two-line read says on its first line, or null when the panel
  /// should show the ordinary entry row.
  String? readingAt(int nowMillis) {
    if (closed) return statusLabel(status!);
    if (quietAt(nowMillis)) return statusLabel(OperationStatus.paused);
    return null;
  }
}
