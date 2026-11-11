// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A radio's serial CAT carried over the network by a bridge that hands the
// port's bytes to a TCP socket as they are — ser2net in raw mode, a serial
// device server in its TCP-server mode, socat. The TCP transport under its
// own key and label: what is behind the socket is the radio's serial wire,
// not a network radio, and the editor files it with the derived pairings.
// docs/design/cat.md § Serial over TCP.

import 'dart:async';
import 'dart:convert';

import 'package:halo_i18n/halo_i18n.dart';

import '../transport.dart';
import 'serial_transport_config.dart' show supportedBaudRates;
import 'tcp_transport.dart';

/// How fast the bridge runs the radio's serial port — the same key, and the
/// same meaning, as the serial pairing's speed: the radio's CAT rate. Never
/// sent anywhere (the bridge has its own setting); a driver that paces by
/// baud reads it to pace for that wire, not for the network in front of it.
const serialTcpLinkBaudKey = 'baudRate';

/// The bridge's port: its own key, since the serial pairing beside it keeps
/// the port's NAME under `port`, and a radio's own network pairing keeps its
/// LAN port under `tcpPort` — a bridge has no standard port, so neither
/// value belongs in its box.
const serialTcpPortConfigKey = 'serialTcpPort';

/// How long the connection stays quiet after the bridge accepts it. A bridge
/// opens the radio's port only once a client connects and drops whatever
/// arrives meanwhile — and what a driver sends first is its one-shot setup
/// (a K3's `AI2;`, a K4's `K40;K31;`), which nothing sends again. Longer
/// than a bridge takes to open a local port; the radio's replies arrive
/// after it, never during.
const serialTcpSettle = Duration(milliseconds: 500);

/// Why a bridge hung up, as it said so: the last line it sent with anything
/// readable on it — a banner sent on every connect comes first, the reason
/// last — printable ASCII only, cut short. Null when it sent nothing
/// readable.
String? _bridgeWords(List<int> bytes) {
  final lines = latin1
      .decode(bytes)
      .split(RegExp(r'[\r\n]+'))
      .map((line) => line.replaceAll(RegExp(r'[^\x20-\x7E]+'), ' ').replaceAll(RegExp(' +'), ' ').trim());
  final text = lines.lastWhere((line) => line.isNotEmpty, orElse: () => '');
  if (text.isEmpty) return null;
  return text.length <= 80 ? text : '${text.substring(0, 79)}…';
}

class SerialTcpTransport extends TcpTransport {
  const SerialTcpTransport() : super(portConfigKey: serialTcpPortConfigKey);

  static const transportKey = 'serialTcp';

  @override
  String get key => transportKey;

  @override
  Set<String> get recognizedConfigKeys => const {'host', serialTcpPortConfigKey, serialTcpLinkBaudKey};

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => [
    ...super.configElements(overrides: overrides, restrictions: restrictions),
    if (!overrides.containsKey(serialTcpLinkBaudKey))
      {
        'type': 'field',
        'fieldType': 'select',
        'key': serialTcpLinkBaudKey,
        'label': t.settings.station.baudRate,
        'description': t.settings.station.serialTcpBaudRateDescription,
        'advanced': true,
        'options': [
          for (final rate in supportedBaudRates)
            if (restrictions[serialTcpLinkBaudKey] is! List || (restrictions[serialTcpLinkBaudKey] as List).contains(rate)) {'value': rate, 'label': '$rate'},
        ],
      },
  ];

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async {
    final connection = await super.connect(target, cancel: cancel);
    final hungUp = await Future.any<bool>([
      Future<bool>.delayed(serialTcpSettle, () => false),
      cancel.whenCancelled.then((_) => false),
      connection.closed.then((_) => true),
    ]);
    if (cancel.isCancelled) {
      await connection.close();
      throw const CatCancelledException();
    }
    if (hungUp) {
      // Nothing has read the connection yet, so what the bridge sent before
      // closing is still buffered behind its end. The fold relies on [data]
      // ending when [closed] completes, as the TCP connection's does; a
      // connection whose data outlived its close would hang here. Closed
      // after reading: the bridge's end is gone, but ours stays open until
      // destroyed.
      final sent = await connection.data.fold<List<int>>([], (all, chunk) => all..addAll(chunk));
      await connection.close();
      throw SerialTcpBridgeClosed(
        _bridgeWords(sent),
        how: switch (connection) {
          ExplainsClose(:final closeReason) => closeReason,
          _ => null,
        },
      );
    }
    return connection;
  }
}
