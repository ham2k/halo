// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The extension dev link (docs/design/extension-dev-link.md): what a dev tool
// on this machine is told, when the operator is asked, and that an allow
// lasts the app session and no longer. The h2kext-dev end of the same
// exchange is asserted in extensions/tools; these lines are the contract.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/agent_link/agent_link_peer.dart';
import 'package:ham2k_logger/services/extensions/dev_link/extension_dev_link.dart';
import 'package:ham2k_logger/services/extensions/extension_dev_client.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';

class _Peer implements AgentLinkPeer {
  final _in = StreamController<String>();
  final _done = Completer<void>();
  final sent = <Map<String, dynamic>>[];

  @override
  Stream<String> get lines => _in.stream;

  @override
  Future<void> get done => _done.future;

  @override
  void send(String line) {
    if (!_done.isCompleted) sent.add(jsonDecode(line) as Map<String, dynamic>);
  }

  @override
  Future<void> close() async {
    if (!_in.isClosed) unawaited(_in.close());
    if (!_done.isCompleted) _done.complete();
  }

  void say(Map<String, Object?> message) => _in.add(jsonEncode(message));

  /// The tool hanging up.
  Future<void> hangUp() => close();
}

class _Listener implements AgentLinkListener {
  @override
  final int port;
  final void Function(AgentLinkPeer) onPeer;
  bool closed = false;

  _Listener(this.port, this.onPeer);

  @override
  Future<void> close() async => closed = true;
}

/// Connects nowhere: records what it was asked to connect to, and reports
/// connected with the keys it was limited to, after failing its first
/// [failures] tries.
class _FakeClient extends ExtensionDevClient {
  final Set<String> keys;
  int failures;
  final connectedTo = <String>[];
  int disconnects = 0;
  DevServerState _fakeState = DevServerState.disconnected;

  _FakeClient(String server, this.keys, {this.failures = 0}) : super(extensions: ExtensionService(), server: server, only: keys);

  @override
  DevServerState get state => _fakeState;

  @override
  String? get lastError => _fakeState == DevServerState.failed ? 'the dev server is serving no extensions' : null;

  @override
  List<String> get servedKeys => [...keys];

  Map<String, String> _loadErrors = const {};

  @override
  Map<String, String> get loadErrors => _loadErrors;

  /// A save that built but would not load in the app.
  void failLoad(String key, String why) {
    _loadErrors = {key: why};
    notifyListeners();
  }

  @override
  Future<void> connect(String url) async {
    connectedTo.add(url);
    _fakeState = failures-- > 0 ? DevServerState.failed : DevServerState.connected;
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    disconnects++;
    _fakeState = DevServerState.disconnected;
  }
}

