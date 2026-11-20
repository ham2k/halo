// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One keyer for both SO2R radios, through an OTRSP box
// (docs/design/station-model.md § 6.1, docs/design/cat.md § The SO2R
// switcher): the box sends the keyer's output to the radio whose transmit
// focus it has, so a message keyed in either set is that set's, on that
// set's radio.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart' show PeerKeyOp, PeerKeyRequestPayload;
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart' show CwSendProgress;
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
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

/// A radio whose CAT keys no CW: what keys it is the keyer, through the box.
class _Radio extends _Session implements TransceiverSession, PttSession {
  _Radio(super.sink);
  @override
  void setPtt(bool on) {}
  @override
  void setFrequency(double freqKHz) {}
  @override
  void setMode(String mode) {}
  @override
  void setPower(num watts) {}
}

/// A WinKeyer: a message is on the air from its send until [finish].
class _Keyer extends _Session implements CwKeyerSession {
  _Keyer(super.sink);
  final sent = <String>[];
  var _ids = 0;
  @override
  bool cwSending = false;
  @override
  void sendCw(String text) {
    sent.add(text);
    cwSending = true;
    sink.reportCwProgress(CwSendProgress(id: ++_ids, text: text, characterEnds: const []));
  }

  @override
  void stopCw() {
    if (cwSending) finish();
  }

  void finish() {
    cwSending = false;
    sink.reportCwProgress(null);
  }

  @override
  void dropQueuedCw(int id) {}
  @override
  void setKeyerSpeed(int wpm) {}
  @override
  ({int min, int max}) get keyerSpeedRange => (min: 5, max: 60);
  @override
  void refreshKeyerSpeed() {}
}

class _Box extends _Session implements So2rSwitchSession {
  _Box(super.sink);
  final transmit = <String>[];
  @override
  void setSo2rAudio(So2rAudio audio) {}
  @override
  void setSo2rTransmit(String radio) => transmit.add(radio);
}

class _Driver extends EquipmentDriver {
  _Driver(this.key, this.make);
  @override
  final String key;
  final EquipmentSession Function(EquipmentSink sink) make;
  @override
  String get name => key;
  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => make(sink);
}

