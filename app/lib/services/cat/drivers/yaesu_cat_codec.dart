// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Yaesu CAT: an ASCII command protocol, documented per-radio (see the FT-891
// CAT Operation Reference Book). Unlike Icom's CI-V, frequency is a plain
// zero-padded decimal Hz string, not BCD. Every command ends with ";" —
// there is no other framing.
//
// Pure: it builds and parses strings and knows nothing about sockets,
// serial ports or timers. The `;` framing itself is shared with Kenwood and
// lives in cat_ascii_codec.dart; this file is only what Yaesu puts inside it. Ported from app-polo's YaesuCatProtocol.js, which
// was the highest-confidence code on that branch precisely because it had
// no I/O in it. See docs/design/cat.md on why the codec is shared while
// the glue around it is not.

export 'cat_ascii_codec.dart' show AsciiCatCommand, AsciiCatFramer, parseAsciiCatCommand;

/// Auto-Information: the radio pushes a status line whenever the VFO changes,
/// instead of us polling for it. Yaesu's CAT manual doesn't spell out the
/// unsolicited format beyond "reports change of status", which is why
/// [Ft891Session] polls as well rather than trusting this alone.
///
/// Yaesu's, not shared: Kenwood spells the same command with a different
/// level (see kenwood_cat_codec.dart).
String buildAutoInformationCommand(bool on) => 'AI${on ? 1 : 0};';

/// P2 mode digit, per the FT-891 CAT manual's MD/MR tables. 'A' is
/// unused/reserved, which is why the letters skip it.
const yaesuModeCodes = <String, String>{
  'LSB': '1',
  'USB': '2',
  'CW': '3',
  'FM': '4',
  'AM': '5',
  'RTTY-LSB': '6',
  'CW-R': '7',
  'DATA-LSB': '8',
  'RTTY-USB': '9',
  'FM-N': 'B',
  'DATA-USB': 'C',
  'AM-N': 'D',
};

final Map<String, String> _modeNamesByCode = {for (final entry in yaesuModeCodes.entries) entry.value: entry.key};

String? modeNameForCode(String code) => _modeNamesByCode[code];

String? codeForModeName(String? name) => name == null ? null : yaesuModeCodes[name.toUpperCase()];

/// How many digits of Hz the line's `FA` and `IF` carry: nine on the FT-891
/// and every radio after it (P1 range 000030000–056000000, i.e. 30 kHz–56
/// MHz), eight on the FT-450 and the generation before the FT-891 (FT-950,
/// FTDX1200, FT-2000, FTDX3000, FTDX5000) — hamlib's `newcat.c` tells the
/// two apart by the `IF` answer's length. A width is a fact about the radio,
/// never guessed from an answer: an eight-digit read on a nine-digit radio
/// is a frame that lost a byte, not a frequency.
const yaesuFrequencyDigits = 9;

/// Hz, zero-padded to [digits].
String encodeFrequencyHz(int freqHz, {int digits = yaesuFrequencyDigits}) {
  final padded = freqHz.abs().toString().padLeft(digits, '0');
  // Keep the LAST [digits]: a value too large to express is truncated the
  // same way the radio would read it, rather than producing an over-long
  // command the radio silently rejects.
  return padded.substring(padded.length - digits);
}

String buildSetFrequencyCommand(int freqHz, {int digits = yaesuFrequencyDigits}) => 'FA${encodeFrequencyHz(freqHz, digits: digits)};';

String buildReadFrequencyCommand() => 'FA;';

/// Null for a mode the radio has no code for — the caller sends nothing
/// rather than a malformed command.
String? buildSetModeCommand(String? mode) {
  final code = codeForModeName(mode);
  return code == null ? null : 'MD0$code;';
}

String buildReadModeCommand() => 'MD0;';

/// `PC` is a 3-digit level, 005-100 per the FT-891 CAT manual — RF power
/// output in watts directly, unlike Kenwood's implied-watts `PC`, which the
/// FT-891's own manual states explicitly. NOT captured against the bench
/// FT-891 this driver's frequency/mode path was verified on — see
/// ft891_driver.dart's own notes on what has and hasn't met hardware.
/// Clamped, not truncated: a value outside the documented range is more
/// likely operator error than a command the radio would parse differently.
String buildSetPowerCommand(num watts) => 'PC${watts.round().clamp(5, 100).toString().padLeft(3, '0')};';

