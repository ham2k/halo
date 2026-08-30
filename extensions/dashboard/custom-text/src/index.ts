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
//
// The text is a TEMPLATE (docs/extensions/templates.md), so the same pane
// can show the log's own numbers, and it is the reference for per-instance
// triggers for the same reason it is the reference for `multiple`: what one
// operator's text asks for is not what another's does, and a band plan that
// never changes must not be re-rendered on every keystroke because the pane
// beside it names the callsign being typed.

import { TemplateError, defineExtension, renderTemplate, templateContext, triggersForTemplate } from "@ham2k/extension-sdk"
import type { HookContext, PanelContent, PanelDescriptor, PanelHook, PanelRenderArgs } from "@ham2k/extension-sdk"

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
        // No triggers HERE: a descriptor's are paid by every placement, and
        // most panes hold static text. What a pane needs depends on what its
        // operator wrote in it, so each render declares its own
        // (`PanelContent.triggers`).
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
            description:
              "Markdown: **bold**, *italic*, # headings, - lists, [links](https://example.com). " +
              "Templates too: {{ op.station }}, {{ op.qsoCount }}, {{ now | date: '%H:%M' }}Z, " +
              "{% if qso %}{{ qso.their.call }}{% endif %}",
          },
        ],
      },
    ]
  },

  async render(args: PanelRenderArgs, ctx: HookContext): Promise<PanelContent> {
    const title = typeof args.config?.title === "string" ? args.config.title.trim() : ""
    const content = typeof args.config?.content === "string" ? args.config.content.trim() : ""

    // Both the text and the tab name, so a pane can be called after what it
    // shows ("142 QSOs"). Derived from both for the same reason.
    const triggers = [...new Set([...triggersForTemplate(content), ...triggersForTemplate(title)])]

    const context = templateContext({
      operation: args.operation,
      qso: args.qso,
      qsoCount: args.qsoCount,
      config: args.config,
      appName: ctx.appName,
    })

    // Rendered separately from the content, and its failure is not the
    // content's: a typo in a two-word tab name would otherwise replace a
    // working document with an error block. A tab that can't be rendered
    // falls back to the descriptor's title rather than showing its own
    // source, which is what the operator would read as the panel breaking.
    //
    // Before the empty-content case below, not after: a pane named
    // `{{ op.qsoCount }} QSOs` with nothing written in it yet would
    // otherwise wear its own template as its label.
    let renderedTitle = ""
    try {
      renderedTitle = renderTemplate(title, context).trim()
    } catch {
      renderedTitle = ""
    }

    if (!content) {
      return {
        kind: "markdown",
        // An empty pane looks like a panel that failed rather than one nobody
        // has filled in yet, and the gear it points at is the only way to fix
        // that — an operator who cannot find it just sees a blank pane.
        content: "_Nothing here yet. Open this panel's settings to write something._",
        // Blank is dropped by the host, so an untitled pane keeps "Custom
        // Text" rather than losing its label entirely.
        title: renderedTitle,
        triggers,
      }
    }

    try {
      return { kind: "markdown", content: renderTemplate(content, context), title: renderedTitle, triggers }
    } catch (e) {
      // The operator's own text is shown BELOW the error, never replaced by
      // it. Notes written before this panel could template — or holding a
      // `{{TODO}}`, or a fenced code sample — parse as a broken template on
      // the first launch after an update, and a pane that answered by
      // deleting what somebody wrote would be the worse failure by far.
      // liquid's message names the line, so the fix is still findable.
      const message = e instanceof TemplateError ? e.message : String(e)
      return {
        kind: "markdown",
        content: `**Template error**\n\n\`\`\`\n${message}\n\`\`\`\n\n---\n\n${content}`,
        title: renderedTitle,
        // Kept, so fixing the template doesn't ALSO require a trigger to
        // fire before the pane recovers — the config edit re-renders it.
        triggers,
      }
    }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("panel", { key: "custom-text", hook: CustomTextPanel })
  },
})
