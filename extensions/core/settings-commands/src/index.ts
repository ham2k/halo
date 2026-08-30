// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// SET, SHOW and HIDE — finding and changing a setting without leaving the
// call field.
//
//   SET ZEROBEAT        → "Zero Beat: On"        (Enter opens it)
//   SET ZEROBEAT N      → "Change Zero Beat to Off?"
//   SHOW GRID           → turns showGridField on
//   HIDE NUMBERS        → turns showNumbersRow off
//
// This hook owns the grammar and the sentences; it owns no list of settings.
// Everything about WHICH settings exist, what they currently hold, what values
// they accept and where a write goes lives app-side and arrives through
// `host.searchSettings` (see settings_command.dart). That split is the point:
// app-polo's equivalent hard-codes seven settings and has silently omitted
// every one added since, whereas here a setting is reachable by name the day
// it's declared — and only while the settings screen would actually show it,
// since the same `devMode`, `environment` and `visibleWhen` rules are applied
// to the catalog.
//
// SHOW/HIDE are not sugar for `SET … Y`. They search only settings that name a
// visibility toggle and let the app decide the polarity, so `HIDE NUMBERS`
// writes `false` to `showNumbersRow` while a hypothetical `hideFoo` would get
// `true` — the verb means what it says regardless of how the setting was named.

import { defineExtension, host } from "@ham2k/extension-sdk"
import type {
  CommandCatalogEntry,
  CommandInterpretation,
  HookContext,
  SettingsSearchResult,
} from "@ham2k/extension-sdk"

import { tFor } from "./i18n.ts"

import manifest from "../manifest.json" with { type: "json" }

type Translator = ReturnType<typeof tFor>

/// Everything after the verb goes across whole. Where the setting's name ends
/// and its value begins is not decidable here — `SET AVOID ZERO BEAT N` and
/// `SET THEME DARK` are the same shape, and only the catalog knows which
/// leading words name a setting — so the app splits it (settings_command.dart).
const SET_MATCH = /^SET(?:\s+(.*))?$/i
const SHOW_MATCH = /^SHOW(?:\s+(.+))?$/i
const HIDE_MATCH = /^HIDE(?:\s+(.+))?$/i

/// The describe line for a setting sitting at its current value. Names the
/// section too when there's one to name, since two settings can reasonably
/// share a label across sections.
function describeCurrent(t: Translator, result: SettingsSearchResult): string {
  const params = { label: result.label ?? '', value: result.valueLabel ?? '', section: result.section ?? '' }
  return result.section ? t('currentIn', params) : t('current', params)
}

/// Opens the settings dialog rather than writing anything — for a setting that
/// can't be typed on one line, one named without a value, and for a query that
/// matched several settings equally well.
///
/// EVERY match goes into the dialog, best first, not just the top one. A query
/// like `SET RST` legitimately names several settings, and offering only the
/// winner means the operator has to guess a better word for the others rather
/// than simply seeing them — the same list the All Settings search box would
/// give for the same query.
function openSettings(t: Translator, result: SettingsSearchResult, query: string): CommandInterpretation {
  const candidates = result.candidates ?? []
  const keys = candidates.length ? candidates.map((c) => c.key) : [result.key as string]
  const label = result.label ?? ''
  return {
    mixedCase: true,
    // The preview names the BEST match and its current value — the one useful
    // thing to show while the operator is still typing, and often enough to
    // refine the query without opening anything. When there are others behind
    // it, say so, so the dialog's extra rows aren't a surprise.
    describe: keys.length > 1
      ? t('currentAndMore', { label, value: result.valueLabel ?? '', count: keys.length - 1 })
      : describeCurrent(t, result),
    commands: [{
      openSettings: {
        keys,
        title: keys.length > 1 ? t('matchingSettings', { query }) : label,
      },
    }],
  }
}

/// The shared body of all three commands: everything past parsing is the same
/// once the app has resolved the query.
async function interpretSettingCommand(
  t: Translator,
  { args, kind }: { args: string; kind: 'set' | 'show' | 'hide' },
): Promise<CommandInterpretation> {
  const result = await host.searchSettings({ args, kind })
  // What the app decided the setting's NAME was, for the messages below —
  // echoing the whole of `args` back would quote the value too.
  const query = result.query ?? args

  // Nothing matched — recognized as a command (so Enter can't log the text as
  // a callsign) but not runnable, and left open for more typing, because this
  // is also what every prefix of a correct query looks like.
  if (!result.found || !result.key) {
    return { mixedCase: true, expectsParams: true, describe: t('noMatch', { query }) }
  }

  // A value that doesn't fit is a mistake worth reporting rather than
  // quietly opening a form — but only once we know WHICH setting it didn't
  // fit. While the query is still ambiguous, complaining about the value of a
  // setting we only guessed at would be noise.
  if (result.expects && !result.ambiguous) {
    return { mixedCase: true, error: t('expects', { label: result.label ?? '', expects: result.expects }) }
  }

  // No value asked for, a setting the command line can't express, or a query
  // that named more than one thing — all three want the dialog.
  if (result.ambiguous || result.simple !== true || result.newValue === undefined) {
    return openSettings(t, result, query)
  }

  const label = result.label ?? ''
  const valueLabel = result.newValueLabel ?? ''

  // Already there: say so and do nothing. Reporting "set to X" for a write
  // that never happened teaches the operator to distrust the confirmations.
  //
  // `confirm` as well as `describe`, and they carry the same words on purpose.
  // Without `confirm` this still counts as a completed command — the field
  // clears and the ⌘K palette closes — so the "already On" line the operator
  // was reading vanishes with it and Enter reads as having done nothing at
  // all. `confirm` is what survives the execution to say why.
  if (result.unchanged) {
    const already = t('alreadySet', { label, value: valueLabel })
    return { mixedCase: true, describe: already, confirm: already }
  }

  return {
    mixedCase: true,
    describe: t('change', { label, value: valueLabel }),
    confirm: t('confirmChanged', { label, value: valueLabel }),
    commands: [{ updateSetting: { key: result.key, value: result.newValue } }],
  }
}

