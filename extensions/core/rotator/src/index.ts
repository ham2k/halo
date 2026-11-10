// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
import { defineExtension, host } from "@ham2k/extension-sdk"
import { createRotatorPanel } from "./rotator.ts"

import manifest from "../manifest.json" with { type: "json" }

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("panel", { key: manifest.key, hook: createRotatorPanel(host) })
  },
})
