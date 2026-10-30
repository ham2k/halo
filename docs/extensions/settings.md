# Settings panels

An extension's preferences live in one panel in the app's Settings,
rendered by the app from a declaration, in the same field schema as a
[form](forms.md). A settings panel is a form whose values are persisted
rather than submitted once. [How hooks work](hooks.md) covers registration,
keys, priority and `ctx`.

Credentials are not settings: a login belongs to the [`account`](accounts.md)
hook, which keeps it in the keychain.

## Where an extension's settings go

**Put all of an extension's settings in one panel, and that panel in the
section that fits the extension's main purpose.** The panel shows there as
a single row that opens it in a dialog. An extension does not add a
category of its own, an entry to the Settings sidebar, or fields to Common
Preferences, not without a reviewer's approval on the catalog.

| `section` | Shown as | For |
| --- | --- | --- |
| `activities` | Activities | an activity program |
| `hunting` | Hunting | chasing and awards |
| `contests` | Contests | a contest or event |
| `lookups` | Lookups | callsign lookups, notes and history |
| `spotting` | Spotting | a spot source or destination |
| `dashboard` | Dashboard | a dashboard panel's app-wide preferences |
| `logging` | Logging | something that changes how contacts are entered |
| `radio` | CAT Control | radios, rigs and keyers |
| `map` | Maps | the map views |
| `exports` | Exports | export files and formats |

Prefer the first six; the last four suit an extension that tunes something
the app already has a section for. A section holding no panel is not shown.
The section is declared twice: in the **manifest**, which is what the
catalog reviews and what the app places the panel by, and on the **panel**,
for an app older than the manifest field. An app without that section (an
older one, or a key it does not know) shows the panel as if it were not set,
so declaring one needs no newer API level.

```json
{ "hooks": ["settingsPanel"], "settings": { "section": "activities" } }
```

```ts
registerHook("settingsPanel", {
  hook: { kind: "simple", title: "Lakes", section: "activities", fields: [ /* … */ ] },
})
```

**What is reviewed.** The catalog holds an upload for an admin, even from a
trusted publisher, when its manifest lists `settingsPanel` and names no
`settings.section`, names one outside the table, or sets `settings.sidebar`
or `settings.common`. A placement once approved stays approved for later
versions whose `settings` are unchanged. To ask for a category or a sidebar
entry, declare it and say why in the release notes. The packer prints `held
for review on the catalog` for each, so it is no surprise.

**What the app enforces.** For every extension it did not ship, the panel
goes in the manifest's `settings.section`; with none, in the panel's own
`section` if it is one of the table's; otherwise it is a category of its
own. It has a sidebar entry only when it is a category of its own, the
panel's `sidebar` is not false, **and** the manifest declares
`sidebar: true`. Its `common: true` fields reach Common Preferences only
when the manifest declares `common: true`. A panel from an extension whose
manifest `hooks` does not list `settingsPanel` is not shown at all, and the
build fails a bundle that registers one its manifest does not declare.
Everything else about a panel is untouched: `dataFilesSection` still adds
its row to the Data Files screen, and `target` still reaches the Logging
and Developer dialogs. An extension installed from a file never passed
through the catalog, and the app takes its `settings` as written.

## Key namespacing

Wherever an extension can define more than one of something under one
category (several settings panels, several accounts) the key defaults to
the extension's key and, if overridden, must equal it or be prefixed
`<key>_`: `w7abc-lakes` may register panels keyed `w7abc-lakes` and
`w7abc-lakes_spots`, never bare `spots`. It applies to a panel's `key`, a
descriptor's `key` (checked when `getPanels` answers, not only at
registration) and an account's `kvKey`, and keeps every panel's storage
under its owning extension.

## Tier 1: `SimpleSettingsPanel`

The common case: a fixed list of fields, each persisted on its own, no
custom logic. Register once at activation; the app reads current values,
writes on change and validates patterns, with no bridge call per keystroke.

```ts
interface SimpleSettingsPanel {
  kind: "simple"
  key?: string            // your key, or <key>_suffix
  title: string
  icon?: string
  order?: number
  section?: string        // the same key as the manifest's settings.section
  sidebar?: boolean       // default true; the manifest's settings.sidebar also has to allow it
  dataFilesSection?: boolean   // default false: also a row in the Data Files screen's Extensions section
  fields: (SettingsField | FormActionElement)[]
}
// SettingsField: a FormField without validate/transform/itemFields closures, plus
//   pattern?: string, patternError?: string, itemFields?: SettingsField[]
```

