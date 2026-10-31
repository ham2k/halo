// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// SO2R's switcher, as the service drives it — docs/design/cat.md § The SO2R
// switcher: what it is told as the operator moves between sets, as a radio
// transmits and as stereo goes on and off; which radios can be their own
// switcher; and what survives a relaunch and the experiment going off.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/so2r_audio.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Connection implements EquipmentConnection {
  final _data = StreamController<Uint8List>();
  final _closed = Completer<void>();
  @override
  Stream<Uint8List> get data => _data.stream;
  @override
  Future<void> get closed => _closed.future;
  @override
  void send(List<int> bytes) {}
  @override
  Future<void> close() async {
    if (!_closed.isCompleted) _closed.complete();
    unawaited(_data.close());
  }
}

class _Transport extends EquipmentTransport {
  @override
  String get key => 'fake';
  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async => _Connection();
}

abstract class _Session implements EquipmentSession {
  _Session(this.sink);
  final EquipmentSink sink;
  @override
  void handleData(Uint8List chunk) {}
  @override
  void startUpdates() {}
  @override
  void stopUpdates() {}
  @override
  void teardown() {}
  @override
  Duration? get expectedUpdateInterval => null;
}

/// A slice of a radio that switches its own audio.
class _Slice extends _Session implements TransceiverSession, So2rRadioAudioSession {
  _Slice(super.sink);
  final ears = <So2rEar?>[];
  @override
  void setSo2rEar(So2rEar? ear) => ears.add(ear);
  @override
  void setFrequency(double freqKHz) {}
  @override
  void setMode(String mode) {}
  @override
  void setPower(num watts) {}
}

class _Box extends _Session implements So2rSwitchSession {
  _Box(super.sink);
  final told = <So2rAudio>[];
  @override
  void setSo2rAudio(So2rAudio audio) => told.add(audio);
}

class _SliceDriver extends EquipmentDriver {
  _SliceDriver(this.made);
  final List<_Slice> made;
  @override
  String get key => 'slice';
  @override
  String get name => 'Slice';
  @override
  ({String radio, int receiver})? so2rAudioReceiverWith(Map<String, dynamic> config) =>
      (radio: config['host'] as String, receiver: int.parse(config['slice'] as String));
  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) {
    final session = _Slice(sink);
    made.add(session);
    return session;
  }
}

class _BoxDriver extends EquipmentDriver {
  _BoxDriver(this.made);
  final List<_Box> made;
  @override
  String get key => 'box';
  @override
  String get name => 'Box';
  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) {
    final session = _Box(sink);
    made.add(session);
    return session;
  }
}

