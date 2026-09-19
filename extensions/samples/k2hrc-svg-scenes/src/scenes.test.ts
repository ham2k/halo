// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
import { test } from 'node:test'
import assert from 'node:assert/strict'
import type { HookContext, PanelRenderArgs } from '@ham2k/extension-sdk'
import { createScenePanels } from './scenes.ts'

const ctx = {} as HookContext
const args = (instanceId = 'one'): PanelRenderArgs => ({ panelKey: 'radio', instanceId, operation: {}, qsoCount: 0, config: {}, reason: 'test' })
test('simulated CAT distinguishes requested/reported values and isolates placements', async () => {
  let time = 1000
  const panel = createScenePanels(() => time)
  const event = { controlId: 'tune', action: 'tune', phase: 'commit' as const, sequence: 1, value: 14200 }
  const result = await panel.onEvent!({ ...args(), event }, ctx)
  assert.equal(result.values.requested, 14200)
  assert.equal(result.values.reported, 14074)
  time += 2001
  const content = await panel.render(args(), ctx)
  assert.equal(content.kind, 'svgScene')
  if (content.kind !== 'svgScene') throw Error('scene expected')
  assert.equal(content.scene.values.reported, 14200)
  const other = await panel.render(args('two'), ctx)
  if (other.kind !== 'svgScene') throw Error('scene expected')
  assert.equal(other.scene.values.reported, 14074)
  const disconnected = await panel.onEvent!({ ...args(), event: { ...event, action: 'connect' } }, ctx)
  assert.equal(disconnected.values.connected, 0)
  await assert.rejects(panel.onEvent!({ ...args(), event }, ctx), /disconnected/)
})
