// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The radio's scope as a scene: the host draws the sweeps in the `spectrum`
// control, and this extension only places it and turns the radio's knobs.
import { host } from "@ham2k/extension-sdk"
import type { PanelContent, PanelHook, PanelRadioSpectrum, PanelRadioState, PanelScene } from "@ham2k/extension-sdk"

type Display = "both" | "pan" | "waterfall"

/** A slider with its label beside it, kept together when the wrap breaks. */
const labeled = (text: string, control: string) => ({
  wrap: [{ control: `label-${text}` }, { control, width: 120 }],
  spacing: 4,
  crossAxisAlignment: "center" as const,
})

/** Where the receiver listens, from the tuned frequency, by mode. A sketch: the radio's real filter is not reported. */
function passband(mode: string | null | undefined): [number, number] | null {
  if (!mode) return null
  if (mode.includes("LSB")) return [-2800, -100]
  if (mode.includes("USB") || mode.startsWith("DATA") || mode === "FT8" || mode === "FT4") return [100, 2800]
  if (mode.startsWith("CW")) return [-250, 250]
  if (mode === "AM" || mode === "FM") return [-3000, 3000]
  return null
}

const cyan = "#2EC5F0"

/** Landmarks on 20 m: something to read, and to click to go to. */
const landmarks: [string, number, "start" | "center" | "end"][] = [
  ["PSK", 14070000, "center"],
  ["FT8", 14074000, "start"],
  ["FT4", 14080000, "center"],
  ["SSTV", 14230000, "start"],
  ["QRP", 14285000, "end"],
  ["Maritime net", 14300000, "center"],
]

const spanLabel = (hz: number) => `±${hz >= 1000 ? `${hz / 1000} kHz` : `${hz} Hz`}`

