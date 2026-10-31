// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What one MIDI controller's messages do — see docs/design/cat.md § MIDI
// controllers. Device-free: MidiService hands it decoded messages, and it
// acts on a [MidiStation].

import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:halo_core/halo_core.dart' show realNowMillis, superModeForMode;

import '../cat/equipment.dart';
import 'midi_codec.dart';
import 'midi_mapping.dart';
import 'midi_station.dart';
import 'midi_targets.dart';

/// Why a mapped control did nothing — said on the mapping pane's monitor
/// line, so a knob that seems dead says why.
enum MidiIgnored {
  /// No radio for the row: no Main VFO radio of this station's own, or no
  /// Radio B picked.
  noRadio,

  /// A Radio B row while SO2R is off.
  so2rOff,

  /// The radio is in a Digital mode, whose app owns the frequency: a bumped
  /// knob must not move it.
  dataMode,

  /// The Keying experiment is off.
  keyingOff,

  /// The radio has no PTT the app can key.
  noPtt,

  /// PTT keys only in a Phone mode, as the PTT key does: in CW or Digital a
  /// footswitch would key a carrier-less transmitter with nobody speaking.
  notPhone,

  /// The radio is already keyed by something else — the PTT key, a message,
  /// a CAT-server client — which a toggle press does not take over.
  keyedElsewhere,

  /// The radio does not report what this would change (no passband, no
  /// keyer speed).
  unsupported,

  /// The control sent a message that moves nothing.
  noMovement,

  /// A mute on a radio with no mute of its own is its AF gain taken to
  /// zero, and back to where this controller last set it — which it has not
  /// yet: nothing reads a radio's AF gain.
  muteNeedsAf,
}

/// What one message did, for the monitor line. [value] is language-free —
/// a frequency, a band, a mode, watts, `TX` / `RX` — or null when the
/// target's name says it all.
class MidiOutcome {
  final MidiTarget target;
  final MidiIgnored? ignored;
  final String? value;

  const MidiOutcome(this.target, {this.ignored, this.value});
}

/// How long a tune the controller made stands as the base for its next
/// step, ahead of what the radio reports. A radio's poll lags a fast knob,
/// and stepping from a lagging echo would walk the dial backwards.
const midiHoldMillis = 1500;

/// What a knob last sent, standing as the base for its next step while the
/// radio reports only values the knob [sent] — its lagging echo. A value it
/// never sent is a change made elsewhere (a spot clicked, the radio's own
/// dial), and the next step builds on that instead of tuning back.
typedef _Hold<T> = ({T value, int at, Set<T> sent});

/// Encoders and faders can send hundreds of messages a second, and most
/// targets cost a CAT command each: one apply per target per this.
const midiFlushInterval = Duration(milliseconds: 40);

const _passbandLimitHz = 20000;

class MidiController {
  final MidiStation station;
  MidiMapping mapping;

  /// The real clock, not the app's: a hold window is a protocol timing,
  /// which developer time travel must not stretch (docs/design/time.md).
  final int Function() _now;

  MidiController({required this.station, required this.mapping, int Function()? now}) : _now = now ?? realNowMillis;

  final _pressed = <String, bool>{};
  final _lastRaw = <String, int>{};
  final _pendingTicks = <String, int>{};
  final _pendingFader = <String, double>{};
  Timer? _flushTimer;

  /// The radio this controller keyed, which its release (or its going away)
  /// unkeys. Null when it keyed nothing — a release then leaves alone a key
  /// someone else holds.
  String? _keyedRadio;

  final _heldFreqHz = <String, _Hold<int>>{};
  final _heldWpm = <String, _Hold<int>>{};
  final _heldPassband = <String, _Hold<Passband>>{};

  /// The base a step on [radio] builds on: the hold, while it stands, else
  /// [reported].
  T? _base<T>(Map<String, _Hold<T>> holds, String radio, T? reported, int now) {
    final held = holds[radio];
    if (held != null && now - held.at < midiHoldMillis && (reported == null || held.sent.contains(reported))) return held.value;
    holds.remove(radio);
    return reported;
  }

  void _hold<T>(Map<String, _Hold<T>> holds, String radio, {required T from, required T to, required int now}) =>
      holds[radio] = (value: to, at: now, sent: {...?holds[radio]?.sent, from, to});

  /// What [message] did — or null when no target is mapped to its control.
  MidiOutcome? handle(MidiControlMessage message) {
    final id = mapping.targetFor(message.control);
    final target = id == null ? null : midiTargetById(id);
    if (target == null || !target.kind.accepts.contains(message.control.kind)) return null;
    return switch (target.kind) {
      MidiTargetKind.encoder => _encoder(target, message),
      MidiTargetKind.fader => _fader(target, message),
      MidiTargetKind.button => _button(target, message),
    };
  }

