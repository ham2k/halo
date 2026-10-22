// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

// Elecraft K4 Programmer's Reference D12, Radio Commands:
// https://ftp.elecraft.com/K4/Manuals%20Downloads/K4ProgrammersReferencerev.D12.html

import '../equipment.dart';
import 'k4_codec.dart';
import 'kenwood_cat_codec.dart';

enum K4Receiver {
  main,
  sub;

  String get suffix => this == sub ? r'$' : '';
  String get frequencyCommand => this == sub ? 'FB' : 'FA';
  int get panId => this == sub ? 1 : 0;
}

/// An absent setting belongs to Main, including previously saved K4 nodes.
K4Receiver? parseK4Receiver(Object? value) => switch (value) {
  null || '' || 'main' => K4Receiver.main,
  'sub' => K4Receiver.sub,
  _ => null,
};

String? buildK4ReceiverFrequency(K4Receiver receiver, double freqKHz) {
  // Preserve transverter frequencies while preventing the legacy encoder's
  // eleven-digit truncation from silently tuning a different frequency.
  if (!freqKHz.isFinite || freqKHz <= 0 || freqKHz > 99999999.999) return null;
  return '${receiver.frequencyCommand}${encodeKenwoodFrequencyHz((freqKHz * 1000).round())};';
}

String? buildK4ReceiverMode(K4Receiver receiver, String mode) {
  final main = buildK4SetModeCommand(mode);
  if (main == null || receiver == K4Receiver.main) return main;
  return main.replaceAll('MD', r'MD$').replaceAll('DT', r'DT$');
}

/// SMH has its own dBm units; legacy SM bars must never be treated as dBm.
({K4Receiver receiver, int dbm})? parseK4Signal(String params) {
  final match = RegExp(r'^H(\$?)([+-]\d{3})$').firstMatch(params);
  if (match == null) return null;
  final dbm = int.parse(match[2]!);
  if (dbm < -200 || dbm > 50) return null;
  return (receiver: match[1]!.isEmpty ? K4Receiver.main : K4Receiver.sub, dbm: dbm);
}

/// SSB has a documented RF orientation. Shifted CW and DATA do not, so
/// their filters stay unknown rather than inventing an on-frequency marker.
Passband? k4ReceiverPassband({required String? mode, required int? widthHz, required int? centerHz, required int? cwPitchHz}) {
  if (widthHz == null || widthHz <= 0 || centerHz == null) return null;
  if (mode == 'CW' || mode == 'CW-R') {
    if (centerHz != cwPitchHz) return null;
    return Passband(-(widthHz ~/ 2), widthHz - widthHz ~/ 2);
  }
  if (mode != 'USB' && mode != 'LSB') return null;
  final low = centerHz - widthHz ~/ 2, high = centerHz + widthHz - widthHz ~/ 2;
  return mode == 'LSB' ? Passband(-high, -low) : Passband(low, high);
}
