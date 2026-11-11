// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Serial over TCP: a radio's serial CAT through a network bridge such as
// ser2net in raw mode (docs/design/cat.md § Serial over TCP).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transports/serial_tcp_transport.dart';
import 'package:ham2k_logger/services/cat/transports/serial_transport.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A K3 behind ser2net in raw mode, answering with what the real one at a
/// remote station answered over its bridge. Like the bridge, it loses what
/// arrives while it is still opening the radio's port. Records every
/// command it is sent once open, writes included.
class _FakeBridgedK3 {
  final ServerSocket _server;
  final commands = <String>[];

  /// Bytes lost while the port was opening.
  var dropped = 0;

  /// How long after a client connects the bridge drops what it is sent.
  final Duration opening;

  _FakeBridgedK3(this._server, {required this.opening}) {
    _server.listen((socket) {
      unawaited(socket.done.then((_) {}, onError: (Object _) {}));
      final openedAt = DateTime.timestamp().add(opening);
      var pending = '';
      socket.listen((chunk) {
        if (DateTime.timestamp().isBefore(openedAt)) {
          dropped += chunk.length;
          return;
        }
        pending += ascii.decode(chunk);
        while (pending.contains(';')) {
          final end = pending.indexOf(';');
          final command = pending.substring(0, end);
          pending = pending.substring(end + 1);
          commands.add('$command;');
          final reply = switch (command) {
            'FA' => 'FA00001831420;',
            'MD' => 'MD3;',
            'IF' => 'IF00001831420     +000000 0003000011 ;',
            'PC' => 'PC100;',
            _ => null,
          };
          if (reply != null) socket.add(ascii.encode(reply));
        }
      }, onError: (Object _) {});
    });
  }

  static Future<_FakeBridgedK3> start({Duration opening = const Duration(milliseconds: 300)}) async =>
      _FakeBridgedK3(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0), opening: opening);

  String get host => _server.address.address;
  int get port => _server.port;

  Future<void> stop() => _server.close();
}

/// A bridge that accepts, says [words] if given, as ser2net does, and hangs
/// up [after] the accept: at once when another program holds its radio port.
class _HangUpBridge {
  final ServerSocket server;

  /// Completes when the app's end of the connection is closed too.
  final clientClosed = Completer<void>();

  _HangUpBridge._(this.server, {String? words, required Duration after}) {
    server.listen((socket) {
      socket.listen(
        (_) {},
        onError: (Object _) {},
        onDone: () {
          if (!clientClosed.isCompleted) clientClosed.complete();
        },
      );
      if (words != null) socket.write(words);
      unawaited(Future<void>.delayed(after).then((_) => socket.close()).then((_) {}, onError: (Object _) {}));
    });
  }

  static Future<_HangUpBridge> start({String? words, Duration after = Duration.zero}) async =>
      _HangUpBridge._(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0), words: words, after: after);
}

