// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
import { test } from "node:test"
import assert from "node:assert/strict"
import { entityPrefixForCall } from "@ham2k/extension-sdk"
import { annotationsFor, bandPlan, licenseRunsFor } from "./plan.ts"

const us = { ituRegion: 2, countryCode: "us" }
const of = (type: string, importance?: string) => (a: { type: string; importance?: string }) => a.type === type && a.importance === importance

test("a band's plan comes as its edges, its modes' stretches, its windows and its markers, most telling first", () => {
  const said = annotationsFor("20m", "N0CALL")
  assert.deepEqual(
    said.filter((a) => a.type === "edge").map((a) => [a.fromHz, a.toHz]),
    [[14000000, 14350000]],
  )
  // The library breaks 20 m's data stretch at each window; read as changes of kind, Data would be
  // three stretches between 14070 and 14095.
  assert.deepEqual(
    said.filter(of("plan")).map((a) => [a.label, a.fromHz, a.toHz]),
    [
      ["CW", 14000000, 14070000],
      ["Data", 14070000, 14095000],
      ["CW", 14095000, 14150000],
      ["Phone", 14150000, 14350000],
    ],
  )
  assert.deepEqual(
    said.filter(of("known", "secondary")).map((a) => [a.label, a.fromHz, a.toHz]),
    [
      ["FT8", 14074000, 14077000],
      ["FT4", 14080000, 14083000],
    ],
  )
  // A marker covers its mode's passband: CW's 250 Hz about it.
  const qrp = said.find((a) => a.label === "🕯️ CW QRP")!
  assert.deepEqual([qrp.type, qrp.importance, qrp.fromHz, qrp.toHz], ["known", "tertiary", 14059875, 14060125])
  // Each has a key of its own, so a reader can tell one from another across reads.
  assert.equal(new Set(said.map((a) => a.key)).size, said.length)
})

test("2 m's FT8 window starts where the library has it, past the half-kHz gap below it", () => {
  // Sampled a kHz apart, the gap between FT4 and FT8 falls between two samples, and FT8's window
  // would be drawn from FT4's end, a third wider than it is.
  const windows = bandPlan("2m", us).filter((s) => s.mode === "FT4" || s.mode === "FT8")
  assert.deepEqual(
    windows.map((s) => [s.mode, s.from, s.to]),
    [
      ["FT4", 144170, 144173],
      ["FT8", 144174, 144177],
    ],
  )
})

test("the plan is the station's own: its band's edges, and only the markers for its region and country", () => {
  const said = annotationsFor("40m", "DL1ABC")
  // Region 1's 40 m ends at 7200; drawn with the US's edges, a German station would see 7200–7300 as its own.
  assert.deepEqual(
    said.filter((a) => a.type === "edge").map((a) => [a.fromHz, a.toHz]),
    [[7000000, 7200000]],
  )
  assert.ok(!said.some((a) => a.label?.includes("Here be dragons")), "Region 2's markers are not a German station's")
  assert.ok(
    said.some((a) => a.label === "🚨 Emergency"),
    "Region 1's emergency frequency is",
  )
})

test("each license level's privileges are where the library has them, the station's regulator's only", () => {
  const station = { entity: entityPrefixForCall("N0CALL"), region: 2 }
  // The General's CW and data from 14025 to 14150, its phone from 14225; the Extra has the whole
  // band, and the Technician none of it.
  assert.deepEqual(
    licenseRunsFor("20m", station).filter((r) => r.level === "General"),
    [
      { level: "General", from: 14025, to: 14150 },
      { level: "General", from: 14225, to: 14350 },
    ],
  )
  assert.ok(!licenseRunsFor("20m", station).some((r) => r.level === "Technician"))
  // The legacy Advanced is not among them.
  assert.ok(!licenseRunsFor("80m", station).some((r) => r.level.includes("Advanced")))
  const general = annotationsFor("20m", "N0CALL").filter(of("plan", "secondary"))
  assert.ok(general.some((a) => a.label === "General" && a.fromHz === 14025000 && a.toHz === 14150000))
  // A regulator the library has no levels for, or a station not known, has none.
  assert.deepEqual(licenseRunsFor("20m", { entity: "ZZ" }), [])
  assert.deepEqual(licenseRunsFor("20m", {}), [])
  assert.ok(!annotationsFor("20m").some(of("plan", "secondary")))
})

test("a hole in the library's plan inside a band is not the band's end", () => {
  // The library has no segment for 17 m's beacons at 18109–18111: read as out of band, the band
  // would have two allocated stretches with a gap between them.
  assert.deepEqual(
    annotationsFor("17m", "N0CALL")
      .filter((a) => a.type === "edge")
      .map((a) => [a.fromHz, a.toHz]),
    [[18068000, 18168000]],
  )
})

test("a band the plan does not know says nothing", () => {
  assert.deepEqual(annotationsFor("23cm", "N0CALL"), [])
})
