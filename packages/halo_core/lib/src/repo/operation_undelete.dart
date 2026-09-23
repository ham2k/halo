// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import '../db/database.dart';
import '../models/qson_values.dart';
import 'operations_repository.dart';
import 'qsos_repository.dart';

/// Restores the soft-deleted operation [uuid], along with the QSOs that were
/// tombstoned WITH it rather than one by one. Returns whether the operation
/// was restored.
///
/// HaLo's operation delete leaves QSOs alone, but app-polo's tombstones every
/// one of them, writing a single `updatedAtMillis` to the operation and its
/// QSOs alike. So a deleted QSO carrying exactly the operation tombstone's
/// stamp went with the operation; any other deleted QSO was the operator's
/// own delete and stays deleted — unless it was made in the tombstone's own
/// millisecond, which no operator manages and a test easily does.
///
/// The stamp is only the tombstone's while nothing has saved the operation
/// since — every save re-stamps it — which is why a deleted operation is
/// read-only in the app until it is undeleted. A tombstone with no stamp
/// (or one no QSO shares) restores the operation alone.
///
/// One transaction: an operation restored without its QSOs reads as an empty
/// log, and nothing would revisit it.
Future<bool> undeleteOperationWithQsos({
  required HaLoDatabase db,
  required OperationsRepository operations,
  required QsosRepository qsos,
  required String uuid,
}) => db.transaction(() async {
  final tombstone = await operations.get(uuid);
  if (!await operations.undelete(uuid)) return false;
  final stamp = asQsonNum(tombstone?.data['updatedAtMillis'])?.toInt();
  if (stamp == null) return true;
  await qsos.undeleteStamped(uuid, stamp);
  qsos.onChange?.call();
  return true;
});
