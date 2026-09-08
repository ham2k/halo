// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Guohetec's own control protocol — the one the Q900 and PMR-171 speak
// natively, as opposed to the thin FT-817 costume they also wear.
//
// A framed protocol, and that is the whole reason this file exists rather
// than a Q900 entry pointing at yaesu_binary_codec.dart. The FT-817 chart
// has no preamble, no length and no checksum, so a reply means whatever the
// outstanding question says it means; here every packet announces itself
// with four 0xA5, states its own length and carries a CRC. A driver on this
// protocol can lose bytes and resynchronise on the next packet, which the
// Yaesu binary driver can only do by going quiet and waiting.
//
//     A5 A5 A5 A5 | len | cmd | data… | CRC-hi CRC-lo
//
// PROVENANCE: Appendix 2 of the Q900 user manual, "Q900 control protocol
// V1.5", which states of itself that it "can be freely disseminated".
// Nothing here is transcribed from Hamlib's GPL `guohetec` backend or any
// other GPL implementation.
//
// NOT VERIFIED AGAINST HARDWARE. Everything the manual does not pin down is
// marked UNVERIFIED where it is decided; those are the places a bench
// capture changes.
//
// Pure: it builds and parses bytes and knows nothing about ports or timers.

/// The four bytes that open every packet.
const guohetecPreamble = 0xA5;

/// How many of them. A single 0xA5 occurs freely inside a payload — it is a
/// legal frequency byte, a legal CRC half — so the count is what makes the
/// header findable at all.
const guohetecPreambleCount = 4;

/// Spectrum sweeps ([GuohetecOpcode.spectrum]) arrive under a DIFFERENT
/// header, with no length and no CRC: four of these, then 256 bytes of raw
/// magnitudes on V1.0 hardware and 80 on V2.0.
///
/// Named here so it is on the record that the stream is not uniformly
/// framed, and so nothing later mistakes a sweep for a corrupt packet. This
/// app never asks for one, and [GuohetecFramer] discards anything that is
/// not preceded by the real preamble, so a sweep the radio sends anyway
/// costs nothing.
const guohetecSpectrumPreamble = 0x7E;

/// Command bytes, as Appendix 2 numbers them.
///
/// The manual's fifty commands are mostly settings — EQ, spectrum refresh
/// rate, mesh networking — that this app has no surface for and no business
/// changing on someone's radio. These are the ones a logger needs.
class GuohetecOpcode {
  /// Keys and unkeys the transmitter. See [buildPttCommand] for the
  /// polarity, which is not the one anybody guesses.
  static const ptt = 0x07;

  /// Sets BOTH VFO frequencies at once — see [buildSetFrequenciesCommand].
  static const setFrequencies = 0x09;

  /// Sets BOTH VFO modes at once — see [buildSetModesCommand].
  static const setModes = 0x0A;

  /// The whole radio state in one exchange: [GuohetecStatus].
  static const statusSync = 0x0B;

  /// Raw spectrum. Never sent by this app; see [guohetecSpectrumPreamble].
  static const spectrum = 0x39;

  /// Selects the active VFO, or copies A to B.
  static const activeVfo = 0x1B;

  /// Split on or off.
  static const split = 0x1C;

  /// Which model is answering: [GuohetecEquipmentType].
  static const equipmentType = 0x27;

  /// Transmit power, 0-100.
  static const powerLevel = 0x28;

  /// Meters alone, for polling faster than a whole [statusSync].
  static const meters = 0x2D;
}

/// The `Equipment type` byte of [GuohetecOpcode.equipmentType].
///
/// The manual lists exactly one value. A radio answering anything else is
/// something this driver has never been told about — most likely a PMR-171,
/// which shares the protocol — and the driver reports what it saw rather
/// than assuming a Q900.
class GuohetecEquipmentType {
  static const q900 = 0x00;
}

