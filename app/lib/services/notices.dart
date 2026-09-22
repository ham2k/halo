// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The server-notice rule engine — a straight port of app-polo's `useNotices`
// (src/store/system/useNotices.js). Feature-flag files (see FlagsService)
// can carry a `notices` array; each entry declares who should see it
// (platform/version/build/sha/callsign/DXCC-entity/continent, a date window,
// and a pseudo-random "segment" bucket for staged rollouts). `shas` is the
// one filter with no app-polo counterpart: HaLo ships Dev-edition web builds
// whose only identity is the commit. This module applies
// those rules against the current operator + app context and returns the
// notices that pass, adjusted (platform-specific keys resolved, template
// variables substituted) and sorted by priority.
//
// Kept as a pure, UI-free, runtime-free function so it can be unit-tested
// without a JS runtime, a network, or a widget tree — FlagsService calls it
// after each merge and pushes the survivors to the StatusBarService notice
// surface. `notes` needs the call-notes extension, which this module has no
// access to, so a rule gated on it is intentionally treated as non-matching
// — a notice gated on it simply never shows, the same safe direction as a
// user whose value isn't in the list. `countries`/`ituRegions` match for
// real — see [countryCode]/[ituRegion] below.

import 'package:halo_core/halo_core.dart';

/// The operator + app facts the notice rules are evaluated against. Mirrors
/// app-polo's `templateData.operator`/`app` plus the callsign-derived filter
/// inputs. Geo fields come from the callsign-annotation guess (bundled
/// country file plus, for [countryCode]/[ituRegion], the DXCC entity table —
/// see `regionAndCountryForDxccCode` in extensions/sdk/src/dxcc.ts).
class NoticeContext {
  /// The operator's base callsign, uppercased (e.g. `KI2D`), or empty.
  final String baseCall;

  /// The full operator callsign as entered (e.g. `KI2D/P`).
  final String call;

  /// DXCC entity prefix from the country-file annotation (e.g. `K`).
  final String? entityPrefix;

  /// Continent code from the country-file annotation (e.g. `NA`).
  final String? continent;

  /// Lowercase ISO country code (e.g. `us`) — matched against the notice's
  /// `countries` filter.
  final String? countryCode;

  /// ITU region (1/2/3) — matched against the notice's `ituRegions` filter.
  final int? ituRegion;

  /// The app's public version string (e.g. `26.8.0`) — matched against
  /// `versions`/`exceptVersions` with `startsWith`, as app-polo does.
  final String appVersion;

  /// A human display name for the version (`app.versionName` in templates).
  final String appVersionName;

  /// The release build number (e.g. `126`) — matched exactly against
  /// `builds`/`exceptBuilds`. This is the number the release ledger and every
  /// version display use, so a rule authored against a released build matches
  /// the build a reporter names.
  ///
  /// Stays BARE even when a code push is running: a code push never alters the
  /// binary, so a `builds` rule must reach every install sitting on that
  /// binary, whichever push they are at. The push is [appCodePush]'s job.
  final String appBuild;

  /// The Shorebird code-push number running on top of [appBuild] (e.g. `2`),
  /// or empty when none is applied — matched exactly against
  /// `codePushes`/`exceptCodePushes`.
  ///
  /// A separate field rather than part of [appBuild] because the two are
  /// matched by exact string membership: folding them into `126.2` would mean
  /// a rule naming build `126` silently stopped matching the moment a push
  /// went out — a rule that targets nothing looks exactly like a rule nobody
  /// tripped. Note the counter restarts at 1 per release, so a `codePushes`
  /// rule is only meaningful alongside a `builds` one.
  final String appCodePush;

  /// The short git SHA this build was cut from (e.g. `04e3d1`), or empty when
  /// none was baked in. A `shas`/`exceptShas` entry names this build when one
  /// of the two is a prefix of the other — see `_shaMatches`, which says why
  /// neither end has a length the other can rely on. It is
  /// the ONLY build identity a Dev-edition build carries, which is what the
  /// hosted web app and every preview deploy are, so it is the only way to
  /// target a notice at one of those.
  final String appSha;

  /// Lowercase platform token: `ios`, `android`, `macos`, `windows`,
  /// `linux`, or `web`. Used for the `platforms` filter and `-<platform>`
  /// key suffixes.
  final String platform;

  /// Notice keys the user has already dismissed — those are skipped.
  final Set<String> dismissedKeys;

  /// Evaluation clock; injectable for tests. Defaults to [nowLocal] at
  /// call time when null.
  final DateTime? now;

