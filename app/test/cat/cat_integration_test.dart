// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The whole chain with nothing faked but the radio: the real
// EquipmentRegistry, the real TCP transport over a real loopback socket,
// and the real FlexRadio, rigctld, flrig and GS-232 drivers, driven by
// CatService the way
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
    _server.listen((socket) {
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
              socket.add(utf8.encode('S5AC2F980|slice 0 in_use=1 RF_frequency=14.074000 client_handle=0x1C61D553 mode=DIGU wide=0\n'));
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
    }, onError: (Object _) {});
  }

  static Future<_FakeFlex> start() async => _FakeFlex(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0));

  String get host => _server.address.address;
  int get port => _server.port;

  /// The radio being retuned at the front panel.
  void pushStatus({required String mhz, required String mode}) => _client?.add(utf8.encode('S5AC2F980|slice 0 RF_frequency=$mhz mode=$mode\n'));

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
    _server.listen((socket) {
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
              socket.add(utf8.encode('get_level: RFPOWER_METER_WATTS\n$power\nRPRT 0\n'));
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
    }, onError: (Object _) {});
  }

  static Future<_FakeRigctld> start() async => _FakeRigctld(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0));

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

  /// The rig's PTT and meters, writable by the test the same way the dial
  /// is. flrig answers every method it has and faults the rest — a fake
  /// that answered only what the test expected to be asked would let a
  /// driver that stalls on an unanswered request pass.
  bool transmitting = false;
  String swr = '1.2';
  String powerMeter = '95';

  _FakeFlrig(this._server) {
    _server.listen((socket) {
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
            final length = int.parse(RegExp(r'content-length:\s*(\d+)', caseSensitive: false).firstMatch(pending.substring(0, headerEnd))!.group(1)!);
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
                socket.add(_response('<i4>$power</i4>'));
              case 'rig.set_power':
                power = RegExp(r'<double>([\d.]+)</double>').firstMatch(body)!.group(1)!;
                socket.add(_response('<i4>1</i4>'));
              case 'rig.get_ptt':
                socket.add(_response('<i4>${transmitting ? 1 : 0}</i4>'));
              case 'rig.get_pwrmeter':
                socket.add(_response(powerMeter));
              case 'rig.get_swrmeter':
                socket.add(_response(swr));
              default:
                socket.add(_fault(method));
            }
          }
        },
        onError: (Object _) {},
        cancelOnError: true,
      );
    }, onError: (Object _) {});
  }

  static List<int> _response(String inner) {
    final body =
        '<?xml version="1.0"?>\r\n'
        '<methodResponse><params><param>\r\n'
        '\t<value>$inner</value>\r\n'
        '</param></params></methodResponse>\r\n';
    return utf8.encode(
      'HTTP/1.1 200 OK\r\n'
      'Server: XMLRPC++ 0.8\r\n'
      'Content-Type: text/xml\r\n'
      'Content-length: ${body.length}\r\n'
      '\r\n'
      '$body',
    );
  }

  static List<int> _fault(String method) {
    final body =
        '<?xml version="1.0"?>\r\n'
        '<methodResponse><fault>\r\n'
        '\t<value><struct><member><name>faultCode</name><value><i4>-1</i4></value></member>'
        '<member><name>faultString</name><value>$method: unknown method name</value></member></struct></value>\r\n'
        '</fault></methodResponse>\r\n';
    return utf8.encode(
      'HTTP/1.1 200 OK\r\n'
      'Server: XMLRPC++ 0.8\r\n'
      'Content-Type: text/xml\r\n'
      'Content-length: ${body.length}\r\n'
      '\r\n'
      '$body',
    );
  }

  static Future<_FakeFlrig> start() async => _FakeFlrig(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0));

  String get host => _server.address.address;
  int get port => _server.port;

  Future<void> stop() => _server.close();
}

/// A GS-232A rotator interface on a serial-to-TCP bridge: answers `C2` in
/// the A dialect and nothing else, as the manual says it does, and jumps
/// straight to whatever heading it is told.
class _FakeGs232 {
  final ServerSocket _server;
  final commands = <String>[];
  var azimuth = 180;
  var elevation = 0;

  /// Off, it takes turn commands and stays put — a mast still on its way.
  var turns = true;

