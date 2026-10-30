# Forms

One form schema serves every place an extension asks the operator for
input: a dialog it opens itself with `host.showForm`, a form the app asks
for by key through the `form` category, a [settings panel](settings.md),
and a [panel](panels.md)'s configuration. A form is a list of fields,
headers, dividers, markdown blocks, links and action buttons, with initial
values and optional validation and transformation callbacks that run back in
your extension.

## The schema

```ts
type FormFieldType =
  | "text" | "multiline" | "textTemplate" | "email" | "callsign" | "number"
  | "select" | "radio" | "checkbox" | "multiselect"
  | "secret"       // obscured text: a password, an API key
  | "list"         // a repeatable list of items, each shaped like itemFields
  | "account"      // a read-only reference into the account system

interface FormField {
  type: "field"
  fieldType: FormFieldType
  key: string
  label: string
  value?: any                   // initial value, unless the state passed to the form has one
  placeholder?: string
  uppercase?: boolean           // force typed input to uppercase; callsign fields always are
  options?: { label: string; value: any; common?: boolean; uncommon?: boolean }[] | string   // select, radio, multiselect; or a "$core.…" system list
  validate?: (value, state) => string | null | undefined | Promise<…>
  transform?: (value, state) => any | Promise<any>
  // text: codes the field takes, offered under it as the operator types (matched on code and
  // name) and named beside it; a value that is none of them shows in red with a `?` once the
  // operator pauses or leaves the field, but Save still writes what was typed. `standalone`
  // marks a code valid only as the whole value, never inside a multiValue list. A settings list
  // row, a field with an icon, and an older app render the plain text field instead
  suggestions?: { code: string; name?: string; standalone?: boolean }[]
  multiValue?: { separator: string; inheritPrefix?: number }   // with suggestions: several codes joined by `separator` (ALB/SCH), each suggested, named and checked on its own
  transforms?: { pattern: string; replacement: string; flags?: string }[]  // live reformatting passes: ALB,SCH becomes ALB/SCH
  // secret, in a settings list: what the row says while a value is stored
  storedText?: string
  // list
  itemFields?: FormField[]
  itemTitle?: string            // "${name} — ${exchange}": templated against the item, `${key}` not Liquid
  itemLabel?: string            // singular noun for one item, for the editor's titles and its Add button; defaults to `label`
  orderable?: boolean
  itemSwitch?: string           // the key of an on/off value in each item, shown as a switch on its row
  inline?: boolean              // render the rows in the form itself rather than behind a summary row
  // account
  account?: { key: string; subkey?: string }
  // textTemplate
  templateContext?: "export" | "adif" | "text"
  templateSample?: Record<string, JSONValue>
  // multiselect: the string list its Defaults button restores; textTemplate: the string its Reset
  // button restores (the SDK types it as a list, so a textTemplate's needs a cast)
  defaultValue?: any
  // visibility and placement; see below and Settings panels
  devMode?: boolean
  common?: boolean
  environment?: string | string[]
  target?: string | string[]
  restartOnChange?: boolean
}
// A settings panel's SettingsField is a FormField without the validate/transform closures,
// plus pattern?, patternError? and aliases?: string | string[]

interface FormHeader {
  type: "header"
  title: string
  subtitle?: string
  style?: "default" | "section" | "category"   // plain text, the accent band over a hairline, the filled band
  // a "section" folds the rows under it, up to the next band or a sectionEnd, and the app remembers
  // how the operator left each one; `collapsed` starts it shut, `key` (unique within the panel) names
  // it for that memory, else the title does and a reworded heading forgets the fold; both ignored
  // for any other style
  collapsed?: boolean
  key?: string
  devMode?: boolean
  environment?: string | string[]
}
interface FormSectionEnd { type: "sectionEnd" }   // ends the band above it; rows after it belong to no band and do not fold with it
interface FormSectionDivider { type: "divider"; title?: string; devMode?: boolean; environment?: string | string[] }
interface FormMarkdownBlock { type: "markdown"; text: string; collapsible?: boolean; title?: string; devMode?: boolean; environment?: string | string[] }   // collapsible starts folded behind `title`, which it requires
interface FormActionElement { type: "action"; key: string; label: string; method: string; style?: "row"; icon?: string; devMode?: boolean; common?: boolean; environment?: string | string[]; target?: string | string[] }   // style "row" is an icon row with a chevron; omit it for a button
interface FormLinkElement { type: "link"; label: string; url: string; key?: string; icon?: string; description?: string; devMode?: boolean; common?: boolean; environment?: string | string[] }   // http, https and mailto only; how it opens is the app's; carries no value and never appears in form state

type FormElement = FormField | FormHeader | FormSectionEnd | FormSectionDivider | FormMarkdownBlock | FormActionElement | FormLinkElement

interface FormDefinition {
  title?: string
  subtitle?: string
  elements: FormElement[]
}
```