export function scene(radio: PanelRadioState | null, display: Display, step = "100"): PanelScene {
  const spectrum: PanelRadioSpectrum | null | undefined = radio?.spectrum
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
  const band = passband(radio?.mode)
  return {
    version: 1,
    width: 600,
    height: 24,
    values: { floor: 0, average: 40, fps: 15, rows: 10, hoverHz: 0, hoverDb: 0, ref },
    strings: {
      span: hasSpan && spectrum.spanHz != null && spectrum.spansHz.includes(spectrum.spanHz) ? String(spectrum.spanHz) : "",
      speed: hasSpeed && spectrum.speed != null && spectrum.speeds.includes(spectrum.speed) ? spectrum.speed : "",
      display,
      step,
    },
    layers: [
      {
        id: "readout",
        x: 0,
        y: 0,
        width: 600,
        height: 24,
        text: { value: "hoverHz", scale: 0.001, decimals: 3, suffix: " kHz", size: 14 },
      },
    ],
    controls: [
      ...(hasSpan
        ? [
            {
              id: "span",
              label: "Span",
              kind: "nativeDropdown" as const,
              value: "span",
              event: "span",
              options: spectrum.spansHz.map((hz) => ({ label: spanLabel(hz), value: String(hz) })),
            },
          ]
        : []),
      ...(hasRef
        ? [
            {
              id: "ref",
              label: "Reference level",
              kind: "nativeSlider" as const,
              value: "ref",
              event: "ref",
              min: spectrum.refMinDb,
              max: spectrum.refMaxDb,
              step: spectrum.refStepDb,
            },
          ]
        : []),
      ...(hasSpeed
        ? [
            {
              id: "speed",
              label: "Speed",
              kind: "nativeSegmented" as const,
              value: "speed",
              event: "speed",
              options: spectrum.speeds.map((s) => ({ label: s, value: s })),
            },
          ]
        : []),
      { id: "floor", label: "Contrast", kind: "nativeSlider" as const, value: "floor", min: -30, max: 30, step: 1 },
      { id: "average", label: "Averaging", kind: "nativeSlider" as const, value: "average", min: 0, max: 95, step: 5 },
      { id: "fps", label: "Panadapter FPS", kind: "nativeSlider" as const, value: "fps", min: 1, max: 30, step: 1 },
      { id: "rows", label: "Waterfall rows per second", kind: "nativeSlider" as const, value: "rows", min: 1, max: 30, step: 1 },
      // A control the layout does not place fails the scene: Ref's label goes with its slider.
      ...[...(hasRef ? ["Ref"] : []), "Contrast", "Avg", "FPS", "Rows"].map((text) => ({
        id: `label-${text}`,
        label: text,
        kind: "nativeText" as const,
      })),
      {
        id: "step",
        label: "Tuning step",
        kind: "nativeSegmented" as const,
        value: "step",
        event: "step",
        options: ["10", "100", "500", "1000"].map((hz) => ({ label: Number(hz) >= 1000 ? `${Number(hz) / 1000} kHz` : `${hz} Hz`, value: hz })),
      },
      {
        id: "display",
        label: "Display",
        kind: "nativeSegmented" as const,
        value: "display",
        event: "display",
        options: (["both", "pan", "waterfall"] as const).map((d) => ({ label: d, value: d })),
      },
      {
        id: "spectrum",
        label: "Panadapter",
        kind: "spectrum" as const,
        event: "tune",
        display,
        floor: "floor",
        average: "average",
        fps: "fps",
        waterfallSpeed: "rows",
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
        // Noise to black, as the radio's own display does: the waterfall's window sits above the panadapter's.
        waterfallFloor: 12,
        waterfallRange: 50,
        waterfallColors: ["#000000", "#00004A", "#0000FF", "#00C8FF", "#00FF60", "#FFFF00", "#FF2000"],
        center: { pan: { color: cyan, width: 4 }, waterfall: { color: cyan, width: 4 } },
        tuneStep: Number(step),
        annotations: landmarks.map(([text, hz, align]) => ({
          id: text,
          text,
          hz,
          align,
          borderColor: "#FFB020",
          pointer: { size: 5 },
          event: "goto",
          offset: 6,
          color: "#0B0E17",
          background: "#E6FFB020",
          size: 11,
          weight: 600,
        })),
        overlays: [
          ...(band ? [{ from: band[0], to: band[1], pan: { fill: "#262EC5F0", color: "#992EC5F0" } }] : []),
          // The bottom of 20 m, and what lies outside it: scenery behind the trace, over the waterfall.
          { at: 14000000, anchor: "absolute" as const, pan: { color: "#FF3030", width: 3 }, waterfall: { color: "#FF3030", width: 3 } },
          { from: 13900000, to: 14000000, anchor: "absolute" as const, pan: { fill: "#33FF3030" }, waterfall: { fill: "#33FF3030" } },
        ],
        hoverHz: "hoverHz",
        hoverDb: "hoverDb",
      },
    ],
    layout: {
      column: [
        {
          wrap: [
            ...(hasSpan ? [{ control: "span" }] : []),
            ...(hasRef ? [labeled("Ref", "ref")] : []),
            ...(hasSpeed ? [{ control: "speed" }] : []),
            labeled("Contrast", "floor"),
            labeled("Avg", "average"),
            labeled("FPS", "fps"),
            labeled("Rows", "rows"),
            { control: "step" },
            { control: "display" },
          ],
          spacing: 8,
          runSpacing: 4,
          padding: 4,
        },
        { control: "spectrum", flex: 1 },
        { scene: true, height: 24 },
      ],
      crossAxisAlignment: "stretch",
    },
  }
}

export function createPanafall(): PanelHook {
  const displays = new Map<string, Display>()
  const steps = new Map<string, string>()
  return {
    async getPanels() {
      return [{ key: "panafall", title: "Panadapter", icon: "waveform", multiple: true, on: ["tick:2"] }]
    },
    async render(args): Promise<PanelContent> {
      const id = args.instanceId ?? ""
      return { kind: "scene", scene: scene(await host.readRadio(), displays.get(id) ?? "both", steps.get(id) ?? "100") }
    },
    async onEvent(args) {
      const { action, value, text } = args.event
      if (action === "step") {
        steps.set(args.instanceId ?? "", text ?? "100")
        return { values: {} }
      }
      if (action === "display") {
        displays.set(args.instanceId ?? "", (text as Display) ?? "both")
        return { values: {} }
      }
      const radio = await host.readRadio()
      if (!radio?.id) return { values: {} }
      if ((action === "tune" || action === "goto") && typeof value === "number") {
        // Already on the step: the host snapped it.
        await host.setRadio({ id: radio.id, frequencyHz: Math.round(value) })
      } else if (action === "span" && text) {
        await host.setRadioSpectrum({ id: radio.id, spanHz: Number(text) })
      } else if (action === "ref" && typeof value === "number") {
        await host.setRadioSpectrum({ id: radio.id, refLevelDb: value })
      } else if (action === "speed" && text) {
        await host.setRadioSpectrum({ id: radio.id, speed: text as "slow" | "mid" | "fast" })
      }
      return { values: {} }
    },
  }
}
