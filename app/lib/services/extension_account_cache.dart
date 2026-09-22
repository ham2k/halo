// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

/// In-memory copy of each extension account's two keychain items, by kvKey,
/// as the host `getAccount` call answers them. The kernel asks for the
/// account context before EVERY hook method call (its own cache lives 3 s),
/// and on Linux each keychain read is several blocking D-Bus round trips on
/// the GTK thread — a Secret Service warm-up, an unlock attempt, the lookup —
/// so without this every navigation freezes for as long as gnome-keyring
/// takes, multiplied by the extensions that declare an account. A failed
/// read is cached as well ([AccountItems.unreadable]), for [unreadableRetry]:
/// a locked keyring costs one freeze per account per interval instead of one
/// per hook call, and a phone locked in a pocket mid-activation
/// (errSecInteractionNotAllowed, which ErrorPolicy's `keychain-locked` rule
/// expects the next unlock to resolve) heals on its own rather than leaving
/// every lookup signed out until a restart.
///
/// Invariant, held by ExtensionService: every in-process writer of an
/// `account_creds_`/`account_session_` item updates or evicts the entry in
/// the same call, and a runtime start clears the cache because the
/// synchronizable flags the keychain is keyed on can change — which is also
/// what covers the bulk paths (uninstall, key migration), since each ends in
/// a runtime restart. A write this process does not make — an iCloud
/// Keychain item arriving from another device — is not observed until the
/// Accounts UI's read (which evicts the entry on every success) or the next
/// runtime start; hooks may lag the Accounts panel until then.
class AccountContextCache {
  /// How long a cached keychain FAILURE stands before the host asks the
  /// keychain again. Real time, not the app clock: it bounds a blocking
  /// platform call, and travel must not make it fire at once or never.
  @visibleForTesting
  static Duration unreadableRetry = const Duration(seconds: 60);

  final Map<String, AccountItems> _items = {};

  /// The entry to answer from, or null when there is none or a remembered
  /// failure has outlived [unreadableRetry].
  AccountItems? operator [](String kvKey) {
    final cached = _items[kvKey];
    return cached == null || cached.expired ? null : cached;
  }

  /// The entry as last written, expired or not — for a writer deciding
  /// whether it is amending a copy or a remembered failure.
  AccountItems? current(String kvKey) => _items[kvKey];

  void operator []=(String kvKey, AccountItems items) => _items[kvKey] = items;

  void remove(String kvKey) => _items.remove(kvKey);

  void clear() => _items.clear();
}

/// One account's keychain items as the host `getAccount` call last saw them
/// (raw JSON strings, decoded per answer so no caller can mutate the copy),
/// or [unreadable] when the keychain could not be read at all.
class AccountItems {
  final String? creds;
  final String? session;
  final bool unavailable;

  /// When a failure was recorded (real millis), null for a successful read.
  final int? failedAtMillis;

  const AccountItems({required this.creds, required this.session}) : unavailable = false, failedAtMillis = null;
  AccountItems.unreadable() : creds = null, session = null, unavailable = true, failedAtMillis = realNowMillis();

  /// A failure older than [AccountContextCache.unreadableRetry]; a
  /// successful read never expires.
  bool get expired => failedAtMillis != null && realNowMillis() - failedAtMillis! >= AccountContextCache.unreadableRetry.inMilliseconds;

  /// The `getAccount` answer: `unavailable` is only ever present when true,
  /// so an extension telling "signed out" from "could not look" keys on it.
  Map<String, dynamic> toHostResult() => {
    'credentials': creds != null ? jsonDecode(creds!) : const <String, dynamic>{},
    'session': session != null ? jsonDecode(session!) : const <String, dynamic>{},
    if (unavailable) 'unavailable': true,
  };
}
