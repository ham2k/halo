// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a connected node's readings do on arrival: prove the radio, keep the
// silence watch armed, and land the VFO in the app's state.

part of 'cat_service.dart';

extension _Readings on CatService {
  /// The equipment just spoke: restart the silence watch, and drop the stale
  /// mark if it was set.
  ///
  /// Anything at all counts, including a report identical to the last one —
  /// a radio answering "still 14074" is a radio that is answering, and a
  /// switch restating its routing is a switch with a live socket.
  void _noteAlive(String uuid, _NodeRuntime runtime) {
    _armStaleWatch(uuid, runtime);
    // Real time: this measures how long a real radio kept answering.
    final now = realNowMillis();
    runtime.answeringSinceMillis ??= now;
    runtime.lastHeardMillis = now;
    if (!runtime.state.stale) return;
    runtime.silenceTimer?.cancel();
    runtime.silenceTimer = null;
    trafficLog?.note(_logLabel(uuid), 'answering again');
    _setState(uuid, runtime.state.copyWith(stale: false));
  }

  /// Restarts the silence watch. Any reading at all counts, including one
  /// that repeats the last: a radio answering "still 14074" is a radio that
  /// is answering.
  void _armStaleWatch(String uuid, _NodeRuntime runtime) {
    runtime.staleTimer?.cancel();
    runtime.staleTimer = Timer(staleAfter, () {
      if (_disposed) return;
      final current = _runtimes[uuid];
      if (current == null || current.state.status != EquipmentStatus.connected) return;
      if (current.state.stale) return;
      trafficLog?.note(_logLabel(uuid), 'nothing heard for ${staleAfter.inSeconds} s: marked not responding');
      _setState(uuid, current.state.copyWith(stale: true));
      _armSilentDrop(uuid, current, silentDropAfter - staleAfter);
    });
  }

  /// Drops and reconnects a designated radio that answered and then went
  /// silent for [silentDropAfter], the way a connection that closed on its
  /// own is reconnected. Armed by the stale mark, so the row reads "not
  /// responding" first.
  ///
  /// The stale mark alone never brings it back. A link can stay open while
  /// the radio answers nothing — the Icom network session keeps its
  /// keepalives flowing after the radio stops answering CI-V — and the row
  /// then reads "not responding" until the operator reconnects by hand.
  ///
  /// Armed only for a radio that kept answering for a whole
  /// [silentDropAfter]. A radio silent since its connect is misconfigured (a
  /// wrong CI-V address, the wrong port), and one that answers once and then
  /// stops (a Yaesu with CAT RTS on, which answers at the open and never
  /// again) comes back the same way; dropping either reconnects it once a
  /// minute for good while changing nothing. A radio that does work for a
  /// while after each connect gets [_silentDropsInARow] drops before it is
  /// left to the operator. Only radio1 and radio2: a keyer device reports
  /// nothing while idle, so silence there is not a dead link.
  void _armSilentDrop(String uuid, _NodeRuntime runtime, Duration after) {
    runtime.silenceTimer?.cancel();
    runtime.silenceTimer = null;
    if (!isRadio1(uuid) && !isRadio2(uuid)) return;
    final connection = runtime.connection;
    final since = runtime.answeringSinceMillis, heard = runtime.lastHeardMillis;
    if (connection == null || since == null || heard == null) return;
    if (heard - since < silentDropAfter.inMilliseconds) return;
    runtime.silenceTimer = Timer(after.isNegative ? Duration.zero : after, () {
      runtime.silenceTimer = null;
      if (_disposed || runtime.connection != connection || !runtime.state.stale) return;
      if (stateFor(uuid).status != EquipmentStatus.connected) return;
      // Designation can move while the timer runs, and a radio that is no
      // longer designated is never reconnected: dropping it would leave it
      // off for good.
      if (!isRadio1(uuid) && !isRadio2(uuid)) return;
      // RF in the CAT cable silences a radio exactly while it transmits, so
      // a radio the app is keying is not judged by its silence until the
      // key is released — [_restartSilentDrops] then gives it a whole window.
      if (_nodeTransmitting(uuid)) return _armSilentDrop(uuid, runtime, silentDropAfter);
      // Keyed some other way (its mic, a footswitch, VOX), all the radio said
      // was that it went on the air. Held off longer, not forever: a radio
      // switched off mid-over says the same.
      final silentFor = realNowMillis() - heard;
      final keyedLimit = (silentDropAfter * _silentWhileKeyedWindows).inMilliseconds;
      if (runtime.state.telemetry.isTransmitting && silentFor < keyedLimit) {
        return _armSilentDrop(uuid, runtime, Duration(milliseconds: keyedLimit - silentFor));
      }
      final shortSession = heard - since < (silentDropAfter * _healthySessionWindows).inMilliseconds;
      if (shortSession && runtime.shortSilentDrops >= _silentDropsInARow) {
        trafficLog?.note(_logLabel(uuid), 'nothing heard for ${silentFor ~/ 1000} s: left alone after $_silentDropsInARow reconnects in a row');
        return;
      }
      runtime.shortSilentDrops = shortSession ? runtime.shortSilentDrops + 1 : 0;
      trafficLog?.note(_logLabel(uuid), 'nothing heard for ${silentFor ~/ 1000} s: reconnecting');
      unawaited(_dropSilent(uuid, runtime));
    });
  }

