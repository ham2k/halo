// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `ExtensionHost.start(httpClient: …)` — the seam for testing anything an
// extension fetches.
//
// Before it, `_HostCore` answered `host.fetch` itself in both isolate and
// in-process modes, so nothing could observe an extension's requests or answer
// them: every spot feed and every spot post in the codebase was untestable.
//
// The seam sits deliberately BELOW the interesting code. The manifest
// allowlist, the https requirement, the canonical User-Agent and both timeouts
// all still run, so a test exercises the real path — and a stub cannot become a
// way to route around any of them.
//
// POTA is the vehicle: it ships in the app, and it both reads a spot feed and
// posts to one.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final assets = Directory('../../app/assets/extensions');
  File bundle(String key) => File('${assets.path}/$key.js');
  bool bundlesMissing() => !bundle('kernel').existsSync() || !bundle('pota').existsSync();

  ({List<http.Request> sent, MockClient client}) recorder(String body, {int status = 200}) {
    final sent = <http.Request>[];
    return (
      sent: sent,
      client: MockClient((request) async {
        sent.add(request);
        return http.Response(body, status, headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );
  }

  Future<ExtensionHost> hostWith(http.Client client, {List<String> domains = const ['api.pota.app', 'pota.app']}) async {
    final host = await ExtensionHost.start(
      kernelSource: bundle('kernel').readAsStringSync(),
      extensions: [ExtensionBundle(key: 'pota', source: bundle('pota').readAsStringSync())],
      fetchAllowlists: {'pota': domains},
      httpClient: client,
      userAgent: 'Ham2K-Test/1.0',
      onHostCall: (method, params) async => null,
    );
    addTearDown(host.dispose);
    return host;
  }

  test('a stubbed client answers what an extension fetches', () async {
    if (bundlesMissing()) {
      markTestSkipped('bundles not built — run `npm run build` in extensions/ first');
      return;
    }
    final rec = recorder('[{"spotId":1,"activator":"W1AW","frequency":"14285","mode":"SSB",'
        '"reference":"US-0001","name":"Acadia","locationDesc":"US-ME",'
        '"spotTime":"2026-07-01T12:00:00","spotter":"K2ABC","comments":"","source":"Web","count":1}]');
    final host = await hostWith(rec.client);

    final spots = (await host.invokeHook('spots', key: 'pota', method: 'fetchSpots',
        args: {'online': true}, timeout: const Duration(seconds: 20)) as List).cast<Map>();

    expect(spots.single['freq'], 14285);
    expect((spots.single['their'] as Map)['call'], 'W1AW');
    expect(rec.sent.single.url.host, 'api.pota.app');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('the request is observable, so a POST body can be asserted', () async {
    if (bundlesMissing()) {
      markTestSkipped('bundles not built');
      return;
    }
    // This is the capability that matters: a wrong payload is otherwise
    // invisible until somebody notices spots not appearing.
    final rec = recorder('{}');
    final host = await hostWith(rec.client);

    final result = await host.invokeHook('spots', key: 'pota', method: 'postSelfSpot', args: {
      'operation': {'stationCall': 'W1AW', 'refs': [{'type': 'potaActivation', 'ref': 'US-0001'}]},
      'freq': 14285,
      'mode': 'SSB',
    }, timeout: const Duration(seconds: 20)) as Map;

    expect(result['ok'], true);
    final body = jsonDecode(rec.sent.single.body) as Map<String, dynamic>;
    expect(body['activator'], 'W1AW');
    expect(body['reference'], 'US-0001');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('the canonical User-Agent is still stamped', () async {
    if (bundlesMissing()) {
      markTestSkipped('bundles not built');
      return;
    }
    // Proof the seam is below the host's own behaviour rather than replacing
    // it: an extension cannot become anonymous by being tested.
    final rec = recorder('[]');
    final host = await hostWith(rec.client);
    await host.invokeHook('spots', key: 'pota', method: 'fetchSpots',
        args: {'online': true}, timeout: const Duration(seconds: 20));

    expect(rec.sent.single.headers['User-Agent'], 'Ham2K-Test/1.0');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('the manifest allowlist still blocks, stub or no stub', () async {
    if (bundlesMissing()) {
      markTestSkipped('bundles not built');
      return;
    }
    final rec = recorder('[]');
    final host = await hostWith(rec.client, domains: const []);

    await expectLater(
      host.invokeHook('spots', key: 'pota', method: 'fetchSpots',
          args: {'online': true}, timeout: const Duration(seconds: 20)),
      throwsA(anything),
    );
    expect(rec.sent, isEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
