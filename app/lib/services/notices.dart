// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The server-notice rule engine — a straight port of app-polo's `useNotices`
// (src/store/system/useNotices.js). Feature-flag files (see FlagsService)
// can carry a `notices` array; each entry declares who should see it
// (platform/version/build/callsign/DXCC-entity/continent, a date window, and
// a pseudo-random "segment" bucket for staged rollouts). This module applies
// those rules against the current operator + app context and returns the
// notices that pass, adjusted (platform-specific keys resolved, template
// variables substituted) and sorted by priority.
//
// Kept as a pure, UI-free, runtime-free function so it can be unit-tested
// without a JS runtime, a network, or a widget tree — FlagsService calls it
// after each merge and pushes the survivors to the StatusBarService notice
// surface. Rules that need data HaLo can't derive from the bundled country
// file (`countries` → ISO country code, `ituRegions`, `notes` → the
// call-notes extension) are intentionally treated as non-matching: a notice
// gated on one of them simply never shows, the same safe direction as a user
// whose value isn't in the list.

/// The operator + app facts the notice rules are evaluated against. Mirrors
/// app-polo's `templateData.operator`/`app` plus the callsign-derived filter
/// inputs. Geo fields come from the callsign-annotation guess (bundled
/// country file); [countryCode] and [ituRegion] are unavailable in HaLo and
/// left null on purpose (see the file header).
class NoticeContext {
  /// The operator's base callsign, uppercased (e.g. `KI2D`), or empty.
  final String baseCall;

  /// The full operator callsign as entered (e.g. `KI2D/P`).
  final String call;

  /// DXCC entity prefix from the country-file annotation (e.g. `K`).
  final String? entityPrefix;

  /// Continent code from the country-file annotation (e.g. `NA`).
  final String? continent;

  /// The app's public version string (e.g. `26.8.0`) — matched against
  /// `versions`/`exceptVersions` with `startsWith`, as app-polo does.
  final String appVersion;

  /// A human display name for the version (`app.versionName` in templates).
  final String appVersionName;

  /// The native build number (e.g. `1234`) — matched exactly against
  /// `builds`/`exceptBuilds`.
  final String appBuild;

  /// Lowercase platform token: `ios`, `android`, `macos`, `windows`,
  /// `linux`, or `web`. Used for the `platforms` filter and `-<platform>`
  /// key suffixes.
  final String platform;

  /// Notice keys the user has already dismissed — those are skipped.
  final Set<String> dismissedKeys;

  /// Evaluation clock; injectable for tests. Defaults to [DateTime.now] at
  /// call time when null.
  final DateTime? now;

  const NoticeContext({
    required this.baseCall,
    required this.call,
    this.entityPrefix,
    this.continent,
    required this.appVersion,
    required this.appVersionName,
    required this.appBuild,
    required this.platform,
    this.dismissedKeys = const {},
    this.now,
  });
}

/// One notice that passed the rules, ready to push. [data] is the fully
/// adjusted map (platform keys resolved, templates substituted); the typed
/// getters are thin conveniences over it.
class EvaluatedNotice {
  final Map<String, dynamic> data;

  const EvaluatedNotice(this.data);

  String get key => (data['key'] as String?) ?? '';
  String? get icon => data['icon'] as String?;
  String? get title => data['title'] as String?;
  String get text => (data['text'] as String?) ?? '';
  String? get eventVariation => data['eventVariation'] as String?;
  num? get priority => data['priority'] as num?;

  /// Action descriptors as raw maps (`{action, label, args, event}`),
  /// interpreted by the notice action handler.
  List<Map<String, dynamic>> get actions =>
      ((data['actions'] as List?) ?? const []).whereType<Map>().map((a) => a.cast<String, dynamic>()).toList();
}

/// Platform tokens recognized in `-<platform>` key suffixes and the
/// `platforms` filter.
const _knownPlatforms = {'ios', 'android', 'macos', 'windows', 'linux', 'web'};

