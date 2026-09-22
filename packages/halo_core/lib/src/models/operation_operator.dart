// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Who is at the key, for an operation several devices may be logging at once.
//
// The operator callsign is the operation's own SYNCED data, beside the station
// call, the title and the notes. What is device-local is the POSITION
// (`localData['multiIdentifier']`): which seat this device occupies. That one
// must not converge, or every device in a multi-station operation would
// self-spot under the same `/OP<n>`.
//
// With a position set, the operator is stored PER POSITION — `operator1`,
// `operator2`, … — so each seat names its own operator in data every device
// can read, and a device that knows it is seat 2 reads seat 2's operator.

import 'models.dart';
import 'qson_values.dart';

/// The `data` key holding the operator of a positionless operation. Also the
/// legacy `localData` key, from when the operator itself was device-local.
const operatorCallKey = 'operatorCall';

/// The `data` key holding the operator sitting at [position] — the plain
/// [operatorCallKey] when there is no position, `operator<n>` when there is.
String operatorCallKeyFor(String position) => position.isEmpty ? operatorCallKey : 'operator$position';

/// Who is at the key on this device — empty when nobody is named.
///
/// Falls back to the legacy device-local `localData['operatorCall']` while the
/// operation's data has no slot for this position at all: operations set up
/// while the operator was device-local carry it there, and reading through
/// means they keep naming the right callsign without a migration pass over
/// every stored row.
///
/// The fallback keys on the SLOT'S PRESENCE, not on an empty value. Once the
/// slot exists, clearing it has to mean cleared — keying on emptiness would
/// read the stale local value back the moment the operator blanked the field,
/// and nothing they could type would remove it.
String operatorCallFor(Operation operation) {
  final key = operatorCallKeyFor(multiIdentifierFor(operation));
  if (operation.data.containsKey(key)) return (asQsonString(operation.data[key]) ?? '').trim();
  return (asQsonString(operation.localData[operatorCallKey]) ?? '').trim();
}

/// The `localData` key holding this device's position in a multi-station
/// operation.
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
/// whatever is in the row, the air gets the canonical form. It also settles
/// which `operator<n>` slot [operatorCallKeyFor] names, so a seat typed as
/// `02` and one typed as `2` are the same seat.
String normalizedMultiIdentifier(String raw) {
  final parsed = int.tryParse(raw.trim());
  return parsed == null || parsed <= 0 ? '' : parsed.toString();
}

/// Whether [operation] is being logged by operating positions at all — this
/// device sits in one, or some device that synced its operator did.
///
/// What the QSO editor keys its Position field on: a plain single-operator
/// operation has no seats to choose between, and offering the field there is
/// offering a number that means nothing.
bool operationHasPositions(Operation operation) => multiIdentifierFor(operation).isNotEmpty || operation.data.keys.any((key) => _positionSlot.hasMatch(key));

final _positionSlot = RegExp(r'^operator[1-9][0-9]*$');

/// This device's position in [operation], canonical — `''` for none.
String multiIdentifierFor(Operation operation) => normalizedMultiIdentifier(asQsonString(operation.localData[multiIdentifierKey]) ?? '');

/// [qso] stamped with who was at the key and which position logged it.
///
/// Both stop being true the moment the next operator takes over — so a
/// contact records them as it is logged rather than deriving them at export,
/// which would attribute the whole log to whoever happens to be sitting there
/// when the file is written.
///
/// Only a contact being LOGGED is stamped. A record that already exists
/// carries its own `uuid` (the editor composes from the stored row, and a
/// call list strips it for the calls it adds), and re-saving one runs through
/// here again: stamping it would hand every contact made before an operator
/// was ever named — and every one made by somebody else — to whoever opened
/// it to fix a typo. A record with no operator stays with no operator, in the
/// log and in the export.
///
/// A value ALREADY on the QSO wins too, and absence is what's tested, not
/// emptiness — that leaves an import's own `OPERATOR` untouched, and lets the
/// QSO editor record a deliberately emptied field as empty.
///
/// Event rows are left alone — a break marker has no operator.
Map<String, dynamic> qsoWithOperator(Map<String, dynamic> qso, Operation operation) {
  if (qso['band'] == 'event') return qso;
  if ((asQsonString(qso['uuid']) ?? '').isNotEmpty) return qso;
  final operatorCall = operatorCallFor(operation);
  final multiIdentifier = multiIdentifierFor(operation);
  if (operatorCall.isEmpty && multiIdentifier.isEmpty) return qso;

  final our = {...?asQsonMap(qso['our'])};
  if (operatorCall.isNotEmpty) our[operatorCallKey] ??= operatorCall;
  if (multiIdentifier.isNotEmpty) our[multiIdentifierKey] ??= multiIdentifier;
  return {...qso, 'our': our};
}
