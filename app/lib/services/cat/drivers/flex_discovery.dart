// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Finding a FlexRadio on the network: the announcement it broadcasts, read
// into what the Add Equipment dialog offers.

import 'package:flutter/foundation.dart' show immutable;

import '../discovery.dart';
import '../transports/udp_broadcast.dart';
import 'flexradio_driver.dart' show FlexRadioDriver;

/// A FlexRadio announces itself over UDP broadcast on its default port —
/// found automatically on the same subnet, and typed in manually otherwise
/// (behind a router that doesn't forward broadcasts, or on another subnet).
///
/// A pairing (an [EquipmentType]) wires this in as its `discoverer` rather
/// than the driver implementing [EquipmentDiscoverer] itself: discovery is
/// protocol knowledge tied to one specific transport (this radio's
/// broadcast, not a generic "any FlexRadio-driver pairing" capability).
class FlexRadioDiscoverer implements EquipmentDiscoverer {
  final String typeKey;

  const FlexRadioDiscoverer({required this.typeKey});

  @override
  Stream<DiscoveredEquipment> discover() => udpBroadcastDatagrams(port: FlexRadioDriver.defaultPort)
      .map(parseFlexDiscovery)
      .where((found) => found != null)
      .map(
        (found) => DiscoveredEquipment(
          typeKey: typeKey,
          // Serial when the radio offers one, so a radio that moves to a
          // new address updates its entry instead of appearing twice.
          id: found!.serial ?? '${found.host}:${found.port}',
          name: found.nickname ?? found.model,
          detail: [found.model, if (found.version != null) 'v${found.version}', found.host].join(' · '),
          config: {'host': found.host, 'port': found.port},
        ),
      );
}

/// What a FlexRadio says about itself when it announces on the network.
@immutable
class FlexDiscovery {
  final String model;
  final String? serial;
  final String? nickname;
  final String? version;
  final String host;
  final int port;

  const FlexDiscovery({required this.model, required this.host, required this.port, this.serial, this.nickname, this.version});
}

/// Reads one discovery datagram.
///
/// A Flex broadcasts VITA-49 frames on UDP 4992 whose payload is plain
/// ASCII `key=value` pairs. Parsing the VITA-49 header properly would buy
/// nothing here, so this scans for the payload the way app-polo did — but
/// it also requires an address, so a datagram from something else sharing
/// the port is ignored rather than half-parsed into a radio with nowhere
/// to connect to.
///
/// Returns null for anything that isn't a usable Flex announcement.
FlexDiscovery? parseFlexDiscovery(List<int> datagram) {
  final text = String.fromCharCodes(datagram.where((b) => b >= 0x20 && b < 0x7f).toList());
  final start = text.indexOf('model=');
  if (start < 0) return null;

  final fields = <String, String>{};
  for (final pair in text.substring(start).split(' ')) {
    final separator = pair.indexOf('=');
    if (separator <= 0) continue;
    fields[pair.substring(0, separator)] = pair.substring(separator + 1).trim();
  }

  final model = fields['model'];
  final host = fields['ip'];
  if (model == null || model.isEmpty) return null;
  // Without an address there is nothing to connect to, so this is not a
  // usable discovery no matter how well-formed the rest of it is.
  if (host == null || host.isEmpty) return null;

  return FlexDiscovery(
    model: model,
    host: host,
    port: int.tryParse(fields['port'] ?? '') ?? FlexRadioDriver.defaultPort,
    serial: _nonEmpty(fields['serial']),
    nickname: _nonEmpty(fields['nickname']),
    version: _nonEmpty(fields['version']),
  );
}

String? _nonEmpty(String? value) => (value == null || value.isEmpty) ? null : value;
