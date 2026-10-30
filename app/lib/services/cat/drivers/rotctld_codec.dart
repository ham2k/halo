// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Hamlib's `rotctld` network protocol, from a capture of `rotctld -m 1`
// (Hamlib 4.7.2). Pure — strings in, records out. Line-oriented ASCII,
// each command and answer ended by a line feed, every answer in the order
// its command was sent:
//
//   p              →  0.61\n0.00\n       azimuth, then elevation, bare
//   P 90 10        →  RPRT 0             turn; RPRT -21 past the limits
//   S              →  RPRT 0             stop
//   \dump_state    →  1\n1\nmin_az=-180.000000\n…\ndone\n
//
// A `p` that fails answers `RPRT n` in place of its two lines.
//
// Plain `p` rather than the self-labelling `+p`: it is what Gpredict sends,
// so it is what anything else that speaks "rotctld" — PstRotator's Gpredict
// mode — is most likely to answer. An azimuth can be negative, on a backend
// whose range starts at -180.
//
// `P` takes BOTH arguments, always: sent one, the daemon takes the next line
// it is sent as the elevation. And a command it does not know is answered
// by nothing at all.
//
// The limits are `\dump_state`'s, not `\dump_caps`': the caps are the
// backend's own, and a daemon started with `-C min_az=0,max_az=360` still
// reports -180 to 450 there while refusing -90. `\dump_state` is the
// protocol version, the rotator model, then the limits — as `key=value`
// lines ending in `done` from version 1 (Hamlib 4.5), as four bare numbers
// in version 0. Neither ends in `RPRT`.

/// Asks where the rotator points.
const rotctldPositionQuery = 'p\n';

/// Asks for the limits the daemon enforces, among the rest of its state.
const rotctldStateQuery = '\\dump_state\n';

/// Stops every axis.
const rotctldStopCommand = 'S\n';

/// Turns to [azimuth] and [elevation], in the controller's own degrees.
String rotctldTurnCommand(int azimuth, int elevation) => 'P $azimuth $elevation\n';

/// Hamlib's "limit exceeded": a turn past the limits the daemon enforces.
const rotctldLimitExceeded = -21;

/// Hamlib's "communication timed out": the backend asked the controller and
/// heard nothing.
const rotctldTimedOut = -5;

final _numberPattern = RegExp(r'^-?\d+(?:\.\d+)?$');
final _reportPattern = RegExp(r'^RPRT (-?\d+)$');
final _stateVersionPattern = RegExp(r'^[01]$');
final _stateLimitPattern = RegExp(r'^(min|max)_(az|el)=(-?\d+(?:\.\d+)?)$');
final _stateFieldPattern = RegExp(r'^\w+=');

/// A bare number — half of a `p` answer — or null for anything else.
double? parseRotctldNumber(String line) => _numberPattern.hasMatch(line.trim()) ? double.parse(line.trim()) : null;

/// The code of an `RPRT n` line: 0 for done, a negative Hamlib error
/// otherwise. Null for anything else.
int? parseRotctldReport(String line) => switch (_reportPattern.firstMatch(line.trim())) {
  final match? => int.parse(match.group(1)!),
  null => null,
};

/// The protocol version a `\dump_state` answer starts with, or null for a
/// line that cannot be one. Hamlib prints a position with decimals, so a
/// bare `0` or `1` is not one.
int? parseRotctldStateVersion(String line) => _stateVersionPattern.hasMatch(line.trim()) ? int.parse(line.trim()) : null;

/// Which limit a `\dump_state` line names, and its value in whole degrees.
typedef RotctldLimit = ({bool max, bool elevation, int degrees});

/// A version 1 `min_az=` / `max_az=` / `min_el=` / `max_el=` line.
RotctldLimit? parseRotctldStateLimit(String line) => switch (_stateLimitPattern.firstMatch(line.trim())) {
  final match? => (max: match.group(1) == 'max', elevation: match.group(2) == 'el', degrees: double.parse(match.group(3)!).round()),
  null => null,
};

/// Any other version 1 `key=value` line.
bool isRotctldStateField(String line) => _stateFieldPattern.hasMatch(line.trim());

/// The line a version 1 `\dump_state` answer ends with.
const rotctldStateEnd = 'done';

/// What version 0's bare numbers after the model are, in order.
const rotctldStateV0Limits = [(max: false, elevation: false), (max: true, elevation: false), (max: false, elevation: true), (max: true, elevation: true)];