/// CRC-16/CCITT-FALSE: init 0xFFFF, polynomial 0x1021, no reflection, no
/// final XOR. Covers the length byte through the last data byte — NOT the
/// preamble, and not itself.
///
/// The manual prints this as C whose loop test is `(int)(reg ^ cur) < 0`.
/// That is the ordinary top-bit test only where `unsigned int` is sixteen
/// bits, as it is on the embedded compiler the listing was written for; read
/// with a 32-bit `int` the branch can never be taken and the routine returns
/// something else entirely. Sixteen bits is the reading that yields a
/// standard CRC, and a standard CRC is what a published protocol is
/// overwhelmingly likely to use — but it IS a reading, and a radio whose
/// packets all fail this check is telling us it was the wrong one.
int guohetecCrc(List<int> bytes) {
  var register = 0xFFFF;
  for (final byte in bytes) {
    register ^= (byte << 8) & 0xFFFF;
    for (var bit = 0; bit < 8; bit++) {
      register = (register & 0x8000) != 0 ? ((register << 1) ^ 0x1021) & 0xFFFF : (register << 1) & 0xFFFF;
    }
  }
  return register;
}

/// Wraps a command and its data in preamble, length and CRC.
///
/// The length byte counts from the byte after itself to the end of the
/// packet — the command, the data and the two CRC bytes — so it is three
/// more than the data length.
List<int> buildGuohetecFrame(int command, [List<int> data = const []]) {
  final body = [data.length + 3, command, ...data];
  final crc = guohetecCrc(body);
  return [
    for (var i = 0; i < guohetecPreambleCount; i++) guohetecPreamble,
    ...body,
    (crc >> 8) & 0xFF,
    crc & 0xFF,
  ];
}

/// Frequencies travel as four big-endian bytes of PLAIN HERTZ, not the BCD
/// the Yaesu binary protocol uses — the manual gives the range as "maximum
/// decimal 2000000000", which is a binary count and covers the radio's
/// 2 GHz top end exactly.
///
/// UNVERIFIED: the manual states the width and the maximum and never the
/// byte order. Big-endian because the CRC beside it is transmitted
/// high-byte-first, and a protocol rarely disagrees with itself. Read the
/// wrong way round, 14.074 MHz decodes as 3.559 GHz — far outside the
/// stated maximum, which is what makes this cheap to confirm.
List<int> encodeFrequency(int freqHz) {
  final value = freqHz.abs() & 0xFFFFFFFF;
  return [(value >> 24) & 0xFF, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF];
}

int decodeFrequency(List<int> bytes) =>
    (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];

/// Modes, by the code the manual's mode-setting and status-sync tables
/// share.
///
/// The names are the app's own vocabulary, the one every other codec here
/// uses. Three of the radio's nine need a note:
///
/// `CWL` is mapped to `CW` and `CWR` to `CW-R`. The manual names the two
/// codes and defines neither, and the app's `CW-R` means reverse sideband —
/// so this is the pairing that puts the radio's ordinary CW on the app's
/// ordinary CW. UNVERIFIED, and cheap to be wrong about: CatService folds
/// `CW-R` to `CW` before it can reach a log, so the cost is a mislabelled
/// mode on screen, not a mislogged contact.
///
/// `DIGI` and `PKT` are mapped to `DATA-USB` and `DATA-LSB`. Which sideband
/// either one actually is depends on the radio's own menu, which this
/// protocol cannot read; an operator on the other sideband logs one letter
/// wrong until they set the mode in the app, which is the same failure any
/// unread menu produces and better than reporting no mode at all.
const guohetecModeCodes = <String, int>{
  'USB': 0x00,
  'LSB': 0x01,
  'CW-R': 0x02,
  'CW': 0x03,
  'AM': 0x04,
  'WFM': 0x05,
  'FM': 0x06,
  'DATA-USB': 0x07,
  'DATA-LSB': 0x08,
};

final Map<int, String> _modeNamesByCode = {
  for (final entry in guohetecModeCodes.entries) entry.value: entry.key,
};

