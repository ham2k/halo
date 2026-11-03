// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// PushService against a fake ham2k-push: a StreamChannelController pair
// stands in for the socket — `foreign` plays the server, `local` is handed
// to PushService as if it were the real WebSocket.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';

import 'package:ham2k_logger/services/push_service.dart';

class _FakeServer {
  final StreamChannelController<dynamic> _controller;
  final List<String> rawFromClient = [];
  bool closedByClient = false;

  _FakeServer() : _controller = StreamChannelController<dynamic>(sync: true) {
    _controller.foreign.stream.listen((raw) => rawFromClient.add(raw as String), onDone: () => closedByClient = true);
  }

  List<Map<String, dynamic>> get sentByClient => [for (final raw in rawFromClient) jsonDecode(raw) as Map<String, dynamic>];

  StreamChannel<dynamic> get local => _controller.local;

  void send(String event, {String? channel, Object? data}) {
    _controller.foreign.sink.add(jsonEncode({'event': event, 'channel': ?channel, 'data': data is String ? data : jsonEncode(data ?? const {})}));
  }

  void establish({int? activityTimeout}) => send('pusher:connection_established', data: {'socket_id': '1.1', 'activity_timeout': ?activityTimeout});

  /// The server closing the connection — PushService's stream sees `onDone`.
  void disconnect() => unawaited(_controller.foreign.sink.close());
}

/// A service whose every dial lands on a new fake server, listed in order.
(PushService, List<_FakeServer>) _connected() {
  final servers = <_FakeServer>[];
  final service = PushService(
    connect: (uri) {
      final s = _FakeServer();
      servers.add(s);
      return s.local;
    },
  );
  return (service, servers);
}

