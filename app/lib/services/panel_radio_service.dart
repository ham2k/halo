// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
import 'dart:async';
import 'dart:convert';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_core/halo_core.dart' show realNowMillis, nowMillis;
import 'cat/cat_service.dart';
import 'cat/equipment.dart';
import 'cat/equipment_registry.dart';
import 'cat/spectrum.dart';
import 'radio_service.dart';

/// [state]'s meter readings still worth showing, by [RadioMeter] name — none
/// unless it is [live]. The receive signal lingers two seconds, past the
/// usual expiry: it pauses while the radio transmits.
Map<String, num> liveMeters(EquipmentState state, {required bool live}) => {
  if (live)
    for (final meter in RadioMeter.values)
      if (state.telemetry.fresh(meter, nowMillis(), linger: meter == RadioMeter.signalDbm ? const Duration(seconds: 2) : meterLinger) case final reading?)
        meter.name: reading.value,
};

/// Narrow extension adapter. CAT retains sessions, telemetry and echo handling.
class PanelRadioService {
  final CatService cat;
  final RadioService radio;
  Future<void> _tail = Future.value();
  final _rawTails = <String, Future<void>>{};
  final _rawWaiting = <String, int>{};
  int _lastCommand = 0;

  /// Whether a radio's linked SDR stands in for its own scope — the SDR
  /// receivers experiment, `fall` in experiments.yaml.
  final bool Function() sdrEnabled;

  /// Whether `keying` is reported and the keying calls act at all — the
  /// `keyer` experiment, which gates the app's own keying surfaces too.
  final bool Function() keyingEnabled;

  /// The operator's opt-in to the app keying PTT at all, off by default: a
  /// panel keys PTT only where the app's own PTT key would.
  final bool Function() pttEnabled;
  PanelRadioService(this.cat, this.radio, {this.sdrEnabled = _never, this.keyingEnabled = _never, this.pttEnabled = _never});

  static bool _never() => false;

  List<Map<String, dynamic>> list() => [
    for (final node in cat.nodes)
      if (cat.typeFor(node)?.category == kCategoryTransceiver) read(node.uuid),
  ];

  Map<String, dynamic> read([String? selection]) {
    final id =
        selection ??
        switch (cat.radio1) {
          LocalRadio(:final uuid) => uuid,
          _ => null,
        };
    final candidate = id == null ? null : cat.nodeFor(id);
    final node = selection != null && candidate != null && cat.typeFor(candidate)?.category != kCategoryTransceiver ? null : candidate;
    // From the NODE, not the id: a selection naming an antenna switch or a
    // keyer has no node here, and must not answer with that device's status,
    // problem text or frequency under a capability that reads radios.
    final state = node == null ? const EquipmentState() : cat.stateFor(node.uuid);
    final live = node != null && state.status == EquipmentStatus.connected && !state.stale && state.problem == null;
    final telemetry = state.telemetry;
    final type = node == null ? null : cat.typeFor(node);
    final config = type?.driverConfig(node!.config);
    return {
      'id': node?.uuid,
      'name': node == null ? null : cat.displayNameFor(node),
      'deviceId': ?(node == null ? null : cat.logicalDeviceIdFor(node.uuid)),
      'channel': ?(node == null ? null : cat.logicalChannelFor(node.uuid)),
      'status': state.status.name,
      'stale': state.stale,
      'problem': state.problem ?? state.error,
      'frequencyHz': state.vfo.freqKHz == null ? null : (state.vfo.freqKHz! * 1000).round(),
      'mode': state.vfo.mode,
      'powerWatts': live ? state.power : null,
      'tuner': live ? state.tuner?.name : null,
      'canStartTune': live && cat.canStartTuneFor(node.uuid),
      'passband': switch (live ? state.passband : null) {
        final p? => {'lowHz': p.lowHz, 'highHz': p.highHz},
        null => null,
      },
      'antennas': switch (live ? state.antennas : null) {
        final a? => {'rxPorts': a.rxPorts, 'txPorts': a.txPorts, 'rx': a.rx, 'tx': a.tx, 'separate': a.separate},
        null => null,
      },
      'transmitting': live ? telemetry.transmitting : null,
      'meters': liveMeters(state, live: live),
      'lastTransmission': switch (node == null ? null : cat.lastTransmissionFor(node.uuid)) {
        (:final swrAverage, :final endedAtMillis) => {'swrAverage': swrAverage, 'endedAtMillis': endedAtMillis},
        null => null,
      },
      'canTune': live && state.vfo.freqKHz != null,
      // The model's rated ceiling where its entry states one; null leaves the
      // range to the extension rather than inventing one.
      'maxWatts': config?['maxWatts'] as num?,
      'modes': type == null ? const <String>[] : _settableModes(type, config!),
      'keying': live && keyingEnabled() && cat.isRadio1(node.uuid) ? _keying() : null,
      'spectrum': node == null || !live ? null : _spectrum(_spectrumNodeFor(node.uuid)),
    };
  }