/// Applies the notice rules from [rawNotices] against [context] and returns
/// the survivors. Order of the checks is preserved from app-polo — notably
/// `testCalls` is a whitelist that admits a notice *before* the segment/entity
/// gates.
///
/// Two independent ordering concerns:
///
///  - **Which notice per key** (de-dup): at most one notice is returned per
///    `key` — the FIRST one in [rawNotices] order that passes the rules;
///    later same-key entries are dropped. This is by LIST order, not priority,
///    so callers can concatenate their sources most-preferred-first and have a
///    higher-precedence source shadow a lower one for a shared key. Keyless
///    notices aren't de-duped.
///  - **Display order** of the resulting distinct set: sorted by `priority`
///    (lower first; notices without a priority rank last), with the original
///    array order as the tiebreaker.
List<EvaluatedNotice> evaluateNotices(List<dynamic> rawNotices, NoticeContext context) {
  final now = context.now ?? DateTime.now();
  final segment = calculateCallSegment(context.baseCall);
  final seenUnique = <String>{};
  final seenKeys = <String>{};

  // Each survivor is tagged with its original array index `i`, used as the
  // priority-sort tiebreaker below.
  final passing = <MapEntry<int, Map<String, dynamic>>>[];

  var index = 0;
  for (final raw in rawNotices) {
    final i = index++;
    if (raw is! Map) continue;
    final notice = raw.cast<String, dynamic>();

    if (!_passes(notice, context, now: now, segment: segment, seenUnique: seenUnique)) continue;

    // One notice per key — keep the first that matched. Checked only for
    // notices that PASS, so a non-matching earlier same-key entry never
    // shadows a later matching one. Keyless notices aren't de-duped.
    final key = notice['key'];
    if (key is String && key.isNotEmpty && !seenKeys.add(key)) continue;

    passing.add(MapEntry(i, _adjustNotice(notice, context)));
  }

  // Display order: priority sort (lower first; no priority ranks last), with
  // the original array order (the tagged index `i`) as the tiebreaker. The
  // explicit index tiebreak is what makes this stable — Dart's List.sort is
  // not — so equal-priority / no-priority notices keep their server order.
  passing.sort((a, b) {
    final pa = a.value['priority'] as num?;
    final pb = b.value['priority'] as num?;
    if (pa != null && pb != null && pa != pb) return pa.compareTo(pb);
    if (pa != null && pb == null) return -1;
    if (pa == null && pb != null) return 1;
    return a.key.compareTo(b.key); // tiebreaker: original array order
  });

  return passing.map((e) => EvaluatedNotice(e.value)).toList();
}

bool _passes(
  Map<String, dynamic> notice,
  NoticeContext ctx, {
  required DateTime now,
  required int segment,
  required Set<String> seenUnique,
}) {
  final key = notice['key'] as String?;
  if (key != null && ctx.dismissedKeys.contains(key)) return false;

  // Transient notices are app-polo's in-session-only banners; nothing in the
  // server flags marks them, and HaLo only pushes persistent notices, so a
  // transient one is skipped rather than persisted.
  if (notice['transient'] == true) return false;

  final platforms = _stringList(notice['platforms']);
  if (platforms.isNotEmpty && !platforms.contains(ctx.platform)) return false;

  final dateFrom = _parseDate(notice['dateFrom']);
  if (dateFrom != null && !now.isAfter(dateFrom)) return false;
  final dateTo = _parseDate(notice['dateTo']);
  if (dateTo != null && !now.isBefore(dateTo)) return false;

  final versions = _stringList(notice['versions']);
  if (versions.isNotEmpty && !versions.any((v) => ctx.appVersion.startsWith(v))) return false;
  final builds = _stringList(notice['builds']);
  if (builds.isNotEmpty && !builds.contains(ctx.appBuild)) return false;
  final exceptVersions = _stringList(notice['exceptVersions']);
  if (exceptVersions.isNotEmpty && exceptVersions.any((v) => ctx.appVersion.startsWith(v))) return false;
  final exceptBuilds = _stringList(notice['exceptBuilds']);
  if (exceptBuilds.isNotEmpty && exceptBuilds.contains(ctx.appBuild)) return false;

  final calls = _stringList(notice['calls']);
  if (calls.isNotEmpty && !calls.any((c) => c.toUpperCase() == ctx.baseCall)) return false;
  // Whitelist: a listed test call admits the notice immediately, bypassing
  // the segment/entity/geo gates below (app-polo returns true here).
  final testCalls = _stringList(notice['testCalls']);
  if (testCalls.isNotEmpty && testCalls.any((c) => c.toUpperCase() == ctx.baseCall)) return true;

  final segmentFrom = notice['segmentFrom'] as num?;
  if (segmentFrom != null && segment < segmentFrom) return false;
  final segmentTo = notice['segmentTo'] as num?;
  if (segmentTo != null && segment > segmentTo) return false;

  // `notes` needs the call-notes extension; unavailable here → non-matching.
  if (notice.containsKey('notes')) return false;

  final entities = _stringList(notice['entities']);
  if (entities.isNotEmpty && !entities.any((d) => d.toUpperCase() == ctx.entityPrefix)) return false;
  // `countries` needs an ISO country code HaLo doesn't derive → non-matching.
  if (_hasItems(notice['countries'])) return false;
  final continents = _stringList(notice['continents']);
  if (continents.isNotEmpty && !continents.any((c) => c.toUpperCase() == ctx.continent)) return false;
  // `ituRegions` (numeric) unavailable in HaLo → non-matching.
  if (_hasItems(notice['ituRegions'])) return false;

  final unique = notice['unique'];
  if (unique is String) {
    if (seenUnique.contains(unique)) return false;
    seenUnique.add(unique);
  }

  return true;
}