  /// Forgets what is pressed and unkeys what this controller keyed: the
  /// device went away, or Learn is about to swallow its messages — a PTT
  /// release among them.
  void releaseAll() {
    _pressed.clear();
    _lastRaw.clear();
    _pendingTicks.clear();
    _pendingFader.clear();
    _flushTimer?.cancel();
    _flushTimer = null;
    _unkey();
  }

  /// A control just learned is down: its own release must not act.
  void notePressed(String targetId, {required bool on}) => _pressed[targetId] = on;

  /// Forgets a key this controller put down that is down no longer —
  /// Escape, the timeout, the other radio's key — so its release leaves
  /// alone whatever keys that radio next. MidiService calls it on every
  /// CatService notification, a PTT change among them.
  void forgetDroppedKey() {
    if (_keyedRadio case final radio? when !station.pttHeld(radio) && !station.pttWaiting(radio)) _keyedRadio = null;
  }

  void dispose() => releaseAll();

  // ---- encoders ----

  MidiOutcome _encoder(MidiTarget target, MidiControlMessage message) {
    // Read first, even when ignored: an absolute knob tracks its position.
    final ticks = midiEncoderTicks(message.raw, mapping.codingFor(target.id), last: _lastRaw[target.id]);
    _lastRaw[target.id] = message.raw;
    if (ticks == 0) return MidiOutcome(target, ignored: MidiIgnored.noMovement);
    if (_radioIgnored(target) case final ignored?) return MidiOutcome(target, ignored: ignored);
    final radio = target.radio!;
    switch (target.action) {
      case MidiAction.vfoCoarse || MidiAction.vfoFine:
        if (_superMode(radio) == 'Digital') return MidiOutcome(target, ignored: MidiIgnored.dataMode);
      case MidiAction.wpm:
        if (!station.keyingEnabled) return MidiOutcome(target, ignored: MidiIgnored.keyingOff);
        if (station.keyerSpeed(radio) == null && _heldWpm[radio] == null) return MidiOutcome(target, ignored: MidiIgnored.unsupported);
      case MidiAction.passbandLow || MidiAction.passbandHigh:
        if (station.passband(radio) == null) return MidiOutcome(target, ignored: MidiIgnored.unsupported);
      default:
        break;
    }
    _pendingTicks[target.id] = (_pendingTicks[target.id] ?? 0) + ticks;
    _schedule();
    final step = target.tunes || target.action == MidiAction.passbandLow || target.action == MidiAction.passbandHigh
        ? ' × ${midiStepLabel(mapping.stepFor(target, cw: _superMode(radio) == 'CW'))}'
        : '';
    return MidiOutcome(target, value: '${ticks > 0 ? '+' : '−'}${ticks.abs()}$step');
  }

  // ---- faders ----

  MidiOutcome _fader(MidiTarget target, MidiControlMessage message) {
    if (_radioIgnored(target) case final ignored?) return MidiOutcome(target, ignored: ignored);
    final levels = station.receiveLevels(target.radio!);
    if ((target.action == MidiAction.afGain && !levels.af) || (target.action == MidiAction.rfGain && !levels.rf)) {
      return MidiOutcome(target, ignored: MidiIgnored.unsupported);
    }
    _pendingFader[target.id] = message.value;
    _schedule();
    return MidiOutcome(target, value: target.action == MidiAction.power ? '${_watts(target.radio!, message.value)} W' : '${(message.value * 100).round()}%');
  }

  int _watts(String radio, double value) => (value * station.maxWatts(radio)).round();

  // ---- buttons ----

  MidiOutcome? _button(MidiTarget target, MidiControlMessage message) {
    // On the press and release edges only: a button sending CC repeats its
    // value while held.
    final was = _pressed[target.id] ?? false;
    _pressed[target.id] = message.on;
    if (message.on == was) return null;
    if (target.action == MidiAction.ptt) return _ptt(target, pressed: message.on);
    if (!message.on) return null;
    switch (target.action) {
      case MidiAction.stop:
        station.stop();
        return MidiOutcome(target);
      case MidiAction.message:
        if (!station.keyingEnabled) return MidiOutcome(target, ignored: MidiIgnored.keyingOff);
        station.keyMessage(target.message!);
        return MidiOutcome(target, value: 'F${target.message}');
      default:
        break;
    }
    if (_radioIgnored(target) case final ignored?) return MidiOutcome(target, ignored: ignored);
    final radio = target.radio!;
    switch (target.action) {
      case MidiAction.bandUp || MidiAction.bandDown:
        final next = _stepped(station.bands, station.vfo(radio).band, target.action == MidiAction.bandUp ? 1 : -1);
        if (next == null) return MidiOutcome(target, ignored: MidiIgnored.noMovement);
        _heldFreqHz.remove(radio);
        station.pickBand(radio, next);
        return MidiOutcome(target, value: next);
      case MidiAction.modeNext:
        final next = _stepped(station.modes, station.vfo(radio).mode, 1);
        if (next == null) return MidiOutcome(target, ignored: MidiIgnored.noMovement);
        station.setMode(radio, next);
        return MidiOutcome(target, value: next);
      case MidiAction.mute:
        return _mute(target, radio);
      default:
        return null;
    }
  }

