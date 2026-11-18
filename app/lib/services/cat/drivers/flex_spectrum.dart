// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A FlexRadio's panadapter, mirrored through DAX IQ — docs/design/cat.md
// § Spectrum.
//
// For a slice HaLo follows on another station (SmartSDR, AetherSDR); its
// own station's slices take the radio's FFT (flex_pan_spectrum.dart). The
// radio sends a panadapter's FFT only to the client that owns it: a bound
// client gets every `display pan` status and none of the data, and a
// `display pan create` it sends lands in the owner's window.
// DAX IQ is the one stream a bound client can open on someone else's pan —
// captured on a FLEX-6600 (4.2.20): `stream create type=dax_iq` answers with
// a stream id and the pan's IQ follows on our UDP port. So the spectrum is
// computed here, and it shows what the operator's panadapter is pointed at.

import 'dart:typed_data';

import 'package:halo_core/halo_core.dart' show nowMillis;
import 'package:halo_i18n/halo_i18n.dart';

import '../spectrum.dart';
import '../spectrum_fft.dart';
import 'flex_dax_iq.dart';

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
/// 8192-point transform is finer than any panel is wide. Fewer, and a
/// waterfall stretched over a Retina pane blurs; the radio's own FFT of a
/// pan HaLo owns is as fine (flex_pan_spectrum.dart).
const _maxPoints = 2048;

const _sweepsPerSecond = {SpectrumSpeed.slow: 8, SpectrumSpeed.mid: 15, SpectrumSpeed.fast: 25};

/// A slice's scope, as its session drives it: mirrored through DAX IQ here,
/// or the radio's own FFT on HaLo's own station (flex_pan_spectrum.dart).
abstract interface class FlexSliceSpectrum {
  bool get wanted;
  SpectrumCapabilities get capabilities;
  void start();

  /// From the session's own subscribe, after the handshake: the radio
  /// refuses a `sub` before it.
  void subscribe();
  void stop();

  /// False when nothing is running to set.
  bool set(SpectrumRequest request);

  /// The UDP socket the data arrives on is open — [FlexRadioSession] opens
  /// it for the meters, and nothing is asked for before it.
  void socketReady();
  void socketLost();

  /// The UDP socket could not be opened, so nothing can arrive: said,
  /// rather than waiting on a socket that is not coming.
  void socketUnavailable();
  void slicePan(String? pan);

  /// `display pan 0x40000000 center=14.218000 bandwidth=0.064120 …`, its
  /// [fields] already merged into the record the scope was given: the
  /// connection merges each status once, before any scope reacts.
  void panStatus(String id, Map<String, String> fields);

  /// One UDP datagram; whether it was this scope's, so the meter codec does
  /// not take it as well. Every slice's scope on the connection is offered
  /// each datagram: two slices on one pan both draw its FFT.
  bool packet(Uint8List data);

  /// For [FlexRadioSession.teardown]: hands back what the scope holds over
  /// the connection while it is still open.
  void teardown();
}

class FlexDaxSpectrum implements FlexSliceSpectrum, FlexDaxIqUser {
  /// Sends a command; [onReply] gets the answer's code and body.
  final void Function(String command, {void Function(int code, String body)? onReply}) send;
  final SpectrumSink? sink;

  /// The connection's DAX IQ: the pan's stream, shared with every other of
  /// the connection's scopes on the pan.
  final FlexDaxIq _iq;

  FlexDaxSpectrum({required this.send, required this.sink, required this._iq, Map<String, Map<String, String>>? pans}) : _pans = pans ?? {};

  bool _wanted = false;
  @override
  bool get wanted => _wanted;

  /// The pan of the slice this node follows, from the slice's status.
  String? _pan;

  /// The pan whose IQ this scope draws, from its joining until it leaves.
  String? _joined;

  /// What each pan last said, merged from pushes that carry only what
  /// changed, and the changes HaLo made: the connection's record (FlexRadio),
  /// shared by every slice's scope on it. The connection alone merges the
  /// radio's statuses.
  final Map<String, Map<String, String>> _pans;

  int _rate = 48000;
  IqSpectrum? _fft;
  final _noise = NoiseFloor();
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

  @override
  SpectrumCapabilities get capabilities => SpectrumCapabilities(
    spansHz: flexDaxIqSpans,
    refMinDb: -30,
    refMaxDb: 30,
    refStepDb: 1,
    speeds: {SpectrumSpeed.slow, SpectrumSpeed.mid, SpectrumSpeed.fast},
    canRecenter: true,
    // The DAX IQ rate is ours alone: SmartSDR's panadapter keeps its own width.
    autoSpan: true,
  );

  @override
  void start() {
    if (_wanted) return;
    _wanted = true;
    if (_handshakeDone) _iq.subscribe();
    // Said again on every start: a display that reopened reads the settings
    // fresh, and nothing below changes them to prompt a report.
    sink?.reportSpectrumSettings(_settings);
    if (_socketFailed) sink?.reportSpectrumProblem(t.settings.station.spectrumNoUdp);
    _settle();
  }

  /// From the session's own subscribe, after the handshake.
  @override
  void subscribe() {
    _handshakeDone = true;
    if (_wanted) _iq.subscribe();
  }

