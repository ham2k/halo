// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// User-visible strings for the LLOTA extension. `invalidReference`,
// `unknownReference`, `activationControl` and `huntingControl` are the
// vocabulary `referenceActivity` looks up; the rest are this extension's own.

import { createCachedTranslator } from "@ham2k/halo-extension-sdk"

import en from "./i18n/en.json" with { type: "json" }
import es from "./i18n/es.json" with { type: "json" }

export const tFor = createCachedTranslator({ en: { translation: en }, es: { translation: es } })
