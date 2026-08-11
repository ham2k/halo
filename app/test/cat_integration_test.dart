// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The whole chain with nothing faked but the radio: the real
// EquipmentRegistry, the real TCP transport over a real loopback socket,
// and the real FlexRadio and rigctld drivers, driven by CatService the way
// the Station Configuration panel drives it.
//
// The unit tests each prove one layer; this is the only tier that proves
// they're wired to each other — that the type builds a target the transport
// can use, that bytes off a real socket reach the driver, and that what the
// driver reports comes back out as the state the panel renders.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/adaptive_poller.dart';
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

/// rigctld is poll-driven: a change at the daemon reaches the app on the
/// NEXT poll, up to [kPollSlow] away — so its waits need a budget past the
/// slow interval, where FlexRadio's pushes land within the default.
Future<void> _settleUntil(bool Function() done, {int tries = 200}) async {
  for (var i = 0; i < tries && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// A rigctld daemon as far as this test is concerned. The dialogue is
/// captured from a real `rigctld -m 1` (Hamlib 4.7.2): extended-response
/// reads answer with labeled lines, plain writes answer `RPRT 0`.
class _FakeRigctld {
  final ServerSocket _server;
  final commands = <String>[];

  /// The rig's state, in the daemon's own strings — writable by the test
  /// (the operator at the radio) and by the client's `F`/`M` commands.
  String frequency = '145000000';
  String mode = 'FM';
  String power = '50';

  _FakeRigctld(this._server) {
    _server.listen(
      (socket) {
        unawaited(socket.done.then((_) {}, onError: (Object _) {}));
        socket.listen(
          (chunk) {
            for (final line in utf8.decode(chunk).split('\n')) {
              final command = line.trim();
              if (command.isEmpty) continue;
              commands.add(command);
              if (command == '+\\chk_vfo') {
                socket.add(utf8.encode('ChkVFO: 0\n'));
              } else if (command == '+f') {
                socket.add(utf8.encode('get_freq:\nFrequency: $frequency\nRPRT 0\n'));
              } else if (command == '+m') {
                socket.add(utf8.encode('get_mode:\nMode: $mode\nPassband: 15000\nRPRT 0\n'));
              } else if (command.startsWith('F ')) {
                frequency = command.substring(2).trim();
                socket.add(utf8.encode('RPRT 0\n'));
              } else if (command.startsWith('M ')) {
                mode = command.split(' ')[1];
                socket.add(utf8.encode('RPRT 0\n'));
              } else if (command == '+l RFPOWER_METER_WATTS') {
                socket.add(utf8.encode('get_level:\nRFPOWER_METER_WATTS: $power\nRPRT 0\n'));
              } else if (command.startsWith('L RFPOWER ')) {
                final fraction = double.parse(command.substring('L RFPOWER '.length).trim());
                power = (fraction * 100).round().toString();
                socket.add(utf8.encode('RPRT 0\n'));
              }
            }
          },
          onError: (Object _) {},
          cancelOnError: true,
        );
      },
      onError: (Object _) {},
    );
  }

  static Future<_FakeRigctld> start() async =>
      _FakeRigctld(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0));

  String get host => _server.address.address;
  int get port => _server.port;

  Future<void> stop() => _server.close();
}

/// An flrig instance as far as this test is concerned. The dialogue is
/// captured from a real flrig 2.0.12: HTTP/1.1 keep-alive, XMLRPC++ 0.8
/// headers with a lowercase `Content-length`, one response per request.
class _FakeFlrig {
  final ServerSocket _server;
  final methods = <String>[];

  /// The rig's state, in flrig's own strings — writable by the test (the
  /// operator at the radio) and by the client's set_* calls.
  String frequency = '14070000';
  String mode = 'USB';
  String power = '100';

  _FakeFlrig(this._server) {
    _server.listen(
      (socket) {
        unawaited(socket.done.then((_) {}, onError: (Object _) {}));
        var pending = '';
        socket.listen(
          (chunk) {
            pending += utf8.decode(chunk);
            // One request per response, so requests are parsed with the
            // same header-then-length walk the driver uses for responses.
            while (true) {
              final headerEnd = pending.indexOf('\r\n\r\n');
              if (headerEnd < 0) return;
              final length = int.parse(
                  RegExp(r'content-length:\s*(\d+)', caseSensitive: false).firstMatch(pending.substring(0, headerEnd))!.group(1)!);
              if (pending.length < headerEnd + 4 + length) return;
              final body = pending.substring(headerEnd + 4, headerEnd + 4 + length);
              pending = pending.substring(headerEnd + 4 + length);
              final method = RegExp(r'<methodName>([^<]+)</methodName>').firstMatch(body)!.group(1)!;
              methods.add(method);
              switch (method) {
                case 'rig.get_vfo':
                  socket.add(_response(frequency));
                case 'rig.get_mode':
                  socket.add(_response(mode));
                case 'rig.set_frequency':
                  frequency = RegExp(r'<double>([\d.]+)</double>').firstMatch(body)!.group(1)!;
                  socket.add(_response('<i4>1</i4>'));
                case 'rig.set_mode':
                  mode = RegExp(r'<param><value>([^<]+)</value></param>').firstMatch(body)!.group(1)!;
                  socket.add(_response(''));
                case 'rig.get_power':
                  socket.add(_response(power));
                case 'rig.set_power':
                  power = RegExp(r'<double>([\d.]+)</double>').firstMatch(body)!.group(1)!;
                  socket.add(_response('<i4>1</i4>'));
              }
            }
          },
          onError: (Object _) {},
          cancelOnError: true,
        );
      },
      onError: (Object _) {},
    );
  }

  static List<int> _response(String inner) {
    final body = '<?xml version="1.0"?>\r\n'
        '<methodResponse><params><param>\r\n'
        '\t<value>$inner</value>\r\n'
        '</param></params></methodResponse>\r\n';
    return utf8.encode('HTTP/1.1 200 OK\r\n'
        'Server: XMLRPC++ 0.8\r\n'
        'Content-Type: text/xml\r\n'
        'Content-length: ${body.length}\r\n'
        '\r\n'
        '$body');
  }

  static Future<_FakeFlrig> start() async =>
      _FakeFlrig(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0));

  String get host => _server.address.address;
  int get port => _server.port;

  Future<void> stop() => _server.close();
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

  test('connects to a rigctld daemon over TCP and follows it by polling', () async {
    final rig = await _FakeRigctld.start();
    try {
      final node = await cat.addNode(
        typeKey: 'rigctld-tcp',
        name: 'Shack Daemon',
        config: {'host': rig.host, 'port': rig.port},
      );

      await cat.connect(node.uuid);
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected);

      // startUpdates asks immediately; the first answers become the state
      // the panel shows.
      await _settleUntil(() => cat.stateFor(node.uuid).vfo.mode != null);
      expect(cat.stateFor(node.uuid).vfo, const VfoReading(freqKHz: 145000, mode: 'FM'));

      // The operator turns the knob. Nothing is pushed — the change rides
      // in on the next poll, up to a slow interval away.
      rig.frequency = '7123450';
      rig.mode = 'LSB';
      // Settle on BOTH fields: the daemon answers frequency and mode as
      // separate writes, so waiting on frequency alone races the mode
      // answer still in flight and asserts against a stale reading.
      await _settleUntil(
          () => cat.stateFor(node.uuid).vfo == const VfoReading(freqKHz: 7123.45, mode: 'LSB'),
          tries: 2 * kPollSlow.inMilliseconds ~/ 10);
      expect(cat.stateFor(node.uuid).vfo, const VfoReading(freqKHz: 7123.45, mode: 'LSB'));

      await cat.disconnect(node.uuid);
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.disconnected);
    } finally {
      await rig.stop();
    }
  });

  test('connects to an flrig instance over TCP and follows it by polling', () async {
    final rig = await _FakeFlrig.start();
    try {
      final node = await cat.addNode(
        typeKey: 'flrig-tcp',
        name: 'Shack flrig',
        config: {'host': rig.host, 'port': rig.port},
      );

      await cat.connect(node.uuid);
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected);

      // startUpdates asks immediately — one request at a time, answers
      // correlated by order.
      await _settleUntil(() => cat.stateFor(node.uuid).vfo.mode != null);
      expect(cat.stateFor(node.uuid).vfo, const VfoReading(freqKHz: 14070, mode: 'USB'));

      // The operator turns the knob. Nothing is pushed — the change rides
      // in on the next poll.
      rig.frequency = '7123450';
      rig.mode = 'LSB-D';
      // Settle on BOTH fields — same in-flight-mode race as the rigctld
      // test above; flrig's one-outstanding queue makes the gap between
      // the two answers even wider.
      await _settleUntil(
          () => cat.stateFor(node.uuid).vfo == const VfoReading(freqKHz: 7123.45, mode: 'DATA-LSB'),
          tries: 2 * kPollSlow.inMilliseconds ~/ 10);
      expect(cat.stateFor(node.uuid).vfo, const VfoReading(freqKHz: 7123.45, mode: 'DATA-LSB'));

      await cat.disconnect(node.uuid);
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.disconnected);
    } finally {
      await rig.stop();
    }
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
