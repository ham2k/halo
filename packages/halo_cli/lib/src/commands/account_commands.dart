// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `account` — storing the credentials extensions ask the host for.
//
// The app keeps these in the platform keychain, keyed by each account hook's
// `kvKey`. There is no keychain here, so they go in the config file — which
// is why that file is written 0600 and why nothing in this group ever prints
// a stored value back. A `--field pass=…` on the command line is already in
// the shell's history before this process starts, so secret fields are
// PROMPTED for by default, with the terminal's echo off.

import 'dart:io';

import 'package:args/command_runner.dart';

import '../cli.dart';
import '../runtime.dart' show CliUsageError, ExtRuntime;

class AccountCommand extends Command<int> {
  @override
  final name = 'account';
  @override
  final description = 'List, store, test and forget extension account credentials.';

  AccountCommand() {
    addSubcommand(_AccountListCommand());
    addSubcommand(_AccountSetCommand());
    addSubcommand(_AccountTestCommand());
    addSubcommand(_AccountForgetCommand());
  }
}

/// What the loaded extensions offer, and whether anything is stored for each.
///
/// Never the values: the point of this row is "is this connected", and an
/// operator running `account list` to check that should not have a password
/// land in their scrollback.
class _AccountListCommand extends AccountCommandBase {
  @override
  final name = 'list';
  @override
  final description = 'List the accounts extensions offer, and what is stored for each.';

  @override
  Future<int> run() => withRuntime((runtime) async {
        final accounts = await definitions(runtime);
        emit([
          for (final account in accounts)
            {
              'key': account.key,
              'kvKey': account.kvKey,
              'label': account.label,
              if (account.description != null) 'description': account.description,
              'fields': [
                for (final field in account.fields)
                  {'key': field.key, 'label': field.label, 'type': field.type},
              ],
              'oauth2': account.usesOAuth,
              // Whether, not what.
              'storedCredentials': stored(account.kvKey, 'credentials').keys.toList()..sort(),
              'hasSession': stored(account.kvKey, 'session').isNotEmpty,
            },
        ]);
        return 0;
      });
}

/// Stores credentials for one account.
class _AccountSetCommand extends AccountCommandBase {
  @override
  final name = 'set';
  @override
  final description = 'Store credentials for an account.';
  @override
  String get invocation => 'halo-ext account set <ACCOUNT> [field=value …]';

  _AccountSetCommand() {
    argParser
      ..addFlag('test',
          negatable: false,
          help: "Call the extension's testCredentials with what you entered, before storing.")
      ..addFlag('stdin',
          negatable: false,
          help: 'Read field values as `key=value` lines on stdin instead of prompting. '
              'For scripts; nothing is echoed either way.');
  }

  @override
  bool get createsConfig => true;

  @override
  Future<int> run() => withRuntime((runtime) async {
        final account = await resolve(runtime, accountArg);
        final useStdin = argResults!.flag('stdin');
        final given = assignmentsFor(
          account: account,
          commandLine: argResults!.rest.skip(1),
          stdinLines: useStdin ? _stdinLines() : const [],
        );

        final values = <String, Object?>{...stored(account.kvKey, 'credentials'), ...given};
        if (useStdin) {
          // Already folded in by assignmentsFor.
        } else if (stdin.hasTerminal) {
          for (final field in account.fields) {
            if (given.containsKey(field.key)) continue;
            final entered = _prompt(field, current: values[field.key]);
            if (entered != null) values[field.key] = entered;
          }
        } else {
          // No terminal — a script, a CI step, a test. Prompting here would
          // block on a stdin nobody is going to type into, which reads as a
          // hang rather than as a question. Take what was passed, and name
          // what is still missing so a half-configured account is not
          // mistaken for a working one.
          final missing = account.fields.where((field) => !values.containsKey(field.key));
          if (missing.isNotEmpty) {
            stderr.writeln('halo-ext: no terminal to prompt on; ${account.kvKey} still has no '
                '${missing.map((field) => '`${field.key}`').join(', ')} '
                '(pass `field=value`, or feed `--stdin`)');
          }
        }

        if (argResults!.flag('test')) {
          final verdict = await test(runtime, account, values);
          stderr.writeln('halo-ext: $verdict');
        }

        config.accounts.putIfAbsent(account.kvKey, () => {})['credentials'] = values;
        config.save();
        stderr.writeln('halo-ext: stored ${values.keys.length} field(s) for ${account.kvKey} '
            'in ${config.file?.path}');
        emit({'kvKey': account.kvKey, 'storedCredentials': values.keys.toList()..sort()});
        return 0;
      });