  const NoticeContext({
    required this.baseCall,
    required this.call,
    this.entityPrefix,
    this.continent,
    this.countryCode,
    this.ituRegion,
    required this.appVersion,
    required this.appVersionName,
    required this.appBuild,
    required this.appCodePush,
    required this.appSha,
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
      ((data['actions'] as List?) ?? const []).whereType<Map<dynamic, dynamic>>().map((a) => a.cast<String, dynamic>()).toList();
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
  final now = context.now ?? nowLocal();
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

/// The shortest `shas`/`exceptShas` entry taken seriously. Six is the shortest
/// SHA this app has ever shown (`04e3d1`), and git will not abbreviate below
/// four, so anything shorter is a typo or a truncated paste rather than an
/// intent. Honouring one would reach a SLICE OF THE FLEET rather than nothing:
/// three hex characters name one build in 4096, where exact matching gave a
/// typo no reach at all. Dropping it is the safe direction, and for
/// `exceptShas` it is the only safe one — a notice wrongly WITHHELD leaves
/// nothing on anybody's screen to report.
const _minShaEntryLength = 6;

/// Whether [appSha] is the build one of [shas] names, comparing on whichever
/// of the two is shorter.
///
/// Neither side has a fixed length and they cannot be made to agree: a build
/// bakes whatever `git rev-parse --short` gave the machine that built it — a
/// length that follows how big the repository is, and that is frozen inside
/// every shipped binary — while the version displays cut it to seven. A rule
/// is written from one of those, or pasted whole out of git at forty. All
/// three have to reach the build they name, which is why the comparison runs
/// in both directions rather than demanding the rule be the shorter one.
///
/// Both ends are real SHAs of the same commit, so one being a prefix of the
/// other identifies it as surely as equality did — git abbreviates only as far
/// as stays unambiguous. What that does NOT survive is a short entry, hence
/// [_minShaEntryLength].
///
/// A build with no SHA baked in matches nothing — an unidentified build is not
/// the one being targeted, so a `shas` list excludes it and an `exceptShas`
/// list leaves it alone. An empty entry likewise matches nothing, though
/// `startsWith('')` is true of every string: a flags file templated from an
/// unset variable serializes `[""]`, and honouring that would broadcast a
/// commit-targeted notice to every build at once, or mute one for all of them.
bool _shaMatches(List<String> shas, String appSha) =>
    appSha.isNotEmpty && shas.any((sha) => sha.length >= _minShaEntryLength && (appSha.startsWith(sha) || sha.startsWith(appSha)));

bool _passes(Map<String, dynamic> notice, NoticeContext ctx, {required DateTime now, required int segment, required Set<String> seenUnique}) {
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
  // An install with no code push applied matches no `codePushes` list and is
  // excluded by no `exceptCodePushes` list, on the same reasoning as `shas`
  // below: an install that is not running a push is not the one being targeted.
  final codePushes = _stringList(notice['codePushes']);
  if (codePushes.isNotEmpty && (ctx.appCodePush.isEmpty || !codePushes.contains(ctx.appCodePush))) return false;
  final exceptCodePushes = _stringList(notice['exceptCodePushes']);
  if (exceptCodePushes.isNotEmpty && ctx.appCodePush.isNotEmpty && exceptCodePushes.contains(ctx.appCodePush)) {
    return false;
  }
  final shas = _stringList(notice['shas']);
  if (shas.isNotEmpty && !_shaMatches(shas, ctx.appSha)) return false;
  final exceptShas = _stringList(notice['exceptShas']);
  if (exceptShas.isNotEmpty && _shaMatches(exceptShas, ctx.appSha)) return false;

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
  final countries = _stringList(notice['countries']);
  if (countries.isNotEmpty && !countries.any((c) => c.toLowerCase() == ctx.countryCode)) return false;
  final continents = _stringList(notice['continents']);
  if (continents.isNotEmpty && !continents.any((c) => c.toUpperCase() == ctx.continent)) return false;
  final ituRegions = notice['ituRegions'];
  if (ituRegions is List && ituRegions.isNotEmpty && !ituRegions.any((r) => (r as num?)?.toInt() == ctx.ituRegion)) {
    return false;
  }

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
    'countryCode': ctx.countryCode,
    'ituRegion': ctx.ituRegion,
  },
  'app': {
    'version': ctx.appVersion,
    'versionName': ctx.appVersionName,
    'build': ctx.appBuild,
    'codePush': ctx.appCodePush,
    'sha': ctx.appSha,
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

DateTime? _parseDate(dynamic value) => value is String ? DateTime.tryParse(value) : null;
