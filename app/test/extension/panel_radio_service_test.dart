// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/cat/cat_ptt.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';
import 'package:ham2k_logger/services/panel_radio_service.dart';
import 'package:ham2k_logger/services/radio_service.dart';

class TestDriver extends Fake implements EquipmentDriver {
  @override
  List<String> settableModes(Map<String, dynamic> config) => const ['LSB', 'USB', 'CW', 'CW-R', 'AM', 'FM', 'DATA-USB'];
}

class TestRadioType extends Fake implements EquipmentType {
  TestRadioType([this.config = const {}]);
  final Map<String, dynamic> config;
  @override
  String get category => kCategoryTransceiver;
  @override
  EquipmentDriver get driver => TestDriver();
  @override
  Map<String, dynamic> driverConfig(Map<String, dynamic> stored) => config;
}

class TestSwitchType extends Fake implements EquipmentType {
  @override
  String get category => kCategoryAntennaSwitch;
}

class TestCat extends Fake implements CatService {
  MainVfo? selected = const LocalRadio('a');
  EquipmentState state = const EquipmentState(
    status: EquipmentStatus.connected,
    vfo: VfoReading(freqKHz: 14074, mode: 'USB'),
  );
  @override
  MainVfo? get radio1 => selected;
  @override
  EquipmentNode? nodeFor(String uuid) => ['a', 'b', 'switch'].contains(uuid) ? EquipmentNode(uuid: uuid, typeKey: 'test') : null;
  @override
  List<EquipmentNode> get nodes => [nodeFor('a')!, nodeFor('b')!, nodeFor('switch')!];
  Map<String, dynamic> modelConfig = const {};
  @override
  EquipmentType? typeFor(EquipmentNode node) => node.uuid == 'switch' ? TestSwitchType() : TestRadioType(modelConfig);
  @override
  bool isRadio1(String uuid) => selected == LocalRadio(uuid);
  final connections = <String>[];
  @override
  Future<void> connect(String uuid) async {
    connections.add('connect:$uuid');
  }

  @override
  Future<void> disconnect(String uuid, {bool byUser = true}) async {
    connections.add('disconnect:$uuid');
  }

  final tuned = <String, VfoReading>{};
  @override
  void tuneNode(String uuid, VfoReading wanted) {
    tuned[uuid] = wanted;
  }

  @override
  EquipmentState stateFor(String uuid) => state;

  final powered = <String, num>{};
  @override
  void setNodePower(String uuid, num watts) => powered[uuid] = watts;

  final tuners = <String, bool>{};
  @override
  void setNodeTuner(String uuid, {required bool inline}) => tuners[uuid] = inline;

  final passbands = <String, Passband>{};
  @override
  void setNodePassband(String uuid, Passband passband) => passbands[uuid] = passband;

  final antennas = <String, (String?, String?)>{};
  @override
  void setNodeAntenna(String uuid, {String? rx, String? tx}) => antennas[uuid] = (rx, tx);

  ({double? swrAverage, int endedAtMillis})? lastTransmission;
  @override
  ({double? swrAverage, int endedAtMillis})? lastTransmissionFor(String uuid) => lastTransmission;

  // What the app keys with — the keyer area's own view of it.
  bool keysCw = true, playsVoice = true, hasPtt = true, speedRefused = false, pttRefused = false;
  final keyed = <String>[];
  final pttHeld = ValueNotifier(false);

  /// The radio the app's PTT key is on, as CatPtt holds it: one radio at a time.
  String? pttOn;
  @override
  bool get canKeyCw => keysCw;
  @override
  bool get cwSending => false;
  @override
  int? get keyerSpeed => 22;
  @override
  ({int min, int max})? get keyerSpeedRange => (min: 5, max: 50);
  @override
  bool setKeyerSpeed(int wpm) {
    keyed.add('wpm:$wpm');
    return keysCw && !speedRefused;
  }

