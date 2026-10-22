// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Ten-Tec's Orion command set, as the Orion (565), the Orion II (566) and
// the Eagle (599) speak it. Plain text, one command per line, every line
// ending in a carriage return:
//
//     *AF14074000<CR>    a set
//     ?AF<CR>            a query
//     @AF14074000<CR>    its answer
//
// Answers name what they answer, so a reply can be read without knowing
// which question it belongs to. Refusals are the exception that shapes the
// driver: the Orion's `Z!AF` names the command it refused, the Eagle's bare
// `Z` does not.
//
// PROVENANCE: Ten-Tec's "Orion Model 565 Programmer's Reference Guide"
// Rev 1.2 (firmware 1.367 and later), the "Orion/Orion II Users Manual
// Addendum, Firmware Version V3" (part 74474), and the "Eagle Model 599
// Programmers Reference Guide" Rev 1.001 (firmware 1.689 and later). Nothing
// here is read from Hamlib or any other GPL implementation.
//
// NOT VERIFIED AGAINST HARDWARE. What the guides leave open is marked
// UNVERIFIED where it is decided.
//
// Pure: it builds and parses text and knows nothing about ports or timers.

import 'dart:math' as math;

import 'cw_send_queue.dart' show cwCharacterEnds, cwDuration, morseElements;

/// Which of the two command sets a radio speaks.
///
/// The Eagle's guide calls its set "for the most part" the Orion's, and the
/// differences are all subtractions or narrowings — so one codec, with the
/// narrowings asked of the dialect rather than spread through the driver.
enum TenTecDialect {
  /// The Orion and Orion II, which share one guide: two receivers, either
  /// on either VFO, and a keyer the serial port can send text through.
  orion,

  /// The Eagle: one receiver, always on VFO A, and no CW over CAT.
  eagle;

  /// The dialect a stored config names, or null for one that names none.
  static TenTecDialect? fromConfig(dynamic raw) => switch (raw) {
    'orion' => orion,
    'eagle' => eagle,
    _ => null,
  };

  /// The app's modes and the codes `*RMM` takes for them.
  ///
  /// The Eagle has no lower CW: its guide says a `3` is accepted and turned
  /// into upper CW, so offering CW-R would be offering a mode the radio
  /// silently replaces. It has no FSK at all.
  Map<String, String> get modeCodes => switch (this) {
    orion => const {'USB': '0', 'LSB': '1', 'CW': '2', 'CW-R': '3', 'AM': '4', 'FM': '5', 'RTTY': '6'},
    eagle => const {'USB': '0', 'LSB': '1', 'CW': '2', 'AM': '4', 'FM': '5'},
  };

  /// The app's mode for an `@RMM` code, or null for one this dialect does
  /// not list. An Eagle answering `3` is read as the CW its guide says it
  /// switches to.
  String? modeFor(String code) => switch ((this, code)) {
    (_, '0') => 'USB',
    (_, '1') => 'LSB',
    (_, '2') => 'CW',
    (orion, '3') => 'CW-R',
    (eagle, '3') => 'CW',
    (_, '4') => 'AM',
    (_, '5') => 'FM',
    (orion, '6') => 'RTTY',
    _ => null,
  };

  /// The widest receive filter `*RMF` takes: the Orion's DSP builds 100 Hz
  /// to 6 kHz, the Eagle's to 15 kHz.
  int get maxFilterHz => this == orion ? 6000 : 15000;

  /// Whether `*RMP` sets the passband shift. The Eagle's is its front-panel
  /// knob's alone; its guide documents the query and no set.
  bool get canSetPassbandShift => this == orion;

  /// Whether the main receiver can be on VFO B. The Eagle's guide: "VFO A is
  /// always the receive frequency".
  bool get mainReceiverFollowsAssignment => this == orion;

  /// Whether the radio keys CW from text (`/c`) and sets its keyer's speed
  /// (`*CS`). The Orion's guide added both at firmware 1.366; the Eagle's
  /// documents neither.
  bool get keysCw => this == orion;
}

/// What the radio's serial port runs at. Fixed on both: the Orion's guide
/// says its interface "parameters are fixed at 57,600 baud", and the Eagle's
/// gives the same figure for its USB serial port.
const tenTecBaudRate = 57600;

/// The narrowest receive filter either dialect builds.
const tenTecMinFilterHz = 100;

/// How far the Orion's passband tuning reaches either side, in Hz.
const tenTecMaxPassbandShiftHz = 8000;

