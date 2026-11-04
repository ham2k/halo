// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An SDR receiver on this computer's USB — docs/design/cat.md § SDR
// receivers. The receiver's samples collect in a ring on its library's own
// threads (halo_sdr_usb); this reads the newest of them a few times a
// second and hands [SdrSpectrum] the stretch since the last read, which
// converts the few windows it draws and skips the rest unread. So the
// megabytes a second an Airspy samples never cross into Dart.

import 'dart:async';
import 'dart:math' as math;

import 'package:halo_core/halo_core.dart' show realNowMillis;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_sdr_usb/halo_sdr_usb.dart';

import '../driver.dart';
import '../spectrum.dart';
import 'sdr_spectrum.dart';

/// An Airspy R2 or Mini's gain step, 0 to 21 — its linearity preset, which
/// sets all three of its stages at once. Blank is its automatic gain.
const sdrUsbGainConfigKey = 'sdrUsbGain';

/// How often the ring is read: twenty times a second keeps the fastest
/// sweep speed fed, and at 10 MS/s is a fifth of what the ring holds.
const sdrUsbPollInterval = Duration(milliseconds: 50);

/// Polls in a row with no new samples, while streaming, before the receiver
/// is taken for gone: two seconds.
const _silentPolls = 40;

/// The stretch between an Airspy HF+'s HF and VHF ports, which hears
/// nothing: a window tuned there is noise.
const _airspyHfGapHz = (31000000, 60000000);

class SdrUsbDriver extends EquipmentDriver {
  /// Whether the receiver takes [sdrUsbGainConfigKey]: an HF+ and an RSP are
  /// left on their own automatic gain.
  final bool gainStep;

  const SdrUsbDriver({this.gainStep = false});

  @override
  String get key => 'sdr-usb';

  @override
  String get name => 'USB SDR';

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => [
    for (final element in sdrConfigElements())
      // Gain in dB and the crystal's correction are rtl_tcp's: these
      // receivers take neither.
      if (!overrides.containsKey(element['key']) && element['key'] != sdrGainDbConfigKey && element['key'] != sdrPpmConfigKey) element,
    if (gainStep && !overrides.containsKey(sdrUsbGainConfigKey))
      {
        'type': 'field',
        'fieldType': 'number',
        'key': sdrUsbGainConfigKey,
        'label': t.settings.station.sdrUsbGain,
        'description': t.settings.station.sdrUsbGainDescription,
        'advanced': true,
      },
  ];

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) =>
      SdrUsbSession(sink, SdrConfig.fromConfig(config), gain: gainStep ? sdrConfigNumber(config, sdrUsbGainConfigKey)?.round() : null);
}

class SdrUsbSession implements SpectrumSession, SdrTuner {
  final EquipmentSink sink;
  final SdrConfig config;

  /// The gain step to set; null leaves the receiver on its automatic gain.
  final int? gain;

  SdrUsbSession(this.sink, this.config, {this.gain});

  SdrUsbDevice? _device;
  SdrSpectrum? _spectrum;
  bool _wanted = false;
  Timer? _poll;

  /// The sample index the next read starts from.
  int _seen = 0;

  /// Counts starts and stops, so a start that finishes after a later stop
  /// does not begin reading.
  int _starts = 0;
  int _quiet = 0;
  int _aliveMillis = 0;

  /// Nothing more is done: the connection is being dropped.
  bool _dead = false;

  @override
  Duration? get expectedUpdateInterval => null;

  @override
  void handleData(_) {}

  @override
  void startUpdates() {
    final device = switch (sink) {
      final SdrSink sdr => sdr.usbDevice,
      _ => null,
    };
    if (device == null || device.sampleRates.isEmpty) return _drop(t.settings.station.sdrUsbUnavailable);
    _device = device;
    device.setGain(gain);
    _spectrum = SdrSpectrum(
      config: config,
      tuner: this,
      sink: sink is SpectrumSink ? sink as SpectrumSink : null,
      vfo: sink is SdrSink ? sink as SdrSink : null,
      rates: device.sampleRates,
    );
    sink.reportDiagnostic('${device.kind.name}, ${device.sampleRates.join('/')} S/s');
    if (_wanted) _start();
  }

  @override
  void stopUpdates() {}

  @override
  void teardown() => stopSpectrum();

