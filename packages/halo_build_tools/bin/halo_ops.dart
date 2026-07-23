// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// halo-ops — a small operations CLI for the Ham2K Logger repo
// (ham2k/app-halo-dist#241). Clean, styled output for humans by default;
// `--json` for automation. Pure Dart, reusing halo_build_tools for the
// version/edition/tag logic and shelling out only to `git`. `release` is the
// single release cutter (it replaced the old scripts/release.sh).
//
//   dart run halo_build_tools:halo-ops status
//   dart run halo_build_tools:halo-ops release [--edition next] [--dry-run] [--yes]

import 'dart:convert';
import 'dart:io';

import 'package:halo_build_tools/halo_build_tools.dart';

const _remote = 'app-halo-dist';

Future<void> main(List<String> args) async {
  final rest = [...args];
  final json = rest.remove('--json');
  final plain = rest.remove('--plain');
  if (rest.remove('-h') || rest.remove('--help') || rest.isEmpty) {
    _printUsage();
    exit(rest.isEmpty ? 2 : 0);
  }
  final out = _Out(useColor: stdout.hasTerminal && !plain && !json && !Platform.environment.containsKey('NO_COLOR'));

  final command = rest.removeAt(0);
  try {
    switch (command) {
      case 'status':
        await _status(rest, out: out, json: json);
      case 'release':
        await _release(rest, out: out, json: json);
      case 'preview':
        await _preview(rest, out: out, json: json);
      case 'prune-previews':
        await _prunePreviews(rest, out: out, json: json);
      default:
        stderr.writeln("halo-ops: unknown command '$command'");
        _printUsage();
        exit(2);
    }
  } on _CliError catch (e) {
    stderr.writeln('halo-ops: ${e.message}');
    exit(1);
  }
}

// ── status ──────────────────────────────────────────────────────────────────

Future<void> _status(List<String> args, {required _Out out, required bool json}) async {
  if (args.isNotEmpty) throw _CliError("unexpected argument '${args.first}'");
  final root = await _repoRoot();
  final branch = (await _git(['rev-parse', '--abbrev-ref', 'HEAD'], cwd: root)).trim();
  await _fetchTagsBestEffort(out, root, quiet: json);
  if (!json && !await _checkInSync(out: out, root: root, branch: branch, yes: false, mustSync: false)) return;
  final tags = parseReleaseTags((await _git(['tag', '--list'], cwd: root)).split('\n'));
  final latest = latestRelease(tags);

  // Tags are edition-agnostic and a pushed `v*` tag builds the Next matrix (see
  // codemagic.yaml), so the tagged ledger IS the Next release line today; prod
  // and dev aren't cut from tags. Report that honestly rather than inventing a
  // per-edition split the tags don't carry.
  if (json) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert({
      'editions': {
        'next': latest == null ? null : {'version': latest.version, 'build': latest.build, 'tag': latest.tag},
        'prod': null,
        'dev': null,
      },
      'tags': [
        for (final t in tags.reversed) {'tag': t.tag, 'version': t.version, 'build': t.build},
      ],
    }));
    return;
  }

  out.title('Ham2K Logger — release status');
  out.blank();
  out.editionLine('Next', latest?.version, latest == null ? null : 'build ${latest.build}',
      latest?.tag ?? 'no release tags yet');
  out.editionLine('Prod', null, null, 'not cut from tags (manual signed release)');
  out.editionLine('Dev', null, null, 'local, build-it-yourself');
  out.blank();

  final byVersion = releasesByVersion(tags);
  if (byVersion.isEmpty) {
    out.dim('  No release tags found.');
  } else {
    for (final entry in byVersion.entries) {
      final builds = entry.value;
      final range = builds.length == 1 ? '${builds.first.build}' : '${builds.first.build}–${builds.last.build}';
      out.dim('  ${builds.length} tagged build${builds.length == 1 ? '' : 's'} ($range) on the ${entry.key} line.');
    }
  }
}

// ── release ─────────────────────────────────────────────────────────────────

