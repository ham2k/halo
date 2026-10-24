// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The host draws the sweeps; the extension chooses their layout and controls.
import { host } from "@ham2k/extension-sdk"
import type { PanelContent, PanelHook, PanelRadioState, PanelScene, PanelSceneControl, PanelSceneLayoutNode } from "@ham2k/extension-sdk"

type Display = "both" | "pan" | "waterfall"
interface RadioView {
  display: Display
  step: string
  floor: number
  average: number
  fps: number
  rows: number
}
interface PanelView {
  selection?: string
  defaultId?: string | null
  endpoints: Set<string>
  views: Record<string, RadioView>
}
interface SceneOptions {
  selection?: string
  views?: Record<string, Partial<RadioView>>
}
const defaultView: RadioView = { display: "both", step: "100", floor: 0, average: 40, fps: 15, rows: 10 }

/** A slider with its label beside it, kept together when the wrap breaks. */
const labeled = (text: string, control: string, prefix: string) => ({
  wrap: [{ control: `${prefix}label-${text}` }, { control: `${prefix}${control}`, width: 120 }],
  spacing: 4,
  crossAxisAlignment: "center" as const,
})

/** A sketch when the receiver does not report its actual filter edges. */
function passband(mode: string | null | undefined): [number, number] | null {
  if (!mode) return null
  if (mode.includes("LSB")) return [-2800, -100]
  if (mode.includes("USB") || mode.startsWith("DATA") || mode === "FT8" || mode === "FT4") return [100, 2800]
  if (mode.startsWith("CW")) return [-250, 250]
  if (mode === "AM" || mode === "FM") return [-3000, 3000]
  return null
}

const cyan = "#2EC5F0"
const landmarks: [string, number, "start" | "center" | "end"][] = [
  ["PSK", 14070000, "center"],
  ["FT8", 14074000, "start"],
  ["FT4", 14080000, "center"],
  ["SSTV", 14230000, "start"],
  ["QRP", 14285000, "end"],
  ["Maritime net", 14300000, "center"],
]
const spanLabel = (hz: number) => `±${hz >= 1000 ? `${hz / 1000} kHz` : `${hz} Hz`}`

