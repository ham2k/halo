// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The WSJT-X listener's multicast socket, against real loop-back sends.
//
// Imports the io implementation directly: the conditional export resolves
// to the web stub under the analyzer.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/udp_multicast_io.dart';

/// Not WSJT-X's own group: a real WSJT-X on this machine must not feed any
/// assertion here.
final _group = InternetAddress('239.239.77.7');

/// A port with nothing on it, as far as a moment ago could tell.
Future<int> _freePort() async {
  final probe = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0, reuseAddress: false);
  final port = probe.port;
  probe.close();
  // The IO service releases a closed socket's port after `close` returns.
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return port;
}

/// The loop-back interface, or null where it refuses a multicast join — a
/// Linux `lo` without the MULTICAST flag. The behaviour under test cannot
/// be exercised there, so the tests skip rather than fail.
Future<NetworkInterface?> _multicastLoopback() async {
  final interfaces = await NetworkInterface.list(includeLoopback: true, type: InternetAddressType.IPv4);
  final loopback = interfaces.where((i) => i.addresses.any((a) => a.isLoopback)).firstOrNull;
  if (loopback == null) return null;
  final probe = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  try {
    probe.joinMulticast(_group, loopback);
    return loopback;
  } on Object {
    return null;
  } finally {
    probe.close();
  }
}

/// Whether a bare `joinMulticast(group)` — the kernel's default-interface
/// membership — can be made here. The kernel picks that interface by a route
/// for the group, and a machine with no default route (Wi-Fi off, no cable)
/// has none; the fallback under test cannot be exercised there.
Future<bool> _defaultRouteJoins() async {
  final probe = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  try {
    probe.joinMulticast(_group);
    return true;
  } on Object {
    return false;
  } finally {
    probe.close();
  }
}

/// Sends to [_group] on the loop-back interface until [heard] reports a
/// receipt, bounded. A listener that binds and joins asynchronously gives
/// no signal for when it is ready, so the send is repeated rather than
/// timed.
Future<void> _sendOnLoopbackUntil(int port, bool Function() heard) async {
  final sender = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  try {
    // The only way Dart picks the outgoing multicast interface:
    // `RawDatagramSocket.multicastInterface` is unimplemented.
    sender.setRawOption(RawSocketOption(RawSocketOption.levelIPv4, RawSocketOption.IPv4MulticastInterface, InternetAddress.loopbackIPv4.rawAddress));
    for (var attempt = 0; attempt < 100 && !heard(); attempt++) {
      sender.send('ping $attempt'.codeUnits, _group, port);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  } finally {
    sender.close();
  }
}

/// An interface no join can succeed on: an index no system has, and a
/// TEST-NET address no local interface carries (macOS joins IPv4 groups by
/// interface address, every other platform by index).
class _RefusingInterface implements NetworkInterface {
  @override
  final addresses = [InternetAddress('192.0.2.1')];
  @override
  final index = 999999;
  @override
  final name = 'nowhere0';
}

void main() {
  // The trap: multicast membership is per interface, and a bare
  // `joinMulticast(group)` joins on the kernel's default-route interface
  // only. WSJT-X's "Outgoing interfaces" list ticks the loop-back interface
  // by default, and a socket joined on the LAN interface alone hears nothing
  // of what it puts there — while looking healthy, since its join succeeded.
  // A send pinned to lo0 is also the one multicast path macOS's
  // Local Network privacy never gates, which is what lets flutter_tester
  // run this for real.
  test('hears a multicast datagram sent on the loop-back interface', () async {
    if (await _multicastLoopback() == null) {
      markTestSkipped('the loop-back interface refuses multicast here');
      return;
    }
    final port = await _freePort();
    final received = <String>[];
    Object? listenError;
    final subscription = udpMulticastDatagrams(
      port: port,
      multicastGroup: _group.address,
    ).listen((data) => received.add(String.fromCharCodes(data)), onError: (Object e) => listenError = e);
    addTearDown(subscription.cancel);

    await _sendOnLoopbackUntil(port, () => received.isNotEmpty || listenError != null);
    expect(listenError, isNull);
    expect(received, isNotEmpty, reason: 'a multicast datagram sent on lo0 was never heard');
  });

  // A VPN tunnel or a multicast-less interface in the list must cost
  // nothing but a console line — were its refusal to abort the loop, the
  // loop-back membership behind it would never be made and the first test's
  // failure would be back, only on machines with one more interface.
  test('an interface that refuses the join does not block the others', () async {
    final loopback = await _multicastLoopback();
    if (loopback == null) {
      markTestSkipped('the loop-back interface refuses multicast here');
      return;
    }
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    addTearDown(socket.close);
    // The fake must really refuse, or this test proves nothing.
    expect(() => socket.joinMulticast(_group, _RefusingInterface()), throwsA(anything));

    joinMulticastOnEach(socket, _group, [_RefusingInterface(), loopback]);

    final received = <String>[];
    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram != null) received.add(String.fromCharCodes(datagram.data));
    });
    await _sendOnLoopbackUntil(socket.port, () => received.isNotEmpty);
    expect(received, isNotEmpty, reason: 'the loop-back join after a refused one was never made');
  });

  // Nothing joinable in the list means the bare `joinMulticast(group)` — the
  // default-interface membership — not an error: a device whose interface
  // table cannot be listed, or refuses every join, still gets the listener
  // that membership gives, not none. A second join of the same group on the
  // same socket is refused, which is what proves the bare one was made.
  test('falls back to the default-interface join when every interface refuses', () async {
    if (!await _defaultRouteJoins()) {
      markTestSkipped('no route for a multicast group here');
      return;
    }
    // One socket per case: a second join of the same group on a socket
    // already in it is itself refused.
    for (final interfaces in [
      [_RefusingInterface()],
      <NetworkInterface>[],
    ]) {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      addTearDown(socket.close);
      expect(() => joinMulticastOnEach(socket, _group, interfaces), returnsNormally, reason: 'with ${interfaces.length} interface(s) listed');
      expect(() => socket.joinMulticast(_group), throwsA(anything), reason: 'no default-interface membership with ${interfaces.length} interface(s) listed');
    }
  });
}
