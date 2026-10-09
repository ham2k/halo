// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A FlexRadio's panadapter, mirrored through DAX IQ — docs/design/cat.md
// § Spectrum.
//
// This app attaches to a slice another client owns (SmartSDR, AetherSDR),
// and the radio sends a panadapter's own FFT stream only to the client that
// owns it: a bound client gets every `display pan` status and none of the
// data, and a `display pan create` it sends lands in the owner's window.
// DAX IQ is the one stream a bound client can open on someone else's pan —
// captured on a FLEX-6600 (4.2.20): `stream create type=dax_iq` answers with
// a stream id and the pan's IQ follows on our UDP port. So the spectrum is
// computed here, and it shows what the operator's panadapter is pointed at.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart' show nowMillis;
import 'package:halo_i18n/halo_i18n.dart';

import '../spectrum.dart';
import '../spectrum_fft.dart';

/// The radio's four DAX IQ channels.
const flexDaxIqChannels = [1, 2, 3, 4];

/// The rates a DAX IQ stream runs at.
const flexDaxIqRates = [24000, 48000, 96000, 192000];

/// What is cut from each edge of a DAX IQ stream: the radio's decimation
/// filter rolls the outer sixteenth off — measured on a FLEX-6600 at 48 kHz,
/// 30 dB down at the edge and flat a sixteenth in. Shown, it reads as a
/// band with no signals in it.
const flexDaxIqTrim = 1 / 16;

/// The half-widths actually shown for each of [flexDaxIqRates].
final flexDaxIqSpans = [for (final rate in flexDaxIqRates) _visibleHalfWidth(rate)];

int _visibleHalfWidth(int rate) => (rate * (1 - 2 * flexDaxIqTrim) / 2).round();

/// Sweeps are pooled to at most this many points: a 192 kHz stream's
/// 8192-point transform is far finer than any panel is wide.
const _maxPoints = 1024;

const _sweepsPerSecond = {SpectrumSpeed.slow: 8, SpectrumSpeed.mid: 15, SpectrumSpeed.fast: 25};

/// How far below the noise the display starts, and how tall it is — the
/// shape of the radio's own panadapter at its default levels.
const _floorBelowNoiseDb = 10.0;
const _displayRangeDb = 80.0;

class FlexDaxSpectrum {
  /// Sends a command; [onReply] gets the answer's code and body.
  final void Function(String command, {void Function(int code, String body)? onReply}) send;
  final SpectrumSink? sink;

  FlexDaxSpectrum({required this.send, required this.sink});

  bool _wanted = false;
  bool get wanted => _wanted;

  /// The pan of the slice this node follows, from the slice's status.
  String? _pan;

  /// What each pan last said, merged from pushes that carry only what changed.
  final _pans = <String, Map<String, String>>{};

  /// The channel this session assigned to the pan, to hand back on stop —
  /// null when the pan already had one, which is then someone else's.
  int? _assignedChannel;
  bool _creating = false;
  String? _stream;

  /// [_stream] as the number a packet carries: compared as text, an id
  /// with a leading zero would never match.
  int? _streamId;

  /// Bumped by every [_release]: a `stream create` answered after it is for
  /// a display, or a pan, that is gone — its stream is handed straight back
  /// rather than adopted on a channel already given up.
  int _epoch = 0;

  /// What the radio said about streams before we knew one was ours: it
  /// pushes a new stream's status ahead of the `stream create` reply
  /// (captured on a FLEX-6600), and that status is the only word on its rate.
  final _unclaimed = <String, Map<String, String>>{};

  /// A span asked for before the stream existed, sent once it does.
  int? _pendingRate;

  /// The radio refused the stream. Not asked again until the display, or
  /// the pan, changes: pan statuses arrive several times a second, and each
  /// one would otherwise ask again.
  bool _refused = false;
  int _rate = 48000;
  bool _littleEndian = true;
  IqSpectrum? _fft;
  double? _noise;
  SpectrumSettings _settings = const SpectrumSettings(speed: SpectrumSpeed.mid, refLevelDb: 0);

  bool _socketReady = false;

  /// The UDP socket could not be opened — remembered, since the session does
  /// not try again until it resubscribes, and a display that opens later
  /// must say so rather than wait.
  bool _socketFailed = false;