void main() {
  late ValueNotifier<bool> developerMode;
  late List<_Listener> listeners;
  late List<_FakeClient> clients;
  late Set<int> takenPorts;
  late int failingConnects;
  late Object Function(int port) bindError;

  ExtensionDevLink makeLink() {
    final link = ExtensionDevLink(
      wanted: () => developerMode.value,
      changes: developerMode,
      ports: const [47392, 47393],
      app: const {'name': 'Ham2K Logger', 'edition': 'dev', 'label': 'notes work', 'version': '26.11'},
      newClient: (server, keys) {
        final client = _FakeClient(server, keys, failures: failingConnects);
        clients.add(client);
        return client;
      },
      bind: ({required port, required onPeer}) async {
        if (takenPorts.contains(port)) throw bindError(port);
        final listener = _Listener(port, onPeer);
        listeners.add(listener);
        return listener;
      },
      retryDelay: Duration.zero,
    );
    addTearDown(link.dispose);
    return link;
  }

  /// A tool connecting to the listening link.
  _Peer connect() {
    final peer = _Peer();
    listeners.last.onPeer(peer);
    return peer;
  }

  const ask = {
    'extDevLink': 1,
    'tool': {'name': 'h2kext-dev', 'version': '1.29.0'},
    'dir': '/Users/w7abc/notes',
    'keys': ['w7abc-notes'],
    'server': 'http://127.0.0.1:8787/',
  };

  setUp(() {
    developerMode = ValueNotifier(true);
    listeners = [];
    clients = [];
    takenPorts = {};
    failingConnects = 0;
    bindError = (port) => SocketException('Address already in use', osError: const OSError('Address already in use', 48), port: port);
  });

  test('listens only while Developer Mode is on', () async {
    developerMode.value = false;
    final link = makeLink();
    await pumpEventQueue();
    expect(link.port, isNull);
    expect(listeners, isEmpty, reason: 'an app nobody develops on opens no port');

    developerMode.value = true;
    await pumpEventQueue();
    expect(link.port, 47392);

    developerMode.value = false;
    await pumpEventQueue();
    expect(link.port, isNull);
    expect(listeners.single.closed, isTrue);
  });

  test('a Dev build whose port another Dev build holds takes the next one', () async {
    takenPorts = {47392};
    final link = makeLink();
    await pumpEventQueue();
    expect(link.port, 47393, reason: 'two worktrees\' Dev builds run side by side');
  });

  test('a probe is told which app this is, and nothing is asked', () async {
    final link = makeLink();
    await pumpEventQueue();
    final peer = connect()..say({'extDevLink': 1, 'probe': true});
    await pumpEventQueue();
    expect(peer.sent.single['app'], containsPair('label', 'notes work'));
    expect(link.pendingRequest, isNull);
  });

  test('a first line that is not the link\'s is hung up on unanswered', () async {
    makeLink();
    await pumpEventQueue();
    final peer = _Peer();
    listeners.last.onPeer(peer);
    peer._in.add('GET / HTTP/1.1');
    await pumpEventQueue();
    expect(peer.sent, isEmpty, reason: 'a web page reaching the port gets nothing to read');
    expect(peer._done.isCompleted, isTrue);
  });

  test('a server anywhere but this machine is refused before the operator is asked', () async {
    final link = makeLink();
    await pumpEventQueue();
    final peer = connect()..say({...ask, 'server': 'http://10.0.0.5:8787/'});
    await pumpEventQueue();
    expect(peer.sent.single, containsPair('reason', 'protocol'));
    expect(link.pendingRequest, isNull, reason: 'the dialog shows a folder on this machine; the code must come from there too');
  });

  test('an ask waits on the operator, and an allow connects to the tool\'s server for the keys it named', () async {
    final link = makeLink();
    await pumpEventQueue();
    final peer = connect()..say(ask);
    await pumpEventQueue();

    expect(peer.sent.single, containsPair('asking', true));
    expect(link.pendingRequest!.ask.keys, ['w7abc-notes']);
    expect(clients, isEmpty, reason: 'nothing is fetched before the operator says yes');

    link.answer(link.pendingRequest!, allow: true);
    await pumpEventQueue();

    expect(peer.sent[1], containsPair('ok', true));
    expect(clients.single.connectedTo, ['http://127.0.0.1:8787/']);
    expect(clients.single.keys, {'w7abc-notes'});
    expect(peer.sent.last, allOf(containsPair('state', 'connected'), containsPair('keys', ['w7abc-notes'])));
    expect(link.connections, hasLength(1));
  });

  test('a deny is said, and nothing connects', () async {
    final link = makeLink();
    await pumpEventQueue();
    final peer = connect()..say(ask);
    await pumpEventQueue();
    link.answer(link.pendingRequest!, allow: false);
    await pumpEventQueue();
    expect(peer.sent.last, containsPair('reason', 'denied'));
    expect(clients, isEmpty);
  });

  test('the allow lasts the session: the same folder and keys get back in without asking', () async {
    final link = makeLink();
    await pumpEventQueue();
    final first = connect()..say(ask);
    await pumpEventQueue();
    link.answer(link.pendingRequest!, allow: true);
    await pumpEventQueue();
    await first.hangUp();
    await pumpEventQueue();
    expect(clients.single.disconnects, 1, reason: 'a tool that stops takes its extensions with it');
    expect(link.connections, isEmpty);

    final again = connect()..say(ask);
    await pumpEventQueue();
    expect(again.sent.first, containsPair('ok', true), reason: 'restarting h2kext-dev must not ask the operator every time');

    final other = connect()
      ..say({
        ...ask,
        'keys': ['w7abc-keyer'],
      });
    await pumpEventQueue();
    expect(other.sent.single, containsPair('asking', true), reason: 'the allow was for the extension the operator was shown');
  });

  test('a tool that hangs up while the operator is being asked withdraws the question', () async {
    final link = makeLink();
    await pumpEventQueue();
    final peer = connect()..say(ask);
    await pumpEventQueue();
    final request = link.pendingRequest!;
    await peer.hangUp();
    await pumpEventQueue();
    expect(link.pendingRequest, isNull);
    await expectLater(request.withdrawn, completes, reason: 'the dialog closes itself');
  });

  test('the operator disconnecting a tool tells it so, and its next ask asks again', () async {
    final link = makeLink();
    await pumpEventQueue();
    final peer = connect()..say(ask);
    await pumpEventQueue();
    link.answer(link.pendingRequest!, allow: true);
    await pumpEventQueue();

    await link.disconnect(link.connections.single);
    await pumpEventQueue();
    expect(peer.sent.last, containsPair('closed', 'disconnected'), reason: 'otherwise the tool reconnects at once and the disconnect undoes itself');
    expect(clients.single.disconnects, 1);

    final again = connect()..say(ask);
    await pumpEventQueue();
    expect(again.sent.single, containsPair('asking', true));
  });

  test('turning Developer Mode off forgets every allow', () async {
    final link = makeLink();
    await pumpEventQueue();
    final peer = connect()..say(ask);
    await pumpEventQueue();
    link.answer(link.pendingRequest!, allow: true);
    await pumpEventQueue();
    await peer.hangUp();

    developerMode.value = false;
    await pumpEventQueue();
    developerMode.value = true;
    await pumpEventQueue();

    final again = connect()..say(ask);
    await pumpEventQueue();
    expect(again.sent.single, containsPair('asking', true));
  });

  test('a tool whose connect fails is tried again until its extension loads, without asking anyone', () async {
    failingConnects = 2;
    final link = makeLink();
    await pumpEventQueue();
    final peer = connect()..say(ask);
    await pumpEventQueue();
    link.answer(link.pendingRequest!, allow: true);
    await pumpEventQueue();

    // Without the retry, a build broken when the tool started stays failed
    // after the author fixes it: the tool does not ask again while connected.
    expect(clients.single.connectedTo, hasLength(3));
    expect(peer.sent.where((m) => m['state'] == 'failed'), hasLength(1), reason: 'the same failure is said once, not on every try');
    expect(peer.sent.last, containsPair('state', 'connected'));
    expect(link.pendingRequest, isNull);
  });

  test('turning Developer Mode off tells each tool so, connected or still waiting on the operator', () async {
    final link = makeLink();
    await pumpEventQueue();
    final connected = connect()..say(ask);
    await pumpEventQueue();
    link.answer(link.pendingRequest!, allow: true);
    await pumpEventQueue();
    final waiting = connect()
      ..say({
        ...ask,
        'keys': ['w7abc-keyer'],
      });
    await pumpEventQueue();

    developerMode.value = false;
    await pumpEventQueue();

    // Otherwise the tool reads the closed connection as the app quitting,
    // and sends the author looking for a crash.
    for (final peer in [connected, waiting]) {
      expect(peer.sent.last, allOf(containsPair('ok', false), containsPair('reason', 'unavailable')));
    }
  });

  test('a save that built but would not load in the app is told to the tool', () async {
    final link = makeLink();
    await pumpEventQueue();
    final peer = connect()..say(ask);
    await pumpEventQueue();
    link.answer(link.pendingRequest!, allow: true);
    await pumpEventQueue();

    clients.single.failLoad('w7abc-notes', 'TypeError: notes is undefined');
    await pumpEventQueue();
    // The tool built it fine; only the app knows it would not load, and the
    // terminal would otherwise go on saying it is running.
    expect(peer.sent.last['notLoaded'], {'w7abc-notes': 'TypeError: notes is undefined'});
  });

  test('ports taken are said as such, and anything else keeping it from listening is said as itself', () async {
    takenPorts = {47392, 47393};
    final taken = makeLink();
    await pumpEventQueue();
    expect(taken.failed, isTrue);
    expect(taken.failure, isNull, reason: 'the panel says the ports are taken');

    bindError = (port) => StateError('no network server entitlement');
    final broken = makeLink();
    await pumpEventQueue();
    expect(broken.failed, isTrue);
    expect(broken.failure, contains('entitlement'), reason: 'calling every bind error "ports taken" sends the operator after a program that is not there');
  });
}
