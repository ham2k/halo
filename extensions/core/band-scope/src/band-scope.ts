// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The app draws the sweeps and handles the pointer — a click or the wheel
// tunes, a drag along the scale zooms and across it resizes, a drag on the
// picture pans (extension API 17) — so this panel only lays the scope out,
// takes its settings from the pane's own form, behind its gear, keeps
// the zoom, the split and the levels the operator left, and marks the band
// plan and the spots on the band, a click on a spot working it as a Spots
// Panel tap does.
import { bandForFrequency } from "@ham2k/lib-operation-data"
import type {
  FormHeader,
  HookContext,
  JSONValue,
  PanelContent,
  PanelHook,
  PanelRadioResult,
  PanelRadioSet,
  PanelRadioSpectrumSet,
  PanelRadioState,
  PanelScene,
  PanelSceneControl,
  PanelSceneSpectrumAnnotation,
  PanelSceneSpectrumLayer,
  SettingsField,
  SuggestedQso,
} from "@ham2k/extension-sdk"
import { planLayers, planRow, type PlanDetail } from "./band-plan.ts"
import { laneHeight, noteSpots, radioModeFor, scopeBackground, scopeSpots, spotId, spotMarks, suggestionFor, type ScopeSpot } from "./spots.ts"

/** The host calls this panel makes, handed in so a test can stand in for them. */
export interface BandScopeHost {
  readRadio(id?: string): Promise<PanelRadioState | null>
  listRadios(): Promise<PanelRadioState[]>
  setRadioSpectrum(args: PanelRadioSpectrumSet): Promise<PanelRadioResult>
  setRadio(args: PanelRadioSet): Promise<PanelRadioResult>
  /** The spot's station into the panel's operation's logging fields, as a Spots Panel tap. */
  suggestQso(args: { qso: SuggestedQso; operationUuid?: string }): Promise<{ accepted: boolean }>
}

type Display = "both" | "spectrum" | "waterfall"
type Speed = "slow" | "mid" | "fast"

/** The pane's settings, from its form: what every receiver it shows is drawn with. */
export interface Settings {
  display: Display
  /** The spectrum's floor, in dB above the radio's. */
  floor: number
  average: number
  fps: number
  rows: number
  /** How far the waterfall's baseline is lowered, in dB: higher brightens it, as a radio's REF does. */
  waterfallRef: number
  /** The radio's sweep speed; absent, left as the radio has it. */
  speed?: Speed
  /** The spots on the band, no older than `age` minutes. */
  spots: boolean
  /** The band's `general` annotations — the operator's band tags, what extensions mark — whether or not the spots show. */
  notes: boolean
  age: number
  /** How far over the noise the spots stand on the spectrum, in dB; under it when negative. */
  spotLevel: number
  /** How much of the band plan is drawn. */
  plan: PlanDetail
}
/** What the operator dragged on one receiver's scope, kept for the session over the settings. */
export interface RadioView {
  /** The width the operator zoomed to, in Hz; absent, the whole sweep. */
  span?: number
  /** The spectrum's share of the height. */
  split?: number
  /** The spectrum's floor and height in dB, and the waterfall's rows a second, from the level strip. */
  floor?: number
  range?: number
  rows?: number
}
interface PanelView {
  selection?: string
  defaultId?: string | null
  endpoints: Set<string>
  views: Record<string, RadioView>
  /** The speed last sent to each receiver, so it is sent once per change of the form. */
  sent: Record<string, { speed?: Speed }>
  /** The spots each receiver's scope last marked, by annotation id, for a click to find. */
  spots: Record<string, Map<string, ScopeSpot>>
}
/** The spots' marks on one receiver's scope. */
export interface Marks {
  annotations: PanelSceneSpectrumAnnotation[]
  layers: PanelSceneSpectrumLayer[]
}
export interface SceneOptions {
  selection?: string
  settings?: Partial<Settings>
  views?: Record<string, RadioView>
  marks?: Record<string, Marks>
}
const defaultSettings: Settings = {
  display: "both",
  floor: 0,
  average: 40,
  fps: 15,
  rows: 10,
  waterfallRef: 0,
  spots: true,
  notes: true,
  age: 30,
  spotLevel: 30,
  plan: "modes",
}