String buildReadPowerCommand() => 'PC;';

/// `PC100;` → 100. Null unless it's exactly three digits.
int? parsePowerParams(String params) => RegExp(r'^\d{3}$').hasMatch(params) ? int.tryParse(params) : null;

/// The FT-2000's and FTDX5000's `PC`: a level 000-255, not watts. Their CAT
/// manuals give the range and no unit; hamlib's `newcat` reads it as a
/// fraction of the radio's rated output, and so does this — unverified
/// against a radio. The FT-891 form would ask a 200 W radio for 39% when
/// the operator picked 100 W.
///
/// The rated output by the radio's own `ID` answer, because one catalogue
/// entry covers the 100 W FT-2000 and the 200 W FT-2000D.
const yaesuRatedWattsById = <String, int>{'0251': 100, '0252': 200, '0362': 200};

/// Clamped to 5 W-[ratedWatts]: the floor of the line's watts form, since
/// these manuals state none.
String buildSetRelativePowerCommand(num watts, int ratedWatts) => 'PC${(watts.clamp(5, ratedWatts) * 255 / ratedWatts).round().toString().padLeft(3, '0')};';

/// `255` on a 200 W radio → 200. Null unless it's three digits up to 255.
int? parseRelativePowerParams(String params, int ratedWatts) {
  final level = parsePowerParams(params);
  return level == null || level > 255 ? null : (level * ratedWatts / 255).round();
}

/// The FTX-1's `PC`, which names the unit it drives before the level: `1`
/// the field head (0.5-10 W, tenths written as `PC11.5;`), `2` the SPA-1
/// amplifier (5-100 W). From hamlib's FTX-1 backend, not a capture. The
/// FT-891 form above neither parses these answers nor builds a command the
/// radio accepts.
///
/// `1010` → field head, 10 W; `10.5` → field head, 0.5 W; `2100` → SPA-1,
/// 100 W. Null for anything else.
({int head, num watts})? parseHeadPowerParams(String params) {
  final match = RegExp(r'^([12])(\d{3}|\d\.\d)$').firstMatch(params);
  if (match == null) return null;
  return (head: int.parse(match[1]!), watts: num.parse(match[2]!));
}

/// Clamped to [head]'s range, as [buildSetPowerCommand] is to the FT-891's.
/// The field head takes whole watts zero-padded and anything finer as a
/// tenth; the SPA-1 takes whole watts only.
String buildSetHeadPowerCommand(int head, num watts) {
  if (head == 2) return 'PC2${watts.round().clamp(5, 100).toString().padLeft(3, '0')};';
  final tenths = (watts.clamp(0.5, 10) * 10).round();
  return tenths % 10 == 0 ? 'PC1${(tenths ~/ 10).toString().padLeft(3, '0')};' : 'PC1${(tenths / 10).toStringAsFixed(1)};';
}

/// `AC;` reads the antenna tuner. The answer is `ACP1P2P3;`: P1P2 a fixed
/// `00`, P3 `0` tuner off (bypassed), `1` tuner on (in line), `2` tuning.
/// On the FT-891, which has no tuner of its own, it is the external FC-50 or
/// ATAS the radio drives. From the CAT manuals, not a capture.
String buildReadTunerCommand() => 'AC;';

/// `AC001;` puts the tuner in line, `AC000;` bypasses it. Never P3 `2`,
/// which transmits and is [buildStartTuneCommand]'s.
String buildSetTunerCommand({required bool inline}) => 'AC00${inline ? 1 : 0};';

/// `AC002;` starts a tune — a carrier on the air.
String buildStartTuneCommand() => 'AC002;';

/// `001` → 1, the P3 of [buildReadTunerCommand]'s answer. Null for anything
/// but `00` followed by `0`, `1` or `2`.
int? parseTunerParams(String params) => RegExp(r'^00[012]$').hasMatch(params) ? int.parse(params[2]) : null;

