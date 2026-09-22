// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The first-success signal and the mark that keeps it to once — see
// radio_proof.dart and docs/design/telemetry.md § Radios.
//
// The rule these exist to defend is that the report describes the RADIO, not
// the app: everything below turns on the difference between a value that came
// off the wire and one the app put there itself.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/radio_proof.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The toy protocol below is `<kHz> <mode>` per line, either field
/// omittable — which is what lets a test say "the radio reported only a
/// frequency" and mean it.
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
    if (_closed.isCompleted) return;
    _closed.complete();
    unawaited(_data.close());
  }

  void push(String line) => _data.add(Uint8List.fromList(utf8.encode(line)));
}

class _Session implements TransceiverSession {
  final EquipmentSink sink;
  _Session(this.sink);

  @override
  void handleData(Uint8List chunk) {
    for (final line in utf8.decode(chunk).split('\n')) {
      if (line.trim().isEmpty) continue;
      final parts = line.trim().split(' ');
      sink.report(VfoReading(freqKHz: parts[0] == '-' ? null : double.tryParse(parts[0]), mode: parts.length > 1 ? parts[1] : null));
    }
  }

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
  Duration? get expectedUpdateInterval => null;
  @override
  void teardown() {}
}

class _Driver extends EquipmentDriver {
  const _Driver();
  @override
  String get key => 'proof-driver';
  @override
  String get name => 'Proof Radio';
  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => _Session(sink);
}

class _Transport extends EquipmentTransport {
  final connections = <_Connection>[];

  @override
  String get key => 'proof';

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async {
    final connection = _Connection();
    connections.add(connection);
    return connection;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService settings;
  late _Transport transport;
  late CatService cat;
  late List<EquipmentNode> proven;

  EquipmentModel model(EquipmentTransport transport) => EquipmentModel(
    key: 'proof-model',
    category: kCategoryTransceiver,
    name: _modelName,
    variants: [EquipmentVariant(key: 'proof-type', driver: const _Driver(), transport: transport)],
  );

  Future<void> makeService() async {
    settings = SettingsService(await SharedPreferences.getInstance());
    transport = _Transport();
    proven = [];
    cat = CatService(
      settings,
      registry: EquipmentRegistry(models: [model(transport)], transports: {'proof': transport}),
      reconnectDelay: Duration.zero,
    )..onRadioProven = proven.add;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await makeService();
  });

  Future<EquipmentNode> addRadio({Map<String, dynamic>? config}) =>
      cat.addNode(typeKey: 'proof-type', name: 'Bench Radio', config: config ?? {'host': 'radio.local'});

  Future<_Connection> connectAndLand(EquipmentNode node) async {
    await cat.connect(node.uuid);
    await pumpEventQueue();
    return transport.connections.last;
  }

  group('what counts as a radio that works', () {
    test('a frequency alone is not proof, and neither is a mode alone', () async {
      final node = await addRadio();
      final connection = await connectAndLand(node);

      connection.push('14074\n');
      await pumpEventQueue();
      expect(proven, isEmpty, reason: 'a rig that never reports its mode has not answered the question');

      connection.push('- CW\n');
      await pumpEventQueue();
      expect(proven, hasLength(1), reason: 'the two may arrive in separate frames');
    });

    test('the app tuning the radio is not the radio answering', () async {
      // THE trap this whole feature turns on. _applyReading completes a
      // partial frame from `lastSent` — what the app TOLD the rig — so a
      // radio that echoes only its frequency still produces a merged reading
      // carrying both fields. Reporting that would file "this pairing reads
      // frequency and mode" about the app talking to itself.
      final node = await addRadio();
      final connection = await connectAndLand(node);

      cat.tuneNode(node.uuid, const VfoReading(freqKHz: 14074, mode: 'CW'));
      await pumpEventQueue();
      expect(proven, isEmpty, reason: 'nothing has come off the wire yet');

      connection.push('14074\n');
      await pumpEventQueue();
      expect(proven, isEmpty, reason: 'the mode in the merged reading is the app\'s own, not the radio\'s');
    });

    test('a reconnect does not ask again', () async {
      // The idle retry reconnects an unhappy radio for the whole session. A
      // report per connection would be a report per retry.
      final node = await addRadio();
      var connection = await connectAndLand(node);
      connection.push('14074 CW\n');
      await pumpEventQueue();

      await cat.disconnect(node.uuid);
      connection = await connectAndLand(node);
      connection.push('14074 CW\n');
      await pumpEventQueue();

      expect(proven, hasLength(1));
    });
  });

  group('the mark that keeps it to once', () {
    test('a changed setting re-arms it, a reordered config does not', () async {
      // Changing a port or a baud rate to get a rig talking is the most
      // useful thing an operator can tell us, so it must count as a new
      // answer — while a config map that merely serialised in another order
      // is the same setup and must not.
      final node = await addRadio(config: {'host': 'radio.local', 'baudRate': 9600});
      final registry = cat.registry;
      await markRadioProven(settings.prefs, node, registry);
      expect(isRadioProven(settings.prefs, node, registry), isTrue);

      final reordered = node.copyWith(config: {'baudRate': 9600, 'host': 'radio.local'});
      expect(isRadioProven(settings.prefs, reordered, registry), isTrue, reason: 'key order is not a setting');

      final rewired = node.copyWith(config: {'host': 'radio.local', 'baudRate': 19200});
      expect(isRadioProven(settings.prefs, rewired, registry), isFalse, reason: 'a different baud rate is a different answer');
    });

    test('one mark per node, however many settings it has worked under', () async {
      // Otherwise the preference file grows by one entry every time an
      // operator tries another baud rate, and never shrinks.
      final node = await addRadio(config: {'host': 'radio.local', 'baudRate': 9600});
      await markRadioProven(settings.prefs, node, cat.registry);
      await markRadioProven(settings.prefs, node.copyWith(config: {'host': 'radio.local', 'baudRate': 19200}), cat.registry);

      expect(provenRadioMarks(settings.prefs), hasLength(1));
    });

    test('removing the radio takes its mark with it', () async {
      // A node re-added later can take the same uuid, and a mark left behind
      // would silence the report for exactly the setup somebody just
      // rebuilt by hand.
      final node = await addRadio();
      await markRadioProven(settings.prefs, node, cat.registry);
      await cat.removeNode(node.uuid);

      expect(provenRadioMarks(settings.prefs), isEmpty);
    });
  });
}

String _modelName() => 'Proof Radio';
