// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An SDR behind Airspy's SpyServer — docs/design/cat.md § SDR receivers.
//
// SpyServer has no published specification. This is written from a
// description of the wire protocol compiled from several open clients and
// from captures of the official server, docs/design/spyserver-protocol.md,
// and checked against public servers of each version from 2.0.1700 on.
//
// Everything is little-endian 32-bit. The client sends commands — a type, a
// body length, a body — and never hears back about them: a setting the server
// does not like is clamped or dropped in silence. The server sends messages
// with a 20-byte header (protocol version, kind, stream, sequence, body
// length) and no marker to resynchronise on, so one framing error ends the
// session.
//
// The server computes the spectrum itself and sends it as one byte a bin,
// a few tens of kilobytes a second where the IQ would be megabytes — which is
// why this asks for that, over a link that is often the internet. A stream
// with the spectrum alone carries nothing, so a narrow IQ comes along with it
// and is thrown away.
//
// Whatever stops a session — a server this cannot use, a stream it can no
// longer read, a spectrum that never comes — drops the connection with the
// reason, and it is tried again while a display waits: a receiver plugged in,
// or a server restarted, is then picked up without the operator.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart' show realNowMillis;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart' show ham2kMachineName;

import '../driver.dart';
import '../spectrum.dart';
import 'sdr_spectrum.dart';

const spyServerDefaultPort = 5555;

/// A step from 0 up to the device's highest — the protocol knows gain only as
/// an index. Blank leaves the server's own.
const spyServerGainConfigKey = 'spyServerGain';

/// The version this client speaks, 2.0.1700: every server since accepts it.
const spyServerProtocolVersion = 2 << 24 | 0 << 16 | 1700;

abstract final class SpyServerCommand {
  static const hello = 0;
  static const setSetting = 2;
  static const ping = 3;
}

abstract final class SpyServerSetting {
  static const streamingMode = 0;
  static const streamingEnabled = 1;
  static const gain = 2;
  static const iqFormat = 100;
  static const iqFrequency = 101;
  static const iqDecimation = 102;
  static const fftFormat = 200;
  static const fftFrequency = 201;
  static const fftDecimation = 202;
  static const fftDbOffset = 203;
  static const fftDbRange = 204;
  static const fftDisplayPixels = 205;
}

abstract final class SpyServerMessage {
  static const deviceInfo = 0;
  static const clientSync = 1;
  static const pong = 2;
  static const uint8Fft = 301;
}

/// The IQ and spectrum streams together; the spectrum alone sends nothing.
const _streamFftAndIq = 5;
const _formatUint8 = 1;

/// Bins a sweep carries — the server reduces its own transform to exactly
/// this — enough for a panel's `span` to crop a wide sweep and still draw.
const spyServerFftPixels = 2048;

/// Byte 255 stands for minus [spyServerDbOffset] dB, and byte 0 for
/// [spyServerDbRange] below that. Measured on servers: a larger offset raises
/// the bytes, the opposite of what the open clients assume.
const spyServerDbOffset = 0;
const spyServerDbRange = 140;

/// A server before [_spyServerSpectrumAnyIq] sends no spectrum while the IQ
/// rate is below about this — measured: 19.5 kS/s streams, 12 kS/s does not.
const _oldServerMinIqRate = 20000;

/// The first server build that streams the spectrum at any IQ rate.
const _spyServerSpectrumAnyIq = 1920;

/// Larger than any message the server sends; a header claiming more is the
/// stream out of step.
const _maxBody = 1 << 20;

const _headerSize = 20;

/// The server sends nothing while its streams are off — an SDR the operator
/// connected with no display — so a ping is what shows it is still there, and
/// keeps an idle connection through a NAT that would time it out. Also how
/// often a session checks it is getting somewhere — the handshake done, and
/// while streaming, a sweep come: one interval of grace, then one without
/// drops it.
const spyServerPingInterval = Duration(seconds: 5);

/// More halvings than any receiver has: a count beyond it is not a count.
const _maxDecimationStages = 16;

/// One command on the wire.
Uint8List spyServerCommand(int type, List<int> body) {
  final out = ByteData(8 + body.length)
    ..setUint32(0, type, Endian.little)
    ..setUint32(4, body.length, Endian.little);
  final bytes = out.buffer.asUint8List()..setRange(8, 8 + body.length, body);
  return bytes;
}