/// `ID;` asks which radio is on the line; the answer is `IDnnnn;`, a number
/// each CAT manual gives its own radio. Read-only on every one of them.
String buildReadIdCommand() => 'ID;';

/// `0650` → `0650`. Null unless it's exactly four digits.
String? parseIdParams(String params) => RegExp(r'^\d{4}$').hasMatch(params) ? params : null;

/// The modes whose receive filter `SH` reads as a width this app can place.
/// RTTY and DATA are left out: where their passband sits depends on a mark
/// frequency or a DATA menu the session does not read.
enum YaesuWidthGroup { ssb, cw }

YaesuWidthGroup? yaesuWidthGroupFor(String? mode) => switch (mode) {
  'USB' || 'LSB' => YaesuWidthGroup.ssb,
  'CW' || 'CW-R' => YaesuWidthGroup.cw,
  _ => null,
};

/// One group's `SH` table: index → Hz.
///
/// Where the radio's NARROW switch (`NA`) splits the table, [narrow] and
/// [wide] are the run of indices offered in each state, and `00` means that
/// state's default width. Where it does not, `00` follows the roofing
/// filter, which nothing here reads, and is not a width at all.
class YaesuWidthTable {
  final Map<int, int> widths;
  final ({int first, int last, int defaultHz})? narrow, wide;
  const YaesuWidthTable(this.widths, {this.narrow, this.wide});

  /// Hz for [index]; null where it cannot be known — `00` without a split,
  /// or with one while the NARROW state is unknown.
  int? widthHz(int index, {bool? narrowOn}) {
    if (index != 0) return widths[index];
    if (narrowOn == null) return null;
    return (narrowOn ? narrow : wide)?.defaultHz;
  }

  /// The index whose width is nearest [hz], the narrower on a tie. Only
  /// indices the radio offers in its present NARROW state, so a set never
  /// has to move the switch; null where that state is unknown. Never `00`:
  /// a set names a width.
  int? nearestIndex(int hz, {bool? narrowOn}) {
    final split = narrowOn == null ? null : (narrowOn ? narrow : wide);
    if (narrow != null && split == null) return null;
    int? best;
    for (final MapEntry(key: index, value: width) in widths.entries) {
      if (split != null && (index < split.first || index > split.last)) continue;
      if (best == null || (width - hz).abs() < (widths[best]! - hz).abs()) best = index;
    }
    return best;
  }
}

/// How `IS` (IF shift) is laid out: after P1, the FT-891 has an on/off digit,
/// the FTDX10 and FT-710 a fixed `0`, the FT-991 and FT-991A nothing.
enum YaesuShiftForm { onOff, fixedZero, bare }

/// Everything about one radio's receive filter over CAT: its `SH` tables and
/// the shape of its `SH` and `IS` commands.
class YaesuWidthProfile {
  final YaesuWidthTable ssb, cw;

  /// What a set puts before the two index digits.
  final String setPrefix;

  /// `SH` answer params: P1 and the index, with an on/off or fixed digit
  /// between them where [setPrefix] has one.
  final int widthParamsLength;

  final YaesuShiftForm shiftForm;

  const YaesuWidthProfile({required this.ssb, required this.cw, required this.setPrefix, required this.widthParamsLength, required this.shiftForm});

  /// Whether `NA` decides what `SH` means, and so has to be read with it.
  bool get readsNarrow => ssb.narrow != null || cw.narrow != null;

  YaesuWidthTable table(YaesuWidthGroup group) => switch (group) {
    YaesuWidthGroup.ssb => ssb,
    YaesuWidthGroup.cw => cw,
  };
}

