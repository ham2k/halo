// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_core/halo_core.dart' show HookRef;

import '../cli.dart';
import '../json_args.dart';
import '../runtime.dart' show CliUsageError;

/// The primitive every other command is shorthand for: call any hook method
/// in any category with arbitrary JSON.
///
/// It exists so a hook added tomorrow is reachable today. A wrapper command
/// that goes stale is a nuisance; a surface where a hook is UNREACHABLE
/// without changing this tool is a reason not to use the tool at all.
class InvokeCommand extends ExtCommand {
  @override
  final name = 'invoke';
  @override
  final description = 'Call any hook method directly.';

  @override
  String get invocation => 'halo-ext invoke <category> <method> [--args <json>]';

  InvokeCommand() {
    argParser
      ..addOption('key', help: 'Narrow to one hook key (e.g. --key core, --key pota).')
      ..addFlag('all', negatable: false, help: 'Call every hook in the category, not just the highest-priority one.')
      ..addOption('args', help: 'Hook arguments as JSON, @file, or - for stdin.');
  }

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.length != 2) throw CliUsageError('usage: $invocation');
    final [category, method] = rest;
    final args = readJsonMapArg(argResults!.option('args'), label: '--args') ?? const {};

    if (argResults!.flag('all') && argResults!.option('key') != null) {
      // invokeHookAll has no key parameter — silently ignoring one would
      // report a whole category's results as if they were that key's.
      throw CliUsageError('--all and --key are mutually exclusive');
    }

    return withRuntime((runtime) async {
      final result = argResults!.flag('all')
          ? await invokeAll(runtime, HookRef(category, method), args: args)
          : await invoke(runtime, HookRef(category, method), key: argResults!.option('key'), args: args);
      emit(result);
      return 0;
    });
  }
}
