// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A Green Heron Everyware server and its device nodes through CatService,
// against a fake server on a loopback socket speaking the lines a live one
// sent (WU2X's station).
//
// What only the service can get wrong lives here: device nodes made from
// the server's ticked list and gone with it, a device riding its server's
// connection rather than opening one, its Connect and Disconnect being the
// server's, and a switch moving by itself only when nothing is on the air.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/everyware_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/everyware_devices.dart';
import 'package:ham2k_logger/services/cat/drivers/everyware_server.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/panel_equipment_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_secure_storage.dart';

const _us = '\u001F';
const _gs = '\u001D';

String _wire(String visible) => visible.replaceAll('|', _us).replaceAll('^', _gs);

final _greeting = [
  'ADD|Tower 3 - OB12-4',
  'POINT|Tower 3 - OB12-4|276.0|0|0',
  'SWITCHADD|3|OB80-2S|3.770 - 4.000 Mhz^3.77^4.0|3.500 - 3.670 Mhz^3.5^3.67',
  'SWITCHUPDATE|OB80-2S|3.770 - 4.000 Mhz|0|0',
  'SWITCHADD|2|80m 4 sq|NE^45^90^false|SE^135^90^false|SW^225^90^false|NW^315^90^false',
  'SWITCHUPDATE|80m 4 sq|SW|0|0',
].map(_wire).toList();

class _FakeEveryware {
  final ServerSocket _server;
  final _clients = <Socket>[];

  /// When set, a client must prove this login before it hears anything — the
  /// server's user authentication on.
  ({String user, String password})? login;
  static const challenge = '0.7316931046151538-81283467123456789011665432101234';

  /// When set, the greeting goes out a line at a time with this gap.
  Duration? paceGreeting;

  /// Whether a refused login is followed by the server closing the
  /// connection, as GHMac's notes have the real one do.
  bool closeAfterRefusal = false;

  void _refuse(Socket socket) {
    socket.add(cp1252Encode('INVALID USER/PASS\r\n'));
    if (closeAfterRefusal) unawaited(socket.flush().then((_) => socket.destroy(), onError: (Object _) {}));
  }

  /// Every command line a client sent, NUL keepalives dropped.
  final commands = <String>[];
  int connections = 0;

  _FakeEveryware(this._server) {
    _server.listen((socket) {
      connections++;
      _clients.add(socket);
      unawaited(socket.done.then((_) {}, onError: (Object _) {}));
      void greet() {
        final pace = paceGreeting;
        if (pace == null) return socket.add(cp1252Encode(_greeting.map((line) => '$line\r\n').join()));
        // A line at a time, as the real server sends them: what a client
        // makes of a half-announced station is only seen this way.
        unawaited(() async {
          for (final line in _greeting) {
            socket.add(cp1252Encode('$line\r\n'));
            await Future<void>.delayed(pace);
          }
        }());
      }

      final splitter = EverywareLineSplitter();
      // Raw bytes until the login is proven: the proof is 32 bytes that may
      // hold a CR or LF, and is no line at all.
      final pending = <int>[];
      var stage = login == null ? 2 : 0;
      if (login == null) {
        greet();
      } else {
        socket.add(cp1252Encode('USER:\r\n'));
      }
      socket.listen(
        (chunk) {
          if (stage == 2) {
            commands.addAll(splitter.add(chunk.where((byte) => byte != 0).toList()).where((line) => line.isNotEmpty));
            return;
          }
          pending.addAll(chunk);
          if (stage == 0 && pending.contains(10)) {
            final user = cp1252Decode(pending.sublist(0, pending.indexOf(10))).trim();
            pending.removeRange(0, pending.indexOf(10) + 1);
            if (user != login!.user) return _refuse(socket);
            stage = 1;
            socket.add(cp1252Encode('PASS:$challenge\r\n'));
          }
          if (stage == 1 && pending.length >= 32) {
            final proof = pending.sublist(0, 32);
            final expected = everywarePasswordProof(user: login!.user, password: login!.password, challenge: challenge);
            if (proof.join(',') != expected.join(',')) return _refuse(socket);
            stage = 2;
            greet();
          }
        },
        onError: (Object _) {},
        cancelOnError: true,
      );
    }, onError: (Object _) {});
  }