const SetCommand = {
  async interpret({ input }: { input: string }, ctx: HookContext): Promise<CommandInterpretation | null> {
    const match = SET_MATCH.exec(input.trim())
    if (!match) return null
    const args = match[1]?.trim()
    // Bare "SET" — recognized, not complete yet. `mixedCase` from the very
    // first keystroke: a text setting's value is typed into this same field
    // and must not be uppercased on its way in.
    if (!args) return { expectsParams: true, mixedCase: true }
    return interpretSettingCommand(tFor(ctx), { args, kind: 'set' })
  },

  async catalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
    const t = tFor(ctx)
    return [{
      command: 'SET',
      params: t('catalogSetParams'),
      describe: t('catalogSet'),
      category: t('catalogCategory'),
      expectsParams: true,
    }]
  },
}

/// SHOW and HIDE differ only in which way they push the toggle — the app
/// works out what that means for a setting named `hide…` rather than `show…`.
function visibilityCommand(kind: 'show' | 'hide', pattern: RegExp, describeKey: string, paramsKey: string) {
  const word = kind.toUpperCase()
  return {
    async interpret({ input }: { input: string }, ctx: HookContext): Promise<CommandInterpretation | null> {
      const match = pattern.exec(input.trim())
      if (!match) return null
      const args = match[1]?.trim()
      // `mixedCase` on the expectsParams result as well as the complete one,
      // same as SET: without it the field snaps back to uppercasing while the
      // setting's name is still being typed, and the name is then echoed back
      // shouting in `noMatch` and `matchingSettings`.
      if (!args) return { expectsParams: true, mixedCase: true }
      return interpretSettingCommand(tFor(ctx), { args, kind })
    },

    async catalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
      const t = tFor(ctx)
      return [{
        command: word,
        params: t(paramsKey),
        describe: t(describeKey),
        category: t('catalogCategory'),
        expectsParams: true,
      }]
    },
  }
}

const ShowCommand = visibilityCommand('show', SHOW_MATCH, 'catalogShow', 'catalogShowParams')
const HideCommand = visibilityCommand('hide', HIDE_MATCH, 'catalogHide', 'catalogHideParams')

/// LAYOUTS — one setting, one word, no arguments.
///
/// `SET LAYOUT` already reaches it: it is an ordinary catalog entry and the
/// generic verb finds it by name like any other. This exists because it is the
/// switch that turns a whole way of using the app on and off, and an operator
/// who has been told about it by another operator will type its name, not the
/// name of the setting behind it.
///
/// The current value comes from the app with the rest of the search result
/// rather than from anything hard-coded here — the same rule the file's own
/// header sets out, and what keeps this from becoming the second place that
/// knows about a setting.
const LAYOUTS_MATCH = /^(?:LYT|LAYOUTS?)$/i

const LayoutsCommand = {
  async interpret({ input }: { input: string }, ctx: HookContext): Promise<CommandInterpretation | null> {
    if (!LAYOUTS_MATCH.test(input.trim())) return null
    const t = tFor(ctx)
    const result = await host.searchSettings({ args: 'layoutCustomization', kind: 'set' })
    // The setting is the app's own and always in the catalog; if it ever is
    // not, saying nothing is right — this is a command that could not run,
    // not one that half-ran.
    // `value` is booleans-only by contract, so a missing one here means the
    // catalog does not hold this as a checkbox — a toggle would then be
    // guessing which way to go, and guessing wrong turns a command meant to
    // switch the feature off into one that only ever switches it on.
    if (!result.found || !result.key || typeof result.value !== 'boolean') return null
    const next = !result.value
    return {
      describe: next ? t('layoutsOn') : t('layoutsOff'),
      confirm: next ? t('layoutsOnConfirm') : t('layoutsOffConfirm'),
      commands: [{ updateSetting: { key: result.key, value: next } }],
    }
  },

  async catalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
    const t = tFor(ctx)
    return [{
      command: 'LAYOUTS',
      describe: t('catalogLayouts'),
      category: t('catalogCategory'),
    }]
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook('command', { key: 'settings-commands-set', hook: SetCommand, priority: 100 })
    registerHook('command', { key: 'settings-commands-show', hook: ShowCommand, priority: 100 })
    registerHook('command', { key: 'settings-commands-hide', hook: HideCommand, priority: 100 })
    registerHook('command', { key: 'settings-commands-layouts', hook: LayoutsCommand, priority: 100 })
  },
})
