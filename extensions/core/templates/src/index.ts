// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The `template` hook: the app hands over a template and what it is about,
// and gets the rendered text back. The renderer (docs/extensions/templates.md)
// lives in the SDK and runs only inside the extension runtime, so a surface
// on the Dart side that wants `{{ qso.call }}` filled in — a CW message
// about to be keyed — has no way to it but a hook. This is that hook, and
// nothing else: the same `templateContext` every panel and export builds,
// so a placeholder means the same thing in a CW message as in a pane.

import { TemplateError, defineExtension, renderTemplate, templateContext } from "@ham2k/extension-sdk"
import type { HookContext, JSONValue } from "@ham2k/extension-sdk"

import manifest from "../manifest.json" with { type: "json" }

export interface TemplateRenderArgs {
  template: string
  operation?: Record<string, JSONValue>
  qso?: Record<string, JSONValue>
  qsoCount?: number
}

/// `text` on success; `error` — the renderer's own message — when the
/// template does not parse. Never both, and never a throw: a message with a
/// typo in it is an operator mistake to show, not a bridge failure.
export type TemplateRenderResult = { text: string } | { error: string }

export interface TemplateRenderManyArgs {
  templates: string[]
  operation?: Record<string, JSONValue>
  qso?: Record<string, JSONValue>
  qsoCount?: number
}

function renderOne(template: string, context: Record<string, unknown>): TemplateRenderResult {
  try {
    return { text: renderTemplate(template ?? "", context) }
  } catch (e) {
    if (e instanceof TemplateError) return { error: e.message }
    throw e
  }
}

const TemplateHook = {
  async render(args: TemplateRenderArgs, ctx: HookContext): Promise<TemplateRenderResult> {
    const context = templateContext({
      operation: args.operation,
      qso: args.qso,
      qsoCount: args.qsoCount,
      appName: ctx.appName,
    })
    return renderOne(args.template, context)
  },

  /// Several templates against ONE context, in one crossing — the keyer
  /// area's button labels, re-rendered together on every draft pause. One
  /// result per template, in order; a template that does not parse gets its
  /// own `error` without spoiling the others.
  async renderMany(args: TemplateRenderManyArgs, ctx: HookContext): Promise<{ results: TemplateRenderResult[] }> {
    const context = templateContext({
      operation: args.operation,
      qso: args.qso,
      qsoCount: args.qsoCount,
      appName: ctx.appName,
    })
    return { results: (args.templates ?? []).map((template) => renderOne(template, context)) }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("template", { key: "templates", hook: TemplateHook })
  },
})
