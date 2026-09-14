// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The inverse of the `adifFields` contributions the reference programs write:
// `SIG`/`SIG_INFO` for the reference the OTHER station was at, `MY_SIG`/
// `MY_SIG_INFO` for the one we were at, plus a program-specific `*_REF` field
// that lists them all when there was more than one.
//
// Every program that HaLo activates writes this same pair, so reading it back
// is one helper rather than eighteen near-identical hooks. A program whose
// files say something this shape cannot express registers its own
// `adifImport` hook instead — the helper is a convenience, not the interface.
//
// Types come in by relative path, not the `@ham2k/extension-sdk` alias,
// so this module's tests can run under plain `node --test` — the constraint
// dxcc.ts and scoring.ts document.

import type { AdifImportHook, AdifImportResult, HookContext, Ref } from "./types.ts"

export interface ActivityAdifImportRules {
  /// The program's `SIG` value, compared case-insensitively — 'POTA'.
  sig: string
  /// Ref type for a reference the other station was at — 'pota'. Omit for an
  /// award that only recognises activations, as several of the castle and
  /// lighthouse programs do: then `SIG_INFO` on an incoming record describes
  /// something this program has no ref type for, and importing it would
  /// invent one.
  huntingType?: string
  /// Ref type for a reference we were at — 'potaActivation'.
  activationType: string
  /// The program's own multi-reference field, lowercased, without the `MY_`
  /// prefix — 'pota_ref'. Omit for a program that writes only SIG_INFO.
  refField?: string
  /// Normalizes a reference as written into the form HaLo stores. Applied to
  /// every reference; one that returns empty is dropped.
  normalize?: (ref: string) => string
}

/// The first argument that is neither absent NOR empty. ADIF files carry empty
/// tags routinely, and for every purpose here an empty field means the same
/// thing as a missing one.
function present(...values: (string | undefined)[]): string | undefined {
  return values.find((v) => v !== undefined && v !== '')
}

/// Splits a `*_REF` field. Programs comma-separate; spaces appear around the
/// commas often enough to be worth tolerating.
function splitRefs(value: string): string[] {
  return value
    .split(',')
    .map((r) => r.trim())
    .filter((r) => r.length > 0)
}

/// References of one side, from BOTH sources, in file order and deduped.
///
/// Neither source subsumes the other. `*_REF` lists every reference but not
/// every program writes it — SOTA's own exports carry `SOTA_REF` and no `SIG`
/// at all, while plenty of other software writes the same summit only as
/// `SIG`/`SIG_INFO`. Reading whichever is present and merging is the only rule
/// that loses nothing.
///
/// The union is safe precisely because it dedupes: taking `SIG_INFO` in
/// PREFERENCE to the list would import an n-fer as a one-fer, since `SIG_INFO`
/// names only the primary reference. Taking both cannot, because the primary
/// is already in the list.
function refsFor(
  fields: Record<string, string>,
  sigField: string,
  sigInfoField: string,
  listField: string | undefined,
  rules: ActivityAdifImportRules,
): string[] {
  const found: string[] = []

  const list = listField ? fields[listField] : undefined
  if (list) found.push(...splitRefs(list))

  // The list field is program-specific, so its presence alone identifies the
  // program. SIG_INFO does not — check that SIG names us before claiming it,
  // or every program would import every other program's references.
  // `_intl` is the UTF-8 spelling of the same field; a logger writing accented
  // reference names emits it instead of the plain one. `present` rather than
  // `??`: ADIF files carry empty tags routinely, and `??` only skips
  // undefined — so an empty `SIG_INFO_INTL` would shadow a real `SIG_INFO`
  // and drop every reference in the log.
  if (present(fields[`${sigField}_intl`], fields[sigField])?.toUpperCase() === rules.sig.toUpperCase()) {
    const info = present(fields[`${sigInfoField}_intl`], fields[sigInfoField])
    if (info) found.push(...splitRefs(info))
  }

  return found
}

/// Builds an `adifImport` hook for a reference program that writes the
/// standard SIG/SIG_INFO pair.
export function activityAdifImport(rules: ActivityAdifImportRules): AdifImportHook {
  const listField = rules.refField
  const myListField = rules.refField ? `my_${rules.refField}` : undefined

  function refsForOneRecord(fields: Record<string, string>): AdifImportResult | null {
    const refs: Ref[] = []

    // The activation belongs to the OPERATION, the hunted reference to the
    // contact. ADIF flattens both onto every record and this hook only ever
    // sees one record, so it tags where each goes and the importer places it.
    for (const [type, sigField, sigInfoField, field, scope] of [
      [rules.huntingType, 'sig', 'sig_info', listField, undefined],
      [rules.activationType, 'my_sig', 'my_sig_info', myListField, 'operation'],
    ] as const) {
      if (!type) continue
      // Deduped AFTER normalizing, not before: the same summit reaches here as
      // `SOTA_REF: W2/GC-001` and `SIG_INFO: w2/gc-001`, which are one
      // reference and two raw strings.
      const seen = new Set<string>()
      for (const raw of refsFor(fields, sigField, sigInfoField, field, rules)) {
        const ref = rules.normalize ? rules.normalize(raw) : raw
        // `seen.has` then `seen.add` — JS `Set.add` returns the Set, so
        // testing its result would dedupe nothing at all.
        if (!ref || seen.has(ref)) continue
        seen.add(ref)
        refs.push(scope ? { type, ref, for: scope } : { type, ref })
      }
    }

    return refs.length > 0 ? { refs } : null
  }

  return {
    async refsForRecords(
      { records }: { records: { fields: Record<string, string> }[] },
      _ctx: HookContext,
    ): Promise<(AdifImportResult | null)[]> {
      return records.map((record) => refsForOneRecord(record.fields ?? {}))
    },
  }
}
