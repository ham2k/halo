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
  | 'checkbox';

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
  options?: FormFieldOption[]; // required for select/radio
  validate?: (value: any, state: Record<string, any>) => string | null | undefined | Promise<string | null | undefined>;
  transform?: (value: any, state: Record<string, any>) => any | Promise<any>;
}

export interface FormHeader {
  type: 'header';
  title: string;
  subtitle?: string;
}

export interface FormSectionDivider {
  type: 'divider';
  title?: string;
}

export interface FormMarkdownBlock {
  type: 'markdown';
  text: string;
}

export type FormElement = FormField | FormHeader | FormSectionDivider | FormMarkdownBlock;

export interface FormDefinition {
  title?: string;
  subtitle?: string;
  elements: FormElement[];
}
```

---

## Usage

### 1. Dialog Flow (`host.showForm`)

An extension can prompt the user at any time using a modal dialog:

```ts
import { host } from "@ham2k/polo-sdk";

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
