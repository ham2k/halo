// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/cluster/cluster_link.dart';
import 'package:ham2k_logger/services/cluster/cluster_protocol.dart';
import 'package:ham2k_logger/services/cluster/cluster_service.dart';
import 'package:ham2k_logger/services/cluster/cluster_settings.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_clock.dart';

/// A node as K1TTT behaved on the wire: a banner whose LINES mention the
/// callsign, a `login: ` prompt with no newline, a `<call> de <node> … >`
/// prompt after every command, and an echo of each spot it takes.
class _FakeNode implements ClusterLink {
  _FakeNode(
    this.host,
    this.port, {
    this.password,
    this.reply,
    this.loginPrompt = 'login: ',
    this.banner = const ['Welcome to the FAKE AR-Cluster node\nAt the login prompt please enter your amateur radio callsign.\n'],
    this.welcome = const [],
    this.prompts = true,
    this.answers = true,
    this.hangsUpOnCall = false,
  }) {
    // The prompt in a read of its own, as over a real network: a client
    // answering the banner instead of the prompt has sent its call before it.
    _sendReads(banner, () {
      _loginShown = true;
      _send(loginPrompt);
    });
  }

  /// K3LR's is a whole line, `Please enter your call:  \n`.
  final String loginPrompt;

  /// What comes before the login prompt, one read each — a real network
  /// splits a banner wherever it likes.
  final List<String> banner;

  /// What the node says after taking the call, before its first command
  /// prompt, one read each.
  final List<String> welcome;

  /// False for a node that never shows a command prompt.
  final bool prompts;

  /// False for a node that logs in and then never answers a command.
  final bool answers;

  /// A node that will not take this call, and says so by hanging up.
  final bool hangsUpOnCall;

  /// Each read [readGap] after the last, as over a real network — a gap
  /// shorter than the session's prompt quiet, longer than one event-loop turn.
  static const readGap = Duration(milliseconds: 20);

  void _sendReads(List<String> reads, void Function() then) {
    if (reads.isEmpty) return then();
    Timer(readGap, () {
      _send(reads.first);
      _sendReads(reads.sublist(1), then);
    });
  }

  bool _loginShown = false;

  final String host;
  final int port;

  /// When set, the node asks for it after the call.
  final String? password;

  /// What the node answers a command with, instead of its usual echo.
  final List<String>? Function(String command)? reply;

  final _out = StreamController<List<int>>();
  final received = <String>[];
  String? call;
  bool _awaitingPassword = false;
  bool closed = false;

  /// A node the network lost without a reset: it still takes writes, and
  /// never answers one.
  bool unreachable = false;

  @override
  Stream<List<int>> get data => _out.stream;

  void _send(String text) {
    if (!closed) _out.add(latin1.encode(text.replaceAll('\n', '\r\n')));
  }

  String get _prompt => '$call de FAKE 15-Oct 0354Z arc6>';

  /// A line the node sends on its own — another station's spot.
  void broadcast(String line) => _send('$line\n');

  /// The node ends the session.
  void hangUp() {
    closed = true;
    _out.close();
  }

  @override
  void write(List<int> bytes) {
    final text = latin1.decode(bytes);
    expect(text, endsWith('\r\n'), reason: 'every line a node reads ends in CRLF');
    final line = text.substring(0, text.length - 2);
    if (unreachable) return;
    if (!_loginShown) {
      received.add('(before the prompt) $line');
      return;
    }
    received.add(line);
    if (call == null) {
      if (hangsUpOnCall) return hangUp();
      call = line;
      if (password != null) {
        _awaitingPassword = true;
        _send('password: ');
        return;
      }
      _sendReads(['Hello $line\n', ...welcome], () {
        if (prompts) _send(_prompt);
      });
      return;
    }
    if (_awaitingPassword) {
      if (line == password) {
        _awaitingPassword = false;
        _send('Hello $call\n$_prompt');
      } else {
        _send('Sorry\npassword: ');
      }
      return;
    }
    if (line == 'bye' || !answers) return;
    final answer = reply?.call(line) ?? _echo(line);
    _send('${answer.map((l) => '$l\n').join()}$_prompt');
  }