Future<void> _release(List<String> args, {required _Out out, required bool json}) async {
  final rest = [...args];
  final dryRun = rest.remove('--dry-run') || rest.remove('-n');
  final yes = rest.remove('--yes') || rest.remove('-y');
  final editionName = _takeValue(rest, '--edition');
  if (rest.isNotEmpty) throw _CliError("unexpected argument '${rest.first}'");

  final root = await _repoRoot();
  final branch = (await _git(['rev-parse', '--abbrev-ref', 'HEAD'], cwd: root)).trim();
  await _fetchTagsBestEffort(out, root, quiet: json);
  if (!json && !await _checkInSync(out: out, root: root, branch: branch, yes: yes, mustSync: true)) return;

  final Edition edition;
  if (editionName != null) {
    final parsed = editionFromName(editionName);
    if (parsed == null) throw _CliError("--edition must be dev, next or prod (got '$editionName')");
    edition = parsed;
  } else {
    edition = editionForBranch(branch);
  }

  // Compute the plan in Dart from the same tag ledger + version.dart the retired
  // scripts/release.sh used — halo-ops is now the single release cutter.
  final tags = parseReleaseTags((await _git(['tag', '--list'], cwd: root)).split('\n'));
  final versionFile = File('$root/app/lib/config/version.dart');
  final source = await versionFile.readAsString();
  final parsed = parseVersionDart(source);
  final currentBuild = parsed.build;
  final latest = latestRelease(tags);
  // Highest shipped build + 1; seed from the file when there are no tags yet.
  final nextBuild = latest == null ? currentBuild : latest.build + 1;
  if (nextBuild > kBuildCap) throw _CliError('next build $nextBuild exceeds the $kBuildCap cap');
  final tagName = parsed.version.releaseTagName(nextBuild);
  final message = parsed.version.releaseMessage(nextBuild);

  if (json) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert({
      'branch': branch,
      'edition': edition.name,
      'currentBuild': currentBuild,
      'nextBuild': nextBuild,
      'version': parsed.version.value,
      'tag': tagName,
      'message': message,
      'wouldTrigger': edition == Edition.dev ? null : 'next build matrix (codemagic, on tag push)',
    }));
    return;
  }

  out.title('Ham2K Logger — cut release');
  out.blank();
  out.field('Branch', branch);
  out.field('Edition', edition.name + (editionName == null ? '  (from branch)' : '  (--edition)'));
  out.field('Build', '$currentBuild → $nextBuild${nextBuild == currentBuild ? '  (unchanged)' : ''}');
  out.field('Version', parsed.version.value);
  out.field('Tag', tagName);
  out.field('Message', message);
  out.blank();

  if (edition == Edition.dev) {
    out.warn('The $branch branch maps to the dev edition, which is not released via tags.');
    out.dim('  Pass --edition next (or prod) to cut a real release.');
    return;
  }
  out.dim('  Pushing this tag triggers the ${edition.name} build matrix on Codemagic (macOS/iOS/Windows/Linux/Android).');
  out.blank();

  if (dryRun) {
    out.dim('  (dry run — nothing written, committed, tagged, or pushed.)');
    return;
  }

  if (!yes && !_confirm(out, 'Cut this release?')) {
    out.dim('  Aborted.');
    return;
  }

  await _cut(
    out: out,
    root: root,
    versionFile: versionFile,
    source: source,
    currentBuild: currentBuild,
    nextBuild: nextBuild,
    tagName: tagName,
    message: message,
  );
}

