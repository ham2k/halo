// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Shorthand for the hooks people actually run from a terminal.
//
// Each of these is one `invoke` with its arguments assembled — nothing here
// interprets a hook's ANSWER. The moment a wrapper starts reshaping results
// it stops being a way to see what the extension did, which is the only
// reason this tool exists.

import 'dart:io';

import '../cli.dart';
import '../runtime.dart' show CliUsageError;

/// `lookup <CALL>` — the whole callsign decoration pass, through the
/// lookupService orchestrator, exactly as the logging panel asks for it.
class LookupCommand extends ExtCommand {
  @override
  final name = 'lookup';
  @override
  final description = 'Look up a callsign through the lookupService orchestrator.';
  @override
  String get invocation => 'halo-ext lookup <CALL>';

  LookupCommand() {
    argParser.addFlag(
      'recent-context',
      negatable: false,
      help:
          'Also run recentContextLookup hooks — what this station is doing RIGHT NOW '
          '(spots, the last minutes of the log). Only meaningful for a contact in progress.',
    );
  }

  @override
  Future<int> run() async {
    final call = _single(argResults!.rest, 'CALL');
    return withRuntime((runtime) async {
      emit(
        await invoke(
          runtime,
          'lookupService',
          key: 'core',
          method: 'lookupCallInfo',
          args: {
            'callInfo': {'call': call},
            'qso': _qsoFor(call),
            'operation': operation ?? const {},
            if (argResults!.flag('recent-context')) 'recentContext': true,
          },
        ),
      );
      return 0;
    });
  }

  Map<String, Object?> _qsoFor(String call) {
    final qso = qsoArg ?? const <String, Object?>{};
    final their = ((qso['their'] as Map?) ?? const {}).cast<String, Object?>();
    return {
      ...qso,
      // The CALL argument wins. Spreading `their` last instead lets a --qso
      // captured for someone else silently redirect the lookup: you ask about
      // W1AW, the file says K1ABC, and K1ABC's answer is printed as W1AW's.
      'their': {...their, 'call': call},
    };
  }
}

/// `command <TEXT>` — what the call field would make of that text.
class InterpretCommand extends ExtCommand {
  @override
  final name = 'command';
  @override
  final description = 'Interpret call-field text as a command, or list the command catalog.';
  @override
  String get invocation => 'halo-ext command <TEXT>';

  InterpretCommand() {
    argParser
      ..addFlag(
        'execute',
        negatable: false,
        help:
            'Set execute: true — the flag a hook reads to know this call is the real one, '
            'not a describe-preview. Does NOT apply the resulting actions; nothing here has a log to apply them to.',
      )
      ..addFlag('catalog', negatable: false, help: 'List the commands every hook advertises (⌘K dialog).');
  }

  @override
  Future<int> run() async {
    return withRuntime((runtime) async {
      if (argResults!.flag('catalog')) {
        emit(await invokeAll(runtime, 'command', method: 'catalog'));
        return 0;
      }
      final input = _single(argResults!.rest, 'TEXT');
      // Fan-out, not a single call: the core applies the first non-null
      // result in priority order, so seeing which OTHER hooks also claimed
      // the text is the point.
      emit(
        await invokeAll(
          runtime,
          'command',
          method: 'interpret',
          args: {
            'input': input,
            if (operation != null) 'operation': operation,
            if (qsoArg != null) 'qso': qsoArg,
            if (argResults!.flag('execute')) 'execute': true,
          },
        ),
      );
      return 0;
    });
  }
}

/// `spots` — fetch from every spot source, or one named source.
class SpotsCommand extends ExtCommand {
  @override
  final name = 'spots';
  @override
  final description = 'Fetch spots from the spot sources.';

  SpotsCommand() {
    argParser.addOption('source', help: 'Only this source (e.g. --source pota).');
  }

  @override
  Future<int> run() async {
    return withRuntime((runtime) async {
      final source = argResults!.option('source');
      emit(source != null ? await invoke(runtime, 'spots', key: source, method: 'fetchSpots') : await invokeAll(runtime, 'spots', method: 'fetchSpots'));
      return 0;
    });
  }
}

/// `export` — the two-step export flow: which options exist, then generate.
class ExportCommand extends ExtCommand {
  @override
  final name = 'export';
  @override
  final description = 'List export options for an operation, or generate one.';

  ExportCommand() {
    argParser
      ..addFlag('list', negatable: false, help: 'List the options every export hook suggests, and stop.')
      ..addOption('key', help: 'Which export hook to generate with (e.g. --key adif).')
      ..addOption('type', help: "The option's exportType, passed back to generateExport.")
      ..addFlag('compact-filenames', negatable: false, help: "Ask for the user's compact filename style.")
      ..addOption(
        'out',
        help:
            'Write the generated content to this file (or into this directory, under the '
            "export's own filename) instead of embedding it in the JSON.",
      );
  }

