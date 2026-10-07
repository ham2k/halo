// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
import { test } from "node:test"
import assert from "node:assert/strict"
import { EXPORT_DEFAULTS, exportQso, exportTypeDefinition, prepareExportOption, resolveExportSettings } from "./exportSettings.ts"

const operation = { stationCall: "N0CALL/P", userTitle: "Private title", startAtMillisMin: Date.UTC(2026, 6, 15), refs: [] }

test("two implementations share settings by activation type and format", () => {
  const first = exportTypeDefinition("potaActivation", "adif", "POTA")
  const second = exportTypeDefinition("potaActivation", "adif", "Another POTA exporter")
  assert.equal(first.exportType, second.exportType)
  const preferences = { includeLookupData: false, customTemplates: true, adifNotesTemplate: "" }
  assert.deepEqual(resolveExportSettings(first, {}, preferences), resolveExportSettings(second, {}, preferences))
})

test("custom templates can be disabled without losing intentional empty overrides", () => {
  const definition = exportTypeDefinition("potaActivation", "adif", "POTA")
  assert.equal(resolveExportSettings(definition, {}, { customTemplates: true, adifNotesTemplate: "" }).adifNotesTemplate, "")
  assert.equal(resolveExportSettings(definition, {}, { customTemplates: false, adifNotesTemplate: "" }).adifNotesTemplate, "{{ qso.notes }}")
  assert.equal(resolveExportSettings(definition, { includeLookupData: false }).includeLookupData, false)
})

test("Cabrillo has filename templates only even when global preferences contain ADIF fields", () => {
  const settings = resolveExportSettings(exportTypeDefinition("cqww", "cabrillo", "CQ WW"), { includePrivateData: true, adifNotesTemplate: "private" })
  assert.equal(settings.includePrivateData, undefined)
  assert.equal(settings.includeLookupData, undefined)
  assert.equal(settings.adifNotesTemplate, undefined)
  assert.equal(settings.titleTemplate, undefined)
  assert.ok(settings.filenameTemplate)
})

test("each park renders its own filename under the shared type and keeps its key", () => {
  const files = ["US-1234", "US-5678"].map((ref) =>
    prepareExportOption(
      {
        exportType: "potaActivation-adif",
        exportKey: `pota-adif:${ref}`,
        format: "adif",
        label: "POTA",
        templateData: { ref, activity: "POTA" },
        exportSettings: EXPORT_DEFAULTS,
      },
      operation,
      [],
      false,
    ),
  )
  assert.equal(files[0].filename, "2026-07-15 N0CALL-P at US-1234.adi")
  assert.equal(files[1].filename, "2026-07-15 N0CALL-P at US-5678.adi")
  assert.equal(files[1].exportKey, "pota-adif:US-5678")
})

test("custom filename paths are sanitized and extensions are not duplicated", () => {
  const prepared = prepareExportOption(
    {
      exportType: "adif",
      format: "adif",
      label: "ADIF",
      exportSettings: { filenameTemplate: "../{{ log.station }}.adi", titleTemplate: "{{ op.userTitle }}", includePrivateData: false },
    },
    operation,
    [],
    false,
  )
  assert.equal(prepared.filename, "..-N0CALL-P.adi")
  assert.equal(prepared.exportTitle, "")
})

test("lookup data is excluded without erasing entered values or mutating the log", () => {
  const qso = { notes: "private", their: { call: "W1AW", name: "Entered", guess: { name: "Lookup", state: "CT" } } }
  const clean = exportQso(qso, { includeLookupData: false })
  assert.deepEqual(clean.their, { call: "W1AW", name: "Entered" })
  assert.ok(qso.their.guess)
  assert.equal(exportQso(qso, { includePrivateData: false }).notes, undefined)
})

test("a broken filename template is reported instead of exporting an invented name", () => {
  assert.throws(() =>
    prepareExportOption({ exportType: "adif", format: "adif", label: "ADIF", exportSettings: { filenameTemplate: "{% if log.ref %}" } }, operation, [], false),
  )
})

