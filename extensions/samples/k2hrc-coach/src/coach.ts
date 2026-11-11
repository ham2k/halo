// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The assistant itself: what it offers in Settings, and what it does when the
// app calls it about an open operation.

import { host } from "@ham2k/extension-sdk"
import type { HookContext, ObserveArgs, AssistantDescriptor, AssistantHook } from "@ham2k/extension-sdk"

import { rateAdvice } from "./rate.ts"
import { setUpOperation } from "./setup.ts"

export const RateCoach: AssistantHook = {
  async getAssistants(_args: Record<string, never>, _ctx: HookContext): Promise<AssistantDescriptor[]> {
    return [
      {
        key: "rate",
        title: "Rate Coach",
        description: "Says when the rate drops below what you set",
        icon: "speedometer-slow",
        // A contact logged changes the rate; a minute passing changes it too,
        // with nothing logged.
        on: ["qsoLogged", "tick:60"],
        form: [
          { type: "field", fieldType: "number", key: "windowMinutes", label: "Window, in minutes", value: 10 },
          { type: "field", fieldType: "number", key: "atLeast", label: "QSOs expected in that window", value: 5 },
          { type: "field", fieldType: "checkbox", key: "keepAwake", label: "Keep the screen awake while operating", value: false },
          { type: "field", fieldType: "checkbox", key: "ownLayout", label: "Switch to the coach's layout: the log beside a UTC clock", value: false },
        ],
      },
    ]
  },

  async observe({ operation, config, clock }: ObserveArgs, ctx: HookContext): Promise<void> {
    await setUpOperation(String(operation.uuid), config)
    const qsos = (await ctx.getQsos?.(String(operation.uuid))) ?? []
    const advice = rateAdvice(
      qsos.map((q) => Number(q.startAtMillis)),
      clock.nowMillis,
      Number(config.windowMinutes ?? 10),
      Number(config.atLeast ?? 5),
    )
    // The key is the same for every operation: with two open, the line
    // carries the one the last call was about.
    if (advice === null) return await host.fyi.clear("rate")
    await host.fyi.post({ key: "rate", category: "info", icon: "speedometer-slow", text: advice })
  },
}
