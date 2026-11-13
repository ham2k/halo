// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
import { defineExtension, host } from "@ham2k/extension-sdk"
import type { AgentLinkHook } from "@ham2k/extension-sdk"
import { answer } from "./mcp.ts"
import { stationTools } from "./tools.ts"

import manifest from "../manifest.json" with { type: "json" }

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    const tools = stationTools(host)
    const hook: AgentLinkHook = {
      handle: (args, ctx) => answer(args, ctx, { version: manifest.version, tools }),
    }
    registerHook("agentLink", { key: manifest.key, hook })
  },
})
