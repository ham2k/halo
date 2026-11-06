// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// TCI, the Transceiver Control Interface: Expert Electronics' protocol, which
// ExpertSDR3 serves for its SunSDR radios and Thetis serves for an ANAN. A
// WebSocket; commands go both ways as text frames, IQ comes as binary ones.
//
// Written from "TCI Protocol" version 2.1 (Expert Group LLC, September 2026,
// https://github.com/ExpertSDR3/TCI, published under the MIT licence), and
// run against neither server. What the document does not say, and this file
// assumes: the server listens at the WebSocket's root path, and Thetis spells
// modes as its own CAT does (CWL, CWU) where ExpertSDR3 has only CW.
//
// Pure: it builds and parses, and knows nothing about sockets or timers.

import 'dart:typed_data';

/// Where both servers listen unless their settings say otherwise. ExpertSDR2
/// used 40001; ExpertSDR3 and Thetis both moved to this.
const tciDefaultPort = 50001;

/// The receiver (TCI's "transceiver periodic number") and the channel on it
/// that a node follows: the first, and its VFO A.
const tciReceiver = 0;
const tciChannel = 0;

/// One command, its name lower-cased: "the case of letters does not matter".
class TciCommand {
  final String name;
  final List<String> args;

  const TciCommand(this.name, this.args);

  @override
  String toString() => '$name:${args.join(',')}';
}

/// Splits text into commands on `;`, keeping a command split across two
/// frames. A frame may carry several — Thetis concatenates them.
class TciFramer {
  String _pending = '';

  /// Whether the text up to the next `;` belongs to a command already
  /// dropped for its length — parsed, its tail would read as a whole one.
  bool _overflowed = false;

  /// What a command without its `;` may grow to before it is dropped: the
  /// longest real one is a `MODULATIONS_LIST`, well under this.
  static const _maxPending = 4096;

  List<TciCommand> add(String text) {
    final commands = <TciCommand>[];
    final buffer = _pending + text;
    var start = 0;
    for (var end = buffer.indexOf(';'); end >= 0; end = buffer.indexOf(';', start)) {
      if (_overflowed) {
        _overflowed = false;
      } else {
        final command = _parse(buffer.substring(start, end));
        if (command != null) commands.add(command);
      }
      start = end + 1;
    }
    _pending = buffer.substring(start);
    if (_pending.length > _maxPending) {
      _pending = '';
      _overflowed = true;
    }
    return commands;
  }

  static TciCommand? _parse(String text) {
    final raw = text.trim();
    if (raw.isEmpty) return null;
    final colon = raw.indexOf(':');
    return colon < 0
        ? TciCommand(raw.toLowerCase(), const [])
        : TciCommand(raw.substring(0, colon).trim().toLowerCase(), [for (final arg in raw.substring(colon + 1).split(',')) arg.trim()]);
  }

  void reset() {
    _pending = '';
    _overflowed = false;
  }
}

/// TCI's booleans: `true` or `1` in any case is true, anything else false.
bool tciBool(String arg) => arg.toLowerCase() == 'true' || arg == '1';

String buildTciReadVfoCommand() => 'VFO:$tciReceiver,$tciChannel;';

String buildTciSetVfoCommand(int freqHz) => 'VFO:$tciReceiver,$tciChannel,$freqHz;';

String buildTciReadModulationCommand() => 'MODULATION:$tciReceiver;';

/// The app's modes, each with the spellings a server may offer for it, in
/// the order a set prefers them. ExpertSDR3 has one CW and calls FM `NFM`;
/// Thetis has CWL and CWU, the pairing its `ZZMD` makes (thetis_codec.dart).
const _tciModulations = <String, List<String>>{
  'LSB': ['lsb'],
  'USB': ['usb'],
  'CW': ['cw', 'cwu'],
  'CW-R': ['cwl'],
  'AM': ['am'],
  'FM': ['nfm', 'fm'],
  'DATA-USB': ['digu'],
  'DATA-LSB': ['digl'],
};

/// Read, never set: synchronous AM is AM in a log, and setting `AM` puts the
/// radio in plain AM. DSB, WFM, DRM and SPEC have no app mode, and naming
/// one would report a plausible wrong mode.
const _tciReadOnlyModulations = {'sam': 'AM'};

final _tciModesByModulation = {
  for (final entry in _tciModulations.entries)
    for (final name in entry.value) name: entry.key,
  ..._tciReadOnlyModulations,
};

/// `digu` → `DATA-USB`. Null for one with no app mode.
String? tciModeFor(String modulation) => _tciModesByModulation[modulation.toLowerCase()];

/// The modes a set can send to any server. Not CW-R: ExpertSDR3 has no
/// reverse CW, and a mode offered that a set cannot reach is a picker that
/// does nothing.
const tciSettableModes = ['LSB', 'USB', 'CW', 'AM', 'FM', 'DATA-USB', 'DATA-LSB'];

/// `MODULATION:0,DIGU;` for [mode], spelled as the server's own
/// `MODULATIONS_LIST` spells it. [offered] is that list, empty before the
/// server has sent it, when the first spelling is used. Null when the
/// server offers none of the spellings, or the app mode has none.
String? buildTciSetModulationCommand(String mode, {List<String> offered = const []}) {
  final names = _tciModulations[mode.toUpperCase()];
  if (names == null) return null;
  if (offered.isEmpty) return 'MODULATION:$tciReceiver,${names.first.toUpperCase()};';
  for (final name in names) {
    for (final candidate in offered) {
      if (candidate.toLowerCase() == name) return 'MODULATION:$tciReceiver,$candidate;';
    }
  }
  return null;
}

