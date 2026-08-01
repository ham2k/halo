// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Feature flags — a port of app-polo's `fetchFeatureFlags`
// (src/store/system/fetchFeatureFlags.js). On startup, and whenever the
// active profile's callsign changes (NOT per operation), the app fetches a
// small set of JSON files from the flags server and deep-merges them into one
// `flags` map, most-specific-last so a per-callsign file overrides the
// defaults:
//
//   defaults.json                 — always
//   entities/<entityPrefix>.json  — for the operator's DXCC entity
//   <ab>/<baseCall>.json          — <ab> = first two chars of the base call
//   <ab>/<fullCall>.json          — if the entered call differs from the base
//
// A fetched file may point to further files via a `more` field (string or
// array), which are appended to the queue. Any file 404ing (most entity/call
// files don't exist) is simply skipped; a request *timeout* aborts the rest
// of the round, matching app-polo — a slow network shouldn't stall boot.
//
// The merged flags carry notices under `notices` (shared with app-polo) and
// `halo-notices` (HaLo-specific); after each refresh both are combined and run
// through the notice rule engine (see notices.dart) and the survivors pushed
// to the StatusBarService notice surface. Flags live in memory only (re-fetched
// each launch, like app-polo); the notices themselves persist once pushed.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:halo_build_tools/halo_build_tools.dart' show isNewerRelease;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/user_agent.dart';
import '../config/version.dart';
import '../i18n/strings.g.dart';
import 'notices.dart';
import 'status_bar_service.dart';

/// The default flags server. app-polo reads this from a build-time env var
/// (`POLO_FLAGS_BASE_URL`); HaLo has no such indirection, so it's a const
/// (overridable via the [FlagsService] constructor for tests).
const kFlagsBaseUrl = 'https://api.ham2k.net/flags';

const _maxRequestTime = Duration(seconds: 5);

/// Fetches one flags file by relative [location] (e.g. `defaults.json`),
/// returning its decoded JSON object, or null if it's missing/unparseable.
/// May throw [TimeoutException] to abort the whole round.
typedef FlagsFetcher = Future<Map<String, dynamic>?> Function(String location);

/// Annotates a callsign, returning the lookup `guess` (with `baseCall`,
/// `entityPrefix`, `continent`, `countryCode`, `ituRegion`…), or null if the
/// runtime can't answer. Wired to `ExtensionService.lookupCall(...,
/// online: false)` in the app.
typedef CallAnnotator = Future<Map<String, dynamic>?> Function(String call);

/// Invoked when the user taps a notice action button. [action] is the raw
/// descriptor (`{action, label, args, event}`); the handler owns the app-side
/// effect (open a link, show a dialog, navigate).
typedef NoticeActionHandler = void Function(String noticeKey, Map<String, dynamic> action);

/// The app/version/platform facts notice rules are matched against. Resolved
/// once per refresh; injectable so tests don't touch PackageInfo.
class NoticeEnvironment {
  final String appVersion;
  final String appVersionName;
  final String appBuild;
  final String platform;

  const NoticeEnvironment({
    required this.appVersion,
    required this.appVersionName,
    required this.appBuild,
    required this.platform,
  });
}

class FlagsService extends ChangeNotifier {
  /// Resolves the operator's callsign details. Null in tests that don't need
  /// entity/call-specific files (only defaults.json is then fetched).
  final CallAnnotator? annotate;

  /// Where dismissible notices are shown; server notices are pushed here.
  final StatusBarService statusBar;

  final String baseUrl;

  /// A caller-supplied fetcher (tests inject one); null means fetch over HTTP
  /// via [_httpFetch].
  final FlagsFetcher? _fetcher;
  final http.Client _client;
  final Future<NoticeEnvironment> Function() _environmentProvider;
  final NoticeActionHandler? _onNoticeAction;

  /// Persists the update-notice dismissal high-water mark ([_dismissedUpdateKey]).
  /// Optional — tests that don't exercise dismissal persistence omit it.
  final SharedPreferences? _prefs;

  /// Consent-gated analytics hook (HaLoServices.track) for notice_shown /
  /// notice_dismissed — optional so tests and standalone use stay silent.
  final void Function(String event, [Map<String, Object?> properties])? _onTrack;

