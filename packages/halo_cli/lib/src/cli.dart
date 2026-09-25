// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The halo-ext command surface.
//
// `invoke` is the primitive: it reaches EVERY hook, including ones added
// after this file was last touched, and is what the friendly commands are
// checked against. The friendly commands exist because typing a
// lookupService request by hand is a paragraph of JSON — they are shorthand,
// never a different code path.

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:halo_core/halo_core.dart' show HookRef;
import 'package:halo_extension_host/halo_extension_host.dart';

import 'bundles.dart';
import 'commands/data_files_command.dart';
import 'commands/hook_commands.dart';
import 'commands/invoke_command.dart';
import 'commands/account_commands.dart';
import 'commands/list_command.dart';
import 'commands/score_commands.dart';
import 'config.dart';
import 'data_files.dart';
import 'host_calls.dart';
import 'json_args.dart';
import 'lookup_store.dart';
import 'runtime.dart';

/// Runs one invocation and returns the process exit code.
Future<int> runHaloExt(List<String> argv) async {
  final runner = CommandRunner<int>('halo-ext', 'Run HaLo extension hooks outside the app: JSON in, JSON out.');

  runner.argParser
    ..addFlag('verbose', abbr: 'v', negatable: false, help: 'Narrate host calls and extension logs on stderr.')
    ..addFlag('compact', negatable: false, help: 'One-line JSON output instead of indented.')
    ..addFlag('md', negatable: false, help: 'Render as markdown instead of JSON, for commands that have a report to render.')
    ..addFlag('offline', negatable: false, help: 'Tell hooks the device is offline (HookContext.online = false).')
    ..addFlag('all-extensions', negatable: false, help: 'Also load extensions that are off by default.')
    ..addOption('bundles', help: 'Directory holding index.json and the built bundles.')
    ..addOption(
      'dev-server',
      help:
          'Take extensions from a running `npm run dev` instead of the built bundles,\n'
          'e.g. --dev-server 127.0.0.1:8787. Overlays what that server serves onto\n'
          'the built ones (it serves no kernel). Dev extensions get no secrets.',
    )
    ..addOption('config', help: 'Config file (default: ${CliConfig.defaultPath}).')
    ..addOption('cache', help: 'Cache directory for downloaded reference data.')
    ..addMultiOption('only', help: 'Load only these extensions (repeatable, comma-separated).')
    ..addMultiOption('exclude', help: 'Do not load these extensions.')
    ..addOption(
      'qson',
      help:
          'A whole log — {operation, qsos} — as a file path, - for stdin, or inline JSON. '
          'A QSON file as PoLo exports one works unedited; --op/--qsos override its halves.',
    )
    ..addOption('op', help: 'Operation: a file path, - for stdin, or inline JSON.')
    ..addOption('qso', help: 'A single QSO: a file path, - for stdin, or inline JSON.')
    ..addOption('qsos', help: 'QSOs as a JSON array: a file path, - for stdin, or inline JSON.')
    ..addOption('spots', help: 'Spots the host has "already fetched", for getSpotsForCall.')
    ..addOption('location', help: 'Device location for getLocation, as "lat,lon".')
    ..addOption('timeout', help: 'Per-hook-call timeout in seconds.', defaultsTo: '30');

  runner
    ..addCommand(ListCommand())
    ..addCommand(AccountCommand())
    ..addCommand(InvokeCommand())
    ..addCommand(LookupCommand())
    ..addCommand(InterpretCommand())
    ..addCommand(SpotsCommand())
    ..addCommand(ExportCommand())
    ..addCommand(ScoreCommand())
    ..addCommand(SuggestCommand())
    ..addCommand(RefCommand())
    ..addCommand(AdifFieldsCommand())
    ..addCommand(DataFilesCommand());

  try {
    return await runner.run(argv) ?? 0;
  } on UsageException catch (e) {
    stderr.writeln(e);
    return 2;
  } on CliUsageError catch (e) {
    stderr.writeln('halo-ext: $e');
    return 2;
  } on QsonShapeError catch (e) {
    stderr.writeln('halo-ext: $e');
    return 2;
  } on BundlesNotBuilt catch (e) {
    stderr.writeln('halo-ext: $e');
    return 2;
  } on DevServerUnreachable catch (e) {
    stderr.writeln('halo-ext: $e');
    return 2;
  } on ExtensionHostException catch (e) {
    stderr.writeln('halo-ext: $e');
    return 1;
  }
}

