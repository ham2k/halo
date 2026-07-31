// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Receives UDP broadcasts on a port, for equipment that announces itself
// (FlexRadio does, on 4992 — the same number as its TCP API, but a
// different protocol and a different socket).
//
// Binding a UDP port is a LISTENING socket, so on macOS this needs
// `com.apple.security.network.server`, which is why that entitlement is now
// in Release.entitlements as well as Debug. It had been Debug-only, which
// meant this would have worked in every development build and failed
// silently in the shipped, signed app.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Datagrams arriving on [port], for as long as the subscription lives.
///
/// Errors are reported on the stream rather than thrown: a port already
/// held by another app, or a sandbox that won't allow the bind, should
/// leave the caller with "nothing found" and a reason — not an exception
/// out of a UI callback.
Stream<Uint8List> udpBroadcastDatagrams({required int port}) {
  RawDatagramSocket? socket;
  var cancelled = false;
  late final StreamController<Uint8List> controller;

  controller = StreamController<Uint8List>(
    onListen: () async {
      try {
        final bound = await _bind(port);
        // Cancelled while the bind was still in flight — `onCancel` saw a
        // null socket and had nothing to close, so this is the only place
        // that can release it. Without this the port stays bound for the
        // life of the process and every later discovery falls back or fails.
        if (cancelled) {
          bound.close();
          return;
        }
        socket = bound;
        socket!.broadcastEnabled = true;
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

Future<RawDatagramSocket> _bind(int port) async {
  // Sharing the port matters: another logger (or a second window) listening
  // for the same announcements must not lock everyone else out. Windows
  // doesn't implement SO_REUSEPORT and throws on it, so fall back rather
  // than lose discovery on that platform entirely.
  try {
    return await RawDatagramSocket.bind(InternetAddress.anyIPv4, port,
        reuseAddress: true, reusePort: true);
  } catch (e) {
    debugPrint('[cat] SO_REUSEPORT unavailable ($e), binding $port without it');
    return RawDatagramSocket.bind(InternetAddress.anyIPv4, port, reuseAddress: true);
  }
}