test("filename and title count the selected file while retaining the operation date", () => {
  const prepared = prepareExportOption(
    {
      exportType: "potaActivation-adif",
      format: "adif",
      label: "POTA",
      qsoCount: 1,
      exportSettings: { filenameTemplate: "{{ op.date }} {{ op.qsoCount }} QSOs", titleTemplate: "{{ op.qsoCount }} contacts" },
    },
    operation,
    [{ startAtMillis: Date.UTC(2026, 6, 14) }, { startAtMillis: Date.UTC(2026, 6, 15) }],
    false,
  )
  assert.equal(prepared.filename, "2026-07-14 1 QSOs.adi")
  assert.equal(prepared.exportTitle, "1 contacts")
})

test("private operation grids and internal positions stay out of public template output", () => {
  const prepared = prepareExportOption(
    {
      exportType: "adif",
      format: "adif",
      label: "ADIF",
      exportSettings: { filenameTemplate: "log", titleTemplate: "{{ op.grid }}", includePrivateData: false },
    },
    { ...operation, grid: "FN31pr12" },
    [],
    false,
  )
  assert.equal(prepared.exportTitle, "FN31pr")
  assert.deepEqual(exportQso({ our: { multiIdentifier: "Private desk", grid: "FN31pr12" } }, { includePrivateData: false }), { our: { grid: "FN31pr" } })
})

// A lookup fills `street` and `email` on the guess, never on `their`: a strip
// that only cleaned the station itself would leak both through a template.
test("a looked-up mailing address and email stay out of output that withholds private data", () => {
  const qso = { their: { call: "W1AW", guess: { street: "225 Main St", email: "w1aw@example.org", county: "Hartford" } } }
  assert.deepEqual(exportQso(qso, { includePrivateData: false }), { their: { call: "W1AW", guess: { county: "Hartford" } } })
  assert.deepEqual(exportQso(qso, { includePrivateData: true }), qso)
})

test("global activity templates stay independent across formats and per-type overrides", () => {
  const reference = { ...exportTypeDefinition("potaActivation", "adif", "POTA"), templateCategory: "reference" as const }
  const other = exportTypeDefinition("cqww", "cabrillo", "CQ WW")
  const global = {
    referenceFilenameTemplate: "Park {{ log.ref }}",
    referenceCompactFilenameTemplate: "R-{{ log.ref }}",
    referenceTitleTemplate: "Reference title",
    otherFilenameTemplate: "Contest {{ log.activity }}",
    otherCompactFilenameTemplate: "C-{{ log.activity }}",
    otherTitleTemplate: "Other title",
    adifNotesTemplate: "Shared notes",
  }
  const park = resolveExportSettings(reference, global)
  const contest = resolveExportSettings(other, global)
  assert.equal(park.filenameTemplate, global.referenceFilenameTemplate)
  assert.equal(park.compactFilenameTemplate, global.referenceCompactFilenameTemplate)
  assert.equal(park.titleTemplate, "Reference title")
  assert.equal(park.adifNotesTemplate, "Shared notes")
  assert.equal(contest.filenameTemplate, global.otherFilenameTemplate)
  assert.equal(contest.compactFilenameTemplate, global.otherCompactFilenameTemplate)
  assert.equal(contest.titleTemplate, undefined)
  assert.equal(resolveExportSettings({ ...other, format: "adif" }, global).titleTemplate, "Other title")
  assert.equal(resolveExportSettings(reference, global, { customTemplates: true, filenameTemplate: "Mine" }).filenameTemplate, "Mine")
  assert.equal(resolveExportSettings({ ...reference, defaults: { filenameTemplate: "Sponsor" } }, global).filenameTemplate, "Sponsor")
})

test("saved common defaults survive until an activity category is customized", () => {
  const reference = { ...exportTypeDefinition("potaActivation", "adif", "POTA"), templateCategory: "reference" as const }
  const other = exportTypeDefinition("cqww", "adif", "CQ WW")
  const global = { filenameTemplate: "Saved filename", titleTemplate: "", referenceFilenameTemplate: "Park file" }
  assert.equal(resolveExportSettings(reference, global).filenameTemplate, "Park file")
  assert.equal(resolveExportSettings(other, global).filenameTemplate, "Saved filename")
  assert.equal(resolveExportSettings(reference, global).titleTemplate, "")
  assert.equal(resolveExportSettings(other, global).titleTemplate, "")
})
