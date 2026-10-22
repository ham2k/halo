// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Call-field commands that set the contact's time, the way typing into the
// Time control does (docs/design/logging-fields.md § Manual time entry):
//   +1m, +30s, -1h, +3d   — move it; a bare +1 is minutes
//   12:33, 12:33:30       — set the time (UTC)
//   :34                   — set the minutes only
//   ::30                  — set the seconds only
//   3/18                  — set the date, in the device's own day/month order
//   NOW                   — back to live time
// The hook only parses: it hands a `setTime` action to the app, which applies
// it to the time the contact has now — reading "now" is the app's.

import { defineExtension } from "@ham2k/extension-sdk"
import type { CommandCatalogEntry, CommandInterpretation, HookContext } from "@ham2k/extension-sdk"
import { clampDay, parseTimeCommand } from "./timeCommandParsing.ts"
import { tFor } from "./i18n.ts"

import manifest from "../manifest.json" with { type: "json" }

const pad = (n: number) => String(n).padStart(2, "0")

const TimeCommand = {
  async interpret({ input, qso }: { input: string; qso?: Record<string, unknown> }, ctx: HookContext): Promise<CommandInterpretation | null> {
    const order = ctx.dateOrder ?? "mdy"
    const parsed = parseTimeCommand(input, order)
    if (!parsed) return null
    const t = tFor(ctx)
    switch (parsed.kind) {
      case "error":
        return { error: t(parsed.error, { format: t(order === "dmy" ? "dayMonth" : "monthDay") }) }
      case "now":
        return { describe: t("now"), confirm: t("nowConfirm"), commands: [{ setTime: { now: true } }] }
      case "delta":
        return {
          describe: t("delta", { delta: parsed.label }),
          confirm: t("deltaConfirm", { delta: parsed.label }),
          commands: [{ setTime: { deltaMillis: parsed.deltaMillis } }],
        }
      case "time": {
        const { hour, minute, second } = parsed
        const time = `${pad(hour)}:${pad(minute)}${second === undefined ? "" : `:${pad(second)}`}`
        return {
          describe: t("time", { time }),
          confirm: t("timeConfirm", { time }),
          commands: [{ setTime: second === undefined ? { hour, minute } : { hour, minute, second } }],
        }
      }
      case "minute": {
        const minute = pad(parsed.minute)
        return {
          describe: t("minute", { minute }),
          confirm: t("minuteConfirm", { minute }),
          commands: [{ setTime: { minute: parsed.minute } }],
        }
      }
      case "second": {
        const second = pad(parsed.second)
        return {
          describe: t("second", { second }),
          confirm: t("secondConfirm", { second }),
          commands: [{ setTime: { second: parsed.second } }],
        }
      }
      case "date": {
        // The year the date lands in is the contact's — its manual time, or
        // now (the sandbox's Date is the app clock) — so the preview names
        // the Feb 28 the app will set for a Feb 29 in a common year.
        const at = typeof qso?.startAtMillis === "number" ? qso.startAtMillis : Date.now()
        const day = clampDay(parsed.month, parsed.day, new Date(at).getUTCFullYear())
        // Spelled out, so the preview settles which of the two numbers was
        // read as the month.
        const date = t("dateLabel", { month: t("months").split(",")[parsed.month - 1], day })
        return {
          describe: t("date", { date }),
          confirm: t("dateConfirm", { date }),
          commands: [{ setTime: { month: parsed.month, day } }],
        }
      }
    }
  },

  async catalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
    const t = tFor(ctx)
    const category = t("catalogCategory")
    return [
      {
        command: "+1M",
        keywords: ["TIME", "CLOCK", "ADJUST", "FORWARD", "BACK"],
        params: "(+1, +30S, -1H, +3D…)",
        describe: t("catalogDelta"),
        category,
        needsOperation: true,
      },
      { command: "12:33", keywords: ["TIME", "UTC", "CLOCK"], params: "(12:33:30)", describe: t("catalogTime"), category, needsOperation: true },
      { command: ":34", keywords: ["MINUTES", "TIME"], describe: t("catalogMinute"), category, needsOperation: true },
      { command: "::30", keywords: ["SECONDS", "TIME"], describe: t("catalogSecond"), category, needsOperation: true },
      { command: ctx.dateOrder === "dmy" ? "18/3" : "3/18", keywords: ["DATE", "DAY"], describe: t("catalogDate"), category, needsOperation: true },
      { command: "NOW", keywords: ["TIME", "LIVE", "CLOCK", "RESET"], describe: t("catalogNow"), category, needsOperation: true },
    ]
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("command", { key: "time-commands", hook: TimeCommand, priority: 100 })
  },
})
