// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT

import { test } from "node:test"
import assert from "node:assert/strict"

import { isValidHookKey, settingsPanelEntriesFor, tier1FormDefinition } from "./settingsPanels.ts"

test("isValidHookKey: exact extension key is always valid", () => {
  assert.equal(isValidHookKey("settingsPanel", "pota", "pota"), true)
  assert.equal(isValidHookKey("account", "qrz", "qrz"), true)
})

test("isValidHookKey: <extensionKey>_-prefixed override is valid", () => {
  assert.equal(isValidHookKey("settingsPanel", "pota", "pota_spots"), true)
})

test("isValidHookKey: bare or camelCase override is rejected", () => {
  assert.equal(isValidHookKey("settingsPanel", "pota", "spots"), false)
  assert.equal(isValidHookKey("settingsPanel", "pota", "potaSpots"), false)
})

test("isValidHookKey: a key that merely starts with the extension key without the underscore is rejected", () => {
  // 'potassium' starts with 'pota' but isn't '<pota>_'-prefixed — must not
  // pass on a naive startsWith(extensionKey) check.
  assert.equal(isValidHookKey("settingsPanel", "pota", "potassium"), false)
})

test("isValidHookKey: categories outside the rule are always valid, any key", () => {
  assert.equal(isValidHookKey("form", "pota", "spots"), true)
  assert.equal(isValidHookKey("lookup", "pota", "anything"), true)
})

test("tier1FormDefinition: builds a FormDefinition from the static hook object, no closures to strip", () => {
  const hook = {
    kind: "simple",
    title: "POTA",
    fields: [{ type: "field", fieldType: "text", key: "apiKey", label: "API Key" }],
  }
  assert.deepEqual(tier1FormDefinition(hook), {
    title: "POTA",
    elements: hook.fields,
  })
})

test("tier1FormDefinition: missing fields defaults to an empty array", () => {
  assert.deepEqual(tier1FormDefinition({ title: "Empty" }), { title: "Empty", elements: [] })
})

test("settingsPanelEntriesFor: Tier 1 (kind: 'simple') is always exactly one panel, hookKey === panelKey", () => {
  const record = {
    key: "pota",
    extensionKey: "pota",
    hook: { kind: "simple", title: "POTA", icon: "pine-tree", order: 3 },
  }
  assert.deepEqual(settingsPanelEntriesFor(record), [
    {
      panelKey: "pota",
      hookKey: "pota",
      extensionKey: "pota",
      title: "POTA",
      icon: "pine-tree",
      order: 3,
      kind: "simple",
      sidebar: true,
      dataFilesSection: false,
    },
  ])
})

test("settingsPanelEntriesFor: Tier 1's sidebar: false is passed through", () => {
  const record = { key: "pota", extensionKey: "pota", hook: { kind: "simple", title: "POTA", sidebar: false } }
  assert.equal(settingsPanelEntriesFor(record)[0].sidebar, false)
})

test("settingsPanelEntriesFor: Tier 1's dataFilesSection: true is passed through, defaulting false when omitted", () => {
  const record = {
    key: "call-notes",
    extensionKey: "call-notes",
    hook: { kind: "simple", title: "Callsign Notes", sidebar: false, dataFilesSection: true },
  }
  assert.equal(settingsPanelEntriesFor(record)[0].dataFilesSection, true)
  const withoutIt = { key: "pota", extensionKey: "pota", hook: { kind: "simple", title: "POTA" } }
  assert.equal(settingsPanelEntriesFor(withoutIt)[0].dataFilesSection, false)
})

test("settingsPanelEntriesFor: Tier 2 without getPanels is one implicit panel with a null title", () => {
  const record = { key: "lofi", extensionKey: "lofi", hook: { kind: "dynamic" } }
  assert.deepEqual(settingsPanelEntriesFor(record, undefined), [
    {
      panelKey: "lofi",
      hookKey: "lofi",
      extensionKey: "lofi",
      title: null,
      icon: null,
      order: null,
      kind: "dynamic",
      sidebar: true,
      dataFilesSection: false,
    },
  ])
})

test("settingsPanelEntriesFor: Tier 2 with getPanels fans out to multiple panels, all sharing one hookKey", () => {
  const record = { key: "pota", extensionKey: "pota", hook: { kind: "dynamic" } }
  const descriptors = [
    { key: "pota", title: "POTA" },
    { key: "pota_spots", title: "POTA Spots", icon: "map", order: 1 },
  ]
  const entries = settingsPanelEntriesFor(record, descriptors)
  assert.equal(entries.length, 2)
  // hookKey routes invokeHook calls back to the ONE registered object —
  // must be the registration's own key on every entry, even though
  // panelKey differs per entry.
  assert.equal(entries[0].hookKey, "pota")
  assert.equal(entries[1].hookKey, "pota")
  assert.equal(entries[0].panelKey, "pota")
  assert.equal(entries[1].panelKey, "pota_spots")
  assert.equal(entries[1].icon, "map")
  assert.equal(entries[1].order, 1)
})

test("settingsPanelEntriesFor: a getPanels() descriptor's sidebar: false is passed through, defaulting true when omitted", () => {
  const record = { key: "call-notes", extensionKey: "call-notes", hook: { kind: "dynamic" } }
  const descriptors = [
    { key: "call-notes", title: "Callsign Notes", sidebar: false },
    { key: "call-notes_other", title: "Other" },
  ]
  const entries = settingsPanelEntriesFor(record, descriptors)
  assert.equal(entries[0].sidebar, false)
  assert.equal(entries[1].sidebar, true)
})

test("settingsPanelEntriesFor: a getPanels() descriptor's dataFilesSection: true is passed through, defaulting false — independent of sidebar", () => {
  const record = { key: "call-notes", extensionKey: "call-notes", hook: { kind: "dynamic" } }
  const descriptors = [
    { key: "call-notes", title: "Callsign Notes", sidebar: false, dataFilesSection: true },
    { key: "call-notes_other", title: "Other", sidebar: false },
  ]
  const entries = settingsPanelEntriesFor(record, descriptors)
  assert.equal(entries[0].dataFilesSection, true)
  assert.equal(entries[1].dataFilesSection, false,
    "opting out of the sidebar alone must not also opt into the Data Files section")
})

test("settingsPanelEntriesFor: an empty getPanels() result yields no panels at all", () => {
  const record = { key: "pota", extensionKey: "pota", hook: { kind: "dynamic" } }
  assert.deepEqual(settingsPanelEntriesFor(record, []), [])
})

test("settingsPanelEntriesFor: a getPanels() descriptor with a bare (non-namespaced) key is dropped", () => {
  const record = { key: "pota", extensionKey: "pota", hook: { kind: "dynamic" } }
  const descriptors = [
    { key: "pota", title: "POTA" },
    { key: "spots", title: "Bare key, should be dropped" },
  ]
  const entries = settingsPanelEntriesFor(record, descriptors)
  assert.equal(entries.length, 1)
  assert.equal(entries[0].panelKey, "pota")
})

test("settingsPanelEntriesFor: a getPanels() descriptor claiming another extension's key is dropped", () => {
  const record = { key: "pota", extensionKey: "pota", hook: { kind: "dynamic" } }
  const descriptors = [{ key: "sota", title: "Someone else's extension key" }]
  assert.deepEqual(settingsPanelEntriesFor(record, descriptors), [])
})