  @override
  bool get canPlayVoice => playsVoice;
  @override
  int get voiceMemoryCount => 2;
  @override
  String voiceMessageLabel(int n) => 'Message $n';
  @override
  bool get canPtt => hasPtt;
  @override
  late final PttKeyboard pttKeys = PttKeyboard(
    held: pttHeld,
    release: () {
      keyed.add('release');
      final was = pttOn != null;
      pttOn = null;
      pttHeld.value = false;
      return was;
    },
    escape: () => false,
    toggle: (_) {},
  );
  @override
  bool get pttHeldOnRadio1 => pttOn != null && isRadio1(pttOn!);
  @override
  bool sendCw(String text, {bool hasMessageOne = false}) {
    keyed.add('cw:$text');
    return keysCw;
  }

  @override
  void playVoiceMemory(int n, {bool repeat = true}) => keyed.add('voice:$n:${repeat ? 'repeat' : 'once'}');
  @override
  void togglePtt(String radio) {
    // CatPtt.toggle: the radio it holds drops; any other radio is keyed, dropping the one held.
    pttOn = pttOn == radio || pttRefused ? null : radio;
    pttHeld.value = pttOn != null;
    keyed.add('ptt:$radio:${pttOn == radio}');
  }

  @override
  bool stopKeying() {
    keyed.add('stop');
    return true;
  }

  EquipmentSession? session;
  @override
  EquipmentSession? connectedSession(String uuid) => session;
  @override
  String displayNameFor(EquipmentNode node) => 'Test radio';
}

class TestScope extends Fake implements SpectrumSession {
  String? unavailable;
  final requests = <SpectrumRequest>[];
  bool running = true;
  @override
  String? get spectrumUnavailable => unavailable;
  @override
  SpectrumCapabilities get spectrumCapabilities =>
      const SpectrumCapabilities(spansHz: [25000, 50000], refMinDb: -20, refMaxDb: 20, refStepDb: .5, speeds: {SpectrumSpeed.slow, SpectrumSpeed.fast});
  @override
  bool setSpectrum(SpectrumRequest request) {
    if (running) requests.add(request);
    return running;
  }
}

class TestRadio extends Fake implements RadioService {
  final calls = <({double? freq, String? mode, num? power, int time})>[];
  @override
  void setVfo(
    String key, {
    double? freq,
    String? band,
    String? mode,
    num? power,
    bool clearFreq = false,
    bool clearPower = false,
    VfoOrigin origin = VfoOrigin.user,
  }) {
    calls.add((freq: freq, mode: mode, power: power, time: realNowMillis()));
  }
}

