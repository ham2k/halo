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
    if (!runtime.state.stale) return;
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
    });
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
    if (uuid == radio2) {
      final mode = appModeForRadioReport(current: _radio?.vfo('vfoB').mode, reported: merged.mode, freqKHz: merged.freqKHz);
      _radio?.setVfo('vfoB', freq: merged.freqKHz, mode: mode, origin: VfoOrigin.radio);
      return;
    }
    if (uuid != _localRadio1) return;
    // From what the radio SAID: [merged] fills a missing frequency in from
    // what it was told, which it may not have reached.
    if (reading.freqKHz case final freqKHz?) {
      if (bandForFrequency(freqKHz) case final band?) runtime.lastFreqByBand[bandMemoryKey(band, merged.mode)] = freqKHz;
    }
    if (_heldByBandPick(runtime, reading)) return;
    _followRadio(merged);
  }

  void _followRadio(VfoReading merged) {
    final mode = appModeForRadioReport(current: _radio?.vfoA.mode, reported: merged.mode, freqKHz: merged.freqKHz);
    _radio?.setVfo('vfoA', freq: merged.freqKHz, mode: mode, origin: VfoOrigin.radio);
    _noteSnapReading(merged);
  }
}
