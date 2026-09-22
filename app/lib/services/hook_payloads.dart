// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The shapes an operation takes on its way into an extension hook — one per
// kind of hook, side by side so the two cannot drift about what an operation
// carries across the bridge.

import 'package:halo_core/halo_core.dart';

/// The QSON payload shape shared by every hook that takes a whole operation's
/// worth of QSOs in one coarse call (export, scoring, …) — `operation.data`
/// with `uuid` folded in, plus each QSO's raw QSON `data`.
///
/// The operator is RESOLVED here rather than left to `operation.data`, because
/// with a position set it lives in that position's own slot (see
/// [operatorCallFor]) and only this side knows which seat this device is in.
/// It is written under both names the extensions read:
/// `operation.operatorCall` for the REG1TEST/EDI writers, and
/// `operation.local.operatorCall` for the ADIF `OPERATORS` header — without
/// which those exports name nobody, or fall back to the station call.
///
/// `local` carries that one field and not the whole blob: `localData` also
/// holds the scoring cache and the title fragments, which have no business in
/// an export payload crossing the extension bridge.
Map<String, dynamic> qsonPayloadFor({required Operation operation, required List<Qso> qsos}) {
  final operatorCall = operatorCallFor(operation);
  return {
    'operation': {
      ...operation.data,
      'uuid': operation.uuid,
      'operatorCall': operatorCall,
      'local': {'operatorCall': operatorCall},
    },
    'qsos': [for (final qso in qsos) qso.data],
  };
}

/// One operation as a control-hook payload: its QSON blob, plus the uuid the
/// blob does not carry.
///
/// `operations_repository` keeps the uuid as the row's identity and strips it
/// from `data`, so a hook handed the bare blob cannot name the operation it
/// was called about — and anything it asks the host about that operation
/// (`ctx.getQsos`, above all) answers about nothing. [qsonPayloadFor] is the
/// same shape for the export and scoring hooks.
Map<String, dynamic> operationPayloadFor(Operation operation) => {...operation.data, 'uuid': operation.uuid};
