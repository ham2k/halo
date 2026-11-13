// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The strings the operator sees from this extension: its assistant, in
// Settings › Assistants. What agents read stays in English, the language
// the tools are described in.

import { createCachedTranslator } from "@ham2k/extension-sdk"

import en from "./i18n/en.json" with { type: "json" }

export const tFor = createCachedTranslator({ en: { translation: en } })
