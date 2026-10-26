// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Opening a session, keeping one open, and closing it: the attempt itself,
// the auto-connect marks around the attempts the app makes on its own, the
// retries after a drop and while the designated radio sits idle, and the
// teardown. The entry points — [CatService.connect], `disconnect`,
// `shutdown`, `reconnectDesignatedRadio` — stay on the class, where a test
// double can override them; an extension member cannot be.

part of 'cat_service.dart';

extension _Connection on CatService {
  /// Every connect the app decides on by itself goes through here — the boot
  /// reconnect, the burst after a drop, the idle ladder — so that the attempt
  /// is on disk before it is made and gone once it returns
  /// (auto_connect_guard.dart). A Connect the operator pressed does not: it is
  /// the one attempt somebody is watching, and the one that lifts a hold.
  Future<_ConnectOutcome> _autoConnect(String uuid) async {
    final node = _nodes[uuid];
    if (node == null) return _ConnectOutcome.failed;
    if (_autoConnectHeld.contains(uuid)) {
      _setState(uuid, EquipmentState(status: EquipmentStatus.error, error: t.settings.station.autoConnectHeld));
      // Through the same first-failure-per-node de-dup as a real connect
      // failure: how often this fires in the field is the only measure of how
      // often a launch is actually dying inside a connect, which is the thing
      // no crash report can show — the process that hangs never reports.
      _trackFailure(node, 'auto_connect_held');
      return _ConnectOutcome.held;
    }
    final prefs = _settings.prefs;
    if ((_autoConnectInFlight[uuid] = (_autoConnectInFlight[uuid] ?? 0) + 1) == 1) {
      await _writeAutoConnectMark(() => markAutoConnectStarted(prefs, uuid), 'cat:mark-auto-connect');
    }
    try {
      // Under the watchdog as well as the mark: the mark keeps the NEXT launch
      // out of a call that does not return, and the watchdog ends the one
      // stuck in it, so that there is a next launch rather than a corpse
      // holding the window.
      return await HangWatchdog.guard(() => _connect(uuid));
    } finally {
      // Every ordinary ending clears it — connected, refused, superseded, or
      // thrown. Only a process that never reaches here at all leaves the mark
      // standing, which is the single case it is written for.
      if ((_autoConnectInFlight[uuid] = _autoConnectInFlight[uuid]! - 1) <= 0) {
        _autoConnectInFlight.remove(uuid);
        await _writeAutoConnectMark(() => clearAutoConnectMark(prefs, uuid), 'cat:clear-auto-connect');
      }
    }
  }

