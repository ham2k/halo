// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the CLI stands in for when an extension asks the host about the user:
// settings, account credentials, build-time secrets, which extensions are on.
//
// The app keeps these in SharedPreferences and the platform keychain. Neither
// exists here, so one JSON file holds all of it. That file is as sensitive as
// a keychain — it can hold a QRZ password and a SOTA refresh token — so it is
// written 0600 and never echoed back by any command.

import 'dart:convert';
import 'dart:io';

import 'runtime.dart' show CliUsageError;

/// The read view an extension gets from `host.getSettings()`.
///
/// Shape and defaults mirror ExtensionService's `getSettings` case, because
/// extensions read specific keys out of it and a missing one reads as `false`
/// or `undefined` rather than as "the CLI didn't implement that". Anything an
/// operator sets in the config file's `settings` map merges OVER this.
const defaultSettings = <String, Object?>{
  'developerMode': false,
  'locale': 'en',
  // Machine-facing (ADIF PROGRAMID, a spot's `source`) — the same fixed name
  // the app reports, so a file exported here matches one exported there.
  'appName': 'Ham2K Logger',
  'edition': 'dev',
  'themeMode': 'system',
  'fontScale': 'normal',
  'distanceUnits': 'kilometers',
  'syncEnabled': false,
  'operatorCall': '',
  'leftieMode': false,
  'fieldsOnTop': false,
  'dxFlags': 'dx',
  'showBearing': false,
  'switchSentRcvd': false,
  'jumpAfterRST': false,
  'defaultReport': '',
  'defaultReportCW': '',
  'defaultReportFT8': '',
  'bands': ['80m', '40m', '30m', '20m', '17m', '15m', '12m', '10m', '6m', '2m'],
  'modes': ['SSB', 'CW', 'FT8', 'FT4', 'FM'],
  'showRSTFields': true,
  'showStateField': false,
  'showGridField': false,
  'showDeletedQSOs': false,
  'showQsoNumbers': true,
  'consentAppData': false,
  'consentOpData': false,
};

/// Everything the CLI knows about this operator, loaded from one JSON file.
class CliConfig {
  /// Where it came from, or null for the defaults-only config a first run
  /// gets. [save] needs this, so a command that writes without a file says so
  /// rather than silently dropping the write.
  final File? file;

  /// Core settings, already merged over [defaultSettings].
  final Map<String, Object?> settings;

  /// Per-extension settings groups, keyed `extension_<ns>` exactly as
  /// SettingsService stores them — that key shape is what `setSettings`
  /// namespacing produces and what extensions read back.
  final Map<String, Map<String, Object?>> extensionSettings;

  /// Account credentials and sessions by `kvKey`, the account hook's own
  /// identifier: `{qrz: {credentials: {...}, session: {...}}}`.
  final Map<String, Map<String, Object?>> accounts;

  /// Build-time values behind `host.secret(name)`, by NAME. Scoping to
  /// extensions happens at runtime start, never here.
  final Map<String, String> secrets;

  /// `{key: enabled}`, overriding the manifest's `enabledByDefault` the same
  /// way the app's Extensions panel does.
  final Map<String, bool> extensionOverrides;

  /// Setting names that came from the environment on this run. Excluded from
  /// [save] for the same reason as [environmentSecrets]: `HALO_SETTING_x=1`
  /// is an override for one invocation, and writing it into the file would
  /// turn it into stored state the operator never chose.
  final Set<String> environmentSettings;

  /// Secret names that came from the environment on THIS run, so [save] can
  /// leave them out. Recorded at load rather than re-read at save: what a
  /// write must not persist is what this invocation was handed, and re-asking
  /// the environment later is a different question that happens to usually
  /// have the same answer.
  final Set<String> environmentSecrets;