Uint8List spyServerSetSetting(int setting, int value) => spyServerCommand(
  SpyServerCommand.setSetting,
  (ByteData(8)
        ..setUint32(0, setting, Endian.little)
        ..setUint32(4, value.toUnsigned(32), Endian.little))
      .buffer
      .asUint8List(),
);

class SpyServerDriver extends EquipmentDriver {
  const SpyServerDriver();

  @override
  String get key => 'spyserver';

  @override
  String get name => 'SpyServer';

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => [
    for (final element in sdrConfigElements())
      // Gain in dB and the crystal's correction are the server's own settings.
      if (!overrides.containsKey(element['key']) && element['key'] != sdrGainDbConfigKey && element['key'] != sdrPpmConfigKey) element,
    if (!overrides.containsKey(spyServerGainConfigKey))
      {
        'type': 'field',
        'fieldType': 'number',
        'key': spyServerGainConfigKey,
        'label': t.settings.station.spyServerGain,
        'description': t.settings.station.spyServerGainDescription,
        'advanced': true,
      },
  ];

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) =>
      SpyServerSession(sink, SdrConfig.fromConfig(config), gain: sdrConfigNumber(config, spyServerGainConfigKey)?.round());
}

/// What the server says about its receiver, once, after the hello.
class _Device {
  /// The server's own build, from the message's header: 1922 for 2.0.1922.
  final int serverBuild;
  final int maxSampleRate;
  final int maxBandwidth;
  final int decimationStages;
  final int maxGain;
  final int minFrequency;
  final int maxFrequency;
  final int minIqDecimation;
  final int forcedIqFormat;

  _Device(ByteData body, {required this.serverBuild})
    : maxSampleRate = body.getUint32(8, Endian.little),
      maxBandwidth = body.getUint32(12, Endian.little),
      decimationStages = body.getUint32(16, Endian.little).clamp(1, _maxDecimationStages),
      maxGain = body.getUint32(24, Endian.little),
      minFrequency = body.getUint32(28, Endian.little),
      maxFrequency = body.getUint32(32, Endian.little),
      minIqDecimation = body.getUint32(40, Endian.little),
      forcedIqFormat = body.getUint32(44, Endian.little);

  /// The sweep widths on offer, ascending: halvings of the analog bandwidth.
  /// Clients disagree on whether the stage count is itself a valid index, so
  /// the last halving is left out rather than risked. Never empty for a
  /// receiver with any bandwidth.
  List<int> get spans => [
    for (var f = decimationStages - 1; f >= 0; f--)
      if (maxBandwidth >> f > 0) maxBandwidth >> f,
  ];

  /// The IQ is thrown away, so the narrowest the server allows — or, from a
  /// server that sends no spectrum below [_oldServerMinIqRate], the narrowest
  /// still that fast.
  int get iqDecimation {
    var d = decimationStages - 1;
    if (serverBuild < _spyServerSpectrumAnyIq) {
      while (d > minIqDecimation && maxSampleRate >> d < _oldServerMinIqRate) {
        d--;
      }
    }
    return math.max(d, minIqDecimation);
  }
}

class SpyServerSession implements SpectrumSession, SdrTuner {
  final EquipmentSink sink;
  final SdrConfig config;

  /// The gain step to set when this client may; null leaves the server's.
  final int? gain;

  SpyServerSession(this.sink, this.config, {this.gain});

  final _buffer = BytesBuilder(copy: false);
  Uint8List _pending = Uint8List(0);

  /// Nothing more is read: the connection is being dropped.
  bool _dead = false;

  Timer? _ping;

  /// Streaming was asked for, and whether the session got somewhere since the
  /// last ping — a sweep, or a fresh start's grace. See [spyServerPingInterval].
  bool _streaming = false;
  bool _swept = true;

  _Device? _device;

  /// Whether this client may retune the receiver and set its gain. Only one
  /// may: a second client sees what the first has tuned.
  bool _canControl = false;
  int _deviceCenterHz = 0;

  SdrSpectrum? _spectrum;
  bool _wanted = false;
  int _aliveMillis = 0;

  @override
  Duration? get expectedUpdateInterval => null;