  _FakeGs232(this._server) {
    _server.listen((socket) {
      unawaited(socket.done.then((_) {}, onError: (Object _) {}));
      var pending = '';
      socket.listen((chunk) {
        pending += ascii.decode(chunk);
        while (pending.contains('\r')) {
          final end = pending.indexOf('\r');
          final command = pending.substring(0, end);
          pending = pending.substring(end + 1);
          commands.add(command);
          if (command == 'C2') {
            socket.add(ascii.encode('+0${'$azimuth'.padLeft(3, '0')}+0${'$elevation'.padLeft(3, '0')}\r\n'));
          } else if (RegExp(r'^W(\d{3}) (\d{3})$').firstMatch(command) case final turn? when turns) {
            azimuth = int.parse(turn.group(1)!);
            elevation = int.parse(turn.group(2)!);
          }
        }
      }, onError: (Object _) {});
    });
  }

  static Future<_FakeGs232> start() async => _FakeGs232(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0));

  String get host => _server.address.address;
  int get port => _server.port;

  Future<void> stop() => _server.close();
}

/// A rotctld daemon as `rotctld -m 1` (Hamlib 4.7.2) answers: bare `p`
/// lines, `RPRT n` to `P` and `S`, and limits in `\dump_state` — here a
/// backend that runs from -180 to 180.
class _FakeRotctld {
  final ServerSocket _server;
  final commands = <String>[];
  var azimuth = 0.0;
  var elevation = 0.0;

  _FakeRotctld(this._server) {
    _server.listen((socket) {
      unawaited(socket.done.then((_) {}, onError: (Object _) {}));
      var pending = '';
      socket.listen((chunk) {
        pending += ascii.decode(chunk);
        while (pending.contains('\n')) {
          final end = pending.indexOf('\n');
          final command = pending.substring(0, end);
          pending = pending.substring(end + 1);
          commands.add(command);
          if (command == 'p') socket.add(ascii.encode('${azimuth.toStringAsFixed(2)}\n${elevation.toStringAsFixed(2)}\n'));
          if (command == r'\dump_state') {
            socket.add(ascii.encode('1\n1\nmin_az=-180.000000\nmax_az=180.000000\nmin_el=0.000000\nmax_el=90.000000\nsouth_zero=0\nrot_type=AzEl\ndone\n'));
          }
          if (RegExp(r'^P (-?\d+) (-?\d+)$').firstMatch(command) case final turn?) {
            final az = double.parse(turn.group(1)!);
            final ok = az >= -180 && az <= 180;
            if (ok) {
              azimuth = az;
              elevation = double.parse(turn.group(2)!);
            }
            socket.add(ascii.encode(ok ? 'RPRT 0\n' : 'RPRT -21\n'));
          }
          if (command == 'S') socket.add(ascii.encode('RPRT 0\n'));
        }
      }, onError: (Object _) {});
    });
  }

  static Future<_FakeRotctld> start() async => _FakeRotctld(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0));

  int get port => _server.port;

  Future<void> stop() => _server.close();
}

/// PstRotator's UDP Control as its manual describes it: `<PST>…</PST>` in,
/// `AZ:`/`EL:` answers out to the port after its own.
class _FakePstRotator {
  final RawDatagramSocket _socket;
  final commands = <String>[];
  var azimuth = 180.0;
  var elevation = 0.0;