const choices = (values: number[], label: (value: number) => string) => values.map((value) => ({ value, label: label(value) }))

/** The pane's form, behind its gear in Layout Setup; the app keeps each placed pane's values. */
const form: (SettingsField | FormHeader)[] = [
  {
    type: "field",
    fieldType: "select",
    key: "display",
    label: "Show",
    value: "both",
    options: [
      { value: "both", label: "Spectrum and waterfall" },
      { value: "spectrum", label: "Spectrum" },
      { value: "waterfall", label: "Waterfall" },
    ],
  },
  { type: "field", fieldType: "checkbox", key: "spots", label: "Show spots", value: true },
  {
    type: "field",
    fieldType: "checkbox",
    key: "notes",
    label: "Show annotations",
    value: true,
    description: "What is marked on the band among the spots: your band tags (QRM!, NET!) and what extensions mark.",
  },
  { type: "field", fieldType: "select", key: "age", label: "Spots no older than", value: 30, options: choices([10, 30, 60], (v) => `${v} minutes`) },
  {
    type: "field",
    fieldType: "number",
    key: "spotLevel",
    label: "Spots position (dB over noise floor)",
    value: 30,
    description: "How far over the noise floor the spots stand on the spectrum, about where a workable signal peaks. Negative puts them under it.",
  },
  {
    type: "field",
    fieldType: "select",
    key: "plan",
    label: "Show Band Plan limits",
    value: "modes",
    options: [
      { value: "none", label: "No" },
      { value: "edges", label: "Band Edges" },
      { value: "modes", label: "Edges & Modes" },
      { value: "all", label: "All details" },
    ],
  },
  // What the scope draws and asks of the radio: set once, so folded away.
  { type: "header", title: "Band Scope Settings", style: "section", collapsed: true },
  {
    type: "field",
    fieldType: "number",
    key: "floor",
    label: "Floor (dB)",
    value: 0,
    description: "The spectrum's bottom edge, in dB above the noise the radio reports. Dragging the level strip moves it too.",
  },
  {
    type: "field",
    fieldType: "select",
    key: "average",
    label: "Averaging",
    value: 40,
    options: choices([0, 20, 40, 60, 80, 95], (v) => (v ? `${v}%` : "Off")),
  },
  { type: "field", fieldType: "select", key: "fps", label: "Spectrum frames a second", value: 15, options: choices([5, 10, 15, 20, 30], String) },
  { type: "field", fieldType: "select", key: "rows", label: "Waterfall rows a second", value: 10, options: choices([2, 5, 10, 15, 20, 30], String) },
  {
    type: "field",
    fieldType: "number",
    key: "waterfallRef",
    label: "Waterfall reference level (dB)",
    value: 0,
    description: "Higher brightens the waterfall, lower darkens it; Alt-drag the waterfall's levels to set it by eye. The radio's own screen is left as it is.",
  },
  {
    type: "field",
    fieldType: "select",
    key: "speed",
    label: "Sweep speed",
    value: "radio",
    options: [
      { value: "radio", label: "The radio's" },
      { value: "slow", label: "Slow" },
      { value: "mid", label: "Medium" },
      { value: "fast", label: "Fast" },
    ],
  },
]

const clamp = (value: number, min: number, max: number) => Math.max(min, Math.min(max, value))

/** A number the form holds, which may have been stored as text; blank is none. */
function numberIn(value: JSONValue | undefined): number | undefined {
  if (value == null || value === "") return undefined
  const number = Number(value)
  return Number.isFinite(number) ? number : undefined
}