```ts
registerHook("settingsPanel", {
  hook: {
    kind: "simple",
    title: "Lakes",
    icon: "waves",
    section: "activities",
    fields: [
      { type: "field", fieldType: "text", key: "endpoint", label: "API endpoint", pattern: "^https://.+" },
      { type: "field", fieldType: "checkbox", key: "spotHunted", label: "Spot hunted lakes", value: true },
      { type: "action", key: "clear", label: "Clear cache", method: "clearCache" },
    ],
    async clearCache(state, ctx) {           // resolved by name from the action element
      await purgeLocalCache()
      return "Cache cleared"
    },
  },
})
```

Each field is read and written under `<panelKey>.<fieldKey>`, where the
panel key is your extension's key unless `key` overrides it, so the common
single-panel case reads `w7abc-lakes.endpoint`, and a second panel keyed
`w7abc-lakes_spots` has a settings group of its own. Fields with
`fieldType: 'secret'` go through secure storage instead of the plain store.

## Tier 2: `DynamicSettingsPanel`

For a panel whose fields, values or validation depend on runtime state:
options fetched from a service, fields that appear or disappear with
another field's value. Mirrors a dynamic [form](forms.md#forms-the-app-asks-for)
plus discovery and a persistence hook.

```ts
interface DynamicSettingsPanel {
  kind: "dynamic"
  key?: string                                                        // the panel key only when getPanels is omitted
  getPanels?(args: {}, ctx): Promise<SettingsPanelDescriptor[]>      // { key, title, icon?, order?, sidebar?, dataFilesSection?, section? }
  getDefinition(args: { panelKey }, ctx): Promise<FormDefinition>
  validateField?(args: { panelKey, fieldKey, value, state }, ctx): Promise<string | null>
  transformField?(args: { panelKey, fieldKey, value, state }, ctx): Promise<any>
  onChangeField(args: { panelKey, fieldKey, value, state }, ctx): Promise<void>
}
```

`onChangeField` fires on every accepted change: the field committed, go
persist it. **You own the persistence** here, through `host.setSettings`,
never `host.kvSet`, which is session memory. `state` is the panel's own
values, bare-keyed, holding the value being written, whether the edit came
from the settings screen or from a `SET` command.

A dynamic field may set `restartOnChange: true` when its value is only ever
read at `onActivation`, the common case being a list of URLs the extension
turns into `dataFile` registrations. Once the field commits the app restarts
the runtime so `onActivation` runs again. Reserve it for fields that cannot
be re-read any other way; a restart is a real interruption. In
`onActivation`, `await host.getSettings()` before the registrations that
depend on it, and register everything that does not depend on it first.

## Field types

The full schema is in [Forms](forms.md). Settings panels add behaviour to a
few:

### The `list` field type

A field that is itself a repeatable list of objects, each shaped like
`itemFields`:

```ts
{ type: "field", fieldType: "list", key: "presets", label: "Saved presets",
  itemTitle: "${label} — ${exchange}", orderable: true, itemSwitch: "enabled",
  itemFields: [
    { type: "field", fieldType: "text", key: "label", label: "Name" },
    { type: "field", fieldType: "text", key: "exchange", label: "Exchange" },
  ] }
```

It renders as one row summarizing the items by `itemTitle` (templated as
`${key}`, not Liquid), opening an editor with a row per item and *Add*,
where every change commits at once and *Done* closes; editing an item opens
the same renderer scoped to `itemFields`, with *Delete* in its footer behind
a confirmation. Saving merges what was edited into the item, so keys it has
no field for are kept. `itemSwitch` names an on/off key in each item shown
as a switch on its row (leave it out of `itemFields`; absent reads as on);
`orderable` allows drag-to-reorder; `inline: true` renders the rows directly
in the form. In a Tier 1 panel, `itemFields` are declarative too.

### The `multiselect` field type

Several values from a fixed vocabulary the operator cannot add to (a `list`
is for values they enter). `value` is a string list and `options` the
vocabulary, inline or a system list:

```ts
{ type: "field", fieldType: "multiselect", key: "bands", label: "Bands", value: ["80m", "40m", "20m"],
  options: "$core.bands", defaultValue: ["80m", "40m", "20m"] }
```

