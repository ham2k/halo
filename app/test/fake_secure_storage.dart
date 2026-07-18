// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// In-memory stand-in for the keychain: `read`/`write` served from a map via
/// noSuchMethod (the real signatures carry per-platform options params not
/// worth spelling out here); anything else throws. Inject into
/// SettingsService wherever a test path reaches `ensureSyncDeviceKey` —
/// the real plugin's platform channel is absent in widget tests.
class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _store = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #read) {
      return Future<String?>.value(_store[invocation.namedArguments[#key] as String]);
    }
    if (invocation.memberName == #write) {
      _store[invocation.namedArguments[#key] as String] = invocation.namedArguments[#value] as String;
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}
