// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT

import type { ExportOption, ExportSettings, ExportTypeDefinition, GlobalExportSettings, JSONValue } from "./types.ts"
import { startMillisOf } from "./exportNames.ts"
import { templateContext } from "./templateContext.ts"
import { oneLine, renderTemplate } from "./templates.ts"
import { isTestOperation } from "./testOperation.ts"

export const EXPORT_DEFAULTS: ExportSettings = {
  includePrivateData: false,
  includeLookupData: true,
  customTemplates: false,
  filenameTemplate:
    "{{ op.date }} {{ log.station }}{% if log.ref != blank %} at {{ log.ref }}{% elsif log.activity != blank %} for {{ log.activity }}{% endif %} {{ log.modifier }}",
  compactFilenameTemplate:
    "{{ log.station | dash }}{% if log.ref != blank %}@{{ log.ref | dash }}{% elsif log.activity != blank %}-{{ log.activity | downcase | dash }}{% endif %}-{{ op.dateCompact }}{% if log.modifier != blank %}-{{ log.modifier | downcase | dash }}{% endif %}",
  titleTemplate:
    "{{ log.station }}{% if log.ref != blank %}: {{ log.activity }} at {{ log.ref }} {{ log.refName }}{% elsif log.activity != blank %}: {{ log.activity }}{% endif %} on {{ op.date }}",
  adifNotesTemplate: "{{ qso.notes }}",
  adifCommentTemplate: "{{ qso.notes }}",
  adifQslMessageTemplate: "",
}

export const GLOBAL_EXPORT_DEFAULTS: GlobalExportSettings = {
  ...EXPORT_DEFAULTS,
  referenceFilenameTemplate: "{{ op.date }} {{ log.station }} at {{ log.ref }} {{ log.modifier }}",
  referenceCompactFilenameTemplate:
    "{{ log.station | dash }}@{{ log.ref | dash }}-{{ op.dateCompact }}{% if log.modifier != blank %}-{{ log.modifier | downcase | dash }}{% endif %}",
  referenceTitleTemplate: "{{ log.station }}: {{ log.activity }} at {{ log.ref }} {{ log.refName }} on {{ op.date }}",
  otherFilenameTemplate: "{{ op.date }} {{ log.station }}{% if log.activity != blank %} for {{ log.activity }}{% endif %} {{ log.modifier }}",
  otherCompactFilenameTemplate:
    "{{ log.station | dash }}{% if log.activity != blank %}-{{ log.activity | downcase | dash }}{% endif %}-{{ op.dateCompact }}{% if log.modifier != blank %}-{{ log.modifier | downcase | dash }}{% endif %}",
  otherTitleTemplate: "{{ log.station }}{% if log.activity != blank %}: {{ log.activity }}{% endif %} on {{ op.date }}",
}

export function resolveGlobalExportSettings(global: GlobalExportSettings = {}): GlobalExportSettings {
  const resolved = { ...GLOBAL_EXPORT_DEFAULTS, ...global }
  // A saved common template remains the fallback until each category is customized.
  for (const prefix of ["reference", "other"] as const) {
    for (const suffix of ["FilenameTemplate", "CompactFilenameTemplate", "TitleTemplate"] as const) {
      const key = `${prefix}${suffix}` as keyof GlobalExportSettings
      const legacy = `${suffix[0].toLowerCase()}${suffix.slice(1)}` as keyof ExportSettings
      if (global[key] === undefined && typeof global[legacy] === "string") {
        Object.assign(resolved, { [key]: global[legacy] })
      }
    }
  }
  return resolved
}

/// Activation identity belongs to the activity, not to the implementing extension.
export function exportTypeDefinition(activationType: string, format: string, label: string, defaults?: ExportSettings): ExportTypeDefinition {
  return { exportType: `${activationType}-${format}`, activationType, format, label, defaults }
}

const templateKeys = [
  "filenameTemplate",
  "compactFilenameTemplate",
  "titleTemplate",
  "adifNotesTemplate",
  "adifCommentTemplate",
  "adifQslMessageTemplate",
] as const