  CliConfig({
    this.file,
    Map<String, Object?>? settings,
    Map<String, Map<String, Object?>>? extensionSettings,
    Map<String, Map<String, Object?>>? accounts,
    Map<String, String>? secrets,
    Map<String, bool>? extensionOverrides,
    this.environmentSecrets = const {},
    this.environmentSettings = const {},
  })  : settings = {...defaultSettings, ...?settings},
        extensionSettings = extensionSettings ?? {},
        accounts = accounts ?? {},
        secrets = secrets ?? {},
        extensionOverrides = extensionOverrides ?? {};

  /// The default config path: `$XDG_CONFIG_HOME/ham2k/halo-cli.json`, or
  /// `~/.config/ham2k/halo-cli.json`.
  static String get defaultPath => defaultPathIn(Platform.environment);

  /// [defaultPath] against a given environment — one source of truth for
  /// where the file lives, and the seam that keeps a test off the
  /// developer's own config.
  static String defaultPathIn(Map<String, String> env) {
    final xdg = env['XDG_CONFIG_HOME'];
    final base = (xdg != null && xdg.isNotEmpty) ? xdg : '${_home(env)}/.config';
    return '$base/ham2k/halo-cli.json';
  }

  /// Loads [path] (default [defaultPath]). A missing file is not an error —
  /// most commands need no configuration at all, and demanding one before the
  /// first lookup would be theater.
  ///
  /// Environment overrides are applied last and win: `HALO_SECRET_<NAME>`
  /// supplies one build-time secret, `HALO_SETTING_<key>=<json-or-string>`
  /// one core setting. They are the channel for CI and for one-off runs; the
  /// file is the channel for an operator's own machine.
  /// [mustExist] is what separates a typo from a first run at a chosen path.
  /// A command that only READS config must fail on a named file that isn't
  /// there — running with none of the credentials the operator meant to pass
  /// looks exactly like an extension that has none. A command that WRITES one
  /// (`account set`) must be able to create it, which is why [save] makes the
  /// parent directory.
  factory CliConfig.load({String? path, Map<String, String>? environment, bool mustExist = true}) {
    final env = environment ?? Platform.environment;
    final file = File(path ?? defaultPathIn(env));
    var json = const <String, Object?>{};
    if (file.existsSync()) {
      final Object? decoded;
      try {
        decoded = jsonDecode(file.readAsStringSync());
      } on FormatException catch (e) {
        throw CliUsageError('config file is not valid JSON: ${file.path}\n$e');
      }
      // A file holding a JSON array or scalar parses fine and then fails the
      // cast — as an uncaught TypeError and a Dart stack trace, where the
      // operator needs the same "your config file is wrong" sentence.
      if (decoded is! Map) {
        throw CliUsageError('config file must hold a JSON object, not a ${decoded.runtimeType}: ${file.path}');
      }
      json = decoded.cast<String, Object?>();
    } else if (path != null && mustExist) {
      // An explicitly named file that isn't there is a typo, not a fresh
      // start — silently defaulting would run the command with none of the
      // credentials the operator meant to pass.
      throw CliUsageError('no config file at $path');
    }

    return CliConfig(
      file: file,
      settings: {..._mapOf(json['settings']), ..._settingsFromEnv(env)},
      extensionSettings: _nestedMapOf(json['extensionSettings']),
      accounts: _nestedMapOf(json['accounts']),
      secrets: {
        for (final entry in _mapOf(json['secrets']).entries)
          if (entry.value != null) entry.key: '${entry.value}',
        ..._secretsFromEnv(env),
      },
      extensionOverrides: {
        for (final entry in _mapOf(json['extensions']).entries)
          if (entry.value is bool) entry.key: entry.value as bool,
      },
      environmentSecrets: _secretsFromEnv(env).keys.toSet(),
      environmentSettings: _settingsFromEnv(env).keys.toSet(),
    );
  }

  /// The `extensions` view `host.getSettings()` returns — the extension-owned
  /// groups, raw. Every extension may read every group (settings are not
  /// secrets); writes are namespaced, see [setExtensionSettings].
  Map<String, Map<String, Object?>> get settingsGroups => extensionSettings;

