// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The host call REPORT reads before it files anything: `getVersionInfo`.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/config/user_agent.dart';
import 'package:ham2k_logger/config/version.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // No start(): getVersionInfo answers from compiled-in constants and never
  // touches the runtime, so booting QuickJS here would cost more than the
  // tests themselves.
  late ExtensionService extensions;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    extensions = ExtensionService();
  });

  group('getVersionInfo', () {
    test('answers every field the SDK VersionInfo interface declares', () async {
      // The extension reads these by name into the report body (report.ts); a
      // renamed or dropped key becomes the literal string "undefined" on a
      // filed card rather than any kind of error.
      final result = await extensions.debugHandleHostCall('getVersionInfo', {}) as Map;

      // Values, not just types: swapping `version` and `versionName` keeps five
      // isA<String>() assertions green while every filed card reads them
      // inverted, and report.test.ts cannot catch it — it supplies its own
      // fixture, so this is the only place the real values are observable.
      expect(result['platform'], platformName());
      expect(result['edition'], kEdition.name);
      expect(result['version'], kPublicVersion);
      expect(result['versionName'], kEditionVersionName);
      expect(result['gitSha'], kGitSha);
    });

    test('omits the build number on Dev, and reports it everywhere else', () async {
      // kBuildNumber on Dev is the last RELEASE's number, not the running
      // build's — the same suppression version_label and flags_service apply.
      // Reporting it would put a confidently wrong build on every card filed
      // from a local run, a preview deploy, or the hosted web app.
      //
      // Both directions are asserted against the SAME expression the code
      // should be using. Branching on `result['edition']` instead would key the
      // expectation off the value under test, and since `flutter test` always
      // compiles as Dev the release branch would never run at all.
      final result = await extensions.debugHandleHostCall('getVersionInfo', {}) as Map;
      expect(result['buildNumber'], kEdition == Edition.dev ? isNull : kBuildNumber);
    });
  });
}