  /// Asks for one field. Secrets are read with the terminal's echo off, and
  /// an empty answer keeps whatever is already stored rather than blanking it
  /// — retyping a password to change an unrelated field is not a thing.
  String? _prompt(AccountField field, {Object? current}) {
    final known = current != null && '$current'.isNotEmpty;
    final suffix = field.isSecret
        ? (known ? ' [stored, Enter to keep]' : '')
        : (known ? ' [$current]' : '');
    // stderr, not stdout: stdout is the JSON result, and a prompt written
    // into it corrupts whatever is parsing the output.
    stderr.write('${field.label.isEmpty ? field.key : field.label}$suffix: ');

    // Echo control is best-effort. `stdin.hasTerminal` is not a reliable
    // guard — with stdin redirected it can still report a terminal while
    // every echoMode call throws StdinException — so the calls themselves
    // are what has to tolerate failure. A secret we could not hide is still
    // read; refusing to accept a password because the terminal would echo it
    // helps nobody, and the operator can see whether it echoed.
    final restore = field.isSecret ? _setEcho(false) : null;
    try {
      final line = stdin.readLineSync();
      if (field.isSecret) stderr.writeln();
      return (line == null || line.isEmpty) ? null : line;
    } finally {
      if (restore != null) _setEcho(restore);
    }
  }

  /// Sets stdin echo, returning what it was, or null when this stdin has no
  /// echo to set.
  bool? _setEcho(bool on) {
    try {
      final was = stdin.echoMode;
      stdin.echoMode = on;
      return was;
    } on StdinException {
      return null;
    }
  }

  Iterable<String> _stdinLines() sync* {
    while (true) {
      final line = stdin.readLineSync();
      if (line == null) return;
      if (line.trim().isNotEmpty) yield line;
    }
  }

}

/// The `field=value` assignments for one `account set`, from the command line
/// and from `--stdin` together, validated against what the extension declared.
///
/// One function over BOTH sources, because validating them separately is how
/// the stdin path came to skip the check entirely: a typo piped in was stored
/// silently, leaving the account looking configured while the extension read
/// null for the field it actually asked for. Pure, so the rule can be tested
/// without a terminal or a subprocess.
Map<String, String> assignmentsFor({
  required AccountDefinition account,
  Iterable<String> commandLine = const [],
  Iterable<String> stdinLines = const [],
}) {
  final values = <String, String>{};
  for (final assignment in [...commandLine, ...stdinLines]) {
    final split = assignment.indexOf('=');
    if (split <= 0) throw CliUsageError('expected `field=value`, got `$assignment`');
    values[assignment.substring(0, split).trim()] = assignment.substring(split + 1);
  }

  final unknown = values.keys.where((key) => !account.fields.any((field) => field.key == key));
  if (unknown.isNotEmpty) {
    throw CliUsageError('${account.kvKey} has no field ${unknown.map((key) => '`$key`').join(', ')} — '
        'it takes ${account.fields.map((field) => '`${field.key}`').join(', ')}');
  }
  return values;
}

/// Asks the extension whether the stored credentials work.
class _AccountTestCommand extends AccountCommandBase {
  @override
  final name = 'test';
  @override
  final description = "Ask the extension whether an account's stored credentials work.";
  @override
  String get invocation => 'halo-ext account test <ACCOUNT>';

  @override
  Future<int> run() => withRuntime((runtime) async {
        final account = await resolve(runtime, accountArg);
        final credentials = stored(account.kvKey, 'credentials');
        if (credentials.isEmpty) {
          throw CliUsageError('nothing stored for ${account.kvKey} — run `halo-ext account set ${account.key}`');
        }
        emit({'kvKey': account.kvKey, 'result': await test(runtime, account, credentials)});
        return 0;
      });
}

/// Removes what is stored, which is the counterpart of storing it.
class _AccountForgetCommand extends AccountCommandBase {
  @override
  final name = 'forget';
  @override
  final description = "Remove an account's stored credentials and session.";
  @override
  String get invocation => 'halo-ext account forget <ACCOUNT>';