/** The pane's form values as settings, out-of-range ones brought in and unknown ones dropped. */
export function settingsFrom(config: Record<string, JSONValue>): Settings {
  const display = config.display === "spectrum" || config.display === "waterfall" ? config.display : "both"
  const speed = config.speed === "slow" || config.speed === "mid" || config.speed === "fast" ? config.speed : undefined
  return {
    display,
    floor: clamp(numberIn(config.floor) ?? defaultSettings.floor, -60, 60),
    average: clamp(numberIn(config.average) ?? defaultSettings.average, 0, 95),
    fps: clamp(numberIn(config.fps) ?? defaultSettings.fps, 1, 30),
    rows: clamp(numberIn(config.rows) ?? defaultSettings.rows, 1, 30),
    waterfallRef: clamp(numberIn(config.waterfallRef) ?? defaultSettings.waterfallRef, -30, 30),
    ...(speed ? { speed } : {}),
    // A checkbox may have been stored as text.
    spots: config.spots !== false && config.spots !== "false",
    notes: config.notes !== false && config.notes !== "false",
    age: [10, 30, 60].includes(numberIn(config.age) ?? 0) ? numberIn(config.age)! : defaultSettings.age,
    spotLevel: clamp(numberIn(config.spotLevel) ?? defaultSettings.spotLevel, -60, 120),
    plan: config.plan === "none" || config.plan === "edges" || config.plan === "all" ? config.plan : defaultSettings.plan,
  }
}

/** A sketch of the passband when the radio does not report its filter's edges. */
function passband(mode: string | null | undefined): [number, number] | null {
  if (!mode) return null
  if (mode.includes("LSB")) return [-2800, -100]
  if (mode.includes("USB") || mode.startsWith("DATA") || mode === "FT8" || mode === "FT4") return [100, 2800]
  if (mode.startsWith("CW")) return [-250, 250]
  if (mode === "AM" || mode === "FM") return [-3000, 3000]
  return null
}

const cyan = "#2EC5F0"

function radioScene(
  radio: PanelRadioState | null,
  settings: Settings,
  view: RadioView,
  multiple: boolean,
  visible: boolean,
  compact: boolean,
  marks: Marks | undefined,
): PanelScene {
  const id = radio?.id ?? ""
  const prefix = multiple ? `${encodeURIComponent(id)}-` : ""
  const key = (name: string) => `${prefix}${name}`
  const event = (action: string) => `${action}:${encodeURIComponent(id)}`
  const title = radio?.channel?.label ?? radio?.name ?? "Radio"
  const hasFrequency = radio?.frequencyHz != null
  const band = hasFrequency ? (radio?.passband ? [radio.passband.lowHz, radio.passband.highHz] : passband(radio?.mode)) : null
  // With both receivers shown, each pane says whose it is.
  const heading = visible && compact
  const controls: PanelSceneControl[] = heading ? [{ id: key("heading"), label: title, kind: "nativeText" }] : []
  // No `tuneStep`: the app tunes on a click, at a step that follows the zoom. The event only
  // hears where a zoom, a split or a level drag ended, to keep it.
  const scope: PanelSceneControl = {
    id: key("spectrum"),
    label: multiple ? `${title} band scope` : "Band scope",
    kind: "bandScope",
    ...(radio?.id ? { radio: radio.id } : {}),
    opacity: visible ? 1 : 0,
    event: event("scope"),
    display: settings.display,
    ...(view.span ? { span: view.span } : {}),
    ...(view.split ? { split: view.split } : {}),
    ...(view.range ? { range: view.range } : {}),
    floor: view.floor ?? settings.floor,
    average: settings.average,
    fps: settings.fps,
    waterfallSpeed: view.rows ?? settings.rows,
    follow: 0.15,
    backgroundColor: scopeBackground,
    traceColor: "#3FD0F0",
    fillColor: "#CC3FD0F0",
    fillColorBottom: "#B3104A5C",
    gridColor: "#2A3446",
    gridDashed: true,
    // Both axes lie over the picture, which keeps all its room: the frequency axis, the strip a
    // drag zooms on, across the waterfall's head, and the levels down the right, styled alike.
    scale: {
      over: "waterfall",
      gap: 26,
      background: "#151B26",
      borderTop: { color: "#2A3446", width: 1 },
      borderBottom: { color: "#2A3446", width: 1 },
      labels: { color: "#8FA3B8", size: 12, offset: 8 },
      ticks: { color: "#8FA3B8", width: 1, offset: 0, length: 5 },
    },
    levelScale: { over: true, side: "end" },
    // 30 dB from the waterfall's floor: the noise a navy speckle, a signal 10 dB over it blue to cyan,
    // 20 dB over it green.
    waterfallFloor: waterfallFloorDb - settings.waterfallRef,
    waterfallRange: 30,
    waterfallColors: ["#000000", "#00004A", "#0000FF", "#00C8FF", "#00FF60", "#FFFF00", "#FF2000"],
    center: hasFrequency
      ? {
          spectrum: { color: cyan, width: 4 },
          waterfall: { color: cyan, width: 4 },
        }
      : {},
    overlays: band
      ? [
          {
            from: band[0],
            to: band[1],
            spectrum: { fill: "#262EC5F0", color: "#992EC5F0" },
          },
        ]
      : [],
    ...(marks?.annotations.length ? { annotations: marks.annotations } : {}),
    ...(marks?.layers.length ? { layers: marks.layers } : {}),
  }
  return {
    version: 1,
    width: 600,
    height: 24,
    values: {},
    layers: [],
    controls: [...controls, scope],
    // Both spectrum slots stay in the document, so a change of selection keeps
    // each one's history. A hidden slot asks for no sweeps and takes no space.
    layout: {
      column: [
        ...(heading ? [{ control: key("heading"), padding: 4 }] : []),
        {
          control: key("spectrum"),
          ...(visible ? { flex: 1 } : { height: 0 }),
        },
      ],
      ...(visible ? { flex: 1 } : { height: 0 }),
      crossAxisAlignment: "stretch",
    },
  }
}

