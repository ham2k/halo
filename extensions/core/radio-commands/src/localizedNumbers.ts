// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Moving between the operator's own number conventions and the canonical
// period-decimal form the shared formatting package speaks.
//
// Its own module rather than helpers inside index.ts so the tests can reach
// them without importing @ham2k/lib-format-tools, which the node test runner
// does not resolve.

import type { HookContext } from "@ham2k/halo-extension-sdk"

/**
 * Just the two fields these need. Narrower than HookContext on purpose: a
 * caller passing a whole context still satisfies it, and a test does not have
 * to invent an `online` flag to exercise a separator.
 */
type NumberConventions = Pick<HookContext, "decimalSeparator" | "groupingSeparator">

/**
 * Rewrites what the operator typed into the canonical period-decimal,
 * no-grouping form `parseFreq` expects.
 *
 * lib-format-tools is a shared package with its own fixed conventions — it
 * maps a comma to a decimal point unconditionally — so under comma
 * conventions `14.285` would reach it as `14.285` MHz when the operator meant
 * 14285 kHz. Normalizing here, against `ctx`'s resolved separators, is what
 * keeps this command agreeing with the frequency field beside it.
 */
export function canonicalNumber(text: string, ctx: NumberConventions): string {
  const grouping = ctx.groupingSeparator
  const decimal = ctx.decimalSeparator ?? '.'
  let out = text
  // Grouping first: under comma conventions a period is grouping, and
  // converting the decimal first would leave two periods behind.
  if (grouping) out = out.split(grouping).join('')
  if (decimal !== '.') out = out.split(decimal).join('.')
  return out
}

/**
 * Rewrites lib-format-tools' fixed `14,285.5` into the operator's own
 * conventions, for text shown back to them.
 *
 * One pass with a callback rather than two replaces: swapping `.` for `,` and
 * then `,` for `.` would undo itself on every character.
 */
export function localizeFormattedNumber(text: string, ctx: NumberConventions): string {
  const decimal = ctx.decimalSeparator ?? '.'
  const grouping = ctx.groupingSeparator ?? ','
  if (decimal === '.' && grouping === ',') return text
  return text.replace(/[.,]/g, (mark) => (mark === '.' ? decimal : grouping))
}
