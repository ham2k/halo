// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Generic Simple Contest. The smallest end-to-end contest: a single free-form
// exchange, one point per contact, dupes on the same band+mode. Ported from
// app-polo's SimpleContestExtension.
//
// It is deliberately the first contest ported (docs/design/contests.md §6): it
// exercises the whole pipeline — operation setup, a typed exchange, scoring,
// and both ADIF and Cabrillo export — with no data files, serial numbers or
// multipliers to obscure the infrastructure work.
//
// Registers:
//   activity            — the setup fields and the on-air exchange control
//   ref:simple-contest  — validation and the operation title
//   scoring             — a ContestScorer, ref-gated to this contest
//   adifFields          — CONTEST_ID / STX_STRING / SRX_STRING
//   export              — contest ADIF options plus a Cabrillo file

import { contestScorer, defineExtension } from "@ham2k/halo-extension-sdk"
import type {
  ExportOption,
  ExportOptionsRequest,
  ExportRequest,
  ExportResult,
  HookContext,
  JSONValue,
  LoggingControlDescriptor,
  Ref,
} from "@ham2k/halo-extension-sdk"

import { qsonToCabrillo } from "./cabrillo.ts"
import { tFor } from "./i18n.ts"
import { SimpleContestScorer } from "./scorer.ts"

import manifest from "../manifest.json" with { type: "json" }

const TYPE = 'simple-contest'

function refOfType(container: Record<string, JSONValue>, type: string): Record<string, JSONValue> | undefined {
  const refs = (container.refs as Record<string, JSONValue>[] | undefined) ?? []
  return refs.find((r) => r?.type === type)
}

function str(value: JSONValue | undefined): string {
  return typeof value === 'string' ? value : ''
}

/// The contest identifier the operator set at setup, defaulting to app-polo's
/// "TEST" so an unconfigured operation still exports something sane.
function contestId(operation: Record<string, JSONValue>, ctx: HookContext): string {
  return str(refOfType(operation, TYPE)?.contestIdentifier) || tFor(ctx)('defaultContestId')
}