String? guohetecModeNameForCode(int code) => _modeNamesByCode[code];

int? guohetecCodeForModeName(String? name) => name == null ? null : guohetecModeCodes[name.toUpperCase()];

/// Keys or unkeys the transmitter.
///
/// The polarity is the manual's and it is backwards from every instinct:
/// **0x00 presses PTT and 0x01 releases it.** Inverting this transmits when
/// the app means to stop, so it is written out rather than computed from a
/// bool in a way a later edit could quietly flip.
List<int> buildPttCommand(bool transmit) =>
    buildGuohetecFrame(GuohetecOpcode.ptt, [transmit ? 0x00 : 0x01]);

/// Sets both VFO frequencies, because there is no command that sets one.
///
/// This is the protocol's sharpest edge. Retuning VFO A means transmitting a
/// value for VFO B as well, so a caller that does not know where B is will
/// move it — onto A's old frequency, or worse onto zero. The driver
/// therefore sends this only with both frequencies from the last
/// [GuohetecStatus], and a split operator's transmit frequency survives a
/// receive-frequency change only because of that.
List<int> buildSetFrequenciesCommand({required int vfoAHz, required int vfoBHz}) =>
    buildGuohetecFrame(GuohetecOpcode.setFrequencies, [...encodeFrequency(vfoAHz), ...encodeFrequency(vfoBHz)]);

/// Sets both VFO modes, with the same both-or-nothing constraint as
/// [buildSetFrequenciesCommand] and the same remedy.
///
/// Null for a mode the radio has no code for, so the caller sends nothing
/// rather than a command the radio would read as some other mode.
///
/// The radio's acknowledgement carries ONE mode byte where the command
/// carries two — an asymmetry the manual states plainly and which nothing
/// here relies on, since the authority on both modes is the next status
/// sync.
List<int>? buildSetModesCommand({required String? vfoAMode, required String? vfoBMode}) {
  final a = guohetecCodeForModeName(vfoAMode);
  final b = guohetecCodeForModeName(vfoBMode);
  if (a == null || b == null) return null;
  return buildGuohetecFrame(GuohetecOpcode.setModes, [a, b]);
}

/// Asks for everything: [GuohetecStatus].
List<int> buildStatusSyncCommand() => buildGuohetecFrame(GuohetecOpcode.statusSync);

/// Asks for the meters alone — the same two bytes the status sync ends
/// with, without the twenty-two in front of them.
List<int> buildMetersCommand() => buildGuohetecFrame(GuohetecOpcode.meters);

/// Asks which model is answering.
List<int> buildEquipmentTypeCommand() => buildGuohetecFrame(GuohetecOpcode.equipmentType, [0x00]);

/// Selects the active VFO. [GuohetecActiveVfo.copyAToB] is a command, not a
/// state: the radio does the copy and then reports A as active.
class GuohetecActiveVfo {
  static const a = 0x00;
  static const b = 0x01;
  static const copyAToB = 0x02;
}

List<int> buildActiveVfoCommand(int selection) => buildGuohetecFrame(GuohetecOpcode.activeVfo, [selection]);

List<int> buildSplitCommand(bool on) => buildGuohetecFrame(GuohetecOpcode.split, [on ? 0x01 : 0x00]);

/// Transmit power as a percentage, 0-100. Clamped rather than rejected: the
/// radio's own range is the authority, and a caller asking for 120% wants
/// full power.
List<int> buildPowerLevelCommand(int percent) =>
    buildGuohetecFrame(GuohetecOpcode.powerLevel, [percent.clamp(0, 100)]);

/// Which scale a meter byte is reporting on. The protocol multiplexes
/// several meters onto one byte and names the scale in its top bits, so a
/// reading without its scale is meaningless — they travel together.
enum GuohetecMeterScale { sMeter, power, swr, alc, audio }

