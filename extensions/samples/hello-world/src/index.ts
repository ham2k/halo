// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The smallest extension that does something visible: one panel, saying hello.
//
// It exists to be COPIED. Everything here is the minimum — one hook, one
// descriptor, one render — so that what a real extension adds is obvious by
// comparison. See extensions/dashboard/custom-text for a panel that earns its
// keep, and docs/extensions/hooks.md for every other hook there is.
//
// It declares no `sharedDependencies` because it uses none. An extension that
// wants @ham2k/lib-callsigns or liquidjs says so in its manifest and uses the
// host's copy, rather than carrying its own — see docs/extensions/distribution.md.

import { defineExtension } from "@ham2k/extension-sdk"
import type { HookContext, PanelContent, PanelDescriptor, PanelHook, PanelRenderArgs } from "@ham2k/extension-sdk"

import manifest from "../manifest.json"

const HelloPanel: PanelHook = {
  /// What the operator sees when choosing a panel to place.
  async getPanels(_args: Record<string, never>, _ctx: HookContext): Promise<PanelDescriptor[]> {
    return [
      {
        key: "hello",
        title: "Hello World",
        description: "A panel that says hello",
        icon: "hand-wave-outline",
      },
    ]
  },

  /// What the pane shows. Markdown, rendered by the app — a panel returns
  /// content, never widgets, which is what keeps extensions out of the UI
  /// toolkit's way.
  ///
  /// The method is `render`, not `renderPanel`: the host routes to the hook by
  /// its registered key and then calls this by name, so a near-miss is a panel
  /// that installs, activates, and then renders nothing.
  async render(_args: PanelRenderArgs, _ctx: HookContext): Promise<PanelContent> {
    return {
      kind: "markdown",
      content: [
        "# Hello, World!",
        "",
        "This panel came from an extension installed from a `.h2kext` file.",
      ].join("\n"),
    }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("panel", { key: "ki2d-hello-world", hook: HelloPanel })
  },
})
