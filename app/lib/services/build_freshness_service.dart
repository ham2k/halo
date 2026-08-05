// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Web only: Cloudflare Pages caches flutter_service_worker.js for hours, so a
// browser tab can keep running an old build for a long time after a real
// deploy — the CDN dashboard shows the new version live while the page a user
// actually has open is stale, with no way for them to know. This polls a
// small deploy-stamped file (build_sha.txt, written by
// .github/workflows/deploy-web.yml) and compares it to this build's own
// baked-in kGitSha, prompting a reload the moment they genuinely differ —
// independent of whatever the browser's HTTP cache thinks is fresh, since the
// fetch itself is cache-busted per request.

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../config/build_reload.dart';
import '../config/version.dart';
import '../i18n/strings.g.dart';
import 'status_bar_service.dart';

/// Outcome of a [BuildFreshnessService.check] call.
enum BuildCheckResult { upToDate, updateAvailable, unknown }

class BuildFreshnessService with WidgetsBindingObserver {
  final StatusBarService statusBar;
  final http.Client _client;

  /// Overridable for tests; defaults to the real deployed path.
  final Uri Function() _urlBuilder;

  /// This build's own sha to compare against — overridable for tests, since
  /// kGitSha (like kIsWeb) can't be faked from a test binary; defaults to the
  /// real compile-time constant.
  final String _currentSha;

  static const _checkInterval = Duration(minutes: 10);
  static const noticeKey = 'build:stale';

  Timer? _timer;
  bool _notified = false;

  BuildFreshnessService({
    required this.statusBar,
    http.Client? client,
    Uri Function()? urlBuilder,
    String? currentSha,
  })  : _client = client ?? http.Client(),
        _urlBuilder = urlBuilder ??
            (() => Uri.base.resolve('build_sha.txt?_=${DateTime.now().millisecondsSinceEpoch}')),
        _currentSha = currentSha ?? kGitSha;

  /// No-op off the web (every other platform updates through its own
  /// channel) and for a local/dev build: no update prompt belongs in one, and
  /// there is usually nothing to compare against either (kGitSha is empty
  /// unless a build passes HALO_GIT_SHA, as only CI normally does). The
  /// build-mode guard is what still holds when a local build does pass one —
  /// its SHA differs from whatever is deployed, so the check would nag every
  /// ten minutes forever. Only the automatic polling is gated: the About
  /// panel's user-initiated check calls [check] directly and still answers.
  void start() {
    if (!kIsWeb || !kReleaseMode || _currentSha.isEmpty) return;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(_checkInterval, (_) => unawaited(check()));
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
  }

  /// Catches the common "left the tab open for hours, then came back" case
  /// immediately on refocus, rather than waiting for the next timer tick.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(check());
  }

  /// Public (not gated on kIsWeb, unlike [start]) both so tests can drive
  /// the actual comparison/notice logic directly — kIsWeb is never true in a
  /// test binary, so [start] itself can never be exercised there — and so
  /// the About panel's "Check for Updates" row can call it on a fresh
  /// instance per check, where its own [_notified] latch never suppresses a
  /// user-initiated re-check.
  Future<BuildCheckResult> check() async {
    if (_notified) return BuildCheckResult.updateAvailable;
    final String deployedSha;
    try {
      final response = await _client.get(_urlBuilder()).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return BuildCheckResult.unknown;
      deployedSha = response.body.trim();
    } catch (_) {
      // Best-effort: a network hiccup or a build predating this file (no
      // build_sha.txt yet) must not nag, and isn't worth reporting either —
      // this check runs every few minutes for the app's whole lifetime.
      return BuildCheckResult.unknown;
    }
    if (deployedSha.isEmpty) return BuildCheckResult.unknown;
    if (deployedSha == _currentSha) return BuildCheckResult.upToDate;
    _notified = true;
    statusBar.showNotice(
      key: noticeKey,
      icon: 'refresh',
      title: t.updates.updateAvailable,
      text: t.updates.reloadToUpdate,
      actions: [StatusBarAction(label: t.updates.reloadNow, onTap: reloadPage)],
      // Its whole point is the "Reload now" action, which can't survive the
      // very reload it triggers (a VoidCallback isn't serializable) —
      // persisting it just leaves a dead, button-less copy sitting in the
      // footer after every reload, looking exactly like it never worked.
      persist: false,
    );
    return BuildCheckResult.updateAvailable;
  }
}
