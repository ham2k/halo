// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a `ref:<type>` hook may answer for a reference's link and shape, read
// as data so the shapes a hook can return are testable without a runtime.

import 'package:flutter/foundation.dart';

import '../link_opener.dart';

/// Reads a `geojsonUrlForRef` answer, or `null` for anything the app would not
/// fetch. Separate from the call so the shapes a hook can return are testable
/// without a runtime, same as [refLinkFromHookResult].
///
/// Unlike a link, this URL is fetched rather than handed to the platform, so
/// the check is on the SCHEME the fetch stack will accept — `https` only. A
/// plaintext shape URL would silently downgrade every activator's connection
/// on a program's say-so.
RefGeojson? refGeojsonFromHookResult(dynamic result, {required String type}) {
  if (result == null) return null;
  if (result is! Map) {
    debugPrint('[extensions] geojsonUrlForRef(ref:$type) answered ${result.runtimeType}, not a map');
    return null;
  }
  final url = result['url'];
  if (url is! String || !url.startsWith('https://') || url.length <= 'https://'.length) {
    debugPrint('[extensions] geojsonUrlForRef(ref:$type) answered no usable https url');
    return null;
  }
  final sourceName = result['sourceName'];
  return RefGeojson(
    url: url,
    maxAge: _positiveDays(result['maxAgeInDays']) ?? const Duration(days: 30),
    missMaxAge: _positiveDays(result['missMaxAgeInDays']) ?? const Duration(days: 1),
    // The host when the hook names none: every outline on a map is credited
    // to someone, and the server it came from is never wrong about that.
    sourceName: sourceName is String && sourceName.trim().isNotEmpty ? sourceName.trim() : Uri.tryParse(url)?.host,
  );
}

/// A hook's day count as a duration, or null for anything that isn't a
/// positive number of at most a century — a zero or negative TTL would re-fetch
/// on every rebuild of the map, and a vast one overflows the conversion and
/// throws, taking every other reference's outline with it; either falls back
/// to the default rather than being honored.
Duration? _positiveDays(dynamic value) {
  final days = value is num ? value.toDouble() : null;
  if (days == null || days <= 0 || days > 36500) return null;
  return Duration(milliseconds: (days * Duration.millisecondsPerDay).round());
}

/// One `geojsonUrlForRef` answer: where a reference's outline lives, and how
/// long the app may keep it — [missMaxAge] being how long it remembers that
/// there is no outline at all.
class RefGeojson {
  const RefGeojson({required this.url, required this.maxAge, required this.missMaxAge, this.sourceName});

  final String url;
  final Duration maxAge;
  final Duration missMaxAge;

  /// Who the shapes come from, as the map's credit line names them.
  final String? sourceName;
}

/// A `geojsonUrlForRef` answer as a list of them reports it: the [source], and
/// whether the program [answered] at all — a null source it answered is "no
/// outline", one it could not be asked for is "ask again later".
typedef RefGeojsonAnswer = ({RefGeojson? source, bool answered});

/// Reads a `linkForRef` answer, or `null` for anything the app would not put a
/// button on. Separate from the call so the shapes a hook can actually return
/// are testable without a runtime.
///
/// [type] appears only in the log lines: a hook answering wrongly and a ref
/// type with no link at all look identical from the row (neither draws a
/// button), so the console is the only place the difference can show.
RefLink? refLinkFromHookResult(dynamic result, {required String type}) {
  // `null` is the ordinary answer — most ref types implement no link at all.
  if (result == null) return null;
  if (result is! Map) {
    debugPrint('[extensions] linkForRef(ref:$type) answered ${result.runtimeType}, not a map');
    return null;
  }
  final url = result['url'];
  if (url is! String || url.isEmpty) {
    debugPrint('[extensions] linkForRef(ref:$type) answered no usable url');
    return null;
  }
  // Checked where the link is RESOLVED, not where it is tapped: the row draws
  // its button because a link came back, so a URL the app would refuse to open
  // has to be no link at all rather than a button that does nothing every time
  // it is pressed.
  if (!canOpenExternalUrl(url)) {
    debugPrint('[extensions] linkForRef(ref:$type) offered an unopenable url: "$url"');
    return null;
  }
  final label = result['label'];
  return RefLink(url: url, label: label is String && label.isNotEmpty ? label : null);
}

/// One `linkForRef` answer: somewhere to read about a reference, and a name
/// for the destination that the UI wraps in its own localized phrasing.
class RefLink {
  const RefLink({required this.url, this.label});

  final String url;
  final String? label;
}