  /// The session's handshake is done: the radio refuses a `sub` before it.
  bool _handshakeDone = false;

  /// Whether the radio has described the slice at all, so "no panadapter"
  /// is said of a slice that has none — not of one not heard from yet.
  bool _sliceSeen = false;

  /// Runs from the stream's grant to its first packet. A granted stream
  /// whose IQ never arrives — a firewall, a network permission — is
  /// otherwise a display that waits forever.
  Timer? _watchdog;
  static const _firstPacketDeadline = Duration(seconds: 5);
  bool _heard = false;

  SpectrumCapabilities get capabilities => SpectrumCapabilities(
    spansHz: flexDaxIqSpans,
    refMinDb: -30,
    refMaxDb: 30,
    refStepDb: 1,
    speeds: {SpectrumSpeed.slow, SpectrumSpeed.mid, SpectrumSpeed.fast},
  );

  void start() {
    if (_wanted) return;
    _wanted = true;
    if (_handshakeDone) send('sub pan all');
    // Said again on every start: a display that reopened reads the settings
    // fresh, and nothing below changes them to prompt a report.
    sink?.reportSpectrumSettings(_settings);
    if (_socketFailed) sink?.reportSpectrumProblem(t.settings.station.spectrumNoUdp);
    _settle();
  }

  /// From the session's own subscribe, after the handshake and on every
  /// resync — the pan subscription, like the slice one, is the radio's to
  /// forget.
  void subscribe() {
    _handshakeDone = true;
    if (_wanted) send('sub pan all');
  }

  void stop() {
    if (!_wanted) return;
    _wanted = false;
    _release();
    send('unsub pan all');
    sink?.reportSpectrumProblem(null);
  }

  /// False when nothing is running to set.
  bool set(SpectrumRequest request) {
    if (!_wanted) return false;
    if (request.refLevelDb case final ref?) _report(_settings.copyWith(refLevelDb: capabilities.snapRef(ref)));
    if (request.speed case final speed?) {
      _report(_settings.copyWith(speed: speed));
      _fft?.hop = _rate ~/ _sweepsPerSecond[speed]!;
    }
    if (request.spanHz case final span?) {
      final rate = flexDaxIqRates[flexDaxIqSpans.indexOf(capabilities.snapSpan(span))];
      if (_stream case final stream?) {
        send('stream set 0x$stream daxiq_rate=$rate');
      } else {
        _pendingRate = rate;
      }
    }
    return true;
  }

  /// The UDP socket the IQ arrives on is open — [FlexRadioSession] opens it
  /// for the meters, and a stream created before it would send to nowhere.
  void socketReady() {
    _socketReady = true;
    _socketFailed = false;
    _settle();
  }

  void socketLost() {
    _socketReady = false;
    _socketFailed = false;
    if (_wanted) _release();
  }

  /// The UDP socket could not be opened, so no IQ can arrive: said, rather
  /// than waiting on a socket that is not coming.
  void socketUnavailable() {
    _socketReady = false;
    _socketFailed = true;
    if (_wanted) sink?.reportSpectrumProblem(t.settings.station.spectrumNoUdp);
  }

  void slicePan(String? pan) {
    final firstWord = !_sliceSeen;
    _sliceSeen = true;
    if (pan == _pan) {
      // A slice first heard of with no pan is news even though nothing moved.
      if (firstWord) _settle();
      return;
    }
    if (_wanted && _pan != null) _release();
    _pan = pan;
    _settle();
  }

  /// `display pan 0x40000000 center=14.218000 bandwidth=0.064120 … daxiq_channel=0 …`
  void panStatus(String id, Map<String, String> fields) {
    if (fields.containsKey('removed')) {
      _pans.remove(id);
      if (id == _pan) _release();
      return;
    }
    (_pans[id] ??= {}).addAll(fields);
    if (id == _pan) _settle();
  }