/// The FT-891's and FT-991's (and FT-991A's) shared table, from their CAT
/// Operation Reference Books: one list of widths, NARROW offering the low
/// end and WIDE the high, overlapping by one index.
const _ft891SsbWidths = {
  1: 200, 2: 400, 3: 600, 4: 850, 5: 1100, 6: 1350, 7: 1500, 8: 1650, 9: 1800, 10: 1950, 11: 2100, //
  12: 2200, 13: 2300, 14: 2400, 15: 2500, 16: 2600, 17: 2700, 18: 2800, 19: 2900, 20: 3000, 21: 3200,
};
const _ft891CwWidths = {
  1: 50, 2: 100, 3: 150, 4: 200, 5: 250, 6: 300, 7: 350, 8: 400, 9: 450, 10: 500, //
  11: 800, 12: 1200, 13: 1400, 14: 1700, 15: 2000, 16: 2400, 17: 3000,
};
const _ft891SsbTable = YaesuWidthTable(_ft891SsbWidths, narrow: (first: 1, last: 9, defaultHz: 1500), wide: (first: 9, last: 21, defaultHz: 2400));
const _ft891CwTable = YaesuWidthTable(_ft891CwWidths, narrow: (first: 1, last: 10, defaultHz: 500), wide: (first: 10, last: 17, defaultHz: 2400));

/// The FTDX10's and FT-710's SSB table — the FTDX10's English and the
/// FT-710's Japanese CAT manual agree on it. hamlib's `newcat` gives both
/// radios the FTDX101's instead, which reads 2200/2300/2400 at 12-14 where
/// both manuals say 2250/2400/2450; the manuals are taken.
const _ftdx10SsbWidths = {
  1: 300, 2: 400, 3: 600, 4: 850, 5: 1100, 6: 1200, 7: 1500, 8: 1650, 9: 1800, 10: 1950, 11: 2100, 12: 2250, //
  13: 2400, 14: 2450, 15: 2500, 16: 2600, 17: 2700, 18: 2800, 19: 2900, 20: 3000, 21: 3200, 22: 3500, 23: 4000,
};

/// The FTDX10's CW table, which runs to 21; the FT-710's has no 3200 Hz and
/// stops at 20 — same indices to 18, different from there.
const _ftdx10CwWidths = {
  1: 50, 2: 100, 3: 150, 4: 200, 5: 250, 6: 300, 7: 350, 8: 400, 9: 450, 10: 500, 11: 600, //
  12: 800, 13: 1200, 14: 1400, 15: 1700, 16: 2000, 17: 2400, 18: 3000, 19: 3200, 20: 3500, 21: 4000,
};
const _ft710CwWidths = {
  1: 50, 2: 100, 3: 150, 4: 200, 5: 250, 6: 300, 7: 350, 8: 400, 9: 450, 10: 500, 11: 600, //
  12: 800, 13: 1200, 14: 1400, 15: 1700, 16: 2000, 17: 2400, 18: 3000, 19: 3500, 20: 4000,
};

/// FT-891: `SH0` + on/off + index. The manual does not say what index an
/// OFF answer means; hamlib writes the digit as `1` and reads the index
/// whatever it says, and so does this.
const _ft891Profile = YaesuWidthProfile(ssb: _ft891SsbTable, cw: _ft891CwTable, setPrefix: 'SH01', widthParamsLength: 4, shiftForm: YaesuShiftForm.onOff);

/// FT-991 and FT-991A: `SH0` + index, nothing between.
const _ft991Profile = YaesuWidthProfile(ssb: _ft891SsbTable, cw: _ft891CwTable, setPrefix: 'SH0', widthParamsLength: 3, shiftForm: YaesuShiftForm.bare);

const _ftdx10Profile = YaesuWidthProfile(
  ssb: YaesuWidthTable(_ftdx10SsbWidths),
  cw: YaesuWidthTable(_ftdx10CwWidths),
  setPrefix: 'SH00',
  widthParamsLength: 4,
  shiftForm: YaesuShiftForm.fixedZero,
);

const _ft710Profile = YaesuWidthProfile(
  ssb: YaesuWidthTable(_ftdx10SsbWidths),
  cw: YaesuWidthTable(_ft710CwWidths),
  setPrefix: 'SH00',
  widthParamsLength: 4,
  shiftForm: YaesuShiftForm.fixedZero,
);

