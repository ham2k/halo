// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// SOTA reference validation/formatting — pulled out of index.ts so it can be
// unit-tested directly (see index.test.ts): this file has no dependency on
// `@ham2k/extension-sdk` (a tsc-only path alias — see extensions/tsconfig.json —
// that Node's own module resolver, used by `node --test`, can't resolve at
// runtime), unlike index.ts which imports real hook types/values from it.

// One reference, e.g. "W6/SD-026". The core's ref chip input lets a user
// type several comma/space-separated references into one field (a boundary
// activation logs every simultaneously-active summit on the one QSO) — each
// becomes its OWN `Ref` entry, so this extension only ever sees one
// reference at a time.
export const REFERENCE_REGEX = /^[A-Z0-9]{1,4}\/[A-Z]{2}-[0-9]{3,}$/i

// Live-typing reformatting for the (possibly comma/space-separated list of)
// SOTA reference(s) in one chip's field, e.g. "w6sd026" -> "W6/SD-026" —
// same declarative-transform mechanism as POTA's, run by the core's native
// input widget on every keystroke.
// Braced `${1}`/`${2}`/`${3}`, not bare `$1`/`$2`/`$3` — see POTA's identical
// note: a bare "$1" immediately followed by a literal that starts with a
// digit misparses as a higher-numbered capture group.
export const TRANSFORMS: { pattern: string; replacement: string; flags?: string }[] = [
  // a run of spaces between two refs -> ", " (normalize to one separator style)
  { pattern: "([A-Z0-9]-\\d{3,}) +(?=[A-Z0-9])", replacement: "${1}, ", flags: "gi" },
  // "W6SD026" / "W6/SD026" / "W6SD-026" -> "W6/SD-026"
  { pattern: "([A-Z0-9]{1,4})\\/?([A-Z]{2})-?(\\d{3,})", replacement: "${1}/${2}-${3}", flags: "gi" },
  // trailing space/comma right after a complete ref -> start the next entry
  { pattern: "([A-Z0-9]{1,4}\\/[A-Z]{2}-\\d{3,})[\\s,]$", replacement: "${1},", flags: "gi" },
  // strip anything that can't appear in a reference list
  { pattern: "[^A-Z0-9\\/\\-, ]", replacement: "", flags: "gi" },
]

// SOTLAS publishes each summit's activation-zone outline as GeoJSON under a
// path built from the reference with its hyphen turned into a separator:
// "W2/GC-116" -> "W2/GC/116.geojson". Ham2K has the operators' permission to
// read these directly from that server.
//
// A summit with no surveyed zone answers 403, not 404 — object storage
// declining to confirm a key exists. So an error status can't be read as
// "the request was wrong"; both mean the same thing here, no zone.
export const ACTIVATION_ZONE_HOST = "https://az.sotl.as"

export function activationZoneUrl(reference: string): string | null {
  const normalized = reference.toUpperCase().trim()
  if (!REFERENCE_REGEX.test(normalized)) return null
  return `${ACTIVATION_ZONE_HOST}/${normalized.replace("-", "/")}.geojson`
}