  /// `stream 0x20000000 type=dax_iq daxiq_channel=1 pan=0x40000000 daxiq_rate=48000 payload_endian=little`
  void streamStatus(String id, Map<String, String> fields) {
    final key = id.replaceFirst('0x', '').toLowerCase();
    if (key != _stream) {
      if (_creating) {
        if (_unclaimed.length >= 8 && !_unclaimed.containsKey(key)) _unclaimed.remove(_unclaimed.keys.first);
        (_unclaimed[key] ??= {}).addAll(fields);
      }
      return;
    }
    _applyStream(fields);
  }

  void _applyStream(Map<String, String> fields) {
    if (fields.containsKey('removed')) {
      _stream = null;
      _fft = null;
      _settle();
      return;
    }
    if (int.tryParse(fields['daxiq_rate'] ?? '') case final rate? when rate != _rate) {
      _rate = rate;
      _fft = null;
      _report(_settings.copyWith(spanHz: _visibleHalfWidth(rate)));
    }
    if (fields['payload_endian'] case final endian?) _littleEndian = endian != 'big';
  }

  /// Creates the stream once everything it needs is known: the slice's pan,
  /// what that pan says, and a socket to send to.
  void _settle() {
    if (!_wanted || !_socketReady || _stream != null || _creating || _refused) return;
    final pan = _pan;
    final status = pan == null ? null : _pans[pan];
    if (pan == null || status == null) {
      if (pan == null && _sliceSeen) sink?.reportSpectrumProblem(t.settings.station.spectrumNoPanadapter);
      return;
    }
    var channel = int.tryParse(status['daxiq_channel'] ?? '') ?? 0;
    if (channel == 0) {
      final taken = {for (final p in _pans.values) int.tryParse(p['daxiq_channel'] ?? '') ?? 0};
      final free = flexDaxIqChannels.where((c) => !taken.contains(c));
      if (free.isEmpty) {
        sink?.reportSpectrumProblem(t.settings.station.spectrumNoDaxChannel);
        return;
      }
      channel = free.first;
      _assignedChannel = channel;
      final epoch = _epoch;
      send(
        'display pan set $pan daxiq_channel=$channel',
        onReply: (code, _) {
          if (code == 0 || epoch != _epoch || !_wanted) return;
          // Not ours to give back, and the stream asked for beside it would
          // be on a channel no pan feeds.
          _assignedChannel = null;
          _release();
          _refused = true;
          sink?.reportSpectrumProblem(t.settings.station.spectrumStreamRefused(code: code.toRadixString(16).toUpperCase()));
        },
      );
    }
    sink?.reportSpectrumProblem(null);
    _creating = true;
    _unclaimed.clear();
    final epoch = _epoch;
    send(
      'stream create type=dax_iq daxiq_channel=$channel',
      onReply: (code, body) {
        final stream = body.replaceFirst('0x', '').toLowerCase();
        if (epoch != _epoch || !_wanted) {
          if (code == 0 && stream.isNotEmpty) send('stream remove 0x$stream');
          return;
        }
        _creating = false;
        if (code != 0 || stream.isEmpty) {
          // Refused: the channel goes back now, and the operator is told,
          // rather than a display that waits for IQ that is not coming.
          if (_assignedChannel != null) send('display pan set $pan daxiq_channel=0');
          _assignedChannel = null;
          _refused = true;
          sink?.reportSpectrumProblem(t.settings.station.spectrumStreamRefused(code: code.toRadixString(16).toUpperCase()));
          return;
        }
        _stream = stream;
        _streamId = int.tryParse(stream, radix: 16);
        _heard = false;
        _watchdog?.cancel();
        _watchdog = Timer(_firstPacketDeadline, () {
          if (_wanted && _stream == stream) sink?.reportSpectrumProblem(t.settings.station.spectrumNoUdp);
        });
        if (_unclaimed.remove(stream) case final fields?) _applyStream(fields);
        _unclaimed.clear();
        if (_pendingRate case final rate? when rate != _rate) send('stream set 0x$stream daxiq_rate=$rate');
        _pendingRate = null;
      },
    );
    _report(_settings.copyWith(spanHz: _visibleHalfWidth(_rate)));
  }