  List<String> _echo(String line) {
    final words = line.split(' ');
    if (words.first != 'DX') return const [];
    return ['DX de $call:     ${words[1]}  ${words[2]}       ${words.skip(3).join(' ')}     0354Z'];
  }

  @override
  Future<void> close() async {
    closed = true;
    await _out.close();
  }
}

void main() {
  late SettingsService settings;
  late ClusterService service;
  late List<_FakeNode> nodes;
  late String? operator;
  late Map<String, String> passwords;
  List<String> Function(String command)? reply;
  String? nodePassword;
  String loginPrompt = 'login: ';
  List<String>? banner;
  List<String> welcome = const [];
  bool prompts = true;
  bool answers = true;
  bool hangsUpOnCall = false;

  /// How long a dial takes; one longer than its timeout fails, as a socket's does.
  Duration dialTime = Duration.zero;

  /// When set, every dial waits for it.
  Completer<void>? dialGate;

  Future<void> start({Map<String, dynamic> cluster = const {}, bool supported = true, Duration deadline = const Duration(seconds: 14)}) async {
    SharedPreferences.setMockInitialValues({'settings.cluster': jsonEncode(cluster)});
    settings = SettingsService(await SharedPreferences.getInstance());
    service = ClusterService(
      settings: settings,
      loginCall: () => operator,
      password: (node) async => passwords[node.address],
      supported: supported,
      deadline: deadline,
      connect: (host, port, timeout) async {
        await dialGate?.future;
        if (dialTime > timeout) {
          await Future<void>.delayed(timeout);
          throw const SocketException('Connection timed out');
        }
        if (dialTime > Duration.zero) await Future<void>.delayed(dialTime);
        final node = _FakeNode(
          host,
          port,
          password: nodePassword,
          reply: (command) => reply?.call(command),
          loginPrompt: loginPrompt,
          banner: banner ?? const ['Welcome to the FAKE AR-Cluster node\nAt the login prompt please enter your amateur radio callsign.\n'],
          welcome: welcome,
          prompts: prompts,
          answers: answers,
          hangsUpOnCall: hangsUpOnCall,
        );
        nodes.add(node);
        return node;
      },
    );
    addTearDown(service.dispose);
  }

  setUp(() {
    nodes = [];
    operator = 'KI2D';
    passwords = {};
    reply = null;
    nodePassword = null;
    loginPrompt = 'login: ';
    banner = null;
    welcome = const [];
    prompts = true;
    answers = true;
    hangsUpOnCall = false;
    dialTime = Duration.zero;
    dialGate = null;
  });

  group('spotCommand', () {
    test('writes a whole kHz without a decimal and a fraction to one place', () {
      expect(spotCommand(freqKHz: 7200, call: 'n2y', comment: 'This is a test').command, 'DX 7200 N2Y This is a test');
      expect(spotCommand(freqKHz: 14074.5, call: 'N2Y').command, 'DX 14074.5 N2Y');
    });

    test('a newline in the comment cannot become a second command', () {
      // The node reads a line per command: an embedded newline would post the
      // spot and then broadcast an announcement to every node as the operator.
      final command = spotCommand(freqKHz: 7200, call: 'N2Y', comment: 'hi\r\nANNOUNCE/FULL spam').command!;
      expect(command, isNot(contains('\n')));
      expect(command, 'DX 7200 N2Y hi ANNOUNCE/FULL spam');
    });

    test('refuses a call no node would take, and a frequency that is not one', () {
      expect(spotCommand(freqKHz: 7200, call: 'N2Y TEST').error, 'invalidCall');
      expect(spotCommand(freqKHz: 0, call: 'N2Y').error, 'invalidFrequency');
    });

    test('cuts a runaway comment, not one longer than the 30-column display', () {
      final comment = 'NYQP SUL/DEL - POTA US-1234 - LLOTA LLUS-1234';
      expect(spotCommand(freqKHz: 7200, call: 'KI2D', comment: comment).command, 'DX 7200 KI2D $comment');
      expect(spotCommand(freqKHz: 7200, call: 'KI2D', comment: 'x' * 100).command!.length, 'DX 7200 KI2D '.length + maxSpotCommentLength);
    });
  });

  test('a 0xFF in a line is doubled, so it cannot start a telnet command', () {
    expect(encodeClusterLine('ÿ'), [0xFF, 0xFF, 0x0D, 0x0A]);
  });

  group('ClusterLineDecoder', () {
    test('drops telnet negotiation, even split across reads', () {
      final decoder = ClusterLineDecoder();
      expect(decoder.add([0xFF, 0xFB]), isEmpty);
      expect(decoder.add([0x01, ...latin1.encode('Hello\r\nlog')]), ['Hello']);
      expect(decoder.add(latin1.encode('in: ')), isEmpty);
      expect(decoder.partial, 'login: ');
    });
  });

  test('logs in as the operator, at the prompt rather than at a banner line naming the callsign', () async {
    await start();
    final result = await service.postSpot(freqKHz: 7200, call: 'N2Y', comment: 'This is a test');
    expect(result.ok, isTrue);
    expect(nodes.single.received, ['KI2D', 'DX 7200 N2Y This is a test']);
    expect(nodes.single.host, 'dx.k3lr.com', reason: 'K3LR is the default node');
    expect(service.status.state, ClusterState.connected);
  });

  test('logs in at a prompt the node ends with a newline, still not at the banner line', () async {
    // K3LR, the default node: answering only an unterminated prompt waits out
    // the whole login timeout there, on every connection.
    loginPrompt = 'Please enter your call:  \n';
    await start();
    final result = await service.postSpot(freqKHz: 7200, call: 'N2Y');
    expect(result.ok, isTrue);
    expect(nodes.single.received, ['KI2D', 'DX 7200 N2Y']);
  });

  test('a banner split mid-sentence is not a prompt, wherever the network cuts it', () async {
    // Cut after "login", or after "callsign" in NC7J's "Enter your callsign"
    // line: answered there, the call goes out before the node listens.
    banner = ['Welcome\nAt the login', ' prompt please enter your amateur radio callsign', '.\nEnter your callsign', '\n'];
    await start();
    expect((await service.send('sh/version')).ok, isTrue);
    expect(nodes.single.received, ['KI2D', 'sh/version']);
  });

  test('a welcome text that mentions a password, split after the word or ending a read in a colon, is not a password prompt', () async {
    // Taken for one, the stored password goes out as a command, and the
    // node's reply echoing it lands where every reading extension sees it.
    // Text alone cannot tell "Use set/password:" from the prompt; the node
    // going on talking can.
    passwords = {'dx.k3lr.com:23': 'secret'};
    welcome = ['Use set/password', ' to protect your call.\nUse set/password:', ' to change it\n'];
    await start();
    expect((await service.send('sh/version')).ok, isTrue);
    expect(nodes.single.received, ['KI2D', 'sh/version'], reason: 'the password never left');
  });

  test('a node that takes the call but never shows its command prompt is a failed login', () async {
    // Taken for logged in, the next command would answer whatever the node
    // is still asking.
    prompts = false;
    await start();
    final result = await service.postSpot(freqKHz: 7200, call: 'N2Y');
    expect(result.ok, isFalse);
    expect(result.error, 'loginFailed');
    expect(nodes.single.received, isNot(contains(startsWith('DX'))), reason: 'the spot was never typed into the unknown prompt');
  });

  test('a server changed during a login ends that login at once, and never shows it as connected', () {
    runOnFakeClock((async) async {
      prompts = false;
      await start();
      final pending = service.send('sh/version');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await settings.setSettingValue(ClusterSettings.group, ClusterSettings.nodeKey, 'K1TTT');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(nodes.first.closed, isTrue);
      expect(service.status.state, isNot(ClusterState.connected));
      final result = await pending;
      expect(result.ok, isFalse);
      expect(service.status.state, isNot(ClusterState.connected));
      expect(service.status.node.name, 'K1TTT', reason: 'the old login does not speak for the new server');
    });
  });

  test('the reply is what came between the command and the next prompt', () async {
    await start();
    final result = await service.send('sh/version');
    expect(result.ok, isTrue);
    expect(result.lines, isEmpty);
    reply = (_) => ['AR-Cluster version: 6.6.181'];
    expect((await service.send('sh/version')).lines, ['AR-Cluster version: 6.6.181']);
  });

  test('a node that says no is a failed spot quoting it, even though it echoed one', () async {
    await start();
    reply = (_) => ['DX de KI2D:  7200.0  N2Y  test  0354Z', 'Sorry, this is a duplicate'];
    final result = await service.postSpot(freqKHz: 7200, call: 'N2Y', comment: 'test');
    expect(result.ok, isFalse);
    expect(result.error, 'refused');
    expect(result.message, 'Sorry, this is a duplicate');
  });

  test('a changed operator logs in again before the next spot, so it reads DX de the new operator', () async {
    await start();
    await service.postSpot(freqKHz: 7200, call: 'N2Y');
    operator = 'W1AW';
    await service.send('sh/version');
    expect(nodes, hasLength(2));
    expect(nodes.first.closed, isTrue);
    expect(nodes.last.received.first, 'W1AW');
  });

  test('sends the stored password when the node asks for one', () async {
    nodePassword = 'secret';
    passwords = {'dx.k3lr.com:23': 'secret'};
    await start();
    expect((await service.send('sh/version')).ok, isTrue);
    expect(nodes.single.received.take(2), ['KI2D', 'secret']);
  });

  test('a node asking for a password the operator never stored is a needsPassword failure, not a hang', () async {
    nodePassword = 'secret';
    await start();
    final result = await service.send('sh/version');
    expect(result.error, 'needsPassword');
    expect(service.status.state, ClusterState.failed);
  });

  test('no operator is noCall, and no connection — and the status says so', () async {
    operator = null;
    await start();
    expect((await service.send('sh/version')).error, 'noCall');
    expect(nodes, isEmpty);
    expect(service.status.error, 'noCall', reason: 'the Connection row reads the status, not the reply');
  });

  test('a platform without sockets answers unsupported', () async {
    await start(supported: false);
    expect((await service.postSpot(freqKHz: 7200, call: 'N2Y')).error, 'unsupported');
  });

  test('a custom node is the one connected to', () async {
    await start(
      cluster: {ClusterSettings.nodeKey: ClusterSettings.custom, ClusterSettings.customHostKey: 'dxc.example.net', ClusterSettings.customPortKey: '7300'},
    );
    await service.send('sh/version');
    expect((nodes.single.host, nodes.single.port), ('dxc.example.net', 7300));
  });

  test('spots are spaced apart, so a looping extension cannot trip the node\'s flood block', () {
    runOnFakeClock((async) async {
      await start();
      expect((await service.postSpot(freqKHz: 7200, call: 'N2Y')).ok, isTrue);
      expect((await service.postSpot(freqKHz: 7201, call: 'N2Y')).error, 'tooSoon');
      await Future<void>.delayed(service.spotInterval);
      expect((await service.postSpot(freqKHz: 7202, call: 'N2Y')).ok, isTrue);
    });
  });

  test('a session nothing uses closes after the idle timeout; a subscribed one stays', () {
    runOnFakeClock((async) async {
      await start();
      await service.send('sh/version');
      await Future<void>.delayed(service.idleTimeout + const Duration(seconds: 1));
      expect(nodes.single.closed, isTrue, reason: 'held longer, it fights the operator\'s own client under the same call');
      expect(service.status.state, ClusterState.idle);

      await service.subscribe('ki2d-reader');
      await Future<void>.delayed(service.idleTimeout * 2);
      expect(nodes.last.closed, isFalse);
      service.unsubscribe('ki2d-reader');
      await Future<void>.delayed(service.idleTimeout + const Duration(seconds: 1));
      expect(nodes.last.closed, isTrue);
    }, limit: const Duration(hours: 1));
  });

  test('a subscriber gets the lines after it subscribed, batched, and never the same line twice', () {
    runOnFakeClock((async) async {
      await start();
      final delivered = <String, List<List<String>>>{};
      var failNext = false;
      service.deliver = (subscriber, lines) async {
        delivered.putIfAbsent(subscriber, () => []).add([for (final l in lines) l.text]);
        if (failNext) {
          failNext = false;
          throw StateError('hook failed');
        }
      };
      await service.subscribe('reader');
      await Future<void>.delayed(service.batchDelay * 2);
      delivered.clear();

      nodes.single
        ..broadcast('DX de W3LPL:  14025.0  JA1ABC  cq  0400Z')
        ..broadcast('DX de K1TTT:  7010.0  ZL2XX  up  0400Z');
      failNext = true;
      await Future<void>.delayed(service.batchDelay * 2);
      expect(delivered['reader'], [
        ['DX de W3LPL:  14025.0  JA1ABC  cq  0400Z', 'DX de K1TTT:  7010.0  ZL2XX  up  0400Z'],
      ], reason: 'one batch, not a hook call per line');

      nodes.single.broadcast('DX de NC7J:  21074.0  VK2AB  FT8  0401Z');
      await Future<void>.delayed(service.batchDelay * 2);
      expect(delivered['reader']!.last, ['DX de NC7J:  21074.0  VK2AB  FT8  0401Z'], reason: 'a failed delivery is not repeated on every flush');
    });
  });

  test('line numbers keep counting across a reconnect, and the scrollback keeps its size', () {
    runOnFakeClock((async) async {
      await start(cluster: {ClusterSettings.scrollbackKey: 500});
      await service.subscribe('reader');
      for (var i = 0; i < 600; i++) {
        nodes.single.broadcast('line $i');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final before = service.status.lastSeq;
      expect(service.lines(), hasLength(500));
      expect(service.lines(limit: 2).map((l) => l.text), ['line 598', 'line 599']);

      nodes.single.hangUp();
      await Future<void>.delayed(service.reconnectDelays.first + const Duration(seconds: 1));
      expect(nodes, hasLength(2), reason: 'a subscriber is waiting, so a dropped session comes back');
      final after = service.lines(after: before);
      expect(after, isNotEmpty);
      expect(after.first.seq, before + 1, reason: 'a reader asking for what came after the last line it saw must not miss one');
    });
  });

  test('a command the connection drops under goes out again on a new session', () {
    runOnFakeClock((async) async {
      await start();
      await service.send('sh/version');
      reply = (command) {
        if (nodes.length == 1) nodes.single.hangUp();
        return const [];
      };
      final result = await service.postSpot(freqKHz: 14025, call: 'JA1ABC', comment: 'cq');
      expect(result.ok, isTrue, reason: 'a spot lost to a drop never reaches the cluster, and the operator cannot tell');
      expect(nodes, hasLength(2));
      expect(nodes.last.received, contains(spotCommand(freqKHz: 14025, call: 'JA1ABC', comment: 'cq').command));
    });
  });

  test('a node that stops answering is dropped, and the command goes out on a new session', () {
    runOnFakeClock((async) async {
      await start();
      await service.send('sh/version');
      nodes.single.unreachable = true;
      final result = await service.send('sh/dx');
      expect(result.ok, isTrue);
      expect(nodes, hasLength(2), reason: 'a lost connection reads as open for minutes; kept, every command waits out its timeout on it');
      expect(nodes.first.closed, isTrue);
    });
  });

  test('a command stops being retried once its deadline runs out', () {
    runOnFakeClock((async) async {
      await start();
      var dials = 0;
      service = ClusterService(
        settings: settings,
        loginCall: () => operator,
        password: (node) async => null,
        connect: (host, port, timeout) async {
          dials++;
          throw const SocketException('Connection refused');
        },
      );
      addTearDown(service.dispose);
      final started = realNowMillis();
      final result = await service.send('sh/dx');
      expect(result.error, 'connectFailed');
      expect(dials, greaterThan(1));
      expect(
        realNowMillis() - started,
        lessThanOrEqualTo(service.deadline.inMilliseconds),
        reason: 'commands go out one at a time: one retried for good holds every command behind it',
      );
    });
  });

  test('every attempt at a command fits in its deadline, however slow each step is', () {
    runOnFakeClock((async) async {
      // Each attempt here takes 3 s to dial and 5 s waiting on the reply; a
      // retry started late in the window would run past the 15 s a spots
      // hook waits, and the spot it reported as timed out would go out after.
      dialTime = const Duration(seconds: 3);
      answers = false;
      await start();
      final started = realNowMillis();
      final result = await service.postSpot(freqKHz: 14025, call: 'JA1ABC');
      expect(result.error, 'timeout');
      expect(nodes.length, greaterThan(1), reason: 'the first attempt leaves time for another');
      expect(realNowMillis() - started, lessThanOrEqualTo(service.deadline.inMilliseconds));
    });
  });

  test('a command abandoned with nothing holding the session says why, in the status and the console', () {
    runOnFakeClock((async) async {
      answers = false;
      await start();
      await service.send('sh/version');
      expect(service.status.state, ClusterState.failed, reason: 'Settings\' "Tap to test" would otherwise read "Not connected" after a failed test');
      expect(service.status.error, 'timeout');
      final last = service.transcript.entries.last;
      expect(last.kind, ClusterTranscriptKind.gaveUp, reason: 'a command typed in the console must not vanish without a word');
      expect(last.text, 'sh/version');
      expect(last.status!.error, 'timeout');
    });
  });

  test('a node that answers and then hangs up took the command: it is not sent again', () {
    runOnFakeClock((async) async {
      await start();
      await service.send('sh/version');
      reply = (command) {
        if (command != 'quit') return const [];
        nodes.last
          ..broadcast('73 de FAKE')
          ..hangUp();
        return const [];
      };
      final result = await service.send('quit');
      expect(result.error, 'disconnected');
      expect(nodes, hasLength(1), reason: 'resent, a quit would log in only to be thrown out again, over and over');
    });
  });

  test('a node that hangs up on the call fails the login once, rather than leaving it connecting', () {
    runOnFakeClock((async) async {
      hangsUpOnCall = true;
      await start();
      final result = await service.send('sh/dx');
      expect(result.error, 'loginFailed');
      expect(service.status.state, ClusterState.failed, reason: 'nothing replaces the session, so nothing else would ever report it');
      expect(service.status.error, 'loginFailed');
      expect(nodes, hasLength(1), reason: 'a node refusing the call, logged in to again and again, is how it comes to ban the operator');
    });
  });

  test('a spot from the network arriving before a drop is no answer: the command goes out again', () {
    runOnFakeClock((async) async {
      await start();
      await service.send('sh/version');
      reply = (command) {
        if (nodes.length == 1) {
          nodes.single
            ..broadcast('DX de W3LPL:  14025.0  JA1ABC  cq  0400Z')
            ..hangUp();
        }
        return const [];
      };
      final result = await service.postSpot(freqKHz: 7010, call: 'ZL2XX');
      expect(result.ok, isTrue, reason: 'on a busy node a spot always arrives meanwhile; taken for an answer, a lost spot is never resent');
      expect(nodes, hasLength(2));
    });
  });

  test('a deadline that runs short is a timeout, not a refused login or a dead session', () {
    runOnFakeClock((async) async {
      prompts = false;
      await start(deadline: const Duration(seconds: 4));
      final login = await service.send('sh/version');
      expect(login.error, 'timeout', reason: 'out of time is not the node refusing the login; "loginFailed" sends the operator after their call or password');
      expect(service.status.error, 'timeout');

      prompts = true;
      await service.send('sh/version');
      expect(service.status.state, ClusterState.connected);
      nodes.last.unreachable = true;
      final slow = service.send('sh/dx');
      final queued = service.send('sh/wwv');
      expect((await slow).error, 'timeout');
      expect(nodes.last.closed, isFalse, reason: 'a wait the deadline cut short says nothing about the session');
      expect((await queued).error, 'timeout');
      expect(nodes.last.received, isNot(contains('sh/wwv')), reason: 'sent with no time left to answer, a command goes out and is reported failed anyway');
    });
  });

  test('turning the connection off closes the session, refuses every command, and stops reconnecting', () {
    runOnFakeClock((async) async {
      await start();
      await service.subscribe('reader');
      expect(service.status.state, ClusterState.connected);

      await settings.setSettingValue(ClusterSettings.group, ClusterSettings.connectKey, false);
      expect(nodes.single.closed, isTrue, reason: 'off means off now, not after the idle timeout');
      expect(service.transcript.entries.last.status?.error, 'off', reason: 'the console says where the session went');
      expect(service.status.error, 'off');
      expect((await service.send('sh/dx')).error, 'off');
      expect((await service.postSpot(freqKHz: 14025, call: 'JA1ABC')).error, 'off');
      await Future<void>.delayed(service.reconnectDelays.last * 2);
      expect(nodes, hasLength(1), reason: 'a subscriber waiting must not bring back a connection the operator turned off');

      await settings.setSettingValue(ClusterSettings.group, ClusterSettings.connectKey, true);
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(nodes, hasLength(2), reason: 'back on, the subscriber that was waiting is served again');
      expect(service.status.state, ClusterState.connected);
    }, limit: const Duration(hours: 1));
  });

  test('turning the connection off while it connects keeps it from logging in', () {
    runOnFakeClock((async) async {
      dialGate = Completer<void>();
      await start();
      final subscribed = service.subscribe('reader');
      await Future<void>.delayed(Duration.zero);
      await settings.setSettingValue(ClusterSettings.group, ClusterSettings.connectKey, false);
      dialGate!.complete();
      await subscribed;
      expect(nodes.single.closed, isTrue);
      expect(nodes.single.received, isEmpty, reason: 'the operator turned it off: no login under their call, which another client of theirs would lose to');
      await Future<void>.delayed(service.reconnectDelays.last * 2);
      expect(nodes, hasLength(1));
    }, limit: const Duration(hours: 1));
  });

  test('Disconnect while connecting keeps the session closed', () {
    runOnFakeClock((async) async {
      dialGate = Completer<void>();
      await start();
      final subscribed = service.subscribe('reader');
      await Future<void>.delayed(Duration.zero);
      service.disconnect();
      dialGate!.complete();
      await subscribed;
      expect(nodes.single.closed, isTrue);
      expect(service.status.state, ClusterState.idle);
      await Future<void>.delayed(service.reconnectDelays.last * 2);
      expect(nodes, hasLength(1), reason: 'a connect already under way, or the subscriber behind it, would undo the Disconnect');
    }, limit: const Duration(hours: 1));
  });

  test('the transcript shows what went out but never the password', () {
    runOnFakeClock((async) async {
      nodePassword = 'hunter2';
      passwords = {'dx.k3lr.com:23': 'hunter2'};
      await start();
      await service.send('sh/version');
      final entries = service.transcript.entries;
      final sent = [
        for (final e in entries)
          if (e.kind == ClusterTranscriptKind.sent) e.text,
      ];
      expect(sent, ['KI2D', 'sh/version']);
      expect(entries.any((e) => e.text.contains('hunter2')), isFalse, reason: 'the console is on screen, and in screenshots');
      expect(entries.any((e) => e.kind == ClusterTranscriptKind.status && e.status!.state == ClusterState.connected), isTrue);
      expect(entries.any((e) => e.kind == ClusterTranscriptKind.received && e.text.startsWith('Hello KI2D')), isTrue);
    });
  });

  test('Connect holds the session while the console is open; Disconnect closes it and keeps it closed', () {
    runOnFakeClock((async) async {
      await start();
      await service.stayConnected();
      await Future<void>.delayed(service.idleTimeout * 2);
      expect(nodes.single.closed, isFalse, reason: 'an operator reading the console is using the session');

      nodes.single.hangUp();
      await Future<void>.delayed(service.reconnectDelays.first + const Duration(seconds: 1));
      expect(nodes, hasLength(2), reason: 'a held session reconnects like a subscribed one');

      await service.subscribe('reader');
      service.disconnect();
      expect(nodes.last.closed, isTrue);
      await Future<void>.delayed(service.reconnectDelays.last * 2);
      expect(nodes, hasLength(2), reason: 'Disconnect would mean nothing if a subscriber dialled straight back');

      await service.send('sh/dx');
      expect(nodes, hasLength(3), reason: 'the next use asks for the session again');
    }, limit: const Duration(hours: 1));
  });

  test('a smaller scrollback shows in an open console at once', () {
    runOnFakeClock((async) async {
      await start();
      await service.subscribe('reader');
      for (var i = 0; i < 600; i++) {
        nodes.single.broadcast('line $i');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
      var notified = false;
      service.transcript.addListener(() => notified = true);
      await settings.setSettingValue(ClusterSettings.group, ClusterSettings.scrollbackKey, 500);
      expect(service.transcript.entries, hasLength(500));
      expect(notified, isTrue, reason: 'on a quiet node, the console would show the old entries until the next line');
    });
  });

  test('closing the console lets a held session idle out', () {
    runOnFakeClock((async) async {
      await start();
      await service.stayConnected();
      service.release();
      await Future<void>.delayed(service.idleTimeout + const Duration(seconds: 1));
      expect(nodes.single.closed, isTrue);
    });
  });
}