void main() {
  late SettingsService settings;
  late CatService cat;
  late List<_Keyer> keyers;
  late List<_Box> boxes;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService(await SharedPreferences.getInstance());
    await settings.setExperimentEnabled('so2r', true);
    final radio = RadioService(await SharedPreferences.getInstance(), writeDelay: Duration.zero);
    addTearDown(radio.dispose);
    keyers = [];
    boxes = [];
    final transport = _Transport();
    EquipmentModel model(String key, String category, EquipmentSession Function(EquipmentSink) make) => EquipmentModel(
      key: key,
      category: category,
      name: () => key,
      variants: [EquipmentVariant(key: '$key-type', driver: _Driver(key, make), transport: transport)],
    );
    cat = CatService(
      settings,
      radio: radio,
      registry: EquipmentRegistry(
        models: [
          model('radio', kCategoryTransceiver, _Radio.new),
          model('keyer', kCategoryKeyer, (sink) => _Keyer(sink)..let(keyers.add)),
          model('box', kCategorySo2rSwitch, (sink) => _Box(sink)..let(boxes.add)),
        ],
        transports: {'fake': transport},
      ),
    );
    addTearDown(cat.dispose);
  });

  /// Two radios, one keyer as radio A's key in use, and an OTRSP box when
  /// [box]; every node connected.
  Future<({EquipmentNode a, EquipmentNode b, EquipmentNode keyer})> station({bool box = true}) async {
    final a = await cat.addNode(typeKey: 'radio-type');
    final b = await cat.addNode(typeKey: 'radio-type');
    await cat.setRadio1(LocalRadio(a.uuid));
    await cat.setRadio2(b.uuid);
    final keyer = await cat.addNode(typeKey: 'keyer-type');
    await cat.setDesignated(kCategoryKey, keyer.uuid);
    for (final node in [a, b, keyer]) {
      await cat.connect(node.uuid);
    }
    if (box) {
      final node = await cat.addNode(typeKey: 'box-type');
      await cat.setSo2rSwitch(node.uuid);
      await cat.connect(node.uuid);
    }
    await pumpEventQueue();
    return (a: a, b: b, keyer: keyer);
  }

  test('set B may take radio A\'s keyer while a box switches, and only then', () async {
    final s = await station(box: false);
    await cat.setDesignated(kCategoryKey, s.keyer.uuid, radio: s.b.uuid);
    expect(cat.designatedFor(kCategoryKey, radio: s.b.uuid), isNull, reason: 'with nothing to route it, one key keys one radio');
    final node = await cat.addNode(typeKey: 'box-type');
    await cat.setSo2rSwitch(node.uuid);
    await cat.setDesignated(kCategoryKey, s.keyer.uuid, radio: s.b.uuid);
    expect(cat.designatedFor(kCategoryKey, radio: s.b.uuid), s.keyer.uuid);
    expect(cat.designatedFor(kCategoryKey), s.keyer.uuid, reason: 'set A keeps it too');
    await cat.setSo2rSwitch(null);
    expect(cat.designatedFor(kCategoryKey, radio: s.b.uuid), isNull, reason: 'the box gone, B is back to None');
  });

  test('a message in set B goes out on radio B, and is radio B\'s alone', () async {
    final s = await station();
    await cat.setDesignated(kCategoryKey, s.keyer.uuid, radio: s.b.uuid);
    cat.keyer('B').sendCw('TU');
    expect(keyers.single.sent, ['TU']);
    expect(boxes.single.transmit, ['B']);
    expect(cat.isTransmitting('B'), isTrue);
    expect(cat.isTransmitting('A'), isFalse, reason: 'one keyer keying is one radio on the air');
    expect(cat.keyer('A').cwProgress.value, isNull, reason: "B's message is not on A's keyer line");
  });

  test("B keyed over A's CQ stops it, goes out on B, and A's CQ comes back on A after", () async {
    // The other radio's CQ resuming is the box's focus moving back: on a
    // focus left on B, A's CQ would go out on B's frequency.
    final s = await station();
    await cat.setDesignated(kCategoryKey, s.keyer.uuid, radio: s.b.uuid);
    final keyer = keyers.single, box = boxes.single;
    final a = cat.keyer('A');
    a.sendCw('CQ');
    a.armKeyerRepeat(delay: const Duration(seconds: 10), text: 'CQ', send: () => a.sendCw('CQ', repeat: true));
    expect(box.transmit, ['A']);
    cat.keyer('B').sendCw('TU');
    await pumpEventQueue();
    expect(keyer.sent, ['CQ', 'TU']);
    expect(box.transmit, ['A', 'B']);
    expect(cat.isTransmitting('A'), isFalse);
    expect(cat.keyer('B').cwProgress.value?.text, 'TU');
    keyer.finish();
    await pumpEventQueue();
    expect(keyer.sent, ['CQ', 'TU', 'CQ'], reason: "A's CQ resumes once B is quiet");
    expect(box.transmit, ['A', 'B', 'A']);
    expect(cat.keyer('A').cwProgress.value?.text, 'CQ');
    expect(cat.keyer('B').cwProgress.value, isNull);
  });

  test("with messages queued, B's waits for A's to end rather than joining the keyer's buffer", () async {
    // Appended, B's text would key behind A's on A's radio, or move the
    // box's focus under the end of A's.
    final s = await station();
    await cat.setDesignated(kCategoryKey, s.keyer.uuid, radio: s.b.uuid);
    await settings.setSo2rQueueMessages(true);
    final keyer = keyers.single;
    cat.keyer('A').sendCw('CQ');
    cat.keyer('B').sendCw('TU');
    expect(keyer.sent, ['CQ']);
    expect(boxes.single.transmit, ['A']);
    keyer.finish();
    await pumpEventQueue();
    expect(keyer.sent, ['CQ', 'TU']);
    expect(boxes.single.transmit, ['A', 'B']);
  });

  test("stopping one set's keying leaves nothing of the other's to stop", () async {
    // Read as its own, B's stop would stop A's message on the one keyer.
    final s = await station();
    await cat.setDesignated(kCategoryKey, s.keyer.uuid, radio: s.b.uuid);
    cat.keyer('A').sendCw('CQ');
    cat.keyer('B').stopCw();
    expect(keyers.single.cwSending, isTrue);
    expect(cat.isTransmitting('A'), isTrue);
  });

  test("a set's claim on the shared keyer ends with its message", () async {
    // Kept past its end, the claim would make the next message keyed from
    // the keyer's own buttons set A's, on whichever radio the box has.
    final s = await station();
    await cat.setDesignated(kCategoryKey, s.keyer.uuid, radio: s.b.uuid);
    final keyer = keyers.single;
    cat.keyer('A').sendCw('CQ');
    keyer.finish();
    keyer.sink.reportCwProgress(CwSendProgress(id: 99, text: 'TEST', characterEnds: const []));
    expect(cat.keyer('A').cwProgress.value, isNull);
  });

  test("set B's key moving off the shared keyer leaves A's message going", () async {
    // Stopped as the outgoing key's message, A's CQ would end for a change
    // made in set B.
    final s = await station();
    await cat.setDesignated(kCategoryKey, s.keyer.uuid, radio: s.b.uuid);
    cat.keyer('A').sendCw('CQ');
    await cat.setDesignated(kCategoryKey, null, radio: s.b.uuid);
    expect(keyers.single.cwSending, isTrue);
    expect(cat.isTransmitting('A'), isTrue);
  });

  test('a message keyed before the other set shares the keyer stays its own', () async {
    // Claimed only when sent on a shared key, it would be neither set's once
    // shared: A's line frozen, and B's next message moving the box's focus
    // under it.
    final s = await station();
    cat.keyer('A').sendCw('CQ');
    await cat.setDesignated(kCategoryKey, s.keyer.uuid, radio: s.b.uuid);
    expect(cat.isTransmitting('A'), isTrue);
    expect(cat.keyer('B').cwProgress.value, isNull);
    keyers.single.finish();
    expect(cat.keyer('A').cwProgress.value, isNull, reason: "the end of A's message reaches A's line");
  });

  test("removing the box ends set B's share of A's keyer, for good", () async {
    // Left stored, B's pick would come back as B's key once A picks another,
    // keying through a keyer wired to radio A.
    final s = await station();
    await cat.setDesignated(kCategoryKey, s.keyer.uuid, radio: s.b.uuid);
    await cat.setSo2rSwitch(null);
    final other = await cat.addNode(typeKey: 'keyer-type');
    await cat.setDesignated(kCategoryKey, other.uuid);
    expect(cat.designatedFor(kCategoryKey, radio: s.b.uuid), isNull);
  });

  test("deleting the box ends set B's share of A's keyer too", () async {
    final s = await station();
    await cat.setDesignated(kCategoryKey, s.keyer.uuid, radio: s.b.uuid);
    await cat.removeNode(cat.so2rSwitch!);
    final other = await cat.addNode(typeKey: 'keyer-type');
    await cat.setDesignated(kCategoryKey, other.uuid);
    expect(cat.designatedFor(kCategoryKey, radio: s.b.uuid), isNull);
  });

  test("once B's key moves off the shared keyer, what it keys is A's again", () async {
    // B's claim outliving its stopped message would leave the keyer's next
    // message, keyed from its own buttons, on no set's line.
    final s = await station();
    await cat.setDesignated(kCategoryKey, s.keyer.uuid, radio: s.b.uuid);
    cat.keyer('B').sendCw('TU');
    await cat.setDesignated(kCategoryKey, null, radio: s.b.uuid);
    keyers.single.sink.reportCwProgress(CwSendProgress(id: 99, text: 'TEST', characterEnds: const []));
    expect(cat.keyer('A').cwProgress.value?.text, 'TEST');
  });

  test("a far station's stop for radio A leaves B's message on the shared keyer", () async {
    // It reaches radio A's keyer without the operator's stop, and read as
    // A's, it would stop B's message.
    final s = await station();
    await cat.setDesignated(kCategoryKey, s.keyer.uuid, radio: s.b.uuid);
    cat.operationOnScreen = () => true;
    cat.keyer('B').sendCw('TU');
    cat.handleKeyRequest(PeerKeyRequestPayload(radioId: s.a.uuid, op: PeerKeyOp.stopCw));
    expect(keyers.single.cwSending, isTrue);
  });

  test("a far station's message keys nothing through the shared keyer while the box is down", () async {
    // It arrives at the send itself, past the check that greys out the
    // operator's keys.
    final s = await station();
    await cat.setDesignated(kCategoryKey, s.keyer.uuid, radio: s.b.uuid);
    cat.operationOnScreen = () => true;
    await cat.disconnect(cat.so2rSwitch!);
    await pumpEventQueue();
    cat.handleKeyRequest(PeerKeyRequestPayload(radioId: s.a.uuid, op: PeerKeyOp.cw, text: 'CQ'));
    expect(keyers.single.sent, isEmpty);
  });

  test("a key that takes no turn stops B's message on the box's keyer after radio A moved off it", () async {
    // No longer shared, the keyer still goes through the box: moving the
    // focus to A would key the rest of B's message on radio A.
    final s = await station();
    await cat.setDesignated(kCategoryKey, s.keyer.uuid, radio: s.b.uuid);
    cat.keyer('B').sendCw('TU');
    final other = await cat.addNode(typeKey: 'keyer-type');
    await cat.setDesignated(kCategoryKey, other.uuid);
    expect(keyers.first.cwSending, isTrue, reason: "A's key moving leaves B's message going");
    final client = Object();
    expect(cat.keyRadio1Ptt(client, timeout: const Duration(seconds: 5)), isTrue);
    expect(keyers.first.cwSending, isFalse);
    cat.releasePtt(client);
  });

  test("a set's claim on the shared keyer goes with the keyer's link", () async {
    // Its message ended unreported: kept, the claim would make what the
    // keyer keys from its own buttons after reconnecting set A's.
    final s = await station();
    await cat.setDesignated(kCategoryKey, s.keyer.uuid, radio: s.b.uuid);
    cat.keyer('A').sendCw('CQ');
    await cat.disconnect(s.keyer.uuid);
    await cat.connect(s.keyer.uuid);
    await pumpEventQueue();
    keyers.last.sink.reportCwProgress(CwSendProgress(id: 99, text: 'TEST', characterEnds: const []));
    expect(cat.keyer('A').cwProgress.value, isNull);
  });

  test("B's key moving off the shared keyer leaves what A still keys through it, sent from nowhere here", () async {
    // One rule for whose message it is: B's change of key asks it as the
    // progress and the stops do, and finds it not B's.
    final s = await station();
    await cat.setDesignated(kCategoryKey, s.keyer.uuid, radio: s.b.uuid);
    final keyer = keyers.single..cwSending = true;
    keyer.sink.reportCwProgress(CwSendProgress(id: 99, text: 'TEST', characterEnds: const []));
    await cat.setDesignated(kCategoryKey, null, radio: s.b.uuid);
    expect(keyer.cwSending, isTrue);
  });

  test("removing the box while B keys stops B's message, which A does not take up", () async {
    // Left going, it keys wherever the box last sent it, shown as A's.
    final s = await station();
    await cat.setDesignated(kCategoryKey, s.keyer.uuid, radio: s.b.uuid);
    cat.keyer('B').sendCw('TU');
    await cat.setSo2rSwitch(null);
    expect(keyers.single.cwSending, isFalse);
    expect(cat.keyer('A').cwProgress.value, isNull);
  });

  test('the shared keyer keys for neither set while the box is down', () async {
    // Its output would go wherever the box's focus last was.
    final s = await station();
    await cat.setDesignated(kCategoryKey, s.keyer.uuid, radio: s.b.uuid);
    await cat.disconnect(cat.so2rSwitch!);
    await pumpEventQueue();
    expect(cat.keyer('B').sendCw('TU'), isFalse);
    expect(cat.keyer('A').canKeyCw, isFalse);
    expect(keyers.single.sent, isEmpty);
  });

  test("a key that takes no turn stops B's message before the box moves to radio A", () async {
    // A CAT client keying radio A waits for no turn: left going, the rest of
    // B's message would key radio A.
    final s = await station();
    await cat.setDesignated(kCategoryKey, s.keyer.uuid, radio: s.b.uuid);
    cat.keyer('B').sendCw('TU');
    final client = Object();
    expect(cat.keyRadio1Ptt(client, timeout: const Duration(seconds: 5)), isTrue);
    expect(keyers.single.cwSending, isFalse);
    expect(boxes.single.transmit, ['B', 'A']);
    cat.releasePtt(client);
  });
}

extension<T> on T {
  void let(void Function(T) f) => f(this);
}
