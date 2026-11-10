// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
import { defineExtension, host } from "@ham2k/extension-sdk"
import { createBoardPanel } from "./panel.ts"

import manifest from "../manifest.json" with { type: "json" }

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("panel", { key: manifest.key, hook: createBoardPanel(host) })
  },
})
