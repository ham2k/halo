// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:typed_data';

import 'package:halo_i18n/halo_i18n.dart';

import '../../error_reporting_service.dart';
import '../spectrum.dart';
import '../transport.dart';
import '../transports/tcp_transport.dart';
import 'k4_spectrum_codec.dart';
import 'k4_spectrum_presenter.dart';

/// The K4's Main panadapter over its dedicated LAN spectrum connection.
///
/// The radio streams precomputed bins as soon as this socket opens. Every
/// control here changes only their presentation; nothing is written to the
/// spectrum connection or to CAT, and the front-panel span stays untouched.
class K4Spectrum {
  final String host;
  final int port;
  final EquipmentTransport transport;
  final SpectrumSink? sink;

  K4Spectrum({required this.host, required this.sink, this.transport = const TcpTransport(), this.port = 9201});

  static const _firstRetryDelay = Duration(seconds: 2);
  static const _maxRetryDelay = Duration(seconds: 60);
  // Doubles per failure so a closed spectrum port does not keep redialing.
  Duration _retryDelay = _firstRetryDelay;
  static const _packetDeadline = Duration(seconds: 5);

  bool _disposed = false;
  bool _wanted = false;
  String? _problem;
  int _epoch = 0;
  CatCancelToken? _cancel;
  EquipmentConnection? _connection;
  StreamSubscription<Uint8List>? _subscription;
  Timer? _retry;
  Timer? _watchdog;
  final _decoder = K4SpectrumDecoder();
  late final _presenter = K4SpectrumPresenter(sink: sink);

  SpectrumCapabilities get capabilities => _presenter.capabilities;

  void start() {
    if (_disposed || _wanted) return;
    _wanted = true;
    final epoch = _epoch;
    _retryDelay = _firstRetryDelay;
    _presenter.start();
    if (!_current(epoch)) return;
    if (_retry == null) unawaited(_open());
  }

  void stop() {
    if (!_wanted) return;
    _wanted = false;
    _presenter.stop();
    _release();
    _reportProblem(null);
  }

  bool set(SpectrumRequest request) => _wanted && _presenter.set(request);

  Future<void> _open() async {
    if (!_wanted || _disposed || _cancel != null) return;
    final epoch = _epoch;
    final cancel = _cancel = CatCancelToken();
    _armWatchdog(epoch);
    EquipmentConnection connection;
    try {
      connection = await transport.connect({'host': host, 'port': port}, cancel: cancel);
    } on CatCancelledException {
      return;
    } catch (error, stack) {
      if (!_current(epoch)) return;
      ErrorReportingService.report(CatConnectFailure('k4-spectrum', error), stack, context: 'cat:k4-spectrum-connect');
      _failed(epoch);
      return;
    }
    if (!_current(epoch)) {
      unawaited(_close(connection));
      return;
    }
    _connection = connection;
    _subscription = connection.data.listen(
      (bytes) {
        if (!_current(epoch)) return;
        for (final packet in _decoder.add(bytes)) {
          if (packet.panId == 'A') _packet(packet, epoch);
        }
      },
      onDone: () => _failed(epoch),
      onError: (Object error, StackTrace stack) {
        if (!_current(epoch)) return;
        ErrorReportingService.report(error, stack, context: 'cat:k4-spectrum-data');
        _failed(epoch);
      },
    );
    unawaited(
      connection.closed.then(
        (_) => _failed(epoch),
        onError: (Object error, StackTrace stack) {
          if (!_current(epoch)) return;
          ErrorReportingService.report(error, stack, context: 'cat:k4-spectrum-closed');
          _failed(epoch);
        },
      ),
    );
    _armWatchdog(epoch);
  }

  bool _current(int epoch) => _wanted && !_disposed && epoch == _epoch;

  void _armWatchdog(int epoch) {
    _watchdog?.cancel();
    _watchdog = Timer(_packetDeadline, () => _failed(epoch));
  }

  void _failed(int epoch) {
    if (!_current(epoch)) return;
    _release();
    final releasedEpoch = _epoch;
    _reportProblem(t.settings.station.spectrumK4Unavailable);
    if (!_current(releasedEpoch)) return;
    _retry = Timer(_retryDelay, () {
      _retry = null;
      unawaited(_open());
    });
    final doubled = _retryDelay * 2;
    _retryDelay = doubled < _maxRetryDelay ? doubled : _maxRetryDelay;
  }

  void _release() {
    _epoch++;
    _cancel?.cancel();
    _cancel = null;
    _retry?.cancel();
    _retry = null;
    _watchdog?.cancel();
    _watchdog = null;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    final connection = _connection;
    _connection = null;
    if (connection != null) unawaited(_close(connection));
    _decoder.reset();
    _presenter.reset();
  }

  Future<void> _close(EquipmentConnection connection) async {
    try {
      await connection.close();
    } catch (error, stack) {
      ErrorReportingService.report(error, stack, context: 'cat:k4-spectrum-close');
    }
  }

  void _packet(K4SpectrumPacket packet, int epoch) {
    if (!_current(epoch)) return;
    // Integer frequency edges and a positive half-span cannot describe a
    // stream narrower than two hertz.
    if (packet.sampleRateHz < 2) return;
    _armWatchdog(epoch);
    _retryDelay = _firstRetryDelay;
    _reportProblem(null);
    if (!_current(epoch)) return;
    _presenter.add(centerHz: packet.centerHz, sampleRateHz: packet.sampleRateHz, levels: packet.levels);
  }

  void _reportProblem(String? problem) {
    if (_problem == problem) return;
    _problem = problem;
    sink?.reportSpectrumProblem(problem);
  }

  void teardown() {
    _disposed = true;
    stop();
  }
}