void main() {
  late SettingsService settings;
  late CatService cat;
  late List<_Slice> slices;
  late List<_Box> boxes;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService(await SharedPreferences.getInstance());
    await settings.setExperimentEnabled('so2r', true);
    final radio = RadioService(await SharedPreferences.getInstance(), writeDelay: Duration.zero);
    addTearDown(radio.dispose);
    slices = [];
    boxes = [];
    final transport = _Transport();
    cat = CatService(
      settings,
      radio: radio,
      registry: EquipmentRegistry(
        models: [
          EquipmentModel(
            key: 'slice',
            category: kCategoryTransceiver,
            name: () => 'Slice',
            variants: [EquipmentVariant(key: 'slice-type', driver: _SliceDriver(slices), transport: transport)],
          ),
          EquipmentModel(
            key: 'box',
            category: kCategorySo2rSwitch,
            name: () => 'Box',
            variants: [EquipmentVariant(key: 'box-type', driver: _BoxDriver(boxes), transport: transport)],
          ),
        ],
        transports: {'fake': transport},
      ),
    );
    addTearDown(cat.dispose);
  });

  /// Radio A and Radio B, connected — slices of one radio unless [hostB]
  /// puts B on another.
  Future<(EquipmentNode, EquipmentNode)> twoRadios({String hostB = 'flex.local', String sliceB = '1'}) async {
    final a = await cat.addNode(typeKey: 'slice-type', config: {'host': 'flex.local', 'slice': '0'});
    final b = await cat.addNode(typeKey: 'slice-type', config: {'host': hostB, 'slice': sliceB});
    await cat.setRadio1(LocalRadio(a.uuid));
    await cat.setRadio2(b.uuid);
    await cat.connect(a.uuid);
    await cat.connect(b.uuid);
    return (a, b);
  }

  Future<_Box> aBox() async {
    final node = await cat.addNode(typeKey: 'box-type');
    await cat.setSo2rSwitch(node.uuid);
    await cat.connect(node.uuid);
    await pumpEventQueue();
    return boxes.last;
  }

  group('an OTRSP box', () {
    test('follows the set the operator is in, telling the box only what changes', () async {
      await twoRadios();
      final box = await aBox();
      expect(box.told, [So2rAudio.a]);
      cat.noteOperatorRadio('B');
      await pumpEventQueue();
      cat.noteOperatorRadio('B');
      await pumpEventQueue();
      expect(box.told, [So2rAudio.a, So2rAudio.b]);
      expect(cat.so2rAudio.value, So2rAudio.b);
    });

    test('hands the headphones to the other radio while one transmits, and back after', () async {
      final (a, _) = await twoRadios();
      final box = await aBox();
      final sink = slices.firstWhere((s) => identical(s, cat.connectedSession(a.uuid))).sink;
      sink.reportTransmitting(true);
      await pumpEventQueue();
      expect(box.told.last, So2rAudio.b, reason: 'sending on A is listening on B');
      sink.reportTransmitting(false);
      await pumpEventQueue();
      expect(box.told.last, So2rAudio.a);
    });

    test('stereo is the shortcut\'s, and only while a switcher switches', () async {
      await twoRadios();
      expect(cat.toggleSo2rStereo(), isFalse, reason: 'with no switcher the key stays free');
      final box = await aBox();
      expect(cat.toggleSo2rStereo(), isTrue);
      await pumpEventQueue();
      expect(box.told.last, So2rAudio.stereoA);
      expect(settings.so2rStereo, isTrue, reason: 'stereo is kept, across a relaunch');
    });

    test('what the box says wins over what it was told: a front-panel switch shows on the pills', () async {
      await twoRadios();
      final box = await aBox();
      (box.sink as So2rSwitchSink).reportSo2rAudio(So2rAudio.stereoB);
      await pumpEventQueue();
      expect(cat.so2rAudio.value, So2rAudio.stereoB);
      expect(box.told, [So2rAudio.a], reason: 'the operator set it by hand; it is not set back until what they should hear changes');
    });

    test('only the picked box is heard from: another connected by hand says nothing about the headphones', () async {
      await twoRadios();
      final picked = await aBox();
      final other = await cat.addNode(typeKey: 'box-type');
      await cat.connect(other.uuid);
      await pumpEventQueue();
      (picked.sink as So2rSwitchSink).reportSo2rAudio(So2rAudio.stereoB);
      expect(boxes.last, isNot(same(picked)));
      (boxes.last.sink as So2rSwitchSink).reportSo2rAudio(So2rAudio.b);
      await pumpEventQueue();
      expect(cat.so2rAudio.value, So2rAudio.stereoB, reason: "the picked box's own word stands");
    });

    test('is brought up when SO2R is turned on, as Radio B is', () async {
      await twoRadios();
      final node = await cat.addNode(typeKey: 'box-type');
      await settings.setExperimentEnabled('so2r', false);
      await pumpEventQueue();
      await cat.setSo2rSwitch(node.uuid);
      await pumpEventQueue();
      expect(boxes, isEmpty, reason: 'with SO2R off there is no Radio B to switch to');
      await settings.setExperimentEnabled('so2r', true);
      await pumpEventQueue();
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected);
      expect(boxes.single.told, [So2rAudio.a]);
    });

    test("the box's word is dropped once it is told otherwise, until it answers", () async {
      await twoRadios();
      final box = await aBox();
      (box.sink as So2rSwitchSink).reportSo2rAudio(So2rAudio.a);
      await pumpEventQueue();
      cat.noteOperatorRadio('B');
      await pumpEventQueue();
      // A box that does not echo what it is told would leave A's headphones
      // on the pills while B is in the operator's ears.
      expect(cat.so2rAudio.value, So2rAudio.b);
    });

    test("the box's word from before it was picked again is not taken for its word now", () async {
      await twoRadios();
      final box = await aBox();
      final uuid = cat.so2rSwitch!;
      (box.sink as So2rSwitchSink).reportSo2rAudio(So2rAudio.stereoA);
      await pumpEventQueue();
      await cat.setSo2rSwitch(null);
      await pumpEventQueue();
      await cat.setSo2rSwitch(uuid);
      await pumpEventQueue();
      expect(cat.so2rAudio.value, So2rAudio.a);
      expect(box.told.last, So2rAudio.a, reason: 'picked again, it is told again');
    });

    test('a reconnected box is told again', () async {
      await twoRadios();
      final first = await aBox();
      final uuid = cat.so2rSwitch!;
      await cat.disconnect(uuid);
      await pumpEventQueue();
      expect(cat.so2rAudio.value, isNull, reason: 'no switcher connected, no headphones');
      await cat.connect(uuid);
      await pumpEventQueue();
      expect(boxes.last, isNot(same(first)));
      expect(boxes.last.told, [So2rAudio.a]);
    });

    test('the pick is kept with the station, and gone with its node', () async {
      await twoRadios();
      await aBox();
      final uuid = cat.so2rSwitch!;
      expect(settings.stationEquipment['so2rSwitch'], uuid);
      await cat.removeNode(uuid);
      expect(cat.so2rSwitch, isNull);
    });
  });

  group('two slices of one radio', () {
    test('are offered as their own switcher, and two radios are not', () async {
      final (a, _) = await twoRadios();
      expect(cat.so2rAudioRadio?.uuid, a.uuid);
      await cat.setRadio2(null);
      final other = await cat.addNode(typeKey: 'slice-type', config: {'host': 'other.local', 'slice': '1'});
      await cat.setRadio2(other.uuid);
      expect(cat.so2rAudioRadio, isNull, reason: 'a slice cannot switch another radio\'s audio');
    });

    test('are not offered when both are one slice, which would be switched against itself', () async {
      await twoRadios(sliceB: '0');
      expect(cat.so2rAudioRadio, isNull);
    });

    test('switch neither while one slice is down: one muted alone is nothing in the headphones', () async {
      final (a, b) = await twoRadios();
      await cat.setSo2rSwitch(so2rSwitchRadios);
      await pumpEventQueue();
      final sliceA = cat.connectedSession(a.uuid)! as _Slice;
      cat.noteOperatorRadio('B');
      await cat.disconnect(b.uuid);
      await pumpEventQueue();
      expect(sliceA.ears.last, isNull, reason: 'radio A given back its own audio, not muted for a radio B that is not there');
      expect(cat.so2rAudio.value, isNull);
    });

    test('mute the radio out of focus, pan each to its ear in stereo, and give the audio back when switching stops', () async {
      final (a, b) = await twoRadios();
      _Slice of(EquipmentNode node) => cat.connectedSession(node.uuid)! as _Slice;
      await cat.setSo2rSwitch(so2rSwitchRadios);
      await pumpEventQueue();
      expect([of(a).ears.last, of(b).ears.last], [So2rEar.both, So2rEar.muted]);
      await settings.setSo2rStereo(true);
      await pumpEventQueue();
      expect([of(a).ears.last, of(b).ears.last], [So2rEar.left, So2rEar.right]);
      await cat.setSo2rSwitch(null);
      await pumpEventQueue();
      expect([of(a).ears.last, of(b).ears.last], [null, null], reason: 'each slice back to what the operator had it at');
      expect(cat.so2rAudio.value, isNull);
    });

    test('SO2R turned off gives the audio back too', () async {
      final (a, b) = await twoRadios();
      await cat.setSo2rSwitch(so2rSwitchRadios);
      await pumpEventQueue();
      await settings.setExperimentEnabled('so2r', false);
      await pumpEventQueue();
      expect((cat.connectedSession(a.uuid)! as _Slice).ears.last, isNull);
      expect((cat.connectedSession(b.uuid)! as _Slice).ears.last, isNull);
    });
  });
}
