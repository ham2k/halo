// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/midi/midi_backend.dart';
import 'package:ham2k_logger/services/midi/midi_codec.dart';
import 'package:ham2k_logger/services/midi/midi_mapping.dart';
import 'package:ham2k_logger/services/midi/midi_service.dart';
import 'package:ham2k_logger/services/midi/midi_station.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/error_reporting_fakes.dart';
import '../support/fake_secure_storage.dart';

class _Backend implements MidiBackend {
  final listed = <MidiDeviceInfo>[];
  final connected = <String>[];

  /// While set, a connect waits on it: a device slow to open.
  Completer<void>? opening;
  final _packets = StreamController<({String deviceId, Uint8List data})>.broadcast();
  final _changes = StreamController<void>.broadcast();

  void plug(String id, String name) {
    listed.add(MidiDeviceInfo(id: id, name: name));
    _changes.add(null);
  }

  void unplug(String id) {
    listed.removeWhere((d) => d.id == id);
    _changes.add(null);
  }

  void send(String id, List<int> bytes) => _packets.add((deviceId: id, data: Uint8List.fromList(bytes)));

  @override
  Future<List<MidiDeviceInfo>> devices() async => [for (final d in listed) MidiDeviceInfo(id: d.id, name: d.name, connected: connected.contains(d.id))];
  @override
  Future<void> connect(String id) async {
    await opening?.future;
    connected.add(id);
  }

  @override
  void disconnect(String id) => connected.remove(id);
  @override
  Stream<({String deviceId, Uint8List data})> get packets => _packets.stream;
  @override
  Stream<void> get changes => _changes.stream;

  /// As FlutterMidiBackend's: closes what is open.
  @override
  void dispose() => connected.clear();
}

