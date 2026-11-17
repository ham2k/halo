// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A FlexRadio panadapter of HaLo's own station, drawn from the radio's own
// FFT — docs/design/cat.md § Spectrum.
//
// The radio sends a panadapter's FFT (VITA class 0x8003, its stream id the
// pan's) only to the GUI client that owns it, which on HaLo's own station
// is HaLo. A slice HaLo follows on another station has no FFT to take and
// is mirrored through DAX IQ instead (flex_spectrum.dart). The pan is
// HaLo's alone, so its width and rate are set to what the displays want.

import 'dart:async';
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart' show nowMillis;
import 'package:halo_i18n/halo_i18n.dart';

import '../spectrum.dart';
import '../spectrum_fft.dart';
import 'flex_spectrum.dart';

/// The half-widths offered: from a single signal to a whole HF sub-band.
const flexPanSpans = [12000, 24000, 48000, 96000, 192000, 384000];

/// The window the pan's rows span. Fixed and wide, so a level is never
/// clipped and the display scales locally, as every other radio's does; at
/// [_rows] rows that is a third of a dB a row.
const _minDbm = -150, _maxDbm = -10;

/// The pan's points and rows: the points a sweep is drawn with, and the
/// steps its levels come in. 2048 points is the radio's own resolution, a
/// 2048th of the span (RadioRoom, 4.3.16: a carrier is a 1024th of the span
/// wide at 6 dB down whether asked for 1024, 2048 or 4096 points). Fewer
/// pools its bins, and a waterfall stretched over a Retina pane blurs; more
/// only interpolates. The radio sends no more than 4096 whatever is asked.
const _points = 2048, _rows = 400;

const _framesPerSecond = {SpectrumSpeed.slow: 8, SpectrumSpeed.mid: 15, SpectrumSpeed.fast: 25};

class FlexPanSpectrum implements FlexSliceSpectrum {
  /// Sends a command; [onReply] gets the answer's code and body.
  final void Function(String command, {void Function(int code, String body)? onReply}) send;
  final SpectrumSink? sink;

  FlexPanSpectrum({required this.send, required this.sink, Map<String, Map<String, String>>? pans}) : _pans = pans ?? {};

  bool _wanted = false;
  @override
  bool get wanted => _wanted;

  /// The pan of the slice this node follows, from the slice's status.
  String? _pan;
  int? _panId;

  /// What each pan last said, merged from pushes that carry only what
  /// changed, and from the radio's acceptance of HaLo's own sets: the
  /// connection's record (FlexRadio), shared by every slice's scope on it,
  /// into which the connection alone merges the radio's statuses.
  final Map<String, Map<String, String>> _pans;

  /// What [pan] is about to be, for the width and speed the displays show:
  /// what the radio said, under HaLo's sets it has not yet answered.
  Map<String, String>? _status(String? pan) {
    final said = _pans[pan], pending = _pending[pan];
    if (pending == null || pending.isEmpty) return said;
    return {...?said, for (final MapEntry(:key, value: (_, value)) in pending.entries) key: value};
  }

  /// The pan [_pan] was last shaped for, so each status does not set it again.
  String? _shaped;

  bool _socketReady = false;
  bool _socketFailed = false;
  bool _handshakeDone = false;
  bool _sliceSeen = false;

  /// Runs from the shaping of the pan to its first frame: FFT that never
  /// arrives — a firewall, a network permission — is otherwise a display
  /// that waits forever.
  Timer? _watchdog;
  static const _firstFrameDeadline = Duration(seconds: 5);
  bool _heard = false;

  /// The sweep being put together: the radio splits one across packets.
  Uint16List? _bins;
  Uint8List? _have;
  int _frame = -1, _filled = 0;

  final _noise = NoiseFloor();
  SpectrumSettings _settings = const SpectrumSettings(speed: SpectrumSpeed.mid, refLevelDb: 0);

  @override
  SpectrumCapabilities get capabilities => SpectrumCapabilities(
    spansHz: flexPanSpans,
    refMinDb: -30,
    refMaxDb: 30,
    refStepDb: 1,
    speeds: {SpectrumSpeed.slow, SpectrumSpeed.mid, SpectrumSpeed.fast},
    canRecenter: true,
    // The pan is HaLo's own: no other window changes with its width.
    autoSpan: true,
  );

  @override
  void start() {
    if (_wanted) return;
    _wanted = true;
    if (_handshakeDone) send('sub pan all');
    sink?.reportSpectrumSettings(_settings);
    if (_socketFailed) sink?.reportSpectrumProblem(t.settings.station.spectrumNoUdp);
    _settle();
  }

  @override
  void subscribe() {
    _handshakeDone = true;
    if (_wanted) send('sub pan all');
  }

  @override
  void stop() {
    if (!_wanted) return;
    _wanted = false;
    _release();
    sink?.reportSpectrumProblem(null);
  }