Options disclose in up to three tiers: `common: true` ones upfront,
unflagged ones behind *Show more*, `uncommon: true` ones behind *Show all*
(the toggle cycles Show more, Show all, Show fewer, or just Show all and
Show fewer when nothing is flagged uncommon); a hidden-tier value that is
selected stays visible for the dialog's lifetime. `defaultValue` offers a
*Defaults* button. The selection keeps the order of `options`; `orderable` is
reserved and ignored here.

### System lists

A field's `options` may name a system list, `$<namespace>.<list>`, that the
app resolves before rendering: `$core.bands` (the extended band vocabulary,
the popular bands flagged `common`) and `$core.modes` (every ADIF mode and
submode, the main ones flagged `common`). `$extensions.*` is reserved for
lists derived at run time. An unknown name is logged and resolves to no
options; the field renders disabled rather than failing the panel.

### The `secret` field type

An obscured text field, persisted through secure storage in a Tier 1 panel;
a Tier 2 panel stores it itself in `onChangeField` and owes it the same
care. For a bare API key with no login behind it. Not for account
credentials, which belong on the `account` hook.

### The `account` field type

A read-only reference into the account system: a row showing "Connected as
…" or "Not connected", with a button that opens that account's own dialog.
It never defines or stores the account. `subkey` is an opaque discriminator
for an extension that exposes more than one account-like entity under one
key; most accounts need none.

```ts
{ type: "field", fieldType: "account", key: "hamqthStatus", label: "HamQTH account", account: { key: "w7abc-hamqth" } }
```

### The `action` element

A button that calls a named method on the hook object with the panel's
current state and shows the returned string as a banner:

```ts
{ type: "action", key: "clear", label: "Clear cache", method: "clearCache" }
```

`method` is resolved by name against an extra property on the registered
hook object, as in the Tier 1 example above; the SDK's `Hook` type permits
the extra property without a cast.

## Reading and writing settings

- `host.getSettings()` answers the whole read view: the app's resolved core
  values and every extension's own group under `extensions`, keyed
  `extension_<key>`. Settings are not secrets, and reading is unrestricted;
  credentials are absent by design.
- `host.setSettings({ key: value })` writes into your own group only. Core
  settings and other extensions' groups are read-only.

A Tier 1 panel's fields are stored in that same group, so a hook reads them
back through `getSettings()`.

## Visibility

**`devMode: true`** on any element hides it unless developer mode is on, and
tints it when shown ([Forms](forms.md#devmode-elements)). A panel with
nothing to show at the current setting is left out of Settings rather than
shown as an empty heading; a panel placed in a section shows a developer
row when every field is `devMode`, and no row at all when it has no fields
on this platform. A sidebar entry is not hidden the same way and would open
on an empty page, so give such a panel `sidebar: false`.

**`common: true`** on a field, link or action also shows it in Common
Preferences, the short list on top of Application Preferences, when the
manifest allows it. Not the same as a `multiselect` option's `common`, which
is a disclosure tier inside one field.

**`environment`** restricts which platforms show an element at all:
`'ios,android'`, `'-web'`, or an array. Unprefixed tokens are a whitelist,
`-`-prefixed ones a blacklist, and mixing the two forms is invalid and
treated as absent. Tokens: `ios`, `android`, `macos`, `windows`, `linux`,
`web`. It applies to every element type, headers included.

**`target`** opts a field, an `account` field or an action into a settings
dialog built around one concern somewhere else in the app, in addition to
its home panel: `'logging'` is the logging view's tune icon; `'developer'`
(extension API 8) is the Developer panel's *Extension Settings* section,
shown only once some field targets it, for a switch only someone working on
the extension needs, paired with `devMode: true`. A `'<target>-extended'`
target starts hidden behind that dialog's *show more settings*. A single
key or an array.

**`aliases`** gives a field extra names for the `SET`, `SHOW` and `HIDE`
commands, which search every setting's key, label and description by
subsequence; an alias is matched at the same tier as the key, for a setting
whose real name buries the word people reach for:

```ts
{ type: "field", fieldType: "text", key: "defaultReport", label: "Default report", aliases: ["report", "rst"] }
```

Matching is case-insensitive and ignores punctuation. Aliases are for names
an operator would plausibly reach for, not a thesaurus: every alias can
collide with another setting's name.

Both `common` and `environment` are evaluated fresh on every reload, so a
dynamic panel may compute them.
