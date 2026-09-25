// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Dart→JS half of the webhook-token refresh: what `ensureLofiClientRegistered`
// actually puts on the wire.
//
// This boundary is untyped in both directions — the args map is JSON-encoded
// into `__polo.invokeHook`, and the extension reads `args?.refreshWebhookToken`.
// A renamed or misspelled key is therefore silently falsy on the far side, and
// the only symptom is that an hour-old webhook token goes into an OAuth
// `state` and the relay refuses the login. Nothing else in the suite looks at
// this map.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'package:ham2k_logger/services/extensions/extension_service.dart';

/// Records what reached `invokeHook`, and answers as the real hook does.
class _RecordingHost implements ExtensionHost {
  final calls = <({String method, Object? args})>[];

  @override
  Future<dynamic> invokeHook(String category, {String? key, required String method, Object? args, Duration timeout = const Duration(seconds: 10)}) async {
    calls.add((method: method, args: args));
    return {'push_channel_name': 'chan', 'webhook_client_token': 'signed--token'};
  }

  @override
  Future<List<Map<String, dynamic>>> invokeHookAll(
    String category, {
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
    bool partialOnTimeout = false,
  }) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ServiceWithHost extends ExtensionService {
  _ServiceWithHost(this.recordingHost);
  final _RecordingHost recordingHost;

  @override
  ExtensionHost? get host => recordingHost;
  @override
  Future<void> start() async {}
}

void main() {
  late _RecordingHost host;
  late _ServiceWithHost extensions;

  setUp(() {
    host = _RecordingHost();
    extensions = _ServiceWithHost(host);
  });

  test('an OAuth login asks the extension for a refreshed token, by that exact key', () async {
    final registration = await extensions.ensureLofiClientRegistered(refreshWebhookToken: true);

    expect(registration?.webhookClientToken, 'signed--token');
    expect(host.calls.single.method, 'ensureClientRegistered');
    // The literal the extension reads. Spelled out rather than compared to a
    // shared constant on purpose: a constant renamed on both sides at once
    // still passes, and the far side is a string lookup in JavaScript.
    expect(host.calls.single.args, {'refreshWebhookToken': true});
  });

  test('every other caller asks for the cache, so boot stays off the network', () async {
    // Default false is what keeps `push_channel_name` — which does not expire
    // — reachable at boot and on an operator-callsign change while offline. A
    // default flipped to true would put a round trip on both.
    await extensions.ensureLofiClientRegistered();

    expect(host.calls.single.args, {'refreshWebhookToken': false});
  });
}
