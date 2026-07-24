// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Expired-build nag: the dialog must tell the user where to get a newer
// build, must be dismissible (an expired build KEEPS WORKING — logging a
// contact always beats freshness), and must never appear in a build with no
// expiration baked in (this test binary has none, pinning the OSS/dev
// default of never nagging).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ham2k_logger/config/version.dart';
import 'package:ham2k_logger/views/expired_build_dialog.dart';

void main() {
  test('isBuildExpired follows kBuildExpiration, whatever is baked in', () {
    // Deliberately value-agnostic: test binaries run as the Dev edition, and
    // `halo-ops release` re-stamps kDevExpirationDate on every cut — so this
    // test must hold both for a fresh OSS checkout (no date → never expired)
    // and for a checkout carrying a real stamp (expiry = the day after the
    // date, UTC — see expirationHasPassed's own tests in halo_build_tools).
    final expiration = kBuildExpiration;
    if (expiration == null) {
      expect(isBuildExpired(now: DateTime.utc(2099)), isFalse);
    } else {
      expect(isBuildExpired(now: expiration.subtract(const Duration(days: 1))), isFalse);
      expect(isBuildExpired(now: DateTime.utc(expiration.year, expiration.month, expiration.day + 2)), isTrue);
    }
  });

  testWidgets('the nag names ham2k.com and dismisses without side effects', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(context: context, builder: (_) => const ExpiredBuildDialog()),
          child: const Text('trigger'),
        ),
      ),
    ));
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.text('This build has expired'), findsOneWidget);
    expect(find.textContaining('ham2k.com'), findsWidgets);

    await tester.tap(find.text('Continue anyway'));
    await tester.pumpAndSettle();
    expect(find.text('This build has expired'), findsNothing,
        reason: 'dismiss must let the user keep using the app');
  });
}
