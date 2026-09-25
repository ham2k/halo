// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Fetches the outline of a reference's own footprint — a SOTA activation
// zone today — and keeps it on the device so it still draws for an activator
// who is standing on the summit with no signal, which is the whole point of
// having it.
//
// The URL comes from the reference's `ref:<type>` handler
// (`geojsonUrlForRef`, docs/extensions/hooks.md); the fetching and the
// caching are the app's, so an extension never gets to decide how long the
// device keeps a file or how large one may be.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';
import 'package:http/http.dart' as http;

import '../config/user_agent.dart';
import 'extensions/extension_service.dart';

/// The `lookups` category these rows live under. Not a data file: nothing
/// registers it with DataFileManager, so its ownership sweeps leave it alone.
const geoshapeLookupCategory = 'geoshape';

/// One answer about a reference's outline.
///
/// [geojson] null means two different things, and the map needs to tell them
/// apart: [resolved] says the program itself publishes no shape (an answer
/// worth remembering), while an unresolved answer means this device could not
/// find out — offline, or a server having a bad day — and asking again later
/// is the right thing to do.
@immutable
class Geoshape {
  const Geoshape(this.geojson, {required this.resolved});

  /// Nothing known, and nothing settled. The map keeps asking.
  static const unknown = Geoshape(null, resolved: false);

  /// The program publishes none. The map stops asking.
  static const none = Geoshape(null, resolved: true);

  final String? geojson;
  final bool resolved;
}

/// The shape of a reference, and when it was fetched — [geojson] null for a
/// reference whose program publishes none.
@immutable
class CachedGeoshape {
  const CachedGeoshape({required this.geojson, required this.fetchedAtMillis});

  final String? geojson;
  final int fetchedAtMillis;
}

class GeoshapeService {
  GeoshapeService({required this.extensions, required this.lookups, this.httpClientFactory = http.Client.new, this.fetchTimeout = defaultFetchTimeout});

  final ExtensionService extensions;
  final LookupRepository lookups;
  final http.Client Function() httpClientFactory;

  /// How long one whole exchange may take — connect, headers and body. Named
  /// on the instance so a test can prove the deadline holds without waiting
  /// out the real one.
  final Duration fetchTimeout;
  static const defaultFetchTimeout = Duration(seconds: 20);

  /// A ceiling on what one reference may pull down. Real activation zones run
  /// to tens of kilobytes; anything past this is a program's server answering
  /// with something that is not a boundary, and reading it would cost the
  /// operator's memory and then their disk for a shape that will never draw.
  /// Checked against the declared length BEFORE the body is read, and again
  /// after for a server that declared none.
  static const maxBodyBytes = 4 * 1024 * 1024;

  /// One in-flight fetch per URL. Two reference types can name the same file
  /// — SOTA's `sota` and `sotaActivation` resolve to one summit — and the map
  /// asks for every reference on the operation at once, so without this the
  /// same document is fetched twice and written twice.
  final Map<String, Future<Geoshape>> _inFlight = {};

  /// The GeoJSON for [ref], from the cache when it is fresh enough and from
  /// the network otherwise.
  ///
  /// A stale cached shape is still returned when the fetch fails: a boundary
  /// that is a month old is right, and refusing to draw it is exactly the
  /// wrong answer for the offline case this cache exists for.
  Future<Geoshape> shapeForRef(Map<String, dynamic> ref) async {
    final source = await extensions.geojsonUrlForRef(ref);
    // A program with no shapes at all is as settled an answer as a 404: the
    // hook builds its URL from the reference and never asks the network, so
    // this cannot change while the app is running.
    if (source == null) return Geoshape.none;

    final cached = await _cached(source.url);
    if (cached != null && !_isStale(cached, source)) {
      return Geoshape(cached.geojson, resolved: true);
    }

    // A block body, never `=> _inFlight.remove(url)`: `Map.remove` answers with
    // the very Future being registered here, and `whenComplete` waits on a
    // future its callback returns — so the arrow form has this future wait for
    // itself, and every fetch hangs forever.
    return _inFlight[source.url] ??= _fetchAndStore(source, fallback: cached).whenComplete(() {
      _inFlight.remove(source.url);
    });
  }

  /// The cached shape for [url] if this device holds one, whatever its age.
  Future<CachedGeoshape?> _cached(String url) async {
    final row = await lookups.getLookup(geoshapeLookupCategory, url);
    if (row == null) return null;
    return CachedGeoshape(geojson: row.data, fetchedAtMillis: row.updated ?? 0);
  }

