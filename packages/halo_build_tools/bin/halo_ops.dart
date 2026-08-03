// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// halo-ops — a small operations CLI for the Ham2K Logger repo.
// Clean, styled output for humans by default;
// `--json` for automation. Pure Dart, reusing halo_build_tools for the
// version/edition/tag logic and shelling out only to `git`. `release` is the
// single release cutter.
//
//   dart run halo_build_tools:halo-ops status
//   dart run halo_build_tools:halo-ops release [--edition next] [--min-build N] [--dry-run] [--yes]

import 'dart:convert';
import 'dart:io';

import 'package:halo_build_tools/halo_build_tools.dart';

const _remote = 'origin';

/// The open-source mirror `publish` pushes to. Pushed over the operator's own
/// git credentials (SSH) — user keys are exempt from the `workflow`-scope
/// restriction that blocks PAT/deploy-key pushes carrying workflow files.
const _mirrorUrl = 'git@github.com:ham2k/halo.git';
const _mirrorBranch = 'main';

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
      case 'patch':
        await _patch(rest, out: out, json: json);
      case 'prune-patches':
        await _prunePatches(rest, out: out, json: json);
      case 'preview':
        await _preview(rest, out: out, json: json);
      case 'prune-previews':
        await _prunePreviews(rest, out: out, json: json);
      case 'publish':
        await _publish(rest, out: out, json: json);
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
  final minBuildStr = _takeValue(rest, '--min-build');
  final minBuild = minBuildStr == null ? null : int.tryParse(minBuildStr);
  if (minBuildStr != null && minBuild == null) {
    throw _CliError("--min-build must be a positive integer (got '$minBuildStr')");
  }
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

  // Compute the plan from the tag ledger and version.dart.
  final tags = parseReleaseTags((await _git(['tag', '--list'], cwd: root)).split('\n'));
  final versionFile = File('$root/app/lib/config/version.dart');
  final source = await versionFile.readAsString();
  final parsed = parseVersionDart(source);
  final currentBuild = parsed.build;
  final latest = latestRelease(tags);
  // Highest shipped build + 1; seed from the file when there are no tags yet.
  final ledgerBuild = latest == null ? currentBuild : latest.build + 1;
  // --min-build is a floor, not a target: something outside the tag ledger
  // (an ad-hoc CI test run, a store's own version-code history) may have
  // already consumed build numbers the ledger doesn't know about. It only
  // ever raises the plan, never lowers it below what the ledger computed.
  final nextBuild = minBuild == null ? ledgerBuild : (minBuild > ledgerBuild ? minBuild : ledgerBuild);
  if (nextBuild > kBuildCap) throw _CliError('next build $nextBuild exceeds the $kBuildCap cap');
  final tagName = parsed.version.releaseTagName(nextBuild);
  final message = parsed.version.releaseMessage(nextBuild);

  // Build expirations (written into version.dart, read back by the app's
  // expired-build dialog; horizons live in expirationDateForBuild). The
  // cutting edition gets its own date, and Dev is ALWAYS re-stamped: dev
  // builds are made from dist commits, so every cut refreshes their leash
  // too. Patch builds re-stamp at build time instead (stamp_expiration.dart
  // from the CI patch scripts) — the patch plane commits nothing.
  final today = DateTime.now().toUtc();
  final expirationDate = edition == Edition.dev
      ? null // dev is never the cutting edition (guarded below)
      : expirationDateForBuild(edition, today);
  final devExpirationDate = expirationDateForBuild(Edition.dev, today);

  if (json) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert({
      'branch': branch,
      'edition': edition.name,
      'currentBuild': currentBuild,
      'nextBuild': nextBuild,
      'version': parsed.version.value,
      'tag': tagName,
      'message': message,
      'expiration': expirationDate,
      'devExpiration': devExpirationDate,
      'wouldTrigger': edition == Edition.dev ? null : 'next build matrix (codemagic, on tag push)',
    }));
    return;
  }

  out.title('Ham2K Logger — cut release');
  out.blank();
  out.field('Branch', branch);
  out.field('Edition', edition.name + (editionName == null ? '  (from branch)' : '  (--edition)'));
  out.field(
    'Build',
    '$currentBuild → $nextBuild'
    '${nextBuild == currentBuild ? '  (unchanged)' : ''}'
    '${minBuild != null && nextBuild == minBuild && minBuild > ledgerBuild ? '  (--min-build, ledger alone would give $ledgerBuild)' : ''}',
  );
  out.field('Version', parsed.version.value);
  out.field('Tag', tagName);
  out.field('Message', message);
  out.field('Expires', expirationDate ?? '—');
  out.field('Dev expires', devExpirationDate);
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
    edition: edition,
    expirationDate: expirationDate,
    devExpirationDate: devExpirationDate,
  );
}