/// A pseudo-random number, consistently derived from a callsign, evenly
/// distributed from 1 to 100 — a straight port of app-polo's
/// `_calculateCallSegment`, so a given operator lands in the same rollout
/// bucket in both apps. Returns 0 for an empty call.
int calculateCallSegment(String? call) {
  if (call == null || call.isEmpty) return 0;
  var hash = 0;
  for (var i = 0; i < call.length; i++) {
    hash = (hash << 5) - hash + call.codeUnitAt(i);
    hash = hash.toSigned(32); // mirror JS `hash |= 0` (32-bit wrap)
  }
  return (hash.abs() % 100) + 1;
}

/// Resolves platform-specific keys (`title-ios` → `title` on iOS), expands a
/// shorthand `actionLabel`/`action`/`actionArgs` into an `actions` array, and
/// substitutes `{{ path }}` template variables through the whole tree.
/// Operates on a deep copy so the source flags map is never mutated.
Map<String, dynamic> _adjustNotice(Map<String, dynamic> notice, NoticeContext ctx) {
  final templateData = _templateData(ctx);
  final copy = _deepCopy(notice) as Map<String, dynamic>;
  return _adjust(copy, ctx.platform, templateData) as Map<String, dynamic>;
}

Object? _adjust(Object? node, String platform, Map<String, dynamic> templateData) {
  if (node is Map<String, dynamic>) {
    // Resolve `-<platform>` suffixed keys first: the matching platform's
    // value overrides the base key; other platforms' variants are dropped.
    for (final key in node.keys.toList()) {
      final dash = key.lastIndexOf('-');
      if (dash <= 0) continue;
      final suffix = key.substring(dash + 1);
      if (!_knownPlatforms.contains(suffix)) continue;
      final baseKey = key.substring(0, dash);
      if (suffix == platform) {
        node[baseKey] = node[key];
      }
      node.remove(key);
    }

    // Shorthand single action → actions array (app-polo's `actionLabel`).
    if (node['actionLabel'] != null && node['actions'] == null) {
      node['actions'] = [
        {'action': node['action'], 'label': node['actionLabel'], 'args': node['actionArgs']},
      ];
    }

    for (final key in node.keys.toList()) {
      node[key] = _adjust(node[key], platform, templateData);
    }
    return node;
  }
  if (node is List) {
    for (var i = 0; i < node.length; i++) {
      node[i] = _adjust(node[i], platform, templateData);
    }
    return node;
  }
  if (node is String) return _applyTemplate(node, templateData);
  return node;
}

/// Substitutes `{{ path.to.value }}` references against [data]. A minimal
/// stand-in for app-polo's Handlebars pass — the server notices use plain
/// text today, but the capability is kept so a templated notice renders
/// rather than showing raw `{{ }}`. Unknown paths resolve to an empty string.
final _templatePattern = RegExp(r'\{\{\s*([\w.]+)\s*\}\}');

String _applyTemplate(String input, Map<String, dynamic> data) {
  if (!input.contains('{{')) return input;
  return input.replaceAllMapped(_templatePattern, (match) {
    final path = match.group(1)!;
    dynamic value = data;
    for (final part in path.split('.')) {
      if (value is Map && value.containsKey(part)) {
        value = value[part];
      } else {
        return '';
      }
    }
    return value?.toString() ?? '';
  });
}

Map<String, dynamic> _templateData(NoticeContext ctx) => {
      'operator': {
        'baseCall': ctx.baseCall,
        'call': ctx.call,
        'entityPrefix': ctx.entityPrefix,
        'continent': ctx.continent,
      },
      'app': {
        'version': ctx.appVersion,
        'versionName': ctx.appVersionName,
        'platform': ctx.platform,
      },
    };

Object? _deepCopy(Object? node) {
  if (node is Map) {
    return {for (final e in node.entries) e.key.toString(): _deepCopy(e.value)};
  }
  if (node is List) return node.map(_deepCopy).toList();
  return node;
}

List<String> _stringList(dynamic value) => value is List ? value.whereType<String>().toList() : const [];

bool _hasItems(dynamic value) => value is List && value.isNotEmpty;

DateTime? _parseDate(dynamic value) => value is String ? DateTime.tryParse(value) : null;
