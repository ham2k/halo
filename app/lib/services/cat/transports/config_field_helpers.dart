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

String trimmedHost(Map<String, dynamic> config) => stringFromConfig(config, 'host').trim();

String? validateHostField(String key, dynamic value, Map<String, dynamic> config) {
  if (key != 'host') return null;
  return trimmedHost({...config, 'host': value}).isEmpty ? t.settings.station.hostRequired : null;
}

/// A field value that must be text, read without a cast.
///
/// A stored config is free-form JSON that nothing validates on the way in, so
/// a wrong-typed value is reachable — and this is read from `validate()`,
/// which [CatService._connect] calls OUTSIDE the try that guards the connect
/// itself. A cast here throws past every handler and takes the launch with
/// it; reading a non-String as absent lets the node fail as "not configured",
/// which is what an operator can act on.
///
/// Refuses where [numberFromConfig] coerces, deliberately: a baud rate stored
/// as `'19200'` means the same speed whichever shape it took, but a port
/// stored as `4800` names no port an operator ever chose — coercing it would
/// open, or fail to open, a device of the app's own invention.
String stringFromConfig(Map<String, dynamic> config, String key) {
  final raw = config[key];
  return raw is String ? raw : '';
}

/// A field value that may arrive as a `num`, or — round-tripped through
/// JSON, as a stored node's config always has been — as a `String`.
int numberFromConfig(Map<String, dynamic> config, String key, int fallback) {
  final raw = config[key];
  if (raw is num) return raw.toInt();
  return int.tryParse('$raw') ?? fallback;
}