/// The actual release cut, in Dart (git shelled out): refuse to clobber an
/// existing tag, write the new build into version.dart, commit ONLY that file
/// (else tag HEAD as-is), annotated-tag it, and — only when the branch tracks
/// halo-dist — push HEAD to its upstream branch plus the tag.
Future<void> _cut({
  required _Out out,
  required String root,
  required File versionFile,
  required String source,
  required int currentBuild,
  required int nextBuild,
  required String tagName,
  required String message,
  required Edition edition,
  required String? expirationDate,
  required String devExpirationDate,
}) async {
  out.blank();
  if (await _gitExit(['rev-parse', '-q', '--verify', 'refs/tags/$tagName'], root) == 0) {
    throw _CliError("tag '$tagName' already exists");
  }

  var newSource = source;
  if (nextBuild != currentBuild) {
    newSource = rewriteBuildNumber(newSource, nextBuild);
  }
  if (expirationDate != null) {
    newSource = rewriteExpirationDate(newSource, edition, expirationDate);
  }
  newSource = rewriteExpirationDate(newSource, Edition.dev, devExpirationDate);
  if (newSource != source) {
    await versionFile.writeAsString(newSource);
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
    // Push the branch AND the tag in ONE atomic push, so the tagged commit is
    // already on the branch the moment Codemagic sees the tag. Codemagic
    // resolves a tag build to the branch the tagged commit lives on; if the
    // commit isn't on any branch yet when it processes the tag webhook, it can't
    // resolve a branch and SILENTLY skips the build — no build record, no error.
    // Tagging first and pushing the branch later leaves exactly that window;
    // `--atomic` updates both refs together, before any webhook fires. Pushing
    // the branch does NOT cause a duplicate build — the workflows trigger on
    // `v*` tags only, not branch pushes.
    //
    // The branch target is the *upstream* branch (e.g. `dist`), NOT the local
    // branch name: a `main-dist-private` local branch's same-named remote ref is
    // a different (stale) branch — pushing to the upstream keeps the target
    // identical to what _checkInSync already verified.
    final upstreamBranch = upstream.substring(_remote.length + 1);
    out.dim('  Pushing HEAD → $upstream and tag $tagName (atomic) …');
    await _git([
      'push', '--atomic', _remote,
      'HEAD:refs/heads/$upstreamBranch',
      'refs/tags/$tagName',
    ], cwd: root);
    out.ok('Pushed.');
  } else {
    out.dim("  Branch upstream is '${upstream ?? '<none>'}' (not on $_remote) — commit + tag are local; skipping push.");
  }
}

// ── patch (Shorebird Dart code push, docs/releases.md §4) ─────────────────────

