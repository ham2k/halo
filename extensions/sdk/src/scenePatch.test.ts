// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The kernel applies a placement's patches to the scene it last sent it, as
// the app applies them to the scene it shows: the two apart, the next render
// is compared with a scene the app does not have, and an unchanged one would
// cross as "nothing changed" while the operator sees something else. So the
// kernel's steps do exactly what the app's do, share what they did not touch
// (which is what lets the app skip reading it again), and refuse whole what
// they cannot do.

import { test } from "node:test"
import assert from "node:assert/strict"

import { applyScenePatch } from "./scenePatch.ts"

type Doc = Record<string, unknown>

const marker = (id: string, lat = 0, lon = 0) => ({ id, lat, lon })
const scene = (markers: unknown[], extra: Doc = {}): Doc => ({
  version: 1,
  width: 300,
  height: 200,
  values: { zoom: 2 },
  layers: [{ id: "bg", x: 0, y: 0, width: 300, height: 200, svg: "<svg/>" }],
  controls: [{ id: "map", kind: "map", label: "Map", markers, lines: [{ id: "l", from: "a", to: "b" }] }],
  ...extra,
})

test("a patch shares everything it did not touch, and copies what it did", () => {
  const before = scene([marker("a"), marker("b")])
  const after = applyScenePatch(before, [{ merge: ["controls", "map", "markers", "b"], value: { lat: 5 } }])
  const control = (d: Doc) => (d.controls as Doc[])[0]
  assert.equal(after.layers, before.layers)
  assert.equal((control(after).markers as unknown[])[0], (control(before).markers as unknown[])[0])
  assert.notEqual(control(after), control(before))
  assert.equal(((control(before).markers as Doc[])[1] as Doc).lat, 0, "the scene patched is left as it was")
})

test("each step does as it says", () => {
  const before = scene([marker("a"), marker("b")])
  const markers = (d: Doc) => ((d.controls as Doc[])[0].markers as Doc[]).map((m) => m.id)
  assert.deepEqual(markers(applyScenePatch(before, [{ insert: ["controls", "map", "markers"], value: marker("n"), before: "b" }])), ["a", "n", "b"])
  assert.deepEqual(markers(applyScenePatch(before, [{ set: ["controls", "map", "markers", "n"], value: marker("n") }])), ["a", "b", "n"])
  assert.deepEqual(markers(applyScenePatch(before, [{ remove: ["controls", "map", "markers", "a"] }])), ["b"])
  const merged = applyScenePatch(before, [{ merge: ["controls", "map"], value: { label: "Contacts", lines: null } }])
  assert.equal((merged.controls as Doc[])[0].label, "Contacts")
  assert.equal("lines" in (merged.controls as Doc[])[0], false, "a null field is removed")
})

// A step that cannot apply would leave the app's scene and the kernel's apart
// from then on; refused, it is the extension's error to see, and nothing changes.
test("a step that cannot apply is refused, naming it", () => {
  const before = scene([marker("a")])
  for (const [steps, said] of [
    [[{ set: ["controls", "nope", "label"], value: "x" }], /step 1: controls › nope is not there/],
    [[{ insert: ["controls", "map", "markers"], value: marker("a") }], /already has a/],
    [[{ set: ["controls", "map", "markers", "a"], value: marker("b") }], /with the id a/],
    [[{ remove: ["values", "missing"] }], /is not there/],
    [[{ merge: ["width"], value: { a: 1 } }], /not an object to merge into/],
    // An object's own keys only, as the app's maps have them.
    [[{ remove: ["values", "toString"] }], /not there/],
    [[{ set: ["strings", "__proto__"], value: "x" }], /names no __proto__/],
    [
      [
        { set: ["values", "zoom"], value: 3 },
        { set: [], value: {} },
      ],
      /step 2: a step names a place/,
    ],
  ] as const) {
    assert.throws(() => applyScenePatch(before, steps), said)
  }
})
