// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

part of 'kenwood_driver.dart';

/// The built-in KAT4 and the transmitter's TUNE state are shared by both receivers.
/// See the AT and TU commands in Elecraft's K4 Programmer's Reference.
class _K4Tuner {
  _K4Tuner(this.sink, this.send);

  final EquipmentSink sink;
  final void Function(String) send;

  int? _mode, _tune;
  TunerStatus? _reported;
  int _pollsToSkip = 0;
  Object? _owner;
  bool _stopRequested = false;
  Timer? _confirmation;
  int _tuneReadsPending = 0;
  int _tuneReadsBeforeStart = 0;
  static const _confirmWithin = Duration(seconds: 3);

  bool get canStart => _mode == 2;
  bool get _installed => _mode == 1 || _mode == 2;

  void poll() {
    if (_pollsToSkip-- > 0) return;
    _pollsToSkip = kenwoodTunerReadEvery - 1;
    if (_owner == null) _readTune(includeMode: _mode != 0);
  }

  void setInline(bool inline) {
    final mode = inline ? 2 : 1;
    if (!_installed || _mode == mode || _owner != null || (_tune ?? 0) != 0) return;
    _mode = null;
    send('AT$mode;AT;');
  }

  void start(Object owner) {
    if (!canStart || _tune != 0 || _owner != null) return;
    _owner = owner;
    _tuneReadsBeforeStart = _tuneReadsPending;
    _commandTune('TU3;');
  }

  void stop(Object owner) {
    if (!identical(_owner, owner) || _stopRequested) return;
    _stopRequested = true;
    _commandTune('TU0;');
  }

  void _commandTune(String command) {
    _checkTune();
    send(command);
  }

  void _checkTune() {
    _confirmation?.cancel();
    // The radio pushes TU on changes, but a check that still reads tuning
    // cannot tell us about a later completion whose push is missed.
    _confirmation = Timer.periodic(_confirmWithin, (_) => _readTune());
  }

  void _readTune({bool includeMode = false}) {
    _tuneReadsPending++;
    send(includeMode ? 'AT;TU;' : 'TU;');
  }

  void close() {
    if (_owner != null && !_stopRequested) send('TU0;');
    _clearOwner();
    _mode = _tune = null;
    _reported = null;
    _pollsToSkip = 0;
    _tuneReadsPending = 0;
  }

  void heardMode(String params) {
    if (params != '0' && params != '1' && params != '2') return;
    _mode = int.parse(params);
    if (_mode == 0) _clearOwner();
    _report();
  }

  void heardTune(String params) {
    if (params.length != 1) return;
    final tune = int.tryParse(params);
    if (tune == null || tune < 0 || tune > 4) return;
    final previous = _tune;
    final wasTuning = previous == 3 || previous == 4;
    final wasCarrier = previous == 1 || previous == 2;
    // TU replies have no request ID. An idle reply to a read sent before
    // TU3 cannot settle that start, even if a newer check is already out.
    final confirmsIdle = _tuneReadsBeforeStart == 0 && (_tuneReadsPending > 0 || _stopRequested);
    if (_tuneReadsBeforeStart > 0) _tuneReadsBeforeStart--;
    if (_tuneReadsPending > 0) _tuneReadsPending--;
    _tune = tune;
    if (tune == 3 || tune == 4) {
      if (_owner != null && !wasTuning) _checkTune();
    } else if (tune != 0 || wasTuning || confirmsIdle) {
      _clearOwner();
    }
    final carrier = tune == 1 || tune == 2;
    if (carrier != wasCarrier) {
      if (sink case final TuneCarrierSink reporter) reporter.reportTuneCarrier(carrier);
    }
    _report();
  }

  void _clearOwner() {
    _confirmation?.cancel();
    _confirmation = null;
    _owner = null;
    _stopRequested = false;
    _tuneReadsBeforeStart = 0;
  }

  void _report() {
    final status = switch ((_mode, _tune)) {
      (0, _) => null,
      (_, 3 || 4) => TunerStatus.tuning,
      (1, _) => TunerStatus.bypassed,
      (2, _) => TunerStatus.inline,
      _ => null,
    };
    if (status == _reported) return;
    _reported = status;
    if (sink case final TunerSink reporter) reporter.reportTuner(status);
  }
}
