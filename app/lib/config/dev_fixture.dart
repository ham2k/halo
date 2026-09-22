// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Canned dev data for the fixture + determinism hooks:
// a deterministic stubbed lookup result (so callsign lookups don't need network
// or QRZ credentials and always return the same thing) and a fixed set of seed
// QSOs for `window.__halo.resetFixture()`. Pure data — no service/UI imports —
// so `ExtensionService` can pull in the stub without dragging in the reset
// orchestration (which lives in `main.dart`).

/// A deterministic stand-in for `lookupCallInfo`, shaped like the real hook's
/// `{guess, lookups}` result. Used when `HALO_STUB_LOOKUPS` is set: every call
/// resolves instantly, offline, and identically, so agent verification isn't at
/// the mercy of the network or credentialed sources.
///
/// The entity is a fixed US template (determinism over realism) with the actual
/// [call] filled in — enough for the logging screen's call-info line.
Map<String, dynamic> stubbedLookupResult(String call) {
  final c = call.toUpperCase();
  return {
    'guess': {
      'call': c,
      'baseCall': c,
      'name': 'Test Op $c',
      'city': 'Newington',
      'state': 'CT',
      'location': 'Newington, CT',
      'country': 'United States',
      'entityName': 'United States',
      'entityPrefix': 'K',
      'dxccCode': 291,
      'continent': 'NA',
      'grid': 'FN31pr',
      'flag': '🇺🇸',
      'lat': 41.7146626,
      'lon': -72.7284655,
      'matchSource': 'stub',
    },
    'lookups': [
      {'source': 'stub', 'call': c},
    ],
  };
}

/// The seed QSOs `resetFixture()` inserts into the fresh fixture operation —
/// a fixed, ordered set (deterministic calls/bands/modes). [baseMillis] anchors
/// the timestamps to "now" so the rows land under Today; they're spaced a
/// minute apart, oldest first. Each carries a grid so the Map tab has
/// locations to draw — without one a fixture QSO is invisible there.
List<Map<String, dynamic>> fixtureQsos(int baseMillis) => [
  {
    'their': {'call': 'W1AW', 'grid': 'FN31pr'},
    'band': '20m',
    'mode': 'SSB',
    'startAtMillis': baseMillis - 120000,
  },
  {
    'their': {'call': 'K2HAM', 'grid': 'DM33xk'},
    'band': '40m',
    'mode': 'CW',
    'startAtMillis': baseMillis - 60000,
  },
  {
    'their': {'call': 'VE3ABC', 'grid': 'FN03hp'},
    'band': '15m',
    'mode': 'FT8',
    'startAtMillis': baseMillis,
  },
];

/// The fixture operation's own grid (northern NJ) — gives the Map tab a QTH
/// circle and great-circle lines, not just unanchored QSO dots.
const fixtureOperationGrid = 'FN20su';