  // Less CW-R, as the Station dialog's picker: the app reads a radio's CW-R
  // report as CW, so a CW-R request would read back as refused.
  static List<String> _settableModes(EquipmentType type, Map<String, dynamic> config) => [
    for (final mode in type.driver.settableModes(config))
      if (mode != 'CW-R') mode,
  ];

  /// What the app keys with — the designated key and radio1's own voice
  /// memories and PTT, the same the keyer area offers. Only ever radio1's.
  Map<String, dynamic> _keying() {
    final range = cat.keyerSpeedRange;
    return {
      'canKeyCw': cat.canKeyCw,
      'cwSending': cat.cwSending,
      'keyerSpeedWpm': cat.keyerSpeed,
      'keyerSpeedRange': range == null ? null : {'min': range.min, 'max': range.max},
      'canPtt': pttEnabled() && cat.canPtt,
      'ptt': cat.pttHeldOnRadio1,
      'voiceMemories': [
        if (cat.canPlayVoice)
          for (var n = 1; n <= cat.voiceMemoryCount; n++) {'number': n, 'label': cat.voiceMessageLabel(n)},
      ],
    };
  }

  /// Must agree with the scene's `CatSpectrumSource.resolve`: the settings a
  /// panel reads and sets are those of the scope its control draws.
  String _spectrumNodeFor(String radioUuid) => sdrEnabled() ? cat.spectrumNodeFor(radioUuid) : radioUuid;

  /// The radio's scope as the radio reports it, and what it accepts. Null for
  /// a radio with none; the sweeps themselves are drawn by the host. [uuid]
  /// is where the radio's spectrum comes from — its linked SDR, when it has
  /// one, which reports nothing until a display has connected it.
  Map<String, dynamic>? _spectrum(String uuid) {
    final session = cat.spectrumSessionFor(uuid);
    final sdrProblem = cat.isSdr(uuid) ? cat.sdrConnectionProblem(uuid) : null;
    // An SDR with no display is not connected, and has no settings to tell.
    // Said as a problem rather than as no spectrum at all: a panel that shows
    // its control only for a radio with a spectrum would otherwise never show
    // the one display that connects it.
    if (session == null && cat.isSdr(uuid)) {
      return {
        'problem': sdrProblem ?? t.settings.station.spectrumWaiting,
        'mode': null,
        'spanHz': null,
        'lowHz': null,
        'highHz': null,
        'refLevelDb': null,
        'speed': null,
        'spansHz': const <int>[],
        'refMinDb': 0,
        'refMaxDb': 0,
        'refStepDb': 0,
        'modes': const <String>[],
        'speeds': const <String>[],
      };
    }
    if (session == null) return null;
    final state = cat.stateFor(uuid);
    final settings = state.spectrum;
    final caps = session.spectrumCapabilities;
    return {
      'problem': sdrProblem ?? session.spectrumUnavailable ?? state.spectrumProblem,
      'mode': settings?.mode.name,
      'spanHz': settings?.spanHz,
      'lowHz': settings?.lowHz,
      'highHz': settings?.highHz,
      'refLevelDb': settings?.refLevelDb,
      'speed': settings?.speed?.name,
      'spansHz': caps.spansHz,
      'refMinDb': caps.refMinDb,
      'refMaxDb': caps.refMaxDb,
      'refStepDb': caps.refStepDb,
      'modes': [for (final m in caps.modes) m.name],
      'speeds': [for (final s in caps.speeds) s.name],
    };
  }