/** Only a pair of receivers offers Both; anything else keeps the designated one's view. */
function receivers(radio: PanelRadioState | null, available: PanelRadioState[]): (PanelRadioState | null)[] {
  if (!radio?.id || !radio.deviceId) return [radio]
  const siblings = available.filter((candidate) => candidate.id && candidate.deviceId === radio.deviceId)
  if (siblings.length !== 2 || !siblings.some((candidate) => candidate.id === radio.id)) return [radio]
  const rank = (candidate: PanelRadioState) => (candidate.channel?.key === "main" ? 0 : candidate.channel?.key === "sub" ? 1 : 2)
  return siblings.map((candidate) => (candidate.id === radio.id ? radio : candidate)).sort((a, b) => rank(a) - rank(b))
}

export function scene(radio: PanelRadioState | null, options: SceneOptions = {}, available: PanelRadioState[] = []): PanelScene {
  const radios = receivers(radio, available)
  const multiple = radios.length === 2
  const selected =
    options.selection != null && ((multiple && options.selection === "both") || radios.some((candidate) => candidate?.id === options.selection))
      ? options.selection!
      : (radio?.id ?? "")
  const settings = { ...defaultSettings, ...options.settings }
  const panes = radios.map((receiver) =>
    radioScene(
      receiver,
      settings,
      options.views?.[receiver?.id ?? ""] ?? {},
      multiple,
      selected === "both" || selected === (receiver?.id ?? ""),
      selected === "both",
      options.marks?.[receiver?.id ?? ""],
    ),
  )
  return {
    version: 1,
    width: 600,
    height: 24,
    values: {},
    ...(multiple ? { strings: { selection: selected } } : {}),
    layers: [],
    controls: [
      ...(multiple
        ? [
            {
              id: "radios",
              label: "Receiver",
              kind: "nativeSegmented" as const,
              value: "selection",
              event: "select",
              options: [
                ...radios.map((receiver) => ({
                  label: receiver!.channel?.label ?? receiver!.name ?? "Radio",
                  value: receiver!.id!,
                })),
                { label: "Both", value: "both" },
              ],
            },
          ]
        : []),
      ...panes.flatMap((pane) => pane.controls!),
    ],
    layout: {
      column: [...(multiple ? [{ control: "radios", padding: 4 }] : []), ...panes.map((pane) => pane.layout!)],
      crossAxisAlignment: "stretch",
    },
  }
}

/**
 * The sweep speed the form names, sent to [radio] where it differs from what this pane last sent
 * it: once when it first shows, then once per change of the form, so the radio's own knob is not
 * fought on every render.
 */
