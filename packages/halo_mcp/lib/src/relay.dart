// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The command's whole job (docs/design/agent-link.md): take MCP's stdio
// transport from the agent app, say hello to the running app with the
// token it keeps for that agent app, and relay every line both ways. It answers
// nothing itself except when it cannot reach the app at all, and then only
// the agent's `initialize`, in words the agent can pass on to the operator.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'link.dart';
import 'token_store.dart';

/// One connection to the app's agent link, as lines.
abstract interface class LinkConnection {
  Stream<String> get lines;
  void send(String line);
  Future<void> close();
}

/// Connects to the app on loopback [port]. A read error ends the lines,
/// told to [log].
Future<LinkConnection> connectLink(int port, {void Function(String message)? log}) async =>
    _SocketLink(await Socket.connect(InternetAddress.loopbackIPv4, port), log);

class _SocketLink implements LinkConnection {
  final Socket _socket;
  final void Function(String message)? _log;

  _SocketLink(this._socket, this._log);

  @override
  late final Stream<String> lines = _socket
      .cast<List<int>>()
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .handleError((Object e) => _log?.call('the connection to the app failed: $e'));

  @override
  void send(String line) => _socket.add(utf8.encode('$line\n'));

  @override
  Future<void> close() async {
    try {
      await _socket.flush();
    } catch (_) {
      // Gone already: nothing to flush to.
    }
    _socket.destroy();
  }
}

/// What to tell the agent when the app turned it away, by the app's reason.
String refusalText(String? reason, String client) => switch (reason) {
  'denied' => 'The operator did not allow $client to use Ham2K Logger.',
  'unavailable' => 'Ham2K Logger is not ready for agent apps yet. Try again in a moment.',
  _ => 'This halo-mcp does not match the Ham2K Logger that is running.',
};

const notRunningText = 'Ham2K Logger is not running, or does not let agent apps connect. Start it, then try again.';

/// Something answered on the app's port, then hung up or said something
/// that is not the app's answer: the app crashing mid-question, or another
/// program holding the port.
const noAnswerText =
    'Ham2K Logger hung up before answering, or another program holds its port. Try again; if it keeps happening, check Connected Apps in its settings.';

/// Relays [input] (the agent's stdin, as lines) to the app and the app's
/// lines to [output] (stdout). Returns the exit code: 0 once either side
/// ends after a connection, 1 when the app could not be reached or turned
/// the agent away.
Future<int> relay({
  required Stream<String> input,
  required void Function(String line) output,
  required Future<LinkConnection> Function() connect,
  required TokenStore tokens,
  String? launcher,
  void Function(String message)? log,
}) async {
  final pending = <String>[];
  final first = Completer<String?>();
  final inputDone = Completer<void>();
  LinkConnection? link;
  var relaying = false;

  final subscription = input.listen(
    (line) {
      if (line.trim().isEmpty) return;
      if (relaying) {
        link!.send(line);
      } else {
        pending.add(line);
        if (!first.isCompleted) first.complete(line);
      }
    },
    onDone: () {
      if (!first.isCompleted) first.complete(null);
      if (!inputDone.isCompleted) inputDone.complete();
    },
  );

  final firstLine = await first.future;
  if (firstLine == null) {
    await subscription.cancel();
    return 0;
  }

  // MCP's first message is `initialize`, naming the agent app: the app asks
  // the operator about it by that name, and its token is kept under it.
  Object? id;
  var name = 'unknown';
  String? version;
  try {
    final message = jsonDecode(firstLine);
    if (message is Map) {
      id = message['id'];
      final params = message['params'];
      final info = params is Map ? params['clientInfo'] : null;
      if (info is Map) {
        if (info['name'] is String && (info['name'] as String).trim().isNotEmpty) name = (info['name'] as String).trim();
        if (info['version'] is String) version = info['version'] as String;
      }
    }
  } on FormatException {
    // Not JSON: relayed all the same, for the app's endpoint to answer.
  }

  void fail(String text) {
    log?.call(text);
    if (id != null) {
      output(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': id,
          'error': {'code': -32000, 'message': text},
        }),
      );
    }
  }

  try {
    link = await connect();
  } catch (e) {
    log?.call('could not reach the app: $e');
    fail(notRunningText);
    await subscription.cancel();
    return 1;
  }

  final fromApp = StreamIterator(link.lines);
  link.send(
    jsonEncode({
      'agentLink': kAgentLinkVersion,
      'client': {'name': name, 'version': ?version, 'launcher': ?launcher},
      'token': _tokenFor(tokens, name, log),
    }),
  );

  // The operator may be reading the question: no timeout here. The agent app
  // gives up on its own; the question stays up in the app, and the operator's
  // answer still holds for the token this run presented.
  // An agent app that closes stdin has left: waiting on would leave this
  // command behind it, holding the question as if the app still waited.
  final answered = await Future.any([fromApp.moveNext(), inputDone.future.then((_) => null)]);
  if (answered == null) {
    await fromApp.cancel();
    await link.close();
    await subscription.cancel();
    return 0;
  }
  Map<dynamic, dynamic>? answer;
  if (answered) {
    try {
      final decoded = jsonDecode(fromApp.current);
      if (decoded is Map) answer = decoded;
    } on FormatException {
      answer = null;
    }
  }
  if (answer == null || answer['ok'] != true) {
    fail(answer == null ? noAnswerText : refusalText(answer['reason'] as String?, name));
    await fromApp.cancel();
    await link.close();
    await subscription.cancel();
    return 1;
  }

  relaying = true;
  for (final line in pending) {
    link.send(line);
  }
  pending.clear();
  unawaited(inputDone.future.then((_) => link?.close()));

  while (await fromApp.moveNext()) {
    output(fromApp.current);
  }
  // The operator removed this app, the app quit, or a line was too long for
  // it; the agent app's log is where its user looks.
  if (!inputDone.isCompleted) log?.call('Ham2K Logger closed the connection');
  await subscription.cancel();
  return 0;
}

/// The token kept for [client], minted and kept first when there is none:
/// kept before the app is asked, so an allow given after this run has gone
/// lets the next run in.
String _tokenFor(TokenStore tokens, String client, void Function(String message)? log) {
  String? kept;
  try {
    kept = tokens.read(client);
  } catch (e) {
    log?.call('could not read the kept tokens: $e');
  }
  if (kept != null && kept.length >= kAgentLinkMinToken) return kept;
  final token = mintAgentLinkToken();
  try {
    tokens.write(client, token);
  } catch (e) {
    // Asked all the same; an allow then holds only for this run's token, and
    // the next run is asked again.
    log?.call('could not keep the token: $e');
  }
  return token;
}

/// The name of the program that started this command, where the system
/// says: the app bundle's name on macOS (`Claude`), the executable's
/// elsewhere. Null when it cannot tell.
Future<String?> launcherName() async {
  if (Platform.isWindows) return null;
  try {
    final parent = (await Process.run('ps', ['-o', 'ppid=', '-p', '$pid'])).stdout.toString().trim();
    if (parent.isEmpty) return null;
    final command = (await Process.run('ps', ['-o', 'comm=', '-p', parent])).stdout.toString().trim();
    if (command.isEmpty) return null;
    final bundle = RegExp(r'([^/]+)\.app/').firstMatch(command);
    if (bundle != null) return bundle.group(1);
    return command.split('/').last;
  } catch (_) {
    return null;
  }
}
