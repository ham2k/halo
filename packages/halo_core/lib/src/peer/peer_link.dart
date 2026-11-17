// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one thing `PeerSession` needs from a transport (HALO-310). Shaped like
// CAT's `EquipmentConnection` (docs/design/cat.md) — same never-throwing
// send, same `closed` future, same idempotent close — with one deliberate
// difference: this is MESSAGE-oriented, not byte-oriented.
//
// CAT's connection is a byte stream because radio protocols are; a peer link
// carries whole `PeerMessage` envelopes, and every transport it will run on
// already frames for us (WebSocket has message boundaries, BLE reassembles
// its own writes). Framing therefore belongs in each transport, not repeated
// in the session — so one element of [inbound] is exactly one message.

import 'dart:async';

abstract class PeerLink {
  /// One complete message per element. Never partial, never two joined.
  Stream<List<int>> get inbound;

  /// Fire-and-forget: MUST NOT throw, even after the link is dead. Liveness
  /// is reported only through [closed], so a caller writing from a timer
  /// needs no defensive try/catch of its own (CAT's rule, same reasoning).
  void send(List<int> message);

  /// Completes when the link is down, however it went down. Never an error.
  Future<void> get closed;

  /// Idempotent.
  Future<void> close();

  /// The IP address at the far end, or null for a transport that has none
  /// (BLE). For a link this side dialled, the address it dialled; for one it
  /// accepted, the address the connection came from. Anything else a peer
  /// opens to this device on its behalf is tied to this address, never to
  /// one a beacon names, since anything on the segment can send a beacon.
  String? get remoteAddress;
}
