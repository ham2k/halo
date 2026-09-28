// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
import type { PanelContent, PanelHook, PanelScene, SceneBinding, PanelSceneLayer } from "@ham2k/extension-sdk"

const svg = (body: string, width = 640, height = 360) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${height}">${body}</svg>`
const bind = (value: string, input: [number, number], output: [number, number]): SceneBinding => ({ value, input, output })
const label = (x: number, y: number, text: string, size = 16, color = "#9aaec6") =>
  `<text x="${x}" y="${y}" fill="${color}" font-family="sans-serif" font-size="${size}">${text}</text>`
const button = (x: number, text: string) => `<rect x="${x}" y="298" width="172" height="38" rx="8" fill="#283b52"/>${label(x + 12, 322, text, 14, "#e7edf4")}`
const textLayer = (id: string, value: string, x: number, y: number, width: number, size: number, prefix = "", suffix = "", decimals = 0): PanelSceneLayer => ({
  id,
  x,
  y,
  width,
  height: size + 12,
  text: { value, prefix, suffix, decimals, size, color: "#a9efcf" },
})

type RadioState = { requested: number; reported: number; connected: number; due: number; slow: number }
type FormState = { strings: Record<string, string>; values: Record<string, number> }
/** Inject time for deterministic tests; no timers or per-frame extension work. */
export function createScenePanels(now: () => number = () => Date.now()): PanelHook {
  const radios = new Map<string, RadioState>()
  const forms = new Map<string, FormState>()
  function form(id: string): FormState {
    let f = forms.get(id)
    if (!f) {
      if (forms.size >= 64) forms.delete(forms.keys().next().value!)
      f = {
        strings: { call: "", band: "20m", mode: "CW", antenna: "vertical", status: "Nothing spotted yet" },
        values: { power: 100, qrp: 0, cluster: 1, cwOnly: 0, spotted: 0 },
      }
      forms.set(id, f)
    }
    return f
  }
  function state(id: string): RadioState {
    let s = radios.get(id)
    if (!s) {
      // Bounded session-only simulator state; no storage or CAT commands.
      if (radios.size >= 64) radios.delete(radios.keys().next().value!)
      s = { requested: 14074, reported: 14074, connected: 1, due: 0, slow: 1 }
      radios.set(id, s)
    }
    if (s.connected && s.due && now() >= s.due) {
      s.reported = s.requested
      s.due = 0
    }
    return s
  }
  return {
    async getPanels() {
      return [
        { key: "radio", title: "Radio Front Face · Simulation", icon: "radio-tower", multiple: true, on: ["tick:1"] },
        { key: "weather", title: "Weather Chart · Simulation", icon: "weather-partly-cloudy", multiple: true },
        { key: "controls", title: "Native Controls · Simulation", icon: "form-textbox", multiple: true },
      ]
    },
    async render(args): Promise<PanelContent> {
      if (args.panelKey === "controls") return { kind: "scene", scene: controlsScene(form(args.instanceId ?? args.panelKey)) }
      if (args.panelKey === "weather") {
        const temperatures = [17, 18, 21, 24, 25, 23, 20, 18]
        const points = temperatures.map((t, i) => `${60 + i * 74},${265 - (t - 15) * 14}`).join(" ")
        return {
          kind: "scene",
          scene: {
            version: 1,
            width: 640,
            height: 360,
            values: { hour: 0 },
            layers: [
              {
                id: "chart",
                x: 0,
                y: 0,
                width: 640,
                height: 360,
                svg: svg(`
              <rect width="640" height="360" rx="18" fill="#142337"/>
              ${label(30, 38, "FORECAST / SIMULATED DATA", 18, "#e7edf4")}
              ${[15, 20, 25].map((t) => `<path d="M60 ${265 - (t - 15) * 14}H580" stroke="#31445b"/>${label(20, 270 - (t - 15) * 14, String(t), 12)}`).join("")}
              <polyline points="${points}" fill="none" stroke="#8bdccc" stroke-width="4"/>
              ${temperatures.map((t, i) => `<circle cx="${60 + i * 74}" cy="${265 - (t - 15) * 14}" r="5" fill="#e7edf4"/>${label(52 + i * 74, 288, "+" + i + "h", 12)}`).join("")}
              ${label(30, 334, "Drag the chart to inspect · Arrow keys to step", 14)}
            `),
              },
              {
                id: "cursor",
                x: 59,
                y: 100,
                width: 2,
                height: 172,
                svg: svg('<rect width="2" height="172" fill="#f7c576"/>', 2, 172),
                translateX: bind("hour", [0, 7], [0, 518]),
              },
              textLayer("hour", "hour", 30, 52, 250, 24, "In ", " hours"),
              {
                ...textLayer("temperature", "hour", 370, 52, 240, 24, "", " °C"),
                text: { value: "hour", samples: temperatures, suffix: " °C", size: 24, color: "#a9efcf" },
              },
            ],
            controls: [
              { id: "inspect", kind: "slider", label: "Forecast hour", x: 60, y: 100, width: 518, height: 185, value: "hour", min: 0, max: 7, step: 1 },
            ],
          },
        }
      }
      const s = state(args.instanceId ?? args.panelKey)
      return {
        kind: "scene",
        scene: {
          version: 1,
          width: 640,
          height: 360,
          values: { requested: s.requested, reported: s.reported, connected: s.connected, slow: s.slow },
          layers: [
            {
              id: "face",
              x: 0,
              y: 0,
              width: 640,
              height: 360,
              svg: svg(`
            <rect width="640" height="360" rx="18" fill="#142337"/>
            ${label(28, 35, "RADIO FRONT FACE / SIMULATED CAT", 18, "#e7edf4")}
            <rect x="28" y="58" width="350" height="114" rx="12" fill="#0a1622"/>
            ${label(42, 78, "REPORTED VFO", 12)}${label(42, 143, "REQUESTED", 12)}
            <path d="M417 150 A90 90 0 0 1 597 150" fill="none" stroke="#52657d" stroke-width="5"/>
            ${label(423, 170, "14.0", 12)}${label(565, 170, "14.35", 12)}
            ${label(424, 197, "VFO POSITION", 12)}
            <path d="M42 236 H332" stroke="#52657d" stroke-width="6"/>
            ${label(42, 268, "Band position / kHz", 14)}
            ${label(548, 256, "LINK", 12)}
            ${button(28, "Connect / disconnect")}${button(234, "External tune +5 kHz")}${button(440, "Toggle 2 s / 0 s delay")}
          `),
            },
            textLayer("reported", "reported", 42, 78, 320, 34, "", " kHz", 1),
            textLayer("requested", "requested", 168, 121, 210, 22, "", "", 1),
            {
              id: "needle",
              x: 503,
              y: 72,
              width: 8,
              height: 80,
              pivot: [0.5, 1],
              transitionMs: 450,
              svg: svg('<path d="M4 0 L7 80 H1 Z" fill="#f6c673"/>', 8, 80),
              rotation: bind("reported", [14000, 14350], [-80, 80]),
            },
            {
              id: "knob",
              x: 400,
              y: 204,
              width: 72,
              height: 72,
              svg: svg(
                '<circle cx="36" cy="36" r="34" fill="#31455d" stroke="#7187a0" stroke-width="2"/><path d="M36 8V22" stroke="#f6c673" stroke-width="4"/>',
                72,
                72,
              ),
              rotation: bind("requested", [14000, 14350], [-150, 150]),
            },
            {
              id: "handle",
              x: 36,
              y: 224,
              width: 12,
              height: 24,
              svg: svg('<rect width="12" height="24" rx="4" fill="#a9efcf"/>', 12, 24),
              translateX: bind("requested", [14000, 14350], [0, 290]),
            },
            {
              id: "led",
              x: 548,
              y: 208,
              width: 40,
              height: 40,
              svg: svg(
                '<defs><radialGradient id="glow"><stop stop-color="#a9ffbd"/><stop offset="0.3" stop-color="#58e8a2"/><stop offset="1" stop-color="#58e8a2" stop-opacity="0"/></radialGradient></defs><circle cx="20" cy="20" r="20" fill="url(#glow)"/>',
                40,
                40,
              ),
              opacity: bind("connected", [0, 1], [0.08, 1]),
              pulse: { periodMs: 1700, minOpacity: 0.55, flicker: true },
            },
          ],
          controls: [
            {
              id: "tune",
              label: "Tuning knob, kHz",
              kind: "knob",
              x: 398,
              y: 202,
              width: 76,
              height: 76,
              value: "requested",
              min: 14000,
              max: 14350,
              step: 0.1,
              sensitivity: 0.1,
              event: "tune",
            },
            {
              id: "band",
              label: "Band position, kHz",
              kind: "slider",
              x: 42,
              y: 215,
              width: 290,
              height: 42,
              value: "requested",
              min: 14000,
              max: 14350,
              step: 0.1,
              event: "tune",
            },
            ...(["connect", "external", "delay"] as const).map((event, i) => ({
              id: event,
              label: ["Toggle connection", "Simulate external tuning", "Toggle CAT delay"][i],
              kind: "button" as const,
              x: 28 + i * 206,
              y: 298,
              width: 172,
              height: 38,
              event,
            })),
          ],
        },
      }
    },
    async onEvent(args) {
      const event = args.event
      if (args.panelKey === "controls") {
        const f = form(args.instanceId ?? args.panelKey)
        if (event.text !== undefined) f.strings[event.controlId] = event.text
        if (event.value !== undefined) f.values[event.controlId] = event.value
        if (event.action === "spot") {
          const call = f.strings.call.trim().toUpperCase()
          if (!call) throw new Error("No callsign to spot")
          f.strings.call = call
          f.values.spotted = 1
          f.strings.status = `Spotted ${call} on ${f.strings.band} ${f.strings.mode}, ${f.values.qrp ? 5 : f.values.power} W`
        }
        if (event.action === "clear") {
          f.values.spotted = 0
          f.strings.status = "Nothing spotted yet"
        }
        return { values: f.values, strings: f.strings }
      }
      const s = state(args.instanceId ?? args.panelKey)
      if (event.action === "connect") {
        s.connected = 1 - s.connected
        s.due = 0
        s.requested = s.reported
      }
      if (event.action === "delay") s.slow = 1 - s.slow
      if (event.action === "external") {
        if (!s.connected) throw new Error("Radio disconnected")
        s.reported = s.reported + 5 > 14350 ? 14000 : s.reported + 5
        s.requested = s.reported
        s.due = 0
      }
      if (event.action === "tune") {
        if (!s.connected) throw new Error("Radio disconnected")
        if (typeof event.value !== "number" || !Number.isFinite(event.value)) throw new Error("Invalid frequency")
        s.requested = Math.max(14000, Math.min(14350, event.value))
        s.due = now() + (s.slow ? 2000 : 0)
        if (!s.slow) {
          s.reported = s.requested
          s.due = 0
        }
      }
      return { values: { requested: s.requested, reported: s.reported, connected: s.connected, slow: s.slow } }
    },
  }
}

