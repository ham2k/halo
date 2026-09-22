// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// QSON county → ADIF `CNTY`.

/// The country tags `adif_to_qson.dart`'s importer prefixes a county with:
/// the scheme it recognised, or `??` for one it didn't. Neither is a US state
/// or a Canadian province, so stripping them cannot eat a real first segment.
const COUNTRY_TAGS = new Set(["US", "??"])

/// ADIF `CNTY` is `STATE,COUNTY` — a bare secondary subdivision qualified by
/// the primary one, with no country in it.
///
/// Several shapes reach this from QSON's `county`, because its producers
/// never agreed on one (HALO-562 catalogues them):
///
/// - `US/NY/Kings` — the country-qualified code an ADIF import produces
///   (`adif_to_qson.dart`), whose last two segments are already the answer;
/// - `??/ON/Bruce` — the same, from a country whose scheme the import didn't
///   recognise, and equally answerable;
/// - `PR/Ponce` — Puerto Rico, which that importer leaves UNqualified, so the
///   two segments are the state and the county themselves. Two deep is
///   therefore ambiguous against `US/Hartford`, a CNTY that arrived with no
///   comma: only the two country tags the importer emits can be told apart,
///   so they are excluded by name and everything else two-deep reads as
///   state/county — `US,Hartford` is a state code to nothing.
/// - `Hartford` — a plain name from a lookup (`normalizeGuess.ts`) or typed
///   into the More pane, which needs the record's own state to become one;
/// - `CT,Hartford` — ADIF's own shape, which app-polo stores and syncs to us;
/// - `Hartford, CT` and `Deschutes/Jefferson` — whatever an operator types
///   into a free-text field (`OperationLocationScreen`).
///
/// **[state] is what tells those apart, so a separator alone never promotes a
/// segment to primary subdivision.** A segment is the primary one when it IS
/// the state this record already claims, at either end — `CT,Hartford` and
/// `Hartford, CT` are the same statement written two ways. Trusting the
/// punctuation instead writes `<CNTY:12>Hartford, CT` beside `<MY_STATE:2>CT`,
/// one record claiming two different primary subdivisions with one of them a
/// county, and the file gives no sign.
///
/// A value with a separator and NEITHER end matching cannot be reduced to a
/// single county of the state claimed, and every way of forcing it invents
/// something: `US/CA/Marin` under an operation in New York glues into
/// `NY,CA Marin`, a county that does not exist, and `Deschutes/Jefferson` is a
/// county LINE — two counties, where ADIF `CNTY` holds one. Both are dropped.
/// Telling them apart would need a table of subdivision codes, and `Bee`,
/// `Lee` and `Ida` are real counties shaped exactly like one.
///
/// Without a state a bare county name is not a CNTY at all, and is dropped
/// rather than written as half of one: a receiving program reading `Hartford`
/// as a primary subdivision has been told something false.
export function adifCounty(county: unknown, state: unknown): string | undefined {
  const text = typeof county === "string" ? county.trim() : ""
  if (!text) return undefined

  const parts = text
    .split(/[,/]/)
    .map((part) => part.trim())
    .filter((part) => part !== "")
  if (parts.length > 1 && COUNTRY_TAGS.has(parts[0]!.toUpperCase())) parts.shift()
  if (parts.length === 0) return undefined

  const primary = typeof state === "string" ? state.trim() : ""
  const matches = (part: string) => primary !== "" && part.toUpperCase() === primary.toUpperCase()

  if (parts.length > 1) {
    // `CT,Hartford` / `US/CT/Hartford` — the state leads, as both ADIF and the
    // importer write it.
    if (matches(parts[0]!)) return `${primary},${parts.slice(1).join(" ")}`
    // `Hartford, CT` — the operator's own order, and the one a naive read gets
    // exactly backwards.
    if (matches(parts[parts.length - 1]!)) return `${primary},${parts.slice(0, -1).join(" ")}`
    // Neither end is the state this record claims, so there is no single
    // county of it to be had.
    if (primary) return undefined
    // No state to check against at all, so the importer's structure is the
    // only thing to go on — `PR/Arecibo`, whose scheme carries no country tag.
    return `${parts[0]},${parts.slice(1).join(" ")}`
  }

  if (!primary) return undefined
  return `${primary},${parts[0]}`
}
