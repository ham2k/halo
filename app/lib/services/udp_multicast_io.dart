// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Receives WSJT-X's own protocol (Status, Decode, QSOLogged, ...). WSJT-X's
// "UDP Server" setting is just a plain destination address, not necessarily
// multicast — its own default is the unicast 127.0.0.1; 239.239.0.2 is the
// multicast group its documentation recommends once more than one program
// listens, since a unicast datagram reaches only one of them; and (if WSJT-X
// ever supports it) the broadcast address is as valid. Only the multicast
// case needs this socket to explicitly JOIN a group; the other two are
// ordinary traffic a plain bound socket already receives.
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
          final interfaces = await _interfacesToJoin();
          // Cancelled during the enumeration: `onCancel` has closed the socket.
          if (cancelled) return;
          joinMulticastOnEach(socket!, InternetAddress(multicastGroup), interfaces);
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

/// Every IPv4 interface — the loop-back one and link-local-only ones (a
/// laptop cabled straight to a radio's network, no DHCP) included. Empty
/// when the system refuses to enumerate them, which [joinMulticastOnEach]
/// reads as "the kernel's default interface".
Future<List<NetworkInterface>> _interfacesToJoin() async {
  try {
    return await NetworkInterface.list(includeLoopback: true, includeLinkLocal: true, type: InternetAddressType.IPv4);
  } on SocketException catch (e) {
    debugPrint('[udp-multicast] cannot list interfaces: $e');
    return const [];
  }
}

/// Joins [group] on each of [interfaces]. Membership is per interface: a
/// datagram the sender puts on lo0 (the interface WSJT-X's "Outgoing
/// interfaces" list ticks by default, and the one multicast path macOS's
/// Local Network privacy never gates) reaches only a socket joined on lo0,
/// and one sent on the LAN interface only a socket joined there. So the
/// listener joins every attached network, where a bare `joinMulticast(group)`
/// covers the default route's alone — a stranger's WSJT-X on a club LAN or a
/// VPN is thereby heard too, which is acceptable because the operator reviews
/// every capture before it reaches a log. An interface that refuses (a VPN
/// tunnel, a Linux `lo` without multicast enabled) is skipped. When none
/// accepted — or there were none to try — the bare join is the fallback, and
/// its failure is the one that propagates: that error says something about
/// the platform (iOS without the multicast entitlement), not about whichever
/// interface happened to be listed last.
@visibleForTesting
void joinMulticastOnEach(RawDatagramSocket socket, InternetAddress group, List<NetworkInterface> interfaces) {
  var joined = 0;
  void refused(NetworkInterface interface, Object e) => debugPrint('[udp-multicast] join ${group.address} on ${interface.name} refused: $e');
  for (final interface in interfaces) {
    // The native join throws OSError; the Dart side throws SocketException
    // (an interface with no address of the group's family, a closed socket).
    try {
      socket.joinMulticast(group, interface);
      joined++;
    } on SocketException catch (e) {
      refused(interface, e);
    } on OSError catch (e) {
      refused(interface, e);
    }
  }
  if (joined == 0) socket.joinMulticast(group);
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
