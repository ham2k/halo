// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:io';

/// The tokens the app handed this command, one per agent app, per edition:
/// a JSON object of client name → token, readable only by the user.
class TokenStore {
  final File file;

  TokenStore(this.file);

  /// The store for [edition] in the user's own config folder.
  factory TokenStore.forEdition(String edition, {Map<String, String>? environment}) {
    final env = environment ?? Platform.environment;
    final String base;
    if (Platform.isWindows) {
      base = '${env['APPDATA'] ?? env['USERPROFILE'] ?? '.'}\\Ham2K\\agent-link';
    } else if (Platform.isMacOS) {
      base = '${env['HOME'] ?? '.'}/Library/Application Support/Ham2K/agent-link';
    } else {
      final config = env['XDG_CONFIG_HOME'];
      base = '${config != null && config.isNotEmpty ? config : '${env['HOME'] ?? '.'}/.config'}/ham2k/agent-link';
    }
    return TokenStore(File('$base${Platform.pathSeparator}$edition.json'));
  }

  Map<String, String> _read() {
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.key is String && entry.value is String) entry.key as String: entry.value as String,
      };
    } on PathNotFoundException {
      return {};
    } on FormatException {
      // A store this command cannot read is one it starts over: the app asks
      // the operator again, which is the worst a lost token costs.
      return {};
    }
  }

  String? read(String client) => _read()[client];

  /// Keeps [token] for [client], written whole to a file beside the store and
  /// moved over it, so a crash mid-write never leaves half a store. The
  /// file is this run's own, so two runs writing at once each move a whole
  /// store rather than one's half over the other's.
  void write(String client, String token) {
    final tokens = {..._read(), client: token};
    file.parent.createSync(recursive: true);
    final temporary = File('${file.path}.$pid.tmp');
    temporary.createSync();
    if (!Platform.isWindows) {
      // While it is still empty: the umask's mode would let other users
      // read the tokens between the write and a chmod after it.
      for (final (mode, path) in [('700', file.parent.path), ('600', temporary.path)]) {
        final result = Process.runSync('chmod', [mode, path]);
        // Written anyway, the tokens would be readable by other users.
        if (result.exitCode != 0) {
          temporary.deleteSync();
          throw FileSystemException('could not make it private: ${result.stderr}'.trim(), path);
        }
      }
    }
    temporary.writeAsStringSync(jsonEncode(tokens), flush: true);
    temporary.renameSync(file.path);
  }
}
