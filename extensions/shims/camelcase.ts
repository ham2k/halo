// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ASCII-only replacement for the npm `camelcase` package, wired in via the
// esbuild alias in build.mjs. camelcase@8 builds /[\p{Lu}]/u-style regexes at
// module top level, and the QuickJS binaries flutter_js ships are compiled
// without CONFIG_ALL_UNICODE, so those literals fail to PARSE — taking the
// entire kernel bundle down on Android/Windows/Linux (macOS/iOS use
// JavaScriptCore and never noticed). The only consumer bundled into the
// kernel is @ham2k/lib-qson-cabrillo, which camel-cases ASCII Cabrillo tags
// like "CREATED-BY", so ASCII semantics are all we need.
export default function camelCase (input: string | string[]): string {
  const joined = Array.isArray(input) ? input.join('-') : input
  const words = joined.trim().split(/[-_. ]+/).filter(Boolean)
  return words
    .map((word, i) => {
      // Match camelcase@8: all-caps words are lowercased ("FOO" → "foo"),
      // mixed-case words keep their inner humps ("fooBar" → "fooBar").
      if (word === word.toUpperCase()) word = word.toLowerCase()
      if (i === 0) return word.charAt(0).toLowerCase() + word.slice(1)
      return word.charAt(0).toUpperCase() + word.slice(1)
    })
    .join('')
}