/// One meter reading: a raw 0-34 and the scale it is on.
///
/// Raw, and staying raw. The manual gives every meter the same 0-34 range
/// and says nothing about what any of the numbers mean — no S-units, no
/// watts, no ratio — so converting one here would be inventing the
/// conversion. What turns these into something an operator can read is a
/// table under `info/`, built from a bench capture.
class GuohetecMeterReading {
  final GuohetecMeterScale scale;
  final int raw;

  const GuohetecMeterReading({required this.scale, required this.raw});

  @override
  bool operator ==(Object other) =>
      other is GuohetecMeterReading && other.scale == scale && other.raw == raw;

  @override
  int get hashCode => Object.hash(scale, raw);

  @override
  String toString() => 'GuohetecMeterReading(${scale.name}: $raw)';
}

/// The S-meter/PO byte: bit 7 picks the scale, the rest is the reading.
///
/// A receiving radio reports on the S scale and a transmitting one on the
/// power scale, so which arrives is not a setting — it follows the PTT.
GuohetecMeterReading parseSignalMeter(int byte) => GuohetecMeterReading(
      scale: (byte & 0x80) != 0 ? GuohetecMeterScale.power : GuohetecMeterScale.sMeter,
      raw: byte & 0x7F,
    );

/// The SWR/AUD/ALC byte: bits 7 and 6 pick the scale.
///
/// `00` is SWR and is the one this app acts on. `01` and `10` are the other
/// two, and the manual CONTRADICTS ITSELF about which is which — its
/// closing "Change notification" swaps the two labels, and even after the
/// swap each line is captioned with the other's name. So the pairing below
/// follows the amended body text and is UNVERIFIED; a capture taken while
/// transmitting into a dummy load settles it, and until then nothing is
/// shown to an operator on either scale.
///
/// `11` is not a value the manual defines. Reported as null rather than
/// guessed at, so a byte this cannot read never reaches a meter.
GuohetecMeterReading? parseSwrMeter(int byte) {
  final scale = switch ((byte >> 6) & 0x03) {
    0x00 => GuohetecMeterScale.swr,
    0x01 => GuohetecMeterScale.audio,
    0x02 => GuohetecMeterScale.alc,
    _ => null,
  };
  if (scale == null) return null;
  return GuohetecMeterReading(scale: scale, raw: byte & 0x3F);
}

/// How many payload bytes a [GuohetecOpcode.statusSync] reply carries — the
/// manual's field list, added up.
const guohetecStatusPayloadLength = 24;


/// Everything one status sync says.
///
/// One exchange for what the FT-817 chart needs three for and still cannot
/// fully answer: it has no second-VFO read at all, so a split operator's
/// transmit frequency is invisible to it.
class GuohetecStatus {
  final bool transmitting;
  final int vfoAHz;
  final int vfoBHz;

  /// Null for a mode code the manual does not list — the frequency beside
  /// it is still good, and a guessed mode in a log the right frequency makes
  /// look trustworthy is the worse failure.
  final String? vfoAMode;
  final String? vfoBMode;

  /// True when VFO B is the active one.
  final bool vfoBActive;

  /// Supply voltage. The radio reports tenths of a volt in one byte, so
  /// this tops out at 25.5 V — above anything the radio will run on.
  final double voltageVolts;

  /// The radio's own clock, as hour/minute/second. Not a `DateTime`: the
  /// radio names no date and no zone, and building one here would have to
  /// invent both.
  final int utcHour;
  final int utcMinute;
  final int utcSecond;

  final bool highPower;
  final bool antennaTunerOn;
  final bool bluetoothConnected;
  final bool gpsOnline;

  final GuohetecMeterReading signalMeter;

  /// Null when the byte is on a scale the manual does not define — see
  /// [parseSwrMeter].
  final GuohetecMeterReading? swrMeter;

  const GuohetecStatus({
    required this.transmitting,
    required this.vfoAHz,
    required this.vfoBHz,
    required this.vfoAMode,
    required this.vfoBMode,
    required this.vfoBActive,
    required this.voltageVolts,
    required this.utcHour,
    required this.utcMinute,
    required this.utcSecond,
    required this.highPower,
    required this.antennaTunerOn,
    required this.bluetoothConnected,
    required this.gpsOnline,
    required this.signalMeter,
    required this.swrMeter,
  });

