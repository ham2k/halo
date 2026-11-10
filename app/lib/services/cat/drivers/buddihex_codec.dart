// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The BuddiHex mast rotator's UDP format, from its controller's firmware
// (github.com/mdannhardt/rotatorControllerESP8266, MIT, 3.0.1). Pure —
// strings in, records out.
//
// The controller listens on UDP 4210 and answers to whichever port a
// command came from. It takes PstRotator's turn and stop as they are, and
// answers its own status query:
//
//   <PST><AZIMUTH>85</AZIMUTH></PST>   turn to azimuth 85
//   <PST><STOP>1</STOP></PST>          stop
//   GET_BEARING  →  GET_BEARING:85            where it points, 1 to 360
//                   GET_BEARING:85:CW         …turning clockwise
//                   GET_BEARING:85:Stuck      …stuck on its last turn
//                   GET_BEARING:0             the compass was not ready
//                   GET_BEARING:-1:Error!     the compass is not there
//
// A turn and a stop are answered by nothing. The firmware's own
// `<PST>AZ?` answer carries a heading only; `GET_BEARING` also says when the
// mast has stuck or the compass has failed, which is why this polls it.

import 'pstrotator_codec.dart' show pstTurnCommand;

export 'pstrotator_codec.dart' show pstStopCommand;

/// Where the controller listens.
const buddihexPort = 4210;

/// The controller's own address on the network it makes for itself, which a
/// phone or a laptop joins to reach it before it is on the shack's WiFi.
const buddihexAccessPointHost = '192.168.4.1';

/// Asks where it points, and how the turn is going.
const buddihexBearingQuery = 'GET_BEARING';

/// Turns to [azimuth], in whole degrees, 0 to 359: the controller refuses
/// anything past 360 and takes 0 as north, as it does 360.
String buddihexTurnCommand(num azimuth) => pstTurnCommand(azimuth.round() % 360);

/// The controller's compass failures: by the code it answers with, and
/// [compassNotReady] for the 0 it gives when a read finds the compass not
/// ready — its headings run 1 to 360, and it drops every turn it is sent
/// while it reads 0.
enum BuddihexFault { compassMissing, compassNotReady, calibrationFailed, other }

/// One answer: a heading, and whether it stuck; or a fault.
sealed class BuddihexReading {
  const BuddihexReading();
}

class BuddihexBearing extends BuddihexReading {
  final int azimuth;

  /// Its last turn stopped short: the compass did not move five degrees in
  /// five seconds, and the controller stopped the motor. It stands until a
  /// turn more than five degrees away; a smaller one is a timed nudge that
  /// leaves it.
  final bool stuck;

  const BuddihexBearing(this.azimuth, {this.stuck = false});

  @override
  bool operator ==(Object other) => other is BuddihexBearing && other.azimuth == azimuth && other.stuck == stuck;

  @override
  int get hashCode => Object.hash(azimuth, stuck);

  @override
  String toString() => 'BuddihexBearing($azimuth${stuck ? ', stuck' : ''})';
}

class BuddihexFaulted extends BuddihexReading {
  final BuddihexFault fault;
  const BuddihexFaulted(this.fault);

  @override
  bool operator ==(Object other) => other is BuddihexFaulted && other.fault == fault;

  @override
  int get hashCode => fault.hashCode;

  @override
  String toString() => 'BuddihexFaulted($fault)';
}

final _bearingPattern = RegExp(r'^GET_BEARING:(-?\d+)((?::[A-Za-z!]+)*)$');

/// A `GET_BEARING:` answer, or null for anything else — an `AZ:` one, an
/// `IDENTIFY:` one, or one only a later firmware gives.
BuddihexReading? parseBuddihexReading(String line) {
  final match = _bearingPattern.firstMatch(line.trim());
  if (match == null) return null;
  final value = int.parse(match.group(1)!);
  final words = match.group(2)!.split(':').where((w) => w.isNotEmpty).toSet();
  if (value == 0) return const BuddihexFaulted(BuddihexFault.compassNotReady);
  if (words.contains('Error!')) {
    return BuddihexFaulted(switch (value) {
      -1 => BuddihexFault.compassMissing,
      -2 => BuddihexFault.compassNotReady,
      -3 => BuddihexFault.calibrationFailed,
      _ => BuddihexFault.other,
    });
  }
  return BuddihexBearing(value % 360, stuck: words.contains('Stuck'));
}
