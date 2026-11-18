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
  ///
  /// [owner], the display as it names itself to [wantSpectrumWidth], gets
  /// the sweeps of the scope run for its width: its own where the radio runs
  /// more than one ([MultiScopeSession]), the widest otherwise. Read at each
  /// sweep, so a display moves to a scope of its own as soon as one runs.
  Stream<SpectrumFrame> spectrumFrames(String uuid, {Object? owner}) {
    final runtime = _runtimeFor(uuid);
    final all = (runtime.spectrum ??= StreamController<(int, SpectrumFrame)>.broadcast(
      onListen: () => _scheduleSpectrumDemand(runtime),
      onCancel: () => _scheduleSpectrumDemand(runtime),
    )).stream;
    return all.where((sweep) => sweep.$1 == (runtime.spectrumScopeOf[owner] ?? 0)).map((sweep) => sweep.$2);
  }

  /// [owner], a display drawing [uuid]'s sweeps, shows [widthHz] of them —
  /// 0 where it names no width and draws the whole sweep, null once it no
  /// longer draws them. Where the span is the app's to choose
  /// ([SpectrumCapabilities.autoSpan]), the scope runs at the narrowest span
  /// that covers the widest display, or the widest it has; a display that
  /// names no width asks for none, so with no display naming one the span
  /// stays where it was until the scope stops. Elsewhere the span stays the
  /// radio's, and a zoom fits it ([spectrumWidthsFor]).
  void wantSpectrumWidth(String uuid, Object owner, int? widthHz) {
    // A display closing after its radio was removed has nothing to take back.
    final runtime = widthHz == null ? _runtimes[uuid] : _runtimeFor(uuid);
    if (runtime == null || runtime.spectrumWidths[owner] == widthHz) return;
    if (widthHz == null) {
      runtime.spectrumWidths.remove(owner);
    } else {
      runtime.spectrumWidths[owner] = widthHz;
    }
    _scheduleSpectrumDemand(runtime);
  }

  /// What each display drawing [uuid]'s scope shows of it, as [wantSpectrumWidth] was told.
  Iterable<int> spectrumWidthsFor(String uuid) => _runtimes[uuid]?.spectrumWidths.values ?? const [];

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
  ///
  /// From [owner], a display, it changes the scope that display draws. From
  /// no display (an extension's `setRadioSpectrum`), it changes the
  /// session's own, whose speed and reference level every other sweep then
  /// follows ([_followSpectrumLook]).
  bool setSpectrum(String uuid, SpectrumRequest request, {Object? owner}) {
    final session = spectrumSessionFor(uuid);
    if (session == null) return false;
    try {
      if (owner != null) {
        if (_runtimes[uuid]?.spectrumScopeOf[owner] case final key?) return _runtimes[uuid]!.spectrumScopes[key]?.scope.setSpectrum(request) ?? false;
      }
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
      _followSpectrumLook(runtime, settings);
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

  /// The speed and reference level the session's own scope reports, given
  /// to every other sweep as it changes and to each as it opens: they are the
  /// receiver's look, where the span and centre are each sweep's own.
  void _followSpectrumLook(_NodeRuntime runtime, SpectrumSettings settings) {
    final look = (settings.speed, settings.refLevelDb);
    if (look == runtime.spectrumLook) return;
    runtime.spectrumLook = look;
    for (final (:scope, span: _) in runtime.spectrumScopes.values.toList()) {
      _lookOf(runtime, scope);
    }
  }

  void _lookOf(_NodeRuntime runtime, SpectrumScope scope) {
    final (speed, refLevelDb) = runtime.spectrumLook ?? (null, null);
    if (speed == null && refLevelDb == null) return;
    try {
      scope.setSpectrum(SpectrumRequest(speed: speed, refLevelDb: refLevelDb));
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:spectrum-scope');
    }
  }

  /// Whether [uuid] is an SDR receiver rather than a radio.
  bool isSdr(String uuid) =>
      switch (nodeFor(uuid)) {
        final node? => typeFor(node)?.category == kCategorySdr,
        null => null,
      } ??
      false;

  /// The radio SDR [sdrUuid] shows the spectrum for, and whose dial it
  /// follows: the local radio whose position picked it as its scope. Several
  /// can, since a scope can be watched from more than one position; then the
  /// one set A logs from, then set B's, since those are the radios in use.
  /// Null when no local radio picked it.
  String? linkedRadioFor(String sdrUuid) {
    final picking = [
      for (final position in _positions.all)
        if (position.radio case LocalRadio(:final uuid) when position.slots[kCapabilityScope] == sdrUuid && _nodes.containsKey(uuid)) uuid,
    ];
    for (final set in [kSetA, kSetB]) {
      if (_positions.radioOf(set) case LocalRadio(:final uuid) when picking.contains(uuid)) return uuid;
    }
    return picking.firstOrNull;
  }

  /// Where [radioUuid]'s spectrum comes from: the SDR its position picked as
  /// its scope, or the radio itself. A picked SDR wins over the radio's own
  /// scope until the operator Disconnects it. One that failed to connect
  /// still wins, and says why: falling back would swap pictures each time a
  /// server came and went.
  String spectrumNodeFor(String radioUuid) {
    final picked = designatedFor(kCapabilityScope, radio: radioUuid);
    if (picked != null && isSdr(picked) && !(_runtimes[picked]?.userDisconnected ?? false)) return picked;
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
      // Whatever stopped it then is not what a display opened later meets.
      runtime.sdrDropReason = null;
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

  /// A network SDR not through [_autoConnect]: its crash mark guards a
  /// synchronous native open that can wedge the process, which a socket
  /// cannot, and a hold it left would be named by no boot notice. One on USB
  /// is such an open — libusb's, or SDRplay's service — so it is marked like
  /// a radio's, and a launch that died in it holds it until the operator's
  /// Connect.
  Future<void> _connectSdr(_NodeRuntime runtime) async {
    runtime.sdrBusy++;
    var outcome = _ConnectOutcome.failed;
    try {
      final usb = switch (_nodes[runtime.uuid]) {
        final node? => typeFor(node)?.transportKey == SdrUsbTransport.transportKey,
        null => false,
      };
      outcome = usb ? await _autoConnect(runtime.uuid) : await HangWatchdog.guard(() => _connect(runtime.uuid));
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
  /// not be, a connection to something that is not an SDR server, or why the
  /// last connection ended while the next one has drawn nothing yet. Null
  /// once it is connected to one and drawing, or its scope says why not.
  String? sdrConnectionProblem(String uuid) {
    final state = stateFor(uuid);
    final dropped = _runtimes[uuid]?.sdrDropReason;
    return switch (state.status) {
      EquipmentStatus.connected => state.problem ?? (state.spectrumProblem == null ? dropped : null),
      EquipmentStatus.error => state.error ?? t.settings.station.spectrumSdrNotConnected,
      _ => dropped ?? t.settings.station.spectrumWaiting,
    };
  }

  void _spectrumDemand(_NodeRuntime runtime, bool wanted) {
    final session = runtime.session;
    if (session is! SpectrumSession || runtime.state.status != EquipmentStatus.connected) return;
    if (wanted == runtime.spectrumStarted) {
      if (wanted) _spectrumSpan(runtime, session);
      return;
    }
    runtime.spectrumStarted = wanted;
    runtime.spectrumSpanAsked = null;
    _closeSpectrumScopes(runtime);
    runtime.spectrumScopeLimit = null;
    try {
      wanted ? session.startSpectrum() : session.stopSpectrum();
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:spectrum-demand');
    }
    if (wanted) _spectrumSpan(runtime, session);
    // A stopped scope's settings are what it was, not what it is: the radio's
    // own knob can move them while nothing listens.
    if (!wanted && (runtime.state.spectrum != null || runtime.state.spectrumProblem != null)) {
      for (final MapEntry(key: uuid, value: r) in _runtimes.entries) {
        if (identical(r, runtime)) _setState(uuid, r.state.copyWith(clearSpectrum: true, clearSpectrumProblem: true));
      }
    }
  }

  /// A running scope whose span is the app's, at the narrowest span covering
  /// the widest display drawing it — asked once per change of that span, so
  /// a radio that snaps it is not asked again on every display's coming and
  /// going. Where the radio runs more than one sweep ([MultiScopeSession]),
  /// each narrower span shown gets one of its own, as far as the radio has
  /// sweeps to spare; a display whose span gets none crops the narrowest
  /// wider one.
  void _spectrumSpan(_NodeRuntime runtime, SpectrumSession session) {
    final capabilities = session.spectrumCapabilities;
    final named = {
      for (final MapEntry(key: owner, value: width) in runtime.spectrumWidths.entries)
        if (width > 0) owner: capabilities.spansHz.firstWhere((s) => s * 2 >= width, orElse: () => capabilities.spansHz.last),
    };
    if (!capabilities.autoSpan || capabilities.spansHz.isEmpty || named.isEmpty) {
      _closeSpectrumScopes(runtime);
      return;
    }
    final spans = named.values.toSet().toList()..sort((a, b) => b.compareTo(a));
    final span = spans.first;
    if (runtime.spectrumSpanAsked != span) {
      try {
        if (session.setSpectrum(SpectrumRequest(spanHz: span))) runtime.spectrumSpanAsked = span;
      } catch (e, st) {
        ErrorReportingService.report(e, st, context: 'cat:spectrum-span');
      }
    }
    _spectrumScopes(runtime, session, spans.skip(1).take(runtime.spectrumScopeLimit ?? spans.length).toList());
    // The narrowest scope at least as wide as each display's span: its own where one runs.
    final running = [(0, span), for (final MapEntry(:key, :value) in runtime.spectrumScopes.entries) (key, value.span ?? span)]
      ..sort((a, b) => a.$2.compareTo(b.$2));
    runtime.spectrumScopeOf
      ..clear()
      ..addAll({for (final MapEntry(key: owner, value: wants) in named.entries) owner: running.firstWhere((s) => s.$2 >= wants, orElse: () => running.last).$1})
      ..removeWhere((_, key) => key == 0);
  }

  /// One sweep beyond the session's own for each of [spans], widest first:
  /// those already open are given new spans rather than closed and opened
  /// again, since a zoom passes through several, and a sweep is a panadapter
  /// on some radios.
  void _spectrumScopes(_NodeRuntime runtime, SpectrumSession session, List<int> spans) {
    final open = runtime.spectrumScopes.entries.toList()..sort((a, b) => (b.value.span ?? 0).compareTo(a.value.span ?? 0));
    for (final entry in open.skip(spans.length)) {
      runtime.spectrumScopes.remove(entry.key);
      _closeSpectrumScope(entry.value.scope);
    }
    for (var i = 0; i < spans.length; i++) {
      var key = i < open.length ? open[i].key : null;
      if (key == null) {
        if (session is! MultiScopeSession) return;
        key = ++runtime.spectrumScopeKeys;
        final sink = _SpectrumScopeSink(this, runtime, runtime.connection, key);
        final SpectrumScope? scope;
        try {
          scope = session.openScope(sink);
        } catch (e, st) {
          ErrorReportingService.report(e, st, context: 'cat:spectrum-scope');
          runtime.spectrumScopeLimit = runtime.spectrumScopes.length;
          return;
        }
        if (scope == null) {
          runtime.spectrumScopeLimit = runtime.spectrumScopes.length;
          return;
        }
        runtime.spectrumScopes[key] = (scope: scope, span: null);
        // Said while it was being opened, before it was one of the sweeps.
        if (sink.opening case final message?) return _dropSpectrumScope(runtime, key, message);
        sink.opening = null;
        sink.opened = true;
        _lookOf(runtime, scope);
      }
      final (:scope, :span) = runtime.spectrumScopes[key]!;
      if (span == spans[i]) continue;
      try {
        if (scope.setSpectrum(SpectrumRequest(spanHz: spans[i]))) runtime.spectrumScopes[key] = (scope: scope, span: spans[i]);
      } catch (e, st) {
        ErrorReportingService.report(e, st, context: 'cat:spectrum-span');
      }
    }
  }

  /// A sweep beyond the session's own the radio turned down, or that failed
  /// after it ran: closed, and no more asked for until the scope restarts.
  /// Its displays go back to cropping a wider one.
  void _dropSpectrumScope(_NodeRuntime runtime, int key, String message) {
    final dropped = runtime.spectrumScopes.remove(key);
    if (dropped == null) return;
    // Its displays crop a wider sweep, which is not an error to the operator.
    debugPrint('[cat] ${runtime.uuid}: a sweep at ±${dropped.span} Hz closed: $message');
    _closeSpectrumScope(dropped.scope);
    runtime.spectrumScopeLimit = runtime.spectrumScopes.length;
    _scheduleSpectrumDemand(runtime);
  }

  void _closeSpectrumScopes(_NodeRuntime runtime) {
    final open = runtime.spectrumScopes.values.toList();
    runtime.spectrumScopes.clear();
    runtime.spectrumScopeOf.clear();
    for (final (:scope, span: _) in open) {
      _closeSpectrumScope(scope);
    }
  }

  /// For a new connection: the last one's sweeps went with its session.
  void _forgetSpectrumScopes(_NodeRuntime runtime) {
    runtime.spectrumScopes.clear();
    runtime.spectrumScopeOf.clear();
    runtime.spectrumScopeLimit = null;
    runtime.spectrumLook = null;
  }

  void _closeSpectrumScope(SpectrumScope scope) {
    try {
      scope.close();
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:spectrum-scope');
    }
  }
}

/// Where a sweep beyond the session's own reports: its sweeps to the
/// displays drawing it, and a problem as the end of it. Its settings are not
/// the receiver's, which the session's own scope reports.
class _SpectrumScopeSink implements SpectrumSink {
  final CatService cat;
  final _NodeRuntime runtime;
  final EquipmentConnection? connection;
  final int key;

  _SpectrumScopeSink(this.cat, this.runtime, this.connection, this.key);

  bool get _current => runtime.connection == connection && runtime.spectrumScopes.containsKey(key);

  /// A problem said before [CatService] held the sweep, from inside its opening.
  String? opening;
  bool opened = false;

  @override
  void reportSpectrum(SpectrumFrame frame) {
    if (_current) runtime.spectrum?.add((key, frame));
  }

  @override
  void reportSpectrumSettings(SpectrumSettings settings) {}

  @override
  void reportSpectrumProblem(String? message) {
    if (message == null) return;
    if (!opened) {
      opening ??= message;
    } else if (_current) {
      cat._dropSpectrumScope(runtime, key, message);
    }
  }
}
