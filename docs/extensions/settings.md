# Settings panel schema

Extensions can contribute panels to the app's settings screen by registering
a hook in the `settingsPanel` category. Panels are rendered with the same
`FormRenderer` used for [ad hoc forms](./forms.md) — a settings panel is a
`FormDefinition` whose fields' values happen to be persisted, not just
submitted once.

This is a separate, complementary mechanism to the `account` hook category
(see [Relationship to `AccountHook`](#relationship-to-accounthook) below) —
`settingsPanel` never defines, stores, or edits account credentials itself.

> **Status: ✅ implemented.** Schema, kernel-side dispatch (key-namespacing
> enforcement at `registerHook` time — including on panel keys a Tier 2
> hook's `getPanels()` returns at call time, not just the registration key
> — Tier 1's static `getDefinition`, `getPanels` discovery/flattening),
> `ExtensionService`, `FormRenderer` support for every field type, and a
> data-driven panel list in `SettingsView` are all done and reachable from
> the app. One known gap: `fieldType: 'account'`'s `subkey` (multiple
> accounts under one extension key) has no real implementation yet —
> `AccountHook` registrations are one-kvKey-per-registration today, so
> there's nothing to disambiguate against; `SettingsView` logs a warning
> rather than silently mismatching if a field ever sets it.

There are two tiers, discriminated by a required `kind` tag.

---

## Key namespacing

Wherever an extension can define more than one of something under one
category — multiple settings panels, multiple accounts — the key that
identifies each one defaults to the extension's own key, but if overridden
it must equal the extension key or be prefixed `<extensionKey>_`. For
example, extension `pota` may register panels keyed `pota` (the default) and
`pota_spots`, but never bare `spots` or camelCase `potaSpots`.

This applies to `SimpleSettingsPanel.key`, `DynamicSettingsPanel.key`,
`SettingsPanelDescriptor.key`, and `AccountHook.kvKey`. It keeps every
panel/account keyed under its owning extension's namespace, which is how
storage collisions between extensions are prevented, and how KV access
control will be scoped once that lands — a write can be checked against the
calling extension's own key prefix without a separate ownership table.

```ts
// Extension key: 'pota'. Two panels — the default and one explicit override.
async getPanels() {
  return [
    { key: 'pota', title: 'POTA' },              // default, no override needed
    { key: 'pota_spots', title: 'POTA Spots' },   // override — extension-key-prefixed
  ];
}
```

---

## Tier 1: `SimpleSettingsPanel` — declarative, engine-owned storage

The common case: a fixed list of fields, each independently persisted, no
custom logic. Register the panel once at activation; the engine handles
reading current values, writing on change, and simple validation. No bridge
call happens per keystroke.

```ts
export interface SettingsField extends Omit<FormField, 'validate' | 'transform' | 'itemFields'> {
  pattern?: string;      // regex; declarative validation instead of a validate() closure
  patternError?: string;
  itemFields?: SettingsField[]; // re-typed, not the inherited FormField[] — see "list" below
}

export interface SimpleSettingsPanel {
  kind: 'simple';
  key?: string;           // defaults to the extension's key; see "Key namespacing"
  title: string;
  icon?: string;
  order?: number;
  // Defaults true. Set false to keep this panel out of the app's top-level
  // settings navigation (the sidebar list). Independent of dataFilesSection
  // below — this only controls the top-level nav.
  sidebar?: boolean;
  // Defaults false. Set true to also show this panel as a row in the Data
  // Files screen's own "Extensions" section — the ONLY host-recognized
  // alternate surface today, so leave this false for anything not actually
  // about managing data files. Independent of `sidebar`; a panel usually
  // wants both false-then-true, but the two aren't coupled at the type
  // level — inferring this from `sidebar: false` alone would sweep any
  // sidebar-opt-out panel in here.
  dataFilesSection?: boolean;
  fields: (SettingsField | FormActionElement)[];
}
```

Persistence: each field is read/written under a KV path built from the
panel's key and the field's key — `<panelKey>.<fieldKey>`, where `panelKey`
is the extension's key unless `key` overrides it (so the common single-panel
case reads/writes e.g. `myext.apiKey`, never a doubled `myext.myext.apiKey`;
a second panel keyed `myext_spots` reads/writes `myext_spots.someField`).
Fields with `fieldType: 'secret'` are read/written through secure storage
instead of the plain KV store — extensions never see the raw stored value
beyond what `getDefinition`-equivalent state exposes back to them.

```ts
api.registerHook('settingsPanel', {
  hook: {
    kind: 'simple',
    title: "My Service",
    icon: "cloud",
    fields: [
      { type: "field", fieldType: "text", key: "endpoint", label: "Webhook URL" },
      { type: "action", key: "clear", label: "Clear Cache", method: "clearCache" }
    ],
    // Not part of the SimpleSettingsPanel type — an extra property the
    // 'clear' action's `method` resolves against at dispatch time. See
    // "The action element" below.
    async clearCache(state, ctx) {
      await purgeLocalCache();
      return "Cache cleared";
    }
  }
});
```

## Tier 2: `DynamicSettingsPanel` — computed fields, custom logic

For panels whose fields, values, or validation depend on runtime state the
engine can't compute on its own (e.g. options fetched from an API, fields
that appear/disappear based on another field's value). Mirrors
[`FormHook`](./forms.md), plus panel discovery metadata and a
persistence-on-commit hook.

```ts
export interface SettingsPanelDescriptor {
  key: string; // extension key, or <extensionKey>_-prefixed; see "Key namespacing"
  title: string;
  icon?: string;
  order?: number;
  sidebar?: boolean; // see SimpleSettingsPanel.sidebar above; defaults true
  dataFilesSection?: boolean; // see SimpleSettingsPanel.dataFilesSection above; defaults false
}

export interface DynamicSettingsPanel {
  kind: 'dynamic';
  key?: string; // same rule; only used as the panel key when getPanels is omitted
  getPanels?(args: Record<string, never>, ctx: HookContext): Promise<SettingsPanelDescriptor[]>;
  getDefinition(args: { panelKey: string }, ctx: HookContext): Promise<FormDefinition>;
  validateField?(args: { panelKey: string; fieldKey: string; value: any; state: Record<string, any> }, ctx: HookContext): Promise<string | null>;
  transformField?(args: { panelKey: string; fieldKey: string; value: any; state: Record<string, any> }, ctx: HookContext): Promise<any>;
  // Fired on every accepted change (post-validate/transform). Unlike
  // FormHook.onChangeField, this isn't patching sibling form state — it's
  // "the field committed, go persist it." The extension is responsible for
  // its own persistence here (e.g. host.setSettings — NOT host.kvSet, which
  // is in-memory only and does not survive a runtime restart), since the
  // engine can't infer storage for computed fields the way it can for
  // Tier 1.
  onChangeField(args: { panelKey: string; fieldKey: string; value: any; state: Record<string, any> }, ctx: HookContext): Promise<void>;
}
```

`state` is always that panel's own values, bare-keyed (never the app's
`<panelKey>.`-namespaced form), and it holds the value being written — the
edited field already reads as `value`, not as what it was before. That is true
whether the edit came from the settings screen or from a `SET` command, so a
hook may validate across fields without caring which surface it was reached
from.