  /// The frequency and mode of whichever VFO the radio is actually on.
  int get activeFreqHz => vfoBActive ? vfoBHz : vfoAHz;
  String? get activeMode => vfoBActive ? vfoBMode : vfoAMode;


  @override
  String toString() => 'GuohetecStatus(${transmitting ? 'TX' : 'RX'}, '
      'A: $vfoAHz ${vfoAMode ?? '?'}, B: $vfoBHz ${vfoBMode ?? '?'}, '
      'active: ${vfoBActive ? 'B' : 'A'}, ${voltageVolts}V)';
}

/// Null unless the payload is the full length the manual describes.
///
/// A short payload is a packet this does not understand, and reading its
/// fields at the offsets a full one would have puts a frequency together out
/// of whatever bytes happen to be there. The CRC has already passed by the
/// time this is called, so a short payload means the radio's firmware
/// disagrees with the manual — worth reporting as unreadable rather than
/// papering over.
GuohetecStatus? parseStatus(List<int> payload) {
  if (payload.length < guohetecStatusPayloadLength) return null;
  final statusBits = payload[21];
  return GuohetecStatus(
    transmitting: payload[0] != 0,
    vfoAMode: guohetecModeNameForCode(payload[1]),
    vfoBMode: guohetecModeNameForCode(payload[2]),
    vfoAHz: decodeFrequency(payload.sublist(3, 7)),
    vfoBHz: decodeFrequency(payload.sublist(7, 11)),
    vfoBActive: payload[11] != 0,
    voltageVolts: payload[17] / 10.0,
    utcHour: payload[18],
    utcMinute: payload[19],
    utcSecond: payload[20],
    bluetoothConnected: (statusBits & 0x01) != 0,
    gpsOnline: (statusBits & 0x02) != 0,
    antennaTunerOn: (statusBits & 0x10) != 0,
    highPower: (statusBits & 0x20) != 0,
    signalMeter: parseSignalMeter(payload[22]),
    swrMeter: parseSwrMeter(payload[23]),
  );
}

/// One complete, CRC-checked packet.
class GuohetecFrame {
  final int command;
  final List<int> data;

  const GuohetecFrame({required this.command, this.data = const []});

  @override
  bool operator ==(Object other) =>
      other is GuohetecFrame && other.command == command && _sameBytes(other.data, data);

  @override
  int get hashCode => Object.hash(command, Object.hashAll(data));

  @override
  String toString() => 'GuohetecFrame(cmd: 0x${command.toRadixString(16).padLeft(2, '0')}, '
      'data: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')})';
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Splits a byte stream into complete, CRC-checked packets, keeping any
/// trailing partial packet for the next call.
///
/// Unlike the Yaesu binary protocol's stream, this one is self-describing,
/// so a driver on it needs no one-command-at-a-time pump: anything that is
/// not a well-formed packet is skipped and the next real one still frames.
/// That is what lets the radio volunteer a spectrum sweep, or the operator
/// unplug and replug the cable mid-answer, without desynchronising the
/// session for good.
class GuohetecFramer {
  /// Bytes seen since the last complete packet.
  final _residual = <int>[];

  /// A cap, because the residual is fed by whatever arrives on the wire. A
  /// stream that never produces a packet — the wrong port, a spectrum sweep
  /// nobody asked for, a half-open socket dribbling noise — must not grow
  /// the buffer without limit.
  ///
  /// Well above the largest packet this protocol defines: the mesh command's
  /// 225-byte payload, and the V1.0 spectrum sweep's 256 unframed bytes.
  static const maxResidual = 1024;

