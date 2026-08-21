// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Receives WSJT-X's own protocol (Status, Decode, QSOLogged, ...). WSJT-X's
// "UDP Server" setting is just a plain destination address, not necessarily
// multicast — its default (239.239.0.2) is, but an operator can just as
// validly point it at a specific host's unicast address, or (if WSJT-X ever
// supports it) the broadcast address. Only the multicast case needs this
// socket to explicitly JOIN a group; the other two are ordinary traffic a
// plain bound socket already receives.
//
// This distinction matters beyond correctness: iOS gates multicast behind
// `com.apple.developer.networking.multicast`, an entitlement Apple grants
// case-by-case on request — not something addable by editing a file. iOS
// builds carry no entitlements file until that request is approved, so a
// multicast join there fails and the operator sees "nothing heard". A
// unicast destination sidesteps that restriction entirely, at the cost of
// needing to be updated if the receiving device's address changes.
//
// A listening socket, same entitlement need as udp_broadcast_io.dart:
// `com.apple.security.network.server` on macOS, in Release too, not just
// Debug.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Datagrams arriving on [port] and addressed to [address], for as long as
/// the subscription lives. Joins [address] as a multicast group only when it
/// actually is one (224.0.0.0–239.255.255.255) — a unicast or broadcast
/// address is received by the plain bind alone.
///
/// Errors are reported on the stream rather than thrown — same contract as
/// [udpBroadcastDatagrams] in udp_broadcast_io.dart, and for the same
/// reason: a port already held by another app, or a network that blocks
/// multicast, should leave the caller with "nothing found" and a reason.
Stream<Uint8List> udpMulticastDatagrams({required int port, required String multicastGroup}) {
  RawDatagramSocket? socket;
  var cancelled = false;
  late final StreamController<Uint8List> controller;

  controller = StreamController<Uint8List>(
    onListen: () async {
      try {
        final bound = await _bind(port);
        if (cancelled) {
          bound.close();
          return;
        }
        socket = bound;
        // Broadcast enabled unconditionally, same as udp_broadcast_io.dart —
        // harmless when the address is unicast or multicast, and what makes
        // a broadcast destination (e.g. 255.255.255.255) work at all.
        socket!.broadcastEnabled = true;
        if (_isMulticastAddress(multicastGroup)) {
          // Unlike a broadcast or unicast bind, multicast delivers nothing
          // until the socket explicitly joins the group.
          socket!.joinMulticast(InternetAddress(multicastGroup));
        }
        socket!.listen(
          (event) {
            if (event != RawSocketEvent.read) return;
            final datagram = socket?.receive();
            if (datagram != null && !controller.isClosed) controller.add(datagram.data);
          },
          onError: controller.addError,
          onDone: controller.close,
        );
      } catch (e, st) {
        if (!controller.isClosed) {
          controller.addError(e, st);
          await controller.close();
        }
      }
    },
    onCancel: () {
      cancelled = true;
      socket?.close();
      socket = null;
    },
  );

  return controller.stream;
}

/// Whether [address] is an IPv4 multicast address — the 224.0.0.0/4 block.
/// Malformed input reads as "not multicast" rather than throwing: an
/// operator's typo in the address field should surface as "nothing
/// arrives", not a crash.
bool _isMulticastAddress(String address) {
  final octets = address.split('.');
  if (octets.length != 4) return false;
  final first = int.tryParse(octets[0]);
  return first != null && first >= 224 && first <= 239;
}

Future<RawDatagramSocket> _bind(int port) async {
  // Sharing the port matters here too — a second listener (JTAlert,
  // GridTracker, N1MM's own WSJT-X bridge) is routinely running alongside
  // this app on the same machine.
  try {
    return await RawDatagramSocket.bind(InternetAddress.anyIPv4, port, reuseAddress: true, reusePort: true);
  } catch (e) {
    debugPrint('[udp-multicast] SO_REUSEPORT unavailable ($e), binding $port without it');
    return RawDatagramSocket.bind(InternetAddress.anyIPv4, port, reuseAddress: true);
  }
}
