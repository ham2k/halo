// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What this device opens to the network on its own: peer device sync, and
// listening for other logging programs (N1MM, WSJT-X). Device-local prefs, every
// one off or on its program's default until the operator turns it. A mixin on
// SettingsService, like ExtensionStoreSettings, so readers keep the one service
// and the one ChangeNotifier.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart' show uuidGenerator;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/device_identity.dart';
import '../config/user_agent.dart';

mixin NetworkSettings on ChangeNotifier {
  SharedPreferences get prefs;
  String get operatorCall;

  static const _listenForOtherAppsEnabledKey = 'listenForOtherAppsEnabled';
  static const _peerSyncEnabledKey = 'peerSyncEnabled';
  static const _peerBleEnabledKey = 'peerBleEnabled';
  static const _peerScreenShareEnabledKey = 'peerScreenShareEnabled';
  static const _peerSharedScreenIdsKey = 'peerSharedScreenIds';
  static const _peerDeviceIdKey = 'peerDeviceId';
  static const _peerDeviceNameKey = 'peerDeviceName';
  static const _n1mmProtocolEnabledKey = 'n1mmProtocolEnabled';
  static const _n1mmListenPortKey = 'n1mmListenPort';
  static const _wsjtxProtocolEnabledKey = 'wsjtxProtocolEnabled';
  static const _wsjtxListenPortKey = 'wsjtxListenPort';
  static const _wsjtxMulticastGroupKey = 'wsjtxMulticastGroup';

  /// N1MM's own default UDP broadcast port — see "Listen for other apps".
  static const n1mmDefaultListenPort = 12060;

  /// WSJT-X's own defaults for its UDP protocol (a DIFFERENT protocol from
  /// N1MM's — multicast, binary — not just a different port).
  static const wsjtxDefaultListenPort = 2237;
  static const wsjtxDefaultMulticastGroup = '239.239.0.2';

  /// Whether the app listens for other logging programs on the network at
  /// all, app-wide and independent of which operation (if any) is open —
  /// see "Listen for other apps". The master switch:
  /// `InboundQsoListenerService` starts nothing while this is off, whatever
  /// [n1mmProtocolEnabled]/[wsjtxProtocolEnabled] say. Those two decide
  /// WHICH protocols run once this is on — an operator who only uses
  /// WSJT-X shouldn't have N1MM's port bound for no reason.
  bool get listenForOtherAppsEnabled => prefs.getBool(_listenForOtherAppsEnabledKey) ?? false;

  Future<void> setListenForOtherAppsEnabled(bool enabled) async {
    await prefs.setBool(_listenForOtherAppsEnabledKey, enabled);
    notifyListeners();
  }

  /// The master switch for peer device sync.
  ///
  /// Off by default, and the ONLY thing that opens a socket: with this off
  /// nothing binds, nothing announces, and this device is invisible to the
  /// network. On, whichever operation the operator has open is shared
  /// automatically — there is no per-operation step, so the switch itself is
  /// the whole consent, which is why it says what it does in the settings
  /// row rather than only in a help page.
  bool get peerSyncEnabled => prefs.getBool(_peerSyncEnabledKey) ?? false;

  Future<void> setPeerSyncEnabled(bool enabled) async {
    await prefs.setBool(_peerSyncEnabledKey, enabled);
    notifyListeners();
  }

  /// The Bluetooth sub-switch under [peerSyncEnabled]. Its own
  /// opt-in where location sharing has none, because turning it on does
  /// what the master switch alone never did: pops an OS Bluetooth
  /// permission prompt and keeps a radio busy. Off, BLE code touches
  /// nothing and existing LAN users see no new prompt.
  bool get peerBleEnabled => prefs.getBool(_peerBleEnabledKey) ?? false;

  Future<void> setPeerBleEnabled(bool enabled) async {
    await prefs.setBool(_peerBleEnabledKey, enabled);
    notifyListeners();
  }

  /// The screen-sharing sub-switch under [peerSyncEnabled], and
  /// its own opt-in for the same reason BLE has one: turning it on does
  /// something the master switch never implied. A shared operation is the
  /// operator's own log; a shared screen is their email, their browser and
  /// whatever else is on that display, and on macOS it also asks the OS for
  /// a Screen Recording grant that outlives the app.
  bool get peerScreenShareEnabled => prefs.getBool(_peerScreenShareEnabledKey) ?? false;

  Future<void> setPeerScreenShareEnabled(bool enabled) async {
    await prefs.setBool(_peerScreenShareEnabledKey, enabled);
    notifyListeners();
  }

  /// Which sources this device offers — nothing is shared merely because the
  /// switch above is on, so a mis-tapped switch cannot expose a screen.
  ///
  /// Ids, not names, and deliberately kept even when a source is not
  /// currently present: an application that is closed and reopened, or an
  /// external display unplugged over lunch, must come back offered rather
  /// than silently dropped from the list the operator built.
  List<String> get peerSharedScreenIds => prefs.getStringList(_peerSharedScreenIdsKey) ?? const [];

  Future<void> setPeerSharedScreenIds(List<String> ids) async {
    await prefs.setStringList(_peerSharedScreenIdsKey, ids);
    notifyListeners();
  }

  /// This install's identifier for peer device sync — the only
  /// thing another device's trust is ever keyed on.
  ///
  /// Deliberately NOT `SettingsService.syncDeviceKey`. That one is a bearer credential for
  /// the account's log and lives in the platform keychain; this one is
  /// broadcast in the clear to every device on the network, so it belongs in
  /// plain prefs — and a keychain-backed id would leave peer sync dead on a
  /// headless Linux box with a locked keyring, where `ensureSyncDeviceKey`
  /// legitimately returns null.
  ///
  /// Generated on first read and persisted fire-and-forget. If that write
  /// were ever to fail the device would come back under a new id and its
  /// peers would ask to pair again — recoverable, and a much better failure
  /// than making every caller handle a null identity.
  String get peerDeviceId {
    final cached = _cachedPeerDeviceId;
    if (cached != null) return cached;
    final existing = prefs.getString(_peerDeviceIdKey);
    if (existing != null && existing.isNotEmpty) return _cachedPeerDeviceId = existing;
    final generated = uuidGenerator.v4();
    _cachedPeerDeviceId = generated;
    unawaited(prefs.setString(_peerDeviceIdKey, generated));
    return generated;
  }

  String? _cachedPeerDeviceId;

  /// What this device calls itself to peers. Shown beside [peerDeviceId] in
  /// the pairing prompt so an operator can tell their laptop from their
  /// phone — self-asserted, and never trusted as identity by the receiving
  /// side.
  String get peerDeviceName {
    final stored = prefs.getString(_peerDeviceNameKey);
    if (stored != null && stored.isNotEmpty) return stored;
    final call = operatorCall;
    final deviceName = resolvedDeviceIdentity?.name ?? '';
    final device = deviceName.isNotEmpty ? deviceName : platformName();
    return call.isEmpty ? device : '$call ($device)';
  }

  Future<void> setPeerDeviceName(String name) async {
    await prefs.setString(_peerDeviceNameKey, name.trim());
    notifyListeners();
  }

  /// Whether N1MM's broadcast protocol specifically is listened to, gated
  /// by [listenForOtherAppsEnabled]. Defaults on: most operators want every
  /// protocol this app understands the moment they turn listening on at all.
  bool get n1mmProtocolEnabled => prefs.getBool(_n1mmProtocolEnabledKey) ?? true;

  Future<void> setN1mmProtocolEnabled(bool enabled) async {
    await prefs.setBool(_n1mmProtocolEnabledKey, enabled);
    notifyListeners();
  }

  /// The UDP port N1MM's broadcast is heard on. Configurable because N1MM's
  /// own broadcast port can be reconfigured, and more than one
  /// N1MM-compatible program may share a machine.
  int get n1mmListenPort => prefs.getInt(_n1mmListenPortKey) ?? n1mmDefaultListenPort;

  Future<void> setN1mmListenPort(int port) async {
    await prefs.setInt(_n1mmListenPortKey, port);
    notifyListeners();
  }

  /// See [n1mmProtocolEnabled] — the same per-protocol opt-out for WSJT-X.
  bool get wsjtxProtocolEnabled => prefs.getBool(_wsjtxProtocolEnabledKey) ?? true;

  Future<void> setWsjtxProtocolEnabled(bool enabled) async {
    await prefs.setBool(_wsjtxProtocolEnabledKey, enabled);
    notifyListeners();
  }

  /// The UDP port WSJT-X's multicast protocol is heard on.
  int get wsjtxListenPort => prefs.getInt(_wsjtxListenPortKey) ?? wsjtxDefaultListenPort;

  Future<void> setWsjtxListenPort(int port) async {
    await prefs.setInt(_wsjtxListenPortKey, port);
    notifyListeners();
  }

  /// The multicast group WSJT-X's UDP Server broadcasts to (its Settings →
  /// Reporting → UDP Server tab) — configurable because that field is
  /// itself configurable in WSJT-X, and a station running several rigs may
  /// use a non-default group to keep instances from colliding.
  String get wsjtxMulticastGroup => prefs.getString(_wsjtxMulticastGroupKey) ?? wsjtxDefaultMulticastGroup;

  Future<void> setWsjtxMulticastGroup(String group) async {
    await prefs.setString(_wsjtxMulticastGroupKey, group);
    notifyListeners();
  }
}
