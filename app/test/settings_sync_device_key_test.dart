// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_secure_storage.dart';

/// Secure storage that fails every call the way a locked/absent libsecret does
/// on Linux — the crash test users hit (`PlatformException(KeyringLocked)`).
class _LockedKeyring implements FlutterSecureStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #read || invocation.memberName == #write) {
      throw PlatformException(code: 'KeyringLocked', message: 'KeyringLocked');
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SettingsService> build(FlutterSecureStorage secure) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return SettingsService(prefs, secureStorage: secure);
  }

  group('ensureSyncDeviceKey', () {
    test('returns null (never throws) when the keyring is locked, so boot survives', () async {
      final settings = await build(_LockedKeyring());
      // The regression: this used to throw KeyringLocked and take bootstrap()
      // down with it. It must now degrade to "no key".
      expect(await settings.ensureSyncDeviceKey(), isNull);
    });

    test('never leaks the bearer credential into plain prefs on failure', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs, secureStorage: _LockedKeyring());
      await settings.ensureSyncDeviceKey();
      // The device key is a secret; a locked keyring must not push it to prefs.
      expect(prefs.getString('syncDeviceKey'), isNull);
    });

    test('mints and caches a stable key when secure storage works', () async {
      final settings = await build(FakeSecureStorage());
      final key = await settings.ensureSyncDeviceKey();
      expect(key, isNotNull);
      expect(await settings.ensureSyncDeviceKey(), key);
    });
  });
}
