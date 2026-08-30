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
  if (local.containsKey(operatorCallKey)) return deviceOperatorCallFor(operation);
  return (asQsonString(operation.data[operatorCallKey]) ?? '').trim();
}

/// Who THIS DEVICE says is at the key — no fallback to the synced value.
///
/// The fallback in [operatorCallFor] is a display convenience: a header
/// naming the operator a legacy operation carries is better than one naming
/// nobody, and it costs nothing if it is out of date. A WRITE cannot afford
/// the same guess. The synced field converges across every device logging the
/// operation, so a device whose own operator was never set would stamp every
/// contact it logs with another device's operator — permanently, and into the
/// exported log.
String deviceOperatorCallFor(Operation operation) =>
    (asQsonString(operation.localData[operatorCallKey]) ?? '').trim();

/// The `localData` key holding this device's position in a multi-station
/// operation. Device-local for the same reason [operatorCallKey] is.
const multiIdentifierKey = 'multiIdentifier';

/// The canonical form of a multi-station position: the digits with no
/// leading zeros, or `''` for no position at all.
///
/// `0` means none. A station numbers its operators from 1, so zero is free
/// to mean off — it is what `POSITION 0` types, and what an operator who read
/// that types into the details dialog. Anything unparseable is none too:
/// `/OP` followed by nonsense is a callsign no hunter can use.
///
/// Every writer goes through this — the Operation Details dialog and the
/// POSITION command alike — so the two cannot disagree about what `0` or
/// `02` mean, and `spotCallForSelfSpot` applies it again on the way out, so
/// whatever is in the row, the air gets the canonical form.
String normalizedMultiIdentifier(String raw) {
  final parsed = int.tryParse(raw.trim());
  return parsed == null || parsed <= 0 ? '' : parsed.toString();
}

/// This device's position in [operation], canonical — `''` for none.
String multiIdentifierFor(Operation operation) =>
    normalizedMultiIdentifier(asQsonString(operation.localData[multiIdentifierKey]) ?? '');

/// [qso] stamped with who was at the key and which position logged it.
///
/// Both are device-local facts about the operation, and both stop being true
/// the moment the next operator takes over — so a contact records them as it
/// is logged rather than deriving them at export, which would attribute the
/// whole log to whoever happens to be sitting there when the file is written.
///
/// A value ALREADY on the QSO wins, and absence is what's tested, not
/// emptiness: re-saving an edited contact runs through here again, and the
/// operator who fixes a typo in someone else's QSO is not the one who made
/// it. That also leaves an import's own `OPERATOR` untouched. The protection
/// only reaches contacts that carry the field at all, so editing one logged
/// before this existed — or imported from a file naming no operator — does
/// stamp whoever is editing.
///
/// Read through [deviceOperatorCallFor], not [operatorCallFor]: a device that
/// has never named an operator stamps nothing, rather than borrowing the
/// value another device synced.
///
/// Event rows are left alone — a break marker has no operator.
Map<String, dynamic> qsoWithOperator(Map<String, dynamic> qso, Operation operation) {
  if (qso['band'] == 'event') return qso;
  final operatorCall = deviceOperatorCallFor(operation);
  final multiIdentifier = multiIdentifierFor(operation);
  if (operatorCall.isEmpty && multiIdentifier.isEmpty) return qso;

  final our = {...?asQsonMap(qso['our'])};
  if (operatorCall.isNotEmpty) our[operatorCallKey] ??= operatorCall;
  if (multiIdentifier.isNotEmpty) our[multiIdentifierKey] ??= multiIdentifier;
  return {...qso, 'our': our};
}
