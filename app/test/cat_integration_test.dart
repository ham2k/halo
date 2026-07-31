// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The whole chain with nothing faked but the radio: the real
// EquipmentRegistry, the real TCP transport over a real loopback socket,
// and the real FlexRadio driver, driven by CatService the way the Station
// Configuration panel drives it.
//
// The unit tests each prove one layer; this is the only tier that proves
// they're wired to each other — that the type builds a target the transport
// can use, that bytes off a real socket reach the driver, and that what the
// driver reports comes back out as the state the panel renders.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A FLEX-6600 as far as this test is concerned: it greets, and answers a
/// slice subscription with the status lines captured from the real radio.
class _FakeFlex {
  final ServerSocket _server;
  final commands = <String>[];
  Socket? _client;

  _FakeFlex(this._server) {
    _server.listen(
      (socket) {
        _client = socket;
        // A write to a socket the client already destroyed fails on `done`,
        // not at the `add` call, and an unhandled error there escapes into
        // the zone and fails the test.
        unawaited(socket.done.then((_) {}, onError: (Object _) {}));
        socket.add(utf8.encode('V1.4.0.0\nH5AC2F980\n'));
        socket.listen(
          (chunk) {
            for (final line in utf8.decode(chunk).split('\n')) {
              if (line.trim().isEmpty) continue;
              commands.add(line);
              if (line.contains('sub slice all')) {
                socket.add(utf8.encode(
                    'S5AC2F980|slice 0 in_use=1 RF_frequency=14.074000 client_handle=0x1C61D553 mode=DIGU wide=0\n'));
              }
            }
          },
          // The client destroys its socket on disconnect (as polo's did, and
          // as this transport does), so the peer sees a reset rather than a
          // clean FIN. A real radio shrugs that off; so must the fake, or an
          // ordinary disconnect fails the test with an unhandled error.
          onError: (Object _) {},
          cancelOnError: true,
        );
      },
      onError: (Object _) {},
    );
  }

  static Future<_FakeFlex> start() async =>
      _FakeFlex(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0));

  String get host => _server.address.address;
  int get port => _server.port;

  /// The radio being retuned at the front panel.
  void pushStatus({required String mhz, required String mode}) =>
      _client?.add(utf8.encode('S5AC2F980|slice 0 RF_frequency=$mhz mode=$mode\n'));

  Future<void> stop() async {
    _client?.destroy();
    await _server.close();
  }
}

Future<void> _settleUntil(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeFlex flex;
  late CatService cat;

  setUp(() async {
    flex = await _FakeFlex.start();
    SharedPreferences.setMockInitialValues({});
    // The real registry — FlexRadioTcpType over the real TcpTransport.
    cat = CatService(SettingsService(await SharedPreferences.getInstance()));
  });

  tearDown(() async {
    cat.dispose();
    await flex.stop();
  });

  test('connects to a FlexRadio over TCP and follows it', () async {
    final node = await cat.addNode(
      typeKey: 'flexradio-tcp',
      name: 'Left Radio',
      config: {'host': flex.host, 'port': flex.port},
    );

    await cat.connect(node.uuid);
    expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected);

    // The driver waits for the H line before subscribing, then Flex answers
    // with a full status refresh — which is what the panel shows.
    await _settleUntil(() => cat.stateFor(node.uuid).vfo.freqKHz != null);
    expect(cat.stateFor(node.uuid).vfo, const VfoReading(freqKHz: 14074, mode: 'DIGU'));
    expect(flex.commands.any((c) => c.contains('sub slice all')), isTrue);

    // The operator turns the knob.
    flex.pushStatus(mhz: '7.123450', mode: 'LSB');
    await _settleUntil(() => cat.stateFor(node.uuid).vfo.freqKHz != 14074);
    expect(cat.stateFor(node.uuid).vfo, const VfoReading(freqKHz: 7123.45, mode: 'LSB'));

    // Disconnecting says goodbye over the still-open socket before closing.
    await cat.disconnect(node.uuid);
    expect(cat.stateFor(node.uuid).status, EquipmentStatus.disconnected);
    await _settleUntil(() => flex.commands.any((c) => c.contains('unsub slice all')));
    expect(flex.commands.any((c) => c.contains('unsub slice all')), isTrue);
  });

  test('a radio that is not there reports an error instead of hanging', () async {
    // Bind and release a port so nothing is listening on it.
    final vacant = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = vacant.port;
    await vacant.close();

    final node = await cat.addNode(
      typeKey: 'flexradio-tcp',
      config: {'host': InternetAddress.loopbackIPv4.address, 'port': port},
    );

    await cat.connect(node.uuid);
    expect(cat.stateFor(node.uuid).status, EquipmentStatus.error);
    expect(cat.stateFor(node.uuid).error, isNotNull);
  });
}
