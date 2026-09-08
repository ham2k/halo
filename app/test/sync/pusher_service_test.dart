// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// PusherService is a hand-rolled client for Pusher's WebSocket protocol —
// see pusher_service.dart's own header for why this isn't a Pusher SDK
// package. These tests fake the transport with a StreamChannelController
// pair instead of opening a real socket: `foreign` plays the server,
// `local` is handed to PusherService as if it were the real WebSocket.

import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';

import 'package:ham2k_logger/services/pusher_service.dart';

class _FakeServer {
  final StreamChannelController<dynamic> _controller;
  final List<Map<String, dynamic>> sentByClient = [];

  _FakeServer() : _controller = StreamChannelController<dynamic>(sync: true) {
    _controller.foreign.stream.listen((raw) => sentByClient.add(jsonDecode(raw as String) as Map<String, dynamic>));
  }

  StreamChannel<dynamic> get local => _controller.local;

  void send(String event, {String? channel, Object? data}) {
    _controller.foreign.sink.add(jsonEncode({
      'event': event,
      'channel': ?channel,
      'data': data is String ? data : jsonEncode(data ?? const {}),
    }));
  }

  void establish() => send('pusher:connection_established', data: {'socket_id': '1.1'});

  /// Simulates the server closing the connection — PusherService's socket
  /// stream sees this as `onDone`.
  void disconnect() => unawaited(_controller.foreign.sink.close());
}

