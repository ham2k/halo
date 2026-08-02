// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Finding a FlexRadio by the broadcast it makes about itself: the payload
// parser, a real UDP socket carrying a real announcement, and the service's
// bookkeeping on top (dedupe by serial, hide what's already configured).

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/discovery.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/flexradio_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/cat/transports/udp_broadcast.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A FLEX-6600's discovery payload, field-for-field as captured off the
/// wire from a live radio (SmartSDR v4.2.20.41343) on UDP 4992. Serial,
/// licence id, addresses and client host names are replaced — everything
/// that identifies a particular radio or shack — but the field set, their
/// order, and their formatting are the real ones.
///
/// The fidelity is the point. It carries three things a hand-written
/// payload wouldn't: `discovery_protocol_version=` sits BEFORE `model=`,
/// `fpc_mac=` is empty in the middle of the payload, and several field
/// names CONTAIN the one we want (`inuse_ip`, `gui_client_ips` alongside
/// `ip`) — which is exactly how a sloppy parser picks the wrong address.
const _payload = 'discovery_protocol_version=3.1.0.4 model=FLEX-6600 serial=0000-0000-6600-0000 '
    'version=4.2.20.41343 nickname=RadioRoom callsign=N0CALL ip=10.0.0.66 port=4992 '
    'status=Available inuse_ip=10.0.0.123 inuse_host=Shack-PC max_licensed_version=v4 '
    'radio_license_id=00-00-00-00-00-00 fpc_mac= wan_connected=1 licensed_clients=2 '
    'available_clients=1 max_panadapters=4 available_panadapters=3 max_slices=4 '
    'available_slices=3 gui_client_ips=10.0.0.123 gui_client_hosts=Shack-PC '
    'gui_client_programs=SmartSDR-Win gui_client_stations=SHACK gui_client_handles=0x04B151AB '
    'min_software_version=2.1.20.0 external_port_link=1 license_is_unknown=0 '
    'is_system_model=0 turf_region=USA';

