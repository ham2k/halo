// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Activity exports: one submittable log PER ACTIVATED REFERENCE.
//
// Activate two parks at once and you owe the program two logs, one claiming
// each — same contacts, each file naming its own reference. That is the
// convention across the reference programs, and it is a different axis from
// the per-record split in `adifFields.fieldCombinationsForOneQSO`, which
// multiplies by the references the OTHER station was at, WITHIN one file
// (docs/design/activities.md §3.2).
//
// Needs nothing from the core. `exportType` is opaque to it and round-trips
// verbatim into `generateExport`, and the Exports panel keys selections by
// `hookKey:exportType` — so encoding the reference into the exportType is
// enough to offer several options from one hook and know which was chosen.
//
// The QSO set is the core's business, not ours: declaring `refType` makes it
// hand `generateExport` only the contacts made while this activity was actually
// running, which is what keeps a park activated after
// a break from claiming the whole day's log.
//
// Types and `hooks` come in by relative path, not the
// `@ham2k/halo-extension-sdk` alias, so this module's tests can run under plain
// `node --test` — the constraint dxcc.ts and scoring.ts document.

import type {
  ExportOption,
  ExportOptionsRequest,
  ExportRequest,
  ExportResult,
  HookContext,
  JSONValue,
} from "./types.ts"
import { exportFilename, startMillisOf } from "./exportNames.ts"
import { createCachedTranslator } from "./i18n.ts"

import en from "./i18n/activityExports.en.json" with { type: "json" }
import es from "./i18n/activityExports.es.json" with { type: "json" }

/// Shared by every activity that registers `activityExportHook`, so POTA's and
/// SOTA's exports are named the same way in every language.
const tFor = createCachedTranslator({ en: { translation: en }, es: { translation: es } })

export interface ActivityExportRules {
  /// The extension's key, which namespaces the exportType — 'pota'.
  key: string
  /// Short program name for the option label — 'POTA'.
  label: string
  /// The ref type an operation carries while activating ('potaActivation').
  activationType: string
  icon?: string
}

/// Separates the program's own exportType prefix from the reference it names.
///
/// A colon CAN appear in a reference — `custom` lets the operator type one
/// freely — which is why the split is by prefix LENGTH below rather than by
/// searching for a colon. Don't switch this to `split(':')`: it would truncate
/// such a reference and then fail to match it back against the operation.
const SEPARATOR = ':'

interface ActivationRef {
  ref: string
  name?: string
}

function activationRefsOf(operation: Record<string, JSONValue>, type: string): ActivationRef[] {
  const refs = (operation.refs as Record<string, JSONValue>[] | undefined) ?? []
  return refs
    .filter((r) => r && r.type === type && typeof r.ref === 'string' && r.ref.length > 0)
    .map((r) => ({ ref: r.ref as string, name: typeof r.name === 'string' ? r.name : undefined }))
}

/// Shared by the option listing and the generated result, which must agree —
/// the panel shows one and the core writes the other, so two copies of this
/// expression would eventually disagree in front of the user. (The core also
/// prefers the offered name over this one, so the promise holds even if they
/// do; this keeps them honest for a hook invoked outside the panel.)
function filenameFor(
  operation: Record<string, JSONValue>,
  qsos: Record<string, JSONValue>[],
  ref: string,
  compact?: boolean,
): string {
  return exportFilename({
    stationCall: operation.stationCall,
    ref,
    startAtMillis: startMillisOf(operation, qsos),
    extension: 'adi',
    compact,
  })
}