/// The actual release cut, in Dart (git shelled out): refuse to clobber an
/// existing tag, write the new build into version.dart, commit ONLY that file
/// (else tag HEAD as-is), annotated-tag it, and — only when the branch tracks
/// app-halo-dist — push HEAD to its upstream branch plus the tag.
Future<void> _cut({
  required _Out out,
  required String root,
  required File versionFile,
  required String source,
  required int currentBuild,
  required int nextBuild,
  required String tagName,
  required String message,
}) async {
  out.blank();
  if (await _gitExit(['rev-parse', '-q', '--verify', 'refs/tags/$tagName'], root) == 0) {
    throw _CliError("tag '$tagName' already exists");
  }

  if (nextBuild != currentBuild) {
    await versionFile.writeAsString(rewriteBuildNumber(source, nextBuild));
  }

  const path = 'app/lib/config/version.dart';
  final unchanged = await _gitExit(['diff', '--quiet', '--', path], root) == 0 &&
      await _gitExit(['diff', '--cached', '--quiet', '--', path], root) == 0;
  if (unchanged) {
    out.dim('  version.dart unchanged; tagging HEAD as-is.');
  } else {
    await _git(['commit', '--only', path, '-m', message], cwd: root);
  }

  await _git(['tag', '-a', tagName, '-m', message], cwd: root);

  final upstream = await _upstream(root);
  if (upstream != null && upstream.startsWith('$_remote/')) {
    // Push the TAG first, then the branch. Codemagic auto-builds on the tag
    // push, but only if the tag is the commit's FIRST appearance on the remote —
    // pushing the branch (a tracked ref like `dist`) first makes Codemagic
    // register the commit and then dedupe the tag build. The tag push carries
    // the commit objects, so tag-first is safe (GitHub also emits one webhook
    // per ref, so a combined push wouldn't help — the order is what matters).
    //
    // Tag-first alone still isn't enough: the branch push lands on the SAME
    // commit ~1s later, and Codemagic dedupes the tag build against it before it
    // starts (observed — rapid back-to-back cuts +89/+90 delivered to the webhook
    // (HTTP 202) but never built, with no "skipped" record). So wait between the
    // two pushes, giving Codemagic time to register the tag build first.
    //
    // The branch target is the *upstream* branch (e.g. `dist`), NOT the local
    // branch name: a `main-dist-private` local branch's same-named remote ref is
    // a different (stale) branch — pushing to the upstream keeps the target
    // identical to what _checkInSync already verified.
    final upstreamBranch = upstream.substring(_remote.length + 1);
    const branchPushDelay = Duration(seconds: 10);
    out.dim('  Pushing tag $tagName …');
    await _git(['push', _remote, 'refs/tags/$tagName'], cwd: root);
    out.dim('  Waiting ${branchPushDelay.inSeconds}s for Codemagic to start the '
        'tag build, then pushing HEAD → $upstream …');
    await Future<void>.delayed(branchPushDelay);
    await _git(['push', _remote, 'HEAD:refs/heads/$upstreamBranch'], cwd: root);
    out.ok('Pushed.');
  } else {
    out.dim("  Branch upstream is '${upstream ?? '<none>'}' (not on $_remote) — commit + tag are local; skipping push.");
  }
}

// ── preview ─────────────────────────────────────────────────────────────────

Future<void> _preview(List<String> args, {required _Out out, required bool json}) async {
  final rest = [...args];
  final dryRun = rest.remove('--dry-run') || rest.remove('-n');
  final yes = rest.remove('--yes') || rest.remove('-y');
  if (rest.length != 1 || rest.first.startsWith('-')) {
    throw _CliError('usage: halo-ops preview <name> [--dry-run] [--yes]');
  }
  final raw = rest.first;
  final name = sanitizePreviewName(raw);
  if (name == null) throw _CliError("invalid preview name '$raw' (empty or reserved after sanitizing)");
  final tag = previewTagName(name);
  final url = previewUrl(name);

  final root = await _repoRoot();
  final sha = (await _git(['rev-parse', '--short', 'HEAD'], cwd: root)).trim();

  if (json) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert({'name': name, 'tag': tag, 'url': url, 'commit': sha}));
    return;
  }

  out.title('Ham2K Logger — deploy web preview');
  out.blank();
  out.field('Name', name + (name == raw ? '' : "  (from '$raw')"));
  out.field('Commit', sha);
  out.field('Tag', tag);
  out.field('URL', url);
  out.blank();
  out.dim('  Pushing the tag runs deploy-web-preview.yml — it builds this commit');
  out.dim('  and deploys it. Re-running the same name replaces the preview.');
  out.blank();

  if (dryRun) {
    out.dim('  (dry run — nothing tagged or pushed.)');
    return;
  }
  if (!yes && !_confirm(out, 'Deploy this preview?')) {
    out.dim('  Aborted.');
    return;
  }

  out.blank();
  // Re-previewing a name is a deliberate replace, so move the tag to HEAD and
  // force-push it (overwriting any existing tag). It's a GitHub Actions trigger,
  // not Codemagic, so tag-push order doesn't matter here.
  await _git(['tag', '-f', tag], cwd: root);
  await _git(['push', _remote, '--force', 'refs/tags/$tag'], cwd: root);
  out.ok('Pushed $tag → $url');
  out.dim('  (give the workflow a minute; follow it in the Actions tab.)');
}

