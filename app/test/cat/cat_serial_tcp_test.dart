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
}
