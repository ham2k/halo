// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// SOTA registers a separate OAuth client per build edition with SOTA's
// Keycloak (ham2k/app-halo-dist#253) — its account hook's `oauth2` is a
// function of `ctx.edition`, not a plain object, so the kernel's
// `account`/`getDefinition` dispatch has to call it (see kernel.ts) rather
// than read it as a static field. This exercises the whole real path: Dart's
// getSettings() host call stamping `edition`, the kernel building it into
// ctx, and SOTA's extension selecting the matching client. `flutter test`
// compiles with no HALO_EDITION define, so kEdition — and therefore what
// SOTA resolves — is 'dev' here; the per-edition mapping itself (all three
// editions' exact client IDs/redirect URLs) is a plain data table with no
// runtime behavior worth a JS-side unit test.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/extension_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("SOTA's OAuth client resolves to the running edition's, not a shared/borrowed one", () async {
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final lookups = LookupRepository(db);
    final extensions = ExtensionService()..lookups = lookups;
    await extensions.start();

    final accounts = await extensions.getAccounts();
    expect(accounts, isNotNull, reason: 'the account fan-out failed outright, so nothing below is testable');
    final sota = accounts!.singleWhere((a) => a['key'] == 'sota');
    final oauth2 = (sota['oauth2'] as Map).cast<String, dynamic>();

    // dev — this test binary's own edition (no HALO_EDITION define set).
    expect(oauth2['clientId'], 'com.ham2k.logger.dev');
    expect(oauth2['redirectUrl'], 'com.ham2k.logger.dev.auth://sota');
    // Never PoLo's borrowed client, which HaLo used before #253.
    expect(oauth2['clientId'], isNot('polo'));
  });
}
