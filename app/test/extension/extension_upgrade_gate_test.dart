// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The upgrade offer's one integration point is `MaterialApp.builder`, ABOVE
// the Navigator — the same rung as the onboarding and release gates. A
// dialog raised from the gate's own context has no Navigator to land on, and
// the failure is invisible: the offer is fire-and-forget off initState, so
// the throw reaches nobody and the operator simply never sees the dialog.
// This test mounts the gate where the app does, not under `home:`.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/config/navigation.dart';
import 'package:ham2k_logger/services/extensions/catalog_service.dart';
import 'package:ham2k_logger/services/extensions/extension_info.dart';
import 'package:ham2k_logger/services/extensions/extension_relevance.dart';
import 'package:ham2k_logger/services/extensions/preloaded_extensions.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/app_shell/extension_upgrade_gate.dart';

import '../support/halo_test_support.dart';

/// Always reachable, with something in it.
class _ReachableCatalog extends CatalogService {
  @override
  Future<List<CatalogEntry>?> fetchCatalog({OperatorGeo? geo, bool force = false}) async => [
    CatalogEntry(
      key: 'wca',
      name: 'WCA',
      version: '1.0.0',
      sha256: 'a' * 64,
      bundleUrl: Uri.parse('https://catalog.example/api/v1/extensions/wca/versions/1.0.0/bundle'),
    ),
  ];
}

/// Answers the upgrade as if every twin arrived, without a network or a
/// store: what this file tests is what the OPERATOR is told afterwards.
class _MigrationSucceeds extends ExtensionServiceWithFakeHost {
  _MigrationSucceeds() : super(FakeExtensionHost({}));

  @override
  Future<bool> preloadShippedExtensions() async => true;

  @override
  Future<({bool complete, bool landed})> adoptTwins() async => (landed: true, complete: true);

  @override
  Future<void> reloadAvailableExtensions() async {}

  @override
  Future<void> restartRuntime({bool fresh = false}) async {}
}

/// A migration still running when the screen goes away.
class _SlowMigration extends ExtensionServiceWithFakeHost {
  _SlowMigration({this.adoptionCompletes = true}) : super(FakeExtensionHost({}));

  /// False to end the upgrade short, which is when the body is plain text
  /// rather than the done message that already carried every name.
  final bool adoptionCompletes;

  final release = Completer<void>();

  @override
  Future<bool> preloadShippedExtensions() async {
    await release.future;
    return true;
  }

  @override
  Future<({bool complete, bool landed})> adoptTwins() async => (landed: true, complete: adoptionCompletes);

  @override
  Future<void> reloadAvailableExtensions() async {}

  @override
  Future<void> restartRuntime({bool fresh = false}) async {}
}

/// Answers as if the runtime never came back: the twins are installed and
/// nothing can run them.
class _RuntimeDead extends ExtensionServiceWithFakeHost {
  _RuntimeDead() : super(FakeExtensionHost({}));

  int restarts = 0;

  @override
  ExtensionHost? get host => restarts > 1 ? fakeHost : null;

  @override
  Future<bool> preloadShippedExtensions() async => false;

  @override
  Future<({bool complete, bool landed})> adoptTwins() async => (landed: true, complete: true);

  @override
  Future<void> reloadAvailableExtensions() async {}

  @override
  Future<void> restartRuntime({bool fresh = false}) async => restarts++;
}

/// Answers the upgrade as if the twins never arrived — the half of the
/// outcome the operator must not be told went well.
class _MigrationFails extends ExtensionServiceWithFakeHost {
  _MigrationFails() : super(FakeExtensionHost({}));

  @override
  Future<bool> preloadShippedExtensions() async => false;

  @override
  Future<({bool complete, bool landed})> adoptTwins() async => (landed: false, complete: false);

  @override
  Future<void> reloadAvailableExtensions() async {}

  @override
  Future<void> restartRuntime({bool fresh = false}) async {}
}

/// Reachable, and publishing nothing — what a channel looks like before its
/// first release.
class _EmptyCatalog extends CatalogService {
  @override
  Future<List<CatalogEntry>?> fetchCatalog({OperatorGeo? geo, bool force = false}) async => const [];
}