  /// Changes the radio's scope. Unpaced, unlike [tune]: a scope setting does
  /// not move the radio off a frequency, and the radio's answer comes back in
  /// [read] like every other reading.
  Map<String, dynamic> setSpectrum(Map<String, dynamic> args) {
    final selection = args['selection'] as String?;
    final state = read(selection);
    if (args['id'] == null || args['id'] != state['id']) return {'accepted': false, 'reason': 'changed', 'state': state};
    final source = _spectrumNodeFor(state['id'] as String);
    final session = cat.spectrumSessionFor(source);
    if (session == null || session.spectrumUnavailable != null) return {'accepted': false, 'reason': 'disconnected', 'state': state};
    T? pick<T extends Enum>(List<T> values, Object? name) => name == null ? null : values.asNameMap()[name];
    final span = args['spanHz'], ref = args['refLevelDb'];
    final mode = pick(SpectrumMode.values, args['mode']), speed = pick(SpectrumSpeed.values, args['speed']);
    final caps = session.spectrumCapabilities;
    // A mode or a speed this radio does not have would be dropped by its
    // driver and answered as accepted.
    if ((span != null && (span is! num || !span.isFinite || span <= 0)) ||
        (ref != null && (ref is! num || !ref.isFinite)) ||
        (args['mode'] != null && (mode == null || !caps.modes.contains(mode))) ||
        (args['speed'] != null && (speed == null || !caps.speeds.contains(speed))) ||
        (span == null && ref == null && mode == null && speed == null)) {
      return {'accepted': false, 'reason': 'invalid', 'state': state};
    }
    final taken = cat.setSpectrum(source, SpectrumRequest(mode: mode, spanHz: (span as num?)?.round(), refLevelDb: (ref as num?)?.toDouble(), speed: speed));
    // Not queued for later: a scope runs only while a display shows it.
    return {'accepted': taken, if (!taken) 'reason': 'stopped', 'state': read(selection)};
  }

  Map<String, dynamic> setConnection(Map<String, dynamic> args) {
    final state = read(args['selection'] as String?);
    if (args['id'] == null || args['id'] != state['id']) {
      return {'accepted': false, 'reason': 'changed', 'state': state};
    }
    if (args['connected'] is! bool) {
      return {'accepted': false, 'reason': 'invalid', 'state': state};
    }
    final id = state['id'] as String;
    if (args['connected'] == true) {
      unawaited(cat.connect(id));
    } else {
      unawaited(cat.disconnect(id));
    }
    return {'accepted': true, 'state': read(args['selection'] as String?)};
  }

  /// Frequency, mode, power, keyer speed, tuner, a tune, passband and antennas. Paced: each one moves the radio,
  /// and a dragged control would otherwise flood its CAT link.
  Future<Map<String, dynamic>> set(Map<String, dynamic> args) async {
    final previous = _tail;
    final done = _perform(previous, args);
    _tail = done.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return done;
  }