  @override
  void startUpdates() {
    final body = ByteData(4)..setUint32(0, spyServerProtocolVersion, Endian.little);
    sink.send(spyServerCommand(SpyServerCommand.hello, [...body.buffer.asUint8List(), ...ham2kMachineName.codeUnits]));
    _ping ??= Timer.periodic(spyServerPingInterval, (_) {
      if (_dead) return;
      // Something that accepts the hello and never answers it — another
      // service on the port, waiting for its own protocol — is not a
      // SpyServer, and would otherwise read as one still being waited for.
      if (!_swept && _spectrum == null) return _drop(t.settings.station.spyServerNotAServer);
      if (!_swept && _streaming) return _drop(t.settings.station.spyServerNoSpectrum);
      _swept = false;
      sink.send(spyServerCommand(SpyServerCommand.ping, const []));
    });
  }

  @override
  void stopUpdates() {}

  @override
  void teardown() {
    _ping?.cancel();
    _ping = null;
    stopSpectrum();
  }

  @override
  void handleData(Uint8List chunk) {
    if (_dead) return;
    _buffer.add(_pending);
    _buffer.add(chunk);
    final bytes = _buffer.takeBytes();
    var at = 0;
    // What is left over is kept however a message ends, a throw included:
    // lost, the next chunk's bytes would be read from the middle of one.
    try {
      while (!_dead && bytes.length - at >= _headerSize) {
        final header = ByteData.sublistView(bytes, at, at + _headerSize);
        final version = header.getUint32(0, Endian.little);
        final kind = header.getUint32(4, Endian.little) & 0xFFFF;
        final size = header.getUint32(16, Endian.little);
        // Every header carries the version. Wrong on the first message, this
        // is not a server this speaks to; wrong later, the stream is out of
        // step.
        if (version >> 24 != 2) {
          _drop(_device == null ? t.settings.station.spyServerNotAServer : t.settings.station.spyServerGarbled);
          break;
        }
        if (size > _maxBody) {
          _drop(t.settings.station.spyServerGarbled);
          break;
        }
        if (bytes.length - at - _headerSize < size) break;
        final body = Uint8List.sublistView(bytes, at + _headerSize, at + _headerSize + size);
        at += _headerSize + size;
        _message(kind, body, version & 0xFFFF);
      }
    } finally {
      _pending = _dead ? Uint8List(0) : Uint8List.fromList(Uint8List.sublistView(bytes, at));
    }
  }

  /// Ends the session: no marker to find a next message by, and nothing
  /// else to say the next try would go differently. The connection is made
  /// again from the hello, and [why] is shown until a sweep is drawn.
  void _drop(String why) {
    _dead = true;
    _streaming = false;
    if (sink case final SdrSink sdr) sdr.dropConnection(why);
  }

  void _message(int kind, Uint8List body, int serverBuild) {
    _alive();
    switch (kind) {
      case SpyServerMessage.deviceInfo:
        if (body.length < 48) return _drop(t.settings.station.spyServerGarbled);
        final data = ByteData.sublistView(body);
        final device = _Device(data, serverBuild: serverBuild);
        if (data.getUint32(0, Endian.little) == 0) return _drop(t.settings.station.spyServerNoDevice);
        if (device.spans.isEmpty) return _drop(t.settings.station.spyServerGarbled);
        _device = device;
        sink.reportDiagnostic('server build $serverBuild, device type ${data.getUint32(0, Endian.little)}, ${device.maxSampleRate} S/s');
      case SpyServerMessage.clientSync:
        if (body.length < 36) return _drop(t.settings.station.spyServerGarbled);
        final data = ByteData.sublistView(body);
        final could = _canControl;
        _canControl = data.getUint32(0, Endian.little) != 0;
        _deviceCenterHz = data.getUint32(8, Endian.little);
        if (could != _canControl || _spectrum == null) {
          sink.reportDiagnostic(_canControl ? 'in control of the receiver' : 'another client controls the receiver');
        }
        if (_spectrum == null && _device != null) {
          _ready(_device!);
        } else {
          if (_canControl && !could) _sendGain();
          _spectrum?.recheck();
        }
      case SpyServerMessage.uint8Fft:
        _swept = true;
        _spectrum?.addSweep(_levels(body));
    }
  }