function radioScene(radio: PanelRadioState | null, view: RadioView, multiple: boolean, visible: boolean, compact: boolean): PanelScene {
  const id = radio?.id ?? ""
  const prefix = multiple ? `${encodeURIComponent(id)}-` : ""
  const key = (name: string) => `${prefix}${name}`
  const event = (action: string) => `${action}:${encodeURIComponent(id)}`
  const title = radio?.channel?.label ?? radio?.name ?? "Radio"
  const canTune = radio?.canTune === true
  const hasFrequency = radio?.frequencyHz != null
  const spectrum = radio?.spectrum
  const knobs = spectrum && !spectrum.problem
  const hasSpan = knobs && spectrum.spansHz.length > 0
  const hasSpeed = knobs && spectrum.speeds.length > 0
  const hasRef =
    knobs &&
    Number.isFinite(spectrum.refMinDb) &&
    Number.isFinite(spectrum.refMaxDb) &&
    Number.isFinite(spectrum.refStepDb) &&
    spectrum.refMinDb < spectrum.refMaxDb &&
    spectrum.refStepDb > 0
  const ref = hasRef ? Math.max(spectrum.refMinDb, Math.min(spectrum.refMaxDb, spectrum.refLevelDb ?? spectrum.refMinDb)) : 0
  const band = hasFrequency ? (radio?.passband ? [radio.passband.lowHz, radio.passband.highHz] : passband(radio?.mode)) : null
  const controls: PanelSceneControl[] = [
    ...(multiple ? [{ id: key("heading"), label: title, kind: "nativeText" as const }] : []),
    ...(hasSpan
      ? [
          {
            id: key("span"),
            label: `${title} span`,
            kind: "nativeDropdown" as const,
            value: key("span"),
            event: event("span"),
            options: spectrum.spansHz.map((hz) => ({ label: spanLabel(hz), value: String(hz) })),
          },
        ]
      : []),
    ...(hasRef
      ? [
          {
            id: key("ref"),
            label: `${title} reference level`,
            kind: "nativeSlider" as const,
            value: key("ref"),
            event: event("ref"),
            min: spectrum.refMinDb,
            max: spectrum.refMaxDb,
            step: spectrum.refStepDb,
          },
        ]
      : []),
    ...(hasSpeed
      ? [
          {
            id: key("speed"),
            label: `${title} speed`,
            kind: "nativeSegmented" as const,
            value: key("speed"),
            event: event("speed"),
            options: spectrum.speeds.map((s) => ({ label: s, value: s })),
          },
        ]
      : []),
    { id: key("floor"), label: `${title} contrast`, kind: "nativeSlider", value: key("floor"), event: event("floor"), min: -30, max: 30, step: 1 },
    { id: key("average"), label: `${title} averaging`, kind: "nativeSlider", value: key("average"), event: event("average"), min: 0, max: 95, step: 5 },
    { id: key("fps"), label: `${title} panadapter FPS`, kind: "nativeSlider", value: key("fps"), event: event("fps"), min: 1, max: 30, step: 1 },
    { id: key("rows"), label: `${title} waterfall rows per second`, kind: "nativeSlider", value: key("rows"), event: event("rows"), min: 1, max: 30, step: 1 },
    ...[...(hasRef ? ["Ref"] : []), "Contrast", "Avg", "FPS", "Rows"].map((text) => ({ id: key(`label-${text}`), label: text, kind: "nativeText" as const })),
    ...(canTune
      ? [
          {
            id: key("step"),
            label: "Tuning step",
            kind: "nativeSegmented" as const,
            value: key("step"),
            event: event("step"),
            options: ["10", "100", "500", "1000"].map((hz) => ({ label: Number(hz) >= 1000 ? `${Number(hz) / 1000} kHz` : `${hz} Hz`, value: hz })),
          },
        ]
      : []),
    {
      id: key("display"),
      label: `${title} display`,
      kind: "nativeSegmented",
      value: key("display"),
      event: event("display"),
      options: (["both", "pan", "waterfall"] as const).map((d) => ({ label: d, value: d })),
    },
  ]
  const scope: PanelSceneControl = {
    id: key("spectrum"),
    label: multiple ? `${title} panadapter` : "Panadapter",
    kind: "spectrum",
    ...(radio?.id ? { radio: radio.id } : {}),
    opacity: visible ? 1 : 0,
    ...(canTune ? { event: event("tune"), tuneStep: Number(view.step) } : {}),
    display: view.display,
    floor: key("floor"),
    average: key("average"),
    fps: key("fps"),
    waterfallSpeed: key("rows"),
    backgroundColor: "#0B0E17",
    traceColor: "#3FD0F0",
    fillColor: "#CC3FD0F0",
    fillColorBottom: "#B3104A5C",
    gridColor: "#2A3446",
    gridDashed: true,
    scale: {
      gap: 26,
      background: "#151B26",
      borderTop: { color: "#2A3446", width: 1 },
      borderBottom: { color: "#2A3446", width: 1 },
      labels: { color: "#8FA3B8", size: 12, offset: 8 },
      ticks: { color: "#8FA3B8", width: 1, offset: 0, length: 5 },
    },
    // The waterfall's window sits above the panadapter's to keep noise black.
    waterfallFloor: 12,
    waterfallRange: 50,
    waterfallColors: ["#000000", "#00004A", "#0000FF", "#00C8FF", "#00FF60", "#FFFF00", "#FF2000"],
    center: hasFrequency ? { pan: { color: cyan, width: 4 }, waterfall: { color: cyan, width: 4 } } : {},
    annotations: landmarks.map(([text, hz, align]) => ({
      id: text,
      text,
      hz,
      align,
      borderColor: "#FFB020",
      pointer: { size: 5 },
      ...(canTune ? { event: event("goto") } : {}),
      offset: 6,
      color: "#0B0E17",
      background: "#E6FFB020",
      size: 11,
      weight: 600,
    })),
    overlays: [
      ...(band ? [{ from: band[0], to: band[1], pan: { fill: "#262EC5F0", color: "#992EC5F0" } }] : []),
      { at: 14000000, anchor: "absolute", pan: { color: "#FF3030", width: 3 }, waterfall: { color: "#FF3030", width: 3 } },
      { from: 13900000, to: 14000000, anchor: "absolute", pan: { fill: "#33FF3030" }, waterfall: { fill: "#33FF3030" } },
    ],
    hoverHz: key("hoverHz"),
    hoverDb: key("hoverDb"),
  }
  const toolbar: PanelSceneLayoutNode = {
    wrap: [
      ...(multiple ? [{ control: key("heading") }] : []),
      ...(hasSpan ? [{ control: key("span"), width: 120 }] : []),
      ...(hasRef ? [labeled("Ref", "ref", prefix)] : []),
      ...(!compact
        ? [
            ...(hasSpeed ? [{ control: key("speed") }] : []),
            labeled("Contrast", "floor", prefix),
            labeled("Avg", "average", prefix),
            labeled("FPS", "fps", prefix),
            labeled("Rows", "rows", prefix),
            ...(canTune ? [{ control: key("step") }] : []),
            { control: key("display") },
          ]
        : []),
    ],
    spacing: 8,
    runSpacing: 4,
    padding: 4,
  }
  // Both reserves room for two waterfalls even in a narrow panel. All other
  // settings remain in the view state and are available in Main or Sub.
  const compactIds = new Set(["heading", "span", "ref", "label-Ref"].map(key))
  const toolbarControls = compact ? controls.filter((control) => compactIds.has(control.id)) : controls
  return {
    version: 1,
    width: 600,
    height: 24,
    values: {
      [key("floor")]: view.floor,
      [key("average")]: view.average,
      [key("fps")]: view.fps,
      [key("rows")]: view.rows,
      [key("hoverHz")]: 0,
      [key("hoverDb")]: 0,
      [key("ref")]: ref,
    },
    strings: {
      [key("span")]: hasSpan && spectrum.spanHz != null && spectrum.spansHz.includes(spectrum.spanHz) ? String(spectrum.spanHz) : "",
      [key("speed")]: hasSpeed && spectrum.speed != null && spectrum.speeds.includes(spectrum.speed) ? spectrum.speed : "",
      [key("display")]: view.display,
      [key("step")]: view.step,
    },
    layers: visible
      ? [
          {
            id: key("readout"),
            x: 0,
            y: 0,
            width: 600,
            height: 24,
            text: { value: key("hoverHz"), prefix: multiple ? `${title} · ` : "", scale: 0.001, decimals: 3, suffix: " kHz", size: 14 },
          },
        ]
      : [],
    controls: [...(visible ? toolbarControls : []), scope],
    // Both spectrum slots stay in the document so changing visibility does not
    // exchange histories. A hidden slot has no demand and takes no space.
    layout: {
      column: [...(visible ? [toolbar] : []), { control: key("spectrum"), ...(visible ? { flex: 1 } : { height: 0 }) }],
      ...(visible ? { flex: 1 } : { height: 0 }),
      crossAxisAlignment: "stretch",
    },
  }
}

