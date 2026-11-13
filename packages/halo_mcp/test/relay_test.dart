// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:halo_mcp/halo_mcp.dart';
import 'package:test/test.dart';

class _FakeLink implements LinkConnection {
  final fromApp = StreamController<String>();
  final sent = <String>[];
  final sentOne = StreamController<String>.broadcast();
  bool closed = false;

  @override
  Stream<String> get lines => fromApp.stream;

  @override
  void send(String line) {
    sent.add(line);
    sentOne.add(line);
  }

  @override
  Future<void> close() async {
    closed = true;
    if (!fromApp.isClosed) await fromApp.close();
  }
}

String _initialize(int id, {String name = 'claude-code'}) => jsonEncode({
  'jsonrpc': '2.0',
  'id': id,
  'method': 'initialize',
  'params': {
    'protocolVersion': '2025-06-18',
    'clientInfo': {'name': name, 'version': '2.1.0'},
  },
});

void main() {
  late Directory dir;
  late TokenStore tokens;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('halo_mcp_test');
    tokens = TokenStore(File('${dir.path}/dev.json'));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  // The order matters: nothing the agent sent may reach the app before the
  // app has said yes, and nothing may be lost while the operator decides.
  test('says hello as the agent app names itself, with a token it kept, then relays in order', () async {
    final link = _FakeLink();
    final input = StreamController<String>();
    final output = <String>[];
    final done = relay(input: input.stream, output: output.add, connect: () async => link, tokens: tokens, launcher: 'Claude');
    input.add(_initialize(1));
    final hello = jsonDecode(await link.sentOne.stream.first) as Map;
    expect(hello['client'], {'name': 'claude-code', 'version': '2.1.0', 'launcher': 'Claude'});
    // Kept before the app answers: an agent app that gives up while the
    // operator reads the question is let in by that answer on its next run.
    expect(hello['token'], tokens.read('claude-code'));
    expect((hello['token'] as String).length, greaterThanOrEqualTo(kAgentLinkMinToken));
    input.add('{"jsonrpc":"2.0","method":"notifications/initialized"}');
    await pumpEventQueue();
    expect(link.sent, hasLength(1), reason: 'nothing is relayed before the app answers');
    link.fromApp.add(jsonEncode({'agentLink': 1, 'ok': true, 'access': 'watch'}));
    await pumpEventQueue();
    expect(link.sent.skip(1).map((l) => (jsonDecode(l) as Map)['method']), ['initialize', 'notifications/initialized']);
    link.fromApp.add('{"jsonrpc":"2.0","id":1,"result":{}}');
    await pumpEventQueue();
    expect(output, ['{"jsonrpc":"2.0","id":1,"result":{}}']);
    await input.close();
    await link.fromApp.close();
    expect(await done, 0);
  });

  test('a later run presents the kept token, so the operator is not asked again', () async {
    final kept = mintAgentLinkToken();
    tokens.write('claude-code', kept);
    final link = _FakeLink();
    final input = StreamController<String>();
    unawaited(relay(input: input.stream, output: (_) {}, connect: () async => link, tokens: tokens));
    input.add(_initialize(1));
    final hello = jsonDecode(await link.sentOne.stream.first) as Map;
    expect(hello['token'], kept);
    await input.close();
    await link.close();
  });

  // The agent shows its user the error on `initialize`; without one it
  // waits on an answer that never comes, and the operator never learns why.
  test('a refusal answers the initialize with why, relays nothing, and exits 1', () async {
    final link = _FakeLink();
    final input = StreamController<String>();
    final output = <String>[];
    final done = relay(input: input.stream, output: output.add, connect: () async => link, tokens: tokens);
    input.add(_initialize(7, name: 'gemini-cli'));
    await link.sentOne.stream.first;
    link.fromApp.add(jsonEncode({'agentLink': 1, 'ok': false, 'reason': 'denied'}));
    expect(await done, 1);
    expect(link.sent, hasLength(1));
    final error = jsonDecode(output.single) as Map;
    expect(error['id'], 7);
    expect((error['error'] as Map)['message'], refusalText('denied', 'gemini-cli'));
    await input.close();
  });

  test('an app that is not running answers the initialize so', () async {
    final input = StreamController<String>();
    final output = <String>[];
    final done = relay(input: input.stream, output: output.add, connect: () async => throw const SocketException('refused'), tokens: tokens);
    input.add(_initialize(3));
    expect(await done, 1);
    expect(((jsonDecode(output.single) as Map)['error'] as Map)['message'], notRunningText);
    await input.close();
  });

  // An agent app that crashes closes the command's stdin. Without this, the
  // command would wait on the operator's answer with nobody behind it.
  test('an agent app that closes its input while the operator is asked ends the command', () async {
    final link = _FakeLink();
    final input = StreamController<String>();
    final done = relay(input: input.stream, output: (_) {}, connect: () async => link, tokens: tokens);
    input.add(_initialize(1));
    await link.sentOne.stream.first;
    await input.close();
    expect(await done.timeout(const Duration(seconds: 5)), 0);
    expect(link.closed, isTrue);
  });

  // Reached, then hung up on: "start the app" would send the operator to
  // start an app that is already running.
  test('an app that hangs up without answering is not reported as not running', () async {
    final link = _FakeLink();
    final input = StreamController<String>();
    final output = <String>[];
    final done = relay(input: input.stream, output: output.add, connect: () async => link, tokens: tokens);
    input.add(_initialize(5));
    await link.sentOne.stream.first;
    await link.fromApp.close();
    expect(await done, 1);
    expect(((jsonDecode(output.single) as Map)['error'] as Map)['message'], noAnswerText);
    await input.close();
  });

  test('the token store is readable only by the user', () {
    tokens.write('codex', 'secret-2');
    if (Platform.isWindows) return;
    final mode = tokens.file.statSync().mode & 0x1FF;
    expect(mode, 0x180, reason: 'rw------- (600)');
  });
}