  Future<Map<String, dynamic>> _perform(Future<void> previous, Map<String, dynamic> args) async {
    await previous;
    final delay = 250 - (realNowMillis() - _lastCommand);
    if (delay > 0) await Future<void>.delayed(Duration(milliseconds: delay));
    final selection = args['selection'] as String?;
    final state = read(selection);
    String? reason;
    final frequency = args['frequencyHz'];
    final mode = args['mode'];
    final power = args['powerWatts'];
    final wpm = args['keyerSpeedWpm'];
    final tunerInline = args['tunerInline'];
    final startTune = args['startTune'];
    final antenna = args['antenna'];
    final antennas = state['antennas'] as Map<String, dynamic>?;
    final asked = [frequency, mode, power, wpm, tunerInline, startTune, args['passband'], antenna].nonNulls.length;
    // A port this radio names for that direction, or nothing asked of it. A radio that lists
    // only the transmit port and its receive-only input for receive also takes a receive
    // antenna moved along with the transmit one.
    bool port(Object? name, String list) =>
        name == null ||
        (name is String &&
            ((antennas?[list] as List?)?.contains(name) == true || (list == 'rxPorts' && antenna is Map && name == antenna['tx'] && port(name, 'txPorts'))));
    final passband = switch (args['passband']) {
      {'lowHz': final int low, 'highHz': final int high} when low < high && low.abs() <= 20000 && high.abs() <= 20000 => Passband(low, high),
      _ => null,
    };
    final maxWatts = state['maxWatts'] as num?;
    final keying = state['keying'] as Map<String, dynamic>?;
    if (args['id'] == null || args['id'] != state['id']) {
      reason = 'changed';
    } else if (state['canTune'] != true) {
      reason = 'disconnected';
    } else if (state['transmitting'] == true) {
      reason = 'transmitting';
    } else if (antenna != null && antennas == null) {
      reason = 'unsupported';
    } else if (asked == 0 ||
        // A tune is a carrier on the air, tuned for where the radio is: alone, so it never goes out
        // on a frequency or into a tuner this same call was still moving.
        (startTune != null && (startTune != true || asked > 1)) ||
        (antenna != null &&
            (antenna is! Map ||
                (antenna['rx'] == null && antenna['tx'] == null) ||
                !port(antenna['rx'], 'rxPorts') ||
                !port(antenna['tx'], 'txPorts') ||
                // One port serves both: two different ones cannot both be had.
                (antennas?['separate'] != true && antenna['rx'] != null && antenna['tx'] != null && antenna['rx'] != antenna['tx']))) ||
        (args['passband'] != null && passband == null) ||
        // A driver reads edges against the mode the radio reports, which a mode set in the same
        // call has not changed yet: the filter would land as the old mode's.
        (args['passband'] != null && mode != null && mode != state['mode']) ||
        (tunerInline != null && tunerInline is! bool) ||
        (frequency != null && (frequency is! num || !frequency.isFinite || frequency <= 0 || frequency > 1e12)) ||
        (mode != null && !(state['modes'] as List).contains(mode)) ||
        (power != null && (power is! num || !power.isFinite || power < 0 || (maxWatts != null && power > maxWatts))) ||
        (wpm != null && (wpm is! num || !wpm.isFinite || wpm <= 0))) {
      reason = 'invalid';
    } else if (wpm != null && keying?['canKeyCw'] != true) {
      reason = 'unsupported';
    } else if (tunerInline != null && state['tuner'] == null) {
      reason = 'unsupported';
    } else if (startTune != null && state['canStartTune'] != true) {
      reason = 'unsupported';
    } else if (passband != null && state['passband'] == null) {
      reason = 'unsupported';
    }
    if (reason != null) return {'accepted': false, 'reason': reason, 'state': state};
    _lastCommand = realNowMillis();
    final id = state['id'] as String;
    // First, so that a keyer refusing it leaves the radio as it was rather than refusing a call
    // half of which already went out. The keyer clamps to its own range; its report says what it took.
    if (wpm != null && !cat.setKeyerSpeed((wpm as num).round())) return {'accepted': false, 'reason': 'unsupported', 'state': read(selection)};
    final freqKHz = frequency == null ? null : (frequency as num).toDouble() / 1000;
    if (cat.isRadio1(id)) {
      // Through the app's VFO, as the logging controls do, so the power a
      // panel sets is the power the next QSO logs.
      // `dial`: an on-screen dial turning, which Smart VFO Snap settles like the radio's own knob.
      final origin = args['dial'] == true ? VfoOrigin.dial : VfoOrigin.user;
      if (freqKHz != null || mode != null || power != null) radio.setVfo('vfoA', freq: freqKHz, mode: mode as String?, power: power as num?, origin: origin);
    } else {
      if (freqKHz != null || mode != null) cat.tuneNode(id, VfoReading(freqKHz: freqKHz, mode: mode as String?));
      if (power != null) cat.setNodePower(id, power as num);
    }
    if (tunerInline != null) cat.setNodeTuner(id, inline: tunerInline as bool);
    if (startTune == true) cat.startNodeTune(id);
    if (passband != null) cat.setNodePassband(id, passband);
    if (antenna is Map) cat.setNodeAntenna(id, rx: antenna['rx'] as String?, tx: antenna['tx'] as String?);
    // Acceptance is not an acknowledgement: read() contains only radio reports.
    return {'accepted': true, 'state': read(selection)};
  }