  /// Merges [values] into extension [ns]'s own group and persists.
  void setExtensionSettings(String ns, Map<String, Object?> values) {
    final group = extensionSettings.putIfAbsent('extension_$ns', () => {});
    group.addAll(values);
    save();
  }

  void setAccountSession(String kvKey, Map<String, Object?> session) {
    accounts.putIfAbsent(kvKey, () => {})['session'] = session;
    save();
  }

  Map<String, Object?> accountFor(String kvKey) => {
        'credentials': accounts[kvKey]?['credentials'] ?? const <String, Object?>{},
        'session': accounts[kvKey]?['session'] ?? const <String, Object?>{},
      };

  /// Writes the file back, 0600. Secrets supplied through the environment are
  /// deliberately NOT written: they belong to the invocation, and persisting
  /// them would quietly turn a one-off `HALO_SECRET_…` into a stored one.
  void save() {
    final target = file;
    if (target == null) return;
    final json = <String, Object?>{
      'settings': {
        for (final entry in settings.entries)
          if (defaultSettings[entry.key] != entry.value && !environmentSettings.contains(entry.key))
            entry.key: entry.value,
      },
      if (extensionSettings.isNotEmpty) 'extensionSettings': extensionSettings,
      if (accounts.isNotEmpty) 'accounts': accounts,
      'secrets': {
        for (final entry in secrets.entries)
          if (!environmentSecrets.contains(entry.key)) entry.key: entry.value,
      },
      if (extensionOverrides.isNotEmpty) 'extensions': extensionOverrides,
    }..removeWhere((_, value) => value is Map && value.isEmpty);

    target.parent.createSync(recursive: true);
    target.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(json)}\n');
    // Credentials live in here. The keychain the app uses is protected by the
    // OS; this file has only its mode.
    if (!Platform.isWindows) Process.runSync('chmod', ['600', target.path]);
  }

  static Map<String, Object?> _mapOf(Object? value) =>
      value is Map ? value.cast<String, Object?>() : const <String, Object?>{};

  static Map<String, Map<String, Object?>> _nestedMapOf(Object? value) => {
        for (final entry in _mapOf(value).entries)
          if (entry.value is Map) entry.key: (entry.value as Map).cast<String, Object?>(),
      };

  static Map<String, String> _secretsFromEnv(Map<String, String> env) => {
        for (final entry in env.entries)
          if (entry.key.startsWith('HALO_SECRET_') && entry.value.isNotEmpty)
            entry.key.substring('HALO_SECRET_'.length): entry.value,
      };

  /// `HALO_SETTING_developerMode=true` → `{developerMode: true}`. The value is
  /// parsed as JSON when it can be, so booleans, numbers and lists all work;
  /// anything else is taken as the plain string it is.
  static Map<String, Object?> _settingsFromEnv(Map<String, String> env) => {
        for (final entry in env.entries)
          if (entry.key.startsWith('HALO_SETTING_'))
            entry.key.substring('HALO_SETTING_'.length): _jsonOrString(entry.value),
      };

  static Object? _jsonOrString(String value) {
    try {
      return jsonDecode(value);
    } on FormatException {
      return value;
    }
  }
}

/// `$XDG_CACHE_HOME/ham2k/halo-cli` or `~/.cache/ham2k/halo-cli` — where the
/// downloaded reference data lives. Separate from the config: this is
/// regenerable, and deleting it costs a re-download, not a re-login.
String defaultCacheDir([Map<String, String>? environment]) {
  final env = environment ?? Platform.environment;
  final xdg = env['XDG_CACHE_HOME'];
  final base = (xdg != null && xdg.isNotEmpty) ? xdg : '${_home(env)}/.cache';
  return '$base/ham2k/halo-cli';
}

String _home(Map<String, String> env) => env['HOME'] ?? env['USERPROFILE'] ?? Directory.current.path;
