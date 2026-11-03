// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The services' account subscription: an `operation` push on the synced
// account's channel is what tells the sync loop to pull early. The engine's
// own tests call notifyRemoteChanged directly, so this is the one place the
// path from the socket to the engine is exercised.

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stream_channel/stream_channel.dart';

import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/push_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';

import '../support/halo_test_support.dart';

class _RecordingEngine extends SyncEngine {
  final List<String?> remoteChanges = [];

  _RecordingEngine(HaLoServices services)
    : super(operations: services.operations, qsos: services.qsos, transport: (_, _) async => const {}, settings: services.settings);

  @override
  void notifyRemoteChanged({String? operationUuid}) => remoteChanges.add(operationUuid);
}

class _Services extends HaLoServices {
  _Services(super.db, super.settings, {super.extensions, super.push});

  late final _engine = _RecordingEngine(this);

  @override
  _RecordingEngine get syncEngine => _engine;
}

void main() {
  late StreamChannelController<dynamic> server;
  late PushService push;
  late _Services services;

  void serverSends(String event, {required String channel, Object? data}) {
    server.foreign.sink.add(jsonEncode({'event': event, 'channel': channel, 'data': jsonEncode(data ?? const {})}));
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({'flutter.syncEnabled': true});
    final settings = SettingsService(await SharedPreferences.getInstance());
    server = StreamChannelController<dynamic>(sync: true);
    server.foreign.stream.listen((_) {});
    push = PushService(connect: (_) => server.local);
    services = _Services(HaLoDatabase(NativeDatabase.memory()), settings, extensions: ExtensionServiceWithFakeHost(), push: push);
    services.setAccountPushChannel('account-abc');
    server.foreign.sink.add(
      jsonEncode({
        'event': 'pusher:connection_established',
        'data': jsonEncode({'socket_id': '1.1'}),
      }),
    );
  });

  tearDown(() async {
    push.dispose();
    await services.db.close();
  });

  test('an operation push on the account channel reaches the sync loop, naming the operation', () async {
    serverSends('operation', channel: 'account-abc', data: {'uuid': 'op-1'});
    await pumpEventQueue();
    expect(services.syncEngine.remoteChanges, ['op-1']);
  });

  test('other events and other channels do not', () async {
    // `permission` and `account` are the Sync panel's; another channel is
    // another account's (or an operation's) news.
    serverSends('permission', channel: 'account-abc');
    serverSends('operation', channel: 'account-zzz', data: {'uuid': 'op-1'});
    await pumpEventQueue();
    expect(services.syncEngine.remoteChanges, isEmpty);
  });

  test('a uuid that is not a string still counts as a change, never as an error', () async {
    // A throwing cast here escapes the stream to the zone, where ErrorPolicy
    // reports every such push as an unknown fault.
    serverSends('operation', channel: 'account-abc', data: {'uuid': 42});
    await pumpEventQueue();
    expect(services.syncEngine.remoteChanges, [null]);
  });

  test('once the channel is cleared, its pushes are no longer acted on', () async {
    services.setAccountPushChannel(null);
    serverSends('operation', channel: 'account-abc', data: {'uuid': 'op-1'});
    await pumpEventQueue();
    expect(services.syncEngine.remoteChanges, isEmpty);
  });
}
