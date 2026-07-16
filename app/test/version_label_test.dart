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
      packageName: 'com.ham2k.halo.prod',
      version: '0.1.0',
      buildNumber: '260807291',
      buildSignature: '',
    );
  });

  testWidgets('shows the version name and public version immediately, then appends the native build number',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VersionLabel()));

    // Before PackageInfo.fromPlatform() resolves, only the version name/public version are known.
    expect(find.text('$kVersionName · $kPublicVersion'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('$kVersionName · $kPublicVersion (build 260807291)'), findsOneWidget);
  });

  testWidgets('prefix is prepended to the version text', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VersionLabel(prefix: 'Version ')));

    expect(find.text('Version $kVersionName · $kPublicVersion'), findsOneWidget);
  });

  testWidgets('renders as selectable text', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VersionLabel()));

    expect(find.byType(SelectableText), findsOneWidget);
  });
}
