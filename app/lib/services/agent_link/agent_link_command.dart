// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// How an agent app runs halo-mcp to reach THIS install
// (docs/design/agent-link.md § The command): what Connected Apps tells the
// operator to paste into their agent app.

import 'dart:convert';

import 'package:halo_build_tools/halo_build_tools.dart' show Edition;
import 'package:path/path.dart' as p;

/// The command line an agent app is configured with: [command] and its
/// [args], ready for an `mcpServers` entry or a shell.
class AgentLinkCommand {
  final String command;
  final List<String> args;

  /// The name the agent app lists the server under: one per edition, so a
  /// Next and a Regular install can both be configured in one agent app.
  final String serverName;

  /// Whether the shell the operator pastes into is Windows', which quotes
  /// differently.
  final bool windows;

  /// Whether [command] is somewhere it will not stay: an app run from its
  /// disk image (a bundle at the root of a mounted volume), or one macOS
  /// moved to a random folder because it was opened where it was
  /// downloaded. Pasted into an agent app, the path stops working once the
  /// app quits or the image is ejected. An app installed on another drive,
  /// in a folder there, is not temporary.
  final bool temporary;

  const AgentLinkCommand({required this.command, required this.args, required this.serverName, required this.windows, this.temporary = false});

  /// The one line that adds the server to Claude Code for every project.
  String get claudeCodeLine => ['claude', 'mcp', 'add', '--scope', 'user', serverName, '--', command, ...args].map(_quote).join(' ');

  /// The `mcpServers` entry most agent apps read (Claude Desktop, Cursor,
  /// Gemini CLI), as a whole JSON object to merge into their config.
  String get mcpServersJson => const JsonEncoder.withIndent('  ').convert({
    'mcpServers': {
      serverName: {'command': command, 'args': args},
    },
  });

  /// [command] alone as a shell would need it typed.
  String get commandLine => [command, ...args].map(_quote).join(' ');

  String _quote(String word) {
    if (word.isNotEmpty && RegExp(r'^[A-Za-z0-9_./:=@%+-]+$').hasMatch(word)) return word;
    // PowerShell and cmd both take a double-quoted word; a path holds no `"`.
    if (windows) return '"$word"';
    return "'${word.replaceAll("'", r"'\''")}'";
  }
}

/// The architecture [platformVersion] (`Platform.version`) says the Dart VM
/// runs on: `arm64` from `… on "macos_arm64"`.
String? dartArch(String platformVersion) => RegExp(r'on "[a-z]+_([a-z0-9]+)"').firstMatch(platformVersion)?.group(1);

/// The command for this install, or null when this build carries none.
///
/// In the order checked: an AppImage runs its bundled halo-mcp through its
/// own `mcp` subcommand, since its files have a path only while it runs; an
/// installed build carries `halo-mcp` beside the app's executable, or, where
/// the app is universal (macOS), one `halo-mcp-<arch>` per architecture,
/// since a Dart executable cannot be made universal; a development build
/// runs the package's source with `dart run`.
///
/// [executable] is `Platform.resolvedExecutable`, [environment]
/// `Platform.environment`, [arch] this process's architecture as Dart names
/// it (`arm64`, `x64`); [exists] says whether a file is there.
AgentLinkCommand? agentLinkCommand({
  required Edition edition,
  required String executable,
  required Map<String, String> environment,
  required bool windows,
  String? arch,
  required bool Function(String path) exists,
}) {
  final context = windows ? p.windows : p.posix;
  // Regular is halo-mcp's default; the others name theirs, or the command
  // would knock on Regular's port.
  final editionArgs = edition == Edition.prod ? const <String>[] : ['--edition', edition.name];
  final serverName = edition == Edition.prod ? 'ham2k-logger' : 'ham2k-logger-${edition.name}';
  AgentLinkCommand make(String command, List<String> args, {bool temporary = false}) =>
      AgentLinkCommand(command: command, args: args, serverName: serverName, windows: windows, temporary: temporary);

  // An AppImage hands APPIMAGE and APPDIR down to everything it starts, so
  // either alone may be another AppImage's: only an executable inside the
  // mount APPDIR names is running from the AppImage APPIMAGE names.
  final appImage = environment['APPIMAGE'];
  final appDir = environment['APPDIR'];
  if (appImage != null && appImage.isNotEmpty && appDir != null && appDir.isNotEmpty && context.isWithin(appDir, executable)) {
    return make(appImage, ['mcp', ...editionArgs]);
  }

  final dir = context.dirname(executable);
  final temporary = !windows && (dir.contains('/AppTranslocation/') || RegExp(r'^/Volumes/[^/]+/[^/]+\.app/').hasMatch(dir));
  for (final name in [windows ? 'halo-mcp.exe' : 'halo-mcp', if (arch != null) 'halo-mcp-$arch']) {
    final bundled = context.join(dir, name);
    if (exists(bundled)) return make(bundled, editionArgs, temporary: temporary);
  }

  // A `flutter run` build sits deep under the checkout's app/build; the
  // package's source is a few levels up from it.
  for (var at = dir; context.dirname(at) != at; at = context.dirname(at)) {
    final source = context.join(at, 'packages', 'halo_mcp', 'bin', 'halo_mcp.dart');
    if (exists(source)) return make('dart', ['run', source, ...editionArgs]);
  }
  return null;
}
