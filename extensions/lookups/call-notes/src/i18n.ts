// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// User-visible strings for the Callsign Notes extension (the `//KEY`
// command's describe line and the data file's description). The per-locale
// catalogs live in i18n/<locale>.json (flat key → string maps, editable
// without touching code); hooks build a translator from `ctx.locale` via
// `tFor`.

import { createCachedTranslator } from "@ham2k/halo-extension-sdk"

import en from "./i18n/en.json" with { type: "json" }
import es from "./i18n/es.json" with { type: "json" }

/// Translator for this extension's strings, cached per locale — `ctx.locale`
/// only changes when the app's locale setting does.
export const tFor = createCachedTranslator({ en: { translation: en }, es: { translation: es } })
