# Form description schema

Extensions can use the Form description schema to request user input through complex forms rendered in either a modal dialog or a dedicated view screen.

Forms are structured as a list of fields, headers, section dividers, and markdown text blocks. They also support initial state values and asynchronous validation/transformation callbacks executed back in the JavaScript runtime.

---

## Form Definition Schema

All types are defined in `extensions/sdk/src/types.ts`.

```ts
export type FormFieldType =
  | 'text'
  | 'multiline'
  | 'email'
  | 'callsign'
  | 'number'
  | 'select'
  | 'radio'
  | 'checkbox'
  | 'secret'  // obscured text, e.g. passwords/API keys
  | 'list'    // a repeatable list of items, each shaped like itemFields
  | 'account'; // a read-only reference into the separate account hook system

export interface FormFieldOption {
  label: string;
  value: any;
}

export interface FormField {
  type: 'field';
  fieldType: FormFieldType;
  key: string;
  label: string;
  value?: any; // initial state value if not provided in host call state
  placeholder?: string;
  uppercase?: boolean; // force typed input to uppercase (callsign fields always are)
  options?: FormFieldOption[]; // required for select/radio
  validate?: (value: any, state: Record<string, any>) => string | null | undefined | Promise<string | null | undefined>;
  transform?: (value: any, state: Record<string, any>) => any | Promise<any>;
  // Only used when fieldType === 'list'. `value` is then a
  // Record<string, any>[]; each item is shaped like itemFields. By default
  // the field renders as one summary row (from itemTitle, templated
  // against the item's values, e.g. "${name}" — NOT "{{name}}") that opens
  // an editor dialog with per-item rows and add/edit/delete; `inline: true`
  // instead renders those rows (with reorder handle/delete per row, and an
  // Add row) directly in the form, skipping that outer dialog — for a list
  // that's the main content of its own section. Either way, tapping a row
  // (or Add) opens the same itemFields editor dialog (the form renderer
  // recursively, scoped to itemFields).
  itemFields?: FormField[];
  itemTitle?: string;
  orderable?: boolean;
  inline?: boolean;
  // Singular noun for one item (e.g. "custom note file"), used in the
  // editor dialog's Add/Edit titles and the Add button instead of `label`
  // — which names the list as a whole and is typically plural. Defaults to
  // `label` when omitted.
  itemLabel?: string;
  // Only used when fieldType === 'account'. See settings.md's "account
  // field type" section — this never defines or stores account data
  // itself, it's a pointer into the separate `account` hook system.
  account?: { key: string; subkey?: string };
  // Hidden entirely unless the app's developer mode is on; when shown,
  // rendered in the orange "dev mode" accent (label/icon/subtitle tinted,
  // no badge or border — matches app-polo's `styles.colors.devMode`
  // convention). Every FormElement variant below supports this, not just
  // fields — a whole section header can be dev-mode-only too.
  devMode?: boolean;
  // Settings-panel-only (ignored in ad hoc forms) — see settings.md's
  // "Common Preferences and environment gating". Also shows this field on
  // the app's Common Preferences quick-access panel.
  common?: boolean;
  // Settings-panel-only. Restricts which platform(s) show this field at
  // all: one or more platform tokens (`ios`, `android`, `macos`,
  // `windows`, `linux`, `web`), comma-separated or as an array. Unprefixed
  // tokens are a whitelist; `-`-prefixed tokens are a blacklist. See
  // settings.md.
  environment?: string | string[];
  // Settings-panel-only. Opts this field into a target-scoped settings
  // modal elsewhere in the app — see settings.md's "Settings targets".
  target?: string | string[];
  // Only meaningful within a `kind: 'dynamic'` settingsPanel. After this
  // field commits, the app restarts the extension runtime — for a value
  // only consulted at onActivation (e.g. a list of URLs to register as
  // dataFile hooks). See settings.md's Tier 2 section.
  restartOnChange?: boolean;
}

export interface FormHeader {
  type: 'header';
  title: string;
  subtitle?: string;
  // How the heading is drawn. Omitted, it is plain text above the fields
  // that follow. 'section' is the app's section band — the accent title
  // over a hairline, which holds the top of the surface while its own rows
  // scroll under it. 'category' is the FILLED band, for a heading that is
  // the top-level grouping of its surface rather than one section inside
  // one (docs/design/user-interface.md § Settings lists). A settings panel
  // is already inside a category, so its own headings take 'section'.
  style?: 'default' | 'section' | 'category';
  devMode?: boolean;
  environment?: string | string[]; // settings-panel-only; see FormField.environment (not `common` — see settings.md)
}

export interface FormSectionDivider {
  type: 'divider';
  title?: string;
  devMode?: boolean;
  environment?: string | string[]; // settings-panel-only; see FormField.environment
}

export interface FormMarkdownBlock {
  type: 'markdown';
  text: string;
  devMode?: boolean;
  environment?: string | string[]; // settings-panel-only; see FormField.environment
  collapsible?: boolean; // starts collapsed behind a tappable `title` header; requires `title`
  title?: string; // the tappable header shown when `collapsible` is set; ignored otherwise
}

// A button that invokes a named hook method (e.g. 'clearCache') against the
// current form/panel state and shows the returned string as a result
// banner. `method` isn't statically declared anywhere — it's resolved
// against an extra, undeclared property on the registered hook object at
// dispatch time, the same "extra property beyond the typed interface" the
// SDK already permits (see settings.md's settingsPanel note). Not used for
// account credentials — those have their own testCredentials on AccountHook.
export interface FormActionElement {
  type: 'action';
  key: string;
  label: string;
  method: string;
  devMode?: boolean;
  common?: boolean;   // settings-panel-only; see FormField.common
  environment?: string | string[]; // settings-panel-only; see FormField.environment
}

// A row that opens an external URL (icon-row-styled tile with an
// open-in-new icon button); how it opens is app policy. Links carry no
// value and never appear in form state.
export interface FormLinkElement {
  type: 'link';
  key?: string;
  label: string;
  url: string;
  icon?: string;
  description?: string;
  devMode?: boolean;
  common?: boolean;   // settings-panel-only; see FormField.common
  environment?: string | string[]; // settings-panel-only; see FormField.environment
}

export type FormElement = FormField | FormHeader | FormSectionDivider | FormMarkdownBlock | FormActionElement | FormLinkElement;

export interface FormDefinition {
  title?: string;
  subtitle?: string;
  elements: FormElement[];
}
```