/// By the radio's own `ID` answer rather than by catalogue entry: the line
/// shares one driver, an FT-710 has been run on the FT-891's entry, and the
/// two radios' tables disagree at most indices — a table picked by entry
/// would show and set the wrong filter there.
///
/// Absent, and so read as having no passband: the FT-450 and FT-450D, the
/// FTX-1 (whose `SH` hamlib's own backend calls "WIDTH/IF SHIFT", with no
/// manual here to say what that means), and anything else.
const yaesuWidthProfilesById = <String, YaesuWidthProfile>{
  '0650': _ft891Profile,
  '0570': _ft991Profile,
  '0670': _ft991Profile,
  '0761': _ftdx10Profile,
  '0800': _ft710Profile,
};

/// The radio's own antenna ports that `AN` selects, by the radio's `ID`
/// answer, named as its CAT manual names them; port n is `AN0n`. One port
/// serves receive and transmit alike.
///
/// Only the FTDX101D and FTDX101MP, whose CAT manual has `AN`. The FT-891,
/// FT-991, FT-991A, FTDX10 and FT-710 manuals have no `AN` at all (hamlib's
/// `newcat` agrees, and adds the FT-450): one HF port, or the FT-991's HF/50
/// and 144/430 connectors, which follow the band and are not a choice. The
/// FTX-1, which hamlib gives `AN`, is absent: no manual here says what its
/// ports are.
///
/// ANT3 is left out though `AN03` selects it: menu ANT3 SELECT decides
/// whether it transmits, receives only, or pairs with ANT1 or ANT2 for
/// transmit, and the CAT manual and the operating manual disagree on that
/// menu's values — a port reported as both would be a transmit antenna the
/// radio may not be using.
const yaesuAntennaPortsById = <String, List<String>>{
  '0681': ['ANT1', 'ANT2'],
  '0682': ['ANT1', 'ANT2'],
};

/// `AN0;` reads the MAIN band's antenna; P1 `1` would be the SUB band's,
/// which no VFO here follows.
String buildReadAntennaCommand() => 'AN0;';

/// `AN0n;` selects port n for the MAIN band.
String buildSetAntennaCommand(int port) => 'AN0$port;';

/// `010` → 1: P1 the MAIN band, P2 the port 1-3, P4 a fixed `0`, as the
/// FTDX101's CAT manual lays the answer out. Null for anything else,
/// including the SUB band's answer.
int? parseAntennaParams(String params) => RegExp(r'^0[123]0$').hasMatch(params) ? int.parse(params[1]) : null;

/// `SH0;` reads the receive filter width.
String buildReadWidthCommand() => 'SH0;';

/// [index] in [profile]'s table, two digits after its prefix.
String buildSetWidthCommand(YaesuWidthProfile profile, int index) => '${profile.setPrefix}${index.toString().padLeft(2, '0')};';

/// The table index from an `SH` answer. Null unless it is exactly the
/// length [profile] answers in — a frame that lost a digit would otherwise
/// read as a different, valid index.
int? parseWidthParams(String params, YaesuWidthProfile profile) {
  if (params.length != profile.widthParamsLength || !RegExp(r'^0[01]?\d\d$').hasMatch(params)) return null;
  return int.parse(params.substring(params.length - 2));
}

/// `IS0;` reads the IF shift: ±Hz, 20 Hz steps.
String buildReadShiftCommand() => 'IS0;';

/// Hz from an `IS` answer, in [profile]'s layout. The FT-891's on/off digit
/// at `0` is the shift switched off, read as no shift — which is also the
/// digit hamlib writes for a zero shift. Null for anything else.
int? parseShiftParams(String params, YaesuWidthProfile profile) {
  final pattern = switch (profile.shiftForm) {
    YaesuShiftForm.onOff => RegExp(r'^0([01])([+-]\d{4})$'),
    YaesuShiftForm.fixedZero => RegExp(r'^0(0)([+-]\d{4})$'),
    YaesuShiftForm.bare => RegExp(r'^0()([+-]\d{4})$'),
  };
  final match = pattern.firstMatch(params);
  if (match == null) return null;
  if (profile.shiftForm == YaesuShiftForm.onOff && match[1] == '0') return 0;
  return int.parse(match[2]!);
}

