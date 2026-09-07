# halo_i18n

HaLo's user-facing strings: the [slang](https://pub.dev/packages/slang)
sources (`lib/i18n/en.i18n.json`, `lib/i18n/es.i18n.json`) and the
`Translations` generated from them, exported from `package:halo_i18n/halo_i18n.dart`
as the `t` global, the `context.t` extension, `LocaleSettings`,
`TranslationProvider` and `AppLocaleUtils`.

**Who may depend on it.** Any first-party package that shows a user a word:
the app, `halo_widgets` (the widget catalog reads `t` directly rather than
taking label bags), and the packages the app's services are being moved into.
`halo_core` stays string-free — it holds data, not screens.

**Editing a string.** Change **both** `en.i18n.json` and `es.i18n.json`, then
regenerate from this directory:

```sh
dart run slang
```

The generated `strings*.g.dart` are committed. Every `scripts/test.sh` run
that loads them regenerates first, and the full gate fails when the files on
disk were behind their sources, so a source edit without the regeneration
cannot reach `main`.
