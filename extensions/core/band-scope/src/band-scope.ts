// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The app draws the sweeps and handles the pointer — a click or the wheel
// tunes, a drag along the scale zooms and across it resizes, a drag on the
// picture pans (extension API 17) — so this panel only lays the scope out,
// takes its settings from the pane's own form, behind its gear, and keeps
// the zoom, the split and the levels the operator left.
import type {
  JSONValue,
  PanelContent,
  PanelHook,
  PanelRadioResult,
  PanelRadioSpectrumSet,
  PanelRadioState,
  PanelScene,
  PanelSceneControl,
  SettingsField,
} from "@ham2k/extension-sdk"

/** The host calls this panel makes, handed in so a test can stand in for them. */
export interface BandScopeHost {
  readRadio(id?: string): Promise<PanelRadioState | null>
  listRadios(): Promise<PanelRadioState[]>
  setRadioSpectrum(args: PanelRadioSpectrumSet): Promise<PanelRadioResult>
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
  /** The radio's reference level and sweep speed; absent, left as the radio has them. */
  ref?: number
  speed?: Speed
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
  /** The reference level and speed last sent to each receiver, so each is sent once per change of the form. */
  sent: Record<string, { ref?: number; speed?: Speed }>
}
export interface SceneOptions {
  selection?: string
  settings?: Partial<Settings>
  views?: Record<string, RadioView>
}
const defaultSettings: Settings = {
  display: "both",
  floor: 0,
  average: 40,
  fps: 15,
  rows: 10,
}

const choices = (values: number[], label: (value: number) => string) => values.map((value) => ({ value, label: label(value) }))

/** The pane's form, behind its gear in Layout Setup; the app keeps each placed pane's values. */
const form: SettingsField[] = [
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
    key: "ref",
    label: "Reference level (dB)",
    placeholder: "The radio's",
    description: "Sent to the radio when changed here; blank leaves the radio's own.",
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
  const ref = numberIn(config.ref)
  return {
    display,
    floor: clamp(numberIn(config.floor) ?? defaultSettings.floor, -60, 60),
    average: clamp(numberIn(config.average) ?? defaultSettings.average, 0, 95),
    fps: clamp(numberIn(config.fps) ?? defaultSettings.fps, 1, 30),
    rows: clamp(numberIn(config.rows) ?? defaultSettings.rows, 1, 30),
    ...(ref != null ? { ref } : {}),
    ...(speed ? { speed } : {}),
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

function radioScene(radio: PanelRadioState | null, settings: Settings, view: RadioView, multiple: boolean, visible: boolean, compact: boolean): PanelScene {
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
    backgroundColor: "#0B0E17",
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
    // The waterfall's window sits above the spectrum's to keep noise black.
    waterfallFloor: 12,
    waterfallRange: 50,
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
 * The reference level and speed the form names, sent to [radio] where they differ from what this
 * pane last sent it: once when it first shows, then once per change of the form, so the radio's
 * own knob is not fought on every render.
 */
async function sendSettings(host: BandScopeHost, view: PanelView, radio: PanelRadioState | null, settings: Settings) {
  const spectrum = radio?.spectrum
  if (!radio?.id || !spectrum || spectrum.problem) return
  const sent = (view.sent[radio.id] ??= {})
  const change: Omit<PanelRadioSpectrumSet, "id"> = {}
  if (settings.ref != null && settings.ref !== sent.ref && spectrum.refMinDb < spectrum.refMaxDb && spectrum.refStepDb > 0) {
    const stepped = Math.round((settings.ref - spectrum.refMinDb) / spectrum.refStepDb) * spectrum.refStepDb + spectrum.refMinDb
    change.refLevelDb = clamp(stepped, spectrum.refMinDb, spectrum.refMaxDb)
  }
  if (settings.speed && settings.speed !== sent.speed && spectrum.speeds.includes(settings.speed)) change.speed = settings.speed
  if (change.refLevelDb != null || change.speed) {
    // Recorded only once the radio has it, or never will: a pane's first render comes before its
    // scope runs, answered `stopped`, and recorded then it would never be sent at all. One that
    // throws fails this render; either way the next render sends it again.
    const result = await host.setRadioSpectrum({ ...change, id: radio.id, selection: radio.id })
    if (!result.accepted && result.reason !== "invalid" && result.reason !== "unsupported") return
  }
  sent.ref = settings.ref
  sent.speed = settings.speed
}

export function createBandScope(host: BandScopeHost): PanelHook {
  const views = new Map<string, PanelView>()
  const viewFor = (instanceId = "") => {
    let view = views.get(instanceId)
    if (!view) {
      view = { endpoints: new Set(), views: {}, sent: {} }
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
          on: ["tick:2"],
          form,
        },
      ]
    },
    async render(args): Promise<PanelContent> {
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
      return { kind: "scene", scene: scene(radio, { ...view, settings }, available) }
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
        }
        return { values: {} }
      }
      return { values: {} }
    },
  }
}
