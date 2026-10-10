// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Presentation cleanup of the assembled guess. Sources report whatever their
// database holds — QRZ's "DELMONT, SEBASTIAN" and "GREENWICH", the FCC's
// all-caps everything — and every consumer of the guess (logging panel,
// call-info panel, exports) would otherwise have to shout it back.
//
// Applied ONCE, to the merged guess, never to the individual `lookups[]`
// entries: those are the record of what each source actually said. The
// normalized value does reach the QSO and its ADIF export (models.dart's
// `theirName` falls back to the guess), so a rule here has to be one we would
// stand behind in an uploaded log, not merely one that looks tidier on screen.

import { capitalizeString } from "@ham2k/lib-format-tools"
import type { CallInfo } from "@ham2k/extension-sdk"

// capitalizeString's own "already mixed case" test — a string that carries any
// deliberate capitalization is left as its source wrote it (`force: false`), so
// "Mcmillan, John" stays "John Mcmillan". We repeat the test here because the
// Mc-name rule below must apply only to the forced (all-caps input) path.
const MIXED_CASE_REGEX = /[A-Z][a-z]/
const MC_NAME_REGEX = /\bMc([a-z])/g

// capitalizeString is an ASCII affair: it recases through toLowerCase/
// toUpperCase and tests case with [A-Z] ranges. Ask it about "ΓΕΩΡΓΙΟΣ" and it
// reads a script it can't judge as "not capitalized yet" and confidently
// returns "Γεωργιος" — Greek uppercase drops the tonos, and lowercasing can't
// put it back, so the output is a misspelling. Anything with no ASCII letter
// at all is left exactly as its source wrote it.
const ASCII_LETTER_REGEX = /[A-Za-z]/

// A QRZ name carries the operator's nickname in curly quotes (see the qrz
// extension). It is a separate name, cased separately.
const NICKNAME_REGEX = /“([^”]*)”/

// A two-letter all-caps nickname is initials ("MJ", "JD"), not a shouted word:
// capitalizing it would produce "Mj".
const INITIALS_REGEX = /^[A-Z]{2}$/

// capitalizeString consults a per-content exception table for 'address' (NSW,
// VIC, QLD, PEI…) that its published `content` type doesn't list — the type
// lags the implementation, so the value has to be asserted in.
const ADDRESS_CONTENT = "address" as "text"

// A short all-caps value is a code rather than a word — `country` holds ISO
// alpha-2 for everything the Ham2K lookup service doesn't have a full name
// for, and "FR" must not become "Fr".
const CODE_REGEX = /^[A-Z]{2,3}$/

// A suffix filed after the name's last comma — QRZ's "OSCAR A CURTIS, JR",
// the Ham2K lookup's "CURTIS, OSCAR A, JR", Callook's "OSCAR A CURTIS, JR ." —
// is lifted off before the "Last, First" flip and put back at the end;
// flipping at that comma instead makes "Jr Oscar A Curtis". Generational
// suffixes and only the credentials that can't be a given name: "NGUYEN, DO"
// is a person called Do, not an osteopath. Each carries the separator it
// goes back on with, and the spelling an all-caps source gets.
const SUFFIXES: Record<string, string> = {
  JR: " Jr",
  SR: " Sr",
  II: " II",
  III: " III",
  IV: " IV",
  V: " V",
  VI: " VI",
  VII: " VII",
  VIII: " VIII",
  IX: " IX",
  "2ND": " 2nd",
  "3RD": " 3rd",
  "4TH": " 4th",
  "5TH": " 5th",
  MD: ", MD",
  PHD: ", PhD",
  DDS: ", DDS",
  DMD: ", DMD",
  DVM: ", DVM",
  ESQ: ", Esq",
  CPA: ", CPA",
}

/// "CURTIS, OSCAR A, JR" -> ["CURTIS, OSCAR A", " Jr"], or null when the
/// name doesn't end in a suffix. Only the dots come out when matching, never
/// the spaces: "SMITH, J R" is a man with two initials, not Smith Jr. And a
/// one-word name before the comma makes it "Last, First" with a given name
/// that looks like a suffix — "NGUYEN, VI", "EWING, JR" — so it isn't one.
function splitSuffix(name: string): [string, string] | null {
  const comma = name.lastIndexOf(",")
  if (comma < 0) return null
  const body = name.slice(0, comma).trim()
  if (!body.includes(",") && !/\s/.test(body)) return null
  const written = name
    .slice(comma + 1)
    .trim()
    .replace(/\s+\./g, ".")
  const suffix = SUFFIXES[written.replace(/\./g, "").toUpperCase()]
  if (!suffix) return null
  // As the source wrote it, unless it's shouting: the rest of an all-caps
  // name is recapitalized, so its suffix is too.
  const separator = suffix.startsWith(",") ? ", " : " "
  return [body, /[a-z]/.test(written) ? separator + written : suffix]
}

