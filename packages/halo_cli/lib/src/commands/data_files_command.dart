// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:args/command_runner.dart';

import '../cli.dart';
import '../data_files.dart';
import '../runtime.dart' show CliUsageError, cliUserAgent;

/// The reference data (`data-files sync`, `data-files list`).
///
/// This is the one command group that WRITES the cache. Everything else reads
/// it, which is what keeps an ordinary invocation stateless while a 181k-row
/// summit list stays on disk between runs.
class DataFilesCommand extends Command<int> {
  @override
  final name = 'data-files';
  @override
  final description = 'Download and inspect the offline reference data (parks, summits, notes).';

  DataFilesCommand() {
    addSubcommand(_DataFilesListCommand());
    addSubcommand(_DataFilesSyncCommand());
  }
}

class _DataFilesListCommand extends ExtCommand {
  @override
  final name = 'list';
  @override
  final description = 'List every registered data file and what the cache holds for it.';

  @override
  bool get warnsOnColdCache => false;

  @override
  Future<int> run() => withRuntime((runtime) async {
        final counts = await lookups.counts();
        final defs = await DataFileSync(
          runtime: runtime,
          store: lookups,
          userAgent: cliUserAgent(runtime.index),
        ).definitions();
        emit({
          'cache': lookups.file.path,
          'files': [
            for (final def in defs)
              {
                'key': def.key,
                'name': def.name,
                'extension': def.extensionKey,
                'fetchType': def.fetchType,
                'category': def.category,
                // A raw file never becomes lookup rows, so a zero here is its
                // normal state, not an empty cache.
                'cachedRows': counts[def.category] ?? 0,
              },
          ],
        });
        return 0;
      });
}

class _DataFilesSyncCommand extends ExtCommand {
  @override
  final name = 'sync';
  @override
  final description = 'Download data files and import them into the cache.';

  @override
  bool get warnsOnColdCache => false;
  @override
  String get invocation => 'halo-ext data-files sync [KEY…]';

  @override
  Future<int> run() => withRuntime((runtime) async {
        final sync = DataFileSync(
          runtime: runtime,
          store: lookups,
          userAgent: cliUserAgent(runtime.index),
          verbose: verbose,
        );
        final wanted = argResults!.rest.toSet();
        final defs = await sync.definitions();
        final selected = wanted.isEmpty ? defs : [for (final def in defs) if (wanted.contains(def.key)) def];
        if (selected.isEmpty) {
          throw CliUsageError(wanted.isEmpty
              ? 'no data files are registered (are the extensions that own them loaded?)'
              : 'no such data file: ${wanted.join(', ')} (try `halo-ext data-files list`)');
        }

        // Serial, not parallel: they all queue through one single-threaded JS
        // engine anyway, and a serial run keeps the progress lines and any
        // failure attributable to one file.
        final results = <DataFileResult>[];
        for (final def in selected) {
          results.add(await sync.import(def));
        }
        emit({
          'cache': lookups.file.path,
          'files': [for (final result in results) result.toJson()],
        });
        // A partial sync is a failure worth an exit code: a script that syncs
        // and then queries would otherwise carry on against data it never got.
        return results.any((result) => result.error != null) ? 1 : 0;
      });
}
