// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
import { test } from "node:test"
import assert from "node:assert/strict"
import type { JSONValue, PanelSceneControl, StationEquipment } from "@ham2k/extension-sdk"
import { createRotatorPanel, sceneFor, settingsFrom, viewAfter, type RotatorHost } from "./rotator.ts"

function host(ids: string[] = ["a", "b", "c"]) {
  const store = new Map<string, JSONValue>()
  const calls: string[] = []
  const fake: RotatorHost = {
    listEquipment: async () => [
      { id: "switch", kind: "antennaSwitch", name: "Switch", connected: true },
      ...ids.map((id): StationEquipment => ({ id, kind: "rotator", name: id, connected: true })),
    ],
    setEquipmentConnection: async ({ id, connected }) => calls.push(`${connected ? "connect" : "disconnect"} ${id}`),
    stopRotator: async ({ id }) => calls.push(`stop ${id}`),
    kvGet: async (key) => store.get(key) ?? null,
    kvSet: async (key, value) => void store.set(key, value),
  }
  return { fake, store, calls }
}

const mapOf = (settings: ReturnType<typeof settingsFrom>) => {
  const content = sceneFor(settings, { width: 400, height: 300 })
  assert.equal(content.kind, "scene")
  return (content as { scene: { controls: PanelSceneControl[] } }).scene.controls.find((c) => c.kind === "rotatorMap")!
}

test("an untouched pane shows the station's first rotator as a 30° beam, centred on the operation", () => {
  const settings = settingsFrom({}, [{ id: "a" }, { id: "b" }])
  assert.equal(settings.rotator, "a")
  assert.equal(settings.beamWidth, 30)
  assert.equal(settings.home, undefined)
  assert.equal(settings.directions, undefined)
})

// A 4-square's lobe is three times a Yagi's: a width carried over from the
// beam would draw a sliver where the array covers a quadrant.
test("a switched array points only at its own bearings, with its own width until one is typed", () => {
  const square = settingsFrom({ antenna: "4sq-diagonal" })
  assert.deepEqual(square.directions, [45, 135, 225, 315])
  assert.equal(square.beamWidth, 90)
  assert.deepEqual(mapOf(square).stops, [45, 135, 225, 315])
  assert.equal(settingsFrom({ antenna: "4sq-diagonal", "beamWidth.4sq-diagonal": "70" }).beamWidth, 70)
  // The beam's own width is its own key: typing one for the beam leaves the array's default.
  assert.equal(settingsFrom({ antenna: "4sq-diagonal", "beamWidth.beam": 20 }).beamWidth, 90)
})

// A directional switch knows the lobe of the antenna it has selected; the
// type's default would draw a beam that is not the one in the air.
test("an antenna that reports its own beam is drawn with it, unless the pane types one", () => {
  const station = [{ id: "a", beamWidth: 120 }, { id: "b" }]
  assert.equal(settingsFrom({}, station).beamWidth, 120)
  assert.equal(settingsFrom({ "beamWidth.beam": 40 }, station).beamWidth, 40)
  assert.deepEqual(
    settingsFrom({ rotator: "multiple" }, [{ id: "b" }, { id: "a", beamWidth: 120 }]).more.map((r) => r.beamWidth),
    [120],
  )
})

test("the station being logged is marked on the map, and clicked to aim at it, unless the pane turns it off", () => {
  const call = (config: Record<string, JSONValue>) => mapOf(settingsFrom(config)).decorations?.find((d) => d.id === "call")
  assert.deepEqual(call({})?.at, { place: "call" })
  assert.equal(call({})?.aim, true)
  assert.equal(call({ callMarker: false }), undefined)
})

// The map draws decorations in list order: a beam listed after an arrow would wash it out, and
// the dot listed before the arrows would hide under them.
test("every beam lies under every arrow, and the station being logged over them all", () => {
  const settings = settingsFrom({ rotator: "multiple" }, [{ id: "a" }, { id: "b" }])
  const ids = mapOf(settings).decorations!.map((d) => d.id)
  const lastBeam = Math.max(ids.indexOf("beam-1"), ids.indexOf("beam-2"))
  assert.ok(lastBeam < ids.indexOf("heading-1") && lastBeam < ids.indexOf("target-1"))
  assert.equal(ids[ids.length - 1], "call")
})

// Every bearing on a map centred in the wrong place is wrong, so a location
// the panel cannot read is said, never swapped for the operation's.
test("a location the pane names and cannot read says so instead of drawing the map", () => {
  assert.deepEqual(settingsFrom({ location: "40.7, -74.0" }).home, { lat: 40.7, lon: -74 })
  assert.equal(settingsFrom({ location: "nowhere" }).home, null)
  const content = sceneFor(settingsFrom({ location: "nowhere" }), { width: 400, height: 300 }) as { scene: { controls?: unknown[] } }
  assert.equal(content.scene.controls, undefined)
})

test("several rotators: those switched on, the first the map's own, each lettered and coloured apart until set", () => {
  const settings = settingsFrom({ rotator: "multiple", "use:a": false, "label:c": "Tower" }, [{ id: "a" }, { id: "b" }, { id: "c" }])
  assert.equal(settings.rotator, "b")
  assert.equal(settings.label, "B")
  assert.deepEqual(
    settings.more.map((r) => r.label),
    ["Tow"],
  )
  assert.notEqual(settings.more[0].color, settings.color)
  assert.deepEqual(
    mapOf(settings).rotators?.map((r) => r.rotator),
    ["c"],
  )
})

test("a zoom or pan the map reports is kept, and the whole-map reset forgets it", () => {
  assert.deepEqual(viewAfter({}, "zoom", 3, undefined), { zoom: 3 })
  assert.deepEqual(viewAfter({ zoom: 3 }, "pan", 0, { x: 12, y: -4 }), { zoom: 3, x: 12, y: -4 })
  assert.deepEqual(viewAfter({ zoom: 3, x: 12, y: -4 }, "zoom", 0, undefined), {})
  // A turn the map sends as the scene's event carries no gesture, and moves nothing.
  const view = { zoom: 2 }
  assert.equal(viewAfter(view, undefined, 120, undefined), view)
})

test("each placed pane keeps its own view across renders, and stop reaches every rotator the map shows", async () => {
  const { fake, store, calls } = host()
  const panel = createRotatorPanel(fake)
  const config = { rotator: "multiple" }
  const event = (instanceId: string, action: string, extra: Record<string, unknown> = {}) =>
    panel.onEvent!({ config, instanceId, event: { controlId: "map", action, phase: "commit", sequence: 1, ...extra } } as never, {} as never)

  assert.deepEqual(await event("one", "view", { gesture: "zoom", value: 4 }), { values: { zoom: 4, panX: 0, panY: 0 } })
  assert.deepEqual(store.get("view:one"), { zoom: 4 })
  assert.equal(store.get("view:two"), undefined)

  const rendered = (await panel.render!({ config, instanceId: "one", environment: { width: 400, height: 300 } } as never, {} as never)) as {
    scene: { values: Record<string, number> }
  }
  assert.equal(rendered.scene.values.zoom, 4)

  await event("one", "stop")
  assert.deepEqual(calls, ["stop a", "stop b", "stop c"])
  calls.length = 0
  await event("one", "connect")
  assert.deepEqual(calls, ["connect a", "connect b", "connect c"])
})