Core discriminates between the two tiers by the required `kind` tag
(`'simple' | 'dynamic'`), not by shape — a panel can't accidentally match
both, and a typo in `kind` is a compile error rather than silent
misclassification.

---

## The `list` field type and nested items

A settings field can itself be a repeatable list of objects — e.g. a list of
saved exchange presets. This reuses `FormField`/`SettingsField` recursively
rather than introducing a separate schema:

```ts
{
  type: "field",
  fieldType: "list",
  key: "presets",
  label: "Saved Presets",
  itemTitle: "${label} — ${exchange}",
  itemFields: [
    { type: "field", fieldType: "text", key: "label", label: "Name" },
    { type: "field", fieldType: "text", key: "exchange", label: "Exchange" }
  ]
}
```

Each item's shape is described by `itemFields`. In `SettingsField`,
`itemFields` is typed as `SettingsField[]`, not the plain `FormField[]` a
Tier 2 form's `itemFields` would allow — so a Tier 1 list's items are
declarative-only too, same as every other Tier 1 field; a `validate`/
`transform` closure inside a Tier 1 list item is a type error, not a
silently-ignored one.

The list renders as a single row summarizing the current items as a
comma-separated list of `itemTitle`s (templated against each item's
values). Tapping it opens an editor dialog with a row per item plus an
"Add" row; every mutation commits immediately and "Done" closes the
dialog. Editing or adding an item opens the same form renderer
recursively, scoped to `itemFields`, in a nested dialog — there is no
separate "list item editor" widget, just `FormRenderer` given a smaller
`FormDefinition`.

