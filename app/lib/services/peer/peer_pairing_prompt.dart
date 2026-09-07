// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The app-wide pairing prompt. A device asking to pair arrives while the
// operator is logging, not while they are looking at the Peers panel; without
// this the request is silent everywhere but that one settings screen, which
// looks exactly like peer sync not working.

import 'dart:async';

import 'package:flutter/material.dart';

import 'ble/peer_ble_transport.dart';
import '../../views/peer_pairing_dialog.dart';

import '../../config/navigation.dart';
import '../halo_services.dart';

/// Raises the pairing prompt wherever the operator happens to be.
///
/// The Peers panel prompts too, but a device asking to pair is not something
/// an operator goes looking for — it arrives while they are logging. Without
/// this the request is silent everywhere except one settings screen, which
/// looks exactly like peer sync not working.
void listenForPeerPairingRequests(HaLoServices services) {
  services.peerService.addListener(() {
    final pending = services.peerService.pendingPairing;
    final peer = pending?.session?.peer;
    if (peer == null) return;
    _openPeerPairingPrompt(services, peer.deviceId, peer.deviceName,
        viaBluetooth: pending?.session?.link is PeerBleLink);
  });
}

/// True while a prompt is on screen, so the service's own notifications —
/// one per beacon, several a second — cannot stack a second dialog on top of
/// the one the operator is reading.
bool _peerPairingPromptOpen = false;

/// Opens the prompt once there is a navigator to open it onto.
///
/// Same cold-start retry as `_openConfirmDevicePane` (deep_link_router.dart), for the same reason: a
/// peer can be discovered while the first frame is still being built, and a
/// dropped prompt leaves a device sitting at `needsPairing` with nothing on
/// screen to say so. Unlike a QR deep link this one does have a way back —
/// the Peers panel lists the waiting device — so it gives up quietly.
void _openPeerPairingPrompt(
  HaLoServices services,
  String deviceId,
  String deviceName, {
  required bool viaBluetooth,
  int attemptsLeft = 20,
}) {
  if (_peerPairingPromptOpen) return;
  final context = navigatorKey.currentContext;
  if (context == null) {
    if (attemptsLeft <= 0) {
      debugPrint('[peer] pairing prompt dropped: no navigator after 5s — '
          'the Peers panel still lists $deviceId');
      return;
    }
    Timer(const Duration(milliseconds: 250),
        () => _openPeerPairingPrompt(services, deviceId, deviceName,
            viaBluetooth: viaBluetooth, attemptsLeft: attemptsLeft - 1));
    return;
  }
  _peerPairingPromptOpen = true;
  // catchError as well as the finally below: a navigator torn down while the
  // dialog is up completes this future with an ERROR, which `then`'s finally
  // does not run for — and a latched flag suppresses every future pairing
  // prompt for the rest of the process.
  unawaited(showPeerPairingDialog(context,
          deviceName: deviceName, deviceId: deviceId, viaBluetooth: viaBluetooth)
      .catchError((Object e) {
    debugPrint('[peer] pairing prompt failed: $e');
    return null;
  }).then((allowed) async {
    try {
      // Dismissed rather than answered: left pending on purpose, so the
      // Peers panel still offers it instead of it counting as a refusal.
      if (allowed == null) return;
      if (allowed) {
        await services.peerService.acceptPairing(deviceId);
      } else {
        await services.peerService.rejectPairing(deviceId);
      }
    } finally {
      _peerPairingPromptOpen = false;
    }
  }));
}
