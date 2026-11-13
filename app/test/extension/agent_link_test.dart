// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The agent link over real loopback sockets (docs/design/agent-link.md): who
// gets in, what the operator is asked, and what each connection may do.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/agent_link/agent_link_model.dart';
import 'package:ham2k_logger/services/agent_link/agent_link_service.dart';

class _MemoryStore implements AgentGrantStore {
  Map<String, dynamic> grants = {};
  bool failWrites = false;

  @override
  Map<String, dynamic> read() => grants;

  @override
  Future<void> write(Map<String, dynamic> grants) async {
    if (failWrites) throw const FileSystemException('disk full');
    this.grants = {...grants};
  }
}

class _Endpoint implements AgentLinkEndpoint {
  @override
  bool available = true;
  final received = <({AgentAccess access, Map<String, dynamic> message})>[];
  Object? failWith;

  /// What a test answers instead of the access, by message.
  Map<String, dynamic>? Function(Map<String, dynamic> message)? resultFor;

  final pulse = ValueNotifier(0);

  @override
  Listenable get news => pulse;

  @override
  Future<List<Map<String, dynamic>>> handle({
    required String connection,
    required AgentClient client,
    required AgentAccess access,
    required Map<String, dynamic> message,
  }) async {
    received.add((access: access, message: message));
    if (failWith != null) throw failWith!;
    final id = message['id'];
    if (id == null) return const [];
    return [
      {
        'jsonrpc': '2.0',
        'id': id,
        'result': resultFor?.call(message) ?? {'access': access.name},
      },
    ];
  }
}

/// A result asking the link to hold it, as the `mcp` extension's
/// `wait_for_events` answers while nothing has happened.
Map<String, dynamic> _held(int seconds, Map<String, dynamic> arguments) => {
  'structuredContent': {'events': 0},
  '_meta': {
    kAgentHoldMetaKey: {'seconds': seconds, 'arguments': arguments},
  },
};

/// The command's side of one connection.
class _Command {
  final Socket socket;
  final StreamIterator<String> _lines;

  /// The token this command keeps: minted per command unless a test hands
  /// one over, as a later run of the same agent app would present it.
  String token = mintAgentLinkToken();

  _Command(this.socket) : _lines = StreamIterator(socket.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()));

  static Future<_Command> connect(int port) async => _Command(await Socket.connect(InternetAddress.loopbackIPv4, port));

  void send(Object frame) => socket.write('${frame is String ? frame : jsonEncode(frame)}\n');

  void hello(String name, {String? token}) => send({
    'agentLink': 1,
    'client': {'name': name, 'launcher': 'Tester'},
    'token': token ?? this.token,
  });

  /// The next frame, or null once the app hung up.
  Future<Map<String, dynamic>?> next() async {
    if (!await _lines.moveNext().timeout(const Duration(seconds: 5))) return null;
    return (jsonDecode(_lines.current) as Map).cast<String, dynamic>();
  }

  Future<void> close() async {
    await _lines.cancel();
    socket.destroy();
  }
}