Set `orderable: true` to allow drag-to-reorder in the editor; omit it for
lists where order doesn't matter.

## The `multiselect` field type

Picking several values from a fixed vocabulary — the user cannot enter new
ones (that's what `list` is for). `value` is a plain string list; `options`
is the vocabulary, each option optionally flagged `common: true`:

```ts
{
  type: "field",
  fieldType: "multiselect",
  key: "bands",
  label: "Bands",
  icon: "radio",
  value: ["80m", "40m", "20m"],
  options: "$core.bands"   // or inline: [{ label: "80m", value: "80m", common: true }, ...]
}
```

Like `list`, it renders as a single row summarizing the selection
comma-separated; tapping opens an editor dialog with a switch per option.
Options disclose in up to three tiers: `common: true` ones show upfront,
unflagged ones behind the first disclosure step, and `uncommon: true`
ones behind the second — the action-row toggle cycles Show more → Show
all → Show fewer (or just Show all / Show fewer when no option is flagged
uncommon). A hidden-tier value that has been selected stays visible for
the dialog's lifetime. Declare `defaultValue` (a string list) to offer a
Defaults button restoring that selection; omit it and none is shown. The
selection always keeps the canonical order of `options` — `orderable` is
reserved for a future manual-ordering variant and currently ignored.

## Reading and writing settings from extensions

Extensions access settings through two host calls:

- `host.getSettings()` — the full read view: resolved core values (theme,
  locale, font scale, distance units, logging toggles, bands/modes,
  privacy consents, the active profile's `operatorCall`, `operatorName`,
  `operatorEmail`, `operatorClub` and `operatorSection`, `syncEnabled`,
  `developerMode`, `appName`, `enabledExperiments`) plus every extension's own settings group
  under `extensions` (keyed `extension_<key>`). Reading is unrestricted —
  settings are not secrets. Credentials and accounts are deliberately
  absent: they live in the platform keychain via the account hook system,
  never in settings. The `operator*` profile fields beyond the callsign are
  all optional and free-form — an extension must cope with `''`, and must
  not treat `operatorSection` as validated against any section table.
- `host.setSettings({ key: value, ... })` — writes into the calling
  extension's OWN group only (`extension_<key>`; the namespace is injected
  by the SDK). Core settings and other extensions' groups are read-only.

## System lists

