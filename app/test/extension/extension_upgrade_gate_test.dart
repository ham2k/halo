// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The restore offer's one integration point is `MaterialApp.builder`, ABOVE
// the Navigator — the same rung as the onboarding and release gates. A
// dialog raised from the gate's own context has no Navigator to land on, and
// the failure is invisible: the offer is fire-and-forget off initState, so
// the throw reaches nobody and the operator simply never sees the dialog.
// These tests mount the gate where the app does, not under `home:`.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/config/navigation.dart';
import 'package:ham2k_logger/services/extensions/catalog_service.dart';
import 'package:ham2k_logger/services/extensions/extension_relevance.dart';
import 'package:ham2k_logger/services/extensions/installed_extensions.dart' show CatalogChannel;
import 'package:ham2k_logger/services/extensions/preloaded_extensions.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/app_shell/extension_upgrade_gate.dart';

import '../support/halo_test_support.dart';

void main() {
  group('extensions the store no longer holds', () {
    // Offered after boot, never on the operator's behalf: Later keeps each
    // for the next launch, Forget is the only way one leaves short of coming
    // back, and one that will not install costs only itself.
    Future<_Missing> pumpGate(
      WidgetTester tester,
      List<MissingExtension> missing, {
      Set<String> failing = const {},
      bool reloadThrows = false,
      bool forgetThrows = false,
      bool pushesDuring = false,
    }) async {
      final extensions = _Missing(missing, failing: failing, reloadThrows: reloadThrows, forgetThrows: forgetThrows, pushesDuring: pushesDuring);
      final h = await makeHaLoServices(extensions: extensions, catalog: _Listing([for (final m in missing) m.key]));
      extensions.catalog = h.services.catalog;
      await h.settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'N0CALL');
      await h.settings.setExtensionsMigrated(true);
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            navigatorKey: navigatorKey,
            builder: (context, child) => ExtensionUpgradeGate(services: h.services, child: child!),
            home: const Scaffold(body: SizedBox()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return extensions;
    }

    const pota = MissingExtension(key: 'ham2k-pota', name: 'POTA', from: MissingFrom.catalog);
    const llota = MissingExtension(key: 'ham2k-llota', name: 'LLOTA', from: MissingFrom.catalog);
    const clock = MissingExtension(key: 'ki2d-clock', name: 'My Clock', from: MissingFrom.file);

    testWidgets('Later installs nothing and forgets nothing', (tester) async {
      final extensions = await pumpGate(tester, const [pota, clock]);
      expect(find.text(t.extensionsPanel.restoreTitle), findsOneWidget);
      await tester.tap(find.text(t.extensionsPanel.restoreLater));
      await tester.pumpAndSettle();
      expect(extensions.reinstalled, isEmpty);
      expect(extensions.forgotten, isEmpty);
    });

    testWidgets('a file install can only be forgotten, and Forget takes it off the list', (tester) async {
      // Nothing can fetch it again, so the dialog must not offer to.
      final extensions = await pumpGate(tester, const [clock]);
      expect(find.text(t.extensionsPanel.restoreInstall), findsNothing);
      await tester.tap(find.byKey(const ValueKey('restore-forget-ki2d-clock')));
      await tester.pumpAndSettle();
      expect(extensions.forgotten, ['ki2d-clock']);
      expect(find.text(t.extensionsPanel.restoreTitle), findsNothing, reason: 'nothing left to decide');
    });

    testWidgets('a restore that fails part way never leaves the operator behind its spinner', (tester) async {
      await withErrorHooks(() async {
        await pumpGate(tester, const [pota], reloadThrows: true);
        await tester.tap(find.text(t.extensionsPanel.restoreInstall));
        await tester.pumpAndSettle();
      });
      expect(find.text(t.extensionsPanel.restoreInstalling), findsNothing);
      // Judged afresh after the throw: POTA had landed.
      expect(find.textContaining(t.extensionsPanel.restoreDoneBody(names: 'POTA')), findsOneWidget);
    });

    testWidgets('a window opened over the spinner survives it, and the spinner still comes down', (tester) async {
      // A bare pop at the end closes whatever is on top — the prompt — and
      // leaves the spinner standing with no way out.
      await pumpGate(tester, const [pota], pushesDuring: true);
      await tester.tap(find.text(t.extensionsPanel.restoreInstall));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.done));
      await tester.pumpAndSettle();
      expect(find.text('Pairing?'), findsOneWidget);
      expect(find.text(t.extensionsPanel.restoreInstalling), findsNothing);
    });

    testWidgets('a catalog extension can be forgotten too', (tester) async {
      // One the catalog stopped serving fails every Install, and would come
      // back every launch with no way to let it go.
      final extensions = await pumpGate(tester, const [pota]);
      await tester.tap(find.byKey(const ValueKey('restore-forget-ham2k-pota')));
      await tester.pumpAndSettle();
      expect(extensions.forgotten, ['ham2k-pota']);
    });

    testWidgets('a Forget that fails leaves the extension on the list', (tester) async {
      await withErrorHooks(() async {
        await pumpGate(tester, const [clock], forgetThrows: true);
        await tester.tap(find.byKey(const ValueKey('restore-forget-ki2d-clock')));
        await tester.pumpAndSettle();
      });
      expect(find.byKey(const ValueKey('restore-forget-ki2d-clock')), findsOneWidget);
    });

    testWidgets('each installs on its own, and the result names what did not', (tester) async {
      final extensions = await pumpGate(tester, const [pota, llota], failing: const {'ham2k-llota'});
      await tester.tap(find.text(t.extensionsPanel.restoreInstall));
      await tester.pumpAndSettle();
      expect(extensions.reinstalled, ['ham2k-pota']);
      expect(find.text(t.extensionsPanel.restorePartialTitle), findsOneWidget);
      expect(find.textContaining(t.extensionsPanel.restoreFailed(names: 'LLOTA')), findsOneWidget);
    });
  });
}

