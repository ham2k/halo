// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The coach's one rule, apart from the hook, so it is tested without the app.

/// What to tell the operator about the contacts started at [startTimes], or
/// null for nothing to say.
export function rateAdvice(startTimes: number[], now: number, windowMinutes: number, atLeast: number): string | null {
  const since = now - windowMinutes * 60_000
  const recent = startTimes.filter((t) => t > since).length
  // Nothing logged in the window at all: the operator is away, not slow.
  if (recent === 0 || recent >= atLeast) return null
  return `Only ${recent} QSO${recent === 1 ? "" : "s"} in the last ${windowMinutes} minutes. Time to change band or call CQ?`
}
