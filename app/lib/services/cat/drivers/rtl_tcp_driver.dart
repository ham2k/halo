// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An SDR behind an rtl_tcp server — docs/design/cat.md § SDR receivers.
//
// rtl_tcp is the RTL-SDR tools' network server, and the protocol other
// receivers borrowed to be usable by the same clients: rsp_tcp for an
// SDRplay speaks it unchanged. The server opens with a 12-byte header —
// `RTL0`, the tuner type and how many gains it has, both big-endian — and
// then streams unsigned 8-bit I/Q pairs, centred on 127.5, for as long as
// the socket is open. Commands are five bytes: one command byte and a
// big-endian 32-bit argument. Nothing is ever answered.
//
// The stream does not pause, and the server takes one client at a time, so
// [CatService] connects an SDR only while a display wants it.

import 'dart:typed_data';

import 'package:halo_core/halo_core.dart' show realNowMillis;
import 'package:halo_i18n/halo_i18n.dart';

import '../driver.dart';
import '../spectrum.dart';
import 'sdr_spectrum.dart';

/// The RTL-SDR's usable sample rates: 250 kHz is the one rate in its low
/// band worth offering, and above 2.4 MHz it drops samples.
const rtlSdrRates = [250000, 1024000, 2048000, 2400000];

/// The RTL2832U's own digitizer, fed straight from the antenna on a V3 for
/// HF without an upconverter: off, on the I branch, or the Q branch.
const rtlDirectSamplingConfigKey = 'rtlDirectSampling';

const rtlTcpDefaultPort = 1234;

/// The command bytes, as rtl_tcp numbers them.
abstract final class RtlTcpCommand {
  static const frequency = 0x01;
  static const sampleRate = 0x02;
  static const gainMode = 0x03;
  static const gain = 0x04;
  static const ppm = 0x05;
  static const directSampling = 0x09;
}

/// One command on the wire.
Uint8List rtlTcpCommand(int command, int argument) =>
    (ByteData(5)
          ..setUint8(0, command)
          ..setUint32(1, argument.toUnsigned(32)))
        .buffer
        .asUint8List();

const _tunerNames = {1: 'E4000', 2: 'FC0012', 3: 'FC0013', 4: 'FC2580', 5: 'R820T', 6: 'R828D'};

class RtlTcpDriver extends EquipmentDriver {
  /// Rates for the device behind this entry's server, ascending.
  final List<int> rates;

  /// Whether to offer [rtlDirectSamplingConfigKey] — an RTL2832U setting
  /// another server's device has no use for.
  final bool directSampling;

  const RtlTcpDriver({this.rates = rtlSdrRates, this.directSampling = true});

  @override
  String get key => 'rtl-tcp';

  @override
  String get name => 'rtl_tcp';

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => [
    for (final element in sdrConfigElements())
      if (!overrides.containsKey(element['key'])) element,
    if (directSampling && !overrides.containsKey(rtlDirectSamplingConfigKey))
      {
        'type': 'field',
        'fieldType': 'select',
        'key': rtlDirectSamplingConfigKey,
        'label': t.settings.station.rtlDirectSampling,
        'description': t.settings.station.rtlDirectSamplingDescription,
        'advanced': true,
        'options': [
          {'value': '0', 'label': t.settings.station.rtlDirectSamplingOff},
          {'value': '1', 'label': t.settings.station.rtlDirectSamplingI},
          {'value': '2', 'label': t.settings.station.rtlDirectSamplingQ},
        ],
      },
  ];

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => RtlTcpSession(
    sink,
    SdrConfig.fromConfig(config),
    rates: rates,
    directSampling: directSampling ? int.tryParse('${config[rtlDirectSamplingConfigKey] ?? 0}') ?? 0 : 0,
  );
}

class RtlTcpSession implements SpectrumSession, SdrTuner {
  final EquipmentSink sink;
  final int directSampling;
  late final SdrSpectrum spectrum;