  /// The longest reply window and the largest command `sendRadioRaw` takes,
  /// and how many of one radio's raw calls may wait at once.
  static const rawReplyMaxMs = 2000, rawMaxBytes = 4096, rawMaxWaiting = 8;

  /// Sends [args]' `text` or `bytes` to the radio through its driver
  /// unchecked — anything at all, transmitting included: `requiresRadioRaw` is
  /// the operator's consent to it. Neither paced nor refused while
  /// transmitting, unlike [set], but one at a time per radio, so that one
  /// call's reply window never holds another's answer — and refused as `busy`
  /// past [rawMaxWaiting], so that an extension calling in a loop cannot hold
  /// every later call back without end.
  Future<Map<String, dynamic>> sendRaw(Map<String, dynamic> args) {
    final radio = '${args['id']}';
    final waiting = _rawWaiting[radio] ?? 0;
    if (waiting >= rawMaxWaiting) return Future.value({'accepted': false, 'reason': 'busy', 'state': read(args['selection'] as String?)});
    _rawWaiting[radio] = waiting + 1;
    final done = (_rawTails[radio] ?? Future<void>.value()).then((_) => _performRaw(args)).whenComplete(() {
      final left = _rawWaiting[radio]! - 1;
      if (left > 0) {
        _rawWaiting[radio] = left;
      } else {
        _rawWaiting.remove(radio);
        _rawTails.remove(radio);
      }
    });
    _rawTails[radio] = done.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return done;
  }

  Future<Map<String, dynamic>> _performRaw(Map<String, dynamic> args) async {
    final selection = args['selection'] as String?;
    final state = read(selection);
    Map<String, dynamic> refused(String reason) => {'accepted': false, 'reason': reason, 'state': state};
    if (args['id'] == null || args['id'] != state['id']) return refused('changed');
    final bytes = _rawBytes(args['text'], args['bytes']);
    final replyMs = args['replyMs'] ?? 0;
    final until = switch (args['until']) {
      null => null,
      // Empty when malformed, which is refused below.
      final String text => _rawBytes(text, null) ?? const <int>[],
      final List<dynamic> bytes => _rawBytes(null, bytes) ?? const <int>[],
      _ => const <int>[],
    };
    if (bytes == null ||
        bytes.length > rawMaxBytes ||
        replyMs is! int ||
        replyMs < 0 ||
        replyMs > rawReplyMaxMs ||
        (until != null && (until.isEmpty || replyMs == 0))) {
      return refused('invalid');
    }
    final result = await cat.sendNodeRaw(
      state['id'] as String,
      bytes,
      reply: Duration(milliseconds: replyMs),
      until: until,
    );
    if (result.refused case final reason?) return refused(reason);
    return {
      'accepted': true,
      if (result.reply case final reply?) 'reply': {'text': utf8.decode(reply, allowMalformed: true), 'bytes': reply},
      'state': read(selection),
    };
  }

  /// Exactly one of [text] (sent as UTF-8) or [bytes] (each 0…255), not
  /// empty — or null.
  static List<int>? _rawBytes(Object? text, Object? bytes) => switch ((text, bytes)) {
    (final String text, null) when text.isNotEmpty => utf8.encode(text),
    (null, final List<dynamic> bytes) when bytes.isNotEmpty && bytes.every((b) => b is int && b >= 0 && b <= 255) => bytes.cast<int>(),
    _ => null,
  };

