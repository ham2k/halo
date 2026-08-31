// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The scoring extension's registration. The actual scoring logic lives in
// `scoring.ts` so its unit tests can run under plain `node --test` without the
// tsc/esbuild-only `@ham2k/extension-sdk` alias — this module is the one
// that uses the alias (for `defineExtension`), so the tests don't import it.
//
// `scoreQsos` is the coarse batched pass over a whole operation; `scoreQso`
// scores the single in-progress QSO for the logging panel's live call-info line.

import { defineExtension } from "@ham2k/extension-sdk"

import { coreScoringHook } from "./scoring.ts"

import manifest from "../manifest.json" with { type: "json" }

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    // The hook carries `scope: 'always'` — core scoring runs for every
    // operation, alongside whatever contest scorers that operation's refs
    // select. It is the LOWEST priority of them on the worked-before axis: for
    // a QSO another scorer has RULED on as worked-before, the app drops this
    // one's dupe alert and its newBand/newMode notices, so the call+band+mode
    // rule never contradicts an activity's. A scorer that merely answered —
    // `invalidBand`, a VHF test's `missingExchange` — has ruled on nothing, and
    // this scorer's dupe warning is then the only one the operator gets. The
    // entity and state notices, which nothing else in the app reports, always
    // survive (docs/design/contests.md §5.1).
    registerHook('scoring', { hook: coreScoringHook, key: 'core' })
  },
})
