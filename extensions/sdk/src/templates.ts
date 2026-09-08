// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one templating engine, for every place HaLo turns log data into text:
// panel documents, export filenames, ADIF field values (see
// docs/extensions/templates.md for the vocabulary each surface offers).
//
// Liquid, not Handlebars — app-polo's engine — for one reason that matters
// here: a template is DATA. Liquid parses and interprets, while Handlebars
// compiles through `new Function`, and these templates arrive from operators,
// get copied between operators, and will eventually be editable in settings.
// A template that can't become code can't become a hazard. The cost of the
// choice is that polo's `{{#if}}`/`{{>partial}}` don't carry over, though the
// plain `{{ op.date }}` majority of polo's templates parse unchanged.
//
// **Every caller goes through here rather than constructing a Liquid.** The
// option set below is the contract — a second engine instance built elsewhere
// would silently disagree about timezones, which is the one mistake in this
// area that testers can't see.

import { Liquid, type Template } from "liquidjs"

/// How long one render may run before it is abandoned, in milliseconds.
///
/// Liquid loops are bounded only by what the template asks for:
/// `{% for i in (1..2000000) %}` renders two million times, and a panel
/// template runs inside the host's five-second render budget. A limit turns
/// an operator's runaway loop into an error message about that template
/// instead of a frozen pane.
const RENDER_LIMIT_MS = 250

let engine: Liquid | undefined

/// The shared engine, built on first use.
///
/// Deliberately NOT eager: most bundles never render a template, and the
/// kernel evaluates every enabled one at startup.
function liquid(): Liquid {
  if (engine) return engine
  engine = new Liquid({
    // UTC, always. Amateur radio logs are kept in UTC, and liquid's `date`
    // filter otherwise formats in the HOST's zone — wrong in a way no
    // tester in UTC±0 can see, exactly like `toLocaleString` with a
    // `timeZone` on this engine (docs/extensions/README.md).
    //
    // The sign is INVERTED from what the name suggests: this follows
    // `Date.getTimezoneOffset()`, i.e. minutes BEHIND UTC, so -300 would
    // render UTC+5. Zero is the only value with no trap in it.
    timezoneOffset: 0,
    // Lenient, because most templates are written by operators rather than
    // by us: an unknown variable renders empty and an unknown filter passes
    // its value through, so a typo costs one wrong line instead of the whole
    // document. Our own templates are covered by tests instead.
    strictVariables: false,
    strictFilters: false,
    renderLimit: RENDER_LIMIT_MS,
  })
  registerFilters(engine)
  return engine
}

/// Filters on top of liquid's own (`date`, `downcase`, `upcase`, `strip`,
/// `default`, `join`, `size`, `round`, `truncate`, `first`, `last`, …). Kept
/// to the two that liquid can't express and that the filename defaults need;
/// polo's `slug` is `downcase | dash` and so isn't one of them.
///
/// Neither name may collide with a built-in: `registerFilter` overwrites
/// silently, so shadowing one would leave a template written against liquid's
/// documentation producing plausible nonsense with no error. `alnum` is
/// named the way it is for that reason — liquid's own `compact` drops nils
/// from an ARRAY, which `op.refs` and `qso.refs` both are.
function registerFilters(liquid: Liquid): void {
  // `US-1234` → `US-1234`, `N0CALL/P` → `N0CALL-P`, `Field Day 2026` →
  // `Field-Day-2026`. Case-preserving on purpose: callsigns and references
  // are written in capitals, and stay legible in a compact filename
  // precisely because they aren't flattened. app-polo's `dash` helper.
  liquid.registerFilter("dash", (value: unknown) =>
    String(value ?? "")
      .replace(/[^A-Za-z0-9-]+/g, "-")
      .replace(/-+/g, "-")
      .replace(/^-|-$/g, ""),
  )

  // `2026-07-27` → `20260727`. app-polo's `compact` helper under a name that
  // doesn't shadow liquid's.
  liquid.registerFilter("alnum", (value: unknown) => String(value ?? "").replace(/[^A-Za-z0-9]/g, ""))
}

/// A template that failed to parse or render, carrying liquid's own message —
/// which names the line and column, and is therefore worth showing to
/// whoever wrote the template rather than replacing with a generic sentence.
export class TemplateError extends Error {
  /// Liquid's own error — a ParseError, RenderError, or a TypeError thrown
  /// inside one of OUR filters — kept rather than flattened into a string.
  /// The message alone cannot tell an operator's typo from our bug, and the
  /// second is the one whose stack somebody will want. Declared here rather
  /// than inherited: the runtime has `Error.cause`, the ES2020 lib these
  /// bundles are typed against does not.
  readonly cause?: unknown