  @override
  void stop() {
    if (!_wanted) return;
    _wanted = false;
    _release(forget: true);
    sink?.reportSpectrumProblem(null);
  }

  /// False when nothing is running to set.
  @override
  bool set(SpectrumRequest request) {
    if (!_wanted) return false;
    if (request.refLevelDb case final ref?) _report(_settings.copyWith(refLevelDb: capabilities.snapRef(ref)));
    if (request.speed case final speed?) {
      _report(_settings.copyWith(speed: speed));
      _fft?.hop = _rate ~/ _sweepsPerSecond[speed]!;
    }
    // The IQ is centred on the slice's PAN, which SmartSDR shows too: moving it
    // moves the operator's panadapter there as well. Applied here at once, as
    // the radio may not echo the change to the client that made it, and every
    // sweep is placed by this centre — and put back if the radio refuses it,
    // or every sweep after would be labelled where the IQ is not.
    if ((request.centerHz, _pan) case (final hz?, final pan?)) {
      final mhz = (hz / 1e6).toStringAsFixed(6), before = _pans[pan]?['center'];
      send(
        'display pan set $pan center=$mhz',
        onReply: (code, _) {
          if (code == 0 || _pans[pan]?['center'] != mhz) return;
          if (before == null) {
            _pans[pan]!.remove('center');
          } else {
            _pans[pan]!['center'] = before;
          }
        },
      );
      _pans[pan]?['center'] = mhz;
    }
    if (request.spanHz case final span?) _iq.ask(this, flexDaxIqRates[flexDaxIqSpans.indexOf(capabilities.snapSpan(span))]);
    return true;
  }

  /// The UDP socket the IQ arrives on is open — [FlexRadioSession] opens it
  /// for the meters, and a stream created before it would send to nowhere.
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

  /// The UDP socket could not be opened, so no IQ can arrive: said, rather
  /// than waiting on a socket that is not coming.
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
      // A slice first heard of with no pan is news even though nothing moved.
      if (firstWord) _settle();
      return;
    }
    if (_wanted && _pan != null) _release();
    _pan = pan;
    _settle();
  }

  /// `display pan 0x40000000 center=14.218000 bandwidth=0.064120 … daxiq_channel=0 …`
  @override
  void panStatus(String id, Map<String, String> fields) {
    if (id != _pan) return;
    if (fields.containsKey('removed')) return _release();
    if (_joined == id) return _iq.settle(id);
    _settle();
  }

  /// Joins the pan's IQ once everything it needs is known: the slice's pan,
  /// what that pan says, and a socket for the IQ to arrive on.
  void _settle() {
    if (!_wanted || !_socketReady || _joined != null) return;
    final pan = _pan;
    if (pan == null || _pans[pan] == null) {
      if (pan == null && _sliceSeen) sink?.reportSpectrumProblem(t.settings.station.spectrumNoPanadapter);
      return;
    }
    _joined = pan;
    _iq.join(pan, this);
  }

  /// Leaves the pan's IQ; [forget] the rate asked too, for a scope that stops.
  void _release({bool forget = false}) {
    if (_joined != null || forget) _iq.leave(this, forget: forget);
    _joined = null;
    _fft = null;
    _noise.reset();
  }

  @override
  void iqRate(int rate) {
    _fft = null;
    if (rate == _rate && _settings.spanHz != null) return;
    _rate = rate;
    _report(_settings.copyWith(spanHz: _visibleHalfWidth(rate)));
  }

  @override
  void iqSamples(Float32List interleaved) {
    final fft = _fft ??= IqSpectrum(size: _sizeFor(_rate), hop: _rate ~/ _sweepsPerSecond[_settings.speed ?? SpectrumSpeed.mid]!);
    fft.add(interleaved, _emit);
  }

  @override
  void iqProblem(String? message) => sink?.reportSpectrumProblem(message);

  /// Taken by the connection's [FlexDaxIq].
  @override
  bool packet(Uint8List data) => false;

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
    final pooled = poolPeaks(Float32List.sublistView(levels, trim, levels.length - trim), _maxPoints);
    final center = (centerMhz * 1e6).round();
    final range = _noise.update(pooled, refLevelDb: _settings.refLevelDb ?? 0, centerHz: center);
    if (range == null) return;
    // The pan stays put when the slice retunes inside it: a panel lining
    // its own picture up with the sweeps needs its edges, not the dial's.
    _report(_settings.copyWith(lowHz: center - _visibleHalfWidth(_rate), highHz: center + _visibleHalfWidth(_rate)));
    sink?.reportSpectrum(
      SpectrumFrame(
        lowHz: center - _visibleHalfWidth(_rate),
        highHz: center + _visibleHalfWidth(_rate),
        levels: pooled,
        floorDb: range.floor,
        ceilingDb: range.ceiling,
        noiseDb: range.noise,
        atMillis: nowMillis(),
      ),
    );
  }

  void _report(SpectrumSettings settings) {
    if (settings == _settings) return;
    _settings = settings;
    sink?.reportSpectrumSettings(settings);
  }

  /// For [FlexRadioSession.teardown]: hands the stream and the channel back
  /// over the connection while it is still open.
  @override
  void teardown() {
    if (_wanted) _release(forget: true);
    _wanted = false;
  }
}