A field's `options` can name a **system list** instead of inlining the
choices: a `$`-prefixed identifier, `$<namespace>.<list>`, resolved by the
app before the definition reaches the renderer. This keeps vocabularies
owned elsewhere (halo_core's band table, runtime-contributed controls) out
of settings declarations — both core settings groups and extension
settingsPanels can reference them.

Currently defined (see `app/lib/settings/system_lists.dart`):

- `$core.bands` — the extended band vocabulary (halo_core's snapshot of
  lib-operation-data's `EXTENDED_BANDS`); `POPULAR_BANDS` flagged `common`.
- `$core.modes` — every ADIF mode and submode (snapshot of
  `ADIF_MODES_AND_SUBMODES`); `MAIN_MODES` flagged `common`.

The `$extensions.*` namespace is reserved for runtime-derived lists (e.g. a
future `$extensions.secondaryLoggingControls`). An unknown name resolves to
no options — logged, and the field renders disabled rather than failing
the panel.

## The `secret` field type

Renders as an obscured text field (`fieldType: 'secret'`). For Tier 1
panels, values are persisted via secure storage rather than the plain KV
store — see "Persistence" above. Tier 2 panels are responsible for their own
storage in `onChangeField` and should apply the same care. Not for account
credentials — those belong on `AccountHook.fields`, not here (see below).

## The `account` field type

A read-only reference into the separate `account` hook system — renders a
connection-status row (e.g. "Connected as KI2D" / "Not Connected") with a
Manage/Connect button that opens that account's own standalone dialog. It
never defines or stores account data itself:

```ts
{
  type: "field",
  fieldType: "account",
  key: "qrzStatus",
  label: "QRZ.com Account",
  account: { key: "qrz" } // matches the account's AccountHook.kvKey
}
```

`subkey` is an opaque, extension-defined discriminator, only needed when one
extension exposes more than one account-like entity under the same `key`
(e.g. multiple stored profiles) — most accounts don't need it.

> **Not implemented yet:** `AccountHook` registrations are one-`kvKey`-per-
> registration today, so there's no real scenario where two accounts share a
> `key` to disambiguate between — `SettingsView`'s Manage/Connect handler
> accepts `subkey` but only matches on `key`, logging a warning if `subkey`
> is set rather than silently picking the wrong account. Wiring this up for
> real needs `AccountHook` to grow its own multi-account concept first.

## The `action` element

A button that invokes a named hook method against the current panel state
and shows the returned string as a result banner:

```ts
{ type: "action", key: "clear", label: "Clear Cache", method: "clearCache" }
```

`method` is resolved dynamically against an extra, undeclared property on
the registered hook object (for Tier 1) or the hook object backing the panel
(for Tier 2) — not statically part of `SimpleSettingsPanel`/
`DynamicSettingsPanel`. The SDK's `Hook` union includes
`Record<string, unknown>`, so TypeScript permits the extra property on the
object literal without a cast. This is a general mechanism, not specific to
credentials — account connection testing lives on `AccountHook.testCredentials`
instead (see below).

## `devMode` fields

Any field (or header/divider/action, anything in `fields`/`elements`) can be
marked `devMode: true` to hide it unless the app's developer mode is on — see
[forms.md's `devMode` elements](./forms.md#devmode-elements) for the full
behavior (orange accent when shown, host-driven visibility). Useful for a
Tier 1 panel that wants to expose a debug field (e.g. a raw API endpoint
override) without it cluttering the panel for regular users:

```ts
{ type: "field", fieldType: "text", key: "apiEndpointOverride", label: "API Endpoint Override", devMode: true }
```

## `aliases`: short names for the SET command

The `SET`, `SHOW` and `HIDE` commands search every declared setting by key,
label and description (see `app/lib/settings/settings_catalog.dart`). Matching is by
subsequence and the ranking is usually enough on its own, but not for a
setting whose real name buries the word people reach for: `REPORT` matches
`defaultReport`, `defaultReportCW` and `defaultReportFT8` alike, and none of
them is obviously the one meant.

`aliases` fixes that by giving a field extra names, matched at the same top
tier as its key:

```ts
{ type: "field", fieldType: "text", key: "defaultReport", label: "Default Report",
  aliases: ["report", "rst"] }
```

A single string is accepted as well as a list. Aliases are matched
case-insensitively and ignoring punctuation, like every other term (`zeroBeat`,
`Zero Beat` and `ZEROBEAT` are the same term), so there is no point declaring
case or spacing variants of a name that already matches.

Aliases are for names an operator would plausibly *reach for* — not a thesaurus.
Every alias is one more thing that can collide with another setting's real name,
and a collision costs a disambiguation prompt on a query that used to be exact.

## Common Preferences and environment gating

The app has two settings screens: **All Settings**, listing every declared
group and panel, and **Common Preferences**, a short list of the handful of
settings most users ever touch. Which fields land on Common Preferences —
and which platforms show a field at all — is declared per-element, not
maintained as a separate list somewhere else in the app. Any field, link, or
action (core-declared or extension-declared, Tier 1 or Tier 2 alike) can set:

- **`common: true`** — also show this element on Common Preferences, in
  addition to All Settings. Off by default. Not the same thing as
  `FormFieldOption.common`/`uncommon` above — that's a `multiselect`
  option's own disclosure tier (upfront vs. behind "Show more"), a
  different scope (an option inside one field, not the field itself).

  ```ts
  { type: "field", fieldType: "select", key: "units", label: "Units", value: "metric", options: [...], common: true }
  ```

- **`environment: 'ios,android'`** (or `'-web'`, or an array either way) —
  restrict which platform(s) show this element at all. This is a platform
  gate, not a Common-vs-All one: an excluded field disappears from every
  settings surface on that platform, not just Common Preferences. Every
  token unprefixed is a whitelist (show ONLY there); every token
  `-`-prefixed is a blacklist (show everywhere EXCEPT there); mixing the two
  forms in one attribute is invalid and treated as if `environment` were
  absent. Tokens: `ios`, `android`, `macos`, `windows`, `linux`, `web` — the
  same vocabulary server notices filter on. Omit `environment` for "every
  platform".

  ```ts
  // A field that only makes sense with an on-screen keyboard.
  { type: "field", fieldType: "checkbox", key: "showNumbersRow", label: "Numbers Row", value: false,
    common: true, environment: "ios,android" }
  ```

Both attributes are evaluated fresh every time the panel reloads (same as
`devMode`), so they can vary with `getDefinition`'s own logic if a Tier 2
panel wants to compute them — though for most panels a static value is all
that's needed. `common` only applies to field/link/action elements — a
header/divider/markdown block can't be individually whitelisted onto Common
Preferences, since that screen builds its own section headers from each
group/panel's title rather than reusing the panel's own `FormHeader`
elements. `environment`, by contrast, applies to every element type,
headers included — a Tier 2 panel with a platform-specific sub-section can
gate its own header the same way it gates the fields under it.

## Settings targets

A third element attribute, **`target`**, opts a field into a target-scoped
settings modal somewhere else in the app — a curated view built around one
concern rather than one owning group/panel. The logging view's tune icon is
the first one: it collects every declared field (core- or
extension-declared) tagged `target: 'logging'`, wherever it's declared, into
one dialog.

```ts
{ type: "field", fieldType: "checkbox", key: "showBearing", label: "Show Bearing",
  value: false, target: "logging" }
```

`target` is a single target key, or an array when the same field should
surface under more than one. A `'<target>-extended'` target (e.g.
`'logging-extended'`) is the same idea, but starts hidden behind that
dialog's own "show more settings" disclosure — for a field related to the
target but niche enough it shouldn't clutter the default view:

```ts
{ type: "field", fieldType: "checkbox", key: "leftieMode", label: "Leftie Mode",
  value: false, target: "logging-extended" }
```

Omitting `target` doesn't hide a field from anywhere it already appears —
Common Preferences and All Settings are unaffected either way. It's purely
additive: an extra place a field can be reached from, on top of wherever
`common`/`environment` already put it.

`type: "field"` (including `fieldType: "account"`) and `type: "action"`
elements can both set `target` and both appear in a target-scoped modal —
an action's method dispatches through the same extension host call the
full settings screens use, and an account field's Manage/Connect button
opens that account's own standalone dialog, exactly as it would from All
Settings.

## Restarting the runtime after a Tier 2 field commits

A `kind: 'dynamic'` field can set `restartOnChange: true` when its value is
only ever consulted at `onActivation` — the common case being a list of URLs
the extension turns into `dataFile` hook registrations at startup, the way
`getPanels`/`getDefinition` can be re-queried on demand but `onActivation`
cannot. Once the field commits, the app calls the same `restartRuntime()`
already used when the user toggles an extension on/off, so `onActivation`
runs again and picks up the new value via `host.getSettings()`.

Don't reach for this by default — most Tier 2 fields are read fresh by a
hook that runs on every relevant call (`getDefinition`, `lookup`, etc.), so
they see a change immediately with no restart needed. Reserve
`restartOnChange` for the fields that genuinely can't be re-read any other
way, since a restart is a real interruption, not a free way to "make sure
everything's fresh."

`onActivation` re-running is only half the story — it also needs to read
that new value, which means `await host.getSettings()` before any
`registerHook` calls that depend on it. Nothing in the kernel awaits
`onActivation` itself (it's dispatched fire-and-forget), so those
`registerHook` calls land whenever that promise happens to resolve, not
before boot "finishes." In practice this is safe because the app's own
boot path always makes an unrelated host round trip of its own before
returning control to any caller — which reliably gives a pending
`getSettings()` continuation enough time to land first — but there's no
hard guarantee of that ordering, only an incidental one. Register anything
that DOESN'T depend on settings (a static builtin list, say) synchronously,
before the `await`, so at least that part is never subject to this.

---

## Relationship to `AccountHook`

`account` and `settingsPanel` are separate, complementary hook categories —
`settingsPanel` does not supersede `account`. Extensions still define
account credentials by registering an `account` hook exactly as before:

```ts
export interface AccountField {
  key: string;
  label: string;
  type: 'text' | 'email' | 'secret';
  preface?: string;
  postface?: string;
}

export interface AccountHook {
  label: string;
  kvKey?: string; // defaults to the extension key; see "Key namespacing"
  fields?: AccountField[];
  oauth2?: OAuth2Config;
  testCredentials(credentials: Record<string, string>, ctx: HookContext): Promise<string>;
}
```

Core aggregates every extension's `account` hook (one hook per account) into
the account list shown in Settings; each account is stored separately
(credentials in secure storage, keyed by `kvKey`) and rendered in its own
standalone dialog — not inline in a `settingsPanel`'s `FormRenderer`.

A `settingsPanel` field can reference an account for display/navigation via
`fieldType: 'account'` (see above), but the account itself is still fully
owned by its `AccountHook` registration. `extensions/lookups/qrz` continues
to register under `account` — there is no migration to do.