Future<void> _patch(List<String> args, {required _Out out, required bool json}) async {
  final rest = [...args];
  final dryRun = rest.remove('--dry-run') || rest.remove('-n');
  final yes = rest.remove('--yes') || rest.remove('-y');
  final force = rest.remove('--force');
  final editionName = _takeValue(rest, '--edition');
  if (rest.isNotEmpty) throw _CliError("unexpected argument '${rest.first}'");

  final root = await _repoRoot();
  final branch = (await _git(['rev-parse', '--abbrev-ref', 'HEAD'], cwd: root)).trim();
  await _fetchTagsBestEffort(out, root, quiet: json);
  // A patch builds HEAD (the fix), not the upstream branch, so being behind isn't
  // fatal — but warn, since you'd be patching without others' merged fixes.
  if (!json && !await _checkInSync(out: out, root: root, branch: branch, yes: yes, mustSync: false)) return;

  final Edition edition;
  if (editionName != null) {
    final parsed = editionFromName(editionName);
    if (parsed == null) throw _CliError("--edition must be dev, next or prod (got '$editionName')");
    edition = parsed;
  } else {
    edition = editionForBranch(branch);
  }
  final platforms = patchPlatformsForEdition(edition);
  if (platforms.isEmpty) {
    throw _CliError('no Shorebird patch workflow is wired for the ${edition.name} edition '
        '(only next and dev have patch builds today)');
  }

  // The release the patch binds to. The tag ledger is the Next line (§ status),
  // so the anchor is exact for next; for dev it's the closest proxy we have.
  final tags = parseReleaseTags((await _git(['tag', '--list'], cwd: root)).split('\n'));
  final release = latestRelease(tags);
  if (release == null) throw _CliError('no release tag found to patch — cut a release first');

  final changed = (await _git(['diff', '--name-only', '${release.tag}..HEAD'], cwd: root))
      .split('\n')
      .where((s) => s.trim().isNotEmpty)
      .toList();
  final compat = classifyPatchChanges(changed);
  final sha = (await _git(['rev-parse', '--short', 'HEAD'], cwd: root)).trim();
  final tag = patchTagName(edition, sha);

  if (json) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert({
      'edition': edition.name,
      'release': {'tag': release.tag, 'version': release.version, 'build': release.build},
      'commit': sha,
      'tag': tag,
      'platforms': platforms,
      'changedFiles': changed.length,
      'patchable': compat.isPatchable,
      'breaking': compat.breaking,
    }));
    return;
  }

  out.title('Ham2K Logger — publish Dart patch');
  out.blank();
  out.field('Branch', branch);
  out.field('Edition', edition.name + (editionName == null ? '  (from branch)' : '  (--edition)'));
  out.field('Release', '${release.version}  (build ${release.build}, ${release.tag})');
  out.field('Commit', sha);
  out.field('Tag', tag);
  out.field('Targets', platforms.join(', '));
  if (edition != Edition.next) {
    out.dim('  (dev/prod aren\'t tag-cut; the release anchor is the Next ledger — treat the check as approximate.)');
  }
  out.blank();

  if (changed.isEmpty) {
    out.warn('No changes since ${release.tag} — nothing to patch.');
    return;
  }

  // Compatibility gate (docs/releases.md §4.2): a patch is pure Dart + assets.
  out.dim('  ${changed.length} file(s) changed since ${release.tag}: '
      '${compat.safe.length} patch-safe, ${compat.breaking.length} native/dependency.');
  if (!compat.isPatchable) {
    out.blank();
    out.warn('These changes are outside the pure-Dart/asset surface a patch can carry:');
    for (final p in compat.breaking) {
      out.dim('    $p');
    }
    out.dim('  A full release (halo-ops release) is likely needed; Shorebird rejects a native diff.');
    out.dim('  --force overrides this local check.');
  }
  out.blank();

  final blocked = !compat.isPatchable && !force;
  if (dryRun) {
    out.dim(blocked
        ? '  (dry run — this would be REFUSED without --force.)'
        : '  (dry run — nothing tagged or pushed.)');
    return;
  }
  if (blocked) {
    throw _CliError('refusing to patch native/dependency changes — re-run with --force to override');
  }
  if (!compat.isPatchable) {
    out.warn('--force set; triggering the patch anyway (Shorebird still has the final say).');
  }
  out.dim('  Pushing $tag triggers ${platforms.length} Codemagic patch workflow(s) for ${edition.name},');
  out.dim('  each building a pure-Dart patch of HEAD against the live Shorebird release.');
  out.blank();

  if (!yes && !_confirm(out, 'Publish this patch?')) {
    out.dim('  Aborted.');
    return;
  }

  out.blank();
  // A per-commit tag (patch-<edition>-<sha>): a fresh ref each time, so Codemagic
  // always sees a tag *creation* and triggers — no reliance on it firing when a
  // reusable tag is moved. `-f`/`--force` only matter when re-patching the exact
  // same commit (the tag already exists); a normal patch advances HEAD → new sha.
  // These patch workflows are distinct from the release matrix, so there's no
  // commit-dedup to fight.
  await _git(['tag', '-f', tag], cwd: root);
  await _git(['push', _remote, '--force', 'refs/tags/$tag'], cwd: root);
  out.ok('Pushed $tag → ${edition.name} patch builds (${platforms.join(', ')}).');
  out.dim('  (follow them in Codemagic; each patch lands on its Shorebird track.)');
}

// ── prune-patches ─────────────────────────────────────────────────────────────