/// Radio A in Phone, keyable; records the key.
class _Station implements MidiStation {
  final held = <String>{};
  final tunes = <double>[];
  @override
  String? radioUuid(String radio) => radio == 'A' ? 'radio-a' : null;
  @override
  bool get so2rOn => false;
  @override
  ({double? freqKHz, String? mode, String? band}) vfo(String radio) => (freqKHz: 14200.0, mode: 'USB', band: '20m');
  @override
  void tune(String radio, double freqKHz) => tunes.add(freqKHz);
  @override
  bool get keyingEnabled => true;
  @override
  bool canPtt(String radio) => true;
  @override
  bool pttHeld(String radio) => held.contains(radio);
  @override
  bool pttWaiting(String radio) => false;
  @override
  void togglePtt(String radio) => held.add(radio);
  @override
  void releasePtt() => held.clear();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService settings;
  late CatService cat;
  late _Backend backend;
  late _Station station;
  late MidiService midi;
  var opened = 0;
  var shortcuts = <String, String>{};

  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<EquipmentNode> addController({String? device, Map<String, dynamic> controls = const {}}) =>
      cat.addNode(typeKey: 'midi-controller-none', name: 'Knobs', config: {midiDeviceConfigKey: ?device, midiControlsConfigKey: controls});

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    settings = SettingsService(prefs, secureStorage: FakeSecureStorage());
    cat = CatService(
      settings,
      radio: RadioService(prefs, writeDelay: Duration.zero),
      registry: EquipmentRegistry(models: const [midiControllerModel], transports: const {}),
    );
    backend = _Backend();
    station = _Station();
    shortcuts = {};
    opened = 0;
    midi = MidiService(
      cat: cat,
      settings: settings,
      station: station,
      backend: () {
        opened++;
        return backend;
      },
      shortcutFor: (control) => shortcuts[control],
    )..start();
  });

  tearDown(() => midi.dispose());

  test('asks the platform for nothing until the experiment is on and a controller exists', () async {
    // On the web the first ask is a permission prompt: an operator who never
    // added a controller must never see one.
    await addController(device: 'Knobs');
    await settle();
    expect(opened, 0);
    await settings.setExperimentEnabled('midi', true);
    await settle();
    expect(opened, 1);
  });

  group('with the experiment on', () {
    setUp(() => settings.setExperimentEnabled('midi', true));

    test('binds the named device and acts on what it sends', () async {
      backend.plug('dev-1', 'Knobs');
      await addController(device: 'Knobs', controls: {'vfoAFine': const MidiControl(MidiControlKind.cc, 1, 21).toJson()});
      await settle();
      expect(backend.connected, ['dev-1']);
      backend.send('dev-1', [0xB0, 21, 65]);
      await settle();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(station.tunes, [closeTo(14200.01, 1e-9)]);
    });

    test('a device plugged in later is found by its name', () async {
      final node = await addController(device: 'Knobs');
      await settle();
      expect(midi.statusFor(node.uuid), MidiDeviceStatus.waiting);
      backend.plug('dev-7', 'Knobs');
      await settle();
      expect(midi.statusFor(node.uuid), MidiDeviceStatus.connected);
    });

    test('unplugging the device mid-transmission unkeys the radio', () async {
      // Its release will never come: the footswitch is on a cable that is
      // no longer attached, and the radio would stay on the air.
      backend.plug('dev-1', 'Knobs');
      await addController(device: 'Knobs', controls: {'pttA': const MidiControl(MidiControlKind.note, 1, 60).toJson()});
      await settle();
      backend.send('dev-1', [0x90, 60, 100]);
      await settle();
      expect(station.held, {'A'});
      backend.unplug('dev-1');
      await settle();
      expect(station.held, isEmpty);
    });

    test('removing a controller closes its device', () async {
      // Left open, a controller added later for the same device would open
      // it a second time and act on its every message twice.
      // Another controller stays: the last one going stops MIDI altogether.
      backend
        ..plug('dev-1', 'Knobs')
        ..plug('dev-2', 'Pads');
      final node = await addController(device: 'Knobs');
      await addController(device: 'Pads');
      await settle();
      expect(backend.connected, unorderedEquals(['dev-1', 'dev-2']));
      await cat.removeNode(node.uuid);
      await settle();
      expect(backend.connected, ['dev-2']);
    });

    test('a controller removed while its device opens closes it, and the next still binds', () async {
      backend
        ..plug('dev-1', 'Knobs')
        ..plug('dev-2', 'Pads');
      backend.opening = Completer();
      final knobs = await addController(device: 'Knobs');
      final pads = await addController(device: 'Pads');
      await settle();
      await cat.removeNode(knobs.uuid);
      backend.opening!.complete();
      backend.opening = null;
      await settle();
      expect(backend.connected, ['dev-2']);
      expect(midi.statusFor(pads.uuid), MidiDeviceStatus.connected);
    });

    test('a controller added while another\'s device opens is bound, and nothing goes wrong', () async {
      // The bind walks the controllers across the wait: one added meanwhile
      // must not throw the walk out halfway.
      final errors = FakeErrorReportingBackend();
      await withErrorHooks(backend: errors, () async {
        backend
          ..plug('dev-1', 'Knobs')
          ..plug('dev-2', 'Pads');
        backend.opening = Completer();
        await addController(device: 'Knobs');
        await settle();
        final pads = await addController(device: 'Pads');
        backend.opening!.complete();
        backend.opening = null;
        await settle();
        expect(backend.connected, unorderedEquals(['dev-1', 'dev-2']));
        expect(midi.statusFor(pads.uuid), MidiDeviceStatus.connected);
      });
      expect(errors.exceptions, isEmpty);
    });

    test('a CC button released before Learn\'s write lands still presses next time', () async {
      // Press and release in one packet: the mapping is not saved yet when
      // the release arrives. Missing the row, it would leave the row held,
      // and the operator's first real press would read as no change.
      backend.plug('dev-1', 'Knobs');
      final node = await addController(device: 'Knobs');
      await settle();
      midi.toggleLearn(node.uuid, 'pttA');
      backend.send('dev-1', [0xB0, 64, 127, 0xB0, 64, 0]);
      await settle();
      backend.send('dev-1', [0xB0, 64, 127]);
      await settle();
      expect(station.held, {'A'});
    });

    test('Learn maps the control that moved, and its release does not act', () async {
      backend.plug('dev-1', 'Knobs');
      final node = await addController(device: 'Knobs');
      await settle();
      midi.toggleLearn(node.uuid, 'pttA');
      backend.send('dev-1', [0x90, 60, 100]);
      await settle();
      expect(MidiMapping.fromConfig(cat.nodeFor(node.uuid)!.config).controls['pttA'], const MidiControl(MidiControlKind.note, 1, 60));
      expect(midi.learning.value, isNull);
      // The release of the very press that was learned: keying on it would
      // put the radio on the air the moment Learn finished.
      backend.send('dev-1', [0x80, 60, 0]);
      await settle();
      expect(station.held, isEmpty);
    });

    test('Learn turns down a control its row cannot use, and keeps listening', () async {
      backend.plug('dev-1', 'Knobs');
      final node = await addController(device: 'Knobs');
      await settle();
      midi.toggleLearn(node.uuid, 'vfoAFine');
      // A pad offered to a tuning knob: a note says nothing about direction.
      backend.send('dev-1', [0x90, 36, 100]);
      await settle();
      expect(midi.learning.value?.refused, isNotNull);
      expect(MidiMapping.fromConfig(cat.nodeFor(node.uuid)!.config).controls, isEmpty);
      backend.send('dev-1', [0xB0, 21, 65]);
      await settle();
      expect(MidiMapping.fromConfig(cat.nodeFor(node.uuid)!.config).controls['vfoAFine'], const MidiControl(MidiControlKind.cc, 1, 21));
    });

    test('one control drives one target', () async {
      const knob = MidiControl(MidiControlKind.cc, 1, 21);
      final config = MidiMapping.assign(
        {
          midiControlsConfigKey: {'vfoAFine': knob.toJson()},
        },
        'vfoBFine',
        knob,
      );
      expect(MidiMapping.fromConfig(config).controls, {'vfoBFine': knob});
    });
  });

  group('Keyboard Shortcuts bound to MIDI controls', () {
    late List<String> pressed;
    bool handler(KeyEvent event) {
      if (event is CommandKeyEvent) pressed.add('${event is KeyDownEvent ? 'down' : 'up'} ${event.commandId}');
      return event is CommandKeyEvent;
    }

    setUp(() async {
      await settings.setExperimentEnabled('midi', true);
      pressed = [];
      HardwareKeyboard.instance.addHandler(handler);
      backend.plug('dev-1', 'Knobs');
    });
    tearDown(() => HardwareKeyboard.instance.removeHandler(handler));

    test('a control no controller maps presses its shortcut, once per press', () async {
      shortcuts = {'note:1:36': 'keyer.message1'};
      await addController(device: 'Knobs');
      await settle();
      backend.send('dev-1', [0x90, 36, 100, 0x80, 36, 0]);
      await settle();
      expect(pressed, ['down keyer.message1', 'up keyer.message1']);
    });

    test('a controller\'s own mapping wins over a shortcut on the same control', () async {
      // Both acting would key F1's CQ every time the operator meant PTT.
      shortcuts = {'note:1:60': 'keyer.message1'};
      await addController(device: 'Knobs', controls: {'pttA': const MidiControl(MidiControlKind.note, 1, 60).toJson()});
      await settle();
      backend.send('dev-1', [0x90, 60, 100]);
      await settle();
      expect(pressed, isEmpty);
      expect(station.held, {'A'});
    });

    test('unplugging lets go of a held shortcut', () async {
      // PTT bound in Keyboard Shortcuts holds while the key is down: a
      // pedal unplugged mid-over never sends its release.
      shortcuts = {'note:1:36': 'radio.ptt'};
      await addController(device: 'Knobs');
      await settle();
      backend.send('dev-1', [0x90, 36, 100]);
      await settle();
      backend.unplug('dev-1');
      await settle();
      expect(pressed, ['down radio.ptt', 'up radio.ptt']);
    });

    test('Learn hands over the next press and swallows the knob turned on the way', () async {
      shortcuts = {'cc:1:21': 'app.toggleTheme'};
      await addController(device: 'Knobs');
      await settle();
      MidiControl? learned;
      midi.learnShortcut((control) => learned = control);
      backend.send('dev-1', [0xB0, 21, 127, 0x90, 40, 90]);
      await settle();
      expect(pressed, isEmpty);
      expect(learned, const MidiControl(MidiControlKind.cc, 1, 21));
    });
  });
}
