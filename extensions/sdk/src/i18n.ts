import i18next from "i18next";

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
  return (key: string, options?: any) => instance.t(key, options);
}