/// The keyer speeds the Orion's `*CS` takes, inclusive.
const tenTecKeyerSpeedRange = (min: 10, max: 60);

/// The highest output either radio is rated for. `*TP` takes 0-100 on both:
/// watts on the Eagle by its guide, percent on the Orion — which, for a
/// 100 W radio, is the same number.
const tenTecMaxWatts = 100;

// ---------------------------------------------------------------- commands

const _cr = '\r';

/// A query: `?` and the command's name.
String tenTecQuery(String name) => '?$name$_cr';

/// Tunes VFO [vfo] (`A` or `B`) to [hz], or null for a frequency the
/// command cannot carry.
///
/// Sent as Hz in eight digits, zero-padded — the form the Eagle's guide
/// shows (`*BF01403000` for 1.403 MHz) and the Orion's describes ("may be
/// specified in Hz or MHz"). Never the MHz form: a frequency with a decimal
/// point runs past the eight characters the Eagle reads.
String? tenTecSetFrequency(String vfo, int hz) {
  if (hz <= 0 || hz > 99999999) return null;
  return '*${vfo}F${hz.toString().padLeft(8, '0')}$_cr';
}

/// Puts the main receiver in [mode], or null for a mode [dialect] has no
/// code for.
String? tenTecSetMode(TenTecDialect dialect, String mode) {
  final code = dialect.modeCodes[mode];
  return code == null ? null : '*RMM$code$_cr';
}

/// Sets transmit power, 0-100 — see [tenTecMaxWatts].
String tenTecSetPower(num watts) => '*TP${watts.round().clamp(0, tenTecMaxWatts)}$_cr';

/// Sets the main receiver's filter width, clamped to what [dialect] builds.
///
/// On the Eagle this takes the width away from the front panel: its guide
/// says the BW knob is ignored from then until the radio is power cycled.
/// Only ever an operator's explicit change for that reason.
String tenTecSetFilterWidth(TenTecDialect dialect, int hz) => '*RMF${hz.clamp(tenTecMinFilterHz, dialect.maxFilterHz)}$_cr';

/// Sets the Orion's main receiver passband shift, clamped to its range.
String tenTecSetPassbandShift(int hz) => '*RMP${hz.clamp(-tenTecMaxPassbandShiftHz, tenTecMaxPassbandShiftHz)}$_cr';

/// Points the main receiver, sub receiver and transmitter at VFOs — `*KVAAA`
/// is everything on A, out of split. The Eagle takes only A for the two
/// receivers and ignores the second.
String tenTecSetVfoAssignment({String mainRx = 'A', String subRx = 'A', String tx = 'A'}) => '*KV$mainRx$subRx$tx$_cr';

/// Keys (`*TK`) or unkeys (`*TU`). Both radios stay keyed until told
/// otherwise — the Eagle's guide: "until *TU or power reset".
String tenTecPtt(bool on) => on ? '*TK$_cr' : '*TU$_cr';

/// Sets the Orion's keyer speed, clamped to [tenTecKeyerSpeedRange].
String tenTecSetKeyerSpeed(int wpm) => '*CS${wpm.clamp(tenTecKeyerSpeedRange.min, tenTecKeyerSpeedRange.max)}$_cr';

/// What `/c` sends for each character the app keys, from the Orion guide's
/// table. Letters go lowercase, as its examples write them (`/b`), because
/// its commands are case-sensitive and the guide shows no uppercase form.
///
/// `-` and `@` are missing on purpose: [morseElements] has them and the
/// Orion's table does not, and what the radio does with a character it has
/// no code for is undocumented.
String? tenTecCwCharacter(String char) {
  if (char.length != 1) return null;
  final lower = char.toLowerCase();
  if (RegExp(r'^[a-z0-9]$').hasMatch(lower)) return '/$lower$_cr';
  return const {'?', '.', ',', '/', '=', '+'}.contains(char) ? '/$char$_cr' : null;
}

/// [text] without the characters [tenTecCwCharacter] has no command for,
/// before it is queued — so the progress shown and the pacing never count a
/// character the radio is not sent.
String tenTecCwText(String text) => text.split('').where((char) => char.trim().isEmpty || tenTecCwCharacter(char) != null).join();

