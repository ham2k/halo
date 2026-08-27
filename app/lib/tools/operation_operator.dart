// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Who is at the key on THIS device, for an operation several devices may be
// logging at once.
//
// The operator callsign is device-local, like the multi-station position
// beside it (`localData['multiIdentifier']`) and unlike the station call:
// several operators log one operation under one station call, a device each,
// so an operator in the operation's SYNCED `data` converges to a single value
// across all of them — peer sync merges operations too, not just QSOs.

import 'package:halo_core/halo_core.dart';

/// The `localData` key. Deliberately the same name the synced field carries,
/// so [operatorCallFor]'s fallback reads one name in both places.
const operatorCallKey = 'operatorCall';

/// Who is at the key on this device — empty when nobody is named.
///
/// Falls back to the operation's synced `data['operatorCall']` while this
/// device has never set one: operations that predate the operator becoming
/// device-local carry it there, and reading through means they keep naming
/// the right callsign without a migration pass over every stored row.
///
/// The fallback keys on the KEY'S PRESENCE, not on an empty value. Once a
/// device has written its own operator, clearing it has to mean cleared —
/// keying on emptiness would read the synced value back the moment the
/// operator blanked the field, and nothing they could type would remove it.
String operatorCallFor(Operation operation) {
  final local = operation.localData;
  if (local.containsKey(operatorCallKey)) return (asQsonString(local[operatorCallKey]) ?? '').trim();
  return (asQsonString(operation.data[operatorCallKey]) ?? '').trim();
}
