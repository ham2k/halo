// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// User-visible strings for GO. Per-locale catalogs live in
// i18n/<locale>.json, as in operation-commands.

import { createCachedTranslator } from "@ham2k/extension-sdk"

import en from "./i18n/en.json" with { type: "json" }

/// Translator for this extension's strings, cached per locale.
export const tFor = createCachedTranslator({ en: { translation: en } })
