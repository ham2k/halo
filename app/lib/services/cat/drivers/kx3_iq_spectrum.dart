// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:typed_data';

import 'package:halo_i18n/halo_i18n.dart';

import '../../error_reporting_service.dart';
import '../spectrum.dart';
import '../transport.dart';
import '../transports/iq_audio.dart';
import '../transports/iq_audio_errors.dart';
import 'kx3_iq_presenter.dart';

/// Owns an optional audio input independently of the KX3's CAT connection.
/// Starts and releases capture only with display demand, including when an
/// asynchronous permission or device open completes after the display closes.
class Kx3IqSpectrum {
  final String deviceId;
  final int sampleRate;
  final SpectrumSink? sink;
  final IqAudioCapture Function() captureFactory;
  late final Kx3IqPresenter _presenter;

  Kx3IqSpectrum({
    required this.deviceId,
    required this.sampleRate,
    required this.sink,
    int offsetHz = 0,
    bool swapIq = false,
    this.captureFactory = createIqAudioCapture,
  }) {
    _presenter = Kx3IqPresenter(sampleRate: sampleRate, offsetHz: offsetHz, swapIq: swapIq, sink: sink);
  }

  bool _wanted = false;
  bool _disposed = false;
  int _epoch = 0;
  int? _frequency;
  IqAudioCapture? _capture;
  Future<void> Function()? _cancelOpen;
  StreamSubscription<Uint8List>? _subscription;
  Timer? _watchdog;
  Future<void> _operations = Future.value();

  SpectrumCapabilities get capabilities => _presenter.capabilities;

  void updateFrequency(int hz) {
    _frequency = hz;
    _presenter.updateFrequency(hz);
  }

  void start() {
    if (_wanted || _disposed) return;
    _wanted = true;
    final epoch = ++_epoch;
    _presenter.updateFrequency(_frequency);
    _presenter.start();
    if (!_current(epoch)) return;
    sink?.reportSpectrumProblem(t.settings.station.kx3IqStarting);
    if (!_current(epoch)) return;
    // One device operation at a time: some backends share an audio session,
    // so a late close must finish before a replacement capture can start.
    _operations = _operations.then((_) => _open(epoch));
  }

  bool _current(int epoch) => _wanted && !_disposed && epoch == _epoch;

  Future<void> _open(int epoch) async {
    if (!_current(epoch)) return;
    IqAudioCapture? capture;
    Future<void>? closing;
    try {
      capture = captureFactory();
      _cancelOpen = () => closing ??= _close(capture!);
      final stream = await capture.start(deviceId: deviceId, sampleRate: sampleRate);
      if (!_current(epoch)) {
        await (closing ??= _close(capture));
        return;
      }
      _cancelOpen = null;
      _capture = capture;
      _subscription = stream.listen(
        (bytes) {
          if (!_current(epoch) || bytes.isEmpty) return;
          _armWatchdog(epoch);
          sink?.reportSpectrumProblem(_frequency == null ? t.settings.station.kx3IqWaitingForRadio : null);
          if (_current(epoch)) _presenter.add(bytes);
        },
        onDone: () => _failed(epoch, t.settings.station.kx3IqFailed),
        onError: (Object error, StackTrace stack) {
          if (!_current(epoch)) return;
          _reportError(error, stack);
          _failed(epoch, iqAudioProblemFor(error));
        },
      );
      _armWatchdog(epoch);
    } catch (error, stack) {
      final adopted = capture != null && identical(capture, _capture);
      if (_current(epoch)) {
        _reportError(error, stack);
        _failed(epoch, iqAudioProblemFor(error));
      }
      if (capture != null && !adopted) await (closing ??= _close(capture));
    } finally {
      _cancelOpen = null;
    }
  }

  void _armWatchdog(int epoch) {
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 5), () => _failed(epoch, t.settings.station.kx3IqFailed));
  }

  void _failed(int epoch, String problem) {
    if (!_current(epoch)) return;
    _release();
    _presenter.stop();
    // No retry loop around audio permission. Closing and reopening the
    // display (or reconnecting the radio) explicitly starts another attempt.
    sink?.reportSpectrumProblem(problem);
  }

  void stop() {
    if (!_wanted) return;
    _wanted = false;
    _release();
    _presenter.stop();
    sink?.reportSpectrumProblem(null);
  }

  bool set(SpectrumRequest request) => _wanted && _presenter.set(request);

  void _release() {
    _epoch++;
    _watchdog?.cancel();
    _watchdog = null;
    final subscription = _subscription;
    _subscription = null;
    final capture = _capture;
    _capture = null;
    // Mark a pending capture disposed before permission or device startup
    // completes. The operation queue still waits for its final cleanup.
    final cancelOpen = _cancelOpen;
    if (cancelOpen != null) unawaited(cancelOpen());
    _operations = _operations.then((_) async {
      if (subscription != null) {
        try {
          await subscription.cancel();
        } catch (error, stack) {
          ErrorReportingService.report(error, stack, context: 'cat:kx3-iq-cancel');
        }
      }
      if (capture != null) await _close(capture);
    });
  }

  Future<void> _close(IqAudioCapture capture) async {
    try {
      await capture.dispose();
    } catch (error, stack) {
      ErrorReportingService.report(error, stack, context: 'cat:kx3-iq-close');
    }
  }

  static void _reportError(Object error, StackTrace stack) {
    ErrorReportingService.report(CatConnectFailure('kx3-iq', error), stack, context: 'cat:kx3-iq');
  }

  void teardown() {
    _disposed = true;
    stop();
  }
}
