// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ASCII-only replacement for the npm `camelcase` package, wired in via the
// esbuild alias in build.mjs. The only consumer bundled into the kernel is
// @ham2k/lib-qson-cabrillo, which camel-cases Cabrillo tags like "CREATED-BY"
// — ASCII by specification — so ASCII semantics are the whole requirement and
// this stays in place of the dependency.
//
// The engine parses \p{...} literals perfectly well, so "the real package
// would work now" is true and is not a reason to switch back — it buys
// unicode this caller has no input for, at the cost of a dependency in every
// kernel build. It is a reimplementation, so it can drift: camelcase.test.ts
// pins the behaviour Cabrillo relies on. Any change here belongs there first.
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
