# Settings panel schema

Extensions can contribute panels to the app's settings screen by registering
a hook in the `settingsPanel` category. Panels are rendered with the same
`FormRenderer` used for [ad hoc forms](./forms.md) — a settings panel is a
`FormDefinition` whose fields' values happen to be persisted, not just
submitted once.

This is a separate, complementary mechanism to the `account` hook category
(see [Relationship to `AccountHook`](#relationship-to-accounthook) below) —
`settingsPanel` never defines, stores, or edits account credentials itself.

> **Status: 🔜 planned.** The types below exist in
> `extensions/sdk/src/types.ts`; the Dart-side rendering and dispatch (a
> `settingsPanel` case in `ExtensionService`, a data-driven panel list in
> `SettingsView`, and `FormRenderer` support for the `secret`/`list`/`account`/
> `action` additions to the form schema) is not implemented yet.

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
  // its own persistence here (e.g. host.kvSet), since the engine can't
  // infer storage for computed fields the way it can for Tier 1.
  onChangeField(args: { panelKey: string; fieldKey: string; value: any; state: Record<string, any> }, ctx: HookContext): Promise<void>;
}
```

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

The list renders as a column of summary rows (from `itemTitle`, templated
against the item's values) with edit/delete affordances and an "Add" row.
Editing or adding an item opens the same form renderer recursively, scoped
to `itemFields`, in a dialog — there is no separate "list item editor"
widget, just `FormRenderer` given a smaller `FormDefinition`.

Set `orderable: true` to allow drag-to-reorder; omit it for lists where
order doesn't matter.

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