void main() {
  late _MemoryStore store;
  late _Endpoint endpoint;
  late AgentLinkService link;
  late int port;

  var wanted = true;
  final experiment = ChangeNotifier();

  Future<void> start() async {
    wanted = true;
    link = AgentLinkService(store: store, endpoint: endpoint, wanted: () => wanted, changes: experiment, port: 0, now: () => 1000);
    addTearDown(link.closeForExit);
    for (var i = 0; i < 100 && link.port == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    port = link.port!;
  }

  Future<_Command> command() async {
    final c = await _Command.connect(port);
    addTearDown(c.close);
    return c;
  }

  Future<AgentLinkRequest> asked() async {
    for (var i = 0; i < 200 && link.pendingRequest == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return link.pendingRequest!;
  }

  setUp(() {
    store = _MemoryStore();
    endpoint = _Endpoint();
  });

  // A web page can make a browser send HTTP to a loopback port. Anything the
  // app wrote back would be the page's to read, so the answer is a hang-up.
  test('a connection that does not open with a hello is hung up on, unanswered', () async {
    await start();
    final c = await command();
    c.send('GET / HTTP/1.1');
    expect(await c.next(), isNull);
    expect(link.pendingRequest, isNull);
  });

  test('a new app is asked about by name, and the access the operator picks is the one it gets', () async {
    await start();
    final c = await command();
    c.hello('claude-code');
    final request = await asked();
    expect(request.client.name, 'claude-code');
    expect(request.client.launcher, 'Tester');
    unawaited(link.answer(request, AgentAccess.watch));
    final answer = (await c.next())!;
    expect(answer, {'agentLink': 1, 'ok': true, 'access': 'watch'});
    // The token itself is never kept: what the settings hold could not be
    // used to connect.
    final stored = jsonEncode(store.grants);
    expect(stored, isNot(contains(c.token)));
    expect(stored, contains(agentTokenHash(c.token)));
    c.send({'jsonrpc': '2.0', 'id': 1, 'method': 'tools/list'});
    expect((await c.next())!['result'], {'access': 'watch'});
    expect(endpoint.received.single.access, AgentAccess.watch);
  });

  test('an app presenting its token is let in without asking', () async {
    await start();
    final first = await command();
    first.hello('claude-code');
    unawaited(link.answer(await asked(), AgentAccess.change));
    await first.next();
    await first.close();

    final again = await command();
    again.hello('claude-code', token: first.token);
    expect(await again.next(), {'agentLink': 1, 'ok': true, 'access': 'change'});
    expect(link.pendingRequest, isNull);
  });

  // The name is the app's own word: a second app calling itself claude-code
  // with a token of its own is a new app, and the operator is asked.
  test('a token that is not one of the grants\' is asked about, whatever the name', () async {
    await start();
    final first = await command();
    first.hello('claude-code');
    unawaited(link.answer(await asked(), AgentAccess.change));
    await first.next();

    final other = await command();
    other.hello('claude-code');
    expect((await asked()).client.name, 'claude-code');
  });

  // A short token is one another program could guess its way into.
  test('a hello without a token of the command\'s own length is refused, and nobody is asked', () async {
    await start();
    final c = await command();
    c.hello('claude-code', token: 'x' * (kAgentLinkMinToken - 1));
    expect((await c.next())!['reason'], 'protocol');
    expect(link.pendingRequest, isNull);
  });

  // A halo-mcp left on an agent app's path from another release: told that
  // it does not match, where a hang-up reads as the app not running.
  test('a hello of another version is answered protocol', () async {
    await start();
    final c = await command();
    c.send({
      'agentLink': kAgentLinkVersion + 1,
      'client': {'name': 'claude-code'},
      'token': c.token,
    });
    expect((await c.next())!['reason'], 'protocol');
  });

  test('a refusal is answered denied, and keeps nothing', () async {
    await start();
    final c = await command();
    c.hello('gemini-cli');
    unawaited(link.answer(await asked(), null));
    expect(await c.next(), {'agentLink': 1, 'ok': false, 'reason': 'denied'});
    expect(store.grants, isEmpty);
  });

  // Agent apps give up on a server that takes long to start, often before
  // the operator has read the question. Were the question to go with the
  // app, the operator could never answer it in time.
  test('a question outlives the app that stopped waiting, and its answer lets the app in next time', () async {
    await start();
    final c = await command();
    c.hello('codex');
    final request = await asked();
    expect(request.waiting.value, isTrue);
    await c.close();
    for (var i = 0; i < 100 && request.waiting.value; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(request.waiting.value, isFalse);
    expect(link.pendingRequest, same(request));

    await link.answer(request, AgentAccess.watch);
    final again = await command();
    again.hello('codex', token: c.token);
    expect(await again.next(), {'agentLink': 1, 'ok': true, 'access': 'watch'});
  });

  test('an app that connects again while asked waits on the same question', () async {
    await start();
    final first = await command();
    first.hello('codex');
    final request = await asked();
    final second = await command();
    second.hello('codex', token: first.token);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(link.pendingRequest, same(request));
    unawaited(link.answer(request, AgentAccess.change));
    expect((await first.next())!['access'], 'change');
    expect((await second.next())!['access'], 'change');
    expect(link.grants, hasLength(1));
  });

  // The operator turning the experiment off, or quitting, is not the
  // operator refusing: the agent app would tell its user "not allowed".
  test('a link that stops while the operator is asked tells the app unavailable, not denied', () async {
    await start();
    final c = await command();
    c.hello('codex');
    await asked();
    wanted = false;
    experiment.notifyListeners();
    expect((await c.next())?['reason'], 'unavailable');
  });

  test('an access changed in Settings applies from the next message', () async {
    await start();
    final c = await command();
    c.hello('claude-code');
    unawaited(link.answer(await asked(), AgentAccess.change));
    await c.next();
    await link.setAccess(link.grants.single.id, AgentAccess.watch);
    c.send({'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list'});
    expect((await c.next())!['result'], {'access': 'watch'});
  });

  // Removing an app is how the operator cuts it off: it is hung up on now,
  // and its token is worth nothing after.
  test('removing an app hangs it up and makes its token ask again', () async {
    await start();
    final c = await command();
    c.hello('claude-code');
    unawaited(link.answer(await asked(), AgentAccess.change));
    await c.next();
    await link.setAccess(link.grants.single.id, null);
    expect(await c.next(), isNull);
    expect(link.grants, isEmpty);

    final again = await command();
    again.hello('claude-code', token: c.token);
    expect((await asked()).client.name, 'claude-code');
  });

  test('while the endpoint is not running, an app is answered unavailable and nobody is asked', () async {
    endpoint.available = false;
    await start();
    final c = await command();
    c.hello('claude-code');
    expect((await c.next())!['reason'], 'unavailable');
    expect(link.pendingRequest, isNull);
  });

  // An unanswered request holds the agent until its own timeout, with
  // nothing said about why.
  // Without this the app waits on an answer that never comes, and the
  // operator, having clicked Allow, sees no app in Settings.
  test('an allow that cannot be kept tells the waiting app to try again', () async {
    await start();
    final c = await command();
    c.hello('claude-code');
    final request = await asked();
    store.failWrites = true;
    await link.answer(request, AgentAccess.watch);
    expect((await c.next())!['reason'], 'unavailable');
    expect(link.pendingRequest, isNull);
  });

  // Bookkeeping must not cost an allowed app its connection: halo-mcp would
  // tell the agent that the app is not running.
  test('an allowed app gets in even when its last-seen time cannot be kept', () async {
    await start();
    final first = await command();
    first.hello('claude-code');
    unawaited(link.answer(await asked(), AgentAccess.watch));
    await first.next();
    store.failWrites = true;
    final again = await command();
    again.hello('claude-code', token: first.token);
    expect((await again.next())!['ok'], isTrue);
  });

  test('an app whose endpoint stopped under it is hung up on, to be told unavailable when it connects again', () async {
    await start();
    final c = await command();
    c.hello('claude-code');
    unawaited(link.answer(await asked(), AgentAccess.change));
    await c.next();
    endpoint.available = false;
    c.send({'jsonrpc': '2.0', 'id': 4, 'method': 'tools/list'});
    expect(await c.next(), isNull);
    expect(endpoint.received, isEmpty);
  });

  // An unanswered line holds a client that waits on it until its timeout.
  test('a line that is not JSON, and a batch, are answered with JSON-RPC errors', () async {
    await start();
    final c = await command();
    c.hello('claude-code');
    unawaited(link.answer(await asked(), AgentAccess.change));
    await c.next();
    c.send('not json');
    expect(((await c.next())!['error'] as Map)['code'], -32700);
    c.send([
      {'jsonrpc': '2.0', 'id': 1, 'method': 'ping'},
    ]);
    expect(((await c.next())!['error'] as Map)['code'], -32600);
  });

  test('a request the endpoint fails on is still answered, with an error for its id', () async {
    await start();
    final c = await command();
    c.hello('claude-code');
    unawaited(link.answer(await asked(), AgentAccess.change));
    await c.next();
    endpoint.failWith = StateError('runtime restarting');
    c.send({'jsonrpc': '2.0', 'id': 9, 'method': 'tools/call'});
    final reply = (await c.next())!;
    expect(reply['id'], 9);
    expect((reply['error'] as Map)['code'], -32603);
  });

  // Held in the endpoint's own hook call instead, the wait would keep the
  // extension engine pumping its jobs every few milliseconds for as long as
  // an agent loops on it.
  group('a reply the endpoint asks to hold', () {
    Future<_Command> connected() async {
      await start();
      final c = await command();
      c.hello('claude-code');
      unawaited(link.answer(await asked(), AgentAccess.watch));
      await c.next();
      return c;
    }

    Map<String, dynamic> argumentsOf(Map<String, dynamic> message) => ((message['params'] as Map)['arguments'] as Map).cast<String, dynamic>();

    test('waits while other requests are answered, and is asked again, with the arguments it named, when the endpoint has news', () async {
      final c = await connected();
      var news = false;
      endpoint.resultFor = (message) => message['id'] != 5
          ? null
          : news
          ? {
              'structuredContent': {'events': 1},
            }
          : _held(20, {'after': 7});
      c.send({
        'jsonrpc': '2.0',
        'id': 5,
        'method': 'tools/call',
        'params': {'name': 'wait_for_events', 'arguments': <String, dynamic>{}},
      });
      c.send({'jsonrpc': '2.0', 'id': 6, 'method': 'ping'});
      expect((await c.next())!['id'], 6, reason: 'the held request is not answered yet');

      news = true;
      endpoint.pulse.value++;
      final reply = (await c.next())!;
      expect(reply['id'], 5);
      expect(reply['result'], {
        'structuredContent': {'events': 1},
      });
      // Asked again from where the hold said, not from "now", or what came
      // meanwhile would be skipped.
      expect(argumentsOf(endpoint.received.last.message), {'after': 7});
    });

    // The extension reads its queue, then waits on a host call before it
    // answers; an event that comes in between pulses the news while nothing
    // is held yet, and would otherwise wait out the whole hold.
    test('news that comes while the endpoint is answering asks again at once', () async {
      final c = await connected();
      var asks = 0;
      endpoint.resultFor = (message) {
        if (message['id'] != 5) return null;
        if (++asks == 1) {
          endpoint.pulse.value++;
          return _held(20, {'after': 7});
        }
        return {
          'structuredContent': {'events': 1},
        };
      };
      c.send({'jsonrpc': '2.0', 'id': 5, 'method': 'tools/call', 'params': <String, dynamic>{}});
      final reply = (await c.next())!;
      expect(reply['id'], 5);
      expect(reply['result'], {
        'structuredContent': {'events': 1},
      });
      expect(asks, 2);
    });

    test('with no news, is answered when its time is up, without the hold in it', () async {
      final c = await connected();
      endpoint.resultFor = (message) => message['id'] == 5 ? _held(1, {'after': 7}) : null;
      c.send({'jsonrpc': '2.0', 'id': 5, 'method': 'tools/call', 'params': <String, dynamic>{}});
      final reply = (await c.next())!;
      expect(reply['id'], 5);
      expect(reply['result'], {
        'structuredContent': {'events': 0},
      });
    });

    test('is forgotten when its app hangs up: news asks the endpoint nothing more', () async {
      final c = await connected();
      endpoint.resultFor = (message) => message['id'] == 5 ? _held(20, {'after': 7}) : null;
      c.send({'jsonrpc': '2.0', 'id': 5, 'method': 'tools/call', 'params': <String, dynamic>{}});
      c.send({'jsonrpc': '2.0', 'id': 6, 'method': 'ping'});
      await c.next();
      await c.close();
      for (var i = 0; i < 100 && link.connectionsOf(link.grants.single.id) > 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      final asked = endpoint.received.length;
      endpoint.pulse.value++;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(endpoint.received.length, asked);
    });
  });
}