  @override
  Future<int> run() async {
    // No runtime: credentials for an extension you have since disabled must
    // still be removable, and booting a runtime to delete a map is silly.
    // Keyed by kvKey, which is what the config stores — `set`/`test` accept
    // the hook key too, but resolving that needs a runtime, and an account
    // whose extension is gone must still be removable. Naming what IS stored
    // beats guessing at the mapping.
    final removed = config.accounts.remove(accountArg);
    if (removed == null) {
      final stored = config.accounts.keys.toList()..sort();
      throw CliUsageError('nothing stored for `$accountArg`'
          '${stored.isEmpty ? ' (nothing is stored at all)' : ' — stored: ${stored.join(', ')}'}');
    }
    config.save();
    stderr.writeln('halo-ext: forgot $accountArg');
    emit({'kvKey': accountArg, 'forgot': true});
    return 0;
  }
}

/// One `account` hook's definition, as the kernel reports it.
class AccountDefinition {
  final String key;
  final String kvKey;
  final String label;
  final String? description;
  final List<AccountField> fields;
  final bool usesOAuth;

  AccountDefinition({
    required this.key,
    required this.kvKey,
    required this.label,
    required this.description,
    required this.fields,
    required this.usesOAuth,
  });

  factory AccountDefinition.fromJson(Map<String, Object?> json) => AccountDefinition(
        key: json['key'] as String? ?? json['kvKey'] as String? ?? '?',
        kvKey: json['kvKey'] as String? ?? json['key'] as String? ?? '?',
        label: json['label'] as String? ?? json['key'] as String? ?? '?',
        description: json['description'] as String?,
        fields: [
          for (final field in (json['fields'] as List? ?? const []))
            if (field is Map) AccountField.fromJson(field.cast<String, Object?>()),
        ],
        usesOAuth: json['oauth2'] != null,
      );
}

class AccountField {
  final String key;
  final String label;
  final String type;

  AccountField({required this.key, required this.label, required this.type});

  factory AccountField.fromJson(Map<String, Object?> json) => AccountField(
        key: json['key'] as String? ?? '?',
        label: json['label'] as String? ?? json['key'] as String? ?? '?',
        type: json['type'] as String? ?? 'text',
      );

  bool get isSecret => type == 'secret';
}

abstract class AccountCommandBase extends ExtCommand {
  /// The account named on the command line, matched against either the hook
  /// key or the `kvKey` — the two differ for an extension with more than one
  /// account, and an operator reading `account list` may quote either.
  String get accountArg {
    final rest = argResults!.rest;
    if (rest.isEmpty) throw CliUsageError('usage: $invocation');
    return rest.first;
  }

  Future<List<AccountDefinition>> definitions(ExtRuntime runtime) async {
    final entries = await invokeAll(runtime, 'account', method: 'getDefinition');
    return [
      for (final entry in entries)
        if (entry['ok'] == true && entry['value'] is Map)
          AccountDefinition.fromJson((entry['value'] as Map).cast<String, Object?>()),
    ];
  }

  Future<AccountDefinition> resolve(ExtRuntime runtime, String wanted) async {
    final accounts = await definitions(runtime);
    for (final account in accounts) {
      if (account.key == wanted || account.kvKey == wanted) return account;
    }
    throw CliUsageError('no account `$wanted` among ${accounts.map((a) => a.key).join(', ')} — '
        'is the extension that offers it loaded? (`--all-extensions` loads the ones off by default)');
  }

  /// `testCredentials` is keyed by the HOOK key, not the kvKey: the kvKey
  /// names where credentials are stored, the hook key names who to ask.
  Future<String> test(ExtRuntime runtime, AccountDefinition account, Map<String, Object?> credentials) async {
    // Called WITHOUT the usual --offline injection: testCredentials takes the
    // credential map itself as its args (types.ts: `Record<string,string>`),
    // not a context bag, so folding `online` in would hand the extension a
    // field its own account never declared.
    final verdict = await runtime.host.invokeHook('account',
        key: account.key, method: 'testCredentials', args: credentials, timeout: hookTimeout);
    return verdict is String ? verdict : '$verdict';
  }

  Map<String, Object?> stored(String kvKey, String kind) {
    final value = config.accounts[kvKey]?[kind];
    return value is Map ? value.cast<String, Object?>() : const {};
  }
}