Future<void> _settleUntil(bool Function() done, {int tries = 500}) async {
  for (var i = 0; i < tries && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final registry = EquipmentRegistry();

  group('the pairing every serial radio derives', () {
    test("is the radio's own driver, paced for the wire behind the bridge, asking only where the bridge is and how fast it runs", () {
      // The traps: a pairing whose speed the driver never sees — dropped as
      // a network pairing's is — so it paces a 38400 wire like a LAN radio,
      // fast telemetry and an Icom's scope included; a speed pinned to the
      // catalogue's when the bridge runs another; or a pairing that asks for
      // a serial port and RTS/DTR the bridge holds instead.
      final type = registry.typeFor('elecraft-generic-serial-tcp')!;
      expect(type.model.key, 'elecraft-generic');
      expect(type.driver, isA<KenwoodDriver>());
      expect(type.transport, isA<SerialTcpTransport>());
      expect(type.defaultConfig[serialTcpLinkBaudKey], 38400, reason: "prefilled with the radio's own serial default");
      expect(type.driverConfig(const {serialTcpLinkBaudKey: 9600})[serialTcpLinkBaudKey], 9600, reason: "the operator's speed reaches the driver");
      expect(type.overrides[KenwoodDriver.passbandDialectKey], 'elecraft', reason: "the serial pairing's pins come along");
      final elements = {for (final element in type.configElements()) element['key']: element};
      expect(elements.keys, containsAll(['host', serialTcpPortConfigKey, serialTcpLinkBaudKey]));
      expect(elements[serialTcpLinkBaudKey]!['advanced'], isTrue, reason: 'set once to match the bridge, then left alone');
      expect(elements.keys, isNot(anyOf(contains('port'), contains(serialRtsHighConfigKey), contains(serialDtrHighConfigKey))));
    });

    test("keeps its port apart from a radio's own network port", () {
      // The trap: a K4's LAN port (9200) prefilled into the bridge's box,
      // since both pairings would otherwise store under `tcpPort`.
      final bridged = {for (final element in registry.typeFor('k4-serial-tcp')!.configElements()) element['key']};
      final lan = registry.typeFor('k4-tcp')!.transport.recognizedConfigKeys;
      expect(bridged.intersection(lan), {'host'}, reason: 'the address may carry over; the port may not');
    });
  });

  group('on iOS', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('does not bring a serial-only radio into the catalogue, and stays for a node already on it', () {
      // The trap: every serial rig listed on an iPhone because a bridge
      // could reach it — or a node on a bridge stranded with no pairing.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final ft891 = registry.typeFor('ft891-serial')!.model;
      expect(registry.offeredVariants(ft891, tx500Experiment: false), isEmpty);
      final saved = registry.typeFor('ft891-serial-tcp')!;
      expect(registry.offeredVariants(ft891, tx500Experiment: false, current: saved), contains(saved));
    });
  });

  group('connected to a K3 behind a raw bridge', () {
    late _FakeBridgedK3 k3;
    late CatService cat;

    setUp(() async {
      k3 = await _FakeBridgedK3.start();
      SharedPreferences.setMockInitialValues({});
      cat = CatService(SettingsService(await SharedPreferences.getInstance()));
    });

    tearDown(() async {
      cat.dispose();
      await k3.stop();
    });

    test("waits for the bridge to open the port, follows the radio, and leaves it as it found it", () async {
      // The traps: a session that speaks while the bridge is still opening
      // the port, losing its one-shot setup (a K3's AI2, a K4's K31) for the
      // whole session; one whose parting AI0 dies in the socket's close,
      // leaving the radio chattering at whoever connects next; and one that
      // changes anything else on a radio at a remote station.
      final node = await cat.addNode(
        typeKey: 'elecraft-generic-serial-tcp',
        name: 'Remote K3',
        config: {'host': k3.host, serialTcpPortConfigKey: k3.port, serialTcpLinkBaudKey: 38400},
      );
      await cat.connect(node.uuid);
      // Both fields: frequency and mode answer separately.
      await _settleUntil(() => cat.stateFor(node.uuid).vfo == const VfoReading(freqKHz: 1831.42, mode: 'CW'));
      expect(cat.stateFor(node.uuid).vfo, const VfoReading(freqKHz: 1831.42, mode: 'CW'));
      expect(k3.dropped, 0, reason: 'nothing sent while the bridge was opening the port');

      await cat.disconnect(node.uuid);
      await _settleUntil(() => k3.commands.contains('AI0;'));
      expect(k3.commands.first, 'AI2;');
      expect(k3.commands.last, 'AI0;');
      for (final command in k3.commands.sublist(1, k3.commands.length - 1)) {
        expect(command, matches(RegExp(r'^[A-Z]{2}[$]?;$')), reason: 'a read, not a write');
      }
    });
  });

  group('a bridge another program holds', () {
    late CatService cat;
    late _HangUpBridge bridge;
    late List<(String, Map<String, Object?>)> tracked;
    final seen = <EquipmentStatus>[];

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tracked = [];
      cat = CatService(SettingsService(await SharedPreferences.getInstance()), onTrack: (event, [props = const {}]) => tracked.add((event, props)));
      seen.clear();
    });

    tearDown(() async {
      cat.dispose();
      await bridge.server.close();
    });

    Future<EquipmentState> connectThrough(_HangUpBridge through) async {
      bridge = through;
      final node = await cat.addNode(
        typeKey: 'elecraft-generic-serial-tcp',
        name: 'Remote K3',
        config: {'host': through.server.address.address, serialTcpPortConfigKey: through.server.port, serialTcpLinkBaudKey: 38400},
      );
      cat.addListener(() => seen.add(cat.stateFor(node.uuid).status));
      await cat.connect(node.uuid);
      return cat.stateFor(node.uuid);
    }

    Iterable<Object?> failureReasons() => tracked.where((e) => e.$1 == 'radio_connect_failed').map((e) => e.$2['reason']);

    test("fails the connect with the bridge's own words, never showing it connected, and lets go of the socket", () async {
      // The traps: a hang-up that reads as Connected and then a bare
      // Disconnected, sending the operator to check a cable that is fine;
      // the bridge's reason, the one thing naming the cause, dropped or
      // buried behind the banner it sends every client; and
      // the app's end left half-open, one more for every retry while the
      // port stays busy.
      final state = await connectThrough(await _HangUpBridge.start(words: 'Welcome to the station bridge\r\nPort already in use\r\n'));
      expect(state.status, EquipmentStatus.error);
      expect(state.error, t.settings.station.connectFailedBridgeSaid(said: 'Port already in use'));
      expect(seen, isNot(contains(EquipmentStatus.connected)));
      expect(failureReasons(), ['bridge_closed']);
      expect(state.errorDetail, contains('the other end closed the connection'), reason: 'a clean hang-up, told apart from a reset in the path');
      await bridge.clientClosed.future.timeout(const Duration(seconds: 2));
    });

    test('says the bridge hung up when it says nothing itself', () async {
      final state = await connectThrough(await _HangUpBridge.start());
      expect(state.status, EquipmentStatus.error);
      expect(state.error, t.settings.station.connectFailedBridgeClosed);
      expect(seen, isNot(contains(EquipmentStatus.connected)));
      expect(failureReasons(), ['bridge_closed']);
    });

    test("quotes only what an operator can read of the bridge's line, cut to fit the row", () async {
      // The trap: a bridge relaying the radio's binary CAT, or a runaway
      // line, before it hangs up, landing control bytes and a wall of text
      // on the equipment row.
      final state = await connectThrough(await _HangUpBridge.start(words: 'busy\x07\x00 port ${'x' * 100}\r\n'));
      expect(state.error, t.settings.station.connectFailedBridgeSaid(said: '${'busy port ${'x' * 100}'.substring(0, 79)}…'));
    });

    test('takes a close after the settle window as an ordinary drop', () async {
      // The trap: a radio that answered and then went away, filed as a busy
      // port and sending the operator after a program that is not there.
      final state = await connectThrough(await _HangUpBridge.start(after: serialTcpSettle * 2));
      expect(state.status, EquipmentStatus.connected);
      await _settleUntil(() => seen.contains(EquipmentStatus.disconnected));
      expect(cat.stateFor(cat.nodes.single.uuid).error, isNull);
      expect(failureReasons(), isEmpty);
    });
  });
}