  /// Whether each radio is muted, as this controller left it.
  final _muted = <String, bool>{};

  /// The AF gain this controller last set on each radio: where an emulated
  /// mute comes back to.
  final _lastAf = <String, double>{};

  /// Each press flips. A radio with a mute of its own takes it; one without
  /// is muted by its AF gain, which comes back to where this controller
  /// last set it.
  MidiOutcome _mute(MidiTarget target, String radio) {
    final levels = station.receiveLevels(radio);
    final mute = !(_muted[radio] ?? false);
    if (levels.mute) {
      station.setReceiveLevel(radio, muted: mute);
    } else if (!levels.af) {
      return MidiOutcome(target, ignored: MidiIgnored.unsupported);
    } else if (_lastAf[radio] case final af?) {
      station.setReceiveLevel(radio, af: mute ? 0 : af);
    } else {
      return MidiOutcome(target, ignored: MidiIgnored.muteNeedsAf);
    }
    _muted[radio] = mute;
    return MidiOutcome(target, value: mute ? 'MUTE' : 'ON');
  }

  /// The option [delta] away from [current], wrapping; from nothing, the
  /// first going up and the last going down.
  static String? _stepped(List<String> options, String? current, int delta) {
    if (options.isEmpty) return null;
    final at = current == null ? -1 : options.indexOf(current);
    if (at < 0) return delta > 0 ? options.first : options.last;
    final next = options[(at + delta) % options.length];
    return next == current ? null : next;
  }

  /// Hold: transmit while pressed. Toggle: each press flips, releases are
  /// ignored — CatPtt's own timeout caps a latched key, as it caps the PTT
  /// key's.
  MidiOutcome? _ptt(MidiTarget target, {required bool pressed}) {
    final radio = target.radio!;
    final toggle = mapping.pttToggles(target.id);
    if (!pressed) {
      if (toggle || _keyedRadio != radio) return null;
      _unkey();
      return MidiOutcome(target, value: 'RX');
    }
    if (_radioIgnored(target) case final ignored?) return MidiOutcome(target, ignored: ignored);
    final keyed = station.pttHeld(radio) || station.pttWaiting(radio);
    if (keyed) {
      if (toggle && _keyedRadio == radio) {
        _unkey();
        return MidiOutcome(target, value: 'RX');
      }
      return MidiOutcome(target, ignored: MidiIgnored.keyedElsewhere);
    }
    if (!station.keyingEnabled) return MidiOutcome(target, ignored: MidiIgnored.keyingOff);
    if (!station.canPtt(radio)) return MidiOutcome(target, ignored: MidiIgnored.noPtt);
    if (_superMode(radio) != 'Phone') return MidiOutcome(target, ignored: MidiIgnored.notPhone);
    // One key at a time: a second radio's press takes the key from the first,
    // as SO2R's own toggle does.
    if (_keyedRadio != null) _unkey();
    station.togglePtt(radio);
    if (!station.pttHeld(radio) && !station.pttWaiting(radio)) return MidiOutcome(target, ignored: MidiIgnored.noPtt);
    _keyedRadio = radio;
    return MidiOutcome(target, value: 'TX');
  }

  void _unkey() {
    final radio = _keyedRadio;
    _keyedRadio = null;
    // Only a key still down: one dropped meanwhile (Escape, the timeout)
    // leaves nothing of ours to release, and a release then would drop a
    // key someone else has since put down.
    if (radio != null && (station.pttHeld(radio) || station.pttWaiting(radio))) station.releasePtt();
  }

  // ---- shared ----

  MidiIgnored? _radioIgnored(MidiTarget target) {
    final radio = target.radio;
    if (radio == null) return null;
    if (radio == 'B' && !station.so2rOn) return MidiIgnored.so2rOff;
    if (station.radioUuid(radio) == null) return MidiIgnored.noRadio;
    return null;
  }

