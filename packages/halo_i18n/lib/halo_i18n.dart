// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The app's strings. `t` is the global Translations for the current locale
// (usable from a service with no BuildContext), `context.t` the widget-side
// one, `LocaleSettings` switches locales and `TranslationProvider` /
// `AppLocaleUtils` are what the app shell mounts, and `applyLocaleSetting`
// turns the Language setting into all of them. The source is
// lib/i18n/en.i18n.json — every other language comes from Crowdin (see the
// README); the gate fails when the generated files are behind the sources.

export 'i18n/strings.g.dart';
export 'locales.dart';