  /// The radio [args] names, if it is the one the app keys with — or why not.
  /// Keying is radio1's: a panel pinned to another radio is refused rather
  /// than keying the logging radio behind the operator's back.
  ({Map<String, dynamic> state, String? reason}) _keyingTarget(Map<String, dynamic> args) {
    final state = read(args['selection'] as String?);
    if (args['id'] == null || args['id'] != state['id']) return (state: state, reason: 'changed');
    final id = state['id'] as String;
    if (!cat.isRadio1(id) || !keyingEnabled()) return (state: state, reason: 'unsupported');
    if (state['keying'] == null) return (state: state, reason: 'disconnected');
    return (state: state, reason: null);
  }

  Map<String, dynamic> _refused(({Map<String, dynamic> state, String? reason}) target) => {'accepted': false, 'reason': target.reason, 'state': target.state};

  /// Keys [args]' `text` on the key in use, as the keyer area's messages do.
  Map<String, dynamic> sendCw(Map<String, dynamic> args) {
    final target = _keyingTarget(args);
    if (target.reason != null) return _refused(target);
    final text = args['text'];
    if (text is! String || text.trim().isEmpty || text.length > 1000) return _refused((state: target.state, reason: 'invalid'));
    if (!cat.sendCw(text)) return _refused((state: target.state, reason: 'unsupported'));
    return {'accepted': true, 'state': read(args['selection'] as String?)};
  }

  /// Plays voice memory `memory` once. Never arms the repeat chain: a CQ
  /// repeating on a panel's say-so would be one nobody started from the
  /// keyer area, where the operator stops it.
  Map<String, dynamic> playVoice(Map<String, dynamic> args) {
    final target = _keyingTarget(args);
    if (target.reason != null) return _refused(target);
    final memory = args['memory'];
    final count = ((target.state['keying'] as Map)['voiceMemories'] as List).length;
    if (count == 0) return _refused((state: target.state, reason: 'unsupported'));
    if (memory is! int || memory < 1 || memory > count) return _refused((state: target.state, reason: 'invalid'));
    cat.playVoiceMemory(memory, repeat: false);
    return {'accepted': true, 'state': read(args['selection'] as String?)};
  }

  /// Keys or unkeys radio1's PTT, through the same latch as the app's PTT
  /// key — so the app's own stop releases it.
  Map<String, dynamic> setPtt(Map<String, dynamic> args) {
    // Off is a release, never a toggle — a key held on another radio would be dropped and this one
    // keyed instead — and like a stop it is not refused for a stale identity.
    if (args['on'] == false) {
      cat.pttKeys.release();
      return {'accepted': true, 'state': read(args['selection'] as String?)};
    }
    final target = _keyingTarget(args);
    if (target.reason != null) return _refused(target);
    if (args['on'] != true) return _refused((state: target.state, reason: 'invalid'));
    if (!pttEnabled() || !cat.canPtt) return _refused((state: target.state, reason: 'unsupported'));
    if (!cat.pttHeldOnRadio1) {
      cat.togglePtt(target.state['id'] as String);
      // A radio that refused the key leaves nothing held.
      if (!cat.pttHeldOnRadio1) return _refused((state: read(args['selection'] as String?), reason: 'disconnected'));
    }
    return {'accepted': true, 'state': read(args['selection'] as String?)};
  }

  /// Stops everything the app is keying — CW, voice, PTT and a tune it
  /// started — as Escape does.
  /// Answered even with keying off, the radio gone or its identity stale: a
  /// stop must never be the call that is refused, and it is the app's, not
  /// one radio's.
  Map<String, dynamic> stopTransmit(Map<String, dynamic> args) {
    cat.stopKeying();
    return {'accepted': true, 'state': read(args['selection'] as String?)};
  }
}
