// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Yaesu GS-232 rotator control wire format.
//
// Pure — strings in, records out. Every command is a few ASCII letters and
// zero-padded three-digit angles, ended by a carriage return. Per the
// GS-232A manual the controller echoes nothing, answers a set command with
// nothing, and answers only the position queries:
//
//   C<CR>        → +0123          azimuth
//   C2<CR>       → +0123+0045     azimuth and elevation
//   M123<CR>       turn to azimuth 123
//   W123 045<CR>   turn to azimuth 123, elevation 045
//   S<CR>          stop everything
//
// The GS-232B answers the same queries as `AZ=123` and `AZ=123  EL=045`,
// and the controllers that emulate either one (K3NG, ERC, PstRotator's
// serial side) answer in whichever dialect they were built for — some
// mixing the two. So the parser accepts both, and nothing else here
// depends on which one a controller speaks.

import '../equipment.dart' show RotatorPosition;

/// Ends every command.
const gs232Terminator = '\r';

/// Asks for the azimuth alone.
const gs232AzimuthQuery = 'C$gs232Terminator';

/// Asks for azimuth and elevation together.
const gs232AzimuthElevationQuery = 'C2$gs232Terminator';

/// Stops both axes.
const gs232StopCommand = 'S$gs232Terminator';

/// The widest azimuth the protocol takes: a 450° rotator's overlap. A
/// bearing is never past 360, but a controller told 450 on a 360° rotator
/// stops at its end stop rather than refusing, so the codec does not need to
/// know which one is on the mast.
const gs232MaxAzimuth = 450;

/// The widest elevation the protocol takes — an az/el rotator like the
/// G-5500 flips over the top, so 90 is not the limit.
const gs232MaxElevation = 180;

/// What the controller says to a command it does not know.
const gs232Refusal = '?>';

/// Turn to [azimuth], leaving the elevation where it is.
String gs232AzimuthCommand(num azimuth) => 'M${_angle(azimuth, gs232MaxAzimuth)}$gs232Terminator';

/// Turn to [azimuth] and [elevation] together. There is no elevation-only
/// command: an elevation change is always sent with an azimuth.
String gs232AzimuthElevationCommand(num azimuth, num elevation) =>
    'W${_angle(azimuth, gs232MaxAzimuth)} ${_angle(elevation, gs232MaxElevation)}$gs232Terminator';

/// Three digits, left-padded — the manual's requirement. `M5` is not `M005`
/// to a GS-232A, which reads the digits that follow as part of the angle.
String _angle(num value, int max) => value.round().clamp(0, max).toString().padLeft(3, '0');

final _gs232aReply = RegExp(r'^\+(\d{4})(?:\+(\d{4}))?$');
final _gs232bAzimuth = RegExp(r'AZ\s*=\s*(\d{1,3})');
final _gs232bElevation = RegExp(r'EL\s*=\s*(\d{1,3})');

/// The position in [line], in either dialect, or null for anything else —
/// a blank line, a refusal, a help screen, a controller's banner. The
/// elevation is null where the answer carried none: a `C` reply, or a
/// controller that answers `C2` with the azimuth alone.
RotatorPosition? parseGs232Position(String line) {
  final text = line.trim().toUpperCase();
  if (_gs232aReply.firstMatch(text) case final match?) {
    final elevation = match.group(2);
    return RotatorPosition(azimuth: int.parse(match.group(1)!), elevation: elevation == null ? null : int.parse(elevation));
  }
  final azimuth = _gs232bAzimuth.firstMatch(text)?.group(1);
  if (azimuth == null) return null;
  final elevation = _gs232bElevation.firstMatch(text)?.group(1);
  return RotatorPosition(azimuth: int.parse(azimuth), elevation: elevation == null ? null : int.parse(elevation));
}

/// Whether [line] is the controller refusing a command.
bool isGs232Refusal(String line) => line.trim().startsWith(gs232Refusal);