/// When each character of [chunk] should START keying at [wpm], from the
/// chunk's start, with the command that keys it. [chunk] is already through
/// [tenTecCwText] and the queue's sanitizing, so every character has one.
///
/// The starts come from cw_send_queue.dart's own timing — a character starts
/// its own length before it ends — so they cannot drift from the pacing of
/// the chunks they sit in. Spaces start nothing: they are the gap before the
/// next character.
///
/// The Orion takes one character per command and its guide says nothing of
/// buffering, so the session writes each character at its own start rather
/// than all at once. A radio that buffers keys it the same; one that does
/// not would otherwise drop all but the first.
List<(Duration, String)> tenTecCwSchedule(String chunk, int wpm) {
  final chars = [
    for (final char in chunk.split(''))
      if (char == ' ' || morseElements.containsKey(char)) char,
  ];
  final ends = cwCharacterEnds(chunk, wpm);
  // cwDuration charges a trailing word gap; a character's own length is
  // without it.
  final wordGapMs = 7 * 1200 / wpm;
  return [
    for (var i = 0; i < chars.length; i++)
      if (chars[i] != ' ')
        (Duration(milliseconds: (ends[i].inMilliseconds - cwDuration(chars[i], wpm).inMilliseconds + wordGapMs).round()), tenTecCwCharacter(chars[i])!),
  ];
}

// ----------------------------------------------------------------- replies

/// One line from the radio, read.
sealed class TenTecReply {
  const TenTecReply();
}

/// `@AF`/`@BF`: where VFO [vfo] is tuned.
class TenTecFrequency extends TenTecReply {
  final String vfo;
  final int hz;
  const TenTecFrequency(this.vfo, this.hz);
}

/// `@KV`: which VFO the main receiver, the sub receiver and the transmitter
/// are on. Null for the Orion's `N`, no VFO at all.
class TenTecVfoAssignment extends TenTecReply {
  final String mainRx;
  final String? subRx, tx;
  const TenTecVfoAssignment(this.mainRx, this.subRx, this.tx);
}

/// `@RMM`: the main receiver's mode code — see [TenTecDialect.modeFor].
class TenTecMode extends TenTecReply {
  final String code;
  const TenTecMode(this.code);
}

/// `@RMF`: the main receiver's filter width, Hz.
class TenTecFilterWidth extends TenTecReply {
  final int hz;
  const TenTecFilterWidth(this.hz);
}

/// `@RMP`: the main receiver's passband shift, Hz.
class TenTecPassbandShift extends TenTecReply {
  final int hz;
  const TenTecPassbandShift(this.hz);
}

/// `@TP`: the transmit power setting, 0-100 — see [tenTecMaxWatts].
class TenTecPower extends TenTecReply {
  final int value;
  const TenTecPower(this.value);
}

/// `@SRM`: the radio is receiving, and its main S-meter reads [raw].
///
/// UNVERIFIED unit, which is why nothing reports this as a meter. The
/// Eagle's guide says "n in dbm" beside an example of `16`, which no receiver
/// reads in dBm; the Orion's calls it "an s-meter reading of 10". Whatever
/// the number is, the answer's SHAPE says the radio is not transmitting.
class TenTecReceiving extends TenTecReply {
  final int raw;
  const TenTecReceiving(this.raw);
}

/// `@STF`: the radio is transmitting, with these readings.
class TenTecTransmitting extends TenTecReply {
  final double forwardWatts;
  final double reflectedWatts;

  /// The radio's own figure where it gives one (the Orion), else worked out
  /// from the two powers.
  final double? swr;

  const TenTecTransmitting(this.forwardWatts, this.reflectedWatts, this.swr);
}

/// `@CK`: whether the Orion's internal keyer is on — `/c` is ignored while
/// it is off.
class TenTecKeyerEnabled extends TenTecReply {
  final bool on;
  const TenTecKeyerEnabled(this.on);
}

/// `@CS`: the Orion's keyer speed, WPM.
class TenTecKeyerSpeed extends TenTecReply {
  final int wpm;
  const TenTecKeyerSpeed(this.wpm);
}

/// A line that names the radio rather than answering a reading: the Eagle's
/// `599 Ver 01.736` version answer, or the `ORION START` / `EAGLE START`
/// banner either sends as it initialises.
class TenTecIdentity extends TenTecReply {
  final String text;
  const TenTecIdentity(this.text);
}

/// `Z`: something was refused. [command] is what the Orion names (`Z!AF`) —
/// or, after a VFO assignment, which VFO was out of range — and null for
/// the Eagle's bare `Z`, which says nothing about which.
class TenTecRefusal extends TenTecReply {
  final String? command;
  const TenTecRefusal(this.command);
}

