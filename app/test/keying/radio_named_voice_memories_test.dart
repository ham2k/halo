// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A radio that names and times its own voice memories — a FlexRadio's DVK —
// through `CatService`, which is all the keying surfaces read. What is
// defended: while that radio is radio1 its names and lengths are THE names
// and lengths, over whatever the settings hold for radios that keep neither;
// a label typed here goes to the radio and not into the settings; a peer
// keying this radio hears the radio's names; and nothing is measured into a
// setting no surface would read.
//
// The real FlexRadio driver, over a connection the test writes the radio's
// half of — so the lines are the protocol's, not a fake session's idea of it.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/drivers/flexradio_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_voice_audio.dart';

class _RadioLink implements EquipmentConnection {
  final _data = StreamController<Uint8List>();
  final _closed = Completer<void>();
  final sent = <String>[];

  @override
  Stream<Uint8List> get data => _data.stream;
  @override
  Future<void> get closed => _closed.future;
  @override
  void send(List<int> bytes) => sent.add(utf8.decode(bytes).trim());
  @override
  Future<void> close() async {
    if (!_closed.isCompleted) _closed.complete();
    unawaited(_data.close());
  }

  void radioSays(List<String> lines) => _data.add(Uint8List.fromList(utf8.encode('${lines.join('\n')}\n')));

  /// What went out, without the `C<seq>|` each command carries.
  List<String> get commands => [for (final line in sent) line.substring(line.indexOf('|') + 1)];
}

class _LinkTransport extends EquipmentTransport {
  final link = _RadioLink();

  @override
  String get key => 'link';
  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async => link;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService settings;
  late CatService cat;
  late _LinkTransport transport;
  late String flex;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService(await SharedPreferences.getInstance());
    await settings.setExperimentEnabled('keyer', true);
    final radio = RadioService(await SharedPreferences.getInstance(), writeDelay: Duration.zero);
    addTearDown(radio.dispose);
    transport = _LinkTransport();
    cat = CatService(
      settings,
      radio: radio,
      voiceAudio: FakeVoiceAudio(),
      voiceMessagesDirectory: () async => '/v',
      registry: EquipmentRegistry(
        models: [
          EquipmentModel(
            key: 'flex',
            category: kCategoryTransceiver,
            name: () => 'Flex',
            // No host: the receive-meter socket would bind a real port.
            variants: [EquipmentVariant(key: 'flex-link', driver: const FlexRadioDriver(), transport: transport)],
          ),
        ],
        transports: {'link': transport},
      ),
    );
    addTearDown(cat.dispose);
    // Labels this station set for radios that keep none — what must NOT
    // show while the Flex, which keeps its own, is radio1.
    await settings.setVoiceMessageLabel(3, 'Old CQ');
    await settings.setVoiceMessageDuration(3, 9999);
    final node = await cat.addNode(typeKey: 'flex-link', name: 'RadioRoom');
    flex = node.uuid;
    await cat.connect(flex);
    await cat.setRadio1(LocalRadio(flex));
    transport.link.radioSays([
      'V1.4.0.0',
      'H7C1A8533',
      'S7C1A8533|dvk status=idle enabled=1',
      'S7C1A8533|dvk added id=1 name="Recording 1" duration=2165',
      'S7C1A8533|dvk added id=3 name="59-NY-TU" duration=2165',
    ]);
    await pumpEventQueue();
  });

  tearDown(() => cat.disconnect(flex));

  test("the radio's names and lengths are the memories' names and lengths", () {
    expect(cat.canPlayVoice, isTrue, reason: 'sanity');
    expect(cat.voiceMessageLabel(3), '59-NY-TU');
    expect(cat.voiceMessageDuration(3), 2165, reason: 'a length stored here was timed against some other recording');
    expect(cat.voiceMessageLabel(1), '', reason: "SmartSDR's default name is no name");
    expect(cat.voiceMessageLabel(5), '', reason: 'an empty slot on the radio is not a label from the settings');
    expect(cat.voiceMessagesNamedOnRadio, isTrue);
  });

  test('a label typed here is saved on the radio, not in the settings', () async {
    await cat.setVoiceMessageLabel(3, 'CQ POTA');
    expect(transport.link.commands, contains('dvk set_name id=3 name="CQ POTA"'));
    expect(settings.voiceMessageLabel(3), 'Old CQ', reason: 'a second copy here would be a second answer to what memory 3 is called');
    expect(cat.voiceMessageLabel(3), 'CQ POTA');
  });

  test("a peer keying this radio hears the radio's names, not this station's settings", () {
    final status = cat.keyStatusForOfferedRadio(flex)!;
    expect(status.voiceLabels[2], '59-NY-TU');
    expect(status.voiceDurationsMs[2], 2165);
  });

  test('a play is not measured into a setting nobody reads', () async {
    cat.playVoiceMemory(3, repeat: false);
    transport.link.radioSays(['S7C1A8533|dvk status=playback id=3']);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    transport.link.radioSays(['S7C1A8533|dvk status=idle']);
    await pumpEventQueue();
    expect(cat.voiceActivity.value, isNull, reason: 'sanity: the radio ended it');
    expect(settings.voiceMessageDuration(3), 9999);
  });

  test('a Flex without the DVK licence has no voice keyer, and no problem', () async {
    transport.link.radioSays(['S53C4018F|license feature name=DIGITAL_VOICE_KEYER enabled=0 reason=PLUS']);
    await pumpEventQueue();
    expect(cat.canPlayVoice, isFalse, reason: 'its keys go disabled, and F1-F8 do whatever else they do');
    expect(cat.voiceMemoryCount, 0);
    expect(cat.stateFor(flex).problem, isNull);
    expect(cat.voiceMessageLabel(3), 'Old CQ', reason: 'holding none, it names none');
  });

  // The DVK keeps reporting its memories while the computer plays the
  // messages; reading them then would label a recording by a DVK slot's
  // name, and rename that slot when the operator names the recording.
  test('while the computer plays the messages, the radio names none of them', () async {
    await settings.setVoiceMessageSets([VoiceMessageSet.empty(id: 's1', name: 'CQ')], active: VoiceMessageSet.defaultId);
    await cat.selectVoiceKeyingSource(VoiceKeyingSource.computer);
    await cat.selectVoiceMessageSet('s1');
    await pumpEventQueue();
    expect(cat.voiceMessagesFromComputer, isTrue, reason: 'sanity');
    expect(cat.stateFor(flex).voiceMemories, isNotEmpty, reason: 'sanity: the radio still reports them');
    expect(cat.voiceMessagesNamedOnRadio, isFalse);
    expect(cat.voiceMessageLabel(3), '', reason: "the set's own label, not the slot's name");
    await cat.setVoiceMessageLabel(3, 'CQ POTA');
    expect(transport.link.commands, isNot(contains(startsWith('dvk set_name'))));
    expect(settings.activeVoiceMessageSet.label(3), 'CQ POTA');
    expect(settings.voiceMessageLabel(3), 'Old CQ', reason: "the radio's own memories keep their labels");
  });

  test('once the radio is gone the settings answer again', () async {
    await cat.disconnect(flex);
    expect(cat.voiceMessageLabel(3), 'Old CQ');
    expect(cat.voiceMessagesNamedOnRadio, isFalse);
  });
}
