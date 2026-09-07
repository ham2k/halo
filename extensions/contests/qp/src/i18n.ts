// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// User-visible strings for the QSO Parties extension, following the pattern
// NAQP set: per-locale flat key → string catalogs in i18n/<locale>.json, with
// hooks building a translator from `ctx.locale` via `tFor`.
//
// Party names, county names and county abbreviations are NOT here. They are the
// sponsors' own names and the codes operators send on the air, and they stay as
// `parties/*.json` spells them (see parties.ts).

import { createCachedTranslator } from "@ham2k/extension-sdk"

import en from "./i18n/en.json" with { type: "json" }
import es from "./i18n/es.json" with { type: "json" }

/// Translator for this extension's strings, cached per locale.
export const tFor = createCachedTranslator({ en: { translation: en }, es: { translation: es } })