// ── prune-previews (#244) ─────────────────────────────────────────────────────

Future<void> _prunePreviews(List<String> args, {required _Out out, required bool json}) async {
  final rest = [...args];
  final yes = rest.remove('--yes') || rest.remove('-y');
  final all = rest.remove('--all');
  final olderThanStr = _takeValue(rest, '--older-than');
  final names = <String>{};
  while (true) {
    final value = _takeValue(rest, '--name');
    if (value == null) break;
    names.add(sanitizePreviewName(value) ?? value);
  }
  if (rest.isNotEmpty) throw _CliError("unexpected argument '${rest.first}'");
  final olderThan = olderThanStr == null ? null : int.tryParse(olderThanStr);
  if (olderThanStr != null && (olderThan == null || olderThan < 0)) {
    throw _CliError('--older-than takes a number of days');
  }

  final token = Platform.environment['CLOUDFLARE_API_TOKEN'];
  final account = Platform.environment['CLOUDFLARE_ACCOUNT_ID'];
  if (token == null || token.isEmpty || account == null || account.isEmpty) {
    throw _CliError('set CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID (the CI secrets) to prune previews');
  }

  final root = await _repoRoot();
  final productionBranch = await _cfProductionBranch(token, account);
  final groups = groupPreviews(await _cfListDeployments(token, account), productionBranch: productionBranch);
  final zoneId = await _cfZoneId(token);
  final dns = await _cfListPreviewDns(token, zoneId); // name -> record id
  final tags = await _listPreviewTags(root); // set of names

  final allNames = <String>{...groups.keys, ...dns.keys, ...tags}.toList()..sort();
  final now = DateTime.now().toUtc();

  if (json) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert([
      for (final name in allNames)
        {
          'name': name,
          'url': previewUrl(name),
          'deployments': groups[name]?.length ?? 0,
          'ageDays': groups[name] == null ? null : now.difference(groups[name]!.first.createdOn).inDays,
          'dns': dns.containsKey(name),
          'tag': tags.contains(name),
        },
    ]));
    return;
  }

  out.title('Ham2K Logger — web previews');
  out.blank();
  if (allNames.isEmpty) {
    out.dim('  No previews found.');
    return;
  }
  final index = <int, String>{};
  for (var i = 0; i < allNames.length; i++) {
    final name = allNames[i];
    index[i + 1] = name;
    final g = groups[name];
    final age = g == null ? 'no deploy' : '${now.difference(g.first.createdOn).inDays}d';
    final parts = [
      g == null ? out.miss('no deploy') : '${g.length} deploy',
      dns.containsKey(name) ? 'dns' : out.miss('no dns'),
      tags.contains(name) ? 'tag' : out.miss('no tag'),
    ];
    out.previewLine(i + 1, name, age, parts.join(' · '), previewUrl(name));
  }
  out.blank();

  // Selection: flags pre-select; otherwise ask interactively.
  Set<String> selected;
  if (all) {
    selected = allNames.toSet();
  } else if (olderThan != null || names.isNotEmpty) {
    for (final name in names.where((n) => !allNames.contains(n))) {
      out.warn("No preview named '$name' — ignoring.");
    }
    selected = {
      ...names.where(allNames.contains),
      if (olderThan != null) ...previewsOlderThan(groups, maxAge: Duration(days: olderThan), now: now),
    };
  } else {
    stdout.write(out.prompt('Delete which? (numbers or names, comma-separated; blank to cancel) '));
    selected = _parseSelection(stdin.readLineSync() ?? '', index, allNames);
  }
  if (selected.isEmpty) {
    out.dim('  Nothing selected.');
    return;
  }

  out.blank();
  out.warn('Will delete ${selected.length} preview(s): ${(selected.toList()..sort()).join(', ')}');
  out.dim('  (Pages deployments + DNS record + web-preview-* tag for each)');
  if (!yes && !_confirm(out, 'Proceed?')) {
    out.dim('  Aborted.');
    return;
  }

  out.blank();
  for (final name in selected.toList()..sort()) {
    for (final d in groups[name] ?? const <PreviewDeployment>[]) {
      await _cfDelete(token, '/accounts/$account/pages/projects/$kPreviewPagesProject/deployments/${d.id}?force=true');
    }
    final recordId = dns[name];
    if (recordId != null) await _cfDelete(token, '/zones/$zoneId/dns_records/$recordId');
    if (tags.contains(name)) {
      await _gitExit(['push', _remote, ':refs/tags/${previewTagName(name)}'], root);
    }
    out.ok('Pruned $name');
  }
}

