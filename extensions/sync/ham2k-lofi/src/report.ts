// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The REPORT command's title/body formatting. Split out from index.ts because
// it is the part with no `host` dependency: this workspace's test runner is
// plain `node --test`, which cannot resolve the SDK package specifier outside
// the esbuild bundle, so anything importing `host` is untestable here.

import type { JSONValue, VersionInfo } from "@ham2k/halo-extension-sdk"

const TITLE_MAX = 120

/// The kinds `POST v1/reports` accepts (api-lofi's
/// `ReportsController::VALID_KINDS`). It travels as a field, not as a word in
/// the title: CaBo's `createCard` writes `cmd.kind` verbatim and parses
/// nothing out of the title.
export type ReportKind = 'idea' | 'task' | 'bug'

// A type alias, not an interface: only an alias gets an implicit index
// signature, which is what makes the payload assignable to JSONValue without
// casting it through `unknown` at the call site.
export type ReportPayload = {
  title: string
  body: string
  kind: ReportKind
}

export interface ReportContext {
  version: VersionInfo
  /// The operator's own callsign. Absent when none is configured yet.
  operatorCall?: string | null
  /// The open operation as the command hook receives it, if any. REPORT works
  /// with nothing open, so every field derived from this is conditional.
  operation?: Record<string, JSONValue>
}

/// The description as a single-line card title.
///
/// Whitespace is collapsed because the command deliberately accepts pasted
/// multi-line text, and a title carrying a newline is a broken row in every
/// card list. The body keeps the description verbatim.
///
/// Truncation counts CODEPOINTS, not UTF-16 code units: slicing mid-surrogate
/// yields a lone surrogate that JSON.stringify emits as `\udXXX`, which the
/// server's JSON parser rejects outright — losing the whole report over an
/// emoji landing on the boundary.
function titleFor(text: string): string {
  const oneLine = text.replace(/\s+/g, ' ').trim()
  const chars = [...oneLine]
  return chars.length > TITLE_MAX ? `${chars.slice(0, TITLE_MAX - 1).join('')}…` : oneLine
}

/// `{type, ref}` pairs, rendered as "pota US-0001, sota W1/AM-001".
function formatRefs(operation: Record<string, JSONValue> | undefined): string | null {
  const refs = operation?.refs
  if (!Array.isArray(refs)) return null
  const formatted = refs
    .filter((r): r is Record<string, JSONValue> => !!r && typeof r === 'object' && !Array.isArray(r))
    // The value is what makes a row real — a type on its own is a row still
    // being filled in, and "pota" with no reference reports nothing.
    .filter((r) => typeof r.ref === 'string' && r.ref)
    .map((r) => (typeof r.type === 'string' && r.type ? `${r.type} ${r.ref}` : `${r.ref}`))
  return formatted.length > 0 ? formatted.join(', ') : null
}

/// Who filed this, from where, on what — the block every report carries
/// whatever surface raised it, under its own rule.
///
/// ONE line, bullet-separated. Markdown collapses consecutive lines into a
/// single paragraph, so a fact per line rendered as an unpunctuated run-on
/// ("Platform: macos Version: … SHA: …") on the card anyway. Writing the
/// separators in makes the rendering deliberate instead of accidental, and
/// keeps the block to one line in the raw text too.
///
/// Operator and station are usually the same call and deliberately both
/// reported anyway: they diverge exactly when a report is hardest to read
/// without them (club and multi-op stations).
///
/// The edition is NOT its own field: `versionName` is the edition-qualified
/// name ("August '26 (Next Edition)"), and a Regular build has no qualifier
/// precisely because it is the plain one. Naming it twice said nothing extra.
function contextLines(context: ReportContext): string[] {
  const { version, operatorCall, operation } = context

  const stationCall = operation?.stationCall
  const refs = formatRefs(operation)

  const facts = [
    ...(operatorCall ? [`Operator: ${operatorCall}`] : []),
    ...(typeof stationCall === 'string' && stationCall ? [`Station: ${stationCall}`] : []),
    ...(refs ? [`References: ${refs}`] : []),
    `Platform: ${version.platform}`,
    `Version: ${version.versionName} (${version.version})`,
    // Null on Dev, where the compiled-in build number is the last release's
    // rather than the running build's — the SHA is the only true identity
    // there, and naming a build that isn't running misdirects triage.
    ...(version.buildNumber == null ? [] : [`Build: ${version.buildNumber}`]),
    `SHA: ${version.gitSha || '(none)'}`,
  ]

  return ['---', facts.join(' • ')]
}

export function buildReportPayload(text: string, context: ReportContext): ReportPayload {
  return { title: titleFor(text), body: [text, '', ...contextLines(context)].join('\n'), kind: 'bug' }
}

/// A report whose title, body and kind were composed by the caller — the
/// equipment editor's radio report, which knows things about the radio this
/// extension has no way to ask for. Only the context block is added here, so
/// every report carries the same one however it was raised.
///
/// The title still goes through [titleFor]: a caller composing it out of
/// operator-typed fields can produce a title of any length, and the same
/// codepoint-safe truncation has to apply.
export function attachReportContext(report: ReportPayload, context: ReportContext): ReportPayload {
  return {
    title: titleFor(report.title),
    body: [report.body, '', ...contextLines(context)].join('\n'),
    kind: report.kind,
  }
}