  /// A hit expires on the program's own schedule, a miss sooner — a summit
  /// that had no surveyed zone last week may have one now, and nothing tells
  /// the device but asking again.
  ///
  /// A stamp in the FUTURE counts as stale rather than as eternally fresh:
  /// the device's clock can move backwards (a correction, a fresh install
  /// restoring a backup), and a row written under the old one would otherwise
  /// never refresh again.
  bool _isStale(CachedGeoshape cached, RefGeojson source) {
    final age = realNowMillis() - cached.fetchedAtMillis;
    if (age < 0) return true;
    final ttl = cached.geojson == null ? source.missMaxAge : source.maxAge;
    return age > ttl.inMilliseconds;
  }

  Future<Geoshape> _fetchAndStore(RefGeojson source, {CachedGeoshape? fallback}) async {
    final client = httpClientFactory();
    try {
      final request = http.Request('GET', Uri.parse(source.url));
      request.headers['User-Agent'] = await ham2kUserAgent();
      // The https-only check in `refGeojsonFromHookResult` guards the URL a
      // hook NAMES; a redirect would otherwise walk straight past it, since a
      // program's server can answer its own https URL with `Location:
      // http://…` and complete the fetch in the clear. Refusing to follow one
      // keeps the check meaning what it says. A browser enforces this itself
      // (mixed content is blocked outright), and package:http's BrowserClient
      // throws on a request that declines redirects, so this is set only off
      // the web.
      if (!kIsWeb) request.followRedirects = false;

      // The timeout covers the whole exchange, connect and headers included —
      // NOT just the body read. A server that accepts the connection and then
      // never sends a status line would otherwise hang forever, and with it
      // this URL's `_inFlight` entry, which is cleared by a completion that
      // never comes.
      final response = await _read(client, request).timeout(fetchTimeout);

      // Object storage declines a key that isn't there with 403 as readily as
      // with 404 (SOTLAS's activation zones do exactly this), so every 4xx is
      // read the same way: this reference has no shape. Only a 5xx, a
      // redirect, or a transport failure is treated as "ask again later" —
      // see the catch.
      if (response.statusCode >= 400 && response.statusCode < 500) {
        await _store(source.url, null);
        return Geoshape.none;
      }
      if (response.statusCode != 200) {
        throw http.ClientException('HTTP ${response.statusCode}', Uri.parse(source.url));
      }
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      // Parsed before it is stored, so a body that is not JSON never becomes
      // a cache entry the map re-reads and re-fails on for the next 30 days.
      jsonDecode(body);
      await _store(source.url, body);
      return Geoshape(body, resolved: true);
    } catch (e) {
      // Offline is the ordinary case here, not an incident: no report, and
      // whatever this device already holds is still the best answer it has.
      debugPrint('[geoshape] Could not fetch ${source.url}: $e');
      return _fallback(fallback);
    } finally {
      client.close();
    }
  }

  /// The response, refusing a body past [maxBodyBytes] before reading it.
  ///
  /// Split out so ONE timeout can cover the whole exchange — connect, headers
  /// and body alike. A `.timeout` on the body read alone leaves a server that
  /// accepts the connection and then says nothing hanging forever, and with
  /// it this URL's `_inFlight` entry, cleared by a completion that never
  /// comes.
  Future<http.Response> _read(http.Client client, http.Request request) async {
    final streamed = await client.send(request);
    final declared = streamed.contentLength;
    if (declared != null && declared > maxBodyBytes) {
      throw http.ClientException('$declared bytes, past the ceiling', request.url);
    }
    final response = await http.Response.fromStream(streamed);
    // Again, for a server that declared no length or under-declared one.
    if (response.bodyBytes.length > maxBodyBytes) {
      throw http.ClientException('${response.bodyBytes.length} bytes, past the ceiling', request.url);
    }
    return response;
  }

  /// What to answer when the fetch didn't settle anything: the stale copy if
  /// this device holds one, otherwise "still unknown" — never
  /// [Geoshape.none], which would have the map stop asking on the strength of
  /// a dropped connection.
  Geoshape _fallback(CachedGeoshape? fallback) => fallback == null ? Geoshape.unknown : Geoshape(fallback.geojson, resolved: fallback.geojson != null);

  /// `realNowMillis`, not the app clock (docs/design/time.md §1): the stamp
  /// persists and outlives the travel that wrote it, so a developer three
  /// days forward must not leave rows that look fresh for three days after
  /// they come back.
  Future<void> _store(String url, String? geojson) =>
      lookups.insertLookupBatch([LookupRow(category: geoshapeLookupCategory, key: url, data: geojson, updated: realNowMillis())]);
}