/// Missing [missing] at boot, with the catch-up already settled; installing
/// one fails for the keys in [failing].
class _Missing extends ExtensionServiceWithFakeHost {
  _Missing(this.missing, {this.failing = const {}, this.reloadThrows = false, this.forgetThrows = false, this.pushesDuring = false})
    : super(FakeExtensionHost({}));

  List<MissingExtension> missing;
  final Set<String> failing;
  final bool reloadThrows;
  final bool forgetThrows;

  /// Opens a prompt of its own over the spinner mid-install, as a pairing
  /// request or the command palette would.
  final bool pushesDuring;
  final reinstalled = <String>[];
  final forgotten = <String>[];

  @override
  Future<void> get firstCatchUp async {}

  @override
  List<MissingExtension> missingExtensions() => missing;

  @override
  Future<void> reinstallFromCatalog(CatalogEntry entry) async {
    if (failing.contains(entry.key)) throw StateError('the download failed');
    if (pushesDuring) {
      unawaited(
        showDialog<void>(
          context: navigatorKey.currentContext!,
          builder: (_) => const AlertDialog(title: Text('Pairing?')),
        ),
      );
      await Future<void>.delayed(Duration.zero);
    }
    reinstalled.add(entry.key);
    missing = [
      for (final m in missing)
        if (m.key != entry.key) m,
    ];
  }

  @override
  Future<void> forgetMissingExtension(String key) async {
    if (forgetThrows) throw StateError('the keychain refused');
    forgotten.add(key);
    missing = [
      for (final m in missing)
        if (m.key != key) m,
    ];
  }

  @override
  Future<void> reloadAvailableExtensions() async {
    if (reloadThrows) throw StateError('the index would not read');
  }

  @override
  Future<void> restartRuntime({bool fresh = false}) async {}
}

/// A catalog listing exactly [keys].
class _Listing extends CatalogService {
  _Listing(this.keys);

  final List<String> keys;

  @override
  Future<List<CatalogEntry>?> fetchCatalog({OperatorGeo? geo, bool force = false, CatalogChannel? channel}) async => [
    for (final key in keys)
      CatalogEntry(
        key: key,
        name: key,
        version: '1.0.0',
        sha256: 'a' * 64,
        bundleUrl: Uri.parse('https://catalog.example/api/v1/extensions/$key/versions/1.0.0/bundle'),
      ),
  ];
}
