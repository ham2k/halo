// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A pane holding whatever the operator writes in it. The smallest useful
// extension panel there is, and the first written to exercise the panel
// system end to end (docs/extensions/hooks.md, `panel`): a descriptor, a
// config form, host-persisted values, and markdown back out.
//
// It is also the first panel an operator would obviously want TWO of — a
// sked list beside a band plan — so it is the reference for `multiple`.
// Everything that makes several placements work is the host's: each gets
// its own id, and therefore its own config, with nothing to do here. The
// one obligation this side has is naming them, via the render result's
// `title`; without it every tab would read "Custom Text".

import { defineExtension } from "@ham2k/halo-extension-sdk"
import type { HookContext, PanelContent, PanelDescriptor, PanelHook, PanelRenderArgs } from "@ham2k/halo-extension-sdk"

import manifest from "../manifest.json"

/// A sheet of paper with a fold, in the app's own accent — a preview has to
/// carry its own pixels (no URL), so it stays small enough to sit inside a
/// descriptor.
const PREVIEW = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path d="M5 2h9l5 5v15H5z" fill="#00b4e6"/>
  <path d="M14 2v5h5z" fill="#006783"/>
  <rect x="8" y="11" width="8" height="1.5" rx=".75" fill="#fff"/>
  <rect x="8" y="14.5" width="8" height="1.5" rx=".75" fill="#fff"/>
  <rect x="8" y="18" width="5" height="1.5" rx=".75" fill="#fff"/>
</svg>`

export const CustomTextPanel: PanelHook = {
  async getPanels(_args: Record<string, never>, _ctx: HookContext): Promise<PanelDescriptor[]> {
    return [
      {
        key: "text",
        title: "Custom Text",
        description: "Your own notes, in markdown",
        icon: "note-text-outline",
        preview: PREVIEW,
        // Several placements, each with its own text. The host mints an id
        // per pane and keys config by it, so nothing here has to know how
        // many exist.
        multiple: true,
        // No triggers: this panel's content depends on its own config and
        // nothing else, and the host already re-renders when that changes.
        // Declaring any would be a bridge call per event for a document
        // that cannot have changed.
        form: [
          {
            type: "field",
            key: "title",
            fieldType: "text",
            label: "Tab name",
            description: "What this pane is called. Useful when you have more than one.",
          },
          {
            type: "field",
            key: "content",
            fieldType: "multiline",
            label: "Text",
            description: "Markdown: **bold**, *italic*, # headings, - lists, [links](https://example.com)",
          },
        ],
      },
    ]
  },

  async render(args: PanelRenderArgs, _ctx: HookContext): Promise<PanelContent> {
    const title = typeof args.config?.title === "string" ? args.config.title.trim() : ""
    const content = typeof args.config?.content === "string" ? args.config.content.trim() : ""
    return {
      kind: "markdown",
      // An empty pane looks like a panel that failed rather than one nobody
      // has filled in yet, and the gear it points at is the only way to fix
      // that — an operator who cannot find it just sees a blank pane.
      content: content || "_Nothing here yet. Open this panel's settings to write something._",
      // Blank is dropped by the host, so an untitled pane keeps "Custom
      // Text" rather than losing its label entirely.
      title,
    }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("panel", { key: "custom-text", hook: CustomTextPanel })
  },
})
