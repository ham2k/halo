// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// User-visible strings for the ParksnPeaks extension — the account dialog's
// labels and the spot-posting failure.

import { createCachedTranslator } from "@ham2k/halo-extension-sdk"

import en from "./i18n/en.json" with { type: "json" }
import es from "./i18n/es.json" with { type: "json" }

export const tFor = createCachedTranslator({ en: { translation: en }, es: { translation: es } })