/// An `ExportHook` offering one ADIF per activated reference. Register it
/// alongside the activity's other hooks:
///
/// ```ts
/// registerHook('export', { hook: activityExportHook(POTA_EXPORTS), key: 'pota' })
/// ```
export function activityExportHook(rules: ActivityExportRules) {
  const prefix = `${rules.key}-adif`

  return {
    async suggestExportOptions(
      { operation, qsos, compactFilenames }: ExportOptionsRequest,
      ctx: HookContext,
    ): Promise<ExportOption[]> {
      // No activation, nothing to submit. A pure hunting log is the plain ADIF
      // export's business, not ours.
      const refs = activationRefsOf(operation, rules.activationType)
      const t = tFor(ctx)

      return refs.map((ref) => ({
        exportType: `${prefix}${SEPARATOR}${ref.ref}`,
        format: 'adif',
        // The FORMAT leads: a park activated on a contest weekend offers
        // several files for the same reference, and "POTA US-1234" alone said
        // nothing about which of them this was.
        label: t('adifForRef', { program: rules.label, ref: ref.ref }),
        // The WHOLE log's first QSO dates the file, not this reference's
        // slice: the slice isn't known until `generateExport`, and a name
        // that changed between being shown and being written would break the
        // panel's promise.
        filename: filenameFor(operation, qsos ?? [], ref.ref, compactFilenames),
        icon: rules.icon,
        selectedByDefault: true,
        // Segment slicing: only the contacts made while this activity ran.
        refType: rules.activationType,
      }))
    },

    async generateExport(args: ExportRequest, ctx: HookContext): Promise<ExportResult> {
      // Answer ONLY for the exportTypes suggested above. A hook that answers
      // for one it never offered makes the ADIF delegation below recurse into
      // itself and hang the export (see contest_export_test.dart).
      const exportType = String(args.exportType ?? '')
      if (!exportType.startsWith(`${prefix}${SEPARATOR}`)) {
        throw new Error(`${rules.key}: unknown export type '${exportType}'`)
      }
      const wanted = exportType.slice(prefix.length + SEPARATOR.length)

      // The option was listed from the operation's refs, but the two are read
      // at different moments — remove a park between opening the Exports panel
      // and running it and `wanted` is gone. Filtering to nothing below would
      // then produce a perfectly valid ADIF that claims no reference at all,
      // which is worse than failing: it looks submittable and isn't.
      if (!activationRefsOf(args.operation, rules.activationType).some((r) => r.ref === wanted)) {
        throw new Error(`${rules.key}: operation has no ${rules.activationType} reference '${wanted}'`)
      }

      // The whole point of the split: this file claims ONE reference, so the
      // operation the ADIF exporter sees carries only that one and every record
      // names it. Other activities' refs are left alone — a park that is also a
      // summit still says so in the POTA file.
      const refs = ((args.operation.refs as Record<string, JSONValue>[] | undefined) ?? []).filter(
        (r) => r?.type !== rules.activationType || r?.ref === wanted,
      )
      const operation = { ...args.operation, refs: refs as unknown as JSONValue }

      const content = await adifFor({
        operation,
        qsos: args.qsos,
        includePrivateData: args.includePrivateData,
      })
      return {
        filename: filenameFor(args.operation, args.qsos, wanted, args.compactFilenames),
        mimeType: 'text/plain',
        content,
      }
    },
  }
}

/// Delegates to the core ADIF exporter inside the runtime (no bridge crossing),
/// so an activity's file is byte-identical to a normal export of the same
/// narrowed operation. `invokeOne`, not `invokeAll` — see the guard above.
async function adifFor(
  { operation, qsos, includePrivateData }: {
    operation: Record<string, JSONValue>
    qsos: Record<string, JSONValue>[]
    includePrivateData?: boolean
  },
): Promise<string> {
  // Imported dynamically, as simple-contest does: a static import of the SDK
  // barrel from inside the SDK is circular (the barrel re-exports this module),
  // and it would drag `defineExtension` — which needs the kernel global — into
  // this module's `node --test` runs.
  const { hooks } = await import("@ham2k/halo-extension-sdk")
  const entries = await hooks.invokeOne('export', 'adif', 'generateExport', {
    operation,
    qsos,
    exportType: 'adif',
    // Forwarded, or the delegate defaults to withholding and the user's
    // "include private info" setting silently does nothing here.
    includePrivateData,
  })
  const adif = entries.find((e) => e.ok)
  return ((adif?.value as ExportResult | undefined)?.content) ?? ''
}
