// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// User-visible strings for the Custom Activity extension. All of them are its
// own: it uses none of `referenceActivity`'s vocabulary, having no list to
// validate a reference against.

import { createCachedTranslator } from "@ham2k/halo-extension-sdk"

import en from "./i18n/en.json" with { type: "json" }
import es from "./i18n/es.json" with { type: "json" }

export const tFor = createCachedTranslator({ en: { translation: en }, es: { translation: es } })
