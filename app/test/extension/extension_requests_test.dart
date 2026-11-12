// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The rule every request the app makes FOR an extension is held to: a data
// file, a reference's outline. The install screen promises the operator an
// extension reaches nothing beyond what it lists, and an address the
// extension names is the extension reaching, whoever sends it. Each test
// sends through a client that records what reached the network; a refusal
// that still sends has refused nothing.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart' show ExtensionUrlRefusal;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ham2k_logger/services/extensions/extension_service.dart';

void main() {
  late List<({Uri url, bool guarded, String? authorization})> sent;
  late Map<String, http.Response> answers;

  setUp(() {
    sent = [];
    answers = {};
  });

  ExtensionClientFactory recording() =>
      ({required guarded}) => MockClient((request) async {
        sent.add((url: request.url, guarded: guarded, authorization: request.headers['Authorization']));
        return answers['${request.url}'] ?? http.Response('ok', 200);
      });

  Future<http.Response> get(ExtensionNetworkGrant grant, String url, {bool dataFile = false, Uri? named, Map<String, String> headers = const {}}) async {
    final client = ExtensionClient(grant, named: named, dataFile: dataFile, clients: recording(), onWeb: false);
    try {
      return await http.Response.fromStream(await client.send(http.Request('GET', Uri.parse(url))..headers.addAll(headers)));
    } finally {
      client.close();
    }
  }

  Matcher refused(ExtensionUrlRefusal reason) => throwsA(isA<ExtensionUrlRefused>().having((e) => e.reason, 'reason', reason));

  const llota = ExtensionNetworkGrant(extensionKey: 'k2hrc-llota', domains: ['llota.app']);

  test('an address the extension did not declare is refused before anything is sent', () async {
    await expectLater(get(llota, 'https://collector.example/lakes.csv?d=secret'), refused(ExtensionUrlRefusal.undeclared));
    expect(sent, isEmpty);
    await get(llota, 'https://llota.app/lakes.csv');
    expect(sent.single.url.host, 'llota.app');
  });

  test('plain http is refused, declared or not', () async {
    await expectLater(get(llota, 'http://llota.app/lakes.csv'), refused(ExtensionUrlRefusal.notHttps));
    expect(sent, isEmpty);
  });

  test('a plain-http host the Ham2K proxy fronts goes out through the proxy, never in the clear', () async {
    // Passed as https because the proxy carries it: sent as spelled, the
    // request the refusal admitted would cross the network unencrypted.
    const hub = ExtensionNetworkGrant(extensionKey: 'qso-parties', domains: ['qsopartyhub.com']);
    await get(hub, 'http://qsopartyhub.com/list.csv');
    answers['https://llota.app/hub'] = http.Response('', 302, headers: {'location': 'http://qsopartyhub.com/list.csv'});
    await get(llota, 'https://llota.app/hub');
    expect(sent.map((s) => '${s.url}'), [
      'https://services.ham2k.net/qsopartyhub.com/list.csv',
      'https://llota.app/hub',
      'https://services.ham2k.net/qsopartyhub.com/list.csv',
    ]);
  });

  test('the local network is reached only by naming the host, or in developer mode', () async {
    const wildcard = ExtensionNetworkGrant(extensionKey: 'w', domains: ['*']);
    await expectLater(get(wildcard, 'https://192.168.1.20/list.csv'), refused(ExtensionUrlRefusal.localNetwork));
    const named = ExtensionNetworkGrant(extensionKey: 'w', domains: ['192.168.1.20']);
    await get(named, 'https://192.168.1.20/list.csv');
    const developer = ExtensionNetworkGrant(extensionKey: 'w', domains: ['*'], developerMode: true);
    await get(developer, 'https://localhost/list.csv');
    expect(sent.map((s) => s.url.host), ['192.168.1.20', 'localhost']);
    // A named host is the consent, wherever the name resolves; a wildcard's
    // is judged again by what it resolves to.
    expect(sent.map((s) => s.guarded), [false, false]);
    await get(wildcard, 'https://example.org/list.csv');
    expect(sent.last.guarded, isTrue);
  });

  group('a data file', () {
    const anyFile = ExtensionNetworkGrant(extensionKey: 'ham2k-call-notes', domains: ['ham2k.com'], anyDataFileHost: true);

    test("may reach any public host under requiresAnyDataFileUrl, and nothing else's request may", () async {
      await get(anyFile, 'https://www.dropbox.com/s/notes.txt', dataFile: true);
      expect(sent.single.url.host, 'www.dropbox.com');
      await expectLater(get(anyFile, 'https://www.dropbox.com/s/notes.txt'), refused(ExtensionUrlRefusal.undeclared));
      await expectLater(get(llota, 'https://www.dropbox.com/s/notes.txt', dataFile: true), refused(ExtensionUrlRefusal.undeclared));
    });

    test('never reaches the local network on that grant', () async {
      await expectLater(get(anyFile, 'https://10.0.0.5/notes.txt', dataFile: true), refused(ExtensionUrlRefusal.localNetwork));
      expect(sent, isEmpty);
    });
  });

  test('the address the extension named is judged, not the form the app rewrote it to', () async {
    // A share link turned into its download form, a host sent through the
    // proxy: judged by the rewrite, the proxy's host would decide, not the
    // extension's grant.
    await get(llota, 'https://services.ham2k.net/llota.app/lakes.csv', named: Uri.parse('https://llota.app/lakes.csv'));
    expect(sent.single.url.host, 'services.ham2k.net');
    await expectLater(
      get(llota, 'https://services.ham2k.net/collector.example/x', named: Uri.parse('https://collector.example/x')),
      refused(ExtensionUrlRefusal.undeclared),
    );
  });

  group('a redirect', () {
    test('to another public https host is followed: the server chose it, not the extension', () async {
      answers['https://llota.app/lakes.csv'] = http.Response('', 302, headers: {'location': 'https://cdn.example/lakes.csv'});
      final response = await get(llota, 'https://llota.app/lakes.csv');
      expect(response.statusCode, 200);
      expect(sent.map((s) => '${s.url}'), ['https://llota.app/lakes.csv', 'https://cdn.example/lakes.csv']);
    });

    test('off https, or onto the local network, is refused at that hop', () async {
      answers['https://llota.app/a'] = http.Response('', 302, headers: {'location': 'http://llota.app/a'});
      answers['https://llota.app/b'] = http.Response('', 307, headers: {'location': 'https://192.168.1.1/admin'});
      await expectLater(get(llota, 'https://llota.app/a'), refused(ExtensionUrlRefusal.notHttps));
      await expectLater(get(llota, 'https://llota.app/b'), refused(ExtensionUrlRefusal.localNetwork));
      expect(sent.map((s) => s.url.host).toSet(), {'llota.app'});
    });

    test('carries no credential to another host', () async {
      answers['https://llota.app/lakes.csv'] = http.Response('', 302, headers: {'location': 'https://cdn.example/lakes.csv'});
      await get(llota, 'https://llota.app/lakes.csv', headers: {'Authorization': 'Bearer t'});
      expect(sent.map((s) => s.authorization), ['Bearer t', null]);
    });

    test('is followed only so far', () async {
      answers['https://llota.app/loop'] = http.Response('', 302, headers: {'location': 'https://llota.app/loop'});
      await expectLater(get(llota, 'https://llota.app/loop'), throwsA(isA<http.ClientException>()));
      expect(sent.length, 6);
    });
  });

  group('networkGrantFor', () {
    ExtensionService withExtensions(List<ExtensionInfo> available) => ExtensionService()..debugSetAvailableExtensions(available);

    ExtensionInfo info(String key, {List<String> domains = const [], bool anyDataFile = false}) =>
        ExtensionInfo(key: key, file: '$key.js', core: false, name: key, domains: domains, requiresAnyDataFileUrl: anyDataFile);

    test("reads a sub-extension's grant from the bundle that defines it", () {
      final service = withExtensions([
        info('ham2k-call-notes', domains: ['ham2k.com'], anyDataFile: true),
      ]);
      final grant = service.networkGrantFor('ham2k-call-notes_hams-of-note');
      expect(grant.domains, ['ham2k.com']);
      expect(grant.anyDataFileHost, isTrue);
    });

    test('gives an extension the app does not know nothing to reach', () {
      final grant = withExtensions([
        info('k2hrc-llota', domains: ['llota.app']),
      ]).networkGrantFor('someone-else');
      expect(grant.domains, isEmpty);
      expect(grant.anyDataFileHost, isFalse);
      expect(grant.refusal(Uri.parse('https://llota.app/lakes.csv')), ExtensionUrlRefusal.undeclared);
    });
  });

  group('a lookup photo', () {
    // Which source named a photo is lost in the merge, so the rule is the
    // host's: one some loaded extension declared already receives whatever
    // that extension sends it, and a request for a photo there tells it
    // nothing more.
    ExtensionService loaded(List<ExtensionInfo> available) => ExtensionService()
      ..debugSetAvailableExtensions(available)
      ..debugLoadedExtensionKeys = {for (final info in available) info.key};

    ExtensionInfo info(String key, List<String> domains) => ExtensionInfo(key: key, file: '$key.js', core: false, name: key, domains: domains);

    test("loads from a host a loaded extension declares, and asks for any other", () {
      final service = loaded([
        info('ham2k-qrz', ['xmldata.qrz.com', '*.qrzcq.com']),
      ]);
      expect(service.lookupPhoto('https://xmldata.qrz.com/p/w1aw.jpg'), LookupPhoto.loads);
      expect(service.lookupPhoto('https://img.qrzcq.com/w1aw.jpg'), LookupPhoto.loads);
      expect(service.lookupPhoto('https://collector.example/w1aw.jpg?seen=K1ABC'), LookupPhoto.asks);
    });

    test("a bare '*' is the declaring extension's consent, not every source's", () {
      final service = loaded([
        info('w1xyz-anything', ['*']),
      ]);
      expect(service.lookupPhoto('https://collector.example/w1aw.jpg'), LookupPhoto.asks);
    });

    test("an extension that is not running vouches for nothing", () {
      final service = ExtensionService()
        ..debugSetAvailableExtensions([
          info('ham2k-qrz', ['xmldata.qrz.com']),
        ]);
      expect(service.lookupPhoto('https://xmldata.qrz.com/p/w1aw.jpg'), LookupPhoto.asks);
    });

    test('never fetches plain http or the local network, even when asked', () {
      final service = loaded([
        info('w1xyz-gear', ['192.168.1.20', 'photos.example']),
      ]);
      expect(service.lookupPhoto('http://photos.example/w1aw.jpg'), LookupPhoto.refused);
      expect(service.lookupPhoto('https://192.168.1.20/w1aw.jpg'), LookupPhoto.refused);
      expect(service.lookupPhoto('not a url'), LookupPhoto.refused);
    });
  });

  group('an OAuth sign-in', () {
    // The app runs the sign-in for the extension: it fetches the issuer's
    // discovery document, opens the browser on the authorization endpoint and
    // posts the code to the token endpoint. Each is the extension reaching,
    // so each is held to what it declared.
    const sota = ExtensionNetworkGrant(extensionKey: 'ham2k-sota', domains: ['sso.sota.org.uk', 'api-db2.sota.org.uk']);
    const issuer = 'https://sso.sota.org.uk/auth/realms/SOTA';
    Map<String, dynamic> discovery({String issuer = issuer, String? authorization, String? token}) => {
      'issuer': issuer,
      'authorization_endpoint': authorization ?? '$issuer/protocol/openid-connect/auth',
      'token_endpoint': token ?? '$issuer/protocol/openid-connect/token',
    };

    test('takes an issuer and endpoints on declared hosts', () {
      checkedOAuthUrl(issuer, sota);
      final endpoints = oauthEndpointsFrom(issuer: issuer, discovery: discovery(), grant: sota);
      expect(endpoints.token.host, 'sso.sota.org.uk');
    });

    test('refuses an issuer the extension did not declare', () {
      expect(() => checkedOAuthUrl('https://login.example/realms/x', sota), throwsA(isA<ExtensionUrlRefused>()));
    });

    test("refuses a discovery document naming an endpoint the operator never saw, or a sign-in page that is not one", () {
      expect(
        () => oauthEndpointsFrom(
          issuer: issuer,
          discovery: discovery(token: 'https://collector.example/token'),
          grant: sota,
        ),
        throwsA(isA<ExtensionUrlRefused>().having((e) => e.reason, 'reason', ExtensionUrlRefusal.undeclared)),
      );
      for (final page in ['javascript:alert(1)', 'file:///etc/passwd', 'http://sso.sota.org.uk/auth']) {
        expect(
          () => oauthEndpointsFrom(
            issuer: issuer,
            discovery: discovery(authorization: page),
            grant: sota,
          ),
          throwsA(isA<ExtensionUrlRefused>()),
          reason: page,
        );
      }
    });

    test("refuses a discovery document served for another issuer", () {
      expect(
        () => oauthEndpointsFrom(
          issuer: issuer,
          discovery: discovery(issuer: 'https://sso.sota.org.uk/auth/realms/other'),
          grant: sota,
        ),
        throwsA(isA<FormatException>()),
      );
      oauthEndpointsFrom(issuer: '$issuer/', discovery: discovery(), grant: sota);
    });
  });
}