/// An answer to a command this codec reads whose value it cannot: `@AF`
/// with no digits, a `@KV` of the wrong shape. Not null, which is a line
/// nobody asked about — this one answers a question, and dropped silently it
/// would read as the radio not answering at all.
class TenTecUnreadable extends TenTecReply {
  final String text;
  const TenTecUnreadable(this.text);
}

final _signedInt = RegExp(r'^[+-]?\d+$');
final _digits = RegExp(r'^\d+$');
final _vfoAssignment = RegExp(r'^([AB])([ABN])([ABN])$');
final _receiving = RegExp(r'^(\d+)(?:S\d+)?$');
final _transmitting = RegExp(r'^(\d+(?:\.\d+)?)R(\d+(?:\.\d+)?)(?:S(\d+(?:\.\d+)?))?$');

/// [line] as [dialect] means it, or null for a line this codec does not
/// read — an answer to a query the driver never asks, or noise.
/// [TenTecUnreadable] for one it should read and cannot.
TenTecReply? parseTenTecReply(String line, TenTecDialect dialect) {
  // Trimmed: both start banners lead with spaces (the Eagle's guide counts
  // two), and a CR-LF peer leaves nothing else.
  final text = line.trim();
  if (text.isEmpty) return null;

  if (text.startsWith('Z')) {
    final named = text.startsWith('Z!') ? text.substring(2).trim() : '';
    return TenTecRefusal(named.isEmpty ? null : named);
  }

  if (!text.startsWith('@')) {
    return text.contains(' Ver ') || text.endsWith('START') ? TenTecIdentity(text) : null;
  }

  final body = text.substring(1);
  String? after(String prefix) => body.startsWith(prefix) ? body.substring(prefix.length) : null;
  final unreadable = TenTecUnreadable(text);

  for (final vfo in const ['A', 'B']) {
    final value = after('${vfo}F');
    if (value != null) return _digits.hasMatch(value) ? TenTecFrequency(vfo, int.parse(value)) : unreadable;
  }

  if (after('KV') case final value?) {
    final match = _vfoAssignment.firstMatch(value);
    if (match == null) return unreadable;
    String? vfo(String letter) => letter == 'N' ? null : letter;
    return TenTecVfoAssignment(match[1]!, vfo(match[2]!), vfo(match[3]!));
  }

  if (after('RMM') case final value?) return value.length == 1 ? TenTecMode(value) : unreadable;

  int? integer(String value) => _signedInt.hasMatch(value) ? int.parse(value) : null;
  for (final (prefix, build) in <(String, TenTecReply Function(int))>[
    ('RMF', TenTecFilterWidth.new),
    ('RMP', TenTecPassbandShift.new),
    ('TP', TenTecPower.new),
    ('CS', TenTecKeyerSpeed.new),
  ]) {
    if (after(prefix) case final value?) return integer(value) == null ? unreadable : build(integer(value)!);
  }
  if (after('CK') case final value?) return value == '0' || value == '1' ? TenTecKeyerEnabled(value == '1') : unreadable;

  if (after('SRM') case final value?) {
    final match = _receiving.firstMatch(value);
    return match == null ? unreadable : TenTecReceiving(int.parse(match[1]!));
  }

  if (after('STF') case final value?) {
    final match = _transmitting.firstMatch(value);
    if (match == null) return unreadable;
    final forward = double.parse(match[1]!);
    // The Eagle sends reflected power in tenths of a watt (`@STF99R10` is
    // "1.0 watt reflected") and no SWR; the Orion sends watts and its SWR
    // (`@STF50R2S1.1`).
    final reflected = dialect == TenTecDialect.eagle ? double.parse(match[2]!) / 10 : double.parse(match[2]!);
    final stated = match[3] == null ? null : double.parse(match[3]!);
    return TenTecTransmitting(forward, reflected, stated ?? tenTecSwr(forward, reflected));
  }

  return null;
}

/// The SWR a forward and reflected power pair implies, or null where it is
/// not a finite ratio — no forward power, or all of it coming back.
double? tenTecSwr(double forwardWatts, double reflectedWatts) {
  if (forwardWatts <= 0 || reflectedWatts < 0 || reflectedWatts >= forwardWatts) return null;
  final rho = math.sqrt(reflectedWatts / forwardWatts);
  return (1 + rho) / (1 - rho);
}