  static Future<_FakeEveryware> start() async => _FakeEveryware(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0));

  int get port => _server.port;

  void push(String visible) {
    for (final client in _clients) {
      client.add([...cp1252Encode(_wire(visible)), 13, 10]);
    }
  }

  /// The server going away, as a restart or a dropped link looks.
  void dropClients() {
    for (final client in _clients) {
      client.destroy();
    }
    _clients.clear();
  }

  Future<void> stop() async {
    dropClients();
    await _server.close();
  }
}

/// A radio that reports what the test says and keys when the test says.
class _Radio {
  /// Every session's sink, in the order the radios connected.
  final sinks = <EquipmentSink>[];
  EquipmentSink? get sink => sinks.lastOrNull;
}

class _RadioSession implements TransceiverSession {
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
  @override
  void setFrequency(double freqKHz) {}
  @override
  void setMode(String mode) {}
  @override
  void setPower(num watts) {}
}

class _RadioDriver extends EquipmentDriver {
  final _Radio radio;
  _RadioDriver(this.radio);
  @override
  String get key => 'test-radio';
  @override
  String get name => 'Test Radio';
  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) {
    radio.sinks.add(sink);
    return _RadioSession();
  }
}

class _OpenConnection implements EquipmentConnection {
  final _closed = Completer<void>();
  @override
  Stream<Uint8List> get data => const Stream.empty();
  @override
  Future<void> get closed => _closed.future;
  @override
  void send(List<int> bytes) {}
  @override
  Future<void> close() async {
    if (!_closed.isCompleted) _closed.complete();
  }
}

class _RadioTransport extends EquipmentTransport {
  @override
  String get key => 'test-radio';
  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async => _OpenConnection();
}