  _FakePstRotator(this._socket) {
    _socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = _socket.receive();
      if (datagram == null) return;
      final message = ascii.decode(datagram.data);
      commands.add(message);
      void answer(String text) => _socket.send(ascii.encode(text), datagram.address, port + 1);
      if (message == '<PST>AZ?</PST>') answer('AZ:${azimuth.toStringAsFixed(1)}\r');
      if (message == '<PST>EL?</PST>') answer('EL:${elevation.toStringAsFixed(1)}\r');
      if (RegExp(r'<AZIMUTH>(\d+)</AZIMUTH>').firstMatch(message) case final turn?) azimuth = double.parse(turn.group(1)!);
      if (RegExp(r'<ELEVATION>(-?\d+)</ELEVATION>').firstMatch(message) case final turn?) elevation = double.parse(turn.group(1)!);
    });
  }

  /// On a port whose next one is free, since that is where the node under
  /// test has to listen.
  static Future<_FakePstRotator> start() async {
    while (true) {
      final socket = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      try {
        (await RawDatagramSocket.bind(InternetAddress.anyIPv4, socket.port + 1, reuseAddress: false)).close();
        // A closed socket's port is released by the IO service, a moment
        // after `close` returns.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return _FakePstRotator(socket);
      } on SocketException {
        socket.close();
      }
    }
  }

  int get port => _socket.port;

  void stop() => _socket.close();
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
    final node = await cat.addNode(typeKey: 'flexradio-tcp', name: 'Left Radio', config: {'host': flex.host, 'port': flex.port});

    await cat.connect(node.uuid);
    expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected);

    // The driver waits for the H line before subscribing, then Flex answers
    // with a full status refresh — which is what the panel shows.
    await _settleUntil(() => cat.stateFor(node.uuid).vfo.freqKHz != null);
    expect(cat.stateFor(node.uuid).vfo, const VfoReading(freqKHz: 14074, mode: 'DATA-USB'));
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
      final node = await cat.addNode(typeKey: 'rigctld-tcp', name: 'Shack Daemon', config: {'host': rig.host, 'port': rig.port});

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
      await _settleUntil(() => cat.stateFor(node.uuid).vfo == const VfoReading(freqKHz: 7123.45, mode: 'LSB'), tries: 2 * kPollSlow.inMilliseconds ~/ 10);
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
      final node = await cat.addNode(typeKey: 'flrig-tcp', name: 'Shack flrig', config: {'host': rig.host, 'port': rig.port});

      await cat.connect(node.uuid);
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected);

      // startUpdates asks immediately — one request at a time, answers
      // correlated by order.
      await _settleUntil(() => cat.stateFor(node.uuid).vfo.mode != null);
      expect(cat.stateFor(node.uuid).vfo, const VfoReading(freqKHz: 14070, mode: 'USB'));

      // The operator turns the knobs. Nothing is pushed — the changes ride
      // in on the next poll, power included: flrig types that answer, and
      // it reaches the app only if the parse reads typed values.
      rig.frequency = '7123450';
      rig.mode = 'LSB-D';
      rig.power = '50';
      // Settle on EVERY field — same in-flight-mode race as the rigctld
      // test above; flrig's one-outstanding queue makes the gap between
      // the answers even wider.
      await _settleUntil(
        () => cat.stateFor(node.uuid).vfo == const VfoReading(freqKHz: 7123.45, mode: 'DATA-LSB') && cat.stateFor(node.uuid).power == 50,
        tries: 2 * kPollSlow.inMilliseconds ~/ 10,
      );
      expect(cat.stateFor(node.uuid).vfo, const VfoReading(freqKHz: 7123.45, mode: 'DATA-LSB'));
      expect(cat.stateFor(node.uuid).power, 50);

      await cat.disconnect(node.uuid);
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.disconnected);
    } finally {
      await rig.stop();
    }
  });

  test('connects to a GS-232A over TCP, reads where it points and turns it', () async {
    // The TCP port is stored under `tcpPort`, not `port` — the serial
    // variant's `port` is its device name. A target built from the wrong
    // key connects to port 0 and this never gets past connecting.
    final rotator = await _FakeGs232.start();
    try {
      final node = await cat.addNode(typeKey: 'gs232a-tcp', name: 'Tower', config: {'host': rotator.host, 'tcpPort': rotator.port, 'rotatorAxes': 'azel'});
      await cat.connect(node.uuid);
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected);

      await _settleUntil(() => cat.stateFor(node.uuid).rotator != null);
      expect(cat.stateFor(node.uuid).rotator, const RotatorPosition(azimuth: 180, elevation: 0));

      cat.rotateTo(node.uuid, azimuth: 45, elevation: 30);
      await _settleUntil(() => rotator.commands.contains('W045 030'));
      expect(rotator.commands, contains('W045 030'));
      // The new heading arrives on a later poll, never assumed from the
      // command: a controller at its end stop does not get there.
      await _settleUntil(() => cat.stateFor(node.uuid).rotator == const RotatorPosition(azimuth: 45, elevation: 30), tries: 300);
      expect(cat.stateFor(node.uuid).rotator, const RotatorPosition(azimuth: 45, elevation: 30));

      cat.stopRotator(node.uuid);
      await _settleUntil(() => rotator.commands.contains('S'));
      expect(rotator.commands, contains('S'));

      await cat.disconnect(node.uuid);
      expect(cat.stateFor(node.uuid).rotator, isNull, reason: 'a heading is never carried past its connection');
    } finally {
      await rotator.stop();
    }
  });

  // The map draws a target line for as long as this holds one. Dropped too
  // early, a turn in progress reads as done; never dropped, a mast that got
  // there still shows a turn, and so does one later moved at the
  // controller's own knob.
  test('a rotator holds its target until it gets there or is stopped', () async {
    final rotator = await _FakeGs232.start()
      ..turns = false;
    try {
      final node = await cat.addNode(typeKey: 'gs232a-tcp', name: 'Tower', config: {'host': rotator.host, 'tcpPort': rotator.port, 'rotatorAxes': 'azel'});
      await cat.connect(node.uuid);
      await _settleUntil(() => cat.stateFor(node.uuid).rotator != null);

      cat.rotateTo(node.uuid, azimuth: 300, elevation: 0);
      expect(cat.stateFor(node.uuid).rotatorTarget, const RotatorPosition(azimuth: 300, elevation: 0));
      final polls = rotator.commands.where((c) => c == 'C2').length;
      await _settleUntil(() => rotator.commands.where((c) => c == 'C2').length > polls + 1, tries: 300);
      expect(cat.stateFor(node.uuid).rotatorTarget, const RotatorPosition(azimuth: 300, elevation: 0), reason: 'still at 180, still on its way');

      // Short of the target, as a controller coasting to a stop leaves it.
      rotator.azimuth = 298;
      await _settleUntil(() => cat.stateFor(node.uuid).rotator?.azimuth == 298, tries: 300);
      expect(cat.stateFor(node.uuid).rotatorTarget, isNull);

      rotator.azimuth = 90;
      await _settleUntil(() => cat.stateFor(node.uuid).rotator?.azimuth == 90, tries: 300);
      expect(cat.stateFor(node.uuid).rotatorTarget, isNull, reason: 'turned at the knob, not by the app');

      cat.rotateTo(node.uuid, azimuth: 0, elevation: 0);
      cat.stopRotator(node.uuid);
      expect(cat.stateFor(node.uuid).rotatorTarget, isNull);

      cat.rotateTo(node.uuid, azimuth: 270, elevation: 0);
      await cat.disconnect(node.uuid);
      expect(cat.stateFor(node.uuid).rotatorTarget, isNull, reason: 'a turn is never carried past its connection');
    } finally {
      await rotator.stop();
    }
  });

  // Judged on azimuth alone, a turn that only raises the elevation is "there"
  // at the first poll, and the pane drops its Stop while the mast still
  // moves.
  test('a turn in elevation alone holds its target until the elevation gets there', () async {
    final rotator = await _FakeGs232.start()
      ..turns = false;
    try {
      final node = await cat.addNode(typeKey: 'gs232a-tcp', name: 'Tower', config: {'host': rotator.host, 'tcpPort': rotator.port, 'rotatorAxes': 'azel'});
      await cat.connect(node.uuid);
      await _settleUntil(() => cat.stateFor(node.uuid).rotator != null);

      cat.rotateTo(node.uuid, azimuth: 180, elevation: 45);
      final polls = rotator.commands.where((c) => c == 'C2').length;
      await _settleUntil(() => rotator.commands.where((c) => c == 'C2').length > polls + 1, tries: 300);
      expect(cat.stateFor(node.uuid).rotatorTarget, const RotatorPosition(azimuth: 180, elevation: 45));

      rotator.elevation = 44;
      await _settleUntil(() => cat.stateFor(node.uuid).rotator?.elevation == 44, tries: 300);
      expect(cat.stateFor(node.uuid).rotatorTarget, isNull);
    } finally {
      await rotator.stop();
    }
  });

  // A GS-232 says nothing when it is stopped at its own front panel, or when
  // the mast meets a stop short of the node's limits: without this the map
  // shows a turn in progress until someone presses Stop in the app. Too
  // eager, and a mast still releasing its brake loses its target.
  test('a turn that stands still short of its target lets the target go', () async {
    final rotator = await _FakeGs232.start()
      ..turns = false;
    try {
      final node = await cat.addNode(
        typeKey: 'gs232a-tcp',
        name: 'Tower',
        config: {'host': rotator.host, 'tcpPort': rotator.port, 'rotatorAxes': 'azel', 'pollInterval': 500},
      );
      await cat.connect(node.uuid);
      await _settleUntil(() => cat.stateFor(node.uuid).rotator != null);

      cat.rotateTo(node.uuid, azimuth: 300, elevation: 0);
      final polls = rotator.commands.where((c) => c == 'C2').length;
      await _settleUntil(() => cat.stateFor(node.uuid).rotatorTarget == null, tries: 600);
      expect(cat.stateFor(node.uuid).rotatorTarget, isNull);
      expect(rotator.commands.where((c) => c == 'C2').length - polls, greaterThanOrEqualTo(rotatorStalledAfterReadings));
    } finally {
      await rotator.stop();
    }
  });

  test('connects to rotctld, reads where it points and turns it within the range the daemon reports', () async {
    final rotctld = await _FakeRotctld.start();
    try {
      final node = await cat.addNode(typeKey: 'rotctld-tcp', name: 'Tower', config: {'host': '127.0.0.1', 'port': rotctld.port, 'rotatorAxes': 'azel'});
      await cat.connect(node.uuid);
      await _settleUntil(() => cat.stateFor(node.uuid).rotator != null, tries: 300);
      expect(cat.stateFor(node.uuid).rotator, const RotatorPosition(azimuth: 0, elevation: 0));

      // Past 180 on this backend: sent as 270 it is refused, and the mast
      // never turns.
      cat.rotateTo(node.uuid, azimuth: 270, elevation: 20);
      await _settleUntil(() => cat.stateFor(node.uuid).rotator == const RotatorPosition(azimuth: 270, elevation: 20), tries: 300);
      expect(rotctld.commands, contains('P -90 20'));
      expect(cat.stateFor(node.uuid).rotator, const RotatorPosition(azimuth: 270, elevation: 20));
      expect(cat.stateFor(node.uuid).problem, isNull);

      cat.stopRotator(node.uuid);
      await _settleUntil(() => rotctld.commands.contains('S'));
      expect(rotctld.commands, contains('S'));
      await cat.disconnect(node.uuid);
    } finally {
      await rotctld.stop();
    }
  });

  test('connects to PstRotator over UDP, reads where it points and turns it', () async {
    final pst = await _FakePstRotator.start();
    try {
      final node = await cat.addNode(typeKey: 'pstrotator-udp', name: 'Tower', config: {'host': '127.0.0.1', 'udpPort': pst.port, 'rotatorAxes': 'azel'});
      await cat.connect(node.uuid);
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected);
      await _settleUntil(() => cat.stateFor(node.uuid).rotator != null, tries: 300);
      expect(cat.stateFor(node.uuid).rotator, const RotatorPosition(azimuth: 180, elevation: 0));

      cat.rotateTo(node.uuid, azimuth: 45, elevation: 30);
      const turn = '<PST><AZIMUTH>45</AZIMUTH><ELEVATION>30</ELEVATION></PST>';
      await _settleUntil(() => pst.commands.contains(turn));
      expect(pst.commands, contains(turn));
      await _settleUntil(() => cat.stateFor(node.uuid).rotator == const RotatorPosition(azimuth: 45, elevation: 30), tries: 300);
      expect(cat.stateFor(node.uuid).rotator, const RotatorPosition(azimuth: 45, elevation: 30));
      expect(cat.stateFor(node.uuid).rotatorTarget, isNull, reason: 'there, on both axes');

      cat.stopRotator(node.uuid);
      await _settleUntil(() => pst.commands.contains('<PST><STOP>1</STOP></PST>'));
      expect(pst.commands, contains('<PST><STOP>1</STOP></PST>'));
      await cat.disconnect(node.uuid);
    } finally {
      pst.stop();
    }
  });

  // UDP has no handshake, so the reply port is the one thing a connect can
  // find wrong. Shared, a second listener there takes some of the answers
  // and the heading stutters with nothing to say why.
  test('a PstRotator reply port something else holds is an error, not a node that never hears', () async {
    final holder = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0, reuseAddress: false);
    try {
      final node = await cat.addNode(typeKey: 'pstrotator-udp', name: 'Tower', config: {'host': '127.0.0.1', 'udpPort': holder.port - 1});
      await cat.connect(node.uuid);
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.error);
      expect(cat.stateFor(node.uuid).error, contains('${holder.port}'), reason: 'the port to free, not a network that cannot reach the host');
      await cat.disconnect(node.uuid);
    } finally {
      holder.close();
    }
  });

  test('a radio that is not there reports an error instead of hanging', () async {
    // Bind and release a port so nothing is listening on it.
    final vacant = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = vacant.port;
    await vacant.close();

    final node = await cat.addNode(typeKey: 'flexradio-tcp', config: {'host': InternetAddress.loopbackIPv4.address, 'port': port});

    await cat.connect(node.uuid);
    expect(cat.stateFor(node.uuid).status, EquipmentStatus.error);
    expect(cat.stateFor(node.uuid).error, isNotNull);
  });
}
