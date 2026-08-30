// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// User-visible strings for the settings commands (describe/confirm/error
// texts). The per-locale catalogs live in i18n/<locale>.json (flat key →
// string maps, editable without touching code).
//
// Only the SENTENCES live here. Every setting's own name, section and value
// wording is already localized by the app and arrives with the
// `host.searchSettings` result — translating those again here would be a
// second, drifting copy of the settings screen's vocabulary.

import { createCachedTranslator } from "@ham2k/extension-sdk"

import en from "./i18n/en.json" with { type: "json" }
import es from "./i18n/es.json" with { type: "json" }

/// Translator for this extension's strings, cached per locale — `ctx.locale`
/// only changes when the app's locale setting does.
export const tFor = createCachedTranslator({ en: { translation: en }, es: { translation: es } })
