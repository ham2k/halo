// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The DXCC extension's registration; the program itself is `program.ts`,
// which its tests import without the `@ham2k/extension-sdk` alias.

import { defineExtension } from "@ham2k/extension-sdk"

import { dxccProgram } from "./program.ts"

import manifest from "../manifest.json" with { type: "json" }

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("chasing", { hook: dxccProgram, key: "dxcc" })
  },
})
