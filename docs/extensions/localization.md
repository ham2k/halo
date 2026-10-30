# Text and locale

What an extension shows the operator should read in the operator's
language and follow the operator's conventions for numbers and dates. The
sandbox gives you less help with this than a browser would, and this page is
the whole of what you need to know.

## Your own strings

The kernel carries `i18next`, and the SDK's `createTranslator` builds a
translator over your own resources for the locale the hook was called in:

```ts
import { createTranslator } from "@ham2k/extension-sdk"
import type { HookContext } from "@ham2k/extension-sdk"

const resources = {
  en: { translation: { name: "Lakes on the Air", newLake: "New lake" } },
  es: { translation: { name: "Lagos en el Aire", newLake: "Lago nuevo" } },
}

export const LakeHandler = {
  async decorateRef({ ref }, ctx: HookContext) {
    const t = createTranslator(resources, ctx.locale ?? "en")
    return { ...ref, name: t("name") }
  },
}
```

`ctx.locale` is the app's active language (`en`, `es`, …). Resolve strings
per call rather than once at activation: the operator can change the
language while your extension is running.

Some hook fields are read without a call of their own, and take either a
plain value or a function `(args, ctx) => value` so they can be localized
the same way. The SDK types them `Localizable<T>`: an account's `label`,
`description` and `fields`, a data file's `name`, `description` and `url`.

The manifest's `name`, `description` and `keywords` are localized in the
manifest itself, under `translations`; [The manifest](manifest.md#identity)
shows the shape.

## The app's strings

`host.translate(key)` reads one of the app's own strings by its dot-path
key, in the active locale; `host.translateAll(keys)` reads several in one
round trip. Either answers `null` for a key the app does not have, or one
that needs interpolation. Use it for a word the app already has (a band, a
mode family, "Settings") rather than shipping your own copy of it, and never
rely on it: a key can go away with an app release.

`ctx.appName` is the app's name on this platform ("Ham2K Logger" on desktop,
"Ham2K Portable Logger" on mobile). Use it wherever you identify the app to
a service or a file, such as a spot's `source` or an ADIF `PROGRAMID`.

## Numbers

**Counts, scores and statistics shown to the operator take thousands
separators.** Use `fmtInteger` from `@ham2k/lib-format-tools`:

```ts
import { fmtInteger } from "@ham2k/lib-format-tools"
const label = `${fmtInteger(tally.total)} QSOs`
```

**Frequencies are written with periods for grouping and decimal alike**,
`14.285.5`, whatever the device's conventions say. `fmtFreq` writes them
that way and `parseFreq` (from 1.3.1 of the library, which the app carries)
reads them back, resolving `14.285`, `14.200.5`,
`1.296`, `1296.000` and `1.296.000` to what an operator means by them, and
reading a comma as a period.

**For every other number the operator types or reads**, `ctx.decimalSeparator`
and `ctx.groupingSeparator` are the characters their device writes numbers
with. Two traps:

- On some locales (fr, ru, sv, pl) the grouping separator is a narrow
  no-break space (U+202F), which no keyboard produces. Strip it, and strip an
  ordinary space too, since that is what people type.
- It can be empty. Guard before using it as a delimiter: `split("")` splits
  everywhere.

**Anything machine-facing takes a plain period-decimal number**, whatever the
operator sees: ADIF, a spot posted to a service, every wire format.

Two more conventions travel in the context: `ctx.distanceUnits`
(`kilometers` or `miles`) and `ctx.gridPrecision` (6 or 8), how many
characters the operator shows a Maidenhead locator with. A locator's length
is a claim about how well a location is known, so a hook that writes one for
a human or a program states the operator's claim; never truncate a
coordinate to it.

## Dates and times

**`Intl` is undefined on native builds**, and the fallbacks do not throw:
`toLocaleString`, `toLocaleTimeString` and friends exist and silently
ignore a `timeZone` option, returning host-local time. On a machine in the
requested zone the result looks right, so the bug is invisible to whoever
wrote it. The web build has full `Intl`, which is the worst split: code that
reaches for it works in one build and is quietly wrong in every other.
Treat `Intl` as absent everywhere.

Work in UTC and do the arithmetic yourself. `toISOString()` sliced is a
UTC date and time; the SDK's `utcDate`, `utcTime`, `utcDateCompact` and
`utcIso` do that slicing. A log is kept in UTC, and a filename that shifted
with the reader's zone would name the wrong day.

Anything that must be shown in a real zone belongs on the app's side, which
has a zone database. Hand the raw millisecond value to the host, through a
template value or a scene binding, and let the app format it.

`ctx.dateOrder` (`mdy`, `dmy`, `ymd`) is the order the device's region writes
a numeric date in, for a hook that parses a date someone typed. It follows
the device, not the app's language.

## Templates

Panel text, export filenames and ADIF fields are Liquid templates over one
shared vocabulary, rendered through the SDK's `renderTemplate` and
`templateContext`. The vocabulary, the filters and the traps are in
[Templates](templates.md).