Future<void> _until(bool Function() done, {String? reason}) async {
  for (var i = 0; i < 300 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(done(), isTrue, reason: reason);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeEveryware server;
  late CatService cat;
  late _Radio radio;
  late SettingsService settings;

  setUp(() async {
    server = await _FakeEveryware.start();
    radio = _Radio();
    SharedPreferences.setMockInitialValues({});
    final radioTransport = _RadioTransport();
    final defaults = EquipmentRegistry();
    cat = CatService(
      settings = SettingsService(await SharedPreferences.getInstance(), secureStorage: FakeSecureStorage()),
      registry: EquipmentRegistry(
        models: [
          ...defaults.models,
          EquipmentModel(
            key: 'test-radio',
            category: kCategoryTransceiver,
            name: () => 'Test Radio',
            variants: [EquipmentVariant(key: 'test-radio', driver: _RadioDriver(radio), transport: radioTransport)],
          ),
        ],
        transports: {...defaults.transports, 'test-radio': radioTransport},
      ),
    );
  });

  tearDown(() async {
    cat.dispose();
    await server.stop();
  });

  /// A connected server node with [devices] ticked.
  Future<EquipmentNode> connectedServer({List<String> devices = const []}) async {
    final node = await cat.addNode(typeKey: everywareServerTypeKey, config: {'host': '127.0.0.1', 'port': server.port});
    await cat.connect(node.uuid);
    await _until(() => cat.stateFor(node.uuid).channels.length == 3, reason: 'the server announces one rotor and two switches');
    if (devices.isNotEmpty) await cat.updateNode(node.copyWith(config: {...node.config, everywareDevicesConfigKey: devices}));
    return cat.nodeFor(node.uuid)!;
  }

  List<EquipmentNode> devicesOf(EquipmentNode server) => [
    for (final node in cat.nodes)
      if (node.config[everywareServerConfigKey] == server.uuid) node,
  ];

  test('a ticked device is a node of its own, on its server’s one connection', () async {
    final node = await connectedServer(devices: ['rotor:Tower 3 - OB12-4', 'switchBox:80m 4 sq']);
    final devices = devicesOf(node);
    // The 4-square is a switch on the wire and a rotator here: what it does
    // is point an antenna.
    expect(devices.map((d) => (d.name, d.typeKey)), [('Tower 3 - OB12-4', everywareRotorTypeKey), ('80m 4 sq', everywareDirectionalTypeKey)]);
    final rotor = devices.first.uuid;
    final fourSquare = devices.last.uuid;
    // Up with the server, from what the server had already said — the rotor
    // never sees its ADD again, and needs none.
    await _until(() => cat.stateFor(rotor).rotator == const RotatorPosition(azimuth: 276));
    await _until(() => cat.stateFor(fourSquare).rotator == const RotatorPosition(azimuth: 225, beamWidth: 90), reason: 'SW, as its heading and its beam');
    expect(server.connections, 1, reason: 'a device rides its server’s connection; a socket each would fill the server’s four client slots');

    expect(cat.rotateTo(rotor, azimuth: 250), const RotatorPosition(azimuth: 250));
    expect(cat.rotateTo(fourSquare, azimuth: 30), const RotatorPosition(azimuth: 45), reason: 'the nearest direction, which is where it will arrive');
    await _until(() => server.commands.length == 2);
    expect(server.commands.map(everywareVisible), ['TURN␟Tower 3 - OB12-4␟250', 'SET_SWITCH␟80m 4 sq␟NE']);
  });

  test("a device's Connect and Disconnect are its server's", () async {
    final node = await connectedServer(devices: ['rotor:Tower 3 - OB12-4']);
    final rotor = devicesOf(node).single.uuid;
    await _until(() => cat.stateFor(rotor).status == EquipmentStatus.connected);

    await cat.disconnect(rotor);
    expect(cat.stateFor(node.uuid).status, EquipmentStatus.disconnected);
    await _until(() => cat.stateFor(rotor).status == EquipmentStatus.disconnected);

    await cat.connect(rotor);
    await _until(() => cat.stateFor(rotor).status == EquipmentStatus.connected, reason: 'connecting a device brings its server and every device up');
    expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected);
  });

  test('a device drops with its server, and is not left connected to nothing', () async {
    final node = await connectedServer(devices: ['switchBox:80m 4 sq']);
    final fourSquare = devicesOf(node).single.uuid;
    await _until(() => cat.stateFor(fourSquare).status == EquipmentStatus.connected);
    server.dropClients();
    await _until(() => cat.stateFor(fourSquare).status == EquipmentStatus.disconnected);
  });

  test('unticking a device removes its node, and removing the server removes them all', () async {
    final node = await connectedServer(devices: ['rotor:Tower 3 - OB12-4', 'switchBox:80m 4 sq']);
    await cat.updateNode(
      node.copyWith(
        config: {
          ...node.config,
          everywareDevicesConfigKey: ['switchBox:80m 4 sq'],
        },
      ),
    );
    expect(devicesOf(node).map((d) => d.name), ['80m 4 sq']);
    await cat.removeNode(node.uuid);
    expect(cat.nodes, isEmpty, reason: 'a device with no server could never be reached again');
  });

  test('a device removed on its own stays removed when its server is next saved', () async {
    final node = await connectedServer(devices: ['rotor:Tower 3 - OB12-4', 'switchBox:80m 4 sq']);
    await cat.removeNode(devicesOf(node).first.uuid);
    expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected, reason: "removing a device is not its server's Disconnect");
    final server = cat.nodeFor(node.uuid)!;
    expect(server.config[everywareDevicesConfigKey], ['switchBox:80m 4 sq']);
    await cat.updateNode(server.copyWith(name: 'Shack server'));
    expect(devicesOf(node).map((d) => d.name), ['80m 4 sq']);
  });

  test('a band switch follows the main radio only when its node says so, and never on the air', () async {
    final node = await connectedServer(devices: ['switchBox:OB80-2S']);
    final band = devicesOf(node).single;
    await _until(() => cat.stateFor(band.uuid).switchPorts.isNotEmpty);
    final rig = await cat.addNode(typeKey: 'test-radio');
    await cat.connect(rig.uuid);

    radio.sink!.report(const VfoReading(freqKHz: 3520, mode: 'CW'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(server.commands, isEmpty, reason: 'off unless the operator opts in: the station is shared');

    await cat.updateNode(band.copyWith(config: {...band.config, everywareFollowConfigKey: true}));
    await _until(() => cat.stateFor(band.uuid).switchPorts.isNotEmpty);
    radio.sink!.reportTransmitting(true);
    radio.sink!.report(const VfoReading(freqKHz: 3521, mode: 'CW'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(server.commands, isEmpty, reason: 'a relay thrown under RF is what destroys one');

    radio.sink!.reportTransmitting(false);
    radio.sink!.report(const VfoReading(freqKHz: 3522, mode: 'CW'));
    await _until(() => server.commands.isNotEmpty);
    expect(server.commands.map(everywareVisible), ['SET_SWITCH␟OB80-2S␟3.500 - 3.670 Mhz']);
  });

  test('a map switch that follows the station worked points toward its bearing', () async {
    final node = await connectedServer(devices: ['switchBox:80m 4 sq']);
    final fourSquare = devicesOf(node).single;
    await cat.updateNode(fourSquare.copyWith(config: {...fourSquare.config, everywareFollowConfigKey: true}));
    await _until(() => cat.stateFor(fourSquare.uuid).rotator != null);
    cat.pointEverywareSwitchesToward(40);
    await _until(() => server.commands.isNotEmpty);
    expect(server.commands.map(everywareVisible), ['SET_SWITCH␟80m 4 sq␟NE']);
  });

  test('logs in with the password kept in the keychain, never in the stored config', () async {
    server.login = (user: 'alice', password: 'secret1');
    final node = await cat.addNode(typeKey: everywareServerTypeKey, config: {'host': '127.0.0.1', 'port': server.port, 'user': 'alice', 'password': 'secret1'});
    expect(cat.nodeFor(node.uuid)!.config.containsKey('password'), isFalse);
    await cat.connect(node.uuid);
    await _until(() => cat.stateFor(node.uuid).channels.length == 3, reason: 'the server says nothing until the login is proven');
    expect(cat.stateFor(node.uuid).problem, isNull);
  });

  test('the server keeps what it announced, for its editor to list while it is away', () async {
    final node = await connectedServer();
    await _until(() => cat.nodeFor(node.uuid)!.config[everywareKnownDevicesConfigKey] != null);
    expect(cat.nodeFor(node.uuid)!.config[everywareKnownDevicesConfigKey], [
      {'key': 'rotor:Tower 3 - OB12-4'},
      {'key': 'switchBox:OB80-2S', 'kind': 'band'},
      {'key': 'switchBox:80m 4 sq', 'kind': 'map'},
    ]);
    await cat.disconnect(node.uuid);
    expect(cat.nodeFor(node.uuid)!.config[everywareKnownDevicesConfigKey], hasLength(3), reason: 'a disconnect forgets nothing');
  });

  test('a stack is listed, never made a node: nothing here drives several antennas at once', () async {
    final node = await connectedServer(devices: ['stack:Upper,Lower', 'rotor:Tower 3 - OB12-4']);
    expect(devicesOf(node).map((d) => d.name), ['Tower 3 - OB12-4']);
  });

  test('a map switch ticked before the server said what it is becomes a rotator once it does, still ticked', () async {
    final node = await cat.addNode(
      typeKey: everywareServerTypeKey,
      config: {
        'host': '127.0.0.1',
        'port': server.port,
        everywareDevicesConfigKey: ['switchBox:80m 4 sq'],
      },
    );
    final made = devicesOf(node).single;
    expect(made.typeKey, everywareSwitchTypeKey, reason: 'nothing has said it is directional yet');
    await cat.updateNode(made.copyWith(name: '80m array'));
    await cat.connect(node.uuid);
    await _until(() => devicesOf(node).singleOrNull?.typeKey == everywareDirectionalTypeKey);
    // Retyped where it stands, not made again: the operator's name for it,
    // and every panel pointed at it, stay with it.
    expect((devicesOf(node).single.uuid, devicesOf(node).single.name), (made.uuid, '80m array'));
    expect(cat.nodeFor(node.uuid)!.config[everywareDevicesConfigKey], ['switchBox:80m 4 sq'], reason: 'made again as what it is, not unticked');
    await _until(() => cat.stateFor(devicesOf(node).single.uuid).rotator?.azimuth == 225);
  });

  test('a directional switch keeps its type through every announcement of a connect', () async {
    final node = await connectedServer(devices: ['switchBox:80m 4 sq']);
    final fourSquare = devicesOf(node).single.uuid;
    await _until(() => cat.nodeFor(fourSquare)?.typeKey == everywareDirectionalTypeKey);
    await cat.disconnect(node.uuid);
    server.paceGreeting = const Duration(milliseconds: 30);
    // The server announces one device at a time: the rotor first, the
    // 4-square fifth. Read between them, a device not yet announced is not a
    // different kind — retyped there, it leaves the rotator panel and comes
    // back on every connect.
    final seen = <String>{};
    void watch() => seen.add(cat.nodeFor(fourSquare)?.typeKey ?? 'gone');
    cat.addListener(watch);
    addTearDown(() => cat.removeListener(watch));
    await cat.connect(node.uuid);
    await _until(() => cat.stateFor(fourSquare).rotator?.azimuth == 225);
    expect(seen, {everywareDirectionalTypeKey});
  });

  test("a directional switch's turn waits out a transmission, as a switch's selection does", () async {
    final node = await connectedServer(devices: ['switchBox:80m 4 sq']);
    final fourSquare = devicesOf(node).single.uuid;
    await _until(() => cat.stateFor(fourSquare).rotator != null);
    final rig = await cat.addNode(typeKey: 'test-radio');
    await cat.connect(rig.uuid);
    radio.sink!.reportTransmitting(true);
    expect(cat.rotateTo(fourSquare, azimuth: 40), isNull, reason: 'a relay thrown under RF is what destroys one');
    // `failed` would tell an extension the device is broken, and promise the
    // operator a notice that nothing gives.
    expect((await PanelEquipmentService(cat).setRotator({'id': fourSquare, 'azimuth': 40}))['reason'], 'transmitting');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(server.commands, isEmpty);
    radio.sink!.reportTransmitting(false);
    expect(cat.rotateTo(fourSquare, azimuth: 40), const RotatorPosition(azimuth: 45));
    await _until(() => server.commands.isNotEmpty);
  });

  test('a refused login keeps the devices down, and the reason on the server, even once it hangs up', () async {
    server
      ..login = (user: 'alice', password: 'secret1')
      ..closeAfterRefusal = true;
    final node = await cat.addNode(
      typeKey: everywareServerTypeKey,
      config: {
        'host': '127.0.0.1',
        'port': server.port,
        'user': 'alice',
        'password': 'wrong',
        everywareDevicesConfigKey: ['rotor:Tower 3 - OB12-4'],
      },
    );
    final rotor = devicesOf(node).single.uuid;
    await cat.connect(node.uuid);
    await _until(() => cat.stateFor(node.uuid).status == EquipmentStatus.error);
    expect(
      cat.stateFor(node.uuid).error,
      t.settings.station.everywareLoginRefused,
      reason: 'the hang-up is because of the refusal, so the refusal is what the row says',
    );
    expect(cat.stateFor(rotor).status, isNot(EquipmentStatus.connected), reason: 'a device up before the login would read connected to nothing');
  });

  test("Connect on one device leaves its server and the other devices up", () async {
    final node = await connectedServer(devices: ['rotor:Tower 3 - OB12-4', 'switchBox:80m 4 sq']);
    final [rotor, fourSquare] = [for (final device in devicesOf(node)) device.uuid];
    await _until(() => cat.stateFor(rotor).status == EquipmentStatus.connected && cat.stateFor(fourSquare).status == EquipmentStatus.connected);
    await cat.disconnect(fourSquare, byUser: false);
    await cat.connect(fourSquare);
    await _until(() => cat.stateFor(fourSquare).status == EquipmentStatus.connected);
    expect(server.connections, 1, reason: 'reconnecting the server to bring up one device drops all the others');
    expect(cat.stateFor(rotor).status, EquipmentStatus.connected);
  });

  test('a device ticked while the login is still pending waits for the server to announce', () async {
    server.login = (user: 'alice', password: 'secret1');
    final node = await cat.addNode(typeKey: everywareServerTypeKey, config: {'host': '127.0.0.1', 'port': server.port});
    await cat.connect(node.uuid);
    await _until(() => cat.stateFor(node.uuid).problem == t.settings.station.everywareNeedsLogin);
    await cat.updateNode(
      cat
          .nodeFor(node.uuid)!
          .copyWith(
            config: {
              ...cat.nodeFor(node.uuid)!.config,
              everywareDevicesConfigKey: ['rotor:Tower 3 - OB12-4'],
            },
          ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(cat.stateFor(devicesOf(node).single.uuid).status, isNot(EquipmentStatus.connected));
  });

  test('a connect keeps the whole list it remembered while the server announces it one device at a time', () async {
    final node = await connectedServer();
    await _until(() => (cat.nodeFor(node.uuid)!.config[everywareKnownDevicesConfigKey] as List?)?.length == 3);
    await cat.disconnect(node.uuid);
    server.paceGreeting = const Duration(milliseconds: 30);
    final lengths = <int>{};
    void watch() => lengths.add((cat.nodeFor(node.uuid)?.config[everywareKnownDevicesConfigKey] as List?)?.length ?? 0);
    cat.addListener(watch);
    addTearDown(() => cat.removeListener(watch));
    await cat.connect(node.uuid);
    await _until(() => cat.stateFor(node.uuid).channels.length == 3);
    expect(lengths, {3}, reason: 'replaced at each announcement, it is written short and saved on every connect');
  });

  test("a server's editor saved after an announcement keeps the announcement", () async {
    final node = await connectedServer();
    await _until(() => (cat.nodeFor(node.uuid)!.config[everywareKnownDevicesConfigKey] as List?)?.length == 3);
    // The editor opened before anything was announced, and saves what it read.
    await cat.updateNode(node.copyWith(name: 'Renamed'));
    expect(cat.nodeFor(node.uuid)!.config[everywareKnownDevicesConfigKey], hasLength(3));
  });

  test("a band switch following SO2R's Radio B moves with Radio B, not Radio A", () async {
    final node = await connectedServer(devices: ['switchBox:OB80-2S']);
    final band = devicesOf(node).single;
    await cat.updateNode(band.copyWith(config: {...band.config, everywareFollowConfigKey: true, everywareFollowRadioConfigKey: everywareFollowRadioB}));
    await _until(() => cat.stateFor(band.uuid).switchPorts.isNotEmpty);
    await settings.setExperimentEnabled('so2r', true);
    final radioA = await cat.addNode(typeKey: 'test-radio', name: 'A');
    final radioB = await cat.addNode(typeKey: 'test-radio', name: 'B');
    await cat.setRadio1(LocalRadio(radioA.uuid));
    await cat.setRadio2(radioB.uuid);
    await cat.connect(radioA.uuid);
    await cat.connect(radioB.uuid);
    await _until(() => radio.sinks.length == 2);
    final [a, b] = radio.sinks;
    a.report(const VfoReading(freqKHz: 3520, mode: 'CW'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(server.commands, isEmpty, reason: "Radio A's band is not the band of the antenna feeding Radio B");
    b.report(const VfoReading(freqKHz: 3520, mode: 'CW'));
    await _until(() => server.commands.isNotEmpty);
    expect(server.commands.map(everywareVisible), ['SET_SWITCH␟OB80-2S␟3.500 - 3.670 Mhz']);
  });

  test('Connect on a device leaves alone a server still logging in', () async {
    server.login = (user: 'alice', password: 'secret1');
    final node = await cat.addNode(
      typeKey: everywareServerTypeKey,
      config: {
        'host': '127.0.0.1',
        'port': server.port,
        everywareDevicesConfigKey: ['rotor:Tower 3 - OB12-4'],
      },
    );
    await cat.connect(node.uuid);
    await _until(() => cat.stateFor(node.uuid).problem == t.settings.station.everywareNeedsLogin);
    await cat.connect(devicesOf(node).single.uuid);
    await cat.connect(devicesOf(node).single.uuid);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(server.connections, 1, reason: 'restarting the login gets the device up no sooner, and resets every other');
  });

  test("the server's last device withdrawn leaves the remembered list too", () async {
    final node = await connectedServer();
    await _until(() => (cat.nodeFor(node.uuid)!.config[everywareKnownDevicesConfigKey] as List?)?.length == 3);
    server
      ..push('REMOVE|Tower 3 - OB12-4')
      ..push('SWITCHREMOVE|OB80-2S')
      ..push('SWITCHREMOVE|80m 4 sq');
    await _until(() => (cat.nodeFor(node.uuid)!.config[everywareKnownDevicesConfigKey] as List?)?.isEmpty ?? false);
  });
}