The exact types are in `dist/index.d.ts`. A settings panel is already inside
a category, so its own headings take `style: "section"`.

## Dialogs you open: `host.showForm`

```ts
const result = await host.showForm(
  {
    title: "Set up the contest",
    elements: [
      { type: "header", title: "Station" },
      { type: "field", fieldType: "callsign", key: "operatorCall", label: "Operator callsign",
        validate: (v) => (v.length < 3 ? "Too short to be a callsign" : null),
        transform: (v) => v.toUpperCase() },
      { type: "divider" },
      { type: "field", fieldType: "select", key: "category", label: "Category",
        options: [{ label: "Single operator, low power", value: "SOLP" }, { label: "Multi operator", value: "MULTI" }] },
    ],
  },
  { operatorCall: "W7ABC" },      // pre-filled state
)
if (result) { /* result.operatorCall, result.category */ } else { /* cancelled */ }
```

The call completes when the dialog closes, with the submitted values or
`null`. A dialog is one extension's at a time: while another extension's
dialogs are up, yours waits for them to close. You may have **3 open**, one
over the other, **3 waiting**, and open **10 a minute**; past any of these
the call throws.

## Forms the app asks for

Register under the `form` category to let the app show a form by key,
validate its fields and transform them:

```ts
registerHook("form", {
  key: "w7abc-contest_setup",
  hook: {
    async getDefinition(args, ctx) {
      return { title: "Contest setup", elements: [{ type: "field", fieldType: "text", key: "exchange", label: "Exchange" }] }
    },
    async validateField({ fieldKey, value, state }, ctx) {
      return fieldKey === "exchange" && value.length !== 2 ? "Two characters" : null
    },
    async transformField({ fieldKey, value, state }, ctx) {
      return fieldKey === "exchange" ? value.toUpperCase() : value
    },
  },
})
```

This is the shape a dynamic [settings panel](settings.md#tier-2-dynamicsettingspanel)
builds on, and the `form` input kind of an activity's operation controls
([Activities](activities.md#controls)) opens one.

## Validation and transformation

1. As the operator edits a field, the app clears any earlier error on it.
2. On **Save**, the app runs every field's `validate` and shows each error
   under its field. Any error aborts the submission.
3. With every field valid, the app runs every field's `transform`.
4. The transformed state is returned to the caller, or saved where the form
   lives.

In a `host.showForm` dialog the callbacks are the closures on the field; in
a `form` hook and a dynamic settings panel they are `validateField` and
`transformField`. A Tier 1 settings panel has neither and uses `pattern`
instead.

## devMode elements

Any element marked `devMode: true` is hidden entirely, and absent from the
submitted values, unless the app's developer mode is on. When it is, the
element renders normally in the developer accent. The app tells the
renderer whether developer mode is on; the form never checks a setting
itself, so it behaves the same in a dialog and in a settings panel.

## Text templates

`fieldType: "textTemplate"` is a string field shown as an editor row that
also displays its rendered sample. It opens a multiline Liquid editor with
a sample preview, syntax errors, insertable attributes, flow-control
examples, and a read-only filter reference. Save commits the draft; Cancel,
Escape and dismissal discard it; `defaultValue` supplies the Reset button; a
disabled field does not open the editor.

```ts
{ type: "field", fieldType: "textTemplate", key: "filename", label: "File name",
  value: "{{ op.date }} {{ log.station }}", templateContext: "export",
  templateSample: { log: { activity: "LLOTA", ref: "AR-0001" } } }
```

`templateContext` picks the vocabulary the editor offers: `export` for
filenames and titles, `adif` adds the contact's attributes, `text` is
generic. `templateSample` replaces values in the preview's `operation`,
`qso` and `log`. The preview uses the same engine and vocabulary as the
exports; [Templates](templates.md) has both.
