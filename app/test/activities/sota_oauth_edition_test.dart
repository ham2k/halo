// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// SOTA's OAuth config varies per build edition, so its account hook's
// `oauth2` is a function of `ctx.edition`, not a plain object, and the
// kernel's `account`/`getDefinition` dispatch has to CALL it (see kernel.ts)
// rather than read it as a static field. This exercises the whole real path:
// Dart's getSettings() host call stamping `edition`, the kernel building it
// into ctx, and SOTA's extension selecting the matching entry. `flutter
// test` compiles with no HALO_EDITION define, so kEdition — and therefore
// what SOTA resolves — is 'dev' here; the mapping itself is a plain data
// table with no runtime behavior worth a JS-side unit test.
//
// What varies per edition is the REDIRECT URL alone. The client id is one
// shared value, `polo`, because SOTA's realm holds exactly one Ham2K client
// and registers HaLo's per-edition redirects against it — see the table in
// extensions/activities/sota/src/index.ts for why a per-edition client id
// cannot work.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("SOTA's OAuth redirect resolves to the running edition's, behind the one shared client", () async {
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final lookups = LookupRepository(db);
    // SOTA is not in the default set — only POTA is — so the runtime has to
    // be asked for it before its account hook is there to answer.
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    await settings.setExtensionOverrides({'sota': true});
    final extensions = ExtensionService()
      ..lookups = lookups
      ..settings = settings;
    await extensions.start();

    final accounts = await extensions.getAccounts();
    expect(accounts, isNotNull, reason: 'the account fan-out failed outright, so nothing below is testable');
    final sota = accounts!.singleWhere((a) => a['key'] == 'sota');
    final oauth2 = (sota['oauth2'] as Map).cast<String, dynamic>();

    // dev — this test binary's own edition (no HALO_EDITION define set). The
    // redirect is the per-edition half, and the only half that is: it must
    // match a string on the `polo` client's redirect allowlist EXACTLY, or
    // Keycloak rejects the authorization request outright.
    // `com.ham2k.logger.*`, not `.halo.*`: OAuth redirects use the OFFICIAL
    // prefix, and each string is on the `polo` client's allowlist as a
    // literal. The `.halo` aliases are not registered there, so spelling one
    // here fails every SOTA sign-in with "Invalid parameter: redirect_uri".
    expect(oauth2['redirectUrl'], 'com.ham2k.logger.dev.auth://sota');
    // One fixed relay URL shared by every edition (HALO-22), used only on
    // platforms oauthUsesWebhookRelay() sends through LoFi (Web/Linux) — see
    // extensions/activities/sota/src/index.ts's SOTA_OAUTH_WEBHOOK_REDIRECT_URL.
    expect(oauth2['webhookRedirectUrl'], 'https://lofi.ham2k.net/v1/webhooks/client/oauth');
    // The one client SOTA's realm actually has. A per-edition client id
    // reads as the more careful choice and is the failure this pins: no
    // `com.ham2k.logger.*` client exists in that realm, so one would take
    // every edition's sign-in to "Client not found" before a sign-in page
    // ever loads.
    expect(oauth2['clientId'], 'polo');
  });
}
