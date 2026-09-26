// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The catalog client is asked questions in the background, so its traps are
// the quiet ones: a callsign leaking into a query, one broken entry costing
// the operator the whole list, a dead catalog turning into an operator
// notice, bytes that do not match the listing reaching the zip decoder, an
// `http://` bundle sneaking through under the developer override, and a
// stamp or a cache following developer time travel.

import 'dart:async';
import 'dart:convert';
import 'dart:io' show HandshakeException, SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart' show AppClock, realNowMillis;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart' show t;
import 'package:ham2k_logger/services/extensions/catalog_service.dart';
import 'package:ham2k_logger/services/error_reporting_service.dart';
import 'package:ham2k_logger/services/extensions/extension_relevance.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/extensions/installed_extensions.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';

import '../support/error_reporting_fakes.dart';

const _sha = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'; // sha256("abc")

Map<String, Object?> _entry({
  String key = 'k2hrc-llota',
  String name = 'LLOTA',
  String version = '1.2.0',
  String sha256 = _sha,
  Object? bundleUrl = 'https://catalog.ham2k.net/api/v1/extensions/k2hrc-llota/versions/1.2.0/bundle',
  Map<String, Object?>? relevance,
  Map<String, Object?> extra = const {},
}) => {'key': key, 'name': name, 'version': version, 'sha256': sha256, 'bundleUrl': bundleUrl, 'category': 'activity', 'relevance': ?relevance, ...extra};

String _catalog(List<Object?> entries) => jsonEncode({'generatedAt': '2026-09-07T05:00:00Z', 'channel': 'stable', 'api': 1, 'extensions': entries});

