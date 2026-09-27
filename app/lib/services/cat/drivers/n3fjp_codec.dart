// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The band, mode and frequency half of the N3FJP logging programs' TCP API
// (https://www.n3fjp.com/help/api.html), both directions: the N3FJP driver's
// client and the CAT server's emulation.
//
// Every message is `<CMD><NAME>…</CMD>` ended by CR LF, and several can
// arrive in one read or one split across two, so input is cut at `</CMD>`
// rather than at line ends. Tags match case-insensitively.
//
// N3FJP's modes are a log's, not a radio's: `SSB` rather than a sideband,
// `DATA` or `FT8` rather than a data sideband. A radio mode folds into the
// mode a log records on the way out ([n3fjpModeForRadioMode]), and a log
// mode goes back through the app's own translation on the way in
// ([appModeForN3fjpMode]).

import 'package:halo_core/halo_core.dart';

/// One message: its command name and everything between that tag and
/// `</CMD>`.
final n3fjpCommand = RegExp(r'<CMD>\s*<([A-Z0-9_]+)>(.*?)</CMD>', caseSensitive: false, dotAll: true);

/// Where a message ends.
final n3fjpCommandEnd = RegExp(r'</CMD>', caseSensitive: false);

/// [inner] as one message on the wire.
String n3fjpMessage(String inner) => '<CMD>$inner</CMD>\r\n';

/// The text of the first `<name>` element in [body], or null.
String? n3fjpTag(String body, String name) => RegExp('<$name>(.*?)</$name>', caseSensitive: false, dotAll: true).firstMatch(body)?.group(1);

/// N3FJP names a band by its metres without the unit (`40`), and anything
/// shorter by its own name (`70CM`).
String n3fjpBand(String? band) {
  if (band == null) return '';
  final upper = band.toUpperCase();
  return upper.endsWith('M') && !upper.endsWith('CM') && !upper.endsWith('MM') ? upper.substring(0, upper.length - 1) : upper;
}

/// A radio mode as N3FJP's mode field writes it: its sidebands and variants
/// fold into the mode a log records.
String n3fjpModeForRadioMode(String? mode) => switch (mode) {
  null => '',
  'CW-R' => 'CW',
  'FM-N' => 'FM',
  'AM-N' => 'AM',
  'RTTY-LSB' || 'RTTY-USB' => 'RTTY',
  'DATA-USB' || 'DATA-LSB' || 'DATA-FM' => 'DATA',
  _ => mode,
};

/// The contest class of a mode N3FJP's mode field writes, for `MODETEST`.
String n3fjpModeTest(String mode) => switch (superModeForMode(mode)) {
  'CW' => 'CW',
  'Phone' => 'PH',
  _ => mode.isEmpty ? '' : 'DIG',
};

/// The app's name for a mode N3FJP or one of its clients writes, or null
/// for none. N3FJP says `DATA` or `DIG` for the data sideband; anything
/// else is already the app's word (`SSB`, `CW`, `FT8`), which
/// [radioModeForAppMode] turns into a radio's.
///
/// [modeTest] stands in when the mode field is empty: N3FJP writes its
/// contest class even where a program leaves the mode blank.
String? appModeForN3fjpMode(String? mode, {String? modeTest}) {
  final upper = mode?.trim().toUpperCase() ?? '';
  if (upper.isEmpty) {
    return switch (modeTest?.trim().toUpperCase()) {
      'CW' => 'CW',
      'PH' => 'SSB',
      'DIG' => 'DATA-USB',
      _ => null,
    };
  }
  return switch (upper) {
    'DATA' || 'DIG' || 'PKTUSB' || 'USB-D' => 'DATA-USB',
    _ => upper,
  };
}
