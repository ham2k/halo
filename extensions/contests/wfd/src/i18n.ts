// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// User-visible strings for Winter Field Day. `fd` keeps its own copy of the
// equivalents rather than sharing these — see `scorer.ts` on why the two
// extensions are duplicates by choice.

import { createCachedTranslator } from "@ham2k/halo-extension-sdk"

import en from "./i18n/en.json" with { type: "json" }
import es from "./i18n/es.json" with { type: "json" }

export const tFor = createCachedTranslator({ en: { translation: en }, es: { translation: es } })