/// `NA0;` reads the NARROW switch.
String buildReadNarrowCommand() => 'NA0;';

/// `01` → true, `00` → false. Null for anything else.
bool? parseNarrowParams(String params) => switch (params) {
  '01' => true,
  '00' => false,
  _ => null,
};

/// What a Yaesu answers a command it does not have: `?;`, naming neither the
/// command nor the reason. It never frames as an [AsciiCatCommand] — there
/// are no letters in it — and no answer [Ft891Session] asks for carries a
/// `?` of its own, so a `?` arriving at all is a refusal.
const yaesuRefusal = '?';

/// Asks whether the radio is transmitting.
///
/// READ ONLY — `TX1;`/`TX2;` would KEY the radio, so the bare `TX;` is the
/// only form this app ever sends. (The Kenwood line has no read form at
/// all, which is why its driver reads the flag out of `IF` instead.)
String buildReadTransmitStatusCommand() => 'TX;';

/// Also a playing memory's clock: a radio that unkeys itself at the end of
/// one does not always SAY so unprompted, so a voice play asks this every
/// second (see [Ft891Session]).
///
/// `TX0;` receiving, `TX1;` transmitting from the radio's own PTT, `TX2;`
/// transmitting because CAT asked. Null for anything else, which is a
/// radio that does not answer the command rather than one that is
/// receiving — the difference decides whether an antenna relay may move.
bool? parseTransmitStatusParams(String params) => switch (params.trim()) {
  '0' => false,
  '1' || '2' => true,
  _ => null,
};

/// The meter reads, by the numbers Yaesu's own CAT manuals give them.
///
/// The spec, for both radios this driver has met:
/// https://www.yaesu.com/Files/4CB893D7-1018-01AF-FA97E9E9AD48B50C/FT-891_CAT_OM_ENG_1909-C.pdf
/// https://www.yaesu.com/Files/4CB893D7-1018-01AF-FA97E9E9AD48B50C/FTDX10_CAT_OM_ENG_2308-F.pdf
///
/// They agree on the three that matter — 4 ALC, 5 PO, 6 SWR — and on a
/// reading of 0-255. What neither publishes, anywhere, is what that number
/// MEANS: there is no table from 0-255 to watts or to an SWR ratio. That
/// missing scale is why nothing here converts.
///
/// Reading a numbered meter is SAFE, unlike on a Kenwood: which meter the
/// front panel displays is a separate command (`MS`), so asking for one
/// here does not change what the operator is looking at. Only `RM0` and
/// `RM2` are tied to the panel — they read "whatever it is showing" — which
/// is why neither is ever asked for.
///
/// Worse than undocumented, the scale is per-RADIO. The technical
/// supplements align these meters in service mode, per band, on each
/// individual unit (`100W MTR 1.8` and its siblings), so a table taken off
/// one FTDX10 describes that FTDX10. Anything shipped from a capture is a
/// starting point, not a calibration. The raw values are captured
/// against a rig on the bench (see [Ft891Session]) so a real table can be
/// built from real readings, rather than a curve being invented and then
/// compared against an SWR threshold the operator is warned at.
const yaesuMeterAlc = 4;
const yaesuMeterPowerOut = 5;
const yaesuMeterSwr = 6;

/// DC input voltage — on the FTDX10, which has it; the FT-891's table stops
/// at 7 (ID) and answers this with nothing useful. Asked anyway during a
/// capture: a radio that does not have the meter simply does not answer,
/// and the alternative is a second capture pass to find out.
const yaesuMeterVdd = 8;

/// The meters a capture reads, in the order asked.
const yaesuCaptureMeters = [yaesuMeterPowerOut, yaesuMeterSwr, yaesuMeterAlc, yaesuMeterVdd];

String buildReadMeterCommand(int meter) => 'RM$meter;';

