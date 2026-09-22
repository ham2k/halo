// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import assert from "node:assert/strict"
import { describe, it } from "node:test"

import { attachReportContext, buildReportPayload } from "./report.ts"

// Shaped as the host actually sends it (extension_service's getVersionInfo):
// `version` is the bare public version and `versionName` the display name
// built from the stage label and edition qualifier — NOT version + suffix.
const VERSION_INFO = {
  platform: "macos",
  edition: "next",
  version: "26.8.1",
  versionName: "August '26 ALPHA patch 1 (Next Edition)",
  buildNumber: 126 as number | null,
  gitSha: "abc1234",
}

const CONTEXT = { version: VERSION_INFO }

describe("buildReportPayload", () => {
  it("always files as a bug", () => {
    const payload = buildReportPayload("it crashed", CONTEXT)
    assert.equal(payload.kind, "bug")
  })

  it("uses the description as the title when short", () => {
    const payload = buildReportPayload("it crashed", CONTEXT)
    assert.equal(payload.title, "it crashed")
  })

  it("truncates a long description for the title but keeps it whole in the body", () => {
    const longText = "x".repeat(200)
    const payload = buildReportPayload(longText, CONTEXT)
    assert.equal(payload.title.length, 120)
    assert.ok(payload.title.endsWith("…"))
    assert.match(payload.body, new RegExp(longText))
  })

  it("includes platform/version/build/sha in the body", () => {
    const payload = buildReportPayload("it crashed", CONTEXT)
    assert.match(payload.body, /Platform: macos/)
    assert.match(payload.body, /Version: August '26 ALPHA patch 1 \(Next Edition\) \(26\.8\.1\)/)
    assert.match(payload.body, /Build: 126/)
    assert.match(payload.body, /SHA: abc1234/)
  })

  it("runs the context facts together on ONE bullet-separated line", () => {
    // Markdown collapses consecutive lines into one paragraph, so a fact per
    // line arrived on the card as an unpunctuated run-on. The separators have
    // to be in the text; a test asserting only that each fact is PRESENT
    // passes either way, which is how the run-on shipped in the first place.
    const payload = buildReportPayload("it crashed", {
      ...CONTEXT,
      operatorCall: "KI2D",
      operation: { stationCall: "W1AW" },
    })
    const [, ...context] = payload.body.split("---")
    const line = context.join("---").trim()
    assert.equal(line.includes("\n"), false)
    assert.equal(
      line,
      "Operator: KI2D • Station: W1AW • Platform: macos • Version: August '26 ALPHA patch 1 (Next Edition) (26.8.1) • Build: 126 • SHA: abc1234",
    )
  })

  it("does not name the edition separately from the version", () => {
    // `versionName` IS the edition-qualified name, and a Regular build has no
    // qualifier precisely because it is the plain one. A second field said
    // nothing the version did not.
    const payload = buildReportPayload("it crashed", CONTEXT)
    assert.doesNotMatch(payload.body, /Edition:/)
  })

  it("omits the build number when the host reports none", () => {
    // Null on Dev, where the compiled-in number is the last release's. A
    // "Build: null" line, or the last release's number presented as this
    // build's, both send triage to a build nobody is running.
    const payload = buildReportPayload("it crashed", { ...CONTEXT, version: { ...VERSION_INFO, buildNumber: null } })
    assert.doesNotMatch(payload.body, /Build:/)
    assert.match(payload.body, /SHA: abc1234/)
  })

  it("collapses a multi-line description into a single-line title", () => {
    // The command deliberately accepts pasted multi-line text; a title
    // carrying a newline is a broken row in every card list. The body keeps
    // the description verbatim.
    const payload = buildReportPayload("App crashed\r\nwhen saving the QSO", CONTEXT)
    assert.equal(payload.title, "App crashed when saving the QSO")
    assert.match(payload.body, /App crashed\r\nwhen saving the QSO/)
  })

  it("truncates on a codepoint boundary, never mid-surrogate", () => {
    // Slicing UTF-16 code units can cut an emoji in half; the lone surrogate
    // that leaves is emitted by JSON.stringify as \udXXX, which the server's
    // JSON parser rejects outright — losing the whole report.
    const payload = buildReportPayload(`${"a".repeat(118)}😀${"b".repeat(20)}`, CONTEXT)
    // A high surrogate with no low surrogate after it is exactly what a
    // mid-emoji cut leaves behind.
    assert.doesNotMatch(payload.title, /[\uD800-\uDBFF](?![\uDC00-\uDFFF])/)
    assert.equal([...payload.title].length, 120)
  })

  it("shows a placeholder for an empty git sha (local/dev builds)", () => {
    const payload = buildReportPayload("it crashed", { ...CONTEXT, version: { ...VERSION_INFO, gitSha: "" } })
    assert.match(payload.body, /SHA: \(none\)/)
  })

  it("reports the operator callsign", () => {
    const payload = buildReportPayload("it crashed", { ...CONTEXT, operatorCall: "KI2D" })
    assert.match(payload.body, /Operator: KI2D/)
  })

  it("reports the station call and references of the open operation", () => {
    const payload = buildReportPayload("it crashed", {
      ...CONTEXT,
      operatorCall: "KI2D",
      operation: {
        stationCall: "W1AW",
        refs: [
          { type: "pota", ref: "US-0001" },
          { type: "sota", ref: "W1/AM-001" },
        ],
      },
    })
    // Operator and station are both reported precisely because they diverge at
    // club and multi-op stations, which is when the difference matters most.
    assert.match(payload.body, /Operator: KI2D/)
    assert.match(payload.body, /Station: W1AW/)
    assert.match(payload.body, /References: pota US-0001, sota W1\/AM-001/)
  })

  it("omits operation lines entirely when nothing is open", () => {
    // REPORT works from the home screen with no operation — empty "Station:"
    // and "References:" headings would read as missing data rather than none.
    const payload = buildReportPayload("it crashed", { ...CONTEXT, operatorCall: "KI2D" })
    assert.doesNotMatch(payload.body, /Station:/)
    assert.doesNotMatch(payload.body, /References:/)
  })

  it("omits the references line for an operation that has none", () => {
    const payload = buildReportPayload("it crashed", {
      ...CONTEXT,
      operation: { stationCall: "KI2D", refs: [] },
    })
    assert.match(payload.body, /Station: KI2D/)
    assert.doesNotMatch(payload.body, /References:/)
  })

  it("skips a half-filled reference row", () => {
    // The operation editor holds a ref with a type and no value while it is
    // being filled in; reporting a bare "pota" says nothing.
    const payload = buildReportPayload("it crashed", {
      ...CONTEXT,
      operation: { refs: [{ type: "pota" }, { type: "sota", ref: "W1/AM-001" }] },
    })
    assert.match(payload.body, /References: sota W1\/AM-001/)
    assert.doesNotMatch(payload.body, /pota/)
  })

  it("omits the operator line when the callsign is not set yet", () => {
    const payload = buildReportPayload("it crashed", { ...CONTEXT, operatorCall: "" })
    assert.doesNotMatch(payload.body, /Operator:/)
  })
})

describe("attachReportContext", () => {
  const RADIO_REPORT = {
    title: "Icom IC-7300 works with issues",
    body: "Mode lags behind the radio.",
    kind: "bug" as const,
  }

  it("keeps the caller title, body and kind", () => {
    // The whole point of this entry point: a surface that knows what the card
    // should say writes it, and only the context block is added.
    const payload = attachReportContext(RADIO_REPORT, { ...CONTEXT, operatorCall: "KI2D" })
    assert.equal(payload.title, RADIO_REPORT.title)
    assert.match(payload.body, /^Mode lags behind the radio\./)
    assert.equal(payload.kind, "bug")
  })

  it("files a working radio as a task, not a bug", () => {
    // A confirmation that a pairing works is real work (marking the driver
    // verified, adding the model), not a defect. Downgrading every report to
    // `bug` would bury it in the bug queue.
    const payload = attachReportContext({ ...RADIO_REPORT, kind: "task" }, CONTEXT)
    assert.equal(payload.kind, "task")
  })

  it("adds the same context block the command gets", () => {
    const payload = attachReportContext(RADIO_REPORT, { ...CONTEXT, operatorCall: "KI2D" })
    assert.match(payload.body, /Operator: KI2D/)
    assert.match(payload.body, /Platform: macos/)
    assert.match(payload.body, /SHA: abc1234/)
  })

  it("truncates a caller-composed title on a codepoint boundary too", () => {
    // The title is built from fields the operator typed, so it has no length
    // bound of its own — and a lone surrogate reaching JSON.stringify loses
    // the whole report to the server's parser.
    const payload = attachReportContext({ ...RADIO_REPORT, title: `${"a".repeat(118)}😀${"b".repeat(20)}` }, CONTEXT)
    assert.equal([...payload.title].length, 120)
    assert.doesNotMatch(payload.title, /[\uD800-\uDBFF](?![\uDC00-\uDFFF])/)
  })
})
