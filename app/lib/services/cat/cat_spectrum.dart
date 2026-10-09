// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

part of 'cat_service.dart';

extension CatServiceSpectrum on CatService {
  /// Sweeps from [uuid]'s scope, for a display to draw.
  ///
  /// The radio streams only while something listens: the first listener
  /// starts its scope and the last one to leave stops it. The stream outlives
  /// a reconnect, so a display keeps drawing when the radio drops and comes
  /// back, and a radio that connects while one is open starts at once.
  Stream<SpectrumFrame> spectrumFrames(String uuid) {
    final runtime = _runtimeFor(uuid);
    return (runtime.spectrum ??= StreamController<SpectrumFrame>.broadcast(
      onListen: () => _scheduleSpectrumDemand(runtime),
      onCancel: () => _scheduleSpectrumDemand(runtime),
    )).stream;
  }

  /// [uuid]'s scope, when it is connected and has one.
  SpectrumSession? spectrumSessionFor(String uuid) => switch (connectedSession(uuid)) {
    final SpectrumSession session => session,
    _ => null,
  };

  /// Changes [uuid]'s scope; the settings come back the usual way, as the
  /// radio reports them. False when no scope is running to change; a driver
  /// that throws is reported and rethrown, since "not running" would be a
  /// false answer for a scope that is.
  bool setSpectrum(String uuid, SpectrumRequest request) {
    final session = spectrumSessionFor(uuid);
    if (session == null) return false;
    try {
      return session.setSpectrum(request);
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:set-spectrum');
      rethrow;
    }
  }

  /// A display subscribes and leaves from inside a widget's build, mount and
  /// unmount, and starting or stopping a scope writes state every listener of
  /// the station hears — which Flutter refuses mid-build. So the demand is
  /// settled once the frame is done, against whoever is listening by then: a
  /// pane hidden and shown within one frame costs the radio nothing.
  void _scheduleSpectrumDemand(_NodeRuntime runtime) => scheduleMicrotask(() {
    if (_disposed) return;
    _spectrumDemand(runtime, runtime.spectrum?.hasListener ?? false);
  });

  void _spectrumDemand(_NodeRuntime runtime, bool wanted) {
    final session = runtime.session;
    if (session is! SpectrumSession || runtime.state.status != EquipmentStatus.connected || wanted == runtime.spectrumStarted) return;
    runtime.spectrumStarted = wanted;
    try {
      wanted ? session.startSpectrum() : session.stopSpectrum();
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:spectrum-demand');
    }
    // A stopped scope's settings are what it was, not what it is: the radio's
    // own knob can move them while nothing listens.
    if (!wanted && (runtime.state.spectrum != null || runtime.state.spectrumProblem != null)) {
      for (final MapEntry(key: uuid, value: r) in _runtimes.entries) {
        if (identical(r, runtime)) _setState(uuid, r.state.copyWith(clearSpectrum: true, clearSpectrumProblem: true));
      }
    }
  }
}