  RtlTcpSession(this.sink, SdrConfig config, {required List<int> rates, this.directSampling = 0}) {
    spectrum = SdrSpectrum(
      config: config,
      tuner: this,
      sink: sink is SpectrumSink ? sink as SpectrumSink : null,
      vfo: sink is SdrSink ? sink as SdrSink : null,
      rates: rates,
    );
  }

  final _header = BytesBuilder(copy: true);
  bool _headerDone = false;

  /// The other end opened with something other than `RTL0`: whatever it
  /// sends after is not IQ, and drawn it would be noise.
  bool _notAServer = false;

  /// An odd byte left by a chunk that split an I/Q pair.
  int? _carry;

  int _aliveMillis = 0;

  @override
  Duration? get expectedUpdateInterval => null;

  @override
  void handleData(Uint8List chunk) {
    if (_notAServer) return;
    var bytes = chunk;
    if (!_headerDone) {
      _header.add(bytes);
      if (_header.length < 12) return;
      final all = _header.takeBytes();
      _headerDone = true;
      if (String.fromCharCodes(all.sublist(0, 4)) != 'RTL0') {
        _notAServer = true;
        sink.reportProblem(t.settings.station.rtlTcpNotAServer);
        return;
      }
      final info = ByteData.sublistView(all, 0, 12);
      final tuner = info.getUint32(4);
      sink.reportDiagnostic('tuner ${_tunerNames[tuner] ?? tuner}, ${info.getUint32(8)} gains');
      bytes = Uint8List.sublistView(all, 12);
    }
    if (bytes.isEmpty) return;
    // Throttled: the stream is a few megabytes a second, and the watch only
    // needs to hear that it has not stopped.
    final now = realNowMillis();
    if (now - _aliveMillis > 1000) {
      _aliveMillis = now;
      sink.reportAlive();
    }
    if (_carry case final first?) {
      _carry = null;
      _feed(Uint8List.fromList([first, bytes[0]]));
      bytes = Uint8List.sublistView(bytes, 1);
    }
    if (bytes.length.isOdd) {
      _carry = bytes.last;
      bytes = Uint8List.sublistView(bytes, 0, bytes.length - 1);
    }
    _feed(bytes);
  }

  void _feed(Uint8List pairs) => spectrum.feed(pairs.length ~/ 2, (from, n, into, at) {
    for (var k = 0; k < n * 2; k++) {
      into[at + k] = (pairs[from * 2 + k] - 127.5) / 127.5;
    }
  });

  @override
  void startUpdates() {
    final config = spectrum.config;
    sink.send(rtlTcpCommand(RtlTcpCommand.ppm, config.ppm));
    sink.send(rtlTcpCommand(RtlTcpCommand.directSampling, directSampling));
    if (config.gainDb case final gain?) {
      sink.send(rtlTcpCommand(RtlTcpCommand.gainMode, 1));
      sink.send(rtlTcpCommand(RtlTcpCommand.gain, (gain * 10).round()));
    } else {
      sink.send(rtlTcpCommand(RtlTcpCommand.gainMode, 0));
    }
    sink.send(rtlTcpCommand(RtlTcpCommand.sampleRate, spectrum.rate));
  }

  @override
  void stopUpdates() {}

  @override
  void teardown() => spectrum.stop();

  @override
  void tuneDevice(int hz) => sink.send(rtlTcpCommand(RtlTcpCommand.frequency, hz));

  @override
  void setSampleRate(int rate) => sink.send(rtlTcpCommand(RtlTcpCommand.sampleRate, rate));

  @override
  String? get spectrumUnavailable => null;

  @override
  SpectrumCapabilities get spectrumCapabilities => spectrum.capabilities;

  @override
  void startSpectrum() => spectrum.start();

  @override
  void stopSpectrum() => spectrum.stop();

  @override
  bool setSpectrum(SpectrumRequest request) => spectrum.set(request);
}