  FlagsService({
    required this.statusBar,
    this.annotate,
    this.baseUrl = kFlagsBaseUrl,
    FlagsFetcher? fetcher,
    http.Client? client,
    Future<NoticeEnvironment> Function()? environmentProvider,
    NoticeActionHandler? onNoticeAction,
    SharedPreferences? prefs,
    void Function(String event, [Map<String, Object?> properties])? onTrack,
  })  : _fetcher = fetcher,
        _client = client ?? http.Client(),
        _environmentProvider = environmentProvider ?? _defaultEnvironment,
        _onNoticeAction = onNoticeAction,
        _prefs = prefs,
        _onTrack = onTrack;

  Map<String, dynamic> _flags = const {};

  /// The current merged flags. Empty until the first successful refresh.
  Map<String, dynamic> get flags => _flags;

  /// The raw callsign the current flags were fetched for — used to skip a
  /// redundant refresh when the callsign hasn't changed.
  String? _lastFetchedCall;

  bool _refreshing = false;

  /// A callsign whose refresh was requested while another was in flight — run
  /// once the current one settles so a fast callsign edit isn't dropped.
  String? _pendingCall;
  bool _pendingForce = false;

  /// Fetches and merges the flags for [call] (the active profile callsign),
  /// then evaluates and pushes any notices. A no-op if [call] matches the
  /// last-fetched callsign, unless [force]. Never throws — network and parse
  /// failures leave the previous flags in place.
  Future<void> refreshForCall(String call, {bool force = false}) async {
    final normalizedCall = call.trim().toUpperCase();
    if (!force && normalizedCall == _lastFetchedCall) return;
    // Only one round runs at a time (concurrent fetches would race on
    // `_flags`); a request arriving mid-round is remembered and run after.
    if (_refreshing) {
      _pendingCall = normalizedCall;
      _pendingForce = _pendingForce || force;
      return;
    }
    _refreshing = true;

    try {
      final guess = normalizedCall.isEmpty ? null : await _annotateSafely(normalizedCall);
      final baseCall = (guess?['baseCall'] as String?)?.toUpperCase() ?? normalizedCall;
      final entityPrefix = guess?['entityPrefix'] as String?;
      final continent = guess?['continent'] as String?;
      final countryCode = guess?['countryCode'] as String?;
      final ituRegion = (guess?['ituRegion'] as num?)?.toInt();

      final merged = await _fetchAndMerge(normalizedCall, baseCall: baseCall, entityPrefix: entityPrefix);

      // Every request failed (offline, or the server is down) — keep the
      // flags we already have rather than clobbering them with an empty map,
      // and don't record this callsign as fetched so the next trigger (or
      // next boot) retries. A partial result (defaults fetched but a per-call
      // file 404'd/timed out) still commits — that's real, current data.
      if (merged == null) {
        debugPrint('[flags] no flags fetched (offline?), keeping previous flags');
        return;
      }

      _flags = merged;
      _lastFetchedCall = normalizedCall;
      notifyListeners();

      await _pushNotices(
        call: normalizedCall,
        baseCall: baseCall,
        entityPrefix: entityPrefix,
        continent: continent,
        countryCode: countryCode,
        ituRegion: ituRegion,
      );
    } catch (e) {
      debugPrint('[flags] refresh failed: $e');
    } finally {
      _refreshing = false;
      final pending = _pendingCall;
      final pendingForce = _pendingForce;
      _pendingCall = null;
      _pendingForce = false;
      if (pending != null && (pendingForce || pending != _lastFetchedCall)) {
        unawaited(refreshForCall(pending, force: pendingForce));
      }
    }
  }

  Future<Map<String, dynamic>?> _annotateSafely(String call) async {
    final annotate = this.annotate;
    if (annotate == null) return null;
    try {
      return await annotate(call);
    } catch (e) {
      debugPrint('[flags] callsign annotation failed: $e');
      return null;
    }
  }

