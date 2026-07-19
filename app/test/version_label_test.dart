// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/config/version.dart';
import 'package:ham2k_logger/views/version_label.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Ham2K Logger',
      packageName: 'com.ham2k.logger.dev',
      version: '0.1.0',
      buildNumber: '260807291',
      buildSignature: '',
    );
  });

  test('the default (unset HALO_EDITION) build is the Dev edition, and its name carries the qualifier', () {
    // `flutter test` runs with no --dart-define, so the tree resolves to the
    // safe, non-distributed edition — and its qualifier is what makes a dev
    // build visibly distinct from a Regular one in the UI (docs/releases.md §2.6).
    expect(kEdition, Edition.dev);
    expect(kEditionVersionName, '$kVersionName (Dev)');
  });

  testWidgets('shows the version name and public version immediately, then appends the native build number',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VersionLabel()));

    // Before PackageInfo.fromPlatform() resolves, only the version name/public version are known.
    expect(find.text('$kEditionVersionName · $kPublicVersion'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('$kEditionVersionName · $kPublicVersion (build 260807291)'), findsOneWidget);
  });

  testWidgets('prefix is prepended to the version text', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VersionLabel(prefix: 'Version ')));

    expect(find.text('Version $kEditionVersionName · $kPublicVersion'), findsOneWidget);
  });

  testWidgets('renders as selectable text', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VersionLabel()));

    expect(find.byType(SelectableText), findsOneWidget);
  });

  testWidgets('detailed mode splits into two lines — version name, then "Version x.y.z[ - Build n]"',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VersionLabel(detailed: true)));
    await tester.pumpAndSettle();

    // find.text() (rather than reading each SelectableText's own `data`)
    // proved order-dependent on the shared, module-cached PackageInfo future
    // this file's other tests also resolve — reading the two SelectableText
    // widgets directly sidesteps that. The build-number suffix itself is
    // already covered by the non-detailed test above (same snapshot logic,
    // just a different template), so this only pins down what's new here:
    // two lines, the first being the bare version name.
    final lines = tester.widgetList<SelectableText>(find.byType(SelectableText)).map((w) => w.data).toList();
    expect(lines, hasLength(2));
    expect(lines[0], kEditionVersionName);
    expect(lines[1], startsWith('Version $kPublicVersion'));
  });

  testWidgets('detailed mode\'s second line is smaller than the first', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: VersionLabel(detailed: true, style: TextStyle(fontSize: 15))),
    );
    await tester.pumpAndSettle();

    final lines = tester.widgetList<SelectableText>(find.byType(SelectableText)).toList();
    expect(lines, hasLength(2));
    expect(lines[0].style?.fontSize, 15);
    expect(lines[1].style?.fontSize, lessThan(lines[0].style!.fontSize!));
  });

  testWidgets('detailed + boldFirstLine: name is bold, detail is normal weight and exactly two points smaller',
      (tester) async {
    // The About row's intent (Issue #42): the version name reads as the
    // heading, the "Version … - Build …" detail as secondary — normal weight,
    // two points smaller than the name.
    await tester.pumpWidget(
      const MaterialApp(
        home: VersionLabel(
          detailed: true,
          boldFirstLine: true,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final lines = tester.widgetList<SelectableText>(find.byType(SelectableText)).toList();
    expect(lines[0].style?.fontWeight, FontWeight.bold);
    expect(lines[0].style?.fontSize, 16);
    expect(lines[1].style?.fontWeight, FontWeight.normal);
    expect(lines[1].style?.fontSize, 14);
  });

  testWidgets('nameOnly shows just the release name — no edition qualifier, no detail line', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VersionLabel(nameOnly: true)));
    await tester.pumpAndSettle();

    // The bare release name (kVersionName), NOT the edition-qualified name —
    // the edition is shown separately by the badge SVG (docs/releases.md §2.6) —
    // and none of the detailed mode's "Version … - Build …" line.
    expect(find.text(kVersionName), findsOneWidget);
    expect(find.text(kEditionVersionName), findsNothing);
    expect(find.textContaining('Version '), findsNothing);
  });
}