/// "Last, First" — exactly one comma, both halves non-empty. A name with two
/// or more commas is a form we can't read (organizations), and is left in
/// its original order.
function reorderName(name: string): string {
  const parts = name.split(",")
  if (parts.length !== 2) return name
  const [last, first] = parts.map((p) => p.trim())
  if (!last || !first) return name
  return `${first} ${last}`
}

/// Deliberately NOT capitalizeString's `content: 'name'` mode, which turns any
/// one-letter word into an initial with a period — the apostrophe it treats as
/// a word separator makes that "O.'Brien" out of O'BRIEN, and it invents a
/// period on a genuine one-syllable given name ("LI, X" -> "X. Li"). PoLo
/// passes 'name' here; we deliberately don't.
function capitalizeNamePart(part: string): string {
  const trimmed = part.trim()
  if (!trimmed || !ASCII_LETTER_REGEX.test(trimmed)) return trimmed
  const capitalized = capitalizeString(trimmed, { force: false })
  // Only when capitalizeString actually recapitalized: "Mcmillan" told us how
  // it wants to be spelled, an all-caps record told us nothing.
  if (MIXED_CASE_REGEX.test(trimmed)) return capitalized
  return capitalized.replace(MC_NAME_REGEX, (_m, letter: string) => `Mc${letter.toUpperCase()}`)
}

/// "DELMONT, SEBASTIAN" -> "Sebastian Delmont", "JOHN MCMILLAN" -> "John
/// McMillan", "ARRL HEADQUARTERS" -> "ARRL Headquarters".
export function normalizeName(name: string): string {
  // Peeled off one at a time: "SMITH, JOHN, JR, MD" carries two.
  let body = `${name}`.trim()
  let suffixes = ""
  for (let split = splitSuffix(body); split; split = splitSuffix(body)) {
    body = split[0]
    suffixes = split[1] + suffixes
  }
  return normalizeNameBody(body) + suffixes
}

function normalizeNameBody(trimmed: string): string {
  const nickname = trimmed.match(NICKNAME_REGEX)
  if (nickname?.index != null) {
    // Each part decides its own casing. Judged as one string, a hand-typed
    // "Jack" inside an all-caps "JOHN “Jack” SMITH" reads as deliberate
    // capitalization and leaves the whole name shouting.
    const inner = nickname[1].trim()
    const quoted = INITIALS_REGEX.test(inner) ? inner : capitalizeNamePart(inner)
    return [
      capitalizeNamePart(trimmed.slice(0, nickname.index)),
      quoted && `“${quoted}”`,
      capitalizeNamePart(trimmed.slice(nickname.index + nickname[0].length)),
    ]
      .filter(Boolean)
      .join(" ")
  }

  return capitalizeNamePart(reorderName(trimmed))
}

/// A place name, capitalized under the same ASCII caveat as a personal one.
function capitalizePlace(value: string, content: "text" = "text"): string {
  if (!ASCII_LETTER_REGEX.test(value)) return value
  return capitalizeString(value, { content, force: false })
}

/// Returns a NEW guess with the human-readable fields cleaned up. `state` is
/// left alone (a code, not a word), and so is `location` beyond the city
/// prefix below — it holds a POTA locationDesc ("US-NY"), a SOTA region or a
/// park descriptor as often as it holds a city.
export function normalizeGuess(guess: CallInfo): CallInfo {
  const next = { ...guess }

  if (next.name) next.name = normalizeName(next.name)
  if (next.county) next.county = capitalizePlace(next.county)
  if (next.country && !CODE_REGEX.test(next.country)) next.country = capitalizePlace(next.country)

  const city = next.city
  if (city) {
    const cleanCity = capitalizePlace(city, ADDRESS_CONTENT)
    next.city = cleanCity
    // The lookup sources that compose `location` build it as "<city>, <state>"
    // (qrz, ham2k-lookup), so rewriting just that prefix keeps the city and
    // the location the operator sees in agreement — without touching a state
    // code, or a `location` that isn't about this city at all. The whole city
    // has to match: `city` and `location` reach the merged guess from
    // different sources routinely, and a bare prefix test splices them
    // ("SPRING" + "SPRINGFIELD, IL" -> "SpringFIELD, IL").
    const location = next.location ? `${next.location}` : ""
    const rest = location.slice(city.length)
    if (location.toLowerCase().startsWith(city.toLowerCase()) && !/^[A-Za-z0-9]/.test(rest)) {
      next.location = cleanCity + rest
    }
  }

  return next
}