void main() {
  testWidgets('the offer is raised from above the Navigator', (tester) async {
    final h = await makeHaLoServices(catalog: _ReachableCatalog());
    await h.settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'N0CALL');

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

    expect(find.text(t.extensionsPanel.upgradeTitle), findsOneWidget);

    // The release notes paint OVER this dialog on a launch that has both. A
    // barrier tap or Esc aimed at the notes must not pop the offer unseen as
    // "Later" — only its own buttons answer it.
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.text(t.extensionsPanel.upgradeTitle), findsOneWidget, reason: 'a barrier tap dismissed the offer');
  });

  testWidgets('an unreachable catalog raises no offer and says nothing', (tester) async {
    // At boot nobody is watching, and a dialog whose button cannot work is
    // worse than none: the offer is retried next launch.
    final h = await makeHaLoServices(catalog: _EmptyCatalog());
    await h.settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'N0CALL');

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

    expect(find.text(t.extensionsPanel.upgradeTitle), findsNothing);
    expect(h.settings.extensionsMigrated, isFalse);
  });

  testWidgets('a finished upgrade says so', (tester) async {
    // The operator agreed to an operation that withdraws the extensions they
    // had. Only the failure was ever reported, so a success looked exactly
    // like a dialog that had done nothing.
    final h = await makeHaLoServices(extensions: _MigrationSucceeds(), catalog: _ReachableCatalog());
    await h.settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'N0CALL');

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

    await tester.tap(find.text(t.extensionsPanel.upgradeAction));
    await tester.pumpAndSettle();

    expect(find.text(t.extensionsPanel.upgradeDoneTitle), findsOneWidget);
    expect(find.text(t.extensionsPanel.upgradeFailedTitle), findsNothing);
    // Exactly the body: nothing was lost, so nothing is listed as lost.
    expect(find.text(t.extensionsPanel.upgradeDoneBody), findsOneWidget);
    expect(h.settings.extensionsMigrated, isTrue);
  });

  testWidgets('a finished upgrade names what the catalog had no replacement for', (tester) async {
    // A built-in the catalog does not serve completes the upgrade instead of
    // failing it, so this dialog is the only moment the operator can learn
    // that something they had running is gone. Said by NAME: the key is
    // nothing they ever saw.
    final extensions = _MigrationSucceeds()
      ..debugSetAvailableExtensions(const [
        ExtensionInfo(key: 'qp', file: 'qp.js', core: false, name: 'QSO Parties'),
        ExtensionInfo(key: 'wca', file: 'wca.js', core: false, name: 'WCA'),
      ]);
    final h = await makeHaLoServices(extensions: extensions, catalog: _ReachableCatalog());
    await h.settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'N0CALL');

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

    await tester.tap(find.text(t.extensionsPanel.upgradeAction));
    await tester.pumpAndSettle();

    expect(find.text(t.extensionsPanel.upgradeDoneTitle), findsOneWidget);
    // WCA is not on the no-twin list, so it is not named whatever else is true.
    final lost = t.extensionsPanel.upgradeDoneUnserved(names: 'QSO Parties');
    expect(find.textContaining(lost), findsOneWidget);
    expect(find.textContaining(t.extensionsPanel.upgradeDoneUnservedHint), findsOneWidget);

    // Bold, because it is the one line the operator has to carry out of a
    // dialog that otherwise reads as reassurance.
    final spans = <InlineSpan>[];
    tester.widget<Text>(find.textContaining(lost)).textSpan!.visitChildren((span) {
      spans.add(span);
      return true;
    });
    final lostSpan = spans.whereType<TextSpan>().singleWhere((span) => span.text == lost);
    expect(lostSpan.style?.fontWeight, FontWeight.bold);
  });

  testWidgets('a built-in the operator had switched off is not named as lost', (tester) async {
    // The upgrade withdraws nothing the operator was running there, so naming
    // it would report a loss that was their own choice.
    final extensions = _MigrationSucceeds()..debugSetAvailableExtensions(const [ExtensionInfo(key: 'qp', file: 'qp.js', core: false, name: 'QSO Parties')]);
    final h = await makeHaLoServices(extensions: extensions, catalog: _ReachableCatalog());
    await h.settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'N0CALL');
    await h.settings.setExtensionOverrides({'qp': false});

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

    await tester.tap(find.text(t.extensionsPanel.upgradeAction));
    await tester.pumpAndSettle();

    expect(find.text(t.extensionsPanel.upgradeDoneBody), findsOneWidget);
  });

  testWidgets('an upgrade that did not finish says THAT, and withdraws nothing', (tester) async {
    // The two outcomes share one dialog, so a success-only reading of `done`
    // tells an operator whose extensions were NOT migrated that they are
    // ready — the worse of the two wrong answers, since the flag is reverted
    // underneath them and the built-ins are what they still have.
    final h = await makeHaLoServices(extensions: _MigrationFails(), catalog: _ReachableCatalog());
    await h.settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'N0CALL');

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

    await tester.tap(find.text(t.extensionsPanel.upgradeAction));
    await tester.pumpAndSettle();

    expect(find.text(t.extensionsPanel.upgradeFailedTitle), findsOneWidget);
    // The downloads are what did not arrive here, so this is the one arm that
    // may name the network. Told over a keychain refusal or a full disk it
    // sends the operator to fix a connection that was never the problem.
    expect(find.text(t.extensionsPanel.upgradeIncompleteBody), findsOneWidget);
    expect(find.text(t.extensionsPanel.upgradeDoneTitle), findsNothing);
    expect(h.settings.extensionsMigrated, isFalse, reason: 'a failed upgrade must leave the built-ins in use');
  });

  testWidgets('a runtime that would not start says so, and says the old extensions are back', (tester) async {
    // Told "your extensions are ready", the operator reads success over an
    // install running nothing at all. The upgrade reverts itself first, so
    // what this has to say is that the previous extensions are working.
    final h = await makeHaLoServices(extensions: _RuntimeDead(), catalog: _ReachableCatalog());
    await h.settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'N0CALL');

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
    await tester.tap(find.text(t.extensionsPanel.upgradeAction));
    await tester.pumpAndSettle();

    expect(find.text(t.extensionsPanel.upgradeRevertedTitle), findsOneWidget);
    expect(find.text(t.extensionsPanel.upgradeRevertedBody), findsOneWidget);
    expect(find.text(t.extensionsPanel.upgradeDoneTitle), findsNothing);
    expect(h.settings.extensionsMigrated, isFalse);
  });

  testWidgets('an outcome with no screen left to show it becomes a notice', (tester) async {
    // The operator agreed to an operation that withdraws their extensions,
    // and the screen the dialog would have used is gone — a rebuild, a hot
    // reload, navigation. Dropped here, nothing anywhere says what happened.
    final extensions = _SlowMigration()
      ..debugSetAvailableExtensions(const [
        ExtensionInfo(key: 'ki2d-my-clock', file: 'index.js', source: ExtensionSource.installed, core: false, name: 'Clock', version: '1.2.3'),
      ]);
    final h = await makeHaLoServices(extensions: extensions, catalog: _ReachableCatalog());
    await h.settings.setExtensionRefused({'ki2d-my-clock': '1.2.3'});
    await h.settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'N0CALL');

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
    await tester.tap(find.text(t.extensionsPanel.upgradeAction));
    await tester.pump();
    // Torn down while the migration is still running, so it answers into a
    // gate that is no longer on screen.
    await tester.pumpWidget(const SizedBox());
    extensions.release.complete();
    await tester.pumpAndSettle();

    expect(find.text(t.extensionsPanel.upgradeDoneTitle), findsNothing);
    final notice = h.services.statusBar.activeNotices.singleWhere((n) => n.key == 'extensions:upgradeResult');
    expect(notice.title, t.extensionsPanel.upgradeDoneTitle);
    // The notice stands in for the dialog, so it must not say less: what
    // stayed out of the runtime is the one line the operator has to carry
    // away, and a notice that dropped it would bury the loss in history.
    expect(notice.text, contains(t.extensionsPanel.upgradeDoneRefused(names: 'Clock')));
  });

  testWidgets('a notice for an upgrade that fell short still names what stayed out', (tester) async {
    // Only the done message was built with the names in it; every other
    // outcome is a plain sentence, and a notice that used that alone would
    // report the failure and bury the loss the operator most needs to know.
    final extensions = _SlowMigration(adoptionCompletes: false)
      ..debugSetAvailableExtensions(const [
        ExtensionInfo(key: 'ki2d-my-clock', file: 'index.js', source: ExtensionSource.installed, core: false, name: 'Clock', version: '1.2.3'),
      ]);
    final h = await makeHaLoServices(extensions: extensions, catalog: _ReachableCatalog());
    await h.settings.setExtensionRefused({'ki2d-my-clock': '1.2.3'});
    await h.settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'N0CALL');

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
    await tester.tap(find.text(t.extensionsPanel.upgradeAction));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    extensions.release.complete();
    await tester.pumpAndSettle();

    final notice = h.services.statusBar.activeNotices.singleWhere((n) => n.key == 'extensions:upgradeResult');
    expect(notice.title, t.extensionsPanel.upgradeFailedTitle);
    expect(notice.text, contains(t.extensionsPanel.upgradeDoneRefused(names: 'Clock')));
  });

  testWidgets('an empty catalog is not offered against', (tester) async {
    // `[]` is a reachable server with nothing on it, so an upgrade taken
    // against it fails — and the offer returns on the next launch, and the
    // one after that. Silence costs the operator nothing: the offer is made
    // again as soon as the channel has something to give them.
    final h = await makeHaLoServices(catalog: _EmptyCatalog());
    await h.settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'N0CALL');

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

    expect(find.text(t.extensionsPanel.upgradeTitle), findsNothing);
    expect(h.settings.extensionsMigrated, isFalse);
  });

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
  Future<List<CatalogEntry>?> fetchCatalog({OperatorGeo? geo, bool force = false}) async => [
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
