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
import 'package:ham2k_logger/services/installed_extensions.dart';
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
        rootOverride: Directory.systemTemp,
      ).inspect(bytes);

  /// Pumps the dialog alone. The picker and the install are not under test
  /// here; what the operator is shown is.
  Future<void> show(WidgetTester tester, InspectedBundle bundle, {bool replacing = false}) async {
    await tester.pumpWidget(TranslationProvider(
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
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('every domain the manifest asks for is named', (tester) async {
    final bundle = await inspect(withManifest((m) => {
          ...m,
          'domains': ['time.example.org', 'backup.example.org'],
        }));

    await show(tester, bundle);

    // Not a summary of its network access — this IS its network access, since
    // host.fetch permits nothing else. A domain missing from this list is a
    // domain the operator never agreed to and cannot discover.
    expect(find.text('time.example.org'), findsOneWidget);
    expect(find.text('backup.example.org'), findsOneWidget);
  });

  testWidgets('location and user-agent claims are named too', (tester) async {
    final bundle = await inspect(withManifest((m) => {
          ...m,
          'requiresLocation': true,
          'allowUserAgentOverride': true,
        }));

    await show(tester, bundle);

    expect(find.text(t.extensionsPanel.canUseLocation), findsOneWidget);
    expect(find.text(t.extensionsPanel.canSetUserAgent), findsOneWidget);
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

    await tester.pumpWidget(TranslationProvider(
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
    ));

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

    await tester.pumpWidget(TranslationProvider(
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
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // A bundle that arrived from a link is one the operator did not choose off
    // their own disk. Where it came from is most of what tells them whether to
    // trust it, so it is named on the screen rather than left implicit.
    expect(find.text(t.extensionsPanel.installedFrom(source: 'example.org')), findsOneWidget);
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
}