/**
 * Every native control kind, placed by a layout around a strip of artwork. Clear sits
 * over the strip instead: ordered among its layers, under a click-through sheen, and
 * faded out until there is something to clear.
 */
function controlsScene(f: FormState): PanelScene {
  return {
    version: 1,
    width: 640,
    height: 60,
    values: f.values,
    strings: f.strings,
    layers: [
      { id: "strip", x: 0, y: 0, width: 640, height: 60, svg: svg('<rect width="640" height="60" rx="10" fill="#142337"/>', 640, 60) },
      { id: "status", x: 16, y: 16, width: 490, height: 28, text: { value: "status", size: 16, color: "#a9efcf" } },
      {
        id: "sheen",
        x: 0,
        y: 0,
        width: 640,
        height: 30,
        svg: svg('<rect width="640" height="30" rx="10" fill="#ffffff" fill-opacity="0.08"/>', 640, 30),
      },
    ],
    controls: [
      { id: "call", kind: "nativeTextField", label: "Callsign", placeholder: "W1AW", value: "call", event: "set" },
      {
        id: "band",
        kind: "nativeDropdown",
        label: "Band",
        value: "band",
        event: "set",
        options: ["40m", "20m", "15m", "10m"].map((b) => ({ label: b, value: b })),
      },
      { id: "mode", kind: "nativeSegmented", label: "Mode", value: "mode", event: "set", options: ["CW", "SSB", "FT8"].map((m) => ({ label: m, value: m })) },
      { id: "spot", kind: "nativeButton", label: "Spot", icon: "bullhorn", event: "spot" },
      {
        id: "clear",
        kind: "nativeButton",
        label: "Clear",
        variant: "outlined",
        event: "clear",
        after: "status",
        x: 520,
        y: 10,
        width: 110,
        height: 40,
        opacity: { value: "spotted", input: [0, 1], output: [0, 1] },
      },
      { id: "power", kind: "nativeSlider", label: "Power, watts", value: "power", event: "set", min: 5, max: 100, step: 5, disabled: f.values.qrp === 1 },
      { id: "qrp", kind: "nativeSwitch", label: "QRP", value: "qrp", event: "set" },
      { id: "cluster", kind: "nativeCheckbox", label: "Send to cluster", value: "cluster", event: "set" },
      {
        id: "antenna",
        kind: "nativeRadio",
        label: "Antenna",
        value: "antenna",
        event: "set",
        options: [
          { label: "Vertical", value: "vertical" },
          { label: "Dipole", value: "dipole" },
        ],
      },
      { id: "cw", kind: "nativeChip", label: "CW only", value: "cwOnly", icon: "filter" },
      { id: "powerText", kind: "nativeText", label: "Power", value: "power", style: "mono", align: "end" },
    ],
    layout: {
      column: [
        { row: [{ control: "call", flex: 1 }, { control: "band", width: 110 }, { control: "mode" }], spacing: 8 },
        { scene: true, flex: 1 },
        {
          wrap: [{ control: "qrp" }, { control: "cluster" }, { control: "antenna" }, { control: "cw" }],
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: "center",
        },
        { row: [{ control: "power", flex: 1 }, { control: "powerText", width: 48 }, { control: "spot" }], spacing: 8 },
      ],
      padding: 12,
      spacing: 8,
      crossAxisAlignment: "stretch",
    },
  }
}