  /// A released key gives every pending silent drop a whole window from
  /// now: the radio's next poll after the unkey may be seconds away, and the
  /// timer's own deadline may fall before it.
  void _restartSilentDrops() {
    if (_ptt.held.value) return;
    for (final uuid in [?_localRadio1, ?radio2]) {
      final runtime = _runtimes[uuid];
      if (runtime?.silenceTimer != null) _armSilentDrop(uuid, runtime!, silentDropAfter);
    }
  }

  /// Not marked as the operator's: a Disconnect they pressed stops every
  /// retry, and this is the case the retries exist for.
  ///
  /// The reconnect is skipped when anything else touched the node during the
  /// teardown, which is most of a second on an Icom network link. A Connect
  /// pressed in that window would otherwise be cancelled part-way by the
  /// burst, leaving two logins back to back against the radio.
  Future<void> _dropSilent(String uuid, _NodeRuntime runtime) async {
    final ours = runtime.attemptSeq + 1;
    await disconnect(uuid, byUser: false);
    if (runtime.attemptSeq != ours) return;
    _autoReconnectAfterDrop(uuid);
    _scheduleIdleRetry();
  }

  /// Fires [onRadioProven] on the reading that completes the pair. [reading]
  /// is the driver's RAW frame — [RadioProofWatch] says why that matters.
  void _noteProven(String uuid, _NodeRuntime runtime, VfoReading reading) {
    if (!runtime.proof.note(reading)) return;
    if (!_provenThisSession.add(uuid)) return;
    final node = _nodes[uuid];
    if (node == null) return;
    // Never let a reporting failure reach the reading path: this runs on
    // every frame a radio sends, and a throw here would take down the
    // session that is working — the one outcome a success report must not
    // produce.
    try {
      onRadioProven?.call(node);
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:radio-proven');
    }
  }

  void _applyReading(String uuid, VfoReading reading) {
    final runtime = _runtimeFor(uuid);
    // The radio said something, so it is not silent — whatever it said.
    _noteAlive(uuid, runtime);
    _noteProven(uuid, runtime, reading);

    // A partial reading is completed from what the radio was last TOLD
    // before what it last SAID. The two agree except in one window: a tune
    // carrying both fields sends them as two commands, and the rig echoes
    // the first before the second has landed. Filling from the rig's own
    // last word there would answer a mode echo with the PRE-tune frequency
    // and push that back to the panel — a spot tap would visibly bounce the
    // frequency and band back to where the rig came from. `lastSent` falls
    // back per field, so a deliberately cleared frequency (a band pick)
    // still reads through to the radio's value rather than resurrecting one.
    final sent = runtime.lastSent;
    final merged = VfoReading(
      freqKHz: reading.freqKHz ?? sent?.freqKHz ?? runtime.state.vfo.freqKHz,
      // CW-R is reverse-sideband CW, not a mode of its own to the rest of the
      // app — every driver's own vocabulary keeps it (a radio must still be
      // told to flip sideband), but nothing past this point should learn a
      // mode ADIF and the log don't have.
      mode: (reading.mode == 'CW-R' ? 'CW' : reading.mode) ?? sent?.mode ?? runtime.state.vfo.mode,
    );
    // A radio echoing back what it already reported shouldn't churn this
    // service's own listeners — but it must still reach RadioService.
    //
    // Returning here instead would be a permanent desync: pick a band (or
    // clear the frequency field) and vfoA.freq goes null while the radio has
    // not moved, so every later report matches this cache and is swallowed.
    // The panel then shows a band with no frequency, and logs QSOs with it,
    // until the operator physically turns the knob. RadioService.setVfo
    // does its own no-op check, so forwarding unconditionally is free.
    if (merged != runtime.state.vfo) _setState(uuid, runtime.state.copyWith(vfo: merged));

    // What the radio just said is now what it has been told — [tuneNode]'s
    // echo guard, and what keeps a knob turn from coming back to the rig as
    // a command. EVERY node, not just radio1: a radio a peer is driving
    // (HALO-416) needs the same guard and never passes through
    // [_onVfoChanged].
    runtime.lastSent = merged;

    // Only the designated radios drive the app's VFOs. Tagging the write
    // `radio` is what lets _onVfoChanged recognise the notification it's
    // about to receive as its own, instead of re-tuning the radio to the
    // value the radio just gave it.
    final vfoKey = _vfoKeyOf(uuid);
    if (vfoKey == null) return;
    // From what the radio SAID: [merged] fills a missing frequency in from
    // what it was told, which it may not have reached.
    if (reading.freqKHz case final freqKHz?) {
      if (bandForFrequency(freqKHz) case final band?) runtime.lastFreqByBand[bandMemoryKey(band, merged.mode)] = freqKHz;
    }
    if (_heldByBandPick(runtime, reading)) return;
    _followRadio(vfoKey, merged);
  }

  /// The app VFO [uuid] drives: `vfoA` for radio1, `vfoB` for SO2R's Radio
  /// B, null for any other node.
  String? _vfoKeyOf(String uuid) => uuid == _localRadio1
      ? 'vfoA'
      : uuid == radio2
      ? 'vfoB'
      : null;

  void _followRadio(String vfoKey, VfoReading merged) {
    final mode = appModeForRadioReport(current: _radio?.vfo(vfoKey).mode, reported: merged.mode, freqKHz: merged.freqKHz);
    _radio?.setVfo(vfoKey, freq: merged.freqKHz, mode: mode, origin: VfoOrigin.radio);
    // Smart VFO Snap is radio1's.
    if (vfoKey == 'vfoA') _noteSnapReading(merged);
  }
}