async function sendSettings(host: BandScopeHost, view: PanelView, radio: PanelRadioState | null, settings: Settings) {
  const spectrum = radio?.spectrum
  if (!radio?.id || !spectrum || spectrum.problem) return
  const sent = (view.sent[radio.id] ??= {})
  const change: Omit<PanelRadioSpectrumSet, "id"> = {}
  if (settings.speed && settings.speed !== sent.speed && spectrum.speeds.includes(settings.speed)) change.speed = settings.speed
  if (change.speed) {
    // Recorded only once the radio has it, or never will: a pane's first render comes before its
    // scope runs, answered `stopped`, and recorded then it would never be sent at all. One that
    // throws fails this render; either way the next render sends it again.
    const result = await host.setRadioSpectrum({ ...change, id: radio.id, selection: radio.id })
    if (!result.accepted && result.reason !== "invalid" && result.reason !== "unsupported") return
  }
  sent.speed = settings.speed
}

/** The width a receiver's sweep shows unzoomed, in Hz: its edges, or twice its span either side of the dial. */
function sweepWidth(radio: PanelRadioState): number | undefined {
  const sp = radio.spectrum
  if (sp?.lowHz != null && sp.highHz != null && sp.highHz > sp.lowHz) return sp.highHz - sp.lowHz
  return sp?.spanHz ? sp.spanHz * 2 : undefined
}

/** The axis's depth over the picture, as `radioScene` draws it. */
const axisGap = 26

/** Room at the spectrum's top for the dial's own label. */
const dialLabel = 26
/**
 * Where the app puts the noise on a spectrum that follows it — `NoiseFloor.belowNoiseDb` up a
 * display 80 dB tall — which the level strip's floor and range then shift and stretch: what places
 * the spots' level up the spectrum, and so the room over it for their lanes. A radio left to its own
 * scale puts the noise where it will, and the count is a guess there.
 */
const noiseOverFloorDb = 10,
  displayRangeDb = 80

/**
 * The waterfall's floor over the spectrum's at a waterfall reference of 0: 5 dB under the noise,
 * matched by eye to an IC-705's own waterfall. The reference lowers it, never the radio's REF.
 */
const waterfallFloorDb = 5

/** Rows of the band plan's labels at the picture's top: the modes', then the windows' and the markers'. */
const planRows: Record<PlanDetail, number> = { none: 0, edges: 0, modes: 2, all: 3 }

/**
 * The band's annotations and the spots on [radio]'s band, laid out at the width its scope shows
 * across a pane [width] pixels wide and [height] tall: the plan's labels along the picture's top,
 * and the spots and the band's `general` annotations up the spectrum from the settings' level over
 * the noise, or down the waterfall from under the axis and the plan where the pane shows no
 * spectrum. The annotations are those for the station of the operation the panel was rendered for.
 */
