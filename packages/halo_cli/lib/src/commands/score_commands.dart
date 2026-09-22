// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `score` and its parts.
//
// One hook call per scorer answers all of it — `scoreQsos` scores a whole
// operation at once (DESIGN.md §4: "score 500 QSOs in one call, not 500
// calls") — so the subcommands differ only in which piece of that answer they
// print. None of them scores less, and none re-scores.
//
// By default this selects the scorers the OPERATION needs and merges their
// per-QSO verdicts by the same priority the app applies (contests.md §5.1),
// because this is the tool an operator is pointed at when the app's scoring
// looks wrong: a CLI that ran one scorer in isolation answered a question
// about a program that wasn't the one running, and its `duplicate` for a
// contact the app counts is the most confusing possible answer.
// `--key` keeps the raw single-scorer view, for looking at one scorer alone.

import 'package:args/args.dart';

import '../cli.dart';
import '../json_args.dart';
import '../runtime.dart' show CliUsageError;
import '../score_report.dart';
import '../scoring.dart';

/// `score` — the whole result, and the parent of the part-wise subcommands.
class ScoreCommand extends ScoreCommandBase {
  @override
  final name = 'score';
  @override
  final description = "Score an operation's QSOs.";

  ScoreCommand() {
    // Declared HERE, not on each subcommand, so `score --key cqww sections`
    // and `score sections --key cqww` mean the same thing: package:args walks
    // up to the parent parser for an option a subcommand does not define, and
    // one declaration cannot disagree with itself about the default.
    argParser
      ..addOption(
        'key',
        help:
            'Look at ONE scorer, raw and unmerged (core, cqww, fd…). '
            'Omitted, the scorers this operation needs are selected and merged as the app merges them.',
      )
      ..addOption('ref', help: 'The contest ref this scorer scopes to, as JSON.');

    addSubcommand(_ScoreSummariesCommand());
    addSubcommand(_ScoreSectionsCommand());
    addSubcommand(_ScoreQsosCommand());
  }

  @override
  Object? part(Map<String, Object?> result) => result;

  @override
  String markdown(Map<String, Object?> result) => scoreMarkdown(result, qsos: qsos, scorerKey: scorerKey);
}

/// The operation-wide tallies (`operationSummary`).
class _ScoreSummariesCommand extends ScoreCommandBase {
  @override
  final name = 'summaries';
  @override
  final description = 'Just the operation-wide tallies.';

  @override
  Object? part(Map<String, Object?> result) => result['operationSummary'];

  @override
  String markdown(Map<String, Object?> result) => scoreSummariesMarkdown((result['operationSummary'] as Map?)?.cast<String, Object?>() ?? const {});
}

/// The 24h UTC day buckets (`daySections`).
class _ScoreSectionsCommand extends ScoreCommandBase {
  @override
  final name = 'sections';
  @override
  final description = 'Just the day sections (24h UTC buckets).';

  @override
  Object? part(Map<String, Object?> result) => result['daySections'];

  @override
  String markdown(Map<String, Object?> result) => scoreSectionsMarkdown([
    for (final section in (result['daySections'] as List? ?? const []))
      if (section is Map) section.cast<String, Object?>(),
  ]);
}

/// The per-QSO verdicts (`qsoScores`).
class _ScoreQsosCommand extends ScoreCommandBase {
  @override
  final name = 'qsos';
  @override
  final description = 'Just the per-QSO verdicts: points, notices, alerts.';

  @override
  Object? part(Map<String, Object?> result) => result['qsoScores'];

  @override
  String markdown(Map<String, Object?> result) => scoreQsosMarkdown((result['qsoScores'] as Map?)?.cast<String, Object?>() ?? const {}, qsos: qsos);
}

/// Shared by `score` and its subcommands: run the scorer once, print the part
/// this command is about.
abstract class ScoreCommandBase extends ExtCommand {
  /// Which slice of the hook's result this command prints, as JSON.
  Object? part(Map<String, Object?> result);

  /// The same slice as markdown, for `--md`.
  String markdown(Map<String, Object?> result);

  /// `--key`/`--ref` live on the `score` parent, so a subcommand reads them
  /// from there — and the parent reads its own.
  ArgResults get _scoreArgs => parent is ScoreCommandBase ? parent!.argResults! : argResults!;

  /// One scorer, raw — or null for the merged pass over whatever this
  /// operation actually needs.
  String? get scorerKey => _scoreArgs.option('key');

  @override
  Future<int> run() async {
    final op = operation;
    final contacts = qsos;
    if (op == null || contacts == null) {
      throw CliUsageError('$name needs an operation and QSOs: --qson <file>, or --op and --qsos');
    }

    final rawRef = _scoreArgs.option('ref');
    return withRuntime((runtime) async {
      final ref = rawRef == null ? null : readJsonArg(rawRef, label: '--ref');
      final single = scorerKey;
      // A merged pass hands each scorer the ref that SELECTED it, so there is
      // nowhere for one the caller typed to go. Refused rather than quietly
      // dropped: this is the tool for finding out why scoring said something,
      // and an ignored argument is the worst possible answer from it.
      if (ref != null && single == null) {
        throw CliUsageError('--ref applies to --key: a merged pass gives each scorer the ref that selected it');
      }
      final scored = single != null
          ? {
              single: await scoreWithOneScorer(
                runtime.host,
                key: single,
                operation: op,
                qsos: contacts,
                ref: ref,
                // The same segments the merged pass resolves. Without them this
                // scorer folds across stretches it was not running for, so the
                // one view an operator is told to reach for to see a scorer's
                // own rules shows something the app never does.
                segments: segmentsOf(op, contacts),
                extraArgs: onlineArgs,
                timeout: hookTimeout,
              ),
            }
          : await scoreOperation(runtime.host, operation: op, qsos: contacts, extraArgs: onlineArgs, timeout: hookTimeout);

      // One scorer keeps the bare result it always printed; several are keyed
      // by scorer, the shape the app caches them in.
      if (single != null) {
        final only = scored[single]!;
        emit(part(only), markdown: () => markdown(only));
      } else {
        // A scorer that failed carries `error` instead of a result, and the
        // parts would slice `null` out of it — printing nothing, which reads
        // exactly like a scorer with nothing to say. This is the tool someone
        // reaches for BECAUSE a scorer is misbehaving, so the failure is
        // passed through whichever view they asked for.
        emit(
          {for (final entry in scored.entries) entry.key: entry.value['error'] == null ? part(entry.value) : entry.value},
          // Each scorer's section under its own heading: in a merged pass the
          // parts alone would run together with nothing saying whose they are.
          markdown: () => [
            for (final entry in scored.entries)
              '## `${entry.key}`\n\n${entry.value['error'] == null ? markdown(entry.value) : '**failed:** ${entry.value['error']}'}',
          ].join('\n\n'),
        );
      }
      return 0;
    });
  }
}