Future<void> _prunePatches(List<String> args, {required _Out out, required bool json}) async {
  final rest = [...args];
  final dryRun = rest.remove('--dry-run') || rest.remove('-n');
  final yes = rest.remove('--yes') || rest.remove('-y');
  final all = rest.remove('--all');
  final olderThanStr = _takeValue(rest, '--older-than');
  if (rest.isNotEmpty) throw _CliError("unexpected argument '${rest.first}'");
  final olderThanDays = olderThanStr == null ? null : int.tryParse(olderThanStr);
  if (olderThanStr != null && (olderThanDays == null || olderThanDays < 0)) {
    throw _CliError('--older-than takes a number of days');
  }
  final maxAge = Duration(days: olderThanDays ?? kPatchTagMaxAgeDays);

  final root = await _repoRoot();
  await _fetchTagsBestEffort(out, root, quiet: json);
  // Local patch tags mirror the remote after the fetch; for a lightweight tag
  // `creatordate` is the tagged commit's date, which is how we age it.
  final lines = (await _git([
    'for-each-ref',
    '--sort=creatordate',
    '--format=%(refname:short)\t%(creatordate:unix)',
    'refs/tags/patch-*',
  ], cwd: root))
      .split('\n');
  final tags = <PatchTag>[];
  for (final line in lines) {
    final parts = line.split('\t');
    if (parts.length != 2 || !isPatchTag(parts[0].trim())) continue;
    final secs = int.tryParse(parts[1].trim());
    if (secs == null) continue;
    tags.add(PatchTag(tag: parts[0].trim(), date: DateTime.fromMillisecondsSinceEpoch(secs * 1000, isUtc: true)));
  }

  final now = DateTime.now().toUtc();
  final selected = all ? tags : patchTagsOlderThan(tags, maxAge: maxAge, now: now);
  final selectedTags = {for (final t in selected) t.tag};

  if (json) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert([
      for (final t in tags)
        {'tag': t.tag, 'ageDays': now.difference(t.date).inDays, 'selected': selectedTags.contains(t.tag)},
    ]));
    return;
  }

  out.title('Ham2K Logger — prune patch tags');
  out.blank();
  if (tags.isEmpty) {
    out.dim('  No patch tags found.');
    return;
  }
  for (final t in tags) {
    out.patchLine(t.tag, '${now.difference(t.date).inDays}d', selected: selectedTags.contains(t.tag));
  }
  out.blank();

  if (selected.isEmpty) {
    out.dim(all ? '  Nothing to prune.' : '  Nothing older than ${maxAge.inDays} days.');
    return;
  }
  out.warn('Will delete ${selected.length} patch tag(s)'
      '${all ? '' : ' older than ${maxAge.inDays} days'}: ${selectedTags.join(', ')}');
  out.dim('  (deletes the tag on $_remote + locally; only trigger tags — published Shorebird patches are untouched.)');

  if (dryRun) {
    out.dim('  (dry run — nothing deleted.)');
    return;
  }
  if (!yes && !_confirm(out, 'Proceed?')) {
    out.dim('  Aborted.');
    return;
  }

  out.blank();
  for (final t in selected) {
    // Delete both refs. `git push :refs/tags/x` is non-zero both when the tag is
    // already gone from the remote (fine) and when the push genuinely fails
    // (network/auth) — we can't cleanly tell them apart, so surface a warning
    // rather than claim a clean prune when the remote ref might survive.
    final remoteOk = await _gitExit(['push', _remote, ':refs/tags/${t.tag}'], root) == 0;
    await _gitExit(['tag', '-d', t.tag], root);
    if (remoteOk) {
      out.ok('Pruned ${t.tag}');
    } else {
      out.warn('Removed ${t.tag} locally; remote delete failed — it may still be on $_remote.');
    }
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

// ── prune-previews ────────────────────────────────────────────────────────────

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

/// The current branch's upstream ref (e.g. `origin/main`), or null when
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

// ── publish ─────────────────────────────────────────────────────────────────

/// Mirrors the generated `public` branch to the open-source repo — a
/// deliberate act rather than an automatic one, so work can sit on `main`
/// for a few days before going public. The Publish Public workflow keeps
/// `origin/public` regenerated (app_dist filtered out of the full history)
/// on every push to main; this command only decides WHEN that history
/// reaches the mirror.
Future<void> _publish(List<String> args, {required _Out out, required bool json}) async {
  final dryRun = args.remove('--dry-run') || args.remove('-n');
  final yes = args.remove('--yes') || args.remove('-y');
  final force = args.remove('--force');
  final ref = _takeValue(args, '--ref');
  if (args.isNotEmpty) throw _CliError("unexpected argument '${args.first}'");

  final root = await _repoRoot();
  await _git(['fetch', _remote, 'public'], cwd: root);

  final publicTip = (await _git(['rev-parse', 'refs/remotes/$_remote/public'], cwd: root)).trim();
  final target = ref == null ? publicTip : (await _git(['rev-parse', '--verify', '$ref^{commit}'], cwd: root)).trim();

  // Publish only generated history: the target must sit on the public branch
  // (so an experiment can be held back by picking the commit before it — the
  // filtered branch mirrors main's commit messages one-to-one), and its tree
  // must carry no app_dist.
  if (await _gitExit(['merge-base', '--is-ancestor', target, publicTip], root) != 0) {
    throw _CliError('--ref must name a commit on $_remote/public (got ${target.substring(0, 8)})');
  }
  final topLevel = await _git(['ls-tree', '-d', '--name-only', target], cwd: root);
  if (topLevel.split('\n').contains('app_dist')) {
    throw _CliError('refusing to publish: app_dist present in ${target.substring(0, 8)} — not filtered history?');
  }

  // Where the mirror is now. The filter is deterministic, so a routine
  // publish fast-forwards; anything else (first publish over the legacy
  // lineage, a rewritten main) needs an explicit --force.
  final lsRemote = await _git(['ls-remote', _mirrorUrl, 'refs/heads/$_mirrorBranch'], cwd: root);
  final mirrorSha = lsRemote.trim().isEmpty ? null : lsRemote.trim().split(RegExp(r'\s+')).first;
  var fastForward = mirrorSha == null;
  var delta = 'mirror branch does not exist yet';
  if (mirrorSha != null) {
    final short = mirrorSha.substring(0, 8);
    if (mirrorSha == target) {
      fastForward = true;
      delta = 'mirror is already at the target — nothing to publish';
    } else if (await _gitExit(['cat-file', '-e', '$mirrorSha^{commit}'], root) == 0 &&
        await _gitExit(['merge-base', '--is-ancestor', mirrorSha, target], root) == 0) {
      fastForward = true;
      final n = (await _git(['rev-list', '--count', '$mirrorSha..$target'], cwd: root)).trim();
      delta = '$n new commit(s) since $short';
    } else {
      delta = 'NOT a fast-forward from $short (unrelated or rewritten history)';
    }
  }

  if (json) {
    stdout.writeln(jsonEncode({
      'target': target,
      'mirror': mirrorSha,
      'fastForward': fastForward,
      'dryRun': dryRun,
    }));
  } else {
    out.title('Publish to the open-source mirror');
    out.field('repo', _mirrorUrl);
    out.field('target', '${target.substring(0, 8)}${ref == null ? '  (public tip)' : ''}');
    out.field('mirror', mirrorSha == null ? '(none)' : mirrorSha.substring(0, 8));
    out.field('delta', delta);
  }

  if (mirrorSha == target) return;
  if (!fastForward && !force) {
    throw _CliError('non-fast-forward publish — rerun with --force if the mirror history is meant to be replaced');
  }
  if (dryRun) {
    if (!json) out.dim('  dry run: nothing pushed.');
    return;
  }
  if (!json && !yes && !_confirm(out, 'Publish?')) {
    out.dim('  aborted.');
    return;
  }

  await _git(['push', if (force) '--force', _mirrorUrl, '$target:refs/heads/$_mirrorBranch'], cwd: root);
  if (!json) out.ok('published ${target.substring(0, 8)} → $_mirrorBranch');
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
  patch                  Publish a Shorebird Dart patch of HEAD (tags patch-<edition>-<sha>, pushes it).
  prune-patches          Delete old patch-<edition>-<sha> trigger tags (default: older than 2 months).
  preview <name>         Deploy a web preview of HEAD (tags web-preview-<name>, pushes it).
  prune-previews         List web previews; delete selected ones (Pages + DNS + tag).
  publish                Mirror the generated public branch to the open-source repo.

Release options:
  --edition <dev|next|prod>   Override the branch→edition mapping.
  --min-build <n>             Floor for the next build number — raises the
                               ledger's computed value if it's lower, never
                               lowers it. For build numbers a store or an
                               ad-hoc CI run already consumed outside the tag
                               ledger (e.g. a manual Google Play test upload).
  --dry-run, -n               Show the plan; don't write/commit/tag/push.
  --yes, -y                   Skip the confirmation prompt.

patch options:
  --edition <dev|next|prod>   Override the branch→edition mapping.
  --force                     Patch even when native/dependency files changed.
  --dry-run, -n / --yes, -y   As in release.

prune-patches options:
  --older-than <days>         Age threshold (default 60 — two months).
  --all                       Delete every patch trigger tag.
  --dry-run, -n / --yes, -y   Preview / skip the confirmation.

preview options:
  --dry-run, -n / --yes, -y   As above.

publish options:
  --ref <sha>            Publish up to this commit on origin/public instead of
                          the tip — the way to hold an experiment back while
                          publishing everything before it.
  --force                Allow a non-fast-forward push (first publish over the
                          legacy lineage, or after a main history rewrite).
  --dry-run, -n / --yes, -y   As in release.

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

  void patchLine(String name, String age, {required bool selected}) {
    final note = selected ? _wrap('prune', '33') : _wrap('keep', '2');
    stdout.writeln('  ${_wrap(name.padRight(24), '1')} ${age.padRight(8)} $note');
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
