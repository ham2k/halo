// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Which radios have already told us they work, so the first-success report
// (docs/design/telemetry.md § Radios) is sent once and not once per launch.
//
// A radio is remembered by its uuid AND by a fingerprint of the settings it
// worked under. That pairing is the whole design: the same radio on a new
// port, baud rate or CI-V address is a different answer to the question the
// report asks, and it is the most interesting one there is — an operator who
// changed a setting and got the rig talking has found out something the
// catalogue's defaults did not know. A uuid-only mark would throw exactly
// that away.
//
// Secrets never reach the fingerprint. It is a hash and it never leaves the
// device, but a password's presence in a prefs file is not something to
// arrange casually, and the values that decide whether a rig talks are the
// ones the operator can see.

import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'equipment.dart';
import 'equipment_registry.dart';

/// Namespaced like `cat:autoConnectInFlight`, the other mark this service
/// keeps in preferences.
const provenRadiosKey = 'cat:provenRadios';

/// Marks already written, as `<uuid>:<fingerprint>` entries.
List<String> provenRadioMarks(SharedPreferences prefs) => prefs.getStringList(provenRadiosKey) ?? const [];

/// Whether [node] has already been reported working under its CURRENT config.
bool isRadioProven(SharedPreferences prefs, EquipmentNode node, EquipmentRegistry registry) => provenRadioMarks(prefs).contains(radioProofMark(node, registry));

/// Records [node] as reported. Replaces any mark this node had under an older
/// config rather than accumulating one per setting it ever worked under: what
/// the app needs to know is whether THIS configuration has been reported, and
/// a list that only grows is a preference file that only grows.
Future<void> markRadioProven(SharedPreferences prefs, EquipmentNode node, EquipmentRegistry registry) async {
  final mark = radioProofMark(node, registry);
  final marks = provenRadioMarks(prefs);
  if (marks.contains(mark)) return;
  final kept = [
    for (final existing in marks)
      if (!existing.startsWith('${node.uuid}:')) existing,
  ];
  await prefs.setStringList(provenRadiosKey, [...kept, mark]);
}

/// Drops [uuid]'s mark, whatever config it was made under — for a node the
/// operator deleted. A mark left behind would re-arm nothing and cost
/// nothing, but a node re-added with the same uuid is exactly the case where
/// a stale "already reported" would silence the report that matters.
Future<void> clearRadioProof(SharedPreferences prefs, String uuid) async {
  final marks = provenRadioMarks(prefs);
  final kept = [
    for (final existing in marks)
      if (!existing.startsWith('$uuid:')) existing,
  ];
  if (kept.length == marks.length) return;
  if (kept.isEmpty) {
    await prefs.remove(provenRadiosKey);
  } else {
    await prefs.setStringList(provenRadiosKey, kept);
  }
}

/// `<uuid>:<fingerprint>` — what a mark is.
String radioProofMark(EquipmentNode node, EquipmentRegistry registry) => '${node.uuid}:${_fingerprint(node, registry)}';

/// The settings this radio is talking under, as eight hex characters.
///
/// Sorted by key, so a config map that merely reordered is the same
/// fingerprint and does not re-arm the report. The type key is in there
/// too: re-pairing an IC-705 from WiFi to USB changes no config value the
/// two transports share, and it is plainly a different setup.
String _fingerprint(EquipmentNode node, EquipmentRegistry registry) {
  final secrets = registry.allSecretFields;
  final keys = [
    for (final key in node.config.keys)
      if (!secrets.contains(key)) key,
  ]..sort();
  final payload = [node.typeKey, for (final key in keys) '$key=${node.config[key]}'].join(' ');
  return sha256.convert(utf8.encode(payload)).toString().substring(0, 8);
}

/// What one connection has heard the RADIO itself say, and the moment that
/// becomes proof the pairing works.
///
/// Never the app's own words. `CatService._applyReading` completes a partial
/// frame from `lastSent` — what the radio was last TOLD — so a rig that
/// echoes only its frequency still yields a merged reading carrying both
/// fields. Fed that, this would report "reads frequency and mode" about the
/// app talking to itself. It is fed the driver's RAW frame for that reason,
/// and the distinction is the whole value of the report.
///
/// One per connection, reset when a new one is installed: what the last
/// connection heard says nothing about this one.
class RadioProofWatch {
  bool _heardFreq = false;
  bool _heardMode = false;
  bool _fired = false;

  /// Takes the radio's own frame and answers whether THIS one completed the
  /// pair — true exactly once, however many readings follow.
  ///
  /// The two are accumulated rather than required together because a driver
  /// may answer them in separate frames.
  bool note(VfoReading reading) {
    if (reading.freqKHz != null) _heardFreq = true;
    if (reading.mode != null) _heardMode = true;
    if (_fired || !_heardFreq || !_heardMode) return false;
    _fired = true;
    return true;
  }

  /// A fresh connection has nothing yet.
  void reset() {
    _heardFreq = false;
    _heardMode = false;
    _fired = false;
  }
}