void main() {
  test('connection requests honor placement selection and reject stale identities', () {
    final cat = TestCat(), bridge = PanelRadioService(TestCat(), TestRadio());
    final local = PanelRadioService(cat, TestRadio());
    expect(local.setConnection({'id': 'b', 'connected': false})['reason'], 'changed');
    expect(cat.connections, isEmpty);
    expect(local.setConnection({'id': 'b', 'selection': 'b', 'connected': false})['accepted'], true);
    expect(local.setConnection({'id': 'a', 'connected': true})['accepted'], true);
    expect(cat.connections, ['disconnect:b', 'connect:a']);
    expect(bridge.setConnection({'id': 'a', 'connected': 'yes'})['reason'], 'invalid');
  });

  test('CAT reports remain distinct from requested VFO writes and units cross correctly', () async {
    final cat = TestCat(), radio = TestRadio(), bridge = PanelRadioService(cat, radio);
    expect(bridge.read()['frequencyHz'], 14074000);
    final result = await bridge.set({'id': 'a', 'frequencyHz': 14075000, 'mode': 'CW'});
    expect(result['accepted'], true);
    expect(radio.calls.single.freq, 14075);
    expect(radio.calls.single.mode, 'CW');
    expect((result['state'] as Map)['frequencyHz'], 14074000);
  });
  test('changed selection, stale state, TX and invalid commands never reach CAT', () async {
    final cat = TestCat(), radio = TestRadio(), bridge = PanelRadioService(cat, radio);
    expect((await bridge.set({'id': 'b', 'frequencyHz': 14075000}))['reason'], 'changed');
    cat.state = cat.state.copyWith(stale: true);
    expect((await bridge.set({'id': 'a', 'frequencyHz': 14075000}))['reason'], 'disconnected');
    cat.state = cat.state.copyWith(stale: false, telemetry: const RadioTelemetry(transmitting: true));
    expect((await bridge.set({'id': 'a', 'mode': 'CW'}))['reason'], 'transmitting');
    cat.state = cat.state.copyWith(telemetry: const RadioTelemetry(transmitting: false));
    expect((await bridge.set({'id': 'a', 'frequencyHz': double.nan}))['reason'], 'invalid');
    expect(radio.calls, isEmpty);
  });
  test('command pacing preserves the final value and rechecks selection after waiting', () async {
    final cat = TestCat(), radio = TestRadio(), bridge = PanelRadioService(cat, radio);
    await bridge.set({'id': 'a', 'frequencyHz': 14075000});
    await bridge.set({'id': 'a', 'frequencyHz': 14076000});
    expect(radio.calls.last.time - radio.calls.first.time, greaterThanOrEqualTo(250));
    expect(radio.calls.last.freq, 14076);
    final waiting = bridge.set({'id': 'a', 'frequencyHz': 14077000});
    cat.selected = const LocalRadio('b');
    expect((await waiting)['reason'], 'changed');
    expect(radio.calls, hasLength(2));
  });
  test('pinned panels read and tune their radio without changing the logging designation', () async {
    final cat = TestCat(), radio = TestRadio(), bridge = PanelRadioService(cat, radio);
    expect(bridge.list().map((r) => r['id']), ['a', 'b']);
    expect(bridge.read('b')['id'], 'b');
    final result = await bridge.set({'selection': 'b', 'id': 'b', 'frequencyHz': 7100000});
    expect(result['accepted'], true);
    expect(cat.tuned['b']?.freqKHz, 7100);
    expect(radio.calls, isEmpty);
    expect(cat.radio1, const LocalRadio('a'));
    expect((await bridge.set({'selection': 'gone', 'id': 'gone', 'frequencyHz': 7100000}))['reason'], 'changed');
  });
  test('expired telemetry is omitted instead of looking like fresh RF output', () {
    final cat = TestCat();
    cat.state = cat.state.copyWith(
      telemetry: RadioTelemetry(meters: {RadioMeter.powerOut: MeterReading(5, nowMillis() - 60000), RadioMeter.supplyVolts: MeterReading(13.8, nowMillis())}),
    );
    final meters = PanelRadioService(cat, TestRadio()).read()['meters'] as Map;
    expect(meters.containsKey('powerOut'), false);
    expect(meters['supplyVolts'], 13.8);
  });

  // The capability reads RADIOS. Naming another device's uuid must not answer
  // with that device's status, problem text or frequency under a blank id.
  test('a selection naming equipment that is not a radio reads as no radio at all', () {
    final cat = TestCat();
    cat.state = cat.state.copyWith(problem: 'relay 3 stuck');
    final read = PanelRadioService(cat, TestRadio()).read('switch');
    expect(read['id'], isNull);
    expect(read['status'], const EquipmentState().status.name);
    expect(read['frequencyHz'], isNull);
    expect(read.values, isNot(contains('relay 3 stuck')));
  });

  test('power reaches the logging radio through the app VFO, and a pinned radio directly', () async {
    final cat = TestCat(), radio = TestRadio(), bridge = PanelRadioService(cat, radio);
    expect((await bridge.set({'id': 'a', 'powerWatts': 40}))['accepted'], true);
    // Through the VFO: the power a panel sets is the power the next QSO logs.
    expect(radio.calls.single.power, 40);
    expect(cat.powered, isEmpty);
    expect((await bridge.set({'selection': 'b', 'id': 'b', 'powerWatts': 25}))['accepted'], true);
    expect(cat.powered, {'b': 25});
    expect(radio.calls, hasLength(1));
  });

  test('a radio that states its ceiling refuses power above it, and modes come from its driver', () async {
    final cat = TestCat()..modelConfig = const {'maxWatts': 10}, radio = TestRadio(), bridge = PanelRadioService(cat, radio);
    expect(bridge.read()['maxWatts'], 10);
    // CW-R reads back as CW, so a request for it would look refused.
    expect(bridge.read()['modes'], ['LSB', 'USB', 'CW', 'AM', 'FM', 'DATA-USB']);
    expect((await bridge.set({'id': 'a', 'powerWatts': 11}))['reason'], 'invalid');
    expect((await bridge.set({'id': 'a', 'powerWatts': -1}))['reason'], 'invalid');
    expect((await bridge.set({'id': 'a', 'mode': 'CW-R'}))['reason'], 'invalid');
    expect(radio.calls, isEmpty);
    expect((await bridge.set({'id': 'a', 'mode': 'DATA-USB'}))['accepted'], true);
    expect(PanelRadioService(TestCat(), radio).read()['maxWatts'], isNull);
  });

  test('the tuner is offered only where the radio reports one', () async {
    final cat = TestCat(), bridge = PanelRadioService(cat, TestRadio());
    expect(bridge.read()['tuner'], isNull);
    // A radio that never said it has a tuner is not sent a tuner command.
    expect((await bridge.set({'id': 'a', 'tunerInline': false}))['reason'], 'unsupported');
    cat.state = cat.state.copyWith(tuner: TunerStatus.inline);
    expect(bridge.read()['tuner'], 'inline');
    expect((await bridge.set({'id': 'a', 'tunerInline': 'yes'}))['reason'], 'invalid');
    expect((await bridge.set({'id': 'a', 'tunerInline': false}))['accepted'], true);
    expect(cat.tuners, {'a': false});
  });

  test('the passband is reported and set only where the radio reads one', () async {
    final cat = TestCat(), bridge = PanelRadioService(cat, TestRadio());
    expect(bridge.read()['passband'], isNull);
    expect(
      (await bridge.set({
        'id': 'a',
        'passband': {'lowHz': 100, 'highHz': 2800},
      }))['reason'],
      'unsupported',
    );
    cat.state = cat.state.copyWith(passband: const Passband(100, 2800));
    expect(bridge.read()['passband'], {'lowHz': 100, 'highHz': 2800});
    // Edges out of order, or a filter wider than any radio's, never reach it.
    expect(
      (await bridge.set({
        'id': 'a',
        'passband': {'lowHz': 2800, 'highHz': 100},
      }))['reason'],
      'invalid',
    );
    expect(
      (await bridge.set({
        'id': 'a',
        'passband': {'lowHz': 0, 'highHz': 50000},
      }))['reason'],
      'invalid',
    );
    expect(
      (await bridge.set({
        'id': 'a',
        'passband': {'lowHz': 200, 'highHz': 2900},
      }))['accepted'],
      true,
    );
    expect(cat.passbands, {'a': const Passband(200, 2900)});
    // Drivers read edges against the mode the radio reports: one set in the same call would land
    // as the old mode's filter.
    expect(
      (await bridge.set({
        'id': 'a',
        'mode': 'LSB',
        'passband': {'lowHz': -2800, 'highHz': -100},
      }))['reason'],
      'invalid',
    );
    expect(
      (await bridge.set({
        'id': 'a',
        'mode': 'USB',
        'passband': {'lowHz': 100, 'highHz': 2700},
      }))['accepted'],
      true,
    );
  });

  test('an antenna is set only to a port the radio offers in that direction', () async {
    final cat = TestCat(), bridge = PanelRadioService(cat, TestRadio());
    expect(
      (await bridge.set({
        'id': 'a',
        'antenna': {'rx': 'ANT2'},
      }))['reason'],
      'unsupported',
    );
    cat.state = cat.state.copyWith(
      antennas: const RadioAntennas(rxPorts: ['ANT1', 'ANT2', 'RX_A'], txPorts: ['ANT1', 'ANT2'], rx: 'ANT1', tx: 'ANT1', separate: true),
    );
    expect((bridge.read()['antennas'] as Map)['rxPorts'], ['ANT1', 'ANT2', 'RX_A']);
    // A receive-only port cannot transmit.
    expect(
      (await bridge.set({
        'id': 'a',
        'antenna': {'tx': 'RX_A'},
      }))['reason'],
      'invalid',
    );
    expect(
      (await bridge.set({
        'id': 'a',
        'antenna': {'rx': 'RX_A'},
      }))['accepted'],
      true,
    );
    expect(cat.antennas, {'a': ('RX_A', null)});
    // A radio listing only the transmit port and its receive input for receive (Icom, TS-590)
    // takes both moved to a new port at once — its driver has the branch for it.
    cat.state = cat.state.copyWith(
      antennas: const RadioAntennas(rxPorts: ['ANT1', 'RX_A'], txPorts: ['ANT1', 'ANT2'], rx: 'RX_A', tx: 'ANT1', separate: true),
    );
    expect(
      (await bridge.set({
        'id': 'a',
        'antenna': {'rx': 'ANT2', 'tx': 'ANT2'},
      }))['accepted'],
      true,
    );
    // One port for both: two different ones cannot both be had, and a driver would drop one.
    cat.state = cat.state.copyWith(
      antennas: const RadioAntennas(rxPorts: ['ANT1', 'ANT2'], txPorts: ['ANT1', 'ANT2'], rx: 'ANT1', tx: 'ANT1', separate: false),
    );
    expect(
      (await bridge.set({
        'id': 'a',
        'antenna': {'rx': 'ANT1', 'tx': 'ANT2'},
      }))['reason'],
      'invalid',
    );
  });

  test('the last transmission is reported as the radio service measured it', () {
    final cat = TestCat(), bridge = PanelRadioService(cat, TestRadio());
    expect(bridge.read()['lastTransmission'], isNull);
    cat.lastTransmission = (swrAverage: 1.6, endedAtMillis: 1234);
    expect(bridge.read()['lastTransmission'], {'swrAverage': 1.6, 'endedAtMillis': 1234});
  });

  group('keying', () {
    late TestCat cat;
    var enabled = true, ptt = true;
    setUp(() {
      enabled = true;
      ptt = true;
      cat = TestCat();
    });
    PanelRadioService bridge() => PanelRadioService(cat, TestRadio(), keyingEnabled: () => enabled, pttEnabled: () => ptt);

    test('is reported for the logging radio only, and only with the app\'s keying on', () {
      final keying = bridge().read()['keying'] as Map;
      expect((keying['canKeyCw'], keying['keyerSpeedWpm']), (true, 22));
      expect(keying['keyerSpeedRange'], {'min': 5, 'max': 50});
      expect(keying['voiceMemories'], [
        {'number': 1, 'label': 'Message 1'},
        {'number': 2, 'label': 'Message 2'},
      ]);
      expect(bridge().read('b')['keying'], isNull);
      enabled = false;
      expect(bridge().read()['keying'], isNull);
    });

    test('keys the logging radio, and never one a panel is pinned to', () {
      expect(bridge().sendCw({'id': 'a', 'text': 'CQ TEST'})['accepted'], true);
      expect(bridge().playVoice({'id': 'a', 'memory': 2})['accepted'], true);
      expect(bridge().setPtt({'id': 'a', 'on': true})['accepted'], true);
      // Asking for the state it is already in toggles nothing.
      expect(bridge().setPtt({'id': 'a', 'on': true})['accepted'], true);
      // A panel cannot arm the repeat chain: nobody started it where it is stopped.
      expect(cat.keyed, ['cw:CQ TEST', 'voice:2:once', 'ptt:a:true']);
      for (final call in [
        () => bridge().sendCw({'selection': 'b', 'id': 'b', 'text': 'CQ'}),
        () => bridge().playVoice({'selection': 'b', 'id': 'b', 'memory': 1}),
        () => bridge().setPtt({'selection': 'b', 'id': 'b', 'on': true}),
      ]) {
        expect(call()['reason'], 'unsupported');
      }
      expect(cat.keyed, hasLength(3));
    });

    test('unkeying releases the key and can never key a radio, whatever the identity says', () {
      // Held on another radio, with the logging radio moved off it: a toggle would drop that
      // key and put the logging radio on the air instead.
      cat.pttOn = 'b';
      cat.pttHeld.value = true;
      expect((bridge().read()['keying'] as Map)['ptt'], false, reason: 'the key is not on the logging radio');
      expect(bridge().setPtt({'id': 'a', 'on': false})['accepted'], true);
      expect(cat.keyed, ['release']);
      expect(cat.pttOn, isNull);
      // A panel holding a stale identity, or one pinned elsewhere, still gets its key released.
      expect(bridge().setPtt({'selection': 'b', 'id': 'gone', 'on': false})['accepted'], true);
      expect(cat.keyed, ['release', 'release']);
    });

    test('PTT waits for the operator\'s own opt-in, as the app\'s PTT key does', () {
      // Off by default because it puts the transmitter on the air: a panel must not be the way
      // around that.
      ptt = false;
      expect((bridge().read()['keying'] as Map)['canPtt'], false);
      expect(bridge().setPtt({'id': 'a', 'on': true})['reason'], 'unsupported');
      expect(cat.keyed, isEmpty);
      // Releasing is never what the opt-in guards.
      expect(bridge().setPtt({'id': 'a', 'on': false})['accepted'], true);
    });

    test('a radio that does not take the key is reported, not answered as keyed', () {
      cat.pttRefused = true;
      expect(bridge().setPtt({'id': 'a', 'on': true})['reason'], 'disconnected');
    });

    test('a stop is never refused, not even for an identity that has gone stale', () {
      // A panel keys, the operator moves the logging radio, the panel's stop names the old one.
      expect(bridge().stopTransmit({'id': 'gone'})['accepted'], true);
      expect(bridge().stopTransmit({})['accepted'], true);
      expect(cat.keyed, ['stop', 'stop']);
    });

    test('a keyer that refuses the speed leaves the rest of the call unsent', () async {
      cat.speedRefused = true;
      final radio = TestRadio(), bridge = PanelRadioService(cat, radio, keyingEnabled: () => enabled, pttEnabled: () => ptt);
      expect((await bridge.set({'id': 'a', 'frequencyHz': 7030000, 'keyerSpeedWpm': 25}))['reason'], 'unsupported');
      expect(radio.calls, isEmpty, reason: 'a refused call must not have moved the radio');
    });

    test('with the app\'s keying off nothing keys — but a stop still stops', () {
      enabled = false;
      expect(bridge().sendCw({'id': 'a', 'text': 'CQ'})['reason'], 'unsupported');
      expect(bridge().setPtt({'id': 'a', 'on': true})['reason'], 'unsupported');
      expect(bridge().stopTransmit({'id': 'a'})['accepted'], true);
      expect(cat.keyed, ['stop']);
    });

    test('malformed requests and missing hardware are refused before the radio hears them', () async {
      expect(bridge().sendCw({'id': 'a', 'text': '  '})['reason'], 'invalid');
      expect(bridge().playVoice({'id': 'a', 'memory': 3})['reason'], 'invalid');
      expect(bridge().setPtt({'id': 'a', 'on': 'yes'})['reason'], 'invalid');
      cat
        ..playsVoice = false
        ..hasPtt = false
        ..keysCw = false;
      expect(bridge().playVoice({'id': 'a', 'memory': 1})['reason'], 'unsupported');
      expect(bridge().setPtt({'id': 'a', 'on': true})['reason'], 'unsupported');
      expect((await bridge().set({'id': 'a', 'keyerSpeedWpm': 25}))['reason'], 'unsupported');
      expect(cat.keyed, isEmpty);
    });

    test('keyer speed is a setting of the logging radio\'s key', () async {
      expect((await bridge().set({'id': 'a', 'keyerSpeedWpm': 24.6}))['accepted'], true);
      expect(cat.keyed, ['wpm:25']);
      expect((await bridge().set({'selection': 'b', 'id': 'b', 'keyerSpeedWpm': 25}))['reason'], 'unsupported');
    });
  });

  group('the scope', () {
    late TestCat cat;
    late TestScope scope;
    var enabled = true;
    setUp(() {
      enabled = true;
      scope = TestScope();
      cat = TestCat()
        ..session = scope
        ..state = const EquipmentState(
          status: EquipmentStatus.connected,
          vfo: VfoReading(freqKHz: 14074, mode: 'USB'),
          spectrum: SpectrumSettings(spanHz: 25000, refLevelDb: -4.5, speed: SpectrumSpeed.slow),
        );
    });
    PanelRadioService bridge() => PanelRadioService(cat, TestRadio(), spectrumEnabled: () => enabled);

    test('is reported, with what it accepts, only where the feature is on', () {
      final spectrum = bridge().read()['spectrum'] as Map;
      expect((spectrum['spanHz'], spectrum['refLevelDb'], spectrum['speed']), (25000, -4.5, 'slow'));
      expect(spectrum['spansHz'], [25000, 50000]);
      enabled = false;
      // Absent, not null: null says this radio has no scope, which is a
      // different thing to tell an extension than "this host has none".
      expect(bridge().read().containsKey('spectrum'), isFalse);
      expect(bridge().setSpectrum({'id': 'a', 'spanHz': 50000})['accepted'], isFalse);
      expect(scope.requests, isEmpty);
    });

    test('a change reaches the radio as asked; a malformed one does not', () {
      expect(bridge().setSpectrum({'id': 'a', 'spanHz': 50000, 'speed': 'fast'})['accepted'], isTrue);
      expect((scope.requests.single.spanHz, scope.requests.single.speed), (50000, SpectrumSpeed.fast));
      expect(bridge().setSpectrum({'id': 'a', 'speed': 'warp'})['reason'], 'invalid');
      // A mode the radio has no such thing as would be dropped by its driver
      // and answered as accepted.
      expect(bridge().setSpectrum({'id': 'a', 'mode': 'fixed'})['reason'], 'invalid');
      expect(bridge().setSpectrum({'id': 'a', 'speed': 'mid'})['reason'], 'invalid');
      expect(bridge().setSpectrum({'id': 'a'})['reason'], 'invalid');
      expect(bridge().setSpectrum({'id': 'b', 'spanHz': 50000})['reason'], 'changed');
      expect(scope.requests, hasLength(1));
    });

    test('a scope no display is running says so, rather than accepting a change it never sent', () {
      scope.running = false;
      final answer = bridge().setSpectrum({'id': 'a', 'spanHz': 50000});
      expect((answer['accepted'], answer['reason']), (false, 'stopped'));
    });

    test('a scope that cannot run refuses a change rather than queueing it', () {
      scope.unavailable = 'Requires CAT at 115200 bps';
      expect(bridge().setSpectrum({'id': 'a', 'spanHz': 50000})['reason'], 'disconnected');
      expect(scope.requests, isEmpty);
    });
  });
}