  /// Packets whose CRC did not match, since the framer was made.
  ///
  /// Counted rather than thrown, and worth counting: the CRC reading this
  /// codec is built on is an inference from the manual's C listing
  /// ([guohetecCrc]), so "every packet fails" is a specific, expected
  /// diagnosis with a specific fix, and it is invisible unless something
  /// keeps score.
  int crcFailures = 0;

  List<GuohetecFrame> add(List<int> incoming) {
    _residual.addAll(incoming);

    final frames = <GuohetecFrame>[];
    var start = 0;

    // Where an incomplete packet began, if one is still waiting for its
    // tail. Kept SEPARATELY from the scan position so the scan can carry on
    // past it: a header whose length byte is a lie never completes, and a
    // framer that simply stopped at the first incomplete packet would hold
    // every real packet behind it hostage until the lie was paid off.
    var keepFrom = -1;

    while (start < _residual.length) {
      if (_residual[start] != guohetecPreamble) {
        start++;
        continue;
      }
      // A packet opens with four of them. A run longer than four is
      // legitimate — the last four are the header and the earlier ones are
      // noise or a truncated packet's tail — so the scan walks to the END of
      // the run and takes the four before the length byte.
      //
      // The cost is that a length byte of 0xA5 is eaten as a fifth
      // preamble, so a 165-byte payload cannot be framed at all. Nothing
      // this app can receive is remotely that size — the largest is the
      // 27-byte status sync — and the alternative is trying every offset in
      // the run, which spends real work on every noise burst to rescue a
      // packet that cannot arrive.
      var runEnd = start;
      while (runEnd < _residual.length && _residual[runEnd] == guohetecPreamble) {
        runEnd++;
      }
      final runLength = runEnd - start;
      if (runEnd >= _residual.length && runLength < guohetecPreambleCount) {
        // Might yet become a header once more bytes arrive.
        if (keepFrom < 0) keepFrom = start;
        break;
      }
      if (runLength < guohetecPreambleCount) {
        start = runEnd;
        continue;
      }
      final headerStart = runEnd - guohetecPreambleCount;
      if (runEnd >= _residual.length) {
        // A complete header and nothing after it yet.
        if (keepFrom < 0) keepFrom = headerStart;
        break;
      }

      final length = _residual[runEnd];
      // The length covers the command and the two CRC bytes at minimum.
      // Nothing caps the other end: a length larger than any reply this app
      // expects is not worth a special case, because the scan already walks
      // past a packet that never completes.
      if (length < 3) {
        start = runEnd;
        continue;
      }
      final end = runEnd + 1 + length;
      if (end > _residual.length) {
        // This packet may still be genuine and merely split across reads —
        // so its start is retained. But the scan continues past it, because
        // it may equally be noise that will never complete, and a real
        // packet sitting behind it must not wait for that to be settled.
        if (keepFrom < 0) keepFrom = headerStart;
        start = runEnd;
        continue;
      }

      final body = _residual.sublist(runEnd, end - 2);
      final stated = (_residual[end - 2] << 8) | _residual[end - 1];
      if (stated == guohetecCrc(body)) {
        frames.add(GuohetecFrame(command: body[1], data: body.sublist(2)));
        start = end;
        // A packet that checksummed settles everything before it: whatever
        // that earlier header was, it was not the start of this one.
        keepFrom = -1;
      } else {
        crcFailures++;
        // Resume the scan just past this header rather than past the packet
        // it claimed to be: a bad CRC means the length byte is not to be
        // trusted either, and skipping the length it named would step over
        // a real packet nested in the noise.
        start = runEnd;
      }
    }

    _residual.removeRange(0, keepFrom >= 0 && keepFrom < start ? keepFrom : start);
    if (_residual.length > maxResidual) {
      // Nothing in here has framed. Keeping the tail rather than everything
      // means a stream that recovers still frames its next real packet.
      _residual.removeRange(0, _residual.length - maxResidual);
    }
    return frames;
  }

  /// Drops any partial packet — for a fresh connection, so a truncated tail
  /// from the previous one cannot prefix the first real packet of the next.
  void reset() => _residual.clear();
}