/// `RM5123;` → (meter: 5, level: 123).
///
/// TWO answer shapes, and this is exactly the kind of difference that makes
/// "the Yaesu line is all the same" wrong. The FT-891 answers
/// `RM P1 P2P2P2;`; the FTDX10 answers `RM P1 P2P2P2 P3P3P3;` with a P3 its
/// manual documents as fixed `000`. A parser that took only the shorter form
/// would read NOTHING from an FTDX10 — silently, since an unparsed answer
/// looks exactly like a radio that never replied.
///
/// The fixed tail is dropped rather than checked: it is documented as a
/// constant, so a radio that put something else there is telling us
/// something this parser has no way to interpret, and refusing the whole
/// reading over it would lose the part we do understand.
///
/// Null for anything else — including `RM0;`, which selects what the front
/// panel displays rather than answering a question.
({int meter, int level})? parseMeterParams(String params) {
  if (params.length != 4 && params.length != 7) return null;
  final meter = int.tryParse(params[0]);
  final level = int.tryParse(params.substring(1, 4));
  if (meter == null || level == null) return null;
  return (meter: meter, level: level);
}

/// `KS;` reads the keyer speed; the answer is `KSnnn;`, 004-060 WPM on the
/// FTDX10 and FT-891 alike.
String buildReadKeyerSpeedCommand() => 'KS;';

const yaesuKeyerSpeedMin = 4;
const yaesuKeyerSpeedMax = 60;

String buildSetKeyerSpeedCommand(int wpm) => 'KS${wpm.clamp(yaesuKeyerSpeedMin, yaesuKeyerSpeedMax).toString().padLeft(3, '0')};';

/// `KS020;` → 20. Null unless it's exactly three digits.
int? parseKeyerSpeedParams(String params) => RegExp(r'^\d{3}$').hasMatch(params) ? int.tryParse(params) : null;

/// Yaesu CAT has no "key this text" command. What it has is five text
/// memories the operator can also fill from the front panel — `KM` writes
/// one (up to [yaesuKeyerMemoryMaxChars]) and `KY` plays one back. Keying
/// a message from the app is therefore WRITE-THEN-PLAY through one memory
/// the app takes over, and the operator's own text in that slot is gone;
/// [yaesuAppKeyerMemory] is the last of the five so the four most people
/// fill first are left alone.
///
/// Not every radio has five, or fifty characters in each: the FT-450D has
/// three memories of forty (`KM1`–`KM3`, played by `KY6`–`KY8`, per its CAT
/// Operation Reference Book), and a `KM5` there writes nothing. So the slot
/// and the length are the catalogue entry's to name — see
/// `yaesuKeyerMemoryConfigKey` and `yaesuKeyerMemoryCharsConfigKey` — and
/// these are only the defaults, those of the radios that have five.
///
/// Playback has no stop command in the FT-891's manual, which is why
/// [Ft891Session.stopCw] can only stop QUEUING.
const yaesuAppKeyerMemory = 5;
const yaesuKeyerMemoryMaxChars = 50;

/// [text] must already be sanitized (cw_send_queue.dart) and no longer than
/// the radio's memory holds.
String buildWriteKeyerMemoryCommand(int memory, String text) => 'KM$memory$text;';

/// `KY6;`-`KYA;` play the TEXT memories 1-5 ("Message Keyer" in the manual's
/// words); `KY1;`-`KY5;` play the recorded-from-paddle ones, which are not
/// what `KM` writes.
String buildPlayKeyerMemoryCommand(int memory) => 'KY${(5 + memory).toRadixString(16).toUpperCase()};';

/// The FT-710's `KY`, which names the kind of memory before the channel:
/// `KY0n;` plays TEXT memory n, `KY1n;` the MESSAGE one (FT-710 CAT
/// Operation Reference Manual). Sent the line's `KYA;` it plays nothing.
String buildPlayKeyerMemoryByChannelCommand(int memory) => 'KY0$memory;';

/// The voice memories ("DVS" in the CAT manuals) across the line: five on
/// the FT-891, FT-710, FT-991A and FTDX10 alike. `PB` plays one and `LM`
/// records one, both with a fixed `0` ahead of the channel digit.
const yaesuVoiceMemoryCount = 5;