  /// The handshake is done: the streams are set up, and the spectrum starts
  /// if a display was already waiting for it.
  void _ready(_Device device) {
    _spectrum = SdrSpectrum(
      config: config,
      tuner: this,
      sink: sink is SpectrumSink ? sink as SpectrumSink : null,
      vfo: sink is SdrSink ? sink as SdrSink : null,
      rates: device.spans,
      serverSweeps: true,
    );
    final iqFormat = device.forcedIqFormat != 0 ? device.forcedIqFormat : _formatUint8;
    for (final (setting, value) in [
      (SpyServerSetting.iqFormat, iqFormat),
      (SpyServerSetting.iqDecimation, device.iqDecimation),
      (SpyServerSetting.fftFormat, _formatUint8),
      (SpyServerSetting.fftDisplayPixels, spyServerFftPixels),
      (SpyServerSetting.fftDbOffset, spyServerDbOffset),
      (SpyServerSetting.fftDbRange, spyServerDbRange),
      (SpyServerSetting.streamingMode, _streamFftAndIq),
    ]) {
      sink.send(spyServerSetSetting(setting, value));
    }
    if (_canControl) _sendGain();
    if (_wanted) _start();
  }

  /// Only the client in control sets it; one that gains control later sets
  /// it then, or the receiver keeps the last client's. A receiver with no
  /// steps has no gain to set.
  void _sendGain() {
    if ((gain, _device) case (final step?, final device?)) {
      if (device.maxGain == 0) return sink.reportDiagnostic('gain step $step not set: the receiver has no gain steps');
      if (step > device.maxGain) sink.reportDiagnostic('gain step $step is past the receiver\'s last, ${device.maxGain}');
      sink.send(spyServerSetSetting(SpyServerSetting.gain, step.clamp(0, device.maxGain)));
    }
  }

  void _start() {
    _spectrum!.start();
    _streaming = true;
    _swept = true;
    sink.send(spyServerSetSetting(SpyServerSetting.streamingEnabled, 1));
  }

  Float32List _levels(Uint8List bins) {
    final out = Float32List(bins.length);
    for (var i = 0; i < bins.length; i++) {
      out[i] = -spyServerDbOffset - spyServerDbRange + bins[i] * spyServerDbRange / 255;
    }
    return out;
  }

  /// Any message counts, a pong included. Throttled: the watch only needs to
  /// hear that the server has not gone quiet.
  void _alive() {
    final now = realNowMillis();
    if (now - _aliveMillis > 1000) {
      _aliveMillis = now;
      sink.reportAlive();
    }
  }

  @override
  int tunable(int hz) {
    final device = _device;
    final spectrum = _spectrum;
    if (device == null || spectrum == null) return hz;
    final half = spectrum.rate ~/ 2;
    // Inside the range the server allows — unless it reports none, as some
    // leave both ends at zero — and for a client that may not retune, inside
    // what the receiver already hears too.
    var (low, high) = device.maxFrequency > device.minFrequency ? (device.minFrequency + half, device.maxFrequency - half) : (0, 0x7FFFFFFF);
    if (!_canControl) {
      final hears = device.maxBandwidth ~/ 2 - half;
      (low, high) = (math.max(low, _deviceCenterHz - hears), math.min(high, _deviceCenterHz + hears));
    }
    // The server's own clamp, which lands on the top when the range is
    // narrower than the window: then the dial is far from it, and said so.
    return math.min(math.max(hz, low), high);
  }

  /// The window first: with the spectrum streaming, the receiver follows it,
  /// and the IQ channel is then placed inside what it hears.
  @override
  void tuneDevice(int hz) {
    sink.send(spyServerSetSetting(SpyServerSetting.fftFrequency, hz));
    sink.send(spyServerSetSetting(SpyServerSetting.iqFrequency, hz));
  }

  /// [rate] is one of [_Device.spans]: the server's halving that gives it.
  @override
  void setSampleRate(int rate) {
    final device = _device;
    if (device == null) return;
    var f = 0;
    while (device.maxBandwidth >> f > rate) {
      f++;
    }
    sink.send(spyServerSetSetting(SpyServerSetting.fftDecimation, f));
  }

  @override
  String? get spectrumUnavailable => null;

  /// Nothing to offer until the server has said what its receiver can do.
  @override
  SpectrumCapabilities get spectrumCapabilities => _spectrum?.capabilities ?? const SpectrumCapabilities(spansHz: [], refMinDb: 0, refMaxDb: 0, refStepDb: 1);

  @override
  void startSpectrum() {
    if (_wanted) return;
    _wanted = true;
    if (_spectrum != null) _start();
  }

  @override
  void stopSpectrum() {
    if (!_wanted) return;
    _wanted = false;
    _streaming = false;
    if (_spectrum case final spectrum?) {
      sink.send(spyServerSetSetting(SpyServerSetting.streamingEnabled, 0));
      spectrum.stop();
    }
  }

  @override
  bool setSpectrum(SpectrumRequest request) => _spectrum?.set(request) ?? false;
}
