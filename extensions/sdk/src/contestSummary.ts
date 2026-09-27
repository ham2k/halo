// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The one shape every contest scorer's summary takes (docs/design/contests.md
// §5.2): a title naming the contest and its score, a line of the arithmetic
// that produced it, then whatever detail the contest keeps — band tables,
// multiplier lists. Built here rather than by each scorer so twelve contests
// cannot drift into twelve layouts.
//
// A contest summarizes the OPERATION only. Its multipliers accumulate across
// the whole entry, so a day's share of the score is not a number the contest
// defines — `contestSummary` answers the day scope with nothing.

import { createCachedTranslator } from "./i18n.ts"
import type { HookContext, JSONValue, ScoreTally } from "./types.ts"
import { fmtInteger, fmtNumber } from "@ham2k/lib-format-tools"

import en from "./i18n/contestSummary.en.json" with { type: "json" }
import es from "./i18n/contestSummary.es.json" with { type: "json" }

const tFor = createCachedTranslator({ en: { translation: en }, es: { translation: es } })

export interface ContestArithmetic {
  qsos: number
  /// QSO points before any multiplier. Omitted by a contest that scores
  /// something else (distance) or nothing but the contacts themselves.
  points?: number
  mults?: number
  /// Names the multiplier when it is not a count of multipliers worked — Field
  /// Day's power factor. Pre-translated by the contest.
  multsNoun?: string
  /// One entry per KIND of multiplier worked, pre-formatted and translated by
  /// the contest ("12 counties", "3 states"), for a contest whose multipliers
  /// come from different kinds of things. Zero-count kinds are left out by
  /// the caller.
  multParts?: string[]
  bonus?: number
  /// The bonus joins the points BEFORE they are multiplied — a QSO party whose
  /// rules fold it in rather than adding it to the product.
  bonusFirst?: boolean
  /// A further factor over the whole product, named by the contest — a QSO
  /// party's power class.
  factor?: { count: number; noun: string }
  /// Further clauses in the contest's own words, appended after the rest
  /// ("5,678 km").
  more?: string[]
}

/// "45 QSOs, 90 pts × 15 mults (12 counties, 3 states) + 100 bonus".
export function contestArithmetic(args: ContestArithmetic, ctx: HookContext): string {
  const t = tFor(ctx)
  const clauses = [args.qsos === 1 ? t("qsoOne") : t("qsoMany", { formatted: fmtInteger(args.qsos) })]
  if (args.points !== undefined) {
    const bonus = args.bonus ? t("bonus", { formatted: fmtInteger(args.bonus) }) : ""
    let expression = args.points === 1 ? t("pointOne") : t("points", { formatted: fmtInteger(args.points) })
    if (bonus && args.bonusFirst) expression = `(${expression} ${bonus})`
    if (args.mults !== undefined) {
      const mults = args.multsNoun
        ? `${fmtInteger(args.mults)} ${args.multsNoun}`
        : args.mults === 1
          ? t("multOne")
          : t("multMany", { formatted: fmtInteger(args.mults) })
      expression += ` × ${mults}`
      if (args.multParts && args.multParts.length > 0) expression += ` (${args.multParts.join(", ")})`
    }
    // Not always whole: two QSO parties weight low power at 1.5.
    if (args.factor) {
      const count = Number.isInteger(args.factor.count) ? fmtInteger(args.factor.count) : fmtNumber(args.factor.count, "oneDecimal")
      expression += ` × ${count} ${args.factor.noun}`
    }
    if (bonus && !args.bonusFirst) expression += ` ${bonus}`
    clauses.push(expression)
  }
  clauses.push(...(args.more ?? []))
  return clauses.join(", ")
}

export interface ContestSummaryArgs {
  key: string
  scope: "day" | "operation"
  icon: string
  /// The contest as the operation's title names it — "CQWPX SSB", "NYQP".
  title: string
  total: number
  arithmetic: string
  /// The contest's own detail, shown under the arithmetic after a blank line.
  detail?: string
  grid?: boolean
  /// Machine-readable fields the contest also reports (`qsos`, `mults`, …).
  extra?: Record<string, JSONValue>
}

/// A contest's summary, keyed by its tally key — empty for the day scope.
export function contestSummary(args: ContestSummaryArgs, ctx: HookContext): Record<string, ScoreTally> {
  if (args.scope === "day") return {}
  const t = tFor(ctx)
  return {
    [args.key]: {
      ...args.extra,
      key: args.key,
      for: "operation",
      icon: args.icon,
      total: args.total,
      label: args.total === 1 ? t("titleOnePoint", { title: args.title }) : t("titleManyPoints", { title: args.title, formatted: fmtInteger(args.total) }),
      summary: fmtInteger(args.total),
      longSummary: [args.arithmetic, args.detail].filter((part) => part).join("\n\n"),
      ...(args.grid ? { grid: true } : {}),
    },
  }
}
