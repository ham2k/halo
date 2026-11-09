// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
import { test } from "node:test"
import assert from "node:assert/strict"
import { rateAdvice } from "./rate.ts"

const now = 10 * 3_600_000
const minutesAgo = (m: number) => now - m * 60_000

test("a slow window is worth a word, a busy one and an empty one are not", () => {
  assert.match(rateAdvice([minutesAgo(2), minutesAgo(5)], now, 10, 5) ?? "", /Only 2 QSOs in the last 10 minutes/)
  assert.equal(rateAdvice([1, 2, 3, 4, 5].map(minutesAgo), now, 10, 5), null)
  // An operator who has logged nothing is away, and a coach nagging them is noise.
  assert.equal(rateAdvice([], now, 10, 5), null)
  // Contacts from before the window do not hold the rate up.
  assert.match(rateAdvice([minutesAgo(1), minutesAgo(30), minutesAgo(40), minutesAgo(50)], now, 10, 2) ?? "", /Only 1 QSO in/)
})
