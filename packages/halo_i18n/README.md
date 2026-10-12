# halo_i18n

HaLo's user-facing strings: the [slang](https://pub.dev/packages/slang)
sources under `lib/i18n/` and the `Translations` generated from them,
exported from `package:halo_i18n/halo_i18n.dart` as the `t` global, the
`context.t` extension, `LocaleSettings`, `TranslationProvider` and
`AppLocaleUtils`, plus what turns the Language setting into a locale
(`lib/locales.dart`).

**Who may depend on it.** Any first-party package that shows a user a word:
the app, `halo_widgets` (the widget catalog reads `t` directly rather than
taking label bags), and the packages the app's services are being moved into.
`halo_core` stays string-free — it holds data, not screens.

## Where each language comes from

| Files | Owner |
| --- | --- |
| `lib/i18n/en.i18n.json` | Developers. The only file edited by hand. |
| `lib/i18n/crowdin/<code>.i18n.json` | [Crowdin](https://crowdin.com). Every other language, Spanish included; never edited here. |
| `lib/i18n/hidden/{cw,qrp,qro}.i18n.json` | `tool/generate_hidden_locales.dart`, from English. |

A string missing from a language reads in English, so a new English string
ships at once and its translations follow on the next Crowdin pull.

The hidden locales are the joke languages PoLo has: QRO (all caps), QRP (all
lowercase) and CW (Morse code). The Language setting never lists them; typing
`LANG CW` (or `LANG QRO`, `LANG QRP`) switches to one, and `LANG SYSTEM` goes
back.

## Editing a string

Change `en.i18n.json`, then regenerate from the repository root:

```sh
mise run strings
```

That writes the hidden locales and runs `dart run slang`. The generated
`strings*.g.dart` and `hidden/*.json` are committed. Every `scripts/test.sh`
run that loads them regenerates first, and the full gate fails when the files
on disk were behind their sources, so a source edit without the regeneration
cannot reach `main`.

## Crowdin

`crowdin.yml` at the repository root maps `en.i18n.json` to
`crowdin/<code>.i18n.json`. With the [Crowdin CLI](https://crowdin.github.io/crowdin-cli/)
installed and `CROWDIN_PROJECT_ID` and `CROWDIN_PERSONAL_TOKEN` set:

```sh
mise run crowdin-push   # upload the English source
mise run crowdin-pull   # download the bundled languages and regenerate
```

`crowdin-pull` names the languages the app bundles. Adding one means adding
it there and giving it a name in `localeNames` (`lib/locales.dart`); the
tests fail on a language without one.

Plurals are the English source's: `one` and `other`. Crowdin's plain-JSON
format offers translators only those, so a language with more forms (Czech
`few`) reads `other` for them.