export function resolveExportSettings(definition: ExportTypeDefinition, global: GlobalExportSettings = {}, overrides: ExportSettings = {}): ExportSettings {
  const defaults = resolveGlobalExportSettings(global)
  const reference = definition.templateCategory === "reference"
  const resolved: ExportSettings = {
    includePrivateData: defaults.includePrivateData,
    includeLookupData: defaults.includeLookupData,
    adifNotesTemplate: defaults.adifNotesTemplate,
    adifCommentTemplate: defaults.adifCommentTemplate,
    adifQslMessageTemplate: defaults.adifQslMessageTemplate,
    filenameTemplate: reference ? defaults.referenceFilenameTemplate : defaults.otherFilenameTemplate,
    compactFilenameTemplate: reference ? defaults.referenceCompactFilenameTemplate : defaults.otherCompactFilenameTemplate,
    titleTemplate: reference ? defaults.referenceTitleTemplate : defaults.otherTitleTemplate,
    ...definition.defaults,
  }
  for (const key of ["includePrivateData", "includeLookupData"] as const) {
    if (typeof overrides[key] === "boolean") resolved[key] = overrides[key]
  }
  resolved.customTemplates = overrides.customTemplates === true
  if (resolved.customTemplates) {
    for (const key of templateKeys) {
      // Empty is intentional: an empty ADIF template suppresses that field.
      if (typeof overrides[key] === "string") resolved[key] = overrides[key]
    }
  }
  if (definition.format !== "adif") {
    delete resolved.includePrivateData
    delete resolved.includeLookupData
    for (const key of templateKeys.slice(2)) delete resolved[key]
  }
  return resolved
}

/// Templates see a copy with withheld data removed, including nested guesses.
export function exportQso(qso: Record<string, JSONValue>, settings: ExportSettings): Record<string, JSONValue> {
  const copy = { ...qso }
  for (const side of ["their", "our"]) {
    if (copy[side] && typeof copy[side] === "object" && !Array.isArray(copy[side])) {
      const station = { ...(copy[side] as Record<string, JSONValue>) }
      if (settings.includeLookupData === false) delete station.guess
      if (settings.includePrivateData === false) {
        for (const key of ["name", "city", "email", "notes", "lat", "lon", "multiIdentifier"]) delete station[key]
        if (typeof station.grid === "string") station.grid = station.grid.slice(0, 6)
        if (station.guess && typeof station.guess === "object") {
          const guess = { ...(station.guess as Record<string, JSONValue>) }
          for (const key of ["name", "city", "email", "notes", "lat", "lon", "multiIdentifier"]) delete guess[key]
          if (typeof guess.grid === "string") guess.grid = guess.grid.slice(0, 6)
          station.guess = guess
        }
      }
      copy[side] = station
    }
  }
  if (settings.includePrivateData === false) delete copy.notes
  return copy
}

export function prepareExportOption(
  option: ExportOption & { exportSettings: ExportSettings },
  operation: Record<string, JSONValue>,
  qsos: Record<string, JSONValue>[],
  compact: boolean,
): ExportOption & { exportSettings: ExportSettings; exportTitle: string; exportData: Record<string, JSONValue> } {
  const settings = option.exportSettings
  const extension = ({ adif: "adi", cabrillo: "log", reg1test: "edi" } as Record<string, string>)[option.format] ?? option.filename?.split(".").pop() ?? "txt"
  const data = {
    station: String(operation.stationCall ?? ""),
    ref: "",
    activity: "",
    modifier: "",
    ...option.templateData,
    exportType: option.exportType,
    format: option.format,
    extension,
    compact,
  }
  if (isTestOperation(operation.stationCall)) data.modifier = [data.modifier, "Testing"].filter(Boolean).join(" ")
  const context = templateContext({ operation, qsoCount: option.qsoCount ?? qsos.length, atMillis: startMillisOf(operation, qsos) ?? Date.now(), log: data })
  const template = compact ? settings.compactFilenameTemplate : settings.filenameTemplate
  const rendered = oneLine(renderTemplate(template ?? "", context, "Export filename"))
  const stem =
    rendered
      .replace(/[/\\:*?"<>|\x00-\x1f]+/g, "-")
      .replace(/[. ]+$/g, "")
      .trim() || "export"
  const filename = stem.toLowerCase().endsWith(`.${extension}`) ? stem : `${stem}.${extension}`
  const titleContext =
    settings.includePrivateData === false
      ? {
          ...context,
          op: {
            ...(context.op as Record<string, unknown>),
            title: "",
            userTitle: "",
            userNotes: "",
            grid: String((context.op as Record<string, unknown>).grid ?? "").slice(0, 6),
          },
          log: { ...(context.log as Record<string, unknown>), modifier: "" },
        }
      : context
  const title = oneLine(renderTemplate(settings.titleTemplate ?? "", titleContext, "Export title"))
  return { ...option, filename, exportTitle: title, exportData: settings.includePrivateData === false ? { ...data, modifier: "" } : data }
}
