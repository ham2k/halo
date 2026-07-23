import i18next from "i18next";

/**
 * The standard per-extension translator: takes the extension's i18next
 * resources once and returns a `tFor(ctx)` that hooks call with their
 * HookContext. The underlying i18next instance is rebuilt only when
 * `ctx.locale` changes (it only does when the app's locale setting does).
 * Typical use, with per-locale JSON catalogs:
 *
 *   import en from "./i18n/en.json" with { type: "json" }
 *   import es from "./i18n/es.json" with { type: "json" }
 *   export const tFor = createCachedTranslator({ en: { translation: en }, es: { translation: es } })
 */
export function createCachedTranslator(resources: Record<string, any>) {
  let cachedLocale: string | undefined;
  let cachedT: ReturnType<typeof createTranslator> | undefined;
  return (ctx: { locale?: string }): ReturnType<typeof createTranslator> => {
    const locale = ctx.locale ?? "en";
    if (!cachedT || cachedLocale !== locale) {
      cachedLocale = locale;
      cachedT = createTranslator(resources, locale);
    }
    return cachedT;
  };
}

/**
 * Creates a lightweight translator function using an i18next instance
 * initialized with the given resources and active locale.
 */
export function createTranslator(resources: Record<string, any>, currentLocale: string) {
  const instance = i18next.createInstance();
  instance.init({
    lng: currentLocale,
    fallbackLng: "en",
    resources,
    interpolation: {
      escapeValue: false, // Not in a browser/HTML environment
    },
  });
  // i18next types `t` very broadly (objects for `returnObjects`, etc.);
  // this translator only ever resolves plain strings.
  return (key: string, options?: any): string => instance.t(key, options) as string;
}
