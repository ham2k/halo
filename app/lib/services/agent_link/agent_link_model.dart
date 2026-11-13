// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the agent link's frames and grants hold (docs/design/agent-link.md).
// No sockets and no Flutter here: the service and its tests share it.

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:halo_build_tools/halo_build_tools.dart' show Edition;
import 'package:halo_mcp/halo_mcp.dart';

export 'package:halo_mcp/halo_mcp.dart' show kAgentLinkMaxFrame, kAgentLinkMinToken, kAgentLinkVersion, mintAgentLinkToken;

/// The command's own table and version, so the two ends cannot drift.
int agentLinkPort(Edition edition) => agentLinkPortFor(edition.name)!;

/// What the operator let an app do.
enum AgentAccess {
  /// Reads, and nothing else.
  watch,

  /// Everything an assistant may do.
  change;

  static AgentAccess? parse(Object? value) => switch (value) {
    'watch' => watch,
    'change' => change,
    _ => null,
  };
}

/// The app that asked, as the command's hello names it: what its MCP
/// `initialize` said of itself, and the process that started the command.
/// All of it is the app's own word, shown to the operator as such.
class AgentClient {
  final String name;
  final String? version;
  final String? launcher;

  const AgentClient({required this.name, this.version, this.launcher});

  Map<String, dynamic> toJson() => {'name': name, 'version': ?version, 'launcher': ?launcher};
}

/// The command's first line, or null for anything else: an HTTP request a
/// web page made a browser send, a line that is not JSON, another version.
/// The token is null when the hello carries none long enough to be the
/// command's own.
({AgentClient client, String? token})? parseAgentHello(String line) {
  final Object? decoded;
  try {
    decoded = jsonDecode(line);
  } on FormatException {
    return null;
  }
  if (decoded is! Map || decoded['agentLink'] != kAgentLinkVersion) return null;
  final client = decoded['client'];
  if (client is! Map) return null;
  final name = _short(client['name']);
  if (name == null) return null;
  final token = decoded['token'];
  return (
    client: AgentClient(name: name, version: _short(client['version']), launcher: _short(client['launcher'])),
    token: token is String && token.length >= kAgentLinkMinToken ? token : null,
  );
}

/// Whether [line] is a hello at all, of whatever version: a JSON object
/// with an `agentLink` key, which no web page can make a browser send.
bool isAgentHelloOfAnyVersion(String line) {
  try {
    final decoded = jsonDecode(line);
    return decoded is Map && decoded.containsKey('agentLink');
  } on FormatException {
    return false;
  }
}

/// A name the operator reads in a dialog: trimmed, and cut at 80 characters
/// so an app cannot fill the dialog with its own text.
String? _short(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return trimmed.length <= 80 ? trimmed : trimmed.substring(0, 80);
}

/// What a grant keeps of the command's token: never the token itself, so the
/// app's settings hold nothing a reader could connect with.
String agentTokenHash(String token) => sha256.convert(utf8.encode(token)).toString();

/// One app the operator allowed.
class AgentGrant {
  final String id;
  final AgentClient client;
  final AgentAccess access;
  final String tokenHash;
  final int grantedAt;
  final int? lastSeenAt;

  const AgentGrant({required this.id, required this.client, required this.access, required this.tokenHash, required this.grantedAt, this.lastSeenAt});

  AgentGrant copyWith({AgentAccess? access, int? lastSeenAt}) =>
      AgentGrant(id: id, client: client, access: access ?? this.access, tokenHash: tokenHash, grantedAt: grantedAt, lastSeenAt: lastSeenAt ?? this.lastSeenAt);

  Map<String, dynamic> toJson() => {
    'client': client.toJson(),
    'access': access.name,
    'tokenHash': tokenHash,
    'grantedAt': grantedAt,
    'lastSeenAt': ?lastSeenAt,
  };

  /// Null for an entry this build cannot read: it is left out rather than
  /// guessed at, and the app it was for is asked again.
  static AgentGrant? fromJson(String id, Object? json) {
    if (json is! Map) return null;
    final client = json['client'];
    final name = client is Map ? _short(client['name']) : null;
    final access = AgentAccess.parse(json['access']);
    final hash = json['tokenHash'];
    final grantedAt = json['grantedAt'];
    if (name == null || access == null || hash is! String || grantedAt is! int) return null;
    final lastSeenAt = json['lastSeenAt'];
    return AgentGrant(
      id: id,
      client: AgentClient(name: name, version: _short((client as Map)['version']), launcher: _short(client['launcher'])),
      access: access,
      tokenHash: hash,
      grantedAt: grantedAt,
      lastSeenAt: lastSeenAt is int ? lastSeenAt : null,
    );
  }
}
