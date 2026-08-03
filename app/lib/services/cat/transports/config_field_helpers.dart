// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A couple of pieces of config-field logic more than one transport needs
// verbatim — a `host` field is a `host` field whether it's reached over TCP
// or the Icom network login, and "this value might be a num or a string
// round-tripped through JSON" is the same parse regardless of which numeric
// field it's for. Shared here so a fix to either only has to land once:
// independently-drifted copies of this kind of parsing have already caused
// a bug (see IcomCivDriver._parseAddress) — don't fork new copies.

import '../../../i18n/strings.g.dart';

/// The plain required-hostname-or-IP field two transports collect
/// identically (TCP's own host, and the Icom network login's host).
Map<String, dynamic> hostConfigElement() => {
      'type': 'field',
      'fieldType': 'text',
      'key': 'host',
      'label': t.settings.station.host,
      'description': t.settings.station.hostDescription,
    };

String trimmedHost(Map<String, dynamic> config) => (config['host'] as String? ?? '').trim();

String? validateHostField(String key, dynamic value, Map<String, dynamic> config) {
  if (key != 'host') return null;
  return trimmedHost({...config, 'host': value}).isEmpty ? t.settings.station.hostRequired : null;
}

/// A field value that may arrive as a `num`, or — round-tripped through
/// JSON, as a stored node's config always has been — as a `String`.
int numberFromConfig(Map<String, dynamic> config, String key, int fallback) {
  final raw = config[key];
  if (raw is num) return raw.toInt();
  return int.tryParse('$raw') ?? fallback;
}
