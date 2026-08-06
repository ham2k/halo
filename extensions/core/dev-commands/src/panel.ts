// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A developer-mode panel for the customizable layout (docs/extensions/hooks.md,
// `panel`): shows what the host actually hands a panel, which is otherwise
// only visible by reading the host's source. It is the reference
// implementation of the hook as much as a tool — one extension, one panel,
// declared triggers, a config form and a preview image.
//
// Hidden unless developer mode is on: a normal operator has no business
// finding "Panel Context" in their layout list, the same rule the dev
// commands follow about the command palette.

import type { HookContext, PanelContent, PanelDescriptor, PanelHook, PanelRenderArgs } from "@ham2k/halo-extension-sdk"

/// A flat dashboard glyph, as a data-free inline SVG — a preview must carry
/// its own pixels (no URL), so it stays small enough to sit in a
/// descriptor.
const PREVIEW = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <rect x="2" y="3" width="9" height="8" rx="1" fill="#00b4e6"/>
  <rect x="13" y="3" width="9" height="18" rx="1" fill="#006783"/>
  <rect x="2" y="13" width="9" height="8" rx="1" fill="#006783"/>
</svg>`

function line(label: string, value: unknown): string {
  return `**${label}:** ${value === undefined || value === null ? "—" : String(value)}`
}

export const PanelContextPanel: PanelHook = {
  async getPanels(_args: Record<string, never>, ctx: HookContext): Promise<PanelDescriptor[]> {
    if (!ctx.developerMode) return []
    return [
      {
        key: "context",
        title: "Panel Context",
        description: "What the host passes an extension panel, and when",
        icon: "bug",
        preview: PREVIEW,
        // Everything the host fires, plus a slow tick. `qso` is included
        // deliberately even though it is the expensive one: this panel
        // exists to show what arrives and when, and the debounce it lands
        // behind is the thing a developer most needs to see working.
        on: ["operation", "qso", "qsoLogged", "lookup", "spots", "tick:30"],
        form: [
          {
            type: "field",
            key: "showOperation",
            fieldType: "checkbox",
            label: "Include the operation's raw data",
            description: "The whole QSON payload, which is long",
          },
        ],
      },
    ]
  },

  async render(args: PanelRenderArgs, ctx: HookContext): Promise<PanelContent> {
    const { operation, qso, qsoCount, config, reason } = args
    const their = qso?.their as Record<string, unknown> | undefined
    const guess = their?.guess as Record<string, unknown> | undefined
    const parts = [
      "## Panel Context",
      "",
      line("Rendered because", reason),
      line("Operation", operation?.uuid),
      line("QSOs", qsoCount),
      line("Composing", their?.call),
      // Proves the lookup travels INSIDE the draft, which is why 'lookup'
      // carries no payload of its own.
      line("Looked up", guess?.name ?? guess?.call),
      line("Band / mode", qso ? `${qso.band ?? "—"} / ${qso.mode ?? "—"}` : undefined),
      line("Developer mode", ctx.developerMode),
      line("Online", ctx.online),
      line("Locale", ctx.locale),
      line("Config", JSON.stringify(config)),
    ]
    if (config?.showOperation) {
      parts.push("", "```json", JSON.stringify(operation, null, 2), "```")
    }
    return { kind: "markdown", content: parts.join("\n") }
  },
}