  /// Hands back what [_settle] took, in reverse.
  void _release() {
    _watchdog?.cancel();
    _watchdog = null;
    _streamId = null;
    _epoch++;
    _refused = false;
    _creating = false;
    _unclaimed.clear();
    if (_stream case final stream?) send('stream remove 0x$stream');
    if ((_assignedChannel, _pan) case (_?, final pan?)) send('display pan set $pan daxiq_channel=0');
    _stream = null;
    _assignedChannel = null;
    _fft = null;
    _noise = null;
  }

  /// One UDP datagram. Returns whether it was this stream's, so the meter
  /// codec does not parse it as well.
  bool packet(Uint8List data) {
    if (data.length < 28) return false;
    final bytes = ByteData.sublistView(data);
    final header = bytes.getUint32(0);
    // IF data with a stream id and a class id: the shape of a DAX IQ packet.
    if (header >> 28 != 1 || header & 0x08000000 == 0) return false;
    final classCode = bytes.getUint16(14);
    if (classCode < 0x02E3 || classCode > 0x02E6) return false;
    if (bytes.getUint32(4) != _streamId) return true;
    // The first packet ends the wait, and any word that it was not coming:
    // IQ that arrives late still arrives.
    if (!_heard) {
      _heard = true;
      _watchdog?.cancel();
      _watchdog = null;
      sink?.reportSpectrumProblem(null);
    }
    var offset = 16;
    if ((header >> 22) & 3 != 0) offset += 4;
    if ((header >> 20) & 3 != 0) offset += 8;
    final end = math.min(data.length, (header & 0xffff) * 4) - (header & 0x04000000 != 0 ? 4 : 0);
    if (end <= offset) return true;
    final count = (end - offset) ~/ 4;
    final samples = Float32List(count);
    final endian = _littleEndian ? Endian.little : Endian.big;
    for (var i = 0; i < count; i++) {
      final sample = bytes.getFloat32(offset + i * 4, endian);
      // One NaN would ride the noise average forever and blank the display.
      samples[i] = sample.isFinite ? sample : 0;
    }
    final fft = _fft ??= IqSpectrum(size: _sizeFor(_rate), hop: _rate ~/ _sweepsPerSecond[_settings.speed ?? SpectrumSpeed.mid]!);
    fft.add(samples, _emit);
    return true;
  }

  static int _sizeFor(int rate) {
    var size = 256;
    while (size < rate ~/ 24) {
      size <<= 1;
    }
    return size;
  }

  void _emit(Float32List levels) {
    final status = _pans[_pan];
    final centerMhz = double.tryParse(status?['center'] ?? '');
    if (centerMhz == null) return;
    final trim = (levels.length * flexDaxIqTrim).round();
    final pooled = _pool(Float32List.sublistView(levels, trim, levels.length - trim));
    final sorted = Float32List.fromList(pooled)..sort();
    final noise = sorted[sorted.length ~/ 5];
    if (!noise.isFinite) return;
    _noise = _noise == null ? noise : _noise! * 0.9 + noise * 0.1;
    final floor = _noise! - _floorBelowNoiseDb - (_settings.refLevelDb ?? 0);
    final center = (centerMhz * 1e6).round();
    sink?.reportSpectrum(
      SpectrumFrame(
        lowHz: center - _visibleHalfWidth(_rate),
        highHz: center + _visibleHalfWidth(_rate),
        levels: pooled,
        floorDb: floor,
        ceilingDb: floor + _displayRangeDb,
        atMillis: nowMillis(),
      ),
    );
  }

  /// The loudest bin of each group: a narrow carrier has to survive pooling.
  static Float32List _pool(Float32List levels) {
    if (levels.length <= _maxPoints) return levels;
    final factor = (levels.length / _maxPoints).ceil();
    final out = Float32List(levels.length ~/ factor);
    for (var i = 0; i < out.length; i++) {
      var peak = levels[i * factor];
      for (var j = 1; j < factor; j++) {
        peak = math.max(peak, levels[i * factor + j]);
      }
      out[i] = peak;
    }
    return out;
  }

  void _report(SpectrumSettings settings) {
    if (settings == _settings) return;
    _settings = settings;
    sink?.reportSpectrumSettings(settings);
  }

  /// For [FlexRadioSession.teardown]: hands the stream and the channel back
  /// over the connection while it is still open.
  void teardown() {
    if (_wanted) _release();
    _wanted = false;
  }
}