  /// Fetches and deep-merges the flag files for [call]. Returns null if NOT
  /// A SINGLE file could be fetched (total failure — likely offline), so the
  /// caller can preserve the previous flags instead of overwriting them.
  Future<Map<String, dynamic>?> _fetchAndMerge(
    String call, {
    required String baseCall,
    String? entityPrefix,
  }) async {
    final locations = <String>['defaults.json'];
    if (call.isNotEmpty) {
      final cleanCall = _clean(call);
      final cleanBaseCall = _clean(baseCall);
      final folder = cleanBaseCall.length >= 2 ? cleanBaseCall.substring(0, 2) : cleanBaseCall;
      if (entityPrefix != null && entityPrefix.isNotEmpty) {
        locations.add('entities/${_clean(entityPrefix)}.json');
      }
      if (cleanCall != cleanBaseCall) locations.add('$folder/$cleanBaseCall.json');
      if (cleanCall.isNotEmpty) locations.add('$folder/$cleanCall.json');
    }

    var flags = <String, dynamic>{};
    final fetched = <String>{};
    var successCount = 0;
    while (locations.isNotEmpty) {
      final location = locations.removeAt(0);
      if (!fetched.add(location)) continue;

      Map<String, dynamic>? data;
      try {
        data = await (_fetcher ?? _httpFetch)(location);
      } on TimeoutException {
        // A timeout aborts the whole round (app-polo re-raises to stop all
        // further fetches) — the network is slow, don't compound the wait.
        debugPrint('[flags] timed out fetching $location, stopping');
        break;
      } catch (e) {
        debugPrint('[flags] error fetching $location: $e');
        continue;
      }
      // Null is a missing file (e.g. a 404 for an absent per-entity/per-call
      // file) — normal, not a failure. Only a successful body counts toward
      // "we reached the server".
      if (data == null) continue;
      successCount++;

      final more = data['more'];
      if (more is String) {
        if (!fetched.contains(more)) locations.add(more);
      } else if (more is List) {
        for (final item in more) {
          if (item is String && !fetched.contains(item)) locations.add(item);
        }
      }

      flags = _deepMerge(flags, data);
    }
    return successCount == 0 ? null : flags;
  }

  Future<void> _pushNotices({
    required String call,
    required String baseCall,
    String? entityPrefix,
    String? continent,
    String? countryCode,
    int? ituRegion,
  }) async {
    final env = await _environmentProvider();
    final dismissedKeys = {
      for (final n in statusBar.history)
        if (n.dismissedAt != null) n.key,
    };
    final active = {for (final n in statusBar.activeNotices) n.key};

    // A binary release newer than the running one (the `latestRelease` flag)
    // gets its own dismissible "update available" notice — independent of the
    // server-authored notices below, and separate from the Shorebird patch
    // prompt (update_notices.dart), which is about the SAME version.
    _maybePushNewVersionNotice(env, active);

    // Notices come from a HaLo-specific `halo-notices` key plus the shared
    // `notices` key (cross-app, authored for app-polo too). `halo-notices`
    // come FIRST so they take precedence: evaluateNotices keeps the first
    // matching notice per key, so a HaLo notice shadows a shared one that
    // reuses its key. Keeping the keys separate also lets a flags file target
    // one app without the other picking up its notices.
    final rawNotices = [
      for (final key in const ['halo-notices', 'notices'])
        if (_flags[key] is List) ...(_flags[key] as List),
    ];
    if (rawNotices.isEmpty) return;

    final evaluated = evaluateNotices(
      rawNotices,
      NoticeContext(
        baseCall: baseCall,
        call: call,
        entityPrefix: entityPrefix,
        continent: continent,
        countryCode: countryCode,
        ituRegion: ituRegion,
        appVersion: env.appVersion,
        appVersionName: env.appVersionName,
        appBuild: env.appBuild,
        platform: env.platform,
        dismissedKeys: dismissedKeys,
      ),
    );

    // evaluateNotices already returns at most one notice per key, so no
    // per-key de-dup is needed here — just skip keyless notices (StatusBar is
    // keyed) and ones already on screen.
    for (final notice in evaluated) {
      final key = notice.key;
      if (key.isEmpty) continue;
      // Already on screen and not dismissed — leave it be rather than
      // resetting its position/timestamp on every refresh.
      if (active.contains(key)) continue;

      _onTrack?.call('notice_shown', {'notice_key': key});
      statusBar.showNotice(
        key: key,
        icon: notice.icon,
        title: notice.title,
        text: notice.text,
        actions: [
          for (final action in notice.actions)
            StatusBarAction(
              label: (action['label'] as String?) ?? t.updates.ok,
              onTap: () {
                _onTrack?.call('notice_dismissed', {'notice_key': key});
                statusBar.dismissNotice(key);
                _onNoticeAction?.call(key, action);
              },
            ),
        ],
      );
    }
  }

  /// Stable status-bar key for the "update available" notice — NOT
  /// version-specific, so a newer release replaces the notice rather than
  /// stacking a second one.
  static const _updateNoticeKey = 'update:version';

  /// prefs keys: the version currently shown, and the newest one the user has
  /// dismissed (the durable high-water mark).
  static const _shownUpdateKey = 'update:shownVersion';
  static const _dismissedUpdateKey = 'update:dismissedVersion';