/// Parses a `prune-previews` selection line: comma-separated numbers (from the
/// listed index) and/or names, into the set of valid preview names.
Set<String> _parseSelection(String answer, Map<int, String> index, List<String> known) {
  final selected = <String>{};
  for (final raw in answer.split(',')) {
    final token = raw.trim();
    if (token.isEmpty) continue;
    final n = int.tryParse(token);
    if (n != null) {
      final name = index[n];
      if (name != null) selected.add(name);
    } else {
      final name = sanitizePreviewName(token) ?? token;
      if (known.contains(name)) selected.add(name);
    }
  }
  return selected;
}

// ── Cloudflare API (dart:io HttpClient; no deps) ──────────────────────────────

const String _cfBase = 'https://api.cloudflare.com/client/v4';

Future<Map<String, dynamic>> _cf(String method, String path, String token, {Map<String, dynamic>? body}) async {
  final client = HttpClient();
  try {
    final req = await client.openUrl(method, Uri.parse('$_cfBase$path'));
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
    }
    final resp = await req.close();
    final text = await resp.transform(utf8.decoder).join();
    Map<String, dynamic> data;
    try {
      data = text.isEmpty ? <String, dynamic>{} : jsonDecode(text) as Map<String, dynamic>;
    } on FormatException {
      // A gateway/5xx can answer with HTML rather than the API's JSON envelope.
      throw _CliError('Cloudflare $method $path → ${resp.statusCode}: ${text.trim()}');
    }
    if (data['success'] != true) {
      throw _CliError('Cloudflare $method $path → ${resp.statusCode}: ${data['errors'] ?? text}');
    }
    return data;
  } finally {
    client.close();
  }
}

Future<void> _cfDelete(String token, String path) => _cf('DELETE', path, token);