  /// Reading begins once the receiver says it is streaming: its start runs
  /// off this isolate, and may take a moment.
  void _start() {
    final device = _device!;
    _spectrum!.start();
    final start = ++_starts;
    unawaited(
      device.start().then((streaming) {
        if (_dead || !_wanted || start != _starts) return;
        if (!streaming) return _drop(t.settings.station.sdrUsbLost);
        _seen = device.written;
        _quiet = 0;
        _poll ??= Timer.periodic(sdrUsbPollInterval, (_) => _read());
      }),
    );
  }

  /// The stretch written since the last read, at most what the ring still
  /// holds, handed to the spectrum to take its windows from.
  void _read() {
    final device = _device;
    final spectrum = _spectrum;
    if (_dead || device == null || spectrum == null) return;
    if (device.streaming != SdrUsbStreaming.streaming) return _drop(t.settings.station.sdrUsbLost);
    final written = device.written;
    if (written == _seen) {
      if (++_quiet >= _silentPolls) _drop(t.settings.station.sdrUsbLost);
      return;
    }
    _quiet = 0;
    _alive();
    // Kept a margin inside the ring: the receiver goes on writing while this
    // reads, and a window it has just overwritten would come back empty.
    final count = math.min(written - _seen, device.capacity ~/ 2);
    final from = written - count;
    _seen = written;
    spectrum.feed(count, (at, n, into, offset) {
      final got = device.read(from + at, n, into, offset);
      if (got < n) into.fillRange(offset + got * 2, offset + n * 2, 0);
    });
  }

  void _alive() {
    // Real time: the watch only needs to hear that it has not stopped.
    final now = realNowMillis();
    if (now - _aliveMillis > 1000) {
      _aliveMillis = now;
      sink.reportAlive();
    }
  }

  /// Ends the session the way a dropped network SDR does: the connection
  /// closes with [why], and is tried again while a display waits — a
  /// receiver plugged back in is picked up without the operator.
  void _drop(String why) {
    if (_dead) return;
    _dead = true;
    _poll?.cancel();
    _poll = null;
    if (sink case final SdrSink sdr) sdr.dropConnection(why);
  }

  @override
  int tunable(int hz) {
    final device = _device;
    final spectrum = _spectrum;
    if (device == null || spectrum == null) return hz;
    final half = spectrum.rate ~/ 2;
    final (low, high) = (device.minFrequencyHz + half, device.maxFrequencyHz - half);
    if (low > high) return hz;
    final clamped = hz.clamp(low, high);
    // Inside an HF+'s deaf stretch, to the nearer port's edge: the dial then
    // reads as out of reach rather than drawn over noise.
    if (device.kind == SdrUsbKind.airspyHf && clamped > _airspyHfGapHz.$1 - half && clamped < _airspyHfGapHz.$2 + half) {
      return clamped - _airspyHfGapHz.$1 < _airspyHfGapHz.$2 - clamped ? _airspyHfGapHz.$1 - half : _airspyHfGapHz.$2 + half;
    }
    return clamped;
  }

  /// Each moves the reading on past what is already in the ring: those were
  /// taken before it, and the spectrum's settle is counted in samples at the
  /// rate it now expects, which a stretch at the old rate can outlast.
  @override
  void tuneDevice(int hz) {
    _device?.setFrequency(hz);
    _skipWritten();
  }

  @override
  void setSampleRate(int rate) {
    _device?.setSampleRate(rate);
    _skipWritten();
  }

  void _skipWritten() {
    if (_device case final device?) _seen = device.written;
  }

  @override
  String? get spectrumUnavailable => null;

  /// Nothing to offer until the receiver is open and has said its rates.
  @override
  SpectrumCapabilities get spectrumCapabilities => _spectrum?.capabilities ?? const SpectrumCapabilities(spansHz: [], refMinDb: 0, refMaxDb: 0, refStepDb: 1);

  @override
  void startSpectrum() {
    if (_wanted) return;
    _wanted = true;
    if (_spectrum != null && !_dead) _start();
  }

  @override
  void stopSpectrum() {
    if (!_wanted) return;
    _wanted = false;
    _starts++;
    _poll?.cancel();
    _poll = null;
    if (!_dead) unawaited(_device?.stop());
    _spectrum?.stop();
  }

  @override
  bool setSpectrum(SpectrumRequest request) => _spectrum?.set(request) ?? false;
}
