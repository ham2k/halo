// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a CI-V RF power level is worth in watts — on the radio's own scale,
// which CI-V never states, so the watts come from the model's entry.

/// The RF power level (0x14 0x0A) is a 0-255 value standing for 0-100% of
/// the radio's OWN maximum — CI-V has no command that states what that
/// maximum is, so `IcomCivSession.maxWatts` comes from config instead: a
/// named radio rated anything other than 100W overrides it with its own
/// SSB/CW ceiling (equipment_models_icom.dart — the IC-705's 10W, the
/// IC-7760's 200W); everything else — the generic Icom pairing, and any
/// config that leaves it out — falls back to this 100W guess, the common
/// ceiling across the HF line the CI-V driver otherwise targets (IC-7300,
/// IC-9700, IC-7610). Unverified either way — see
/// `IcomCivDriver.hardwareVerified`.
const civAssumedMaxWatts = 100;

/// Below this ceiling a 0-255 level actually carries sub-watt resolution
/// worth showing (10W over 255 steps is ~0.04W/step) — above it the ceiling
/// itself is a guess, and reporting e.g. 76.47058823529412W as though
/// precise is worse than useless. One decimal, not the raw division: it
/// still fits the Power field's 4-digit width and is what a QRP radio's own
/// display shows.
const civPreciseWattsCeiling = 20;

int civLevelForWatts(num watts, num maxWatts) => (watts / maxWatts * 255).round().clamp(0, 255);

num civWattsForLevel(int level, num maxWatts) {
  final raw = level / 255 * maxWatts;
  return maxWatts <= civPreciseWattsCeiling ? (raw * 10).round() / 10 : raw.round();
}

/// Below this RAW reading, `IcomCivSession.dcInputMeterLevel` says the radio
/// is on its own battery rather than an external supply — confirmed LIVE
/// against an IC-705, which read 115 on its internal battery and 195 plugged
/// in. The midpoint, since only those two bench readings exist; a supply
/// that happens to land near it would misclassify, but nothing between "flat
/// battery" and "external DC" is physically expected.
///
/// Deliberately compared as a RAW level and not as volts. Icom's published
/// Vd scale is a curve, and a different one per radio (see
/// `civMeterDcInputVoltage`) — this check needs neither, because both bench
/// readings are in the same units the radio answers in.
const civBatteryMeterCeiling = 150;

/// Pinned by an entry whose radio's 100% RF power level is a different
/// number of watts on different bands — the IC-9700's 100 W on 2 m, 75 W on
/// 70 cm and 10 W on 23 cm. A list of `[fromHz, watts]` pairs, ascending: at
/// a frequency the ceiling is the watts of the last pair at or below it, and
/// `maxWatts` below the first. Never a field: it is a fact about the model.
const civBandMaxWattsConfigKey = 'civBandMaxWatts';

/// The pairs a config pins under [civBandMaxWattsConfigKey]; anything else
/// in the list is skipped.
List<(int, num)> civBandMaxWattsFrom(Object? value) => [
  if (value case final List<dynamic> pairs)
    for (final pair in pairs)
      if (pair case [final num fromHz, final num watts]) (fromHz.toInt(), watts),
];

/// What the 100% level is worth at [freqHz]: [maxWatts], unless one of
/// [bands] covers it. Without this an IC-9700 asked for 10 W on 23 cm is
/// sent 10% of its 10 W. Before any frequency is known, [maxWatts].
num civRatedWatts(num maxWatts, List<(int, num)> bands, int? freqHz) {
  var watts = maxWatts;
  if (freqHz == null) return watts;
  for (final (fromHz, ceiling) in bands) {
    if (freqHz >= fromHz) watts = ceiling;
  }
  return watts;
}