const ActivityHook = {
  /// Setup, stored on the operation's own contest ref: which contest this is,
  /// and the exchange we send. Delivered as a `FormDefinition` rather than
  /// individual controls — operation setup is form-shaped, and reusing the form
  /// schema keeps enum fields (a mode, a station type) available to the
  /// contests that follow without growing the input catalog
  /// (docs/design/contests.md §5.4).
  async operationControls(
    _args: { operation: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    const t = tFor(ctx)
    return [
      {
        key: 'simple-contest/setup',
        // Names the contest family, not the act of configuring it — this is
        // what the Activity Types list shows, where "… Setup" reads as a
        // settings screen rather than the thing being added. The dialog itself
        // still says "Setup" below, matching the other three contests.
        label: t('activityLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        input: {
          kind: 'form',
          refType: TYPE,
          form: {
            title: t('setupLabel'),
            elements: [
              {
                type: 'field',
                fieldType: 'text',
                key: 'contestIdentifier',
                label: t('contestIdLabel'),
                placeholder: t('contestIdPlaceholder'),
                uppercase: true,
              },
              {
                type: 'field',
                fieldType: 'text',
                key: 'exchange',
                label: t('sentExchangeLabel'),
                placeholder: t('exchangePlaceholder'),
                uppercase: true,
              },
            ],
          },
        },
      },
    ]
  },

  /// The one field typed per QSO. `qso` carries `their.guess` from the callsign
  /// lookup, so the received state makes a reasonable hint — a placeholder, not
  /// a suggested value, since a contest exchange is rarely just the state.
  async loggingControls(
    args: { operation: Record<string, JSONValue>; qso?: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    // Off-contest, contribute nothing. This is an OPTIMIZATION, not the rule:
    // the core already refuses a primary field to any activity the operation
    // isn't running (halo_widgets' `_textControls`), so forgetting this guard
    // is invisible to the operator. What it saves is the work below — a country
    // -file annotation per keystroke-triggered refresh, in the JS isolate,
    // multiplied by every contest extension the user happens to have enabled.
    if (!refOfType(args.operation, TYPE)) return []

    const t = tFor(ctx)
    const their = ((args.qso?.their as Record<string, JSONValue>) ?? {})
    const guess = (their.guess as Record<string, JSONValue>) ?? {}
    // Only a real guess for this QSO — an example exchange as placeholder
    // would read as a value the operator had already entered.
    const hint = str(their.state) || str(guess.state)

    return [
      {
        key: 'simple-contest/exchange',
        label: t('exchangeLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        optionType: 'optional',
        input: { kind: 'text', refType: TYPE, field: 'exchange', placeholder: hint || undefined },
      },
    ]
  },

  /// Mirrors the exchange this contest keeps on its own ref into the generic
  /// `their.exchange`. Nothing outside this extension knows to look inside a
  /// contest ref, so without this the QSO row's exchange column and a plain
  /// (non-contest) ADIF export both come up empty on a contest log.
  ///
  /// Only ever a projection: the ref stays the source of truth, and the patch
  /// touches exactly one field.
  async processQsoBeforeSave(
    args: { qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
    _ctx: HookContext,
  ): Promise<Record<string, JSONValue> | null> {
    if (!refOfType(args.operation, TYPE)) return null
    // the whole free-form exchange
    const qsoRef = refOfType(args.qso, TYPE)
    const exchange = str(qsoRef?.exchange)
    // A field the operator EMPTIED is present-but-blank rather than absent (see
    // `_refsWithTextValues`). Returning null there would leave the previous
    // save's `their.exchange` showing in the QSO row and in a plain ADIF export,
    // so a cleared exchange has to project the blank.
    if (!exchange) return qsoRef && 'exchange' in qsoRef ? { their: { exchange: '' } } : null
    return { their: { exchange } }
  },
}

const RefHandler = {
  async validateRef({ ref }: { ref: Ref }, _ctx: HookContext) {
    // Any exchange the operator types is acceptable — this contest makes no
    // claim about the format, which is the point of it being generic.
    return { valid: true, normalized: (ref.ref ?? '').trim() }
  },

  /// A contest ref has no reference *code* the way a park or summit does, so
  /// without this the Activities list would render it as "?". Label it with the
  /// contest identifier the operator set, falling back to the extension's name
  /// before setup has happened.
  async decorateRef({ ref }: { ref: Ref }, ctx: HookContext): Promise<Ref> {
    const id = str((ref as Record<string, JSONValue>).contestIdentifier)
    const sent = str((ref as Record<string, JSONValue>).exchange)
    const label = id || tFor(ctx)('unconfigured')
    return { ...ref, program: 'Contest', label, shortLabel: label, name: sent || undefined }
  },

  async suggestOperationTitle(
    { ref, operation }: { ref: Ref; operation: Record<string, JSONValue> },
    ctx: HookContext,
  ) {
    const id = str((ref as Record<string, JSONValue>).contestIdentifier) || contestId(operation, ctx)
    return { for: id, subtitle: str((ref as Record<string, JSONValue>).exchange) || undefined }
  },
}

const AdifFieldsHook = {
  async fieldsForOneQSO(
    { qso, operation }: { qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<{ name: string; value: string }[]> {
    const opRef = refOfType(operation, TYPE)
    if (!opRef) return []

    const fields: { name: string; value: string }[] = [{ name: 'CONTEST_ID', value: contestId(operation, ctx) }]
    const sent = str(opRef.exchange)
    const received = str(refOfType(qso, TYPE)?.exchange)
    if (sent) fields.push({ name: 'STX_STRING', value: sent })
    if (received) fields.push({ name: 'SRX_STRING', value: received })
    return fields
  },
}

/// Cabrillo wants an RST alongside each exchange; a contest that doesn't log
/// them still has to emit something, so fall back to the mode's conventional
/// default the way app-polo does.
function reportFor(qso: Record<string, JSONValue>, side: 'our' | 'their'): string {
  const sideData = (qso[side] as Record<string, JSONValue>) ?? {}
  const sent = str(sideData.sent)
  if (sent) return sent
  const mode = str(qso.mode)
  return mode === 'CW' || mode === 'RTTY' ? '599' : '59'
}

const ExportHook = {
  async suggestExportOptions(args: ExportOptionsRequest, ctx: HookContext): Promise<ExportOption[]> {
    if (!refOfType(args.operation, TYPE)) return []
    const t = tFor(ctx)
    return [
      { exportType: 'contest-adif', format: 'adif', label: t('adifExport'), selectedByDefault: true },
      { exportType: 'cabrillo', format: 'cabrillo', label: t('cabrilloExport'), selectedByDefault: true },
    ]
  },

  async generateExport(args: ExportRequest, ctx: HookContext): Promise<ExportResult> {
    // Only the two exportTypes `suggestExportOptions` above offers. Belt and
    // braces alongside the keyed `invokeOne` below: a hook that answers for an
    // exportType it never offered is how the ADIF delegation recursed into
    // itself in the first place.
    if (args.exportType !== 'cabrillo' && args.exportType !== 'contest-adif') {
      return { filename: '', mimeType: '', content: '' }
    }

    const operation = args.operation
    const opRef = refOfType(operation, TYPE)
    const id = contestId(operation, ctx)
    const ourCall = str(operation.stationCall)
    const stamp = `${id}-${ourCall || 'log'}`.replace(/[^A-Za-z0-9_-]+/g, '-')

    if (args.exportType === 'cabrillo') {
      const content = qsonToCabrillo(args.qsos, {
        headers: [
          ['CONTEST', id],
          ['CALLSIGN', ourCall],
          ['OPERATORS', str((operation.local as Record<string, JSONValue>)?.operatorCall)],
          ['GRID-LOCATOR', str(operation.grid)],
        ],
        qsoParts: (qso) => [
          ourCall || '-',
          reportFor(qso, 'our'),
          str(opRef?.exchange) || '-',
          str(((qso.their as Record<string, JSONValue>) ?? {}).call) || '-',
          reportFor(qso, 'their'),
          str(refOfType(qso, TYPE)?.exchange) || '-',
        ],
      })
      return { filename: `${stamp}.log`, mimeType: 'text/plain', content }
    }

    // ADIF is produced by the core `adif` extension, which composes every
    // `adifFields` contribution — including this contest's above — so there is
    // nothing contest-specific to build here beyond naming the file.
    const adif = await hooksInvokeAdif(args, ctx)
    return { filename: `${stamp}.adi`, mimeType: 'text/plain', content: adif }
  },
}

/// Delegates to the core ADIF exporter inside the runtime (no bridge crossing),
/// so contest ADIF is byte-identical to a normal export plus this extension's
/// CONTEST_ID/STX/SRX fields.
async function hooksInvokeAdif(args: ExportRequest, _ctx: HookContext): Promise<string> {
  const { hooks } = await import("@ham2k/halo-extension-sdk")
  // invokeOne, NOT invokeAll: the fan-out includes this contest's own
  // `generateExport`, which would take the same ADIF branch and delegate
  // again — unbounded recursion that only surfaced as a 30s export timeout.
  const entries = await hooks.invokeOne('export', 'adif', 'generateExport', {
    operation: args.operation,
    qsos: args.qsos,
    exportType: 'adif',
  })
  const adif = entries.find((e) => e.ok)
  return ((adif?.value as ExportResult | undefined)?.content) ?? ''
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook('activity', { hook: ActivityHook, key: TYPE })
    registerHook(`ref:${TYPE}`, { hook: RefHandler, key: TYPE })
    registerHook('adifFields', { hook: AdifFieldsHook, key: TYPE })
    registerHook('export', { hook: ExportHook, key: TYPE })
    // Ref-gated: the core skips this scorer entirely on operations that don't
    // carry a simple-contest ref, rather than invoking it to be told "not mine".
    registerHook('scoring', {
      hook: contestScorer(SimpleContestScorer, { scope: { refTypes: [TYPE] } }),
      key: TYPE,
    })
  },
})
