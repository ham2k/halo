// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A radio whose session says a key would go out somewhere else
// (TransmitGatedSession — a Flex slice not open on the radio, whose `xmit`
// keys another slice on its frequency): keying treats it as a radio that
// cannot key, and the keypress says why. The trap is a gate the session
// alone enforces: the key is refused, and the app shows the message going
// out, the PTT held, with nothing on the air — and the reverse, a gate in
// the keyer lookups, which a stop goes through too: a message sent while
// the slice was open goes on after it closes, with nothing to stop it.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/halo_services.dart';
import 'package:ham2k_logger/services/voice_message_set.dart';
import 'package:ham2k_logger/views/keyer_area.dart';

import '../support/halo_test_support.dart';

class _FakeConnection implements EquipmentConnection {
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

class _FakeTransport extends EquipmentTransport {
  @override
  String get key => 'fake';
  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async => _FakeConnection();
}

class _GatedSession implements TransceiverSession, PttSession, CwKeyerSession, VoiceKeyerSession, TransmitGatedSession {
  _GatedSession(this.sink);

  final EquipmentSink sink;
  final commands = <String>[];

  @override
  String? cannotTransmit;

  @override
  Duration? expectedUpdateInterval;
  @override
  void handleData(Uint8List chunk) {}
  @override
  void startUpdates() {}
  @override
  void stopUpdates() {}
  @override
  void setFrequency(double freqKHz) {}
  @override
  void setMode(String mode) {}
  @override
  void setPower(num watts) {}
  @override
  void setPtt(bool on) => commands.add('ptt:$on');
  @override
  void sendCw(String text) {
    commands.add('cw:$text');
    sink.reportCwProgress(CwSendProgress(id: 1, text: text, characterEnds: const []));
  }

  @override
  void stopCw() {
    commands.add('stop');
    sink.reportCwProgress(null);
  }

  @override
  bool get cwSending => false;
  @override
  void dropQueuedCw(int id) {}
  @override
  void setKeyerSpeed(int wpm) {}
  @override
  void refreshKeyerSpeed() {}
  @override
  ({int min, int max}) get keyerSpeedRange => (min: 5, max: 60);
  @override
  int get voiceMemoryCount => 4;
  @override
  bool get canRecordVoice => true;
  @override
  Duration get voiceMemoryCeiling => const Duration(seconds: 30);
  @override
  void playVoiceMemory(int n) => commands.add('play:$n');
  @override
  void recordVoiceMemory(int n) => commands.add('record:$n');
  @override
  void stopVoice() => commands.add('stopVoice');
  @override
  void teardown() {}
}

class _GatedDriver extends EquipmentDriver {
  final sessions = <_GatedSession>[];

  @override
  String get key => 'gated-driver';
  @override
  String get name => 'Gated Radio';
  @override
  bool get canKeyCw => true;

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) {
    final session = _GatedSession(sink);
    sessions.add(session);
    return session;
  }
}

void main() {
  late HaLoServices services;
  late _GatedDriver driver;

  setUp(() async {
    driver = _GatedDriver();
    final transport = _FakeTransport();
    services = (await makeHaLoServices(
      cat: (settings) => CatService(
        settings,
        registry: EquipmentRegistry(
          models: [
            EquipmentModel(
              key: 'gated',
              category: kCategoryTransceiver,
              name: () => 'Gated Radio',
              variants: [EquipmentVariant(key: 'gated-type', driver: driver, transport: transport)],
            ),
          ],
          transports: {'fake': transport},
        ),
      ),
    )).services;
  });

  testWidgets('a radio that would key somewhere else keys nothing, and the keypress says why', (tester) async {
    final cat = services.cat;
    final node = await cat.addNode(typeKey: 'gated-type', config: const {});
    await tester.runAsync(() => cat.connect(node.uuid));
    await cat.setRadio1(LocalRadio(node.uuid));
    await cat.setDesignated(kCategoryKey, node.uuid);
    final session = driver.sessions.single;
    await services.settings.setVoiceKeyingSource(VoiceKeyingSource.radio);
    final keyer = cat.keyer('A');
    expect(keyer.canKeyCw, isTrue);
    expect(keyer.canPtt, isTrue);
    expect(keyer.canPlayVoice, isTrue);

    keyer.sendCw('TEST');
    expect(session.commands, ['cw:TEST']);
    expect(keyer.cwProgress.value, isNotNull);
    session.cannotTransmit = 'Slice B is not in use on this radio';
    keyer.stopCw();
    expect(session.commands, ['cw:TEST', 'stop'], reason: 'sent while the slice was open, it is stopped after');
    expect(keyer.cwProgress.value, isNull, reason: 'and shown ended');
    keyer.stopVoice();
    keyer.recordVoiceMemory(2);
    expect(session.commands, ['cw:TEST', 'stop', 'stopVoice', 'record:2'], reason: 'a voice stop and a recording, which keys nothing, reach it too');
    session.commands.clear();

    expect(keyer.cannotTransmit, 'Slice B is not in use on this radio');
    expect(keyer.canKeyCw, isFalse);
    expect(keyer.canPtt, isFalse);
    expect(keyer.canPlayVoice, isFalse);
    keyer.sendCw('CQ');
    keyer.playVoiceMemory(1, repeat: false);
    cat.togglePtt(node.uuid);
    expect(session.commands, isEmpty);
    expect(cat.pttKeys.held.value, isFalse, reason: 'a key refused is not a key held');
    // A peer's request reaches the radio by its own way, past the keypress.
    await services.settings.setExperimentEnabled('keyer', true);
    expect(cat.offeredRadios.single.keysCw, isFalse, reason: 'nor offered to a peer as a keyer');
    expect(cat.offeredRadios.single.voiceMemories, 0);
    expect(cat.keyStatusForOfferedRadio(node.uuid)?.voiceLabels, isEmpty, reason: 'nor labels for buttons it does not offer');
    cat.handleKeyRequest(PeerKeyRequestPayload(radioId: node.uuid, op: PeerKeyOp.cw, text: 'CQ'));
    cat.handleKeyRequest(PeerKeyRequestPayload(radioId: node.uuid, op: PeerKeyOp.voice, memory: 1));
    expect(session.commands, isEmpty, reason: "nor keyed for a peer's request");

    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(keyerOrSay(context, services, keyer, () => keyer.canKeyCw), isFalse);
    expect(services.statusBar.activeNotices.map((n) => n.text), contains('Slice B is not in use on this radio'));

    session.cannotTransmit = null;
    expect(keyer.canKeyCw, isTrue, reason: 'the radio able again keys again');
    await tester.runAsync(() => cat.disconnect(node.uuid));
  });
}