async function marksFor(
  ctx: HookContext,
  radio: PanelRadioState,
  settings: Settings,
  view: RadioView,
  nowMillis: number,
  { width, height, fontFamily }: { width: number; height: number; fontFamily?: string },
): Promise<{ marks: Marks; spots: ScopeSpot[] }> {
  const none = { marks: { annotations: [], layers: [] }, spots: [] }
  const shownHz = view.span ?? sweepWidth(radio)
  if (radio.frequencyHz == null || !shownHz || width <= 0) return none
  const band = bandForFrequency(radio.frequencyHz / 1000)
  if (!band || band === "other") return none
  const part = settings.display === "waterfall" ? "waterfall" : "spectrum"
  const hzPerPx = shownHz / width
  const said = (await ctx.getBandAnnotations?.({ band })) ?? []
  // Whatever the sweep takes in, and the band's own edges: the operator pans and zooms natively,
  // and the panel hears where only once a gesture ends, so drawn about the dial alone, an edge the
  // picture was panned to would be missing.
  const dial = radio.frequencyHz,
    reach = Math.max(shownHz, sweepWidth(radio) ?? 0)
  const edges = said.filter((a) => a.type === "edge").flatMap((a) => [a.fromHz, a.toHz ?? a.fromHz])
  const sweep = radio.spectrum?.lowHz != null && radio.spectrum.highHz != null ? [radio.spectrum.lowHz, radio.spectrum.highHz] : [dial, dial]
  const plan = planLayers(said, settings.plan, {
    hzPerPx,
    top: part === "spectrum" ? "spectrum" : `waterfall+${axisGap}px`,
    rows: planRows[settings.plan],
    window: [Math.min(...edges, dial - reach, sweep[0]), Math.max(...edges, dial + reach, sweep[1])],
    most: 64,
    height,
  })
  const board = settings.spots ? ((await ctx.getSpots?.({ filter: "sources", band, maxAgeMinutes: settings.age })) ?? []) : []
  const spots = [...(settings.notes ? noteSpots(said) : []), ...scopeSpots(board, nowMillis)]
  if (!spots.length) return { marks: { annotations: [], layers: plan }, spots: [] }
  const labels = planRows[settings.plan] * planRow
  // The axis lies over the waterfall's head, and over the spectrum's foot only where there is no
  // waterfall; with no spectrum, the plan's labels hang under it.
  const clear = settings.display === "both" ? 0 : axisGap + (part === "waterfall" ? labels : 0)
  const spectrumHeight = settings.display === "both" ? height * (view.split ?? 0.4) : height
  // From the spots' level up to just under the dial's label, or the plan's.
  const floor = view.floor ?? settings.floor
  const spotsUp = Math.min(1, Math.max(0, (noiseOverFloorDb - floor + settings.spotLevel) / (view.range ?? displayRangeDb)))
  const room = part === "spectrum" ? spectrumHeight * (1 - spotsUp) - Math.max(dialLabel, labels) : height - clear
  const { annotations, layers } = spotMarks(spots, {
    hzPerPx,
    lanes: Math.max(1, Math.floor((room - 4) / laneHeight)),
    part,
    clear,
    layers: 512 - plan.length,
    ...(part === "spectrum" ? { from: `noise${settings.spotLevel < 0 ? "-" : "+"}${Math.abs(settings.spotLevel)}db` } : {}),
    maxAgeMinutes: settings.age,
    ...(fontFamily ? { fontFamily } : {}),
    event: `spot:${encodeURIComponent(radio.id ?? "")}`,
  })
  return { marks: { annotations, layers: [...plan, ...layers] }, spots }
}

/**
 * The radio alone to [spot], in the spot's mode where [inItsMode] and the radio has one for it. A
 * refusal is the host's to report, not a success.
 */
async function tuneAlone(host: BandScopeHost, id: string, spot: ScopeSpot, inItsMode: boolean) {
  const radio = await host.readRadio(id)
  if (!radio?.id) throw new Error("The radio is not connected")
  const mode = inItsMode ? radioModeFor(spot.mode, spot.khz, radio.modes ?? []) : undefined
  const result = await host.setRadio({ id: radio.id, frequencyHz: Math.round(spot.khz * 1000), ...(mode && mode !== radio.mode ? { mode } : {}) })
  if (!result.accepted) throw new Error(`The radio did not take it${result.reason ? ` (${result.reason})` : ""}`)
  return { values: {} }
}