  constructor(message: string, options?: { cause?: unknown }) {
    super(message)
    this.name = "TemplateError"
    this.cause = options?.cause
  }
}

/// Parsed templates, keyed by their source.
///
/// Parsing is the expensive half — an ADIF export renders the same field
/// template once per QSO, and a panel re-renders the same document on every
/// tick, so a ten-thousand-contact export would otherwise spend seconds
/// re-parsing one unchanged string.
const parsed = new Map<string, Template[]>()

/// Above the handful of templates any surface has, plus room for an operator
/// editing one and re-rendering as they type. Cleared rather than evicted
/// one-by-one: this is a guard against a session accumulating strings
/// forever, not a cache anyone tunes.
const PARSE_CACHE_LIMIT = 64

/// Renders `template` against `context`.
///
/// Throws [TemplateError] rather than returning a fallback: a broken
/// template is either an operator's typo, which they can only fix if they
/// are told about it, or a bug in one of ours, which tests are meant to
/// catch. Silently substituting empty text hides both — which is also why
/// `template` is required rather than defaulted: a caller that reaches here
/// with nothing has lost its template, and rendering "" would spell that as
/// an empty document.
///
/// `label` names the template in the error, for the surfaces that don't
/// catch. `line:1, col:14` is enough when the reader is looking at the pane
/// they typed it into, and useless when the message surfaces as a failed
/// export naming none of the six filename templates.
export function renderTemplate(template: string, context: Record<string, unknown>, label?: string): string {
  const source = template ?? ""
  try {
    let compiled = parsed.get(source)
    if (!compiled) {
      compiled = liquid().parse(source)
      if (parsed.size >= PARSE_CACHE_LIMIT) parsed.clear()
      parsed.set(source, compiled)
    }
    return liquid().renderSync(compiled, context)
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e)
    throw new TemplateError(label ? `${label}: ${message}` : message, { cause: e })
  }
}

/// Collapses the whitespace a template's own line breaks and empty values
/// leave behind, for text that has to be ONE line — a filename.
/// `{{ a }} {{ b }}` with no `b` would otherwise end in a space, and a
/// `{% if %}` block spanning lines would carry those newlines into the
/// value. app-polo does the same to its filenames.
///
/// The ADIF free-text fields apply it by ADIF TYPE, not uniformly: NOTES is a
/// MultilineString and keeps the operator's own line breaks, while COMMENT and
/// QSLMSG are Strings, which exclude them (`core/adif`'s
/// TEXT_FIELD_TEMPLATES).
export function oneLine(text: string): string {
  return text.replace(/\s+/g, " ").trim()
}

/// Which panel triggers a template needs, derived from the namespaces it
/// mentions (docs/extensions/templates.md). A panel that renders operator
/// text can't know what that text will ask for until it reads it, and
/// declaring the whole set unconditionally would put every custom panel on
/// the typing path.
///
/// Only the TEMPLATE spans are read — `{{ … }}` and `{% … %}` — never the
/// prose around them. A Custom Text pane is mostly prose, and English is
/// full of these words: "Goal: 100 qso today", "on the 20m dipole now", a
/// markdown link to `qrz.com/db/op`. Scanning the whole document would put
/// the operation view on the per-keystroke draft path for a static band
/// plan, which is the precise cost this exists to avoid.
///
/// Within a span it stays generous: `{% assign c = qso.their.call %}`,
/// `{{ qso.band }}` and `{% if qso %}` all count as asking for `qso`. A
/// false negative there shows an operator stale text with no clue why.
export function triggersForTemplate(template: string): string[] {
  const text = (template ?? "").match(/\{\{.*?\}\}|\{%.*?%\}/gs)?.join(" ") ?? ""
  const mentions = (name: string) => new RegExp(`\\b${name}\\b`).test(text)
  const triggers: string[] = []

  // `qso` is the draft being typed, and `lookup` is what fills in
  // `qso.their.guess` — a template naming the callsign in the field wants
  // both, or it shows the call without the name that arrives a moment later.
  if (mentions("qso")) triggers.push("qso", "lookup")
  // `qsoCount` also lives under `op`, so this is checked on its own.
  if (mentions("qsoCount")) triggers.push("qsoLogged")
  if (mentions("op") || mentions("operation")) triggers.push("operation")
  // A clock, and the age of anything the template computed from `now`.
  // 30 seconds: the finest thing a template can show is HH:MM (liquid's
  // `date` has no sub-minute need here), and the host floors ticks at
  // `minPanelTickSeconds` anyway.
  if (mentions("now")) triggers.push("tick:30")

  return triggers
}
