// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The account stand-in a peer hello carries (HALO-365). Two devices signed
// in to the same LoFi account may take each other's UNSEEN operations; every
// other pair is limited to operations both already have.

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../settings_service.dart';

/// A stable, opaque tag for the account this device is signed in to, or null
/// when it is signed in to none.
///
/// Hashed, not the account uuid itself: a hello is sent before either side
/// has decided to trust the other, so anything that can open a socket to
/// this device reads whatever is in it. The domain prefix keeps the digest
/// from matching one computed over the bare uuid somewhere else.
///
/// Comparing tags is the ONLY use. Nothing may resolve one back to an
/// account, and a null must never compare equal to another null — see
/// `PeerHello.accountTag`.
String? peerAccountTag(SettingsService settings) {
  final accountData = settings.syncState['accountData'];
  final current = accountData is Map ? accountData['current_account'] : null;
  final uuid = current is Map ? current['uuid'] : null;
  if (uuid is! String || uuid.isEmpty) return null;
  return sha256.convert(utf8.encode('ham2k-peer-account:$uuid')).toString().substring(0, 32);
}