  @override
  bool set(SpectrumRequest request) {
    if (!_wanted) return false;
    if (request.refLevelDb case final ref?) _report(_settings.copyWith(refLevelDb: capabilities.snapRef(ref)));
    if (request.speed case final speed?) _askedSpeed = speed;
    if (request.spanHz case final span?) _askedSpan = capabilities.snapSpan(span);
    final pan = _pan;
    if (pan == null || _shaped != pan) return true;
    if (request.speed != null) _askSpeed(pan);
    if (request.spanHz != null) _askSpan(pan);
    if (request.centerHz case final hz?) _setPan(pan, 'center', (hz / 1e6).toStringAsFixed(6));
    return true;
  }

  /// What the displays last asked for, given to every pan as it is shaped:
  /// asked once, before the slice names its pan or for the pan it had, a
  /// span would otherwise never reach the pan the scope draws.
  SpectrumSpeed? _askedSpeed;
  int? _askedSpan;

  void _askSpeed(String pan) {
    if (_askedSpeed case final speed?) _setPan(pan, 'fps', '${_framesPerSecond[speed]}');
  }

  void _askSpan(String pan) {
    if (_askedSpan case final span?) _setPan(pan, 'bandwidth', (span * 2 / 1e6).toStringAsFixed(6));
  }

  /// The fields set and not yet answered, by pan: the latest set's number and
  /// value.
  final _pending = <String, Map<String, (int, String)>>{};
  int _sets = 0;

  /// The radio sends no status to the client that made a change (captured
  /// on RadioRoom, 4.3.16): its answer is the only word that the change
  /// took, and without it a pan said to have 20 rows that has 400 reads its
  /// levels twenty times too far down. A refusal leaves what the radio last
  /// said, never HaLo's own earlier guess, which a second refused set in a
  /// row would otherwise put back.
  /// [status] is the field's name in a status, where the radio's differs.
  void _setPan(String pan, String field, String value, {String? status}) {
    final key = status ?? field, number = ++_sets;
    (_pending[pan] ??= {})[key] = (number, value);
    send(
      'display pan set $pan $field=$value',
      onReply: (code, _) {
        // A pan removed meanwhile is not brought back by its answer.
        if (code == 0) _pans[pan]?[key] = value;
        if (_pending[pan]?[key]?.$1 == number) _pending[pan]!.remove(key);
        if (pan == _pan) _reportPan();
      },
    );
    _reportPan();
  }

  @override
  void socketReady() {
    _socketReady = true;
    _socketFailed = false;
    _settle();
  }

  @override
  void socketLost() {
    _socketReady = false;
    _socketFailed = false;
    if (_wanted) _release();
  }

  @override
  void socketUnavailable() {
    _socketReady = false;
    _socketFailed = true;
    if (_wanted) sink?.reportSpectrumProblem(t.settings.station.spectrumNoUdp);
  }

  @override
  void slicePan(String? pan) {
    final firstWord = !_sliceSeen;
    _sliceSeen = true;
    if (pan == _pan) {
      if (firstWord) _settle();
      return;
    }
    if (_wanted) _release();
    _pan = pan;
    _panId = pan == null ? null : int.tryParse(pan.replaceFirst('0x', ''), radix: 16);
    _settle();
  }

  @override
  void panStatus(String id, Map<String, String> fields) {
    if (fields.containsKey('removed')) {
      _pending.remove(id);
      if (id == _pan && _wanted) {
        _release();
        sink?.reportSpectrumProblem(t.settings.station.spectrumNoPanadapter);
      }
      return;
    }
    if (id != _pan) return;
    _settle();
    if (!_wanted) return;
    // The radio sets the window back on its own (with `rfgain` and `pre`):
    // left there, a strong signal is cut off at its top.
    if (_shaped == id) {
      for (final (field, value) in [('min_dbm', _minDbm), ('max_dbm', _maxDbm)]) {
        if (_pending[id]?.containsKey(field) ?? false) continue;
        if (double.tryParse(fields[field] ?? '') case final dbm? when dbm != value) _setPan(id, field, '$value');
      }
    }
    _reportPan();
  }

  @override
  void streamStatus(String id, Map<String, String> fields) {}

  /// Shapes the pan once everything it needs is known: the slice's pan,
  /// what that pan says, and a socket for its FFT to arrive on.
  void _settle() {
    if (!_wanted || !_socketReady) return;
    final pan = _pan;
    if (pan == null || _pans[pan] == null) {
      if (pan == null && _sliceSeen) sink?.reportSpectrumProblem(t.settings.station.spectrumNoPanadapter);
      return;
    }
    if (_shaped == pan) return;
    _shaped = pan;
    sink?.reportSpectrumProblem(null);
    // One field a command: the radio's own clients set them one at a time.
    _setPan(pan, 'xpixels', '$_points', status: 'x_pixels');
    _setPan(pan, 'ypixels', '$_rows', status: 'y_pixels');
    _setPan(pan, 'min_dbm', '$_minDbm');
    _setPan(pan, 'max_dbm', '$_maxDbm');
    _askSpeed(pan);
    _askSpan(pan);
    _heard = false;
    _watchdog?.cancel();
    _watchdog = Timer(_firstFrameDeadline, () {
      if (_wanted && _shaped == pan && !_heard) sink?.reportSpectrumProblem(t.settings.station.spectrumNoUdp);
    });
    _reportPan();
  }

