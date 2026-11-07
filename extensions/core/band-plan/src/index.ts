// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
import { defineExtension } from "@ham2k/extension-sdk"
import { annotationsFor } from "./plan.ts"

import manifest from "../manifest.json" with { type: "json" }

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("bandAnnotations", {
      key: manifest.key,
      hook: {
        async annotationsFor({ band, station }) {
          return annotationsFor(band, station)
        },
      },
    })
  },
})