ExtensionInfo _installed(String key, String version, {String? name}) =>
    ExtensionInfo(key: key, file: 'index.js', core: false, name: name ?? key, source: ExtensionSource.installed, version: version);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeErrorReportingBackend backend;
  setUp(() {
    backend = FakeErrorReportingBackend();
    ErrorReportingService.resetFailureStreaks();
  });
  tearDown(() {
    ErrorReportingService.resetFailureStreaks();
    AppClock.instance.reset();
  });

  CatalogService service(
    Future<http.Response> Function(http.Request) handler, {
    SettingsService? settings,
    Duration? requestTimeout,
    Duration? downloadTimeout,
  }) => CatalogService(
    client: MockClient(handler),
    settings: settings,
    userAgent: () async => 'Ham2K Logger/test',
    locale: () => 'es',
    requestTimeout: requestTimeout ?? kCatalogRequestTimeout,
    downloadTimeout: downloadTimeout ?? kCatalogDownloadTimeout,
  );

  Future<SettingsService> settingsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SettingsService(await SharedPreferences.getInstance());
  }

  group('fetchCatalog', () {
    test('the query carries the channel, the api, the language and ONLY the geo values known', () async {
      // Never the callsign, and never an empty parameter for an unknown
      // value: to the catalog `country=` is a country, absent is unknown.
      final urls = <Uri>[];
      final catalog = service((request) async {
        urls.add(request.url);
        return http.Response(_catalog([]), 200);
      });

      await catalog.fetchCatalog(
        geo: const OperatorGeo(entityPrefix: 'K', continent: 'NA'),
      );
      expect(urls.single.path, '/api/v1/catalog');
      expect(urls.single.queryParameters, {'channel': 'stable', 'entity': 'K', 'continent': 'NA', 'api': '$kExtensionApiVersion', 'lang': 'es'});
      expect(urls.single.host, 'catalog.ham2k.net');

      catalog.invalidate();
      await catalog.fetchCatalog();
      expect(urls.last.queryParameters.keys, isNot(anyOf(contains('entity'), contains('country'))));
    });

    test('sends the canonical User-Agent', () async {
      late Map<String, String> headers;
      final catalog = service((request) async {
        headers = request.headers;
        return http.Response(_catalog([]), 200);
      });
      await catalog.fetchCatalog();
      expect(headers['User-Agent'], 'Ham2K Logger/test');
    });

    test('a malformed entry is dropped, never the list', () async {
      // The alternative reads as an empty catalog, which is indistinguishable
      // from a catalog with nothing in it — over one publisher's typo.
      final catalog = service(
        (_) async => http.Response(
          _catalog([
            _entry(key: 'good-one', name: 'Good'),
            _entry(key: 'NOT A KEY'),
            _entry(key: 'no-hash', sha256: 'deadbeef'),
            _entry(key: 'no-bundle', bundleUrl: 'not a url'),
            _entry(key: 'no-version', version: ''),
            'a string where an object should be',
            null,
            _entry(key: 'also-good', name: 'Also good'),
          ]),
          200,
        ),
      );

      final entries = await catalog.fetchCatalog();
      expect(entries!.map((e) => e.key), ['good-one', 'also-good']);
    });

    test('a non-200 answers null and reports nothing', () async {
      await withErrorHooks(() async {
        final catalog = service((_) async => http.Response('nope', 503));
        expect(await catalog.fetchCatalog(), isNull);
        expect(backend.exceptions, isEmpty);
      }, backend: backend);
    });

    test('a 200 that is not JSON answers null and is reported at once', () async {
      // Something published a broken response: a defect on the first
      // occurrence, not a flaky network to wait out.
      await withErrorHooks(() async {
        final catalog = service((_) async => http.Response('<html>maintenance</html>', 200));
        expect(await catalog.fetchCatalog(), isNull);
        expect(backend.exceptions, hasLength(1));
        expect(backend.exceptions.single.error, isA<FormatException>());
      }, backend: backend);
    });

    test('not being answered is reported only as a streak, and an answer resets it', () async {
      // Two failures, an answer, two failures: never three IN A ROW, so
      // nothing is uploaded. Without recordSuccess on the answer, the fourth
      // failure is the third of a streak and reports.
      await withErrorHooks(() async {
        var fail = true;
        final catalog = service((_) async {
          if (fail) throw http.ClientException('connection refused');
          return http.Response(_catalog([]), 200);
        });
        Future<void> attempt() async {
          catalog.invalidate();
          await catalog.fetchCatalog();
        }

        await attempt();
        await attempt();
        fail = false;
        await attempt();
        fail = true;
        await attempt();
        await attempt();
        expect(backend.exceptions, isEmpty);

        await attempt();
        expect(backend.exceptions, hasLength(1));
        // What reaches the policy is the wrapper, whose rule keeps it off the
        // operator's screen; a bare ClientException would too, a bare
        // TimeoutException would not.
        expect(backend.exceptions.single.error, isA<CatalogUnreachable>());
      }, backend: backend);
    });

    test('a timeout is the same streak as a refused connection', () async {
      await withErrorHooks(() async {
        final catalog = service((_) => Completer<http.Response>().future, requestTimeout: const Duration(milliseconds: 20));
        for (var i = 0; i < 3; i++) {
          catalog.invalidate();
          expect(await catalog.fetchCatalog(), isNull);
        }
        expect(backend.exceptions, hasLength(1));
        expect((backend.exceptions.single.error as CatalogUnreachable).cause, isA<TimeoutException>());
      }, backend: backend);
    });

    test('a TLS or socket failure below package:http is the same streak — never loud', () async {
      // IOClient hands a handshake or socket failure up unwrapped, so
      // catching ClientException alone lets it escape the unattended check
      // as a bare exception the policy would notify the operator about.
      await withErrorHooks(() async {
        for (final failure in [HandshakeException('tls'), const SocketException('reset')]) {
          ErrorReportingService.resetFailureStreaks();
          backend.exceptions.clear();
          final catalog = service((_) async => throw failure);
          for (var i = 0; i < 3; i++) {
            catalog.invalidate();
            expect(await catalog.fetchCatalog(), isNull, reason: '$failure');
          }
          expect(backend.exceptions, hasLength(1), reason: '$failure');
          final reported = backend.exceptions.single.error;
          expect(reported, isA<CatalogUnreachable>(), reason: '$failure');
          expect((reported as CatalogUnreachable).cause, same(failure));
        }
      }, backend: backend);
    });

    test('answers from its cache for a while, judged on the REAL clock', () async {
      // The TTL mirrors the catalog's own max-age, which is real seconds
      // (time.md §1, category 2). Travelled a month forward, a cache on the
      // app clock would have expired and asked again.
      var requests = 0;
      final catalog = service((_) async {
        requests++;
        return http.Response(_catalog([_entry()]), 200);
      });
      await catalog.fetchCatalog();
      AppClock.instance.travel(delta: const Duration(days: 30));
      await catalog.fetchCatalog();
      expect(requests, 1);
    });

    test('a caller that IS the operator asking goes past the cache', () async {
      // Opening the Extensions panel. A listing from four minutes ago predates
      // whatever they opened it to look for — which, for somebody who has just
      // been told an update exists, is the update.
      var requests = 0;
      final catalog = service((_) async {
        requests++;
        return http.Response(_catalog([_entry()]), 200);
      });
      await catalog.fetchCatalog();
      await catalog.fetchCatalog(force: true);
      expect(requests, 2);
      // And the answer is remembered, so the rest of that opening is free.
      await catalog.fetchCatalog();
      expect(requests, 2);
    });
  });

  group('checkUpdates', () {
    test('sends only the installed store\'s extensions, and nothing when there are none', () async {
      final bodies = <Map<String, dynamic>>[];
      final catalog = service((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(jsonEncode({'updates': [], 'revoked': [], 'ignored': []}), 200);
      });
      const builtIn = ExtensionInfo(key: 'pota', file: 'pota.js', core: false, name: 'POTA', version: '9.9.9');

      // A built-in is not the catalog's to update, and a request naming one
      // would report a "withdrawn" release for every key the app ships.
      final result = await catalog.checkUpdates([builtIn, _installed('k2hrc-llota', '1.0.0')]);
      expect(result, isNotNull);
      expect(bodies.single['channel'], 'stable');
      expect(bodies.single['installed'], [
        {'key': 'k2hrc-llota', 'version': '1.0.0'},
      ]);

      // Nothing installed: no request at all — what keeps every fresh
      // install and every developer build quiet.
      expect(await catalog.checkUpdates([builtIn]), isNull);
      expect(bodies, hasLength(1));
    });

    test('reads updates, revocations and the ignored list', () async {
      final catalog = service(
        (_) async => http.Response(
          jsonEncode({
            'updates': [
              {..._entry(version: '1.3.0'), 'installedStatus': 'withdrawn'},
              {'key': 'broken'},
            ],
            'revoked': [
              {'key': 'k2hrc-llota', 'version': '1.0.0', 'note': 'leaks the log'},
            ],
            'ignored': [
              {'key': 'odd-one', 'reason': 'unparseable'},
            ],
          }),
          200,
        ),
      );
      final result = (await catalog.checkUpdates([_installed('k2hrc-llota', '1.0.0')]))!;
      expect(result.updates.single.entry.version, '1.3.0');
      expect(result.updates.single.installedStatus, 'withdrawn');
      expect(result.revoked.single.note, 'leaks the log');
      expect(result.ignored.single.reason, 'unparseable');
    });
  });

  group('download', () {
    test('bytes that do not hash to the listing are refused BEFORE anything opens them', () async {
      // The body is not a zip. If the archive were sniffed first, the reason
      // would be notAnArchive; hashMismatch proves the hash came first.
      final catalog = service((_) async => http.Response('not the bytes the listing promised', 200));
      final entry = CatalogEntry.fromJson(_entry())!;
      await expectLater(catalog.download(entry.release), throwsA(isA<BundleException>().having((e) => e.reason, 'reason', BundleRejection.hashMismatch)));
    });

    test('bytes that match come back whole', () async {
      final catalog = service((_) async => http.Response('abc', 200));
      expect(await catalog.download(CatalogEntry.fromJson(_entry())!.release), utf8.encode('abc'));
    });

    test('a version off the extension\'s listing carries its own hash', () async {
      final catalog = service((request) async {
        if (request.url.path == '/api/v1/extensions/k2hrc-llota') {
          return http.Response(
            jsonEncode({
              'key': 'k2hrc-llota',
              'versions': [
                {'version': '1.2.0', 'api': 1, 'sha256': _sha, 'size': 3},
                {'version': '1.1.0', 'api': 1, 'sha256': 'f' * 64, 'size': 3},
              ],
            }),
            200,
          );
        }
        return http.Response('abc', 200);
      });
      final listing = (await catalog.fetchExtension('k2hrc-llota'))!;
      CatalogRelease release(String version) =>
          (key: 'k2hrc-llota', version: version, sha256: listing.versionNamed(version)!.sha256, bundleUrl: catalog.bundleUrlFor('k2hrc-llota', version));
      expect(await catalog.download(release('1.2.0')), utf8.encode('abc'));
      // The same bytes against the other version's hash: refused.
      await expectLater(catalog.download(release('1.1.0')), throwsA(isA<BundleException>().having((e) => e.reason, 'reason', BundleRejection.hashMismatch)));
      expect(listing.versionNamed('3.0.0'), isNull);
    });

    test('a version the cached listing lacks is read again past the cache, once', () async {
      // A deep link can name a release published inside the five minutes the
      // listing answers from memory; refused on the cached page, the
      // catalog's own link would not install. Without the re-read, the
      // second call answers from the cache and never sees 1.3.0.
      var served = ['1.2.0'];
      var requests = 0;
      final catalog = service((request) async {
        requests++;
        return http.Response(
          jsonEncode({
            'key': 'k2hrc-llota',
            'versions': [
              for (final v in served) {'version': v, 'sha256': _sha},
            ],
          }),
          200,
        );
      });
      expect((await catalog.fetchExtension('k2hrc-llota'))!.versionNamed('1.3.0'), isNull);
      served = ['1.2.0', '1.3.0'];
      expect((await catalog.fetchExtension('k2hrc-llota', expecting: '1.3.0'))!.versionNamed('1.3.0'), isNotNull);
      expect(requests, 2);
      // A version the cache does hold is not a reason to ask again.
      await catalog.fetchExtension('k2hrc-llota', expecting: '1.2.0');
      expect(requests, 2);
    });

    test('a host that never answers, or cannot be reached, is a refusal the flow shows — not a defect', () async {
      // The install flow reports anything but a BundleException as a defect
      // and shows its toString. A dead link is neither: it is a sentence
      // about this link, on the same footing as an unreadable file.
      await withErrorHooks(() async {
        final stalled = service((_) => Completer<http.Response>().future, downloadTimeout: const Duration(milliseconds: 20));
        await expectLater(
          stalled.downloadBundle(Uri.parse('https://example.org/a.h2kext')),
          throwsA(
            isA<BundleException>()
                .having((e) => e.reason, 'reason', BundleRejection.downloadFailed)
                .having((e) => e.message, 'message', t.extensionsPanel.downloadUnreachable(source: 'example.org')),
          ),
        );
        for (final failure in [http.ClientException('refused'), HandshakeException('tls')]) {
          final dead = service((_) async => throw failure);
          await expectLater(
            dead.downloadBundle(Uri.parse('https://example.org/a.h2kext')),
            throwsA(isA<BundleException>().having((e) => e.reason, 'reason', BundleRejection.downloadFailed)),
            reason: '$failure',
          );
        }
        final refused = service((_) async => http.Response('', 404));
        await expectLater(
          refused.downloadBundle(Uri.parse('https://example.org/a.h2kext')),
          throwsA(isA<BundleException>().having((e) => e.reason, 'reason', BundleRejection.downloadFailed)),
        );
        expect(backend.exceptions, isEmpty);
      }, backend: backend);
    });

    test('a redirect off https is refused, whatever it leads to', () async {
      // The rule the deep-link router's plain download shared: a client following
      // redirects itself walks https into http and hands the result back as
      // though it were the URL asked for.
      final catalog = service((request) async {
        if (request.url.host == 'example.org') {
          return http.Response('', 302, headers: {'location': 'http://example.org/plain.h2kext'});
        }
        return http.Response('abc', 200);
      });
      await expectLater(
        catalog.downloadBundle(Uri.parse('https://example.org/a.h2kext')),
        throwsA(isA<BundleException>().having((e) => e.reason, 'reason', BundleRejection.notAnArchive)),
      );
    });

    test('the developer override allows http only for loopback, and only while developer mode is on', () async {
      Future<void> expectRefused(CatalogService catalog, String url) =>
          expectLater(catalog.downloadBundle(Uri.parse(url)), throwsA(isA<BundleException>().having((e) => e.reason, 'reason', BundleRejection.notAnArchive)));
      Future<http.Response> serve(http.Request request) async => http.Response('abc', 200);

      // Typed with a trailing slash, as addresses are pasted: kept, it
      // would put `//api/v1/...` on every request.
      final dev = await settingsWith({'developerMode': true, 'catalogBaseUrl': 'http://localhost:8787/'});
      final overridden = service(serve, settings: dev);
      expect(overridden.baseUrl, 'http://localhost:8787');
      expect(overridden.host, 'localhost');
      expect(overridden.bundleUrlFor('a', '1.0.0').path, '/api/v1/extensions/a/versions/1.0.0/bundle');
      expect(await overridden.downloadBundle(Uri.parse('http://localhost:8787/b')), utf8.encode('abc'));
      expect(await overridden.downloadBundle(Uri.parse('http://127.0.0.1:8787/b')), utf8.encode('abc'));
      // A LAN address over http is exactly the rewrite https rules out — and
      // it is said as such, not as a redirect that never happened.
      await expectRefused(overridden, 'http://192.168.1.20:8787/b');
      await expectLater(
        overridden.downloadBundle(Uri.parse('http://192.168.1.20:8787/b')),
        throwsA(isA<BundleException>().having((e) => e.message, 'message', t.extensionsPanel.downloadNotHttps)),
      );
      await expectRefused(overridden, 'http://catalog.ham2k.net/b');

      // The address alone is not enough: developer mode off returns the app
      // to the real catalog, and loopback over http with it.
      final notDev = await settingsWith({'developerMode': false, 'catalogBaseUrl': 'http://localhost:8787'});
      final plain = service(serve, settings: notDev);
      expect(plain.baseUrl, kCatalogBaseUrl);
      await expectRefused(plain, 'http://localhost:8787/b');
    });
  });

  group('catalog URLs', () {
    test('a catalog link is one on the catalog in force — the override displaces the built-in host', () async {
      final plain = service((_) async => http.Response('', 404));
      expect(plain.isCatalogUrl(Uri.parse('https://catalog.ham2k.net/api/v1/extensions/a/versions/1.0.0/bundle')), isTrue);
      expect(plain.isCatalogUrl(Uri.parse('https://example.org/a.h2kext')), isFalse);
      expect(plain.isCatalogUrl(Uri.parse('http://localhost:8787/api/v1/extensions/a/versions/1.0.0/bundle')), isFalse);
      expect(plain.isCatalogUrl(Uri.parse('file:///tmp/a.h2kext')), isFalse);

      // Under the override, a production link is NOT a catalog link: routed
      // through the verified path it would be resolved against the local
      // catalog's listings, which never served it. It takes the plain path,
      // where the https rule judges it like any other host.
      final dev = await settingsWith({'developerMode': true, 'catalogBaseUrl': 'http://localhost:8787'});
      final overridden = service((_) async => http.Response('', 404), settings: dev);
      expect(overridden.isCatalogUrl(Uri.parse('http://localhost:8787/api/v1/extensions/a/versions/1.0.0/bundle')), isTrue);
      expect(overridden.isCatalogUrl(Uri.parse('https://catalog.ham2k.net/x')), isFalse);
    });

    test('a bundle path names its key and version, and nothing else parses', () {
      expect(CatalogService.parseBundleUrl(Uri.parse('https://catalog.ham2k.net/api/v1/extensions/k2hrc-llota/versions/1.2.0-beta.1/bundle')), (
        key: 'k2hrc-llota',
        version: '1.2.0-beta.1',
      ));
      expect(CatalogService.parseBundleUrl(Uri.parse('https://catalog.ham2k.net/api/v1/extensions/k2hrc-llota')), isNull);
      expect(CatalogService.parseBundleUrl(Uri.parse('https://catalog.ham2k.net/extensions/k2hrc-llota')), isNull);
    });
  });

  group('the unattended update check', () {
    late StatusBarService statusBar;
    late SettingsService settings;
    late int applied;
    late int opened;
    late List<List<String>> updatedAll;
    late List<Set<String>> namedAll;

    /// The check is behind the `catalog` experiment; on by default here so
    /// every test below is about the check itself.
    Future<CatalogUpdateCheck> checker(
      Future<http.Response> Function(http.Request) handler, {
      List<ExtensionInfo>? installed,
      bool Function(ExtensionInfo)? inUse,
      Map<String, Object> prefs = const {},
      int Function()? realNow,
      bool experiment = true,
    }) async {
      settings = await settingsWith(prefs);
      if (experiment) await settings.setExperimentEnabled('catalog', true);
      statusBar = StatusBarService(settings.prefs);
      applied = 0;
      opened = 0;
      updatedAll = [];
      namedAll = [];
      return CatalogUpdateCheck(
        catalog: service(handler),
        settings: settings,
        statusBar: statusBar,
        installed: () => installed ?? [_installed('k2hrc-llota', '1.0.0', name: 'LLOTA')],
        inUse: inUse,
        applyAvailability: () async => applied++,
        openExtensions: () => opened++,
        updateAll: (entries, named) async {
          updatedAll.add([for (final entry in entries) entry.key]);
          namedAll.add(named);
        },
        realNow: realNow,
      );
    }

    http.Response answer({List<Object?> updates = const [], List<Object?> revoked = const []}) =>
        http.Response(jsonEncode({'updates': updates, 'revoked': revoked, 'ignored': []}), 200);

    Iterable<StatusBarNotice> notices(String key) => statusBar.activeNotices.where((n) => n.key == key);

    test('one update is named; several are counted; the row badge knows the key', () async {
      final check = await checker((_) async => answer(updates: [_entry(version: '1.1.0')]));
      expect(await check.check(), isTrue);
      expect(notices(CatalogUpdateCheck.noticeKey).single.text, 'An update is available for LLOTA.');
      expect(check.pendingUpdates.keys, ['k2hrc-llota']);
      // Non-persistent: the next launch checks again, and an update taken in
      // between must not leave a stale notice in the footer.
      expect(notices(CatalogUpdateCheck.noticeKey).single.persist, isFalse);

      final two = await checker(
        (_) async => answer(
          updates: [
            _entry(version: '1.1.0'),
            _entry(key: 'other-one', version: '2.0.0'),
          ],
        ),
        installed: [
          _installed('k2hrc-llota', '1.0.0', name: 'LLOTA'),
          _installed('other-one', '1.0.0', name: 'Other One'),
        ],
      );
      await two.check();
      // Two names is still a sentence; the count is what a third would cost.
      expect(notices(CatalogUpdateCheck.noticeKey).single.text, 'LLOTA, Other One need updating.');
    });

    test('past two, the notice names two and counts the rest', () async {
      // A notice is read at a glance from the footer. Listing every name turns
      // it into a list, and the button below it is what the list was for.
      final many = await checker(
        (_) async => answer(
          updates: [
            _entry(version: '1.1.0'),
            _entry(key: 'other-one', version: '2.0.0'),
            _entry(key: 'third-one', version: '3.0.0'),
          ],
        ),
        installed: [
          _installed('k2hrc-llota', '1.0.0', name: 'LLOTA'),
          _installed('other-one', '1.0.0', name: 'Other One'),
          _installed('third-one', '1.0.0', name: 'Third One'),
        ],
      );
      await many.check();
      expect(notices(CatalogUpdateCheck.noticeKey).single.text, 'LLOTA, Other One and 1 more need updating.');
      // The counted one is not named, so Update all must still confirm it.
      notices(CatalogUpdateCheck.noticeKey).single.actions.last.onTap();
      await pumpEventQueue();
      expect(namedAll.single, {'k2hrc-llota', 'other-one'});
    });

    test('the notice carries a way to the panel that can act on it', () async {
      // Without it the notice reports a job and leaves the operator to find
      // where it is done — which is the Extensions panel, several taps into
      // Settings.
      final one = await checker((_) async => answer(updates: [_entry(version: '1.1.0')]));
      await one.check();
      final action = notices(CatalogUpdateCheck.noticeKey).single.actions.first;
      expect(action.label, 'More info');
      expect(action.primary, isFalse);
      action.onTap();
      expect(opened, 1);
      // And it takes itself down on the way: the panel it opened IS the
      // detail, and a notice still in the footer behind it asks twice for
      // something already being answered.
      expect(notices(CatalogUpdateCheck.noticeKey), isEmpty);
    });

    test('the notice can take the updates where it stands', () async {
      // The job the notice reports is one press from done, and sending the
      // operator several taps into Settings to press the same button there is
      // the app making work. It is the primary, so it sits on the trailing
      // edge apart from More info.
      final check = await checker((_) async => answer(updates: [_entry(version: '1.1.0')]));
      await check.check();
      final action = notices(CatalogUpdateCheck.noticeKey).single.actions.last;
      expect(action.label, 'Update all');
      expect(action.primary, isTrue);
      action.onTap();
      await pumpEventQueue();
      // What was pending, handed over whole — the confirmation and the
      // installs are the caller's; nothing here opens the panel.
      expect(updatedAll, [
        ['k2hrc-llota'],
      ]);
      expect(namedAll, [
        {'k2hrc-llota'},
      ]);
      expect(opened, 0);
    });

    test('Update all hands over the names the notice shows, not what is pending by the press', () async {
      // Those names are what the press agreed to, and they skip the
      // confirmation. A silent check can add an update under a notice that
      // still reads the same; read at the press, the new one would install
      // unnamed and unconfirmed.
      var updates = [_entry(version: '1.1.0')];
      final check = await checker(
        (_) async => answer(updates: updates),
        installed: [
          _installed('k2hrc-llota', '1.0.0', name: 'LLOTA'),
          _installed('other-one', '1.0.0', name: 'Other One'),
        ],
      );
      await check.check();
      expect(notices(CatalogUpdateCheck.noticeKey).single.text, 'An update is available for LLOTA.');

      updates = [_entry(version: '1.1.0'), _entry(key: 'other-one', version: '2.0.0')];
      await check.check(force: true, announce: false);
      notices(CatalogUpdateCheck.noticeKey).single.actions.last.onTap();
      await pumpEventQueue();
      expect(updatedAll.single, ['k2hrc-llota', 'other-one']);
      expect(namedAll.single, {'k2hrc-llota'});
    });

    test('the check the panel runs on opening does not put the notice back', () async {
      // The action above takes the notice down on its way to the panel, and
      // the panel opens by forcing a check of its own. Announced, that answer
      // raises the same notice again behind the list the operator came to
      // read — the app asking twice about what it is already showing them.
      final check = await checker((_) async => answer(updates: [_entry(version: '1.1.0')]));
      await check.check();
      notices(CatalogUpdateCheck.noticeKey).single.actions.first.onTap();
      expect(notices(CatalogUpdateCheck.noticeKey), isEmpty);

      expect(await check.check(force: true, announce: false), isTrue);
      expect(notices(CatalogUpdateCheck.noticeKey), isEmpty);
      // Asked and answered all the same: the panel's own list is where the
      // update is shown, and it reads this.
      expect(check.pendingUpdates.keys, ['k2hrc-llota']);
    });

    test('a silent check still takes down a notice with nothing left behind it', () async {
      // Suppressing the announcement must not suppress the retraction: an
      // update taken elsewhere leaves "an update is available" in the footer
      // over nothing, which is the footer lying.
      var updates = [_entry(version: '1.1.0')];
      final check = await checker((_) async => answer(updates: updates));
      await check.check();
      expect(notices(CatalogUpdateCheck.noticeKey), hasLength(1));

      updates = const [];
      expect(await check.check(force: true, announce: false), isTrue);
      expect(notices(CatalogUpdateCheck.noticeKey), isEmpty);
    });

    test('asks at most once per six hours, judged by the persisted stamp', () async {
      var requests = 0;
      var now = 1_800_000_000_000;
      final check = await checker((_) async {
        requests++;
        return answer();
      }, realNow: () => now);

      expect(await check.check(), isTrue);
      expect(settings.catalogUpdateCheckedAt, now);
      now += const Duration(hours: 5).inMilliseconds;
      expect(await check.check(), isFalse);
      expect(requests, 1);
      now += const Duration(hours: 2).inMilliseconds;
      expect(await check.check(), isTrue);
      expect(requests, 2);
    });

    test('the stamp is on the REAL clock, whatever the app clock says', () async {
      // time.md §7: the seam's default is the contract. Travelled thirty
      // days back, a stamp on the app clock would read as thirty days old
      // and re-ask the catalog on every resume for the length of the offset;
      // travelled forward, it would silence the check for as long.
      AppClock.instance.travel(delta: const Duration(days: -30));
      final check = await checker((_) async => answer());
      final before = realNowMillis();
      await check.check();
      final stamp = settings.catalogUpdateCheckedAt!;
      expect(stamp, inInclusiveRange(before, realNowMillis()));
    });

    test('a catalog that does not answer leaves the stamp alone, so the next trigger asks again', () async {
      final check = await checker((_) async => http.Response('', 503));
      expect(await check.check(), isFalse);
      expect(settings.catalogUpdateCheckedAt, isNull);
      expect(notices(CatalogUpdateCheck.noticeKey), isEmpty);
    });

    test('nothing installed means no request', () async {
      var requests = 0;
      final check = await checker((_) async {
        requests++;
        return answer();
      }, installed: const [ExtensionInfo(key: 'pota', file: 'pota.js', core: false, name: 'POTA', version: '1.0.0')]);
      expect(await check.check(), isFalse);
      expect(requests, 0);
    });

    test('the experiment off means no request, and no stamp', () async {
      // Forced, so only the experiment can be what skips it. The stamp is
      // the trap: a skip that wrote one would silence the first check after
      // the flip for six hours, and read as "checked" in the meantime.
      var requests = 0;
      final check = await checker((_) async {
        requests++;
        return answer(updates: [_entry(version: '1.1.0')]);
      }, experiment: false);
      expect(await check.check(force: true), isFalse);
      expect(requests, 0);
      expect(settings.catalogUpdateCheckedAt, isNull);
      expect(check.pendingUpdates, isEmpty);
      expect(notices(CatalogUpdateCheck.noticeKey), isEmpty);
    });

    test('the notice comes down with the last pending update, and with a check that finds none', () async {
      // "An update is available" over an update just taken is the footer
      // lying, and a non-persistent notice is not enough: it lasts the
      // session. Mutated to never dismiss, both halves fail.
      var offered = [_entry(version: '1.1.0'), _entry(key: 'other-one', version: '2.0.0')];
      final check = await checker((_) async => answer(updates: offered), installed: [_installed('k2hrc-llota', '1.0.0'), _installed('other-one', '1.0.0')]);
      await check.check();
      expect(notices(CatalogUpdateCheck.noticeKey), hasLength(1));

      // An older version than the one offered resolves nothing.
      check.noteInstalled('k2hrc-llota', '1.0.5');
      expect(check.pendingUpdates.keys, ['k2hrc-llota', 'other-one']);
      check.noteInstalled('k2hrc-llota', '1.1.0');
      expect(check.pendingUpdates.keys, ['other-one']);
      expect(notices(CatalogUpdateCheck.noticeKey), hasLength(1));
      check.noteInstalled('other-one', '2.1.0');
      expect(check.pendingUpdates, isEmpty);
      expect(notices(CatalogUpdateCheck.noticeKey), isEmpty);

      // Offered again, then the next check finds everything current.
      await check.check(force: true);
      expect(notices(CatalogUpdateCheck.noticeKey), hasLength(1));
      offered = [];
      await check.check(force: true);
      expect(notices(CatalogUpdateCheck.noticeKey), isEmpty);
    });

    test('an update for an extension that is not loading is not offered', () async {
      // Before the catalog upgrade is taken, every pre-loaded or
      // hand-installed twin sits dormant behind the built-in it replaces.
      // Offering an update for one is the app talking about an extension that
      // is not running, on an install that has not moved to the catalog at
      // all — which is exactly what it did.
      final check = await checker(
        (_) async => answer(updates: [_entry(version: '1.1.0')]),
        inUse: (_) => false,
      );
      await check.check();
      expect(check.pendingUpdates, isEmpty);
      expect(notices(CatalogUpdateCheck.noticeKey), isEmpty);
    });

    test('a revocation is judged over everything installed, loading or not', () async {
      // The other half of the same rule: a bundle withdrawn for cause is on
      // disk whether or not a built-in is currently standing in front of it,
      // and the built-in going away later would light it up.
      final check = await checker(
        (_) async => answer(
          revoked: [
            {'key': 'k2hrc-llota', 'version': '1.0.0', 'note': 'It uploads the whole log.'},
          ],
        ),
        inUse: (_) => false,
      );
      await check.check();
      expect(settings.extensionRevoked, {
        'k2hrc-llota': {'version': '1.0.0', 'note': 'It uploads the whole log.'},
      });
      expect(applied, 1);
    });

    test('a revoked pair is put on record, unloaded and told once, with the catalog\'s note', () async {
      final check = await checker(
        (_) async => answer(
          revoked: [
            {'key': 'k2hrc-llota', 'version': '1.0.0', 'note': 'It uploads the whole log.'},
            // A version that is not the installed one is not this install's.
            {'key': 'k2hrc-llota', 'version': '0.9.0', 'note': 'old'},
          ],
        ),
      );
      await check.check();
      expect(settings.extensionRevoked, {
        'k2hrc-llota': {'version': '1.0.0', 'note': 'It uploads the whole log.'},
      });
      expect(applied, 1);
      // The record, not the switch: the operator's own override is theirs.
      expect(settings.extensionOverrides, isEmpty);
      final notice = notices(CatalogUpdateCheck.revokedNoticeKey('k2hrc-llota')).single;
      expect(notice.title, contains('LLOTA'));
      expect(notice.text, contains('It uploads the whole log.'));

      // On record: the six-hourly check must not announce the same pair
      // again, nor restart the runtime over it.
      statusBar.dismissNotice(CatalogUpdateCheck.revokedNoticeKey('k2hrc-llota'));
      await check.check(force: true);
      expect(applied, 1);
      expect(notices(CatalogUpdateCheck.revokedNoticeKey('k2hrc-llota')), isEmpty);
    });

    test('an extension the operator had already switched off is revoked all the same', () async {
      // Deduplicated on the record, not on the override: with the switch
      // standing in for "told", an extension that was off would never get
      // the record — and would run the revoked bytes the day the operator
      // switched it back on.
      final check = await checker(
        (_) async => answer(
          revoked: [
            {'key': 'k2hrc-llota', 'version': '1.0.0', 'note': 'It uploads the whole log.'},
          ],
        ),
        prefs: {
          'extensionOverrides': jsonEncode({'k2hrc-llota': false}),
        },
      );
      await check.check();
      expect(settings.extensionRevoked['k2hrc-llota']?['version'], '1.0.0');
      expect(notices(CatalogUpdateCheck.revokedNoticeKey('k2hrc-llota')), hasLength(1));
      expect(applied, 1);
    });
  });
}