  void _release() {
    _watchdog?.cancel();
    _watchdog = null;
    _shaped = null;
    _bins = null;
    _have = null;
    _frame = -1;
    _noise.reset();
  }

  /// The pan's width and speed, as it last said.
  void _reportPan() {
    final status = _status(_pan);
    if (status == null) return;
    var settings = _settings;
    if (double.tryParse(status['bandwidth'] ?? '') case final mhz?) settings = settings.copyWith(spanHz: (mhz * 1e6 / 2).round());
    if (int.tryParse(status['fps'] ?? '') case final fps?) {
      final speed = _framesPerSecond.entries.reduce((a, b) => (a.value - fps).abs() <= (b.value - fps).abs() ? a : b).key;
      settings = settings.copyWith(speed: speed);
    }
    _report(settings);
  }

  /// One UDP datagram. Returns whether it was this pan's FFT, so the meter
  /// codec does not parse it as well.
  @override
  bool packet(Uint8List data) {
    if (data.length < 40 || _panId == null) return false;
    final bytes = ByteData.sublistView(data);
    final header = bytes.getUint32(0);
    // Extension data with a stream id and a class id, of the FFT class.
    if (header >> 28 != 3 || header & 0x08000000 == 0 || bytes.getUint16(14) != 0x8003) return false;
    if (bytes.getUint32(4) != _panId) return false;
    if (!_wanted) return true;
    var offset = 16;
    if ((header >> 22) & 3 != 0) offset += 4;
    if ((header >> 20) & 3 != 0) offset += 8;
    final end = (data.length < (header & 0xffff) * 4 ? data.length : (header & 0xffff) * 4) - (header & 0x04000000 != 0 ? 4 : 0);
    if (end < offset + 12) return true;
    final start = bytes.getUint16(offset), count = bytes.getUint16(offset + 2), total = bytes.getUint16(offset + 6);
    final frame = bytes.getUint32(offset + 8);
    if (total == 0 || bytes.getUint16(offset + 4) != 2) return true;
    var bins = _bins, have = _have;
    if (frame != _frame || bins == null || have == null || bins.length != total) {
      bins = _bins = Uint16List(total);
      have = _have = Uint8List(total);
      _frame = frame;
      _filled = 0;
    }
    offset += 12;
    // A bin counted once however often it comes: a lost packet and a
    // repeated one would otherwise make a whole sweep with a hole at the top.
    for (var i = 0; i < count && start + i < total && offset + 2 <= end; i++, offset += 2) {
      bins[start + i] = bytes.getUint16(offset);
      if (have[start + i] == 0) {
        have[start + i] = 1;
        _filled++;
      }
    }
    if (_filled < total) return true;
    _frame = -1;
    // Cleared only for a sweep that is drawn: one that can't be placed is,
    // to the operator, no FFT at all.
    if (_emit(bins) && !_heard) {
      _heard = true;
      _watchdog?.cancel();
      _watchdog = null;
      sink?.reportSpectrumProblem(null);
    }
    return true;
  }

  /// A row is a step down from the pan's top: row 0 is max_dbm, its last
  /// row min_dbm.
  /// Read by what the radio has said and answered, not by what HaLo has
  /// asked: a sweep in flight was made before the radio took the change.
  bool _emit(Uint16List rows) {
    final status = _pans[_pan];
    final centerMhz = double.tryParse(status?['center'] ?? ''), widthMhz = double.tryParse(status?['bandwidth'] ?? '');
    final top = double.tryParse(status?['max_dbm'] ?? ''), bottom = double.tryParse(status?['min_dbm'] ?? '');
    final height = int.tryParse(status?['y_pixels'] ?? '') ?? _rows;
    if (centerMhz == null || widthMhz == null || top == null || bottom == null || height < 2) return false;
    // A sweep as wide as the pan was before its shaping: its rows are of the
    // old height too, and would seed the noise floor near the top.
    if (int.tryParse(status?['x_pixels'] ?? '') case final width? when width != rows.length) return false;
    final step = (top - bottom) / (height - 1);
    final levels = Float32List(rows.length);
    for (var i = 0; i < rows.length; i++) {
      // Below the pan's last row: a sweep from before its height changed,
      // which no height known here places.
      if (rows[i] >= height) return false;
      levels[i] = top - rows[i] * step;
    }
    final center = (centerMhz * 1e6).round(), half = (widthMhz * 1e6 / 2).round();
    final range = _noise.update(levels, refLevelDb: _settings.refLevelDb ?? 0, centerHz: center);
    if (range == null) return false;
    _report(_settings.copyWith(lowHz: center - half, highHz: center + half));
    sink?.reportSpectrum(
      SpectrumFrame(
        lowHz: center - half,
        highHz: center + half,
        levels: levels,
        floorDb: range.floor,
        ceilingDb: range.ceiling,
        noiseDb: range.noise,
        atMillis: nowMillis(),
      ),
    );
    return true;
  }

  void _report(SpectrumSettings settings) {
    if (settings == _settings) return;
    _settings = settings;
    sink?.reportSpectrumSettings(settings);
  }

  @override
  void teardown() {
    if (_wanted) _release();
    _wanted = false;
  }
}