String buildTciSetTrxCommand(bool on) => 'TRX:$tciReceiver,$on;';

String buildTciReadTrxCommand() => 'TRX:$tciReceiver;';

String buildTciReadTuneCommand() => 'TUNE:$tciReceiver;';

/// `DRIVE` is 0–100, a share of the radio's rated output.
String buildTciSetDriveCommand(int share) => 'DRIVE:$tciReceiver,${share.clamp(0, 100)};';

String buildTciReadDriveCommand() => 'DRIVE:$tciReceiver;';

/// What one `CW_MACROS` is given at a time. The server queues macros itself,
/// so a message goes whole; the cap only keeps a pasted page from going as
/// one command.
const tciCwMaxChars = 200;

/// `CW_MACROS:0,TU 5NN;`. [text] must already be sanitized
/// (cw_send_queue.dart); of what survives that, only the comma is reserved,
/// and the spec has it sent as `~`.
String buildTciSendCwCommand(String text) => 'CW_MACROS:$tciReceiver,${text.replaceAll(',', '~')};';

String buildTciStopCwCommand() => 'CW_MACROS_STOP;';

/// The macros' speed, which is what `CW_MACROS` keys at — not
/// `CW_KEYER_SPEED`, the paddle's.
const tciKeyerSpeedRange = (min: 1, max: 60);

String buildTciSetKeyerSpeedCommand(int wpm) => 'CW_MACROS_SPEED:${wpm.clamp(tciKeyerSpeedRange.min, tciKeyerSpeedRange.max)};';

String buildTciReadKeyerSpeedCommand() => 'CW_MACROS_SPEED;';

/// The meters, pushed every [intervalMs] (30–1000) once asked for.
String buildTciRxSensorsCommand(bool on, {int intervalMs = 250}) => 'RX_SENSORS_ENABLE:$on,$intervalMs;';

String buildTciTxSensorsCommand(bool on, {int intervalMs = 250}) => 'TX_SENSORS_ENABLE:$on,$intervalMs;';

/// The IQ rates the spec lists. Per client: a rate asked for changes nothing
/// the operator sees in the server's own panadapter.
const tciIqRates = [48000, 96000, 192000, 384000];

String buildTciIqRateCommand(int rate) => 'IQ_SAMPLERATE:$rate;';

String buildTciIqStartCommand() => 'IQ_START:$tciReceiver;';

String buildTciIqStopCommand() => 'IQ_STOP:$tciReceiver;';

/// `DDS` is the receiver's centre — where its IQ, and its panadapter, sit.
String buildTciReadDdsCommand() => 'DDS:$tciReceiver;';

String buildTciSetDdsCommand(int hz) => 'DDS:$tciReceiver,$hz;';

/// A binary frame's header: the spec's `struct Stream`, nine little-endian
/// `uint32`s and seven reserved, 64 bytes before the samples.
const tciStreamHeaderBytes = 64;

/// `StreamType.IQ_STREAM`.
const tciIqStreamType = 0;

/// `SampleType`: how wide each sample is, and whether it is a float.
enum TciSampleType { int16, int24, int32, float32 }

class TciStreamHeader {
  final int receiver;
  final int sampleRate;
  final TciSampleType? format;

  /// Real samples in the frame: an IQ pair is two.
  final int length;
  final int type;
  final int channels;

  const TciStreamHeader({
    required this.receiver,
    required this.sampleRate,
    required this.format,
    required this.length,
    required this.type,
    required this.channels,
  });
}

/// Null for a frame shorter than its header.
TciStreamHeader? parseTciStreamHeader(Uint8List frame) {
  if (frame.length < tciStreamHeaderBytes) return null;
  final bytes = ByteData.sublistView(frame);
  int word(int index) => bytes.getUint32(index * 4, Endian.little);
  final format = word(2);
  return TciStreamHeader(
    receiver: word(0),
    sampleRate: word(1),
    format: format < TciSampleType.values.length ? TciSampleType.values[format] : null,
    length: word(5),
    type: word(6),
    channels: word(7),
  );
}

/// The frame's samples as floats, interleaved I/Q, full scale ±1 for the
/// integer types. As many as [TciStreamHeader.length] says and the frame
/// holds, whichever is fewer — a short frame is read, not trusted. Empty
/// for a format the spec does not define.
Float32List tciSamples(Uint8List frame, TciStreamHeader header) {
  final format = header.format;
  if (format == null) return Float32List(0);
  final width = switch (format) {
    TciSampleType.int16 => 2,
    TciSampleType.int24 => 3,
    TciSampleType.int32 || TciSampleType.float32 => 4,
  };
  final available = (frame.length - tciStreamHeaderBytes) ~/ width;
  final count = header.length < available ? header.length : available;
  final bytes = ByteData.sublistView(frame, tciStreamHeaderBytes);
  final out = Float32List(count);
  for (var i = 0; i < count; i++) {
    final at = i * width;
    final sample = switch (format) {
      TciSampleType.int16 => bytes.getInt16(at, Endian.little) / 32768,
      TciSampleType.int24 => ((bytes.getUint8(at) | bytes.getUint8(at + 1) << 8 | bytes.getInt8(at + 2) << 16)) / 8388608,
      TciSampleType.int32 => bytes.getInt32(at, Endian.little) / 2147483648,
      TciSampleType.float32 => bytes.getFloat32(at, Endian.little),
    };
    // One NaN would ride the noise average forever and blank the display.
    out[i] = sample.isFinite ? sample : 0;
  }
  return out;
}
