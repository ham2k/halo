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
    // Push HEAD to the *upstream* branch (e.g. `dist`), NOT the local branch
    // name: the local branch is often `main-dist-private`, and a same-named
    // `git push <remote> main-dist-private` targets a different (stale) remote
    // ref that rejects the push. Pushing to the upstream keeps the target
    // identical to what _checkInSync already verified.
    final upstreamBranch = upstream.substring(_remote.length + 1);
    out.dim('  Pushing HEAD → $upstream + tag $tagName …');
    await _git(['push', _remote, 'HEAD:refs/heads/$upstreamBranch'], cwd: root);
    await _git(['push', _remote, 'refs/tags/$tagName'], cwd: root);
    out.ok('Pushed.');
  } else {
    out.dim("  Branch upstream is '${upstream ?? '<none>'}' (not on $_remote) — commit + tag are local; skipping push.");
  }
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

Release options:
  --edition <dev|next|prod>   Override the branch→edition mapping.
  --dry-run, -n               Show the plan; don't write/commit/tag/push.
  --yes, -y                   Skip the confirmation prompt.

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