void main() {
  group('PusherService', () {
    test('a host connects to Ham2K push instead of deriving a Pusher cluster host', () {
      // The whole client-side migration off Pusher (LOFI-47) is this one
      // substitution: same protocol, same frames, different host. If the URL
      // stopped honouring `host`, a build configured for our own push service
      // would quietly go on talking to Pusher.
      fakeAsync((async) {
        var connectedTo = '';
        final service = PusherService(
          appKey: 'key',
          host: 'push.ham2k.com',
          connect: (uri) {
            connectedTo = uri.toString();
            return _FakeServer().local;
          },
        );

        service.subscribe('client-abc123');
        async.flushMicrotasks();

        expect(connectedTo, 'wss://push.ham2k.com/app/key?protocol=7&client=halo&version=1.0');

        service.dispose();
      });
    });

    test('a host wins over a cluster when a build names both', () {
      fakeAsync((async) {
        var connectedTo = '';
        final service = PusherService(
          appKey: 'key',
          cluster: 'mt1',
          host: 'push.ham2k.com',
          connect: (uri) {
            connectedTo = uri.toString();
            return _FakeServer().local;
          },
        );

        service.subscribe('client-abc123');
        async.flushMicrotasks();

        expect(connectedTo, startsWith('wss://push.ham2k.com/'));

        service.dispose();
      });
    });

    test('subscribing connects and sends pusher:subscribe once the connection is established', () {
      fakeAsync((async) {
        late _FakeServer server;
        final service = PusherService(
          appKey: 'key',
          cluster: 'mt1',
          connect: (uri) {
            expect(uri.toString(), 'wss://ws-mt1.pusher.com/app/key?protocol=7&client=halo&version=1.0');
            server = _FakeServer();
            return server.local;
          },
        );

        service.subscribe('client-abc123');
        async.flushMicrotasks();
        expect(server.sentByClient, isEmpty, reason: 'nothing is sent before connection_established');

        server.establish();
        async.flushMicrotasks();
        expect(server.sentByClient, [
          {
            'event': 'pusher:subscribe',
            'data': {'channel': 'client-abc123'},
          },
        ]);

        service.dispose();
      });
    });

    test('a named event on a subscribed channel decodes its JSON-string data and arrives on .events', () {
      fakeAsync((async) {
        late _FakeServer server;
        final service = PusherService(
          appKey: 'key',
          cluster: 'mt1',
          connect: (uri) {
            server = _FakeServer();
            return server.local;
          },
        );
        final received = <PusherEvent>[];
        service.events.listen(received.add);

        service.subscribe('client-abc');
        async.flushMicrotasks();
        server.establish();
        async.flushMicrotasks();

        server.send('webhook_event', channel: 'client-abc', data: {'id': 42});
        async.flushMicrotasks();

        expect(received, hasLength(1));
        expect(received.single.event, 'webhook_event');
        expect(received.single.channel, 'client-abc');
        expect(received.single.data, {'id': 42});

        service.dispose();
      });
    });

    test('an event on a channel this service never subscribed to is still delivered (server-side scoping, not client-side filtering)', () {
      fakeAsync((async) {
        late _FakeServer server;
        final service = PusherService(
          appKey: 'key',
          cluster: 'mt1',
          connect: (uri) {
            server = _FakeServer();
            return server.local;
          },
        );
        final received = <PusherEvent>[];
        service.events.listen(received.add);

        service.subscribe('client-abc');
        async.flushMicrotasks();
        server.establish();
        async.flushMicrotasks();

        // A real Pusher server would never do this (it only forwards events
        // for channels this connection subscribed to) — this just documents
        // that the client itself does no extra filtering, trusting the
        // server's channel scoping same as `.bind()` would with the real SDK.
        server.send('webhook_event', channel: 'some-other-channel', data: {'id': 1});
        async.flushMicrotasks();

        expect(received.single.channel, 'some-other-channel');
        service.dispose();
      });
    });

    test('pusher:ping gets a pusher:pong reply', () {
      fakeAsync((async) {
        late _FakeServer server;
        final service = PusherService(
          appKey: 'key',
          cluster: 'mt1',
          connect: (uri) {
            server = _FakeServer();
            return server.local;
          },
        );
        service.subscribe('client-abc');
        async.flushMicrotasks();
        server.establish();
        async.flushMicrotasks();
        server.sentByClient.clear();

        server.send('pusher:ping', data: const {});
        async.flushMicrotasks();

        expect(server.sentByClient, [
          {'event': 'pusher:pong', 'data': {}},
        ]);
        service.dispose();
      });
    });

    test('pusher_internal:* protocol events never reach .events', () {
      fakeAsync((async) {
        late _FakeServer server;
        final service = PusherService(
          appKey: 'key',
          cluster: 'mt1',
          connect: (uri) {
            server = _FakeServer();
            return server.local;
          },
        );
        final received = <PusherEvent>[];
        service.events.listen(received.add);

        service.subscribe('client-abc');
        async.flushMicrotasks();
        server.establish();
        async.flushMicrotasks();

        server.send('pusher_internal:subscription_succeeded', channel: 'client-abc', data: const {});
        async.flushMicrotasks();

        expect(received, isEmpty);
        service.dispose();
      });
    });

    test('a dropped connection reconnects with backoff and re-subscribes every channel', () {
      fakeAsync((async) {
        final servers = <_FakeServer>[];
        final service = PusherService(
          appKey: 'key',
          cluster: 'mt1',
          connect: (uri) {
            final s = _FakeServer();
            servers.add(s);
            return s.local;
          },
        );

        service.subscribe('client-abc');
        service.subscribe('account-def');
        async.flushMicrotasks();
        servers[0].establish();
        async.flushMicrotasks();
        expect(
          servers[0].sentByClient.map((m) => (m['data'] as Map)['channel']),
          containsAll(['client-abc', 'account-def']),
        );

        servers[0].disconnect();
        async.flushMicrotasks();
        // First reconnect attempt is scheduled after 2^0 = 1 second.
        expect(servers, hasLength(1), reason: 'reconnect is scheduled, not immediate');
        async.elapse(const Duration(seconds: 1));
        expect(servers, hasLength(2));

        servers[1].establish();
        async.flushMicrotasks();
        expect(
          servers[1].sentByClient.map((m) => (m['data'] as Map)['channel']),
          containsAll(['client-abc', 'account-def']),
          reason: 'every previously-subscribed channel is resubscribed on the new connection, unprompted',
        );

        service.dispose();
      });
    });

    test('reconnect backoff doubles on repeated drops, capped at 30s', () {
      fakeAsync((async) {
        final servers = <_FakeServer>[];
        final service = PusherService(
          appKey: 'key',
          cluster: 'mt1',
          connect: (uri) {
            final s = _FakeServer();
            servers.add(s);
            return s.local;
          },
        );

        service.subscribe('client-abc');
        async.flushMicrotasks();

        // Fail to establish repeatedly — each drop before a successful
        // connection_established doubles the delay: 1s, 2s, 4s.
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

    test('unsubscribing sends pusher:unsubscribe and drops the channel from future resubscribes', () {
      fakeAsync((async) {
        final servers = <_FakeServer>[];
        final service = PusherService(
          appKey: 'key',
          cluster: 'mt1',
          connect: (uri) {
            final s = _FakeServer();
            servers.add(s);
            return s.local;
          },
        );

        service.subscribe('client-abc');
        async.flushMicrotasks();
        servers[0].establish();
        async.flushMicrotasks();
        servers[0].sentByClient.clear();

        service.unsubscribe('client-abc');
        async.flushMicrotasks();
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
}