/// Shared plumbing for every command: the global options, a booted runtime,
/// and JSON output.
abstract class ExtCommand extends Command<int> {
  /// Whether this command reads the downloaded reference data. Opening the
  /// database creates it, so a command that never looks things up should not
  /// leave a file behind on a machine that has never synced.
  bool get needsLookups => true;

  /// Whether an empty cache is worth warning about. False for the commands
  /// whose whole job is to fill it — telling `data-files sync` that the cache
  /// it is about to populate is empty is noise.
  bool get warnsOnColdCache => true;

  /// Whether this command may CREATE the config file named by `--config`.
  /// True only for the commands whose job is to write it: for everything
  /// else a named file that isn't there is a typo, and proceeding with empty
  /// credentials looks like an extension that has none.
  bool get createsConfig => false;

  /// This operator's settings, accounts and secrets. Loaded once, and
  /// available to commands that never boot a runtime — forgetting an
  /// account's credentials must work even for an extension since disabled.
  late final CliConfig config = CliConfig.load(path: globalResults!.option('config'), mustExist: !createsConfig);

  bool get verbose => globalResults!.flag('verbose');
  bool get compact => globalResults!.flag('compact');
  bool get offline => globalResults!.flag('offline');

  Duration get hookTimeout {
    final seconds = int.tryParse(globalResults!.option('timeout') ?? '');
    if (seconds == null || seconds <= 0) throw CliUsageError('--timeout must be a positive number of seconds');
    return Duration(seconds: seconds);
  }

  // Parsed ONCE. These are read from several places in one command, and a
  // `--op -` re-read would find stdin already drained — the second caller
  // would silently see no operation at all.
  late final LogContext log = _resolveLog();

  LogContext _resolveLog() {
    // stdin can only be drained once: a second `-` reads an already-empty
    // stream and lands as "absent", which for --qsos means "no log access"
    // — a wrong answer with no diagnostic anywhere.
    final fromStdin = [
      for (final option in ['qson', 'op', 'qso', 'qsos', 'spots'])
        if (globalResults!.option(option) == '-') '--$option',
    ];
    if (fromStdin.length > 1) {
      throw CliUsageError('only one option can read stdin; ${fromStdin.join(' and ')} both asked for it');
    }
    return LogContext.resolve(
      qson: readJsonMapArg(globalResults!.option('qson'), label: '--qson'),
      operation: readJsonMapArg(globalResults!.option('op'), label: '--op'),
      qsos: readJsonListArg(globalResults!.option('qsos'), label: '--qsos'),
      spots: spotsArg,
    );
  }

  /// The operation this invocation is about, from `--op` or `--qson`.
  Map<String, Object?>? get operation => log.operation;

  List<Map<String, Object?>>? get qsos => log.qsos;

  /// The single in-progress QSO, from `--qso`.
  late final Map<String, Object?>? qsoArg = readJsonMapArg(globalResults!.option('qso'), label: '--qso');

  late final List<Map<String, Object?>> spotsArg = readJsonListArg(globalResults!.option('spots'), label: '--spots') ?? const [];

  /// A JSON-valued option of this SUBcommand (as opposed to the global ones
  /// above), e.g. `score --ref`.
  Object? jsonOption(String name) => readJsonArg(argResults!.option(name), label: '--$name');

  bool get markdownWanted => globalResults!.flag('md');

  /// Prints one result: JSON, or [markdown] when `--md` is set.
  ///
  /// A command with no renderer REFUSES `--md` rather than quietly printing
  /// JSON — an output-format flag that silently does nothing is worse than
  /// one that is unsupported, because the caller believes the format changed.
  void emit(Object? value, {String Function()? markdown}) {
    if (!markdownWanted) return writeJson(value, compact: compact);
    if (markdown == null) {
      throw CliUsageError(
        '--md is not supported by `$name` — it has no report to render, '
        'only the hook result. Drop --md, or pipe the JSON somewhere.',
      );
    }
    stdout.writeln(markdown());
  }

  /// The reference-data store this invocation opened, available to the body
  /// of [withRuntime]. One per invocation: two handles on the same SQLite
  /// file is a lock waiting to happen, and `data-files` writes through this.
  LookupStore get lookups => _lookups!;
  LookupStore? _lookups;

