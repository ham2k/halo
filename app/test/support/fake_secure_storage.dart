// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// In-memory stand-in for the keychain: `read`/`write`/`delete` served from a map via
/// noSuchMethod (the real signatures carry per-platform options params not
/// worth spelling out here); anything else throws. Inject into
/// SettingsService wherever a test path reaches `ensureSyncDeviceKey` —
/// the real plugin's platform channel is absent in widget tests.
/// [failWrites] models a locked keyring or a headless box: reads and
/// deletes work, writes refuse.
class FakeSecureStorage implements FlutterSecureStorage {
  final bool failWrites;

  FakeSecureStorage({this.failWrites = false});

  final Map<String, String> _store = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #read) {
      return Future<String?>.value(_store[invocation.namedArguments[#key] as String]);
    }
    if (invocation.memberName == #write) {
      if (failWrites) {
        return Future<void>.error(PlatformException(code: 'Locked', message: 'keyring is locked'));
      }
      _store[invocation.namedArguments[#key] as String] = invocation.namedArguments[#value] as String;
      return Future<void>.value();
    }
    if (invocation.memberName == #delete) {
      // Needed by anything that CLEARS a credential — CAT deletes an
      // equipment node's password when the node is removed. Without this
      // the call threw, the caller swallowed it, and a test asserting the
      // secret was gone passed with it still there.
      _store.remove(invocation.namedArguments[#key] as String);
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}
