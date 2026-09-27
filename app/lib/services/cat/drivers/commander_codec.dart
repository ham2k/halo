// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// DXLab Commander's TCP messages, as its "Commander TCPIP Messages" document
// (2019-07-11) specifies them.
//
// Everything on the wire is ADIF field syntax, `<name:length>value`, so a
// field is self-delimiting and needs no terminator. A request is two fields,
// the command and its parameters, the parameters themselves fields:
//
//   <command:10>CmdSetFreq<parameters:17><xcvrfreq:5>21230
//
// and an answer is one field named after what it reports:
//
//   <CmdFreq:10>14,010.500
//
// Frequencies are kHz. What Commander SENDS comes in a fixed form from
// `CmdGetFreq` (comma thousands, period decimal) and in the machine's locale
// from `CmdSendFreq`; what it READS is always in the locale. So a set
// written with a period reaches a comma-locale Commander a thousand times
// off, and the locale's separator can only be learned from `CmdSendFreq`.

/// `<name:length>value`.
String commanderField(String name, String value) => '<$name:${value.length}>$value';

/// One request: [command] with its [parameters], already in field syntax.
String commanderMessage(String command, [String parameters = '']) => commanderField('command', command) + commanderField('parameters', parameters);

final _fieldHeader = RegExp(r'<([^:<>]+):(\d+)(?::[^<>]*)?>');

/// Far past any real field. A header claiming more is not a header: waiting
/// for its value would hold up every answer behind it.
const _maxFieldLength = 1024;

/// The first complete field in [pending] — how many characters it and
/// anything before it take, its name and its value — or null while it is
/// still arriving. Text before the first `<` is skipped; a `<…>` that is not
/// a field header — including one claiming an impossible length — is skipped
/// with it.
({int consumed, String name, String value})? takeCommanderField(String pending) {
  var searchFrom = 0;
  while (true) {
    final open = pending.indexOf('<', searchFrom);
    if (open < 0) return null;
    final close = pending.indexOf('>', open);
    if (close < 0) return null;
    final header = _fieldHeader.matchAsPrefix(pending, open);
    if (header == null || header.end != close + 1) {
      searchFrom = open + 1;
      continue;
    }
    final length = int.tryParse(header.group(2)!);
    if (length == null || length > _maxFieldLength) {
      searchFrom = open + 1;
      continue;
    }
    if (pending.length < header.end + length) return null;
    return (consumed: header.end + length, name: header.group(1)!, value: pending.substring(header.end, header.end + length));
  }
}

final _fixedFormKHz = RegExp(r'^(\d{1,3}(,\d{3})*)?\.\d+$');

/// kHz from a `CmdGetFreq` answer (`14,010.500`), or null for none —
/// Commander answers `.000` when the radio has not reported one. Only the
/// fixed form is read: a locale-form `CmdSendFreq` answer (`14.074,000`)
/// landing on this question out of step would otherwise read as 14.074 kHz.
double? commanderKHz(String value) {
  final text = value.trim();
  if (!_fixedFormKHz.hasMatch(text)) return null;
  final kHz = double.tryParse(text.replaceAll(',', ''));
  return kHz != null && kHz > 0 ? kHz : null;
}

/// The decimal separator of a `CmdSendFreq` answer, which Commander writes
/// in the machine's locale (`14.010,500` in Germany), or null when it cannot
/// be told.
///
/// The document shows three decimals, and nothing captured confirms it, so
/// the last separator is taken as the decimal only where it cannot be a
/// thousands separator: a DIFFERENT separator comes before it, or the digits
/// before it are none (`.000`) or more than a thousands group holds. A
/// `14,010` or a `1,296,100` could be either, and is not guessed at.
String? commanderDecimalSeparator(String localeValue) {
  final value = localeValue.trim();
  final match = RegExp(r'^([0-9]*)(.*?)([^0-9])[0-9]+$').firstMatch(value);
  if (match == null) return null;
  final lead = match.group(1)!;
  final between = match.group(2)!;
  final separator = match.group(3)!;
  if (between.split('').any((c) => !'0123456789'.contains(c) && c != separator)) return separator;
  if (lead.isEmpty || lead.length > 3) return separator;
  return null;
}

/// [kHz] as Commander reads `xcvrfreq`: no separator at all for a whole
/// number, which reads the same in every locale, and otherwise [decimal]
/// before at most three decimals. With no [decimal] known, the nearest whole
/// kHz.
String commanderFrequency(double kHz, {required String? decimal}) {
  if (decimal == null) return '${kHz.round()}';
  final hz = (kHz * 1000).round();
  final whole = hz ~/ 1000;
  final fraction = hz % 1000;
  if (fraction == 0) return '$whole';
  return '$whole$decimal${fraction.toString().padLeft(3, '0').replaceFirst(RegExp(r'0+$'), '')}';
}

/// App modes against Commander's, where they differ. Commander's whole list
/// is AM, CW, CW-R, DATA-L, DATA-U, FM, LSB, USB, RTTY, RTTY-R and WBFM.
const commanderModesByAppMode = <String, String>{'DATA-USB': 'DATA-U', 'DATA-LSB': 'DATA-L', 'RTTY-LSB': 'RTTY', 'RTTY-USB': 'RTTY-R', 'WFM': 'WBFM'};

final _appModesByCommanderMode = {for (final e in commanderModesByAppMode.entries) e.value: e.key};

/// Commander's name for an app mode, or null for one it has no name for —
/// Commander ignores a mode outside its list, so nothing is sent.
String? commanderModeForAppMode(String mode) {
  final upper = mode.toUpperCase();
  final name = commanderModesByAppMode[upper] ?? upper;
  return const {'AM', 'CW', 'CW-R', 'DATA-L', 'DATA-U', 'FM', 'LSB', 'USB', 'RTTY', 'RTTY-R', 'WBFM'}.contains(name) ? name : null;
}

String appModeForCommanderMode(String name) {
  final upper = name.trim().toUpperCase();
  return _appModesByCommanderMode[upper] ?? upper;
}
