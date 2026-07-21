// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The patch-ready notice adapts to the platform: desktop can relaunch itself, so
// it offers a "Restart now" button; mobile can't, so the notice is purely
// informational. These verify that branching without ever tapping the button
// (which would actually try to restart the process).

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/restart_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:ham2k_logger/services/update_notices.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StatusBarService statusBar;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    statusBar = StatusBarService(await SharedPreferences.getInstance());
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('desktop offers a "Restart now" button', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    showPatchReadyNotice(statusBar, const RestartService());

    final notice = statusBar.activeNotices.single;
    expect(notice.key, patchReadyNoticeKey);
    expect(notice.title, 'Update ready');
    expect(notice.text, contains('Restart to apply'));
    expect(notice.actions.single.label, 'Restart now');
  });

  test('mobile is informational only — no restart button', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    showPatchReadyNotice(statusBar, const RestartService());

    final notice = statusBar.activeNotices.single;
    expect(notice.actions, isEmpty);
    expect(notice.text, contains('next time you'));
  });
}