/// `PB` starts the DVS but does NOT key the transmitter — an unkeyed radio
/// plays the memory to the monitor only, and nothing goes on the air. The
/// caller keys first with [buildSetTxCommand]; see [Ft891Session.playVoiceMemory].
String buildPlayVoiceMemoryCommand(int n) => 'PB0${n.clamp(1, yaesuVoiceMemoryCount)};';

/// `TX1;` transmits under CAT ("RADIO TX OFF / CAT TX ON" in the manual's
/// P1 table), `TX0;` returns to receive. P1 2 is answer-only — the radio
/// saying its own PTT is down — so it is never sent.
String buildSetTxCommand(bool on) => 'TX${on ? 1 : 0};';

/// `PB00;` — stops playback.
String buildStopVoiceMemoryCommand() => 'PB00;';

/// `PB0;` — the answer, `PB0n;`, names the channel playing, or 0.
String buildReadVoicePlaybackCommand() => 'PB0;';

/// Starts recording into memory [n] — the same command sent again stops it,
/// which is why [buildStopVoiceRecordingCommand] exists: a stop that does not
/// have to know which channel was recording.
String buildRecordVoiceMemoryCommand(int n) => 'LM0${n.clamp(1, yaesuVoiceMemoryCount)};';

/// `LM00;` — recording stop.
String buildStopVoiceRecordingCommand() => 'LM00;';

/// `LM0;` — documented as answering `LM0n;` with the channel recording. The
/// FT-891 answers `00` while its panel blinks REC, so the read says nothing
/// about whether a recording is running and no driver here asks it (see
/// [Ft891Session]'s voice tracker). Kept because the command is real and the
/// manual's shape is worth stating where the next reader looks for it.
String buildReadVoiceRecordingCommand() => 'LM0;';

/// `0n` → n, for both `PB` and `LM` answers. Null for anything else.
int? parseVoiceChannelParams(String params) => RegExp(r'^0\d$').hasMatch(params) ? int.tryParse(params.substring(1)) : null;

/// `FA014250000;` → 14250000 Hz. Null unless it's exactly [digits] digits
/// — a truncated or over-long response is not a frequency.
int? parseFrequencyParams(String params, {int digits = yaesuFrequencyDigits}) {
  if (params.length != digits || !RegExp(r'^\d+$').hasMatch(params)) return null;
  return int.tryParse(params);
}

/// The radio's own status packet, which is what Auto-Information actually
/// pushes when the operator turns the dial — NOT `FA`/`MD`, which only ever
/// come back as answers to a read. Ignoring `IF` would leave a connected
/// radio moving only when the 5-second poll comes round.
///
/// Layout, derived from a live FT-891 rather than from the manual's table
/// (`IF001014233700+000000200000;` alongside its own `FA014233700;` and
/// `MD02;`), params being everything between `IF` and `;`:
///
///     001 014233700 +0000 0 0 2 ...
///     |   |         |     | | └─ P6 mode, index 19
///     |   |         |     | └─ TX clarifier
///     |   |         |     └─ RX clarifier
///     |   |         └─ P3 clarifier offset
///     |   └─ P2 frequency in Hz, 9 digits, indices 3..11
///     └─ P1 memory channel
///
/// An eight-digit radio ([yaesuFrequencyDigits]) has the same fields one
/// place earlier from P2 on, which puts its mode at index 18.
///
/// Returns null for anything that doesn't match, so a short or unexpected
/// packet is skipped rather than reported as a bogus frequency.
({int? freqHz, String? mode})? parseInformationParams(String params, {int digits = yaesuFrequencyDigits}) {
  final modeIndex = digits + 10;
  if (params.length <= modeIndex) return null;
  final freq = params.substring(3, 3 + digits);
  if (!RegExp(r'^\d+$').hasMatch(freq)) return null;
  return (freqHz: int.tryParse(freq), mode: modeNameForCode(params[modeIndex]));
}

/// `MD01;` → `LSB`. P1 (the fixed `0` for MAIN) is ignored.
String? parseModeParams(String params) {
  if (params.isEmpty) return null;
  return modeNameForCode(params.substring(params.length - 1));
}
