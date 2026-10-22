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

  SpectrumCapabilities? spectrumCapabilitiesFor(String uuid) => spectrumSessionFor(uuid)?.spectrumCapabilities;

  String? spectrumProblemFor(String uuid) => spectrumSessionFor(uuid)?.spectrumUnavailable ?? stateFor(uuid).spectrumProblem;

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

  void Function(SpectrumSettings) _spectrumSettingsListener(String uuid, _NodeRuntime runtime, EquipmentConnection connection) {
    SpectrumCapabilities? lastCapabilities;
    return (settings) {
      if (runtime.connection != connection) return;
      final capabilities = switch (runtime.session) {
        final SpectrumSession session => session.spectrumCapabilities,
        _ => null,
      };
      // A new sample rate may change the available zooms while the selected
      // crop still has the same edges. Controls read capabilities from the
      // session, so they need this notification even when settings match.
      if (stateFor(uuid).spectrum == settings && lastCapabilities == capabilities) return;
      lastCapabilities = capabilities;
      _setState(uuid, stateFor(uuid).copyWith(spectrum: settings));
    };
  }

  /// Whether [uuid] is an SDR receiver rather than a radio.
  bool isSdr(String uuid) =>
      switch (nodeFor(uuid)) {
        final node? => typeFor(node)?.category == kCategorySdr,
        null => null,
      } ??
      false;

  /// The radio SDR [sdrUuid] shows the spectrum for — the one its config
  /// names, or whichever is Main. Null when that is no local radio.
  String? linkedRadioFor(String sdrUuid) {
    final link = nodeFor(sdrUuid)?.config[sdrRadioConfigKey];
    if (link is String && link.isNotEmpty && link != sdrRadioMain) return _nodes.containsKey(link) ? link : null;
    return _localRadio1;
  }

  /// Where [radioUuid]'s spectrum comes from: an SDR linked to it, or the
  /// radio itself. A linked SDR wins over the radio's own scope — linking
  /// one is the operator saying which picture they want — until they
  /// Disconnect it. One that failed to connect still wins, and says why:
  /// falling back would swap pictures each time a server came and went. The
  /// first such SDR in station order, when several are.
  String spectrumNodeFor(String radioUuid) {
    for (final node in nodes) {
      if (typeFor(node)?.category == kCategorySdr && linkedRadioFor(node.uuid) == radioUuid && !(_runtimes[node.uuid]?.userDisconnected ?? false)) {
        return node.uuid;
      }
    }
    return radioUuid;
  }

  /// The dial of the radio [sdrUuid] is linked to, in Hz.
  double? _linkedVfoHz(String sdrUuid) {
    final radio = linkedRadioFor(sdrUuid);
    if (radio == null) return null;
    final state = stateFor(radio);
    if (state.status != EquipmentStatus.connected) return null;
    return switch (state.vfo.freqKHz) {
      final khz? => khz * 1000,
      null => null,
    };
  }

  /// A display subscribes and leaves from inside a widget's build, mount and
  /// unmount, and starting or stopping a scope writes state every listener of
  /// the station hears — which Flutter refuses mid-build. So the demand is
  /// settled once the frame is done, against whoever is listening by then: a
  /// pane hidden and shown within one frame costs the radio nothing.
  void _scheduleSpectrumDemand(_NodeRuntime runtime) => scheduleMicrotask(() {
    if (_disposed) return;
    _settleSdr(runtime);
    _spectrumDemand(runtime, runtime.spectrum?.hasListener ?? false);
  });

  /// An SDR is connected while a display wants it, and let go
  /// [sdrIdleRelease] after the last one leaves. Its server streams for as
  /// long as the socket is open — megabytes a second nobody draws — and an
  /// rtl_tcp server takes one client, so holding it idle locks out every
  /// other program on the station.
  ///
  /// The operator overrides both ways: their Connect keeps it connected with
  /// no display, their Disconnect keeps it off and hands its radio back its
  /// own scope ([spectrumNodeFor]). The release is not their Disconnect.
  ///
  /// The one place an SDR is connected or let go on the app's own account.
  /// Called whenever what decides it may have changed — a display arriving or
  /// leaving, a connect or disconnect ending, a timer — and it reads the
  /// state afresh each time rather than trusting the caller's.
  void _settleSdr(_NodeRuntime runtime) {
    if (_disposed || runtime.sdrBusy > 0 || !isSdr(runtime.uuid)) return;
    final status = runtime.state.status;
    if (_sdrWanted(runtime)) {
      runtime.sdrRelease?.cancel();
      runtime.sdrRelease = null;
      if ((status == EquipmentStatus.disconnected || status == EquipmentStatus.error) && runtime.sdrRetry == null) unawaited(_connectSdr(runtime));
    } else {
      runtime.sdrRetry?.cancel();
      runtime.sdrRetry = null;
      if (status == EquipmentStatus.connected) {
        runtime.sdrRelease ??= Timer(sdrIdleRelease, () {
          runtime.sdrRelease = null;
          if (_disposed || _sdrWanted(runtime)) return;
          runtime.sdrBusy++;
          unawaited(
            disconnect(runtime.uuid, byUser: false).whenComplete(() {
              runtime.sdrBusy--;
              _settleSdr(runtime);
            }),
          );
        });
      }
    }
  }

  bool _sdrWanted(_NodeRuntime runtime) => !runtime.userDisconnected && (runtime.sdrPinned || (runtime.spectrum?.hasListener ?? false));

  /// Not through [_autoConnect]: its crash mark guards a synchronous native
  /// open that can wedge the process, which a network SDR's socket has not,
  /// and a hold it left would be named by no boot notice.
  Future<void> _connectSdr(_NodeRuntime runtime) async {
    runtime.sdrBusy++;
    var outcome = _ConnectOutcome.failed;
    try {
      outcome = await HangWatchdog.guard(() => _connect(runtime.uuid));
    } finally {
      runtime.sdrBusy--;
      if (outcome == _ConnectOutcome.failed) _retrySdr(runtime);
      _settleSdr(runtime);
    }
  }

  /// Tries a wanted SDR again after [sdrRetryDelay] — after a pause, since a
  /// server that accepts and drops would otherwise be reconnected as fast as
  /// it can refuse. Retried for as long as it is wanted: the server may be
  /// starting, or another program letting go of it.
  void _retrySdr(_NodeRuntime runtime) {
    if (_disposed || !isSdr(runtime.uuid) || !_sdrWanted(runtime)) return;
    runtime.sdrRetry?.cancel();
    runtime.sdrRetry = Timer(sdrRetryDelay, () {
      runtime.sdrRetry = null;
      _settleSdr(runtime);
    });
  }

  /// What stands between a display and SDR [uuid]'s sweeps before its scope
  /// has its say: a wait while it is connected on demand, the reason it could
  /// not be, or a connection to something that is not an SDR server. Null
  /// once it is connected to one.
  String? sdrConnectionProblem(String uuid) {
    final state = stateFor(uuid);
    return switch (state.status) {
      EquipmentStatus.connected => state.problem,
      EquipmentStatus.error => state.error ?? t.settings.station.spectrumSdrNotConnected,
      _ => t.settings.station.spectrumWaiting,
    };
  }

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