  /// Pushes an "update available" notice when the `latestRelease` flag names a
  /// binary newer than the running version. Dismissal is remembered in prefs
  /// (the status-bar history is capped at 50, so it can't be the durable
  /// record): the version showing when the user dismisses becomes a high-water
  /// mark, and only a release newer than that ever notifies again. "Get it"
  /// opens `latestReleaseUrl` (or the Ham2K site) via the shared link action.
  void _maybePushNewVersionNotice(NoticeEnvironment env, Set<String> active) {
    final latest = _flags['latestRelease'];
    if (latest is! String || latest.isEmpty) return;
    if (!isNewerRelease(current: env.appVersion, available: latest)) return;

    // Promote a just-dismissed notice into the durable high-water mark before
    // it can age out of the capped history.
    final shown = _prefs?.getString(_shownUpdateKey);
    final dismissedInBar = statusBar.history
        .any((n) => n.key == _updateNoticeKey && n.dismissedAt != null);
    if (shown != null && dismissedInBar) {
      final mark = _prefs?.getString(_dismissedUpdateKey);
      if (mark == null || isNewerRelease(current: mark, available: shown)) {
        _prefs?.setString(_dismissedUpdateKey, shown);
      }
      _prefs?.remove(_shownUpdateKey);
    }

    // Already dismissed this release (or a newer one)? Stay quiet.
    final dismissed = _prefs?.getString(_dismissedUpdateKey);
    if (dismissed != null && !isNewerRelease(current: dismissed, available: latest)) {
      return;
    }

    // Already showing this exact release — don't reset it on every refresh. A
    // newer release falls through and replaces the notice via the shared key.
    if (active.contains(_updateNoticeKey) && shown == latest) return;

    final rawUrl = _flags['latestReleaseUrl'];
    final url = (rawUrl is String && rawUrl.isNotEmpty) ? rawUrl : 'https://ham2k.com';

    _prefs?.setString(_shownUpdateKey, latest);
    statusBar.showNotice(
      key: _updateNoticeKey,
      icon: 'download',
      title: t.updates.updateAvailable,
      text: t.updates.newVersionAvailable(version: latest),
      actions: [
        StatusBarAction(
          label: t.updates.getIt,
          onTap: () {
            statusBar.dismissNotice(_updateNoticeKey);
            _onNoticeAction?.call(_updateNoticeKey, {
              'action': 'link',
              'args': {'url': url},
            });
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  static String _clean(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');

  static Map<String, dynamic> _deepMerge(Map<String, dynamic> a, Map<String, dynamic> b) {
    final result = <String, dynamic>{...a};
    b.forEach((key, bv) {
      final av = result[key];
      if (av is Map<String, dynamic> && bv is Map) {
        result[key] = _deepMerge(av, bv.cast<String, dynamic>());
      } else if (av is List && bv is List) {
        // Arrays concatenate (deepmerge's default) — so `notices` from
        // defaults + the per-call file accumulate rather than replace.
        result[key] = [...av, ...bv];
      } else {
        result[key] = bv;
      }
    });
    return result;
  }

  /// The default HTTP fetcher. Throws [TimeoutException] on a slow request
  /// (aborting the round) and returns null for a non-200 or non-object body.
  /// Sends the canonical HaLo User-Agent like every other core network call
  /// (docs/design/network.md); the fallback resolver never throws, so a
  /// missing build number can't block a flag fetch.
  Future<Map<String, dynamic>?> _httpFetch(String location) async {
    final response = await _client
        .get(Uri.parse('$baseUrl/$location'), headers: {'User-Agent': await ham2kUserAgentOrFallback()})
        .timeout(_maxRequestTime);
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    return decoded is Map ? decoded.cast<String, dynamic>() : null;
  }

  static Future<NoticeEnvironment> _defaultEnvironment() async {
    String platform;
    if (kIsWeb) {
      platform = 'web';
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
          platform = 'ios';
        case TargetPlatform.android:
          platform = 'android';
        case TargetPlatform.macOS:
          platform = 'macos';
        case TargetPlatform.windows:
          platform = 'windows';
        case TargetPlatform.linux:
          platform = 'linux';
        default:
          platform = defaultTargetPlatform.name.toLowerCase();
      }
    }
    String build = '';
    try {
      build = (await PackageInfo.fromPlatform()).buildNumber;
    } catch (e) {
      debugPrint('[flags] could not read build number: $e');
    }
    return NoticeEnvironment(
      appVersion: kPublicVersion,
      appVersionName: kVersionName,
      appBuild: build,
      platform: platform,
    );
  }
}
