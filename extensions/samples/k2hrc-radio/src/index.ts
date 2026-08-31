// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// SAMPLE — an HTML panel: what the radio is doing, big enough to read from
// across the room.
//
// A panel returns a DOCUMENT, not widgets, and `html` is the escape hatch for
// when `markdown` cannot express the layout. It buys you exactly one thing —
// arbitrary CSS — and costs several:
//
//   * No JavaScript. None. The document is static from the moment it renders,
//     so anything that changes has to come from another render.
//   * No network for subresources. Fonts, images and stylesheets must be
//     inlined, as text or as `data:` URIs.
//   * No navigation. A link the operator taps opens in their browser; one the
//     document triggers itself is blocked.
//   * It does not render at all where there is no web view — Linux, Windows
//     without WebView2, and the web build. The pane says so, which is a worse
//     experience than markdown that simply works.
//
// So reach for `markdown` first: it renders with the app's own typography,
// theme, font scale and density, and costs no web view. This panel earns the
// escape hatch because a readout is about type size and nothing else.
//
// See `docs/hooks.md` §`panel` for the whole contract, including `form`,
// `multiple` and every trigger name.

import { defineExtension } from "@ham2k/extension-sdk"
import type { HookContext, PanelContent, PanelDescriptor, PanelHook, PanelRenderArgs } from "@ham2k/extension-sdk"

import manifest from "../manifest.json" with { type: "json" }

/// A still image for the panel picker. It carries its own pixels — never a URL,
/// because the list renders offline and a remote preview would make opening it
/// a network fetch (and a beacon).
const PREVIEW = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <rect x="2" y="5" width="20" height="14" rx="2" fill="#4C6EF5"/>
  <rect x="4" y="8" width="16" height="5" rx="1" fill="#1B2559"/>
  <rect x="5.5" y="9.5" width="9" height="2" rx="1" fill="#8FA4FF"/>
  <circle cx="7" cy="16" r="1.2" fill="#1B2559"/>
  <circle cx="11" cy="16" r="1.2" fill="#1B2559"/>
</svg>`

/// Everything that reaches the document goes through here.
///
/// The values below are the operator's own — a callsign they typed, a mode
/// their radio reported — and none of it is trusted markup. A panel that
/// interpolates raw strings into HTML is one odd character away from a
/// document that does not parse, and the sandbox is a mitigation, not a reason
/// to skip this.
function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
}

/// 14074000 → "14.074.0" — the grouping a radio's own display uses, which is
/// what makes a frequency readable at a glance rather than counted digit by
/// digit.
function formatFrequency(hz: number): string {
  const khz = hz / 1000
  const whole = Math.floor(khz)
  const fraction = Math.round((khz - whole) * 10)
  return `${whole.toLocaleString("en-US").replace(/,/g, ".")}.${fraction}`
}

const RadioPanel: PanelHook = {
  async getPanels(_args: Record<string, never>, _ctx: HookContext): Promise<PanelDescriptor[]> {
    return [
      {
        key: "readout",
        title: "Radio Readout",
        description: "Band, mode and frequency, in large type",
        icon: manifest.icon,
        preview: PREVIEW,
        // `on` is a refresh BUDGET, not a subscription: every trigger named
        // here is paid by every placement of this panel, every time it fires.
        //
        // 'qso' is the expensive one — it is the whole QSO being composed, and
        // it changes as fast as the operator types (the host debounces it to
        // one wake per pause). It is the right trigger here anyway, because
        // the band and mode on that draft ARE the radio's, and they are what
        // this panel exists to show. A panel wanting only a resolved callsign
        // should declare 'lookup' instead and get far fewer renders.
        on: ["qso", "operation"],
      },
    ]
  },

  async render(args: PanelRenderArgs, _ctx: HookContext): Promise<PanelContent> {
    const qso = (args.qso ?? {}) as Record<string, any>

    // `args.qso` is absent unless some panel in the arrangement asked for it —
    // which this one does. It is still absent when there is no logging panel
    // in the view at all, so the empty state is a real state, not a bug.
    const band = typeof qso.band === "string" ? qso.band : ""
    const mode = typeof qso.mode === "string" ? qso.mode : ""
    const freq = typeof qso.freq === "number" ? qso.freq : undefined

    const primary = freq ? formatFrequency(freq) : band || "—"
    const unit = freq ? "kHz" : ""

    // One inline stylesheet, no external anything, and `prefers-color-scheme`
    // rather than a fixed palette: the panel sits inside the app's own theme,
    // and a readout that stays white at night is a readout nobody uses at
    // night. `vw` units so the type grows with the pane rather than the pane
    // scrolling.
    const content = `<style>
  :root { color-scheme: light dark; }
  body {
    margin: 0; height: 100vh;
    display: flex; flex-direction: column;
    align-items: center; justify-content: center;
    font-family: ui-monospace, "SF Mono", Menlo, monospace;
    background: #fff; color: #1B2559;
  }
  .frequency { font-size: min(18vw, 22vh); font-weight: 600; line-height: 1; letter-spacing: -0.02em; }
  .unit { font-size: min(4vw, 5vh); opacity: 0.5; margin-left: 0.3em; }
  .details { margin-top: 0.6em; font-size: min(6vw, 7vh); letter-spacing: 0.08em; opacity: 0.75; }
  .details span + span::before { content: "·"; margin: 0 0.5em; opacity: 0.4; }
  .idle { opacity: 0.4; font-size: min(5vw, 6vh); }
  @media (prefers-color-scheme: dark) {
    body { background: #10121A; color: #E8ECFF; }
  }
</style>
<div class="frequency">${escapeHtml(primary)}<span class="unit">${unit}</span></div>
<div class="details">
  ${band ? `<span>${escapeHtml(band)}</span>` : ""}
  ${mode ? `<span>${escapeHtml(mode)}</span>` : ""}
  <span>${args.qsoCount} Q</span>
</div>
${freq || band ? "" : '<div class="idle">No radio connected</div>'}`

    return { kind: "html", content }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("panel", { key: manifest.key, hook: RadioPanel })
  },
})