The same `FormDefinition`/`FormField` schema is also the basis for the settings panel system — see [settings.md](./settings.md).

## `devMode` elements

Any element — a field, a header, a divider, a markdown block, an action
button — can be marked `devMode: true`. It's then hidden entirely (not
rendered at all, not part of the submitted values) unless the app's developer
mode is on; when it is, the element renders normally but tinted in the same
orange accent app-polo uses for dev-mode-only settings (`styles.colors.devMode`
— label/icon/subtitle text color, no badge or border). This is host-driven —
the renderer is told whether developer mode is on, it doesn't check any
setting itself — so it works the same whether the form comes from an
extension's ad hoc `host.showForm` call or a `settingsPanel`.

---

## Usage

### 1. Dialog Flow (`host.showForm`)

An extension can prompt the user at any time using a modal dialog:

```ts
import { host } from "@ham2k/extension-sdk";

const result = await host.showForm({
  title: "Setup Contest",
  subtitle: "Configure exchange and operator options",
  elements: [
    {
      type: "header",
      title: "Station Parameters"
    },
    {
      type: "field",
      fieldType: "callsign",
      key: "operatorCall",
      label: "Operator Callsign",
      validate: (val) => val.length < 3 ? "Invalid callsign" : null,
      transform: (val) => val.toUpperCase()
    },
    {
      type: "divider"
    },
    {
      type: "field",
      fieldType: "select",
      key: "category",
      label: "Contest Category",
      options: [
        { label: "Single Operator Low Power", value: "SOLP" },
        { label: "Single Operator High Power", value: "SOHP" },
        { label: "Multi Operator", value: "MULTI" }
      ]
    }
  ]
}, {
  operatorCall: "KI2D" // pre-filled state
});

if (result) {
  console.log("Form values submitted:", result);
} else {
  console.log("Form cancelled");
}
```

### 2. View/Hook Flow (`form` category)

Extensions can also contribute static/predefined forms by registering a hook in the `form` category. The host can query the form by key, validate fields, and transform them:

```ts
// Static registration in extension code
api.registerHook('form', {
  key: 'my-contest-settings',
  hook: {
    async getDefinition(args, ctx) {
      return {
        title: "Contest Setup",
        elements: [
          {
            type: "field",
            fieldType: "text",
            key: "exchange",
            label: "State/Section Exchange"
          }
        ]
      };
    },
    async validateField({ fieldKey, value, state }, ctx) {
      if (fieldKey === 'exchange' && value.length !== 2) {
        return "Exchange must be a 2-character abbreviation";
      }
      return null;
    },
    async transformField({ fieldKey, value, state }, ctx) {
      if (fieldKey === 'exchange') {
        return value.toUpperCase();
      }
      return value;
    }
  }
});
```

---

## Validation & Transformation Lifecycle

1. **User input**: When a user fills out text or makes selections, the Dart UI clears any previous error for that field.
2. **Submit validation**: When the user clicks **Save / Submit**:
   - The Flutter form renderer triggers validation for each field asynchronously.
   - Any validation error returns back to Dart and is displayed underneath the field. If any fields have errors, submission is aborted.
3. **Submit transformation**: When all fields are successfully validated, Dart invokes any JS transformation callbacks for each field.
4. **Completion**: The final transformed state is resolved and returned back to the caller (or saved in the view context).
