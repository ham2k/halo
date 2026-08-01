// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// GENERATED FILE — do not edit by hand.
// Regenerate with: node packages/halo_core/tool/generate_band_plan_segments.mjs
// Source: @ham2k/lib-operation-data 1.1.0 (bandPlans data, not part of
// the package's public API — parsed out of its bundle, see the generator).
//
// One entry per band-plan segment, read by modeForFrequency (radio.dart).
// `scoped` collapses the source's `regions`/`countries`/`entities`
// restrictions into a single flag — HaLo has no ituRegion/countryCode for
// the operator (see NoticeContext in app/lib/services/notices.dart, which
// hits the same gap for server notices), so modeForFrequency can't evaluate
// them; it only uses the flag to prefer an unscoped segment when one covers
// the frequency. See radio.dart's modeForFrequency doc comment for why.
//
// The source data is treated as authoritative and carried through as-is,
// including known issues — e.g. 12m's FT4 segment ships as mhz: [24919,
// 23922] (hi < lo, so it never matches any frequency). Re-run the generator
// above to see the current list of these.

const List<({double loKHz, double hiKHz, String? mode, int priority, bool scoped})> bandPlanModeSegments = [
  // 160m
  (loKHz: 1800, hiKHz: 2000, mode: null, priority: 0, scoped: true),
  (loKHz: 1810, hiKHz: 1838, mode: 'CW', priority: 0, scoped: true),
  (loKHz: 1800, hiKHz: 1810, mode: 'RTTY', priority: 0, scoped: false),
  (loKHz: 1800, hiKHz: 1843, mode: 'CW', priority: 0, scoped: false),
  (loKHz: 1840, hiKHz: 1843, mode: 'FT8', priority: 100, scoped: false),
  (loKHz: 1843, hiKHz: 2000, mode: 'SSB', priority: 0, scoped: false),
  (loKHz: 1800, hiKHz: 1875, mode: null, priority: 0, scoped: true),
  // 80m
  (loKHz: 3500, hiKHz: 3570, mode: 'CW', priority: 0, scoped: true),
  (loKHz: 3500, hiKHz: 3600, mode: 'CW', priority: 0, scoped: false),
  (loKHz: 3535, hiKHz: 3800, mode: 'SSB', priority: 0, scoped: true),
  (loKHz: 3568, hiKHz: 3571, mode: 'FT8', priority: 100, scoped: true),
  (loKHz: 3570, hiKHz: 3600, mode: 'RTTY', priority: 0, scoped: false),
  (loKHz: 3573, hiKHz: 3576, mode: 'FT8', priority: 100, scoped: false),
  (loKHz: 3600, hiKHz: 4000, mode: 'SSB', priority: 0, scoped: false),
  (loKHz: 3500, hiKHz: 3800, mode: null, priority: 0, scoped: true),
  // 60m
  (loKHz: 5330.5, hiKHz: 5333.5, mode: null, priority: 0, scoped: false),
  (loKHz: 5346.5, hiKHz: 5349.5, mode: null, priority: 0, scoped: false),
  (loKHz: 5357, hiKHz: 5360, mode: 'FT8', priority: 100, scoped: false),
  (loKHz: 5371.5, hiKHz: 5373.5, mode: null, priority: 0, scoped: false),
  (loKHz: 5403.5, hiKHz: 5406.5, mode: null, priority: 0, scoped: false),
  // 40m
  (loKHz: 7000, hiKHz: 7060, mode: 'CW', priority: 0, scoped: false),
  (loKHz: 7000, hiKHz: 7040, mode: 'CW', priority: 0, scoped: true),
  (loKHz: 7000, hiKHz: 7125, mode: 'CW', priority: 0, scoped: true),
  (loKHz: 7047.5, hiKHz: 7050.5, mode: 'FT4', priority: 100, scoped: false),
  (loKHz: 7060, hiKHz: 7300, mode: 'SSB', priority: 0, scoped: false),
  (loKHz: 7074, hiKHz: 7077, mode: 'FT8', priority: 100, scoped: false),
  (loKHz: 7080, hiKHz: 7125, mode: 'RTTY', priority: 0, scoped: true),
  (loKHz: 7125, hiKHz: 7300, mode: 'SSB', priority: 0, scoped: true),
  (loKHz: 7000, hiKHz: 7300, mode: null, priority: 0, scoped: true),
  (loKHz: 7200, hiKHz: 7300, mode: null, priority: 0, scoped: true),
  // 30m
  (loKHz: 10100, hiKHz: 10150, mode: 'CW', priority: 0, scoped: false),
  (loKHz: 10100, hiKHz: 10130, mode: 'CW', priority: 0, scoped: true),
  (loKHz: 10130, hiKHz: 10140, mode: 'RTTY', priority: 0, scoped: false),
  (loKHz: 10136, hiKHz: 10139, mode: 'FT8', priority: 100, scoped: false),
  (loKHz: 10140, hiKHz: 10143, mode: 'FT4', priority: 100, scoped: false),
  (loKHz: 10100, hiKHz: 10150, mode: null, priority: 0, scoped: true),
  // 20m
  (loKHz: 14000, hiKHz: 14150, mode: 'CW', priority: 0, scoped: false),
  (loKHz: 14000, hiKHz: 14070, mode: 'CW', priority: 0, scoped: true),
  (loKHz: 14000, hiKHz: 14101, mode: 'CW', priority: 0, scoped: true),
  (loKHz: 14070, hiKHz: 14095, mode: 'RTTY', priority: 0, scoped: false),
  (loKHz: 14074, hiKHz: 14077, mode: 'FT8', priority: 100, scoped: false),
  (loKHz: 14080, hiKHz: 14083, mode: 'FT4', priority: 100, scoped: false),
  (loKHz: 14112, hiKHz: 14350, mode: 'SSB', priority: 0, scoped: true),
  (loKHz: 14150, hiKHz: 14350, mode: 'SSB', priority: 0, scoped: true),
  (loKHz: 14000, hiKHz: 14350, mode: null, priority: 0, scoped: true),
  // 17m
  (loKHz: 18068, hiKHz: 18110, mode: 'CW', priority: 0, scoped: false),
  (loKHz: 18068, hiKHz: 18095, mode: 'CW', priority: 0, scoped: true),
  (loKHz: 18100, hiKHz: 18105, mode: 'RTTY', priority: 0, scoped: false),
  (loKHz: 18100, hiKHz: 18103, mode: 'FT8', priority: 100, scoped: false),
  (loKHz: 18104, hiKHz: 18107, mode: 'FT4', priority: 100, scoped: false),
  (loKHz: 18109, hiKHz: 18111, mode: null, priority: 100, scoped: false),
  (loKHz: 18111, hiKHz: 18168, mode: 'SSB', priority: 0, scoped: false),
  (loKHz: 18110, hiKHz: 18168, mode: 'SSB', priority: 0, scoped: true),
  (loKHz: 18068, hiKHz: 18168, mode: null, priority: 0, scoped: true),
  // 15m
  (loKHz: 21000, hiKHz: 21150, mode: 'CW', priority: 0, scoped: false),
  (loKHz: 21000, hiKHz: 21070, mode: 'CW', priority: 0, scoped: true),
  (loKHz: 21070, hiKHz: 21095, mode: 'RTTY', priority: 0, scoped: false),
  (loKHz: 21074, hiKHz: 21077, mode: 'FT8', priority: 100, scoped: false),
  (loKHz: 21140, hiKHz: 21143, mode: 'FT4', priority: 100, scoped: false),
  (loKHz: 21149, hiKHz: 21151, mode: null, priority: 100, scoped: false),
  (loKHz: 21151, hiKHz: 21450, mode: 'SSB', priority: 0, scoped: false),
  (loKHz: 21150, hiKHz: 21450, mode: 'SSB', priority: 0, scoped: true),
  (loKHz: 21000, hiKHz: 21450, mode: null, priority: 0, scoped: true),
  // 12m
  (loKHz: 24890, hiKHz: 24930, mode: 'CW', priority: 0, scoped: false),
  (loKHz: 24890, hiKHz: 24915, mode: 'CW', priority: 0, scoped: true),
  (loKHz: 24915, hiKHz: 24918, mode: 'FT8', priority: 100, scoped: false),
  (loKHz: 24919, hiKHz: 23922, mode: 'FT4', priority: 100, scoped: false),
  (loKHz: 24920, hiKHz: 24925, mode: 'RTTY', priority: 0, scoped: false),
  (loKHz: 24930, hiKHz: 24990, mode: 'SSB', priority: 0, scoped: false),
  (loKHz: 24929, hiKHz: 24931, mode: null, priority: 100, scoped: false),
  (loKHz: 24930, hiKHz: 24990, mode: 'SSB', priority: 0, scoped: true),
  (loKHz: 24890, hiKHz: 24990, mode: null, priority: 0, scoped: true),
  // 10m
  (loKHz: 28000, hiKHz: 28190, mode: 'CW', priority: 0, scoped: false),
  (loKHz: 28000, hiKHz: 28070, mode: 'CW', priority: 0, scoped: true),
  (loKHz: 28070, hiKHz: 28150, mode: 'RTTY', priority: 0, scoped: false),
  (loKHz: 28074, hiKHz: 28077, mode: 'FT8', priority: 100, scoped: false),
  (loKHz: 28180, hiKHz: 28183, mode: 'FT4', priority: 100, scoped: false),
  (loKHz: 28190, hiKHz: 28300, mode: null, priority: 100, scoped: false),
  (loKHz: 28300, hiKHz: 29000, mode: 'SSB', priority: 0, scoped: false),
  (loKHz: 29000, hiKHz: 29200, mode: 'AM', priority: 0, scoped: false),
  (loKHz: 29300, hiKHz: 29520, mode: null, priority: 0, scoped: false),
  (loKHz: 29510, hiKHz: 29520, mode: null, priority: 100, scoped: true),
  (loKHz: 29520, hiKHz: 29590, mode: null, priority: 0, scoped: false),
  (loKHz: 29520, hiKHz: 29700, mode: 'FM', priority: 0, scoped: false),
  (loKHz: 29620, hiKHz: 29700, mode: null, priority: 0, scoped: false),
  (loKHz: 28000, hiKHz: 29700, mode: null, priority: 0, scoped: true),
  // 6m
  (loKHz: 50000, hiKHz: 50010, mode: null, priority: 0, scoped: true),
  (loKHz: 50010, hiKHz: 50020, mode: null, priority: 0, scoped: true),
  (loKHz: 50020, hiKHz: 50030, mode: null, priority: 0, scoped: true),
  (loKHz: 50000, hiKHz: 50100, mode: 'CW', priority: 0, scoped: false),
  (loKHz: 50100, hiKHz: 50300, mode: 'SSB', priority: 0, scoped: true),
  (loKHz: 51400, hiKHz: 54000, mode: 'FM', priority: 0, scoped: true),
  (loKHz: 50150, hiKHz: 50400, mode: 'SSB', priority: 0, scoped: false),
  (loKHz: 51000, hiKHz: 51110, mode: 'SSB', priority: 0, scoped: false),
  (loKHz: 51110, hiKHz: 52100, mode: 'FM', priority: 0, scoped: false),
  (loKHz: 51110, hiKHz: 52100, mode: 'FM', priority: 0, scoped: false),
  (loKHz: 51410, hiKHz: 51590, mode: 'FM', priority: 0, scoped: true),
  (loKHz: 50313, hiKHz: 50316, mode: 'FT8', priority: 100, scoped: false),
  (loKHz: 50318, hiKHz: 50321, mode: 'FT4', priority: 100, scoped: false),
  (loKHz: 50323, hiKHz: 50326, mode: 'FT8', priority: 100, scoped: false),
  (loKHz: 50000, hiKHz: 54000, mode: null, priority: 0, scoped: true),
  // 4m
  (loKHz: 70090, hiKHz: 70100, mode: 'CW', priority: 0, scoped: true),
  (loKHz: 70000, hiKHz: 70090, mode: 'CW', priority: 0, scoped: true),
  (loKHz: 70100, hiKHz: 70294, mode: 'SSB', priority: 0, scoped: true),
  (loKHz: 70294, hiKHz: 70500, mode: 'FM', priority: 0, scoped: true),
  (loKHz: 70257, hiKHz: 70263, mode: 'AM', priority: 100, scoped: true),
  (loKHz: 70100, hiKHz: 70103, mode: 'FT8', priority: 100, scoped: true),
  (loKHz: 70154, hiKHz: 70157, mode: 'FT8', priority: 100, scoped: true),
  // 2m
  (loKHz: 144000, hiKHz: 144100, mode: 'CW', priority: 0, scoped: false),
  (loKHz: 144000, hiKHz: 144025, mode: null, priority: 0, scoped: true),
  (loKHz: 144025, hiKHz: 144150, mode: 'CW', priority: 0, scoped: true),
  (loKHz: 144100, hiKHz: 144200, mode: 'RTTY', priority: 0, scoped: false),
  (loKHz: 144174, hiKHz: 144177, mode: 'FT8', priority: 100, scoped: false),
  (loKHz: 144170, hiKHz: 144173, mode: 'FT4', priority: 100, scoped: false),
  (loKHz: 144200, hiKHz: 144275, mode: 'SSB', priority: 0, scoped: false),
  (loKHz: 144150, hiKHz: 144400, mode: 'SSB', priority: 0, scoped: true),
  (loKHz: 144400, hiKHz: 144490, mode: null, priority: 100, scoped: true),
  (loKHz: 144300, hiKHz: 148000, mode: 'FM', priority: 0, scoped: false),
  (loKHz: 144500, hiKHz: 144794, mode: null, priority: 0, scoped: true),
  (loKHz: 145194, hiKHz: 145206, mode: 'FM', priority: 0, scoped: true),
  (loKHz: 145206, hiKHz: 145563, mode: 'FM', priority: 0, scoped: true),
  (loKHz: 146000, hiKHz: 148000, mode: null, priority: 0, scoped: true),
  // 1.25m
  (loKHz: 222000, hiKHz: 222070, mode: 'CW', priority: 0, scoped: false),
  (loKHz: 222070, hiKHz: 222150, mode: 'SSB', priority: 0, scoped: false),
  (loKHz: 222200, hiKHz: 225000, mode: 'FM', priority: 0, scoped: false),
  // 70cm
  (loKHz: 420000, hiKHz: 430000, mode: null, priority: 0, scoped: true),
  (loKHz: 432000, hiKHz: 432100, mode: 'CW', priority: 0, scoped: false),
  (loKHz: 432100, hiKHz: 432300, mode: 'SSB', priority: 0, scoped: false),
  (loKHz: 432420, hiKHz: 433000, mode: 'SSB', priority: 0, scoped: false),
  (loKHz: 432100, hiKHz: 432400, mode: 'SSB', priority: 0, scoped: true),
  (loKHz: 420000, hiKHz: 450000, mode: 'FM', priority: 0, scoped: false),
  (loKHz: 433400, hiKHz: 433575, mode: 'FM', priority: 0, scoped: true),
  (loKHz: 440000, hiKHz: 450000, mode: null, priority: 0, scoped: true),
  // 33cm
  (loKHz: 927000, hiKHz: 928000, mode: 'FM', priority: 0, scoped: false),
];
