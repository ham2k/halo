// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// halo-mcp [--edition prod|next|dev] [--port N]
//
// The command an agent app runs to reach Ham2K Logger over MCP
// (docs/design/agent-link.md). Stdout carries MCP and nothing else; what the
// command has to say for itself goes to stderr, where agent apps log it.

import 'dart:convert';
import 'dart:io';

import 'package:halo_mcp/halo_mcp.dart';

Future<void> main(List<String> args) async {
  var edition = 'prod';
  int? port;
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    String? value() => i + 1 < args.length ? args[++i] : null;
    if (arg == '--edition') {
      edition = value() ?? edition;
    } else if (arg.startsWith('--edition=')) {
      edition = arg.substring('--edition='.length);
    } else if (arg == '--port') {
      port = int.tryParse(value() ?? '');
    } else if (arg.startsWith('--port=')) {
      port = int.tryParse(arg.substring('--port='.length));
    } else {
      stderr.writeln('halo-mcp: unknown argument "$arg"\nusage: halo-mcp [--edition ${kAgentLinkEditions.join('|')}] [--port N]');
      exit(64);
    }
  }
  final resolvedPort = port ?? agentLinkPortFor(edition);
  if (resolvedPort == null) {
    stderr.writeln('halo-mcp: unknown edition "$edition" (one of ${kAgentLinkEditions.join(', ')})');
    exit(64);
  }
  final code = await relay(
    input: stdin.transform(utf8.decoder).transform(const LineSplitter()),
    output: stdout.writeln,
    connect: () => connectLink(resolvedPort, log: (message) => stderr.writeln('halo-mcp: $message')),
    tokens: TokenStore.forEdition(edition),
    launcher: await launcherName(),
    log: (message) => stderr.writeln('halo-mcp: $message'),
  );
  await stdout.flush();
  exit(code);
}