  String? _superMode(String radio) => superModeForMode(station.vfo(radio).mode);

  void _schedule() => _flushTimer ??= Timer(midiFlushInterval, flush);

  /// Applies what queued since the last flush: one command per target, and
  /// one tune per radio however many of its knobs turned.
  @visibleForTesting
  void flush() {
    _flushTimer?.cancel();
    _flushTimer = null;
    final now = _now();
    final faders = Map.of(_pendingFader);
    _pendingFader.clear();
    for (final MapEntry(key: id, :value) in faders.entries) {
      final target = midiTargetById(id)!;
      if (_radioIgnored(target) != null) continue;
      final radio = target.radio!;
      switch (target.action) {
        case MidiAction.power:
          station.setPower(radio, _watts(radio, value));
        case MidiAction.afGain:
          _lastAf[radio] = value;
          // Moving the AF gain is hearing the radio again: an emulated mute
          // ends with it, as the knob on a muted radio's front panel would.
          if (!station.receiveLevels(radio).mute) _muted[radio] = false;
          station.setReceiveLevel(radio, af: value);
        case MidiAction.rfGain:
          station.setReceiveLevel(radio, rf: value);
        default:
          break;
      }
    }
    final ticks = Map.of(_pendingTicks)..removeWhere((_, n) => n == 0);
    _pendingTicks.clear();
    for (final radio in const ['A', 'B']) {
      final mine = [
        for (final target in midiTargets)
          if (target.radio == radio && ticks.containsKey(target.id)) target,
      ];
      if (mine.isEmpty || station.radioUuid(radio) == null) continue;
      if (radio == 'B' && !station.so2rOn) continue;
      _flushTune(radio, mine.where((t) => t.tunes), ticks, now);
      _flushWpm(radio, mine.where((t) => t.action == MidiAction.wpm), ticks, now);
      _flushPassband(radio, mine.where((t) => t.action == MidiAction.passbandLow || t.action == MidiAction.passbandHigh), ticks, now);
    }
  }

  void _flushTune(String radio, Iterable<MidiTarget> rows, Map<String, int> ticks, int now) {
    if (rows.isEmpty) return;
    final vfo = station.vfo(radio);
    final base = _base(_heldFreqHz, radio, vfo.freqKHz == null ? null : (vfo.freqKHz! * 1000).round(), now);
    if (base == null || base <= 0) return;
    final cw = superModeForMode(vfo.mode) == 'CW';
    // Coarse then fine, each snapped to its own step.
    var hz = base;
    for (final target in rows) {
      hz = midiStepFrequency(hz, ticks[target.id]!, mapping.stepFor(target, cw: cw));
    }
    if (hz <= 0) return;
    _hold(_heldFreqHz, radio, from: base, to: hz, now: now);
    station.tune(radio, hz / 1000);
  }

  void _flushWpm(String radio, Iterable<MidiTarget> rows, Map<String, int> ticks, int now) {
    if (rows.isEmpty || !station.keyingEnabled) return;
    final base = _base(_heldWpm, radio, station.keyerSpeed(radio), now);
    if (base == null) return;
    final range = station.keyerSpeedRange(radio);
    var wpm = base + rows.fold<int>(0, (sum, t) => sum + ticks[t.id]!);
    if (range != null) wpm = wpm.clamp(range.min, range.max);
    if (wpm == base) return;
    if (station.setKeyerSpeed(radio, wpm)) _hold(_heldWpm, radio, from: base, to: wpm, now: now);
  }

  void _flushPassband(String radio, Iterable<MidiTarget> rows, Map<String, int> ticks, int now) {
    if (rows.isEmpty) return;
    final base = _base(_heldPassband, radio, station.passband(radio), now);
    if (base == null) return;
    final cw = _superMode(radio) == 'CW';
    var low = base.lowHz, high = base.highHz;
    for (final target in rows) {
      final delta = ticks[target.id]! * mapping.stepFor(target, cw: cw);
      if (target.action == MidiAction.passbandLow) low += delta;
      if (target.action == MidiAction.passbandHigh) high += delta;
    }
    // An edge stops where it would cross the other, or leave what a driver
    // takes — PanelRadioService's own bounds.
    low = low.clamp(-_passbandLimitHz, _passbandLimitHz);
    high = high.clamp(-_passbandLimitHz, _passbandLimitHz);
    if (low >= high) return;
    final next = Passband(low, high);
    if (next == base) return;
    _hold(_heldPassband, radio, from: base, to: next, now: now);
    station.setPassband(radio, next);
  }
}