void main() {
  group('PushService', () {
    test('dials production ham2k-push unless a build names another', () {
      // The compiled-in default is what every shipped build uses; a wrong
      // one is realtime silently off everywhere, with the poll hiding it.
      fakeAsync((async) {
        final urls = <String>[];
        final production = PushService(
          connect: (uri) {
            urls.add('$uri');
            return _FakeServer().local;
          },
        );
        final staging = PushService(
          host: 'ham2k-push-staging.example.workers.dev',
          appKey: 'ham2k-push-staging',
          connect: (uri) {
            urls.add('$uri');
            return _FakeServer().local;
          },
        );

        production.subscribe('client-abc');
        staging.subscribe('client-abc');
        async.flushMicrotasks();

        expect(urls, [
          'wss://pusher.ham2k.net/app/ham2k-push?protocol=7&client=halo&version=1.0',
          'wss://ham2k-push-staging.example.workers.dev/app/ham2k-push-staging?protocol=7&client=halo&version=1.0',
        ]);
        production.dispose();
        staging.dispose();
      });
    });

    test('subscribing connects and sends pusher:subscribe once the connection is established', () {
      fakeAsync((async) {
        final (service, servers) = _connected();

        service.subscribe('client-abc123');
        async.flushMicrotasks();
        expect(servers.single.sentByClient, isEmpty, reason: 'nothing is sent before connection_established');

        servers.single.establish();
        async.flushMicrotasks();
        expect(servers.single.sentByClient, [
          {
            'event': 'pusher:subscribe',
            'data': {'channel': 'client-abc123'},
          },
        ]);
        service.dispose();
      });
    });

    test('a named event decodes its JSON-string data and arrives on .events', () {
      fakeAsync((async) {
        final (service, servers) = _connected();
        final received = <PushEvent>[];
        service.events.listen(received.add);

        service.subscribe('client-abc');
        async.flushMicrotasks();
        servers.single.establish();
        servers.single.send('webhook_event', channel: 'client-abc', data: {'id': 42});
        async.flushMicrotasks();

        expect(received.single.event, 'webhook_event');
        expect(received.single.channel, 'client-abc');
        expect(received.single.data, {'id': 42});
        service.dispose();
      });
    });

    test('protocol frames never reach .events, a server error included', () {
      // ham2k-push answers a subscription past its per-socket budget with a
      // pusher:error and keeps the connection; surfacing it as an app event
      // would hand consumers a frame with no channel to act on.
      fakeAsync((async) {
        final (service, servers) = _connected();
        final received = <PushEvent>[];
        service.events.listen(received.add);

        service.subscribe('client-abc');
        async.flushMicrotasks();
        servers.single.establish();
        servers.single.send('pusher_internal:subscription_succeeded', channel: 'client-abc', data: const {});
        servers.single.send('pusher:error', data: {'message': 'Subscription limit reached', 'code': 4100});
        async.flushMicrotasks();

        expect(received, isEmpty);
        expect(service.isConnected, isTrue, reason: 'a refused subscription is not a dead connection');
        service.dispose();
      });
    });

    test('pusher:ping gets a pusher:pong reply', () {
      fakeAsync((async) {
        final (service, servers) = _connected();
        service.subscribe('client-abc');
        async.flushMicrotasks();
        servers.single.establish();
        async.flushMicrotasks();
        servers.single.rawFromClient.clear();

        servers.single.send('pusher:ping', data: const {});
        async.flushMicrotasks();

        expect(servers.single.sentByClient, [
          {'event': 'pusher:pong', 'data': {}},
        ]);
        service.dispose();
      });
    });

    group('liveness', () {
      test('pings after a quiet spell, byte for byte the frame ham2k-push answers without waking', () {
        // push/src/protocol.ts PING_FRAME: the Durable Object's auto-response
        // matches the request string literally. Any other spelling still gets
        // a pong, but bills a wake per ping per connection.
        fakeAsync((async) {
          final (service, servers) = _connected();
          service.subscribe('client-abc');
          async.flushMicrotasks();
          servers.single.establish();
          async.flushMicrotasks();
          servers.single.rawFromClient.clear();

          async.elapse(PushService.maxActivityTimeout);

          expect(servers.single.rawFromClient, ['{"event":"pusher:ping","data":{}}']);
          service.dispose();
        });
      });

      test('pings sooner when the server advertises a shorter activity timeout', () {
        fakeAsync((async) {
          final (service, servers) = _connected();
          service.subscribe('client-abc');
          async.flushMicrotasks();
          servers.single.establish(activityTimeout: 45);
          async.flushMicrotasks();
          servers.single.rawFromClient.clear();

          async.elapse(const Duration(seconds: 45));

          expect(servers.single.sentByClient.single['event'], 'pusher:ping');
          service.dispose();
        });
      });

      test('a ping left unanswered drops the connection and redials', () {
        // The half-open socket after sleep or a network switch: writes go
        // nowhere and nothing ever closes it. Without the deadline the app
        // would sit "connected" and deaf for good.
        fakeAsync((async) {
          final (service, servers) = _connected();
          service.subscribe('client-abc');
          async.flushMicrotasks();
          servers.single.establish();
          async.flushMicrotasks();

          async.elapse(PushService.maxActivityTimeout + PushService.pongTimeout);
          expect(service.isConnected, isFalse);
          expect(servers.first.closedByClient, isTrue, reason: 'the abandoned socket is closed, not leaked');

          async.elapse(const Duration(seconds: 1));
          expect(servers, hasLength(2));
          servers[1].establish();
          async.flushMicrotasks();
          expect(servers[1].sentByClient.single['data'], {'channel': 'client-abc'});
          service.dispose();
        });
      });

      test('an answered ping keeps the connection', () {
        fakeAsync((async) {
          final (service, servers) = _connected();
          service.subscribe('client-abc');
          async.flushMicrotasks();
          servers.single.establish();
          async.flushMicrotasks();

          async.elapse(PushService.maxActivityTimeout);
          // ham2k-push's auto-response carries `data` as an object.
          servers.single.send('pusher:pong', data: <String, dynamic>{});
          async.elapse(PushService.pongTimeout);

          expect(service.isConnected, isTrue);
          expect(servers, hasLength(1));
          service.dispose();
        });
      });

      test('a dial never confirmed is abandoned and retried', () {
        // A network dropping packets holds a dial open on the OS's TCP
        // timeout — over a minute — with every subscription parked behind it.
        fakeAsync((async) {
          final (service, servers) = _connected();
          service.subscribe('client-abc');
          async.flushMicrotasks();

          async.elapse(PushService.connectTimeout);
          expect(servers.first.closedByClient, isTrue);
          async.elapse(const Duration(seconds: 1));
          expect(servers, hasLength(2));
          service.dispose();
        });
      });

      test('checkConnection pings at once and drops a connection that does not answer', () {
        // The app resuming: a suspended process can come back to a socket
        // that died while it slept, long before the next scheduled ping.
        fakeAsync((async) {
          final (service, servers) = _connected();
          service.subscribe('client-abc');
          async.flushMicrotasks();
          servers.single.establish();
          async.flushMicrotasks();
          servers.single.rawFromClient.clear();

          service.checkConnection();
          expect(servers.single.sentByClient.single['event'], 'pusher:ping');
          async.elapse(PushService.pongTimeout);
          expect(service.isConnected, isFalse);
          service.dispose();
        });
      });
    });

    group('reconnecting', () {
      test('a dropped connection reconnects with backoff and re-subscribes every channel', () {
        fakeAsync((async) {
          final (service, servers) = _connected();
          service.subscribe('client-abc');
          service.subscribe('account-def');
          async.flushMicrotasks();
          servers[0].establish();
          async.flushMicrotasks();

          servers[0].disconnect();
          async.flushMicrotasks();
          expect(servers, hasLength(1), reason: 'reconnect is scheduled, not immediate');
          async.elapse(const Duration(seconds: 1));
          expect(servers, hasLength(2));

          servers[1].establish();
          async.flushMicrotasks();
          expect(servers[1].sentByClient.map((m) => (m['data'] as Map)['channel']), containsAll(['client-abc', 'account-def']));
          service.dispose();
        });
      });

      test('backoff doubles on repeated drops', () {
        fakeAsync((async) {
          final (service, servers) = _connected();
          service.subscribe('client-abc');
          async.flushMicrotasks();

          for (final expectedDelay in [1, 2, 4]) {
            final countBefore = servers.length;
            servers.last.disconnect();
            async.elapse(Duration(seconds: expectedDelay) - const Duration(milliseconds: 1));
            expect(servers, hasLength(countBefore), reason: 'not yet — only $expectedDelay-1ms have elapsed');
            async.elapse(const Duration(milliseconds: 1));
            expect(servers, hasLength(countBefore + 1));
          }
          service.dispose();
        });
      });

      test('reconnectNow cuts a backoff short when the network returns', () {
        // Deep in backoff, a device back in coverage would otherwise stay
        // deaf for up to 30 seconds after everything else is working again.
        fakeAsync((async) {
          final (service, servers) = _connected();
          service.subscribe('client-abc');
          async.flushMicrotasks();
          for (var i = 0; i < 5; i++) {
            servers.last.disconnect();
            async.elapse(const Duration(seconds: 16));
          }
          final countBefore = servers.length;
          servers.last.disconnect();
          async.flushMicrotasks();

          service.reconnectNow();
          expect(servers, hasLength(countBefore + 1));
          service.dispose();
        });
      });

      test('unsubscribing sends pusher:unsubscribe and drops the channel from future resubscribes', () {
        fakeAsync((async) {
          final (service, servers) = _connected();
          service.subscribe('client-abc');
          async.flushMicrotasks();
          servers[0].establish();
          async.flushMicrotasks();
          servers[0].rawFromClient.clear();

          service.unsubscribe('client-abc');
          expect(servers[0].sentByClient, [
            {
              'event': 'pusher:unsubscribe',
              'data': {'channel': 'client-abc'},
            },
          ]);

          servers[0].disconnect();
          async.elapse(const Duration(seconds: 1));
          servers[1].establish();
          async.flushMicrotasks();
          expect(servers[1].sentByClient, isEmpty, reason: 'an unsubscribed channel is not resubscribed after reconnect');
          service.dispose();
        });
      });
    });

    test('a refused dial on the real socket raises nothing uncaught', () async {
      // The channel reports a failed dial twice: on its stream, which drives
      // the reconnect, and on its `ready` future. Unlistened, the second copy
      // reaches the zone, and ErrorPolicy reads it as an unknown fault — a
      // "Something went wrong" notice and an upload per attempt, for as long
      // as the device is offline.
      final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = closed.port;
      await closed.close();

      final uncaught = <Object>[];
      final service = runZonedGuarded(() {
        final service = PushService(host: '127.0.0.1:$port');
        service.subscribe('client-abc');
        return service;
      }, (error, _) => uncaught.add(error))!;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      service.dispose();

      expect(uncaught, isEmpty);
    });
  });
}