  /// Boots everything this command asked for, runs [body], and tears down.
  Future<int> withRuntime(Future<int> Function(ExtRuntime runtime) body) async {
    final index = BundleIndex.load(dir: globalResults!.option('bundles') != null ? Directory(globalResults!.option('bundles')!) : null);
    final devServer = globalResults!.option('dev-server');
    if (devServer != null && devServer.isNotEmpty) {
      await index.overlayDevServer(normalizeDevServerUrl(devServer));
      if (verbose) {
        final served = index.extensions.where((e) => e.fromDevServer).map((e) => e.key).join(', ');
        stderr.writeln('[dev-server] serving: $served');
      }
    }
    final lookups = _lookups = needsLookups ? LookupStore.open(globalResults!.option('cache') ?? defaultCacheDir()) : null;

    final hostCalls = CliHostCalls(
      config: config,
      index: index,
      lookups: lookups,
      log: log,
      location: location,
      locationAllowlist: {
        for (final entry in index.extensions)
          if (entry.requiresLocation) entry.key,
      },
      verbose: verbose,
    );

    final runtime = await ExtRuntime.start(
      index: index,
      config: config,
      onHostCall: hostCalls.call,
      only: globalResults!.multiOption('only').expand((value) => value.split(',')).toSet(),
      exclude: globalResults!.multiOption('exclude').expand((value) => value.split(',')).toSet(),
      all: globalResults!.flag('all-extensions'),
    );
    // Raw data files (callsign notes) live in the extension's own module
    // state, which dies with the process — the cached copy has to be fed
    // back in before any hook asks for it.
    if (lookups != null) await DataFileSync.replayRawDataFiles(runtime, lookups);

    // Cold cache, in the one place it can be said before a hook answers
    // empty and looks like a bug in the hook.
    if (warnsOnColdCache && lookups != null && !await lookups.hasAnyData) {
      stderr.writeln(
        'halo-ext: the reference-data cache is empty — park/summit lookups and '
        'suggestions will come back empty. Run `halo-ext data-files sync`.',
      );
    }
    if (verbose) {
      for (final line in runtime.host.logLines) {
        stderr.writeln('[extensions] $line');
      }
      runtime.host.logs.listen((line) => stderr.writeln('[extensions] $line'));
    }

    try {
      return await body(runtime);
    } finally {
      await runtime.stop();
      await lookups?.close();
      _lookups = null;
    }
  }

  /// `--location lat,lon`: both the device fix `getLocation` answers with and
  /// the point `suggest` searches around — an operator means one place.
  ({double lat, double lon})? get location {
    final raw = globalResults!.option('location');
    if (raw == null) return null;
    final parts = raw.split(',');
    final lat = parts.length == 2 ? double.tryParse(parts[0].trim()) : null;
    final lon = parts.length == 2 ? double.tryParse(parts[1].trim()) : null;
    if (lat == null || lon == null) throw CliUsageError('--location must be "lat,lon", e.g. 40.7,-74.0');
    return (lat: lat, lon: lon);
  }

  /// Calls one hook, folding in the flags every hook call honors.
  Future<dynamic> invoke(ExtRuntime runtime, HookRef hook, {String? key, Map<String, Object?> args = const {}}) =>
      runtime.host.invoke(hook, key: key, args: _withOnline(args), timeout: hookTimeout);

  /// Calls every hook in a category. The per-source `{key, ok, value|error}`
  /// envelope is passed through rather than flattened: which source answered,
  /// and which one failed, is most of what a caller is asking.
  Future<List<Map<String, dynamic>>> invokeAll(ExtRuntime runtime, HookRef hook, {Map<String, Object?> args = const {}}) =>
      runtime.host.invokeAll(hook, args: _withOnline(args), timeout: hookTimeout);

  /// The flag every hook call carries, on its own — for a caller that builds
  /// its own args rather than going through [invoke] (`scoring.dart`, which is
  /// testable against a bare host precisely because it does not need this
  /// class).
  Map<String, Object?> get onlineArgs => offline ? const {'online': false} : const {};

  /// `--offline` reaches hooks as `args.online`, which is where the kernel
  /// reads it from (kernel.ts builds HookContext per call).
  Map<String, Object?> _withOnline(Map<String, Object?> args) => offline ? {...args, 'online': false} : args;
}