/// The real frame is a VITA-49 packet: the ASCII payload sits behind a
/// binary header and is NUL-padded to a 32-bit boundary. Both are
/// reproduced because both are what the parser has to see past — the
/// header in particular contains bytes that are printable ASCII.
Uint8List _vita49Frame(String payload) => Uint8List.fromList([
      0x38, 0x58, 0x00, 0xaf, 0x00, 0x00, 0x08, 0x00,
      0x00, 0x00, 0x1c, 0x2d, 0x53, 0x4c, 0xff, 0xff,
      0x6a, 0x69, 0x3e, 0xfc, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00,
      ...utf8.encode(payload),
      0, 0,
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parsing an announcement', () {
    test('reads a real FLEX-6600 discovery frame', () {
      final found = parseFlexDiscovery(_vita49Frame(_payload))!;

      expect(found.model, 'FLEX-6600');
      expect(found.serial, '0000-0000-6600-0000');
      expect(found.nickname, 'RadioRoom');
      expect(found.version, '4.2.20.41343');
      expect(found.host, '10.0.0.66');
      expect(found.port, 4992);
    });

    test('takes the radio address, not one of the fields whose name contains it', () {
      final found = parseFlexDiscovery(_vita49Frame(_payload))!;

      // `inuse_ip` and `gui_client_ips` are the CLIENT already connected to
      // the radio — connecting there instead would try to reach someone
      // else's PC. The payload also has `fpc_mac=` empty partway through,
      // which a parser that stops at the first valueless field would choke on.
      expect(found.host, isNot('10.0.0.123'));
      expect(found.host, '10.0.0.66');
    });

    test('empty fields read as absent, not as empty strings', () {
      // `inuse_ip=` and friends are empty in the real payload; a nickname
      // can be too, and the UI falls back to the model for the name.
      final found = parseFlexDiscovery(
          _vita49Frame('model=FLEX-6400 serial=1 nickname= ip=10.0.0.7 port=4992'))!;
      expect(found.nickname, isNull);
      expect(found.model, 'FLEX-6400');
    });

    test('falls back to the default port when the announcement omits one', () {
      final found = parseFlexDiscovery(_vita49Frame('model=FLEX-6300 ip=10.0.0.8'))!;
      expect(found.port, 4992);
    });

    test('ignores a datagram with no address to connect to', () {
      // Well-formed but useless — better to show nothing than a radio that
      // can't be reached.
      expect(parseFlexDiscovery(_vita49Frame('model=FLEX-6600 serial=1 port=4992')), isNull);
    });

    test('ignores datagrams from anything else sharing the port', () {
      expect(parseFlexDiscovery(utf8.encode('hello there')), isNull);
      expect(parseFlexDiscovery(const [0xde, 0xad, 0xbe, 0xef]), isNull);
      expect(parseFlexDiscovery(const []), isNull);
    });
  });

  group('over a real socket', () {
    test('an announcement sent to the port arrives parsed', () async {
      // An ephemeral port, not 4992: the test must not fight a real Flex on
      // the developer's network, or a second test run.
      final probe = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = probe.port;
      probe.close();

      final datagrams = udpBroadcastDatagrams(port: port);
      final firstFrame = datagrams.first;
      // Give the bind a moment before anything is sent at it.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final sender = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      sender.send(_vita49Frame(_payload), InternetAddress.loopbackIPv4, port);
      addTearDown(sender.close);

      final received = await firstFrame.timeout(const Duration(seconds: 5));
      expect(parseFlexDiscovery(received)?.nickname, 'RadioRoom');
    });
  });

  group('over a real socket, cancelled early', () {
    test('a listener cancelled before the bind completes still releases the port', () async {
      final probe = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = probe.port;
      probe.close();

      // Cancel immediately — inside the window where the bind is still in
      // flight and `onCancel` has no socket to close yet.
      final subscription = udpBroadcastDatagrams(port: port).listen((_) {});
      await subscription.cancel();

      // If the socket that lands after the cancel is never closed, the port
      // stays bound for the life of the process and this rebind throws.
      //
      // The probe has to bind the way the LEAKED socket does — `anyIPv4`,
      // and refusing to share. Binding `127.0.0.1` with `reuseAddress`
      // (which defaults to true) succeeds straight through a leaked
      // `anyIPv4`+`reusePort` socket, so the first version of this test
      // passed with the fix reverted and guarded nothing at all.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final rebound = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port,
          reuseAddress: false, reusePort: false);
      addTearDown(rebound.close);
      expect(rebound.port, port);
    });
  });

  group('service bookkeeping', () {
    late StreamController<DiscoveredEquipment> announcements;
    late CatService cat;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      announcements = StreamController<DiscoveredEquipment>.broadcast();
      cat = CatService(
        SettingsService(await SharedPreferences.getInstance()),
        registry: EquipmentRegistry(
          types: [_fakeDiscoverableType(announcements.stream)],
          transports: const {},
        ),
      );
    });

    tearDown(() async {
      cat.dispose();
      await announcements.close();
    });

    /// One announcement, delivered.
    Future<void> announce({required String id, required String host, String name = 'RadioRoom'}) async {
      announcements.add(DiscoveredEquipment(
        typeKey: 'fake-discoverable',
        id: id,
        name: name,
        config: {'host': host, 'port': 4992},
      ));
      await pumpEventQueue();
    }

    test('nothing has been found before discovery runs', () {
      expect(cat.discovered, isEmpty);
      expect(cat.isDiscovering, isFalse);
    });

    test('start/stop is idempotent and releases the listener', () {
      cat.startDiscovery();
      expect(cat.isDiscovering, isTrue);
      cat.startDiscovery();
      expect(cat.isDiscovering, isTrue);

      cat.stopDiscovery();
      expect(cat.isDiscovering, isFalse);
      // Discovery holds a bound UDP port in real use, so a second stop must
      // not throw.
      cat.stopDiscovery();
      expect(cat.isDiscovering, isFalse);
    });

    test('a radio announcing repeatedly appears once', () async {
      cat.startDiscovery();
      await announce(id: 'serial-1', host: '192.168.1.50');
      await announce(id: 'serial-1', host: '192.168.1.50');
      await announce(id: 'serial-1', host: '192.168.1.50');

      // A Flex re-announces every few seconds; without dedupe the Add
      // dialog fills up with the same radio.
      expect(cat.discovered, hasLength(1));
      expect(cat.discovered.single.name, 'RadioRoom');
    });

    test('a radio that moved updates in place rather than appearing twice', () async {
      cat.startDiscovery();
      await announce(id: 'serial-1', host: '192.168.1.50');
      await announce(id: 'serial-1', host: '192.168.1.77');

      expect(cat.discovered, hasLength(1));
      expect(cat.discovered.single.config['host'], '192.168.1.77');
    });

    test('two different radios both show', () async {
      cat.startDiscovery();
      await announce(id: 'serial-1', host: '192.168.1.50', name: 'RadioRoom');
      await announce(id: 'serial-2', host: '192.168.1.51', name: 'ShackFlex');

      expect(cat.discovered.map((d) => d.name), unorderedEquals(['RadioRoom', 'ShackFlex']));
    });

    test('a radio already configured drops off the found list', () async {
      cat.startDiscovery();
      await announce(id: 'serial-1', host: '192.168.1.50');
      expect(cat.discovered, hasLength(1));

      await cat.addDiscovered(cat.discovered.single);

      // It keeps announcing itself every few seconds; offering to add it
      // again each time is how you end up with six copies of one radio.
      expect(cat.nodes.single.name, 'RadioRoom');
      expect(cat.nodes.single.config, {'host': '192.168.1.50', 'port': 4992});
      expect(cat.discovered, isEmpty);

      await announce(id: 'serial-1', host: '192.168.1.50');
      expect(cat.discovered, isEmpty);
    });

    test('findings survive closing the Add dialog', () async {
      cat.startDiscovery();
      await announce(id: 'serial-1', host: '192.168.1.50');
      cat.stopDiscovery();

      // Reopening shouldn't show an empty list while waiting on the next
      // announcement — for a Flex that's several seconds of looking broken.
      expect(cat.discovered, hasLength(1));
    });

    test('a discovery that cannot start reports why instead of staying silent', () async {
      cat.startDiscovery();
      announcements.addError(StateError('Failed to bind port 4992'));
      await pumpEventQueue();

      // "Nothing found" and "we never got to look" are indistinguishable to
      // a user staring at an empty list.
      expect(cat.discoveryError, contains('Failed to bind'));
    });
  });
}

