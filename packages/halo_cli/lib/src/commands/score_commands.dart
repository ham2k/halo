// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `score` and its parts.
//
// One hook call answers all of it — `scoreQsos` scores a whole operation at
// once (DESIGN.md §4: "score 500 QSOs in one call, not 500 calls") — so the
// subcommands differ only in which piece of that answer they print. None of
// them scores less, and none re-scores.

import 'package:args/args.dart';

import '../cli.dart';
import '../json_args.dart';
import '../runtime.dart' show CliUsageError;
import '../score_report.dart';

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
      ..addOption('key', defaultsTo: 'core', help: 'Which scorer (core, cqww, fd…).')
      ..addOption('ref', help: 'The contest ref this scorer scopes to, as JSON.');

    addSubcommand(_ScoreSummariesCommand());
    addSubcommand(_ScoreSectionsCommand());
    addSubcommand(_ScoreQsosCommand());
  }

  @override
  Object? part(Map<String, Object?> result) => result;

  @override
  String markdown(Map<String, Object?> result) =>
      scoreMarkdown(result, qsos: qsos, scorerKey: scorerKey);
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
  String markdown(Map<String, Object?> result) =>
      scoreSummariesMarkdown((result['operationSummary'] as Map?)?.cast<String, Object?>() ?? const {});
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
  String markdown(Map<String, Object?> result) => scoreQsosMarkdown(
        (result['qsoScores'] as Map?)?.cast<String, Object?>() ?? const {},
        qsos: qsos,
      );
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

  String get scorerKey => _scoreArgs.option('key') ?? 'core';

  @override
  Future<int> run() async {
    final op = operation;
    final contacts = qsos;
    if (op == null || contacts == null) {
      throw CliUsageError('$name needs an operation and QSOs: --qson <file>, or --op and --qsos');
    }

    final rawRef = _scoreArgs.option('ref');
    return withRuntime((runtime) async {
      final result = await invoke(runtime, 'scoring', key: scorerKey, method: 'scoreQsos', args: {
        'operation': op,
        'qsos': contacts,
        if (rawRef != null) 'ref': readJsonArg(rawRef, label: '--ref'),
      });
      if (result is! Map) {
        // A scorer that answers with something else is a bug in that scorer,
        // and slicing `null` for a part would report it as an empty score.
        throw CliUsageError('scoring/$scorerKey returned ${result.runtimeType}, not a result object');
      }
      final scored = result.cast<String, Object?>();
      emit(part(scored), markdown: () => markdown(scored));
      return 0;
    });
  }
}