  @override
  Future<int> run() async {
    final op = operation;
    final contacts = qsos;
    if (op == null || contacts == null) {
      throw CliUsageError('export needs an operation and QSOs: --qson <file>, or --op and --qsos');
    }

    return withRuntime((runtime) async {
      final args = <String, Object?>{'operation': op, 'qsos': contacts, if (argResults!.flag('compact-filenames')) 'compactFilenames': true};
      if (argResults!.flag('list')) {
        emit(await invokeAll(runtime, 'export', method: 'suggestExportOptions', args: args));
        return 0;
      }

      final result = await invoke(
        runtime,
        'export',
        key: argResults!.option('key'),
        method: 'generateExport',
        args: {...args, if (argResults!.option('type') != null) 'exportType': argResults!.option('type')},
      );

      final out = argResults!.option('out');
      if (out == null || result is! Map) {
        emit(result);
        return 0;
      }
      // Exports are files. Keeping the body out of stdout means the JSON stays
      // readable and an ADIF with CRLFs lands on disk byte-for-byte.
      final target = FileSystemEntity.isDirectorySync(out) ? File('$out/${result['filename'] ?? 'export.txt'}') : File(out);
      target.writeAsStringSync('${result['content'] ?? ''}');
      emit({
        for (final entry in result.entries)
          if (entry.key != 'content') entry.key: entry.value,
        'writtenTo': target.path,
        'bytes': target.lengthSync(),
      });
      return 0;
    });
  }
}

/// `suggest` — the Activities view's search and nearby list.
class SuggestCommand extends ExtCommand {
  @override
  final name = 'suggest';
  @override
  final description = 'Ask every activity for suggestions, by search term or by location.';
  @override
  String get invocation => 'halo-ext suggest [SEARCH TERM]';

  SuggestCommand() {
    argParser.addOption('callsign', help: 'The callsign to suggest for (defaults to the operation\'s).');
  }

  @override
  Future<int> run() async {
    return withRuntime((runtime) async {
      final term = argResults!.rest.join(' ');
      final fix = location;
      emit(
        await invokeAll(
          runtime,
          'activity',
          method: 'suggest',
          args: {
            'operation': operation ?? const {},
            if (fix != null) 'location': {'lat': fix.lat, 'lon': fix.lon},
            if (argResults!.option('callsign') != null) 'callsign': argResults!.option('callsign'),
            if (term.isNotEmpty) 'searchTerm': term,
          },
        ),
      );
      return 0;
    });
  }
}

/// `ref <TYPE> <REF>` — validate, decorate, or title from one reference.
class RefCommand extends ExtCommand {
  @override
  final name = 'ref';
  @override
  final description = 'Validate, decorate, or take an operation title from a reference.';
  @override
  String get invocation => 'halo-ext ref <TYPE> <REF>';

  RefCommand() {
    argParser
      ..addFlag('validate', negatable: false, help: 'Call validateRef instead of decorateRef.')
      ..addFlag('title', negatable: false, help: 'Call suggestOperationTitle instead (needs --op).');
  }

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.length != 2) throw CliUsageError('usage: $invocation');
    final [type, ref] = rest;
    final method = argResults!.flag('validate')
        ? 'validateRef'
        : argResults!.flag('title')
        ? 'suggestOperationTitle'
        : 'decorateRef';

    return withRuntime((runtime) async {
      emit(
        await invoke(
          runtime,
          'ref:$type',
          method: method,
          args: {
            'ref': {'type': type, 'ref': ref},
            if (method == 'suggestOperationTitle') 'operation': operation ?? const {},
          },
        ),
      );
      return 0;
    });
  }
}

/// `adif-fields` — the program fields activities contribute to one QSO's
/// ADIF record(s).
class AdifFieldsCommand extends ExtCommand {
  @override
  final name = 'adif-fields';
  @override
  final description = 'Show the ADIF fields activities contribute for one QSO.';

  AdifFieldsCommand() {
    argParser.addFlag(
      'combinations',
      negatable: false,
      help:
          'Call fieldCombinationsForOneQSO — one field set per ADIF RECORD, for a contact '
          'that owes several (a station standing in two parks).',
    );
  }

  @override
  Future<int> run() async {
    final qso = qsoArg;
    if (qso == null) throw CliUsageError('adif-fields needs --qso');
    return withRuntime((runtime) async {
      emit(
        await invokeAll(
          runtime,
          'adifFields',
          method: argResults!.flag('combinations') ? 'fieldCombinationsForOneQSO' : 'fieldsForOneQSO',
          args: {'qso': qso, 'operation': operation ?? const {}},
        ),
      );
      return 0;
    });
  }
}

String _single(List<String> rest, String label) {
  if (rest.length != 1) throw CliUsageError('expected exactly one $label argument');
  return rest.single;
}