export function createBandScope(host: BandScopeHost): PanelHook {
  const views = new Map<string, PanelView>()
  const viewFor = (instanceId = "") => {
    let view = views.get(instanceId)
    if (!view) {
      view = { endpoints: new Set(), views: {}, sent: {}, spots: {} }
      views.set(instanceId, view)
    }
    return view
  }
  return {
    async getPanels() {
      return [
        {
          key: "band-scope",
          title: "Band Scope",
          description: "A radio's spectrum (or panadapter) and waterfall",
          icon: "waveform",
          multiple: true,
          on: ["tick:2", "spots"],
          form,
        },
      ]
    },
    async render(args, ctx): Promise<PanelContent> {
      const radio = await host.readRadio()
      const available = radio?.deviceId ? await host.listRadios() : []
      const view = viewFor(args.instanceId)
      if (view.defaultId !== radio?.id) {
        view.defaultId = radio?.id
        view.selection = radio?.id ?? undefined
      }
      const shown = receivers(radio, available)
      view.endpoints = new Set(shown.map((receiver) => receiver?.id ?? ""))
      const settings = settingsFrom(args.config)
      for (const receiver of shown) await sendSettings(host, view, receiver, settings)
      // Only the receivers shown; each of two shown together has half the pane, under the picker.
      // The selection as the scene reads it: one no longer shown falls back to the radio's own.
      const selected =
        (view.selection === "both" && shown.length === 2) || shown.some((receiver) => receiver?.id === view.selection) ? view.selection : radio?.id
      const visible = shown.filter((receiver) => selected === "both" || receiver?.id === selected)
      const marks: Record<string, Marks> = {}
      // Filled whole, then swapped in: a click arriving while a receiver's spots are still being
      // fetched finds the table the last render drew, not an empty one.
      const spots: typeof view.spots = {}
      if (args.environment) {
        const width = args.environment.width
        // Calls in the app's call face, as the Spots Panel shows them.
        const fontFamily = args.environment.typography.mono.fontFamily ?? undefined
        const height = (args.environment.height - (shown.length === 2 ? 40 : 0)) / Math.max(1, visible.length)
        for (const receiver of visible) {
          if (!receiver?.id) continue
          const found = await marksFor(ctx, receiver, settings, view.views[receiver.id] ?? {}, args.clock?.nowMillis ?? Date.now(), {
            width,
            height,
            fontFamily,
          })
          marks[receiver.id] = found.marks
          const byId = new Map(found.spots.map((spot) => [spotId(spot), spot]))
          spots[receiver.id] = new Map(found.marks.annotations.map((a) => [a.id, byId.get(a.id)!]))
        }
      }
      view.spots = spots
      return { kind: "scene", scene: scene(radio, { ...view, settings, marks }, available) }
    },
    async onEvent(args) {
      const { action, value, text } = args.event
      const view = viewFor(args.instanceId)
      if (action === "select") {
        if (text && (view.endpoints.has(text) || (text === "both" && view.endpoints.size === 2))) view.selection = text
        return { values: {} }
      }
      const separator = action.indexOf(":")
      if (separator < 0) return { values: {} }
      const command = action.slice(0, separator)
      let id: string
      try {
        id = decodeURIComponent(action.slice(separator + 1))
      } catch {
        return { values: {} }
      }
      if (!view.endpoints.has(id)) return { values: {} }
      if (command === "spot") {
        const spot = args.event.annotation ? view.spots[id]?.get(args.event.annotation) : undefined
        if (!spot) return { values: {} }
        // Nothing to log at a note: the radio alone, to where it is, in the mode it is in.
        if (spot.note) return await tuneAlone(host, id, spot, false)
        // As a Spots Panel tap: the station into this operation's logging fields, which move the
        // radio there too. With no such operation open, the radio alone.
        const operationUuid = typeof args.operation?.uuid === "string" ? args.operation.uuid : undefined
        const { accepted } = await host.suggestQso({ qso: suggestionFor(spot), operationUuid })
        if (accepted) return { values: {} }
        return await tuneAlone(host, id, spot, true)
      }
      if (command === "scope") {
        const preferences = (view.views[id] ??= {})
        // A pan is not kept: the radio will have moved by the time it is drawn again.
        // 0 for any of them is a double click, on the scale or the level strip: the
        // whole sweep, or the pane's settings, back. The rest are kept within what the
        // scene takes, the app's own limits for a drag: kept narrower, the picture would
        // snap back under the operator's hand.
        const { gesture } = args.event
        if (typeof value !== "number" || !Number.isFinite(value)) return { values: {} }
        if (gesture === "zoom") {
          if (value > 0) preferences.span = Math.round(value)
          else delete preferences.span
        } else if (gesture === "split") {
          preferences.split = clamp(value, 0.1, 0.9)
        } else if (gesture === "floor") {
          if (value !== 0) preferences.floor = clamp(value, -200, 200)
          else delete preferences.floor
        } else if (gesture === "range") {
          if (value > 0) preferences.range = clamp(value, 1, 200)
          else delete preferences.range
        } else if (gesture === "speed") {
          if (value > 0) preferences.rows = clamp(value, 0.1, 60)
          else delete preferences.rows
        } else if (gesture === "waterfallFloor") {
          // An Alt-drag of the waterfall's levels is the form's reference, kept with the pane rather
          // than for the session; written once, where the drag ends.
          if (args.event.phase !== "commit") return { values: {} }
          return { values: {}, config: { waterfallRef: clamp(Math.round((waterfallFloorDb - value) * 10) / 10, -30, 30) } }
        }
        return { values: {} }
      }
      return { values: {} }
    },
  }
}
