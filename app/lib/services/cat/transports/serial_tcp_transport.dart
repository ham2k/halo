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
    await Future.any([Future<void>.delayed(serialTcpSettle), cancel.whenCancelled]);
    if (cancel.isCancelled) {
      await connection.close();
      throw const CatCancelledException();
    }
    return connection;
  }
}