/// All Pages deployments for the preview project, as [PreviewDeployment]s
/// (paginated).
Future<List<PreviewDeployment>> _cfListDeployments(String token, String account) async {
  final out = <PreviewDeployment>[];
  for (var page = 1;; page++) {
    final data =
        await _cf('GET', '/accounts/$account/pages/projects/$kPreviewPagesProject/deployments?per_page=100&page=$page', token);
    final result = (data['result'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    for (final d in result) {
      final branch = ((d['deployment_trigger'] as Map?)?['metadata'] as Map?)?['branch'] as String? ?? '';
      final created = DateTime.tryParse(d['created_on'] as String? ?? '')?.toUtc();
      if (created != null) out.add(PreviewDeployment(id: d['id'] as String, branch: branch, createdOn: created));
    }
    final totalPages = ((data['result_info'] as Map?)?['total_pages'] as num?)?.toInt() ?? 1;
    if (result.isEmpty || page >= totalPages) break;
  }
  return out;
}

/// The Pages project's production branch — the one deploy alias a prune must
/// never touch. Fetched rather than assumed, since force-deleting is destructive
/// and the whole preview/production boundary rests on this one value.
Future<String> _cfProductionBranch(String token, String account) async {
  final data = await _cf('GET', '/accounts/$account/pages/projects/$kPreviewPagesProject', token);
  final branch = (data['result'] as Map?)?['production_branch'] as String?;
  if (branch == null || branch.isEmpty) {
    throw _CliError('could not read the $kPreviewPagesProject production branch from Cloudflare');
  }
  return branch;
}

Future<String> _cfZoneId(String token) async {
  final data = await _cf('GET', '/zones?name=$kPreviewZone', token);
  final result = (data['result'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
  final id = result.isEmpty ? null : result.first['id'] as String?;
  if (id == null) throw _CliError('could not find the $kPreviewZone zone');
  return id;
}

/// The preview placeholder DNS records (the ones this pipeline creates), as a
/// map of preview name -> record id.
Future<Map<String, String>> _cfListPreviewDns(String token, String zoneId) async {
  final byName = <String, String>{};
  final pattern = RegExp(r'^(.+)-halo-dev\.ham2k\.net$');
  for (var page = 1;; page++) {
    final data = await _cf('GET', '/zones/$zoneId/dns_records?type=AAAA&per_page=100&page=$page', token);
    final result = (data['result'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    for (final r in result) {
      // Only records this pipeline created (identified by its comment), so we
      // never touch an unrelated AAAA that happens to match the host shape.
      final comment = r['comment'] as String? ?? '';
      if (!comment.contains('HaLo web preview')) continue;
      final match = pattern.firstMatch(r['name'] as String? ?? '');
      if (match != null) byName[match.group(1)!] = r['id'] as String;
    }
    final totalPages = ((data['result_info'] as Map?)?['total_pages'] as num?)?.toInt() ?? 1;
    if (result.isEmpty || page >= totalPages) break;
  }
  return byName;
}

/// The preview names with a `web-preview-*` tag on the remote.
Future<Set<String>> _listPreviewTags(String root) async {
  final out = <String>{};
  final lines = (await _git(['ls-remote', '--tags', _remote, 'web-preview-*'], cwd: root)).split('\n');
  for (final line in lines) {
    final parts = line.trim().split(RegExp(r'\s+'));
    final ref = parts.isEmpty ? '' : parts.last;
    if (!ref.startsWith('refs/tags/web-preview-')) continue;
    final name = ref.replaceFirst('refs/tags/web-preview-', '');
    if (name.isNotEmpty && !name.endsWith('^{}')) out.add(name);
  }
  return out;
}

// ── git + process helpers ─────────────────────────────────────────────────────

Future<String> _repoRoot() async => (await _git(['rev-parse', '--show-toplevel'])).trim();

Future<void> _fetchTagsBestEffort(_Out out, String root, {required bool quiet}) async {
  // Reflect what's shipped from any machine; on failure, fall back to local tags
  // but say so (unless [quiet] for --json, where a warning would corrupt stdout)
  // — a silently stale ledger would compute a wrong next build.
  final r = await Process.run('git', ['fetch', '--tags', '--quiet', _remote], workingDirectory: root);
  if (r.exitCode != 0 && !quiet) {
    out.warn('Could not fetch from $_remote — using local tags; the plan may be out of date.');
  }
}

Future<String> _git(List<String> args, {String? cwd}) async {
  final result = await Process.run('git', args, workingDirectory: cwd);
  if (result.exitCode != 0) {
    throw _CliError('git ${args.join(' ')} failed: ${(result.stderr as String).trim()}');
  }
  return result.stdout as String;
}

/// Runs git for its exit code only (no throw) — for the yes/no checks
/// (tag-exists, is-dirty).
Future<int> _gitExit(List<String> args, String root) async =>
    (await Process.run('git', args, workingDirectory: root)).exitCode;

/// The current branch's upstream ref (e.g. `app-halo-dist/dist`), or null when
/// the branch has no upstream.
Future<String?> _upstream(String root) async {
  final r = await Process.run(
      'git', ['rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{upstream}'],
      workingDirectory: root);
  if (r.exitCode != 0) return null;
  final s = (r.stdout as String).trim();
  return s.isEmpty ? null : s;
}

/// Warns when the current branch is behind its upstream and offers to
/// fast-forward before continuing — so a release isn't cut from (nor status
/// reported against) a stale HEAD. Assumes the remote-tracking refs were just
/// fetched. Returns true to proceed, false to abort.
///
/// With [mustSync] (used by `release`), declining the fix aborts: cutting from a
/// behind branch would commit + tag locally but then fail to push (non-fast-
/// forward), leaving a stray local tag. Without it (`status`, read-only),
/// declining just proceeds against the stale branch. A branch with no upstream,
/// or one only ahead, proceeds silently.
Future<bool> _checkInSync(
    {required _Out out, required String root, required String branch, required bool yes, required bool mustSync}) async {
  final upstream = await _upstream(root);
  if (upstream == null) return true;
  final counts = (await _git(['rev-list', '--left-right', '--count', 'HEAD...@{upstream}'], cwd: root))
      .trim()
      .split(RegExp(r'\s+'));
  final ahead = int.tryParse(counts.isNotEmpty ? counts[0] : '') ?? 0;
  final behind = int.tryParse(counts.length > 1 ? counts[1] : '') ?? 0;
  if (behind == 0) return true;

  final diverged = ahead > 0;
  out.warn('$branch is behind $upstream by $behind commit${behind == 1 ? '' : 's'}'
      '${diverged ? ' and ahead by $ahead (diverged)' : ''}.');
  if (!(yes || _confirm(out, 'Update the branch now?'))) {
    if (mustSync) {
      out.warn("Won't cut a release from an out-of-date branch (the push would be rejected) — update it first.");
      return false;
    }
    out.dim('  Continuing with an out-of-date branch.');
    return true;
  }
  if (await _gitExit(['merge', '--ff-only', '@{upstream}'], root) == 0) {
    out.ok('Updated to $upstream.');
    return true;
  }
  out.warn('Could not fast-forward (the branch has diverged, or the working tree is dirty). '
      'Resolve it manually, then retry.');
  return false;
}

bool _confirm(_Out out, String question) {
  stdout.write(out.prompt('$question [y/N] '));
  final a = stdin.readLineSync()?.trim().toLowerCase();
  return a == 'y' || a == 'yes';
}

String? _takeValue(List<String> args, String flag) {
  final i = args.indexOf(flag);
  if (i < 0) return null;
  if (i + 1 >= args.length) throw _CliError('$flag needs a value');
  final value = args[i + 1];
  args.removeRange(i, i + 2);
  return value;
}

void _printUsage() {
  stderr.writeln('''
halo-ops — Ham2K Logger operations

Usage: halo-ops <command> [options]

Commands:
  status                 Show the released version for each edition, from tags.
  release                Preview and cut a release (bump version.dart, commit, tag, push).
  preview <name>         Deploy a web preview of HEAD (tags web-preview-<name>, pushes it).
  prune-previews         List web previews; delete selected ones (Pages + DNS + tag).

Release options:
  --edition <dev|next|prod>   Override the branch→edition mapping.
  --dry-run, -n               Show the plan; don't write/commit/tag/push.
  --yes, -y                   Skip the confirmation prompt.

preview options:
  --dry-run, -n / --yes, -y   As above.

prune-previews options (needs CLOUDFLARE_API_TOKEN + CLOUDFLARE_ACCOUNT_ID):
  --older-than <days>         Select previews whose newest deploy is older than N days.
  --name <name>               Select a preview by name (repeatable).
  --all                       Select every preview.
  --yes, -y                   Skip the confirmation prompt.
  (with no selection flag, lists and asks interactively.)

Global options:
  --json                 Machine-readable output (implies no color/prompts).
  --plain                No ANSI styling.
  --help, -h             This help.''');
}

class _CliError implements Exception {
  final String message;
  _CliError(this.message);
}

// ── styled output ─────────────────────────────────────────────────────────────

class _Out {
  final bool useColor;
  _Out({required this.useColor});

  String _wrap(String s, String code) => useColor ? '\x1b[${code}m$s\x1b[0m' : s;

  void title(String s) => stdout.writeln(_wrap(s, '1;36')); // bold cyan
  void blank() => stdout.writeln();
  void dim(String s) => stdout.writeln(_wrap(s, '2'));
  void warn(String s) => stdout.writeln('  ${_wrap('!', '1;33')} ${_wrap(s, '33')}');
  void ok(String s) => stdout.writeln('  ${_wrap('✓', '1;32')} $s');
  String prompt(String s) => _wrap(s, '1');

  /// A missing/orphaned piece in a preview row (e.g. `no dns`), tinted.
  String miss(String s) => _wrap(s, '33');

  void previewLine(int n, String name, String age, String flags, String url) {
    stdout.writeln('  ${_wrap('[$n]', '1')} ${_wrap(name.padRight(20), '1')} ${age.padRight(11)} $flags   ${_wrap(url, '2')}');
  }

  void field(String label, String value) {
    stdout.writeln('  ${_wrap(label.padRight(9), '1')}$value');
  }

  void editionLine(String edition, String? version, String? build, String note) {
    final name = _wrap(edition.padRight(7), '1');
    if (version == null) {
      stdout.writeln('  $name${_wrap('—  $note', '2')}');
    } else {
      final b = build == null ? '' : '   ${_wrap(build, '2')}';
      stdout.writeln('  $name$version$b   ${_wrap(note, '2')}');
    }
  }
}
