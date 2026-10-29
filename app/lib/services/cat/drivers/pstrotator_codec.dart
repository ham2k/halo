// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// PstRotator's UDP Control wire format, from its User's Manual (Rev 7.5,
// "UDP Control"). Pure — strings in, records out.
//
// Every message is one `<PST>…</PST>` envelope, and may carry several
// commands. Set commands are elements; queries are bare text:
//
//   <PST><AZIMUTH>85</AZIMUTH></PST>     turn to azimuth 85
//   <PST><ELEVATION>23</ELEVATION></PST> turn to elevation 23
//   <PST><STOP>1</STOP></PST>            stop
//   <PST>AZ?</PST>  →  AZ:xxx.x<CR>      to the UDP port + 1
//   <PST>EL?</PST>  →  EL:yy.y<CR>
//
// Set commands are answered by nothing the manual names, and a handful of
// others (ACQ, HOME, the satellite ones) by `OK:…` — none of which this
// layer sends.

/// Asks for the azimuth.
const pstAzimuthQuery = '<PST>AZ?</PST>';

/// Asks for the elevation.
const pstElevationQuery = '<PST>EL?</PST>';

/// Stops the rotator.
const pstStopCommand = '<PST><STOP>1</STOP></PST>';

/// Turns to [azimuth], and to [elevation] when there is one, in one message
/// — the manual's "many commands in one message" — so an az/el turn is never
/// half sent.
///
/// Whole degrees, as every example in the manual is. An azimuth is held to
/// 0–360: past either end it is a heading on no rotator.
String pstTurnCommand(num azimuth, {num? elevation}) {
  final az = azimuth.round().clamp(0, 360);
  return '<PST><AZIMUTH>$az</AZIMUTH>${elevation == null ? '' : '<ELEVATION>${elevation.round()}</ELEVATION>'}</PST>';
}

/// One answer: which axis, and where it points, in whole degrees.
typedef PstReading = ({bool elevation, int degrees});

final _readingPattern = RegExp(r'^(AZ|EL):\s*(-?\d+(?:\.\d+)?)');

/// An `AZ:` or `EL:` answer, or null for anything else — an `OK:` echo, a
/// `MODE:`, or something only a later PstRotator says.
PstReading? parsePstReading(String line) {
  final match = _readingPattern.firstMatch(line.trim());
  if (match == null) return null;
  return (elevation: match.group(1) == 'EL', degrees: double.parse(match.group(2)!).round());
}
