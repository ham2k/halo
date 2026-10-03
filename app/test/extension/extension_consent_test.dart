// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The install-consent dialog (HALO-422).
//
// This screen is the whole of what stands between a file from anyone and code
// the app will run, so what it SAYS is the feature. A dialog that renders but
// omits a capability is worse than no dialog: it is a dialog people learned to
// trust.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/extensions/bundle_storage_io.dart';
import 'package:ham2k_logger/services/extensions/installed_extensions.dart';
import 'package:ham2k_logger/views/extension_install_flow.dart';

void main() {
  late List<int> fixture;

  setUpAll(() => LocaleSettings.setLocaleRaw('en'));
  setUp(() => fixture = File('test/fixtures/ki2d-my-clock.h2kext').readAsBytesSync());

  /// The fixture's manifest, rewritten — the capability combinations a single
  /// packaged file cannot cover.
  List<int> withManifest(Map<String, dynamic> Function(Map<String, dynamic>) edit) {
    final archive = ZipDecoder().decodeBytes(fixture);
    final out = Archive();
    for (final file in archive.files) {
      if (file.name == 'manifest.json') {
        final manifest = edit(jsonDecode(utf8.decode(file.content as List<int>)) as Map<String, dynamic>);
        final bytes = utf8.encode(jsonEncode(manifest));
        out.addFile(ArchiveFile('manifest.json', bytes.length, bytes));
      } else {
        out.addFile(file);
      }
    }
    return ZipEncoder().encode(out);
  }

  Future<InspectedBundle> inspect(List<int> bytes) => InstalledExtensions(
    builtInKeys: () => const {},
    hostSharedModules: const {'i18next': '23.11.5'},
    storage: FileBundleStorage(root: Directory.systemTemp),
  ).inspect(bytes);

  /// Pumps the dialog alone. The picker and the install are not under test
  /// here; what the operator is shown is.
  Future<void> show(WidgetTester tester, InspectedBundle bundle, {bool replacing = false}) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showConsentDialog(context, bundle: bundle, replacing: replacing),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('every domain the manifest asks for is named', (tester) async {
    final bundle = await inspect(
      withManifest(
        (m) => {
          ...m,
          'domains': ['time.example.org', 'backup.example.org'],
        },
      ),
    );

    await show(tester, bundle);

    // Not a summary of its network access — this IS its network access, since
    // host.fetch permits nothing else. A domain missing from this list is a
    // domain the operator never agreed to and cannot discover.
    expect(find.text('time.example.org'), findsOneWidget);
    expect(find.text('backup.example.org'), findsOneWidget);
  });

  testWidgets('every host it may hold a connection to is named, on its own', (tester) async {
    // A socket grant with no fetch grant beside it: an extension claiming only
    // this must not be presented as asking for nothing.
    final bundle = await inspect(
      withManifest(
        (m) => {
          ...m,
          'domains': <String>[],
          'webSockets': ['stream.example.org'],
        },
      ),
    );

    await show(tester, bundle);

    expect(find.text(t.extensionsPanel.noCapabilities), findsNothing);
    expect(find.text(t.extensionsPanel.canHoldConnection(host: 'stream.example.org')), findsOneWidget);
  });

  testWidgets('the local entry reads as the local network, not as a host called "local"', (tester) async {
    // It admits every private address there is, which a line reading "local"
    // would hide from the operator agreeing to it.
    await show(
      tester,
      await inspect(
        withManifest(
          (m) => {
            ...m,
            'domains': <String>[],
            'webSockets': <String>['local'],
          },
        ),
      ),
    );

    expect(find.text(t.extensionsPanel.canHoldLocalConnection), findsOneWidget);
    expect(find.text(t.extensionsPanel.canHoldConnection(host: 'local')), findsNothing);
  });

  testWidgets('location and user-agent claims are named too', (tester) async {
    final bundle = await inspect(withManifest((m) => {...m, 'requiresLocation': true, 'allowUserAgentOverride': true}));

    await show(tester, bundle);

    expect(find.text(t.extensionsPanel.canUseLocation), findsOneWidget);
    expect(find.text(t.extensionsPanel.canSetUserAgent), findsOneWidget);
  });

  // Commanding the radio is the claim an operator most needs to see before
  // agreeing: it retunes the rig and can drop the CAT link mid-QSO.
  testWidgets('a claim to command the radio is named, in place of the read it implies', (tester) async {
    await show(tester, await inspect(withManifest((m) => {...m, 'domains': <String>[], 'requiresRadioWrite': true})));

    expect(find.text(t.extensionsPanel.noCapabilities), findsNothing);
    expect(find.text(t.extensionsPanel.canControlRadio), findsOneWidget);
    expect(find.text(t.extensionsPanel.canReadRadio), findsNothing);
  });

  testWidgets('a claim to read the radio is named, and does not read as control', (tester) async {
    await show(tester, await inspect(withManifest((m) => {...m, 'domains': <String>[], 'requiresRadioRead': true})));

    expect(find.text(t.extensionsPanel.canReadRadio), findsOneWidget);
    expect(find.text(t.extensionsPanel.canControlRadio), findsNothing);
  });

  testWidgets('an extension asking for nothing says so, rather than showing an empty list', (tester) async {
    final bundle = await inspect(withManifest((m) => {...m, 'domains': <String>[]}));

    await show(tester, bundle);

    // A bundle claiming nothing must not be dressed up as though it did — an
    // empty "can reach" heading reads as though something were hidden.
    expect(find.text(t.extensionsPanel.noCapabilities), findsOneWidget);
    expect(find.text(t.extensionsPanel.canReach), findsNothing);
  });

  testWidgets('the identity is shown, so the name in the title is checkable', (tester) async {
    await show(tester, await inspect(fixture));

    expect(find.textContaining('KI2D My Clock'), findsWidgets);
    expect(find.text(t.extensionsPanel.installVersion(version: '1.2.3')), findsOneWidget);
    expect(find.text('A clock'), findsOneWidget);
  });

  testWidgets('installing answers true; cancelling answers false', (tester) async {
    final bundle = await inspect(fixture);
    bool? answer;

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async => answer = await showConsentDialog(context, bundle: bundle, replacing: false),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.extensionsPanel.installAction));
    await tester.pumpAndSettle();
    expect(answer, isTrue);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.common.cancel));
    await tester.pumpAndSettle();
    // Dismissing must never read as agreement — the whole point of asking.
    expect(answer, isFalse);
  });

  testWidgets('a bundle from a link names where it came from', (tester) async {
    final bundle = await inspect(fixture);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showConsentDialog(context, bundle: bundle, replacing: false, from: 'example.org'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // A bundle that arrived from a link is one the operator did not choose off
    // their own disk. Where it came from is most of what tells them whether to
    // trust it, so it is named on the screen rather than left implicit.
    expect(find.text(t.extensionsPanel.installedFrom(source: 'example.org')), findsOneWidget);
  });

  testWidgets('a release that is not stable is warned about, by how rough it is; a stable one is not', (tester) async {
    // Every other line on this screen reads the same for a finished release
    // and an unfinished one, so the warning is the only thing telling the
    // operator what they are agreeing to run. Warning over stable too would
    // teach them to read past it.
    final bundle = await inspect(fixture);
    CatalogChannel? channel;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showConsentDialog(context, bundle: bundle, replacing: false, from: kCatalogHost, channel: channel),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    Future<void> open(CatalogChannel? asked) async {
      channel = asked;
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> close() async {
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
    }

    await open(CatalogChannel.unstable);
    expect(find.text(t.extensionsPanel.unstableReleaseWarning), findsOneWidget);
    await close();
    await open(CatalogChannel.bleeding);
    expect(find.text(t.extensionsPanel.bleedingReleaseWarning), findsOneWidget);
    await close();
    await open(CatalogChannel.stable);
    expect(find.byType(PreReleaseWarning), findsNothing);
    await close();
    await open(null);
    expect(find.byType(PreReleaseWarning), findsNothing);
  });

  testWidgets('a bundle picked off disk names no source', (tester) async {
    await show(tester, await inspect(fixture));

    expect(find.textContaining('Downloaded from'), findsNothing);
  });

  testWidgets('an update says update, not install', (tester) async {
    final bundle = await inspect(fixture);

    await show(tester, bundle, replacing: true);

    expect(find.text(t.extensionsPanel.updateAction), findsOneWidget);
    expect(find.text(t.extensionsPanel.installAction), findsNothing);
  });

  testWidgets('an install of a key already under way is refused before anything is written', (tester) async {
    // Two installs of one key overlapping land whichever finishes last: a
    // file dropped over a catalog update still downloading is overwritten by
    // the older catalog bytes, with no consent screen under Update all.
    final store = InstalledExtensions(
      builtInKeys: () => const {},
      hostSharedModules: const {'i18next': '23.11.5'},
      storage: FileBundleStorage(root: Directory.systemTemp),
    );
    var commits = 0;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () =>
                    installExtensionFromBytes(context, store: store, read: () async => fixture, commit: (_) async => commits++, isBusy: (_) => true),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('is already being installed'), findsOneWidget);
    // Refused ahead of the consent screen: agreeing to something that cannot
    // then happen is a question the operator should never be asked.
    expect(find.widgetWithText(FilledButton, t.extensionsPanel.installAction), findsNothing);
    expect(commits, 0);
  });
}
