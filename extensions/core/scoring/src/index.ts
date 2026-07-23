// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The scoring extension's registration. The actual scoring logic lives in
// `scoring.ts` so its unit tests can run under plain `node --test` without the
// tsc/esbuild-only `@ham2k/halo-extension-sdk` alias — this module is the one
// that uses the alias (for `defineExtension`), so the tests don't import it.
//
// `scoreQsos` is the coarse batched pass over a whole operation; `scoreQso`
// scores the single in-progress QSO for the logging panel's live call-info line.

import { defineExtension } from "@ham2k/halo-extension-sdk"

import { scoreQso, scoreQsos } from "./scoring.ts"

import manifest from "../manifest.json" with { type: "json" }

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook('scoring', { hook: { scoreQsos, scoreQso }, key: 'core' })
  },
})