  /// Writes one of the auto-connect marks, and never lets the writing of it
  /// become the failure.
  ///
  /// [_connect] answers with an outcome and never throws, and two callers are
  /// built on that: the idle ladder's `.then` reschedules itself from there,
  /// and the boot burst hands over to that ladder on its way out. An exception
  /// escaping from here — an unwritable preferences file, a wedged platform
  /// channel — would skip both, and the designated radio would then never
  /// connect again for the whole session, with nothing on the row and nothing
  /// in a report to say why. Bounded for the same reason it is caught: the
  /// mark is worth less than the connect it describes.
  ///
  /// So a mark that cannot be written leaves the call UNMARKED and proceeds.
  /// The alternative — refusing to connect a radio because a breadcrumb could
  /// not be written — trades a possible hang for a certain loss of the feature,
  /// on machines whose preference store is already in trouble.
  Future<void> _writeAutoConnectMark(Future<void> Function() write, String context) async {
    try {
      await write().timeout(_markBudget);
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: context);
    }
  }

  /// The outcome matters only to [reconnectDesignatedRadio]: a retry loop
  /// must keep trying after a *failure* but stop dead when something else
  /// has taken the node over. app-polo conflated the two and its
  /// auto-reconnect ended up fighting the user's own Connect.
  Future<_ConnectOutcome> _connect(String uuid) async {
    final node = _nodes[uuid];
    if (node == null) return _ConnectOutcome.failed;

    final type = registry.typeFor(node.typeKey);
    final transport = registry.transportFor(type?.transportKey);
    if (type == null || transport == null) {
      // Translated like every other error this sets, because [error] is not
      // only a diagnostic: the Radio panel renders it as its primary text and
      // its Semantics label, in the slot a frequency belongs in. The raw key
      // survives in [errorDetail] for an equipment report.
      _setState(
        uuid,
        EquipmentState(
          status: EquipmentStatus.error,
          error: t.settings.station.unknownType(typeKey: node.typeKey),
          errorDetail: 'Unknown equipment type "${node.typeKey}"',
        ),
      );
      _trackFailure(node, 'unknown_type');
      return _ConnectOutcome.failed;
    }

    final config = await _configWithSecrets(node);

    if (type.isUnconfigured(config)) {
      // A port just cleared may have a session up, or an attempt that (as in disconnect()) must learn it lost.
      final runtime = _runtimeFor(uuid)..cancel?.cancel();
      runtime.attemptSeq += 1;
      await _teardown(runtime);
      _setState(uuid, const EquipmentState(status: EquipmentStatus.disconnected));
      return _ConnectOutcome.unconfigured;
    }

    // Guarded, unlike the transport's own connect below, because validate()
    // reads the stored config directly: a value of the wrong shape that gets
    // past every reader in config_field_helpers would otherwise escape as an
    // unhandled async error from a fire-and-forget reconnect. A node whose
    // config cannot even be read is exactly a node to ignore and say so about.
    final String? invalid;
    try {
      invalid = type.validate(config);
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:validate-config');
      _setState(uuid, EquipmentState(status: EquipmentStatus.error, error: t.settings.station.configUnreadable, errorDetail: '$e'));
      _trackFailure(node, 'invalid_config', extra: _baudExtra(config));
      return _ConnectOutcome.failed;
    }
    if (invalid != null) {
      _setState(uuid, EquipmentState(status: EquipmentStatus.error, error: invalid));
      _trackFailure(node, 'invalid_config', extra: _baudExtra(config));
      return _ConnectOutcome.failed;
    }

    final runtime = _runtimeFor(uuid);

    // Supersede whatever this node already has going: cancel an in-flight
    // attempt so it stops hammering the radio, and tear down a live
    // connection before opening another.
    runtime.cancel?.cancel();
    await _teardown(runtime);

    final attempt = ++runtime.attemptSeq;
    final cancel = CatCancelToken();
    runtime.cancel = cancel;
    _setState(uuid, const EquipmentState(status: EquipmentStatus.connecting));
    trafficLog?.note(_logLabel(uuid), 'connecting');

    final EquipmentConnection connection;
    try {
      connection = await transport.connect(type.targetFor(config), cancel: cancel);
    } on CatCancelledException {
      // A newer connect (or a disconnect) owns this node now — not a
      // failure, and not ours to report.
      return _ConnectOutcome.superseded;
    } catch (e, st) {
      if (attempt != runtime.attemptSeq) return _ConnectOutcome.superseded;
      // Wrapped for the report only: ErrorPolicy needs to know a bare
      // SocketException came from a connect attempt before it can keep a
      // switched-off rig out of the backend. The state below shows a
      // translated reason for a recognized cause, or the underlying error's
      // own words otherwise — [errorDetail] keeps those words either way,
      // for the equipment report a developer reads.
      ErrorReportingService.report(CatConnectFailure(node.typeKey, e), st, context: 'cat:connect');
      final reason = connectFailureReason(e);
      final friendly = friendlyConnectError(reason, e);
      final raw = '$e';
      // The classified reason, not the error's text: a serial open failure
      // names the port, and the port carries the adapter's serial number.
      trafficLog?.note(_logLabel(uuid), 'connect failed: $reason (${e.runtimeType})');
      _setState(uuid, EquipmentState(status: EquipmentStatus.error, error: friendly, errorDetail: friendly == raw ? null : raw));
      _trackFailure(node, reason, extra: _baudExtra(config));
      if (e is SerialPortProblem && e.failure == SerialFailure.lines) runtime.linesRefused = true;
      return _ConnectOutcome.failed;
    }

    if (attempt != runtime.attemptSeq) {
      // Superseded while the handshake was running. Don't resurrect a
      // connection nothing is expecting any more — just close it, or it
      // leaks (the exact bug polo's attempt sequence was added to fix).
      unawaited(connection.close());
      return _ConnectOutcome.superseded;
    }

    final sink = _NodeSink(
      connection: connection,
      linkedVfo: () => _linkedVfoHz(uuid),
      onSend: (bytes) => trafficLog?.sent(_logLabel(uuid), bytes),
      onReading: (reading) {
        // A session from a superseded connection must not write state.
        if (runtime.connection != connection) return;
        _applyReading(uuid, reading);
      },
      onPower: (watts) {
        if (runtime.connection != connection) return;
        // What the radio just said is now what it has been told — the same
        // echo discipline [_applyReading] keeps for freq/mode.
        runtime.lastSentPower = watts;
        if (stateFor(uuid).power != watts) _setState(uuid, stateFor(uuid).copyWith(power: watts));
        // Only the designated radio drives the app's power, and tagged
        // `radio` so [_onVfoChanged] doesn't send it straight back. The
        // baseline moves with it: what the radio reports is where the app
        // now is, so the next operator change is measured from there.
        if (uuid == _localRadio1) {
          _lastSeenVfoPower = watts;
          _radio?.setVfo('vfoA', power: watts, origin: VfoOrigin.radio);
        } else if (uuid == radio2) {
          _radio?.setVfo('vfoB', power: watts, origin: VfoOrigin.radio);
        }
      },
      onTransmitting: (transmitting) {
        if (runtime.connection != connection) return;
        // NOT _noteAlive: a driver may know this WITHOUT the radio saying
        // so — the app keys the rig itself for a CW or voice message — and
        // the silence watch exists to catch a live session over a dead
        // reading stream. A driver whose TX state arrived off the wire
        // reports it as a reading or calls reportAlive itself.
        final state = stateFor(uuid);
        if (state.telemetry.transmitting == transmitting) return;
        if (transmitting) {
          runtime.startTransmission();
        } else if (state.telemetry.transmitting == true) {
          runtime.endTransmission();
        }
        _setState(uuid, state.copyWith(telemetry: state.telemetry.withTransmitting(transmitting)));
        _ptt.onTransmitting(runtime.session, transmitting);
        _meterReadings.notify();
      },
      onMeter: (meter, value) {
        if (runtime.connection != connection) return;
        final state = stateFor(uuid);
        final previous = state.telemetry.meters[meter];
        // Stamped with the app clock, never DateTime.now()
        // (docs/design/time.md) — developer time travel moves the whole app,
        // expiry included.
        final telemetry = state.telemetry.withMeter(meter, value, nowMillis());
        if (meter == RadioMeter.swr) {
          runtime.noteSwr(value, powerOut: state.telemetry.meters[RadioMeter.powerOut]?.value, transmitting: state.telemetry.transmitting);
        }
        // A meter answering with the number it answered with last time is
        // not news. The timestamp still has to move — that is what keeps
        // the reading from expiring under a steady transmission — but at
        // three meters on a 200 ms cycle, repainting every listener fifteen
        // times a second to redraw an unchanged 1.2 is work nobody sees.
        //
        // The receive signal is never news to a listener: band noise moves it
        // by a dB or more between samples, so it would notify for as long as
        // the radio is connected — and what reads it, an extension's
        // `readRadio`, polls the state rather than listening for it.
        _setState(uuid, state.copyWith(telemetry: telemetry), notify: meter != RadioMeter.signalDbm && previous?.value != value);
        // An SWR reading moves the running average even when it repeats the last one.
        if (previous?.value != value || meter == RadioMeter.swr) _meterReadings.notify();
      },
      onCwProgress: (progress) {
        if (runtime.connection != connection) return;
        // A keyer has no VFO to feed the silence watch with — see the
        // reasoning at onSwitchState.
        _noteAlive(uuid, runtime);
        // Only the designated key keys for the app, so only its progress is
        // shown — and reported to a peer following one of this station's
        // radios, which is why it crosses whether or not anything here is
        // looking at the strip.
        for (final keyer in _keyers.values) {
          keyer.noteCwProgress(uuid, progress);
        }
      },
      onKeyerSpeed: (wpm) {
        if (runtime.connection != connection) return;
        _noteAlive(uuid, runtime);
        if (stateFor(uuid).keyerSpeed != wpm) _setState(uuid, stateFor(uuid).copyWith(keyerSpeed: wpm));
        if (uuid == keyInUse) _keying.onKeyingChanged();
      },
      onVoiceActivity: (activity) {
        if (runtime.connection != connection) return;
        // NOT _noteAlive, unlike onCwProgress: a voice report is made at the
        // app's own keypress and at a local ceiling timer, never from a byte
        // off the radio, so it says nothing about the link. The poll answers
        // that end one feed the watch through the normal reading path.
        for (final keyer in _keyers.values) {
          keyer.noteVoiceActivity(uuid, activity);
        }
      },
      onVoiceMemories: (memories) {
        if (runtime.connection != connection) return;
        // NOT _noteAlive: a rename reports the slots itself, from the app's
        // own keypress rather than a byte off the radio.
        if (listEquals(stateFor(uuid).voiceMemories, memories)) return;
        _setState(uuid, stateFor(uuid).copyWith(voiceMemories: memories));
        // A peer following this radio reads the names and lengths off its
        // status, which only a keying change republishes.
        _keying.onKeyingChanged();
      },
      onProblem: (message) {
        if (runtime.connection != connection) return;
        if (stateFor(uuid).problem == message) return;
        if (message != null) trafficLog?.note(_logLabel(uuid), 'problem: $message');
        _setState(uuid, stateFor(uuid).copyWith(problem: message, clearProblem: message == null));
      },
      onChannels: (channels) {
        if (runtime.connection != connection) return;
        if (listEquals(stateFor(uuid).channels, channels)) return;
        _setState(uuid, stateFor(uuid).copyWith(channels: channels));
      },
      onSwitchState: (antennas, ports) {
        if (runtime.connection != connection) return;
        // The switch said something, so it is not silent — whatever it said,
        // and whether or not any of it differs from last time.
        //
        // Without this the watchdog is fed by VfoReadings alone, and
        // equipment that has no VFO to report goes stale 30 s after every
        // connect however healthy it is. That was invisible while the only
        // thing in this layer was radios.
        _noteAlive(uuid, runtime);
        final state = stateFor(uuid);
        // Both compared before either is written: a switch reports the whole
        // picture on every port change, so the antenna list is identical
        // almost every time and only the ports actually moved.
        if (listEquals(state.switchAntennas, antennas) && listEquals(state.switchPorts, ports)) return;
        _setState(uuid, state.copyWith(switchAntennas: antennas, switchPorts: ports));
      },
      onDiagnostic: (note) {
        // Same guard, same reason: a superseded session's account of itself
        // is about a connection nobody is looking at any more.
        if (runtime.connection != connection) return;
        // Deduped HERE rather than in the driver, because this is what holds
        // the value: a driver remembering what it last said would be wrong
        // the moment a status transition replaced the state underneath it,
        // and every driver would have to remember separately.
        if (stateFor(uuid).diagnostic == note) return;
        // In the log as well: the screen shows it only in developer mode,
        // and the operators who run DEVLOGCAT are not in it.
        if (note != null) trafficLog?.note(_logLabel(uuid), 'driver: $note');
        _setState(uuid, stateFor(uuid).copyWith(diagnostic: note, clearDiagnostic: note == null));
      },
      onAlive: () {
        if (runtime.connection != connection) return;
        _noteAlive(uuid, runtime);
      },
      onSpectrum: (frame) {
        if (runtime.connection != connection) return;
        // NOT _noteAlive: a Flex sweep is computed from a UDP stream that
        // outlives the command socket the silence watch is about.
        runtime.spectrum?.add(frame);
      },
      onSpectrumSettings: _spectrumSettingsListener(uuid, runtime, connection),
      onSpectrumProblem: (message) {
        if (runtime.connection != connection || stateFor(uuid).spectrumProblem == message) return;
        _setState(uuid, stateFor(uuid).copyWith(spectrumProblem: message, clearSpectrumProblem: message == null));
      },
      onTuner: (status) {
        if (runtime.connection != connection || stateFor(uuid).tuner == status) return;
        _setState(uuid, stateFor(uuid).copyWith(tuner: status, clearTuner: status == null));
      },
      onPassband: (passband) {
        if (runtime.connection != connection || stateFor(uuid).passband == passband) return;
        _setState(uuid, stateFor(uuid).copyWith(passband: passband, clearPassband: passband == null));
      },
      onAntennas: (antennas) {
        if (runtime.connection != connection || stateFor(uuid).antennas == antennas) return;
        _setState(uuid, stateFor(uuid).copyWith(antennas: antennas, clearAntennas: antennas == null));
      },
    );
    // driverConfig, not config: a type may know something about its
    // protocol that is not a setting anyone should be asked for — the
    // IC-705's network controller address, for one.
    final session = type.driver.createSession(sink, type.driverConfig(config));

    runtime.connection = connection;
    runtime.session = session;
    // This connection has heard nothing yet, whatever the last one heard.
    runtime.proof.reset();
    // The baud rate and nothing else of the config: the log leaves the device,
    // and a serial port name carries the adapter's serial number on macOS.
    trafficLog?.note(_logLabel(uuid), config['baudRate'] == null ? 'connected' : 'connected at ${config['baudRate']} baud');
    runtime.subscription = connection.data.listen((chunk) {
      // Not an SDR's IQ: megabytes a second of it would fill the log in
      // moments and end the recording of the CAT traffic it exists for.
      if (type.category != kCategorySdr) trafficLog?.received(_logLabel(uuid), chunk);
      runtime.heard(chunk);
      try {
        session.handleData(chunk);
      } catch (e, st) {
        // One malformed frame must not kill the connection.
        ErrorReportingService.report(e, st, context: 'cat:handle-data:${type.driver.key}');
      }
    });

    unawaited(
      connection.closed.then((_) {
        // A stale connection's close must not clobber a live one's status.
        if (runtime.connection != connection) return;
        trafficLog?.note(_logLabel(uuid), 'connection closed by the transport');
        // NOTE on deliberate disconnects: there is no guard for them here, and
        // none is needed. _teardown calls _closeSession FIRST, which sets
        // runtime.connection = null, and only then closes the connection — so a
        // disconnect the operator asked for exits at the guard above and never
        // reaches this line. A `status == disconnecting` check here would be
        // dead code for the same reason. If teardown's ordering ever changes,
        // the test 'a DELIBERATE disconnect is never undone' is what will
        // catch it.
        // The driver keeps its own timers (FlexRadio resyncs every 60s, the
        // CI-V drivers poll every 5s). Dropping the session without tearing
        // it down leaves them ticking for the life of the process — once per
        // drop — each one retaining its sink and this dead connection.
        unawaited(_closeSession(runtime));
        _setState(uuid, const EquipmentState(status: EquipmentStatus.disconnected));
        _autoReconnectAfterDrop(uuid);
        // An SDR comes back for the display still waiting on it.
        _retrySdr(runtime);
        // And keep trying slowly afterwards, in case that burst is spent before
        // the radio is back.
        //
        // Unconditional on purpose. A guard on which node dropped would be
        // dead code: [_scheduleIdleRetry] reads the nodes it covers itself and
        // stops on the first tick if each is connected or absent, so the guard
        // could not change any outcome. One place decides, and it is the loop.
        _scheduleIdleRetry();
      }),
    );

    _setState(uuid, const EquipmentState(status: EquipmentStatus.connected));
    if (_trackedConnected.add(uuid)) _trackRadio('radio_connected', node);
    _armStaleWatch(uuid, runtime);

    // Start updates on connect rather than when a UI subscriber shows up:
    // polo gated this on a refcount, so connecting with no screen mounted
    // succeeded and then never asked the radio anything.
    try {
      session.startUpdates();
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:start-updates:${type.driver.key}');
    }
    runtime.spectrumStarted = false;
    runtime.spectrumSpanAsked = null;
    if (runtime.spectrum?.hasListener ?? false) _spectrumDemand(runtime, true);
    _settleSdr(runtime);
    return _ConnectOutcome.connected;
  }

  /// Keeps trying the designated radio, slowly, while it sits disconnected.
  ///
  /// [_autoReconnectAfterDrop] handles the moment a live session dies. This
  /// handles everything after: a radio that was switched off, or was still
  /// booting when that burst was spent, or that refused because another client
  /// held it. A real gap, verified on hardware — see [_idleRetryFirst].
  ///
  /// Three things keep it from becoming the bug it is meant to fix:
  ///
  ///  * it never touches a node the operator switched off — [disconnect]
  ///    records that, and only [connect] clears it;
  ///  * it only ever looks at the designated radio, so a station full of
  ///    equipment does not generate traffic nobody asked for. With no radio
  ///    designated (None) it does nothing at all;
  ///  * it backs off to [_idleRetryMax]. This radio measurably degrades when
  ///    reconnected at speed, so a rig that is present and refusing must not
  ///    be poked on a fixed short cycle.
  void _scheduleIdleRetry() {
    if (_disposed) return;
    _idleRetryTimer?.cancel();
    _idleRetryTimer = Timer(_idleRetryDelay, () {
      if (_disposed) return;
      // radio1, and the key in use when it is a device of its own: the two
      // nodes the app depends on, so the two this loop brings back.
      final wanted = _autoConnectTargets;

      // STOP only for a reason that will not resolve itself: there is nothing
      // designated, the node is gone, the operator switched it off, its port
      // was refused over its control lines, it is held from a launch that
      // died connecting it, or it is already connected.
      // connect/disconnect and a dropped session restart it.
      bool settled(String uuid) =>
          !_nodes.containsKey(uuid) ||
          (_runtimes[uuid]?.userDisconnected ?? false) ||
          (_runtimes[uuid]?.linesRefused ?? false) ||
          _autoConnectHeld.contains(uuid) ||
          stateFor(uuid).status == EquipmentStatus.connected;
      final open = wanted.where((uuid) => !settled(uuid)).toList();
      if (open.isEmpty) {
        _idleRetryTimer = null;
        return;
      }

      // WAIT, without counting it as an attempt, while something else is
      // mid-flight. Only these two mean "in progress"; `error` is a FAILED
      // attempt and is exactly what we are here to retry.
      //
      // Both tempting simplifications are wrong. Treating `connecting` as
      // nothing-to-do and STOPPING shuts the loop down permanently when the
      // drop burst is still in flight on the first tick — reintroducing the
      // gap this exists to close. Waiting on anything that is not
      // `disconnected` includes `error`, so after the first failure it would
      // wait for ever and never retry at all.
      if (open.any((uuid) {
        final status = stateFor(uuid).status;
        return status == EquipmentStatus.connecting || status == EquipmentStatus.disconnecting;
      })) {
        _scheduleIdleRetry();
        return;
      }

      // Double first, so a failure that arrives after this fire still leaves
      // the next wait longer than this one.
      _idleRetryDelay = _idleRetryDelay * 2 > _idleRetryMax ? _idleRetryMax : _idleRetryDelay * 2;
      unawaited(
        Future.wait(open.map(_autoConnect)).then((outcomes) {
          if (outcomes.every((outcome) => outcome == _ConnectOutcome.connected || outcome == _ConnectOutcome.unconfigured)) {
            _idleRetryDelay = idleRetryFirst;
            // CANCEL, not just forget. There is an async gap above while the
            // connect runs, and _scheduleIdleRetry may have been called during
            // it — a drop on any node calls it. Nulling alone would leave that
            // timer pending and unreachable: dispose() could no longer stop it,
            // and if the radio drops again before it fires it runs a second
            // retry chain alongside the real one, doubling the connect rate
            // against the radio whose backoff exists to prevent exactly that.
            _idleRetryTimer?.cancel();
            _idleRetryTimer = null;
            return;
          }
          _scheduleIdleRetry();
        }),
      );
    });
  }

  /// Whether [uuid] is a key device of its own (a keyer node, not a radio
  /// doubling as one) — what the app's keying depends on when it is a
  /// radio's key, so it is brought back the way radio1 is.
  bool _isKeyerDevice(String uuid) {
    final node = _nodes[uuid];
    return node != null && typeFor(node)?.category == kCategoryKeyer;
  }

  /// When the designated radio's connection dies on its own, try to get it
  /// back — once, and then leave it alone.
  ///
  /// The radio can end a session without us doing anything wrong: it says so
  /// with an 0x50 (see the Icom transport, which listens for that), or it
  /// simply stops answering. Without this, the row goes disconnected and stays
  /// there until the operator notices and presses Connect — a poor answer from
  /// a logger whose job is to follow the VFO.
  ///
  /// DELIBERATELY TIMID, for a reason recorded in hardware terms.
  /// IcomNetworkTransport.connect documents that retrying a refused login
  /// makes this radio WORSE: every attempt opens a session it must track, and
  /// measured on hardware, three attempts per Connect turned "ignores the
  /// login" into "ignores the handshake". app-polo's auto-reconnect also ended
  /// up fighting the user's own Connect (see [_ConnectOutcome]). So:
  ///
  ///  * only what the logging panel depends on — [_autoConnectTargets];
  ///  * never after a deliberate Disconnect;
  ///  * at most one burst per [_autoReconnectCooldown], so a flapping radio —
  ///    or a second client holding its only session slot — gets a few attempts
  ///    a minute rather than a storm.
  ///
  /// [reconnectDesignatedRadio] supplies the retry policy; this only decides
  /// whether it may run at all.
  void _autoReconnectAfterDrop(String uuid) {
    if (_disposed || !_autoConnectTargets.contains(uuid)) return;
    final last = _lastAutoReconnect[uuid];
    // Real time: this cooldown rate-limits real reconnect attempts against a
    // real radio, so a rescaled clock would let a storm through.
    final now = realNowUtc();
    if (last != null && now.difference(last) < _autoReconnectCooldown) {
      debugPrint('[cat] auto-reconnect suppressed: last was ${now.difference(last).inSeconds}s ago');
      return;
    }
    _lastAutoReconnect[uuid] = now;
    unawaited(reconnectDesignatedRadio());
  }

  Future<void> _reconnectWithRetries(String? uuid) async {
    if (uuid == null || !_nodes.containsKey(uuid)) return;
    // A deliberate Disconnect holds whatever else drops: the other device
    // coming back must not bring this one with it.
    if (_runtimes[uuid]?.userDisconnected ?? false) return;

    for (var attempt = 0; attempt <= _reconnectRetries; attempt++) {
      // The delay below can't be cancelled, so the service may have been
      // disposed while this loop was parked on it.
      if (_disposed) return;

      final status = stateFor(uuid).status;
      // Connected already, or someone is mid-connect — either way, not ours.
      if (status == EquipmentStatus.connected || status == EquipmentStatus.connecting) return;

      final outcome = await _autoConnect(uuid);
      if (outcome != _ConnectOutcome.failed) return;

      if (attempt == _reconnectRetries) break;
      await Future<void>.delayed(reconnectDelay);
    }

    // The burst is spent and the radio still is not there, so hand over to the
    // slow loop. Without this, main.dart's boot call meant three attempts in a
    // few seconds and then silence for the rest of the session: the loop was
    // only ever started by a drop, and at boot nothing has dropped. That is the
    // same gap the loop exists to close, on the one path most likely to hit it
    // — the operator switches the rig on after the app, not before.
    //
    // Only reached when the burst EXHAUSTED. Connected, superseded and disposed
    // all return above, because in each of those cases something else is
    // already driving this node.
    _scheduleIdleRetry();
  }

  /// Drops the session and everything that belongs to it, and gives the
  /// driver its chance to stop timers. Everything up to the first `await`
  /// runs synchronously, so a caller that has just checked
  /// `runtime.connection` can rely on it being cleared before anything else
  /// gets a turn.
  ///
  /// Separate from [_teardown] because a connection that closed on its own
  /// still needs all of this — only the socket is already gone.
  Future<void> _closeSession(_NodeRuntime runtime) async {
    final session = runtime.session;
    final subscription = runtime.subscription;
    runtime.session = null;
    runtime.connection = null;
    runtime.subscription = null;
    runtime.staleTimer?.cancel();
    runtime.staleTimer = null;
    _cancelBandPick(runtime);
    // The echo guard describes what THIS session was told. Carrying it into
    // the next connection would suppress the first tune to a frequency the
    // previous session happened to be on, leaving the app and a
    // freshly-reconnected radio silently disagreeing.
    runtime.lastSent = null;
    runtime.lastSentPower = null;
    // Whatever this node was keying is not keying now — and a radio that is
    // gone is playing nothing, which a peer following it has to be told.
    for (final entry in _runtimes.entries) {
      if (!identical(entry.value, runtime)) continue;
      if (session != null) trafficLog?.note(_logLabel(entry.key), 'session closed');
      for (final keyer in _keyers.values) {
        keyer.forgetNode(entry.key);
      }
    }
    // A pending snap belongs to the session that reported the movement. It
    // has nowhere to be sent now, and the next session's first reading is a
    // fresh resting point, not the continuation of a knob turn. Only for the
    // designated radio — nothing else ever feeds the snapper, and clearing it
    // when some other node disconnects would drop a live knob turn.
    if (_localRadio1 != null && identical(_runtimes[_localRadio1], runtime)) _cancelSnap(null);

    if (subscription != null) await subscription.cancel();

    if (session != null) {
      _ptt.forget(session);
      try {
        session.teardown();
      } catch (e, st) {
        ErrorReportingService.report(e, st, context: 'cat:teardown-session');
      }
    }
  }

  /// Says goodbye over a still-open connection, then closes it. Two
  /// independent guards: a throwing teardown must not skip the close.
  /// polo found abandoned sessions accumulating on a radio until it refused
  /// new connections — across a power cycle.
  Future<void> _teardown(_NodeRuntime runtime) async {
    final connection = runtime.connection;
    await _closeSession(runtime);
    if (connection != null) {
      try {
        await connection.close();
      } catch (e, st) {
        ErrorReportingService.report(e, st, context: 'cat:close-connection');
      }
    }
  }
}
