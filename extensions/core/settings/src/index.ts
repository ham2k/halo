// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The app's General settings (theme, language, font scale), as a Tier 2
// (dynamic) settingsPanel — the reference example for the mechanism
// documented in docs/extensions/settings.md, and a real replacement for
// what used to be a hand-built _GeneralPanel widget in settings_view.dart.
//
// These are core Dart-owned settings with their own getters/setters/
// notifyListeners on SettingsService (ThemeMode drives MaterialApp, locale
// drives LocaleSettings, fontScale drives text scaling elsewhere) — not
// generic extension data — so this can't use Tier 1's engine-owned KV
// storage the way a real extension's settings would. Two new host calls
// (getCoreSettings/setCoreSetting) bridge getDefinition/onChangeField to
// SettingsService directly, so changing a value here actually takes effect
// everywhere else in the app, not just in a KV store nobody else reads.
//
// Labels come from host.translate(key), which reads the same
// app/lib/i18n/{en,es}.i18n.json "settings" section the rest of the app
// uses (via Dart's generated `t[key]` lookup) — no separate/duplicated
// strings here, and no separate extension-i18n mechanism to maintain.
//
// Fields use `icon`/`description` to render as Sync/Accounts-style list
// rows (icon + bold label + description, compact control trailing) rather
// than the default standalone Material inputs — see FormField.icon in the
// SDK types for why that's opt-in per field.

import { defineExtension, host } from "@ham2k/polo-sdk"
import type { FormDefinition, HookContext, JSONValue } from "@ham2k/polo-sdk"

const TRANSLATION_KEYS = [
  "settings.general",
  "settings.theme.title",
  "settings.theme.system",
  "settings.theme.light",
  "settings.theme.dark",
  "settings.themeDescription.system",
  "settings.themeDescription.light",
  "settings.themeDescription.dark",
  "settings.language",
  "settings.fontScale",
  "settings.fontScaleOpts.smallest",
  "settings.fontScaleOpts.smaller",
  "settings.fontScaleOpts.normal",
  "settings.fontScaleOpts.larger",
  "settings.fontScaleOpts.largest",
  "settings.fontScaleDescription",
] as const

type TranslationKey = (typeof TRANSLATION_KEYS)[number]

async function loadStrings(): Promise<Record<TranslationKey, string>> {
  const values = await host.translateAll([...TRANSLATION_KEYS])
  return Object.fromEntries(TRANSLATION_KEYS.map((key) => [key, values[key] ?? key])) as Record<TranslationKey, string>
}

const LOCALE_OPTIONS = [
  { label: "English", value: "en" },
  { label: "Español", value: "es" },
]

// system/light/dark all exist as MDI icons; the field's own icon switches
// with its current value so the row reflects what's actually selected, not
// just that it's a theme setting.
const THEME_ICONS: Record<string, string> = {
  system: "theme-light-dark",
  light: "white-balance-sunny",
  dark: "weather-night",
}

defineExtension({
  key: "settings",
  name: "General Settings",
  version: "0.0.1",
  onActivation({ registerHook }) {
    registerHook("settingsPanel", {
      hook: {
        kind: "dynamic",
        // Gives the sidebar a title/icon immediately, without waiting for
        // getDefinition's round trip — see kernel.ts's settingsPanel/
        // getPanels handling. "General" is left untranslated here to match
        // its sidebar siblings (Sync/Accounts/About in settings_view.dart),
        // none of which are localized yet either.
        async getPanels(_args: Record<string, never>, _ctx: HookContext) {
          return [{ key: "settings", title: "General", icon: "cog-outline", order: 0 }]
        },
        async getDefinition(_args: { panelKey: string }, _ctx: HookContext): Promise<FormDefinition> {
          const [current, s] = await Promise.all([host.getCoreSettings(), loadStrings()])
          return {
            elements: [
              { type: "header", title: s["settings.general"], style: "section" },
              {
                type: "field",
                fieldType: "select",
                key: "themeMode",
                label: s["settings.theme.title"],
                icon: THEME_ICONS[current.themeMode] ?? THEME_ICONS.system,
                description: s[`settings.themeDescription.${current.themeMode}` as TranslationKey] ?? s["settings.themeDescription.system"],
                value: current.themeMode,
                options: [
                  { label: s["settings.theme.system"], value: "system" },
                  { label: s["settings.theme.light"], value: "light" },
                  { label: s["settings.theme.dark"], value: "dark" },
                ],
              },
              {
                type: "field",
                fieldType: "select",
                key: "locale",
                label: s["settings.language"],
                icon: "translate",
                value: current.locale,
                options: LOCALE_OPTIONS,
              },
              {
                type: "field",
                fieldType: "select",
                key: "fontScale",
                label: s["settings.fontScale"],
                icon: "format-size",
                description: s["settings.fontScaleDescription"],
                value: current.fontScale,
                options: [
                  { label: s["settings.fontScaleOpts.smallest"], value: "smallest" },
                  { label: s["settings.fontScaleOpts.smaller"], value: "smaller" },
                  { label: s["settings.fontScaleOpts.normal"], value: "normal" },
                  { label: s["settings.fontScaleOpts.larger"], value: "larger" },
                  { label: s["settings.fontScaleOpts.largest"], value: "largest" },
                ],
              },
            ],
          }
        },
        async onChangeField(args: { fieldKey: string; value: JSONValue }, _ctx: HookContext): Promise<void> {
          await host.setCoreSetting(args.fieldKey, args.value)
        },
      },
    })
  },
})