/// A type that announces itself on a stream the test controls, so the
/// service's dedupe and filtering can be exercised without a socket.
EquipmentType _fakeDiscoverableType(Stream<DiscoveredEquipment> announcements) => EquipmentType(
      key: 'fake-discoverable',
      category: kCategoryTransceiver,
      name: () => 'Fake Discoverable Radio',
      driver: const _NeverConnectsDriver(),
      transport: const _NeverConnectsTransport(),
      discoverer: _FakeDiscoverer(announcements),
    );

class _FakeDiscoverer implements EquipmentDiscoverer {
  final Stream<DiscoveredEquipment> announcements;

  const _FakeDiscoverer(this.announcements);

  @override
  Stream<DiscoveredEquipment> discover() => announcements;
}

class _NeverConnectsDriver extends EquipmentDriver {
  const _NeverConnectsDriver();

  @override
  String get key => 'fake';

  @override
  String get name => 'fake';

  @override
  bool get hardwareVerified => false;

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) =>
      throw UnimplementedError('discovery never connects');
}

class _NeverConnectsTransport extends EquipmentTransport {
  const _NeverConnectsTransport();

  @override
  String get key => 'fake';

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) =>
      throw UnimplementedError('discovery never connects');

  @override
  Map<String, dynamic> targetFor(Map<String, dynamic> config) =>
      {'host': config['host'], 'port': config['port']};

  @override
  String describeTarget(Map<String, dynamic> config) => '${config['host']}:${config['port']}';
}
