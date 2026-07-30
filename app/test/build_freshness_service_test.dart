// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// kIsWeb (like kGitSha) can never be true in a test binary, so start()
// itself is untestable here — these drive check() directly instead (see its
// @visibleForTesting doc), pinning the actual comparison/notice logic.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/services/build_freshness_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<StatusBarService> makeStatusBar() async {
    SharedPreferences.setMockInitialValues({});
    return StatusBarService(await SharedPreferences.getInstance());
  }

  BuildFreshnessService makeService({
    required StatusBarService statusBar,
    required String deployedSha,
    String currentSha = 'aaa1111',
    int statusCode = 200,
  }) {
    return BuildFreshnessService(
      statusBar: statusBar,
      currentSha: currentSha,
      client: MockClient((request) async => http.Response(deployedSha, statusCode)),
    );
  }

  test('a matching deployed sha posts no notice', () async {
    final statusBar = await makeStatusBar();
    final service = makeService(statusBar: statusBar, deployedSha: 'aaa1111', currentSha: 'aaa1111');

    await service.check();

    expect(statusBar.activeNotices.where((n) => n.key == BuildFreshnessService.noticeKey), isEmpty);
  });

  test('a different deployed sha posts a reload notice', () async {
    final statusBar = await makeStatusBar();
    final service = makeService(statusBar: statusBar, deployedSha: 'bbb2222', currentSha: 'aaa1111');

    await service.check();

    final notices = statusBar.activeNotices.where((n) => n.key == BuildFreshnessService.noticeKey);
    expect(notices, hasLength(1));
    expect(notices.single.actions.map((a) => a.label), contains('Reload now'));
  });

  test('an empty deployed sha (build predates build_sha.txt) posts no notice', () async {
    final statusBar = await makeStatusBar();
    final service = makeService(statusBar: statusBar, deployedSha: '', currentSha: 'aaa1111');

    await service.check();

    expect(statusBar.activeNotices.where((n) => n.key == BuildFreshnessService.noticeKey), isEmpty);
  });

  test('a non-200 response posts no notice', () async {
    final statusBar = await makeStatusBar();
    final service = makeService(statusBar: statusBar, deployedSha: 'bbb2222', currentSha: 'aaa1111', statusCode: 404);

    await service.check();

    expect(statusBar.activeNotices.where((n) => n.key == BuildFreshnessService.noticeKey), isEmpty);
  });

  test('only ever posts once — a later check does not stack a second notice', () async {
    final statusBar = await makeStatusBar();
    final service = makeService(statusBar: statusBar, deployedSha: 'bbb2222', currentSha: 'aaa1111');

    await service.check();
    await service.check();

    expect(statusBar.activeNotices.where((n) => n.key == BuildFreshnessService.noticeKey), hasLength(1));
  });

  test('the reload notice does not survive the reload it triggers', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final statusBar = StatusBarService(prefs);
    final service = makeService(statusBar: statusBar, deployedSha: 'bbb2222', currentSha: 'aaa1111');

    await service.check();
    // "Reload now" reloads the page, which for a real browser tears down
    // this whole process — simulate that by reading history back from the
    // same SharedPreferences-backed store into a fresh instance.
    final afterReload = StatusBarService(prefs);

    expect(afterReload.activeNotices.where((n) => n.key == BuildFreshnessService.noticeKey), isEmpty);
  });

  test('a network failure is swallowed, not thrown', () async {
    final statusBar = await makeStatusBar();
    final service = BuildFreshnessService(
      statusBar: statusBar,
      currentSha: 'aaa1111',
      client: MockClient((request) async => throw Exception('network down')),
    );

    await service.check();

    expect(statusBar.activeNotices.where((n) => n.key == BuildFreshnessService.noticeKey), isEmpty);
  });
}
