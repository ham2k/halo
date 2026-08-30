// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// User-visible strings for the State Parks extension, following NAQP's pattern:
// per-locale flat key → string catalogs in i18n/<locale>.json, with hooks
// building a translator from `ctx.locale` via `tFor`.
//
// Event names, park names and park abbreviations are NOT here: they are the
// sponsors' own proper names and the codes operators exchange on the air, so
// they stay as the data files spell them (see events.ts).

import { createCachedTranslator } from "@ham2k/extension-sdk"

import en from "./i18n/en.json" with { type: "json" }
import es from "./i18n/es.json" with { type: "json" }

/// Translator for this extension's strings, cached per locale — `ctx.locale`
/// only changes when the app's locale setting does.
export const tFor = createCachedTranslator({ en: { translation: en }, es: { translation: es } })
