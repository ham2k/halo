// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

part of 'cat_service.dart';

/// The most sweeps a session runs beyond its own: each is a panadapter of the
/// radio's or a transform of every IQ sample here, and a display past them
/// crops the narrowest sweep that covers it.
const spectrumExtraScopesMax = 3;

/// The wait before a sweep the radio turned down is asked for again, doubling
/// each time up to [spectrumScopeRetryLongest]: a radio with no panadapter or
/// channel free is not asked every few seconds for as long as a display wants
/// a sweep of its own.
const spectrumScopeRetryFirst = Duration(seconds: 10);
const spectrumScopeRetryLongest = Duration(minutes: 2);

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
  ///
  /// [leads]: the display may move the scope, being neither secondary nor on
  /// a panel that may not command the radio ([spectrumLedElsewhere]).
  void wantSpectrumWidth(String uuid, Object owner, int? widthHz, {bool leads = true}) {
    // A display closing after its radio was removed has nothing to take back.
    final runtime = widthHz == null ? _runtimes[uuid] : _runtimeFor(uuid);
    if (runtime == null) return;
    final (led, leading) = (runtime.spectrumLeaders.contains(owner), widthHz != null && leads);
    if (runtime.spectrumWidths[owner] == widthHz && led == leading) return;
    // A display arriving or leaving is a new arrangement, worth asking for again soon; a zoom is not.
    if (runtime.spectrumWidths.containsKey(owner) != (widthHz != null)) _spectrumScopesAfresh(runtime);
    if (widthHz == null) {
      runtime.spectrumWidths.remove(owner);
    } else {
      runtime.spectrumWidths[owner] = widthHz;
    }
    leading ? runtime.spectrumLeaders.add(owner) : runtime.spectrumLeaders.remove(owner);
    // A leader arriving or leaving is what a secondary display reads: told after the frame, as one
    // display's build can be what asks, once however many came at once, and ahead of the demand, so
    // a secondary display giving way to the new one has given its width back before the scope is
    // sized. Sized first, the scope would run the secondary's width, and on a Flex of HaLo's own
    // open a pan for the new display, both undone at once.
    if (led != leading && !runtime.spectrumLeadersTelling) {
      runtime.spectrumLeadersTelling = true;
      scheduleMicrotask(() {
        runtime.spectrumLeadersTelling = false;
        if (!_disposed) _changed();
      });
    }
    _scheduleSpectrumDemand(runtime);
  }

  /// Whether a display other than [owner] that may move [uuid]'s scope shows
  /// its sweeps ([wantSpectrumWidth]'s `leads`). A secondary display leaves
  /// the scope to such a one. With none it asks of the scope itself, beside
  /// any other secondary display, the scope run for the widest of them: one
  /// left to a display that cannot move it would stay where it started while
  /// the dial walked out of it.
  bool spectrumLedElsewhere(String uuid, Object owner) => _runtimes[uuid]?.spectrumLeaders.any((other) => !identical(other, owner)) ?? false;

  /// Why [owner], a display of [uuid]'s sweeps narrower than the widest,
  /// draws a crop of a wider sweep rather than one of its own: the radio
  /// turned its own down, or more displays want one than the radio runs
  /// ([spectrumExtraScopesMax]). Null when it has its own, or needs none.
  /// [CatService] notifies when it changes.
  String? spectrumCroppedWhy(String uuid, Object owner) => _runtimes[uuid]?.spectrumCrops[owner];

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
  ///
  /// While a change of the leading displays is on its way, a demand queued
  /// before it is dropped: run first, it would size the scope for a secondary
  /// display's width before that display hears it is to give way. The call
  /// that sent the change queued a demand of its own after it
  /// ([wantSpectrumWidth]).
  void _scheduleSpectrumDemand(_NodeRuntime runtime) => scheduleMicrotask(() {
    if (_disposed || runtime.spectrumLeadersTelling) return;
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
    _allowSpectrumScopes(runtime);
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
    int snapped(int width) => capabilities.spansHz.firstWhere((s) => s * 2 >= width, orElse: () => capabilities.spansHz.last);
    final widths = {
      for (final MapEntry(key: owner, value: width) in runtime.spectrumWidths.entries)
        if (width > 0) owner: width,
    };
    if (!capabilities.autoSpan || capabilities.spansHz.isEmpty || widths.isEmpty) {
      _closeSpectrumScopes(runtime);
      return;
    }
    // The session's own at a span it has; a sweep beyond it at each narrower display's own width
    // where it takes any, which a crop of a rounded-up span would spread over few of its points.
    final anySpan = session is MultiScopeSession && session.scopesTakeAnySpan;
    final span = snapped(widths.values.reduce((a, b) => a > b ? a : b));
    final named = {
      for (final MapEntry(key: owner, value: width) in widths.entries)
        owner: switch (snapped(width)) {
          final own when anySpan && own < span => (width + 1) ~/ 2,
          final own => own,
        },
    };
    final spans = [span, ...named.values.where((s) => s < span).toSet().toList()..sort((a, b) => b.compareTo(a))];
    if (runtime.spectrumSpanAsked != span) {
      try {
        if (session.setSpectrum(SpectrumRequest(spanHz: span))) runtime.spectrumSpanAsked = span;
      } catch (e, st) {
        ErrorReportingService.report(e, st, context: 'cat:spectrum-span');
      }
    }
    final extras = (runtime.spectrumScopeLimit ?? spans.length).clamp(0, spectrumExtraScopesMax);
    _spectrumScopes(runtime, session, spans.skip(1).take(extras).toList());
    // The narrowest scope at least as wide as each display's span: its own where one runs.
    final running = [(0, span), for (final MapEntry(:key, :value) in runtime.spectrumScopes.entries) (key, value.span ?? span)]
      ..sort((a, b) => a.$2.compareTo(b.$2));
    final drawn = {for (final MapEntry(key: owner, value: wants) in named.entries) owner: running.firstWhere((s) => s.$2 >= wants, orElse: () => running.last)};
    runtime.spectrumScopeOf
      ..clear()
      ..addAll({for (final MapEntry(key: owner, value: (key, _)) in drawn.entries) owner: key})
      ..removeWhere((_, key) => key == 0);
    // A display drawing a coarser sweep than its own says why, where it is one the radio turned
    // down or the cap held back; one still opening has no reason to give yet.
    // A radio with one scope crops as it always has: there is no sweep of its own to explain.
    // Asked for again, the refusal stands until the sweep comes, rather than blinking off meanwhile.
    final why = switch (runtime.spectrumScopeLimit) {
      _ when session is! MultiScopeSession => null,
      null when spans.length - 1 > spectrumExtraScopesMax => t.settings.station.spectrumCroppedCap(max: spectrumExtraScopesMax),
      _ => runtime.spectrumScopeRefusal,
    };
    _setSpectrumCrops(runtime, {
      if (why != null)
        for (final MapEntry(key: owner, value: (_, has)) in drawn.entries)
          if (has > named[owner]!) owner: t.settings.station.spectrumCropped(why: why),
    });
  }

  void _setSpectrumCrops(_NodeRuntime runtime, Map<Object, String> crops) {
    if (mapEquals(runtime.spectrumCrops, crops)) return;
    runtime.spectrumCrops
      ..clear()
      ..addAll(crops);
    _changed();
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
          return _refuseSpectrumScopes(runtime, null, retry: false);
        }
        if (scope == null) return _refuseSpectrumScopes(runtime, t.settings.station.spectrumNoSweepToSpare, retry: true);
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
  /// after it ran: closed, its displays back to cropping a wider one.
  void _dropSpectrumScope(_NodeRuntime runtime, int key, String message) {
    final dropped = runtime.spectrumScopes.remove(key);
    if (dropped == null) return;
    // Its displays crop a wider sweep and say why, which is not an error to the operator.
    debugPrint('[cat] ${runtime.uuid}: a sweep at ±${dropped.span} Hz closed: $message');
    _closeSpectrumScope(dropped.scope);
    _refuseSpectrumScopes(runtime, message, retry: dropped.scope.turnedDown);
    _scheduleSpectrumDemand(runtime);
  }

  /// No more sweeps than run now, the displays told [message]. One the radio
  /// turned down is asked for again ([retry]), as what was in the way, another
  /// program's panadapter or a DAX channel, may since have gone; one that
  /// failed, or a driver that threw, waits for the scope to restart, as asking
  /// again would only fail again.
  void _refuseSpectrumScopes(_NodeRuntime runtime, String? message, {required bool retry}) {
    runtime.spectrumScopeLimit = runtime.spectrumScopes.length;
    runtime.spectrumScopeRefusal = message;
    if (!retry) {
      runtime.spectrumScopeRetry?.cancel();
      runtime.spectrumScopeRetry = null;
    } else if (runtime.spectrumScopeRetry == null) {
      _armSpectrumScopeRetry(runtime, _spectrumScopeRetryWait(runtime.spectrumScopeRefusals++));
    }
  }

  /// [spectrumScopeRetryFirst] after the first refusal in a row, doubling to [spectrumScopeRetryLongest].
  Duration _spectrumScopeRetryWait(int refusals) =>
      spectrumScopeRetryFirst *
      exponentialBackoff(refusals, cap: Duration(seconds: spectrumScopeRetryLongest.inSeconds ~/ spectrumScopeRetryFirst.inSeconds)).inSeconds;

  void _armSpectrumScopeRetry(_NodeRuntime runtime, Duration wait) {
    runtime.spectrumScopeRetry?.cancel();
    runtime.spectrumScopeRetry = Timer(wait, () {
      runtime.spectrumScopeRetry = null;
      runtime.spectrumScopeLimit = null;
      if (!_disposed) _scheduleSpectrumDemand(runtime);
    });
  }

  /// The waits start over, a sweep already waiting to be asked for again
  /// asked for after the first of them.
  void _spectrumScopesAfresh(_NodeRuntime runtime) {
    runtime.spectrumScopeRefusals = 0;
    if (runtime.spectrumScopeRetry != null) _armSpectrumScopeRetry(runtime, _spectrumScopeRetryWait(runtime.spectrumScopeRefusals++));
  }

  /// As many sweeps as the displays want, from the first wait: for a scope starting afresh.
  void _allowSpectrumScopes(_NodeRuntime runtime) {
    runtime.spectrumScopeRetry?.cancel();
    runtime.spectrumScopeRetry = null;
    runtime.spectrumScopeLimit = null;
    runtime.spectrumScopeRefusal = null;
    runtime.spectrumScopeRefusals = 0;
  }

  void _closeSpectrumScopes(_NodeRuntime runtime) {
    final open = runtime.spectrumScopes.values.toList();
    runtime.spectrumScopes.clear();
    runtime.spectrumScopeOf.clear();
    _setSpectrumCrops(runtime, const {});
    for (final (:scope, span: _) in open) {
      _closeSpectrumScope(scope);
    }
  }

  /// For a new connection: the last one's sweeps went with its session.
  void _forgetSpectrumScopes(_NodeRuntime runtime) {
    runtime.spectrumScopes.clear();
    runtime.spectrumScopeOf.clear();
    _setSpectrumCrops(runtime, const {});
    _allowSpectrumScopes(runtime);
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

  /// A sweep drawn ends a run of refusals: one after it starts the waits over.
  @override
  void reportSpectrum(SpectrumFrame frame) {
    if (!_current) return;
    runtime.spectrumScopeRefusals = 0;
    runtime.spectrum?.add((key, frame));
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