/** Only a pair offers Both; larger devices keep the designated receiver's view. */
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
  const panes = radios.map((receiver) =>
    radioScene(
      receiver,
      { ...defaultView, ...options.views?.[receiver?.id ?? ""] },
      multiple,
      selected === "both" || selected === (receiver?.id ?? ""),
      selected === "both",
    ),
  )
  const layers = panes.flatMap((pane) => pane.layers).map((layer, i) => ({ ...layer, y: i * 24 }))
  return {
    version: 1,
    width: 600,
    height: layers.length * 24,
    values: Object.assign({}, ...panes.map((pane) => pane.values)),
    strings: { ...Object.assign({}, ...panes.map((pane) => pane.strings)), ...(multiple ? { selection: selected } : {}) },
    layers,
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
                ...radios.map((receiver) => ({ label: receiver!.channel?.label ?? receiver!.name ?? "Radio", value: receiver!.id! })),
                { label: "Both", value: "both" },
              ],
            },
          ]
        : []),
      ...panes.flatMap((pane) => pane.controls!),
    ],
    layout: {
      column: [...(multiple ? [{ control: "radios" }] : []), ...panes.map((pane) => pane.layout!), { scene: true, height: layers.length * 24 }],
      crossAxisAlignment: "stretch",
    },
  }
}

export function createPanafall(): PanelHook {
  const views = new Map<string, PanelView>()
  const viewFor = (instanceId = "") => {
    let view = views.get(instanceId)
    if (!view) {
      view = { endpoints: new Set(), views: {} }
      views.set(instanceId, view)
    }
    return view
  }
  return {
    async getPanels() {
      return [{ key: "panafall", title: "Panadapter", icon: "waveform", multiple: true, on: ["tick:2"] }]
    },
    async render(args): Promise<PanelContent> {
      const radio = await host.readRadio()
      const available = radio?.deviceId ? await host.listRadios() : []
      const view = viewFor(args.instanceId)
      if (view.defaultId !== radio?.id) {
        view.defaultId = radio?.id
        view.selection = radio?.id ?? undefined
      }
      view.endpoints = new Set(receivers(radio, available).map((receiver) => receiver?.id ?? ""))
      return { kind: "scene", scene: scene(radio, view, available) }
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
      const preferences = (view.views[id] ??= { ...defaultView })
      if (command === "step") {
        if (text && ["10", "100", "500", "1000"].includes(text)) preferences.step = text
        return { values: {} }
      }
      if (command === "display") {
        if (text === "both" || text === "pan" || text === "waterfall") preferences.display = text
        return { values: {} }
      }
      if (command === "floor" || command === "average" || command === "fps" || command === "rows") {
        if (typeof value === "number" && Number.isFinite(value)) {
          const [min, max] = command === "floor" ? [-30, 30] : command === "average" ? [0, 95] : [1, 30]
          preferences[command] = Math.max(min, Math.min(max, value))
        }
        return { values: {} }
      }
      if (!id) return { values: {} }
      const radio = await host.readRadio(id)
      if (radio?.id !== id) return { values: {} }
      const target = { id, selection: id }
      if ((command === "tune" || command === "goto") && radio.canTune && typeof value === "number" && Number.isFinite(value)) {
        await host.setRadio({ ...target, frequencyHz: Math.round(value) })
      } else if (command === "span" && text && Number.isFinite(Number(text))) {
        await host.setRadioSpectrum({ ...target, spanHz: Number(text) })
      } else if (command === "ref" && typeof value === "number" && Number.isFinite(value)) {
        await host.setRadioSpectrum({ ...target, refLevelDb: value })
      } else if (command === "speed" && (text === "slow" || text === "mid" || text === "fast")) {
        await host.setRadioSpectrum({ ...target, speed: text })
      }
      return { values: {} }
    },
  }
}
