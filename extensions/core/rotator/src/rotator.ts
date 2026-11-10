// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The app's own Rotator panel: one rotator on a `rotatorMap` control, which
// the app draws and turns natively — a click on the map, a drag of the
// heading, a click on the station in the call field — so this panel only
// takes its settings from the pane's form and lays the map out.
import { gridToLocation } from "@ham2k/lib-geo-tools"
import type {
  FormHeader,
  FormRowElement,
  JSONValue,
  PanelContent,
  PanelHook,
  PanelSceneControl,
  PanelSceneEventResult,
  PanelSceneLayer,
  PanelSceneRotatorLayer,
  SettingsField,
  StationEquipment,
} from "@ham2k/extension-sdk"

/** The host calls this panel makes, handed in so a test can stand in for them. */
export interface RotatorHost {
  listEquipment(): Promise<StationEquipment[]>
  setEquipmentConnection(args: { id: string; connected: boolean }): Promise<unknown>
  stopRotator(args: { id: string }): Promise<unknown>
  kvGet(key: string): Promise<JSONValue | null>
  kvSet(key: string, value: JSONValue): Promise<void>
}

export interface Settings {
  /** A rotator's id; absent, the station's first. */
  rotator?: string
  /** The bearings a switched array points at; absent, a beam that turns to any. */
  directions?: number[]
  /** A short name for the main rotator, shown on its heading; absent, none. */
  label?: string
  /** The main rotator's colour, `#RRGGBB`. */
  color: string
  /** More rotators on the same map, each with its own colour and short name. */
  more: { id: string; label: string; color: string; beamWidth: number }[]
  /** The main rotator's beam, in degrees. */
  beamWidth: number
  /** Where the map centres; absent, the operation's location. Null: named, but unreadable. */
  home?: { lat: number; lon: number } | null
  grayline: boolean
  /** Whether the station in the call field is marked on the map, and clicked to aim at it. */
  callMarker: boolean
  palette: "color" | "gray" | "muted" | "contrast" | "teal"
}

const numberIn = (value: JSONValue | undefined): number | undefined => {
  const n = typeof value === "number" ? value : typeof value === "string" && value.trim() !== "" ? Number(value) : NaN
  return Number.isFinite(n) ? n : undefined
}

/** A grid square, or a `lat, lon` pair, as the Weather pane reads one; null where it names neither. */
export function placeFrom(text: string): { lat: number; lon: number } | null {
  const pair = text.match(/^\s*(-?\d+(?:\.\d+)?)\s*[,\s]\s*(-?\d+(?:\.\d+)?)\s*$/)
  if (pair) {
    const [lat, lon] = [Number(pair[1]), Number(pair[2])]
    return Math.abs(lat) <= 90 && Math.abs(lon) <= 180 ? { lat, lon } : null
  }
  if (/^[A-R]{2}(\d{2}([A-X]{2}(\d{2})?)?)?$/i.test(text.trim())) {
    const [lat, lon] = gridToLocation(text.trim())
    return { lat, lon }
  }
  return null
}

/** The colours a rotator can be drawn in: each stands off the sea and land of every theme, cased in white. */
export const rotatorColors: Record<string, { label: string; hex: string }> = {
  black: { label: "Black", hex: "#101010" },
  red: { label: "Red", hex: "#D32F2F" },
  magenta: { label: "Magenta", hex: "#C2185B" },
  purple: { label: "Purple", hex: "#7B1FA2" },
  blue: { label: "Blue", hex: "#1565C0" },
  teal: { label: "Teal", hex: "#00796B" },
  green: { label: "Green", hex: "#2E7D32" },
  orange: { label: "Orange", hex: "#EF6C00" },
  brown: { label: "Brown", hex: "#6D4C41" },
}

/** Each rotator's colour until one is picked, in the order the station lists them: apart from each other. */
const firstColors = ["black", "magenta", "green", "blue", "orange", "purple", "teal", "brown", "red"]

/** The [index]th rotator's colour: the one picked, else its first. */
const colorOf = (value: JSONValue | undefined, index: number) =>
  rotatorColors[typeof value === "string" ? value : ""]?.hex ?? rotatorColors[firstColors[index % firstColors.length]].hex

/** The [index]th rotator's label until one is typed: A, B, C… */
const letterOf = (index: number) => String.fromCharCode(65 + (index % 26))

/** The `rotator` setting naming every rotator on one map, each set on its own row. */
const multiple = "multiple"

/** The switched arrays the panel knows, by the bearings each can point at. */
export const antennas: Record<string, { label: string; directions?: number[]; beamWidth: number }> = {
  beam: { label: "Rotatable beam", beamWidth: 30 },
  "4sq-diagonal": { label: "4-square (NE, SE, SW, NW)", directions: [45, 135, 225, 315], beamWidth: 90 },
  "4sq-cardinal": { label: "4-square (N, E, S, W)", directions: [0, 90, 180, 270], beamWidth: 90 },
  "8-direction": { label: "8-direction array", directions: [0, 45, 90, 135, 180, 225, 270, 315], beamWidth: 60 },
}

/**
 * The pane's settings, from its form. [available] are the station's rotators, in their order:
 * what a rotator left unpicked defaults to, and what Multiple rotators lists.
 */
export function settingsFrom(config: Record<string, JSONValue>, available: { id: string; beamWidth?: number }[] = []): Settings {
  const location = typeof config.location === "string" ? config.location.trim() : ""
  const antennaKey = typeof config.antenna === "string" && antennas[config.antenna] ? config.antenna : "beam"
  const antenna = antennas[antennaKey]
  const word = (value: JSONValue | undefined) => (typeof value === "string" ? value.trim().slice(0, 3) : "")
  const picked = typeof config.rotator === "string" && config.rotator !== "" ? config.rotator : available[0]?.id
  // A width typed for the type, else the antenna's own where its device reports one — a
  // directional switch's lobe — else the type's.
  const typed = numberIn(config[`beamWidth.${antennaKey}`])
  const beamOf = (id: string | undefined) => Math.min(360, Math.max(0, typed ?? available.find((r) => r.id === id)?.beamWidth ?? antenna.beamWidth))
  // Multiple: each rotator switched on in its row, the first of them the map's own and the one a click turns.
  const shown =
    picked === multiple
      ? available.flatMap(({ id }, i) =>
          config[`use:${id}`] === false || config[`use:${id}`] === "false"
            ? []
            : [{ id, label: word(config[`label:${id}`]) || letterOf(i), color: colorOf(config[`color:${id}`], i), beamWidth: beamOf(id) }],
        )
      : undefined
  const [first, ...more] = shown ?? []
  return {
    ...(shown ? (first ? { rotator: first.id, label: first.label } : {}) : picked ? { rotator: picked } : {}),
    color: shown ? (first?.color ?? colorOf(undefined, 0)) : colorOf(config.color, 0),
    more,
    ...(antenna.directions ? { directions: antenna.directions } : {}),
    // A width left blank is the type's own: a 4-square's lobe is far wider than a Yagi's.
    beamWidth: beamOf(shown ? first?.id : picked),
    home: location === "" ? undefined : placeFrom(location),
    grayline: config.grayline !== false && config.grayline !== "false",
    callMarker: config.callMarker !== false && config.callMarker !== "false",
    palette: ["gray", "muted", "contrast", "teal"].includes(config.theme as string) ? (config.theme as Settings["palette"]) : "color",
  }
}

const colorOptions = Object.entries(rotatorColors).map(([value, c]) => ({ value, label: c.label }))

/**
 * The pane's form. Each row shows what it is set to, never an explanation: a select its choice, a
 * text its value. The rotators are the station's own, the first picked until another is; with
 * more than one, Multiple rotators sets each on a line of its own.
 */
function form(rotators: StationEquipment[]): (SettingsField | FormHeader | FormRowElement)[] {
  const named = rotators.map((r) => ({ id: r.id, name: r.name || r.id }))
  const ids = named.map((r) => r.id)
  return [
    {
      type: "field",
      fieldType: "select",
      key: "rotator",
      label: "Rotator",
      value: ids[0] ?? "",
      options: [...named.map((r) => ({ value: r.id, label: r.name })), ...(named.length > 1 ? [{ value: multiple, label: "Multiple rotators" }] : [])],
    },
    {
      type: "field",
      fieldType: "select",
      key: "color",
      label: "Color",
      value: firstColors[0],
      options: colorOptions,
      visibleWhen: { field: "rotator", equals: ids },
    },
    ...(named.length > 1
      ? named.map((r, i): FormRowElement => ({
          type: "row",
          label: r.name,
          visibleWhen: { field: "rotator", equals: multiple },
          elements: [
            { type: "field", fieldType: "checkbox", key: `use:${r.id}`, label: `Show ${r.name}`, value: true, flex: 0 },
            { type: "field", fieldType: "text", key: `label:${r.id}`, label: "Label", value: letterOf(i), flex: 1 },
            {
              type: "field",
              fieldType: "select",
              key: `color:${r.id}`,
              label: "Color",
              value: firstColors[i % firstColors.length],
              options: colorOptions,
              flex: 2,
            },
          ],
        }))
      : []),
    {
      type: "field",
      fieldType: "select",
      key: "antenna",
      label: "Rotator Type",
      value: "beam",
      options: Object.entries(antennas).map(([value, a]) => ({ value, label: a.label })),
    },
    // One per type, each saying the type's own width while blank: a width is the antenna's, kept
    // apart for each, so switching the type does not carry a Yagi's 30° onto a 4-square.
    ...Object.entries(antennas).map(([key, a]): SettingsField => ({
      type: "field",
      fieldType: "number",
      key: `beamWidth.${key}`,
      label: "Beam width",
      placeholder: `${a.beamWidth} degrees (Default for type)`,
      valueFormat: "${value} degrees (Manually specified)",
      visibleWhen: { field: "antenna", equals: key },
    })),
    { type: "field", fieldType: "text", key: "location", label: "Location", value: "", placeholder: "The operation's location" },
    {
      type: "field",
      fieldType: "select",
      key: "theme",
      label: "Theme",
      value: "color",
      options: [
        { value: "color", label: "Color" },
        { value: "gray", label: "Gray" },
        { value: "muted", label: "Muted" },
        { value: "contrast", label: "High contrast" },
        { value: "teal", label: "Teal" },
      ],
    },
    { type: "field", fieldType: "checkbox", key: "grayline", label: "Show the grayline", value: true },
    { type: "field", fieldType: "checkbox", key: "callMarker", label: "Show the station being logged", value: true },
  ]
}

/** What the operator left the view at: the zoom, and where the station was panned to. */
export interface View {
  zoom?: number
  x?: number
  y?: number
}

/**
 * The pane's background under each palette, light and dark: the map's own, so the panel reads as
 * one surface around the square the map is drawn in.
 */
const backgrounds: Record<Settings["palette"], { light: string; dark: string }> = {
  color: { light: "#E4EEF5", dark: "#1B2833" },
  gray: { light: "#F0F0F0", dark: "#262626" },
  muted: { light: "#EDE8DE", dark: "#2A2722" },
  contrast: { light: "#F4EBD0", dark: "#10233F" },
  // KI2D's panels' Teal face, the same in both app themes.
  teal: { light: "#A9C4CB", dark: "#A9C4CB" },
}

const svgRect = (width: number, height: number, fill: string) =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${height}"><rect width="${width}" height="${height}" fill="${fill}"/></svg>`

/**
 * The scene: the whole pane in the map's background, the map in the square as large as the pane's
 * shorter side, centred, and the panel's own readout and buttons at the pane's corners, beside the
 * square where there is room. The map writes the rotator's heading, target and state into the
 * scene, so the readout and the buttons follow the rotator with no render.
 */
export function sceneFor(settings: Settings, size: { width: number; height: number }, view: View = {}, dark = false): PanelContent {
  const { width, height } = size
  const side = Math.min(width, height)
  const background = backgrounds[settings.palette][dark ? "dark" : "light"]
  // Teal is a light face whatever the app's theme, with black ink.
  const ink = dark && settings.palette !== "teal" ? "#E6E6E6" : "#1A1A1A"
  const fill = { id: "background", x: 0, y: 0, width, height, svg: svgRect(width, height, background) }
  if (settings.home === null) {
    return {
      kind: "scene",
      scene: {
        version: 1,
        width,
        height,
        values: {},
        layers: [
          fill,
          {
            id: "unreadable",
            x: 12,
            y: 12,
            width: Math.max(1, width - 24),
            height: Math.max(1, height - 24),
            text: {
              literal: "Can't read the location in this panel's settings. Use a grid square, or a latitude and longitude like 40.7, -74.0.",
              size: 14,
              align: "center",
              color: ink,
            },
          },
        ],
      },
    }
  }
  const map: PanelSceneControl = {
    id: "map",
    kind: "rotatorMap",
    label: "Rotator",
    x: (width - side) / 2,
    y: (height - side) / 2,
    width: side,
    height: side,
    event: "view",
    // Right over the pane's fill, so the readouts drawn after it lie over the map's corners.
    after: "background",
    ...(settings.rotator ? { rotator: settings.rotator } : {}),
    ...(settings.home ? { home: settings.home } : {}),
    beamWidth: settings.beamWidth,
    ...(settings.directions ? { stops: settings.directions } : {}),
    // Always the panel's own, so a rotator is in the colour its settings pick.
    decorations: decorationsFor(settings),
    map: { palette: settings.palette, grayline: settings.grayline, background },
    zoom: { min: 1, initial: "zoom" },
    pan: { x: "panX", y: "panY" },
    headingDeg: "heading",
    targetDeg: "target",
    zoomValue: "zoomNow",
    status: "status",
    ...(settings.more.length
      ? { rotators: settings.more.map((r, i) => ({ rotator: r.id, headingDeg: `heading${i + 2}`, targetDeg: `target${i + 2}`, status: `status${i + 2}` })) }
      : {}),
    // This panel draws its own, at the pane's corners rather than the square's.
    hud: false,
    actions: false,
  }
  const live = { value: "status", in: ["connected", "turning"] }
  // A rotator not answering keeps its last bearing, greyed: where it was, not where it is.
  const idle = dark && settings.palette !== "teal" ? "#7A7A7A" : "#8C8C8C"
  const several = settings.more.length > 0
  const text = (size: number, color: string, weight = 700) => ({ size, color, fontWeight: weight, fontFamily: "RobotoMono" })
  const button = (id: string, label: string, icon: string, event: string, x: number, y: number, when: PanelSceneControl["when"]): PanelSceneControl => ({
    id,
    kind: "nativeButton",
    label,
    icon,
    event,
    variant: "icon",
    x,
    y,
    width: 48,
    height: 48,
    when,
  })
  return {
    kind: "scene",
    scene: {
      version: 1,
      width,
      height,
      values: {
        zoom: view.zoom ?? 1,
        panX: view.x ?? 0,
        panY: view.y ?? 0,
        heading: 0,
        target: 0,
        zoomNow: 1,
        ...Object.fromEntries(
          settings.more.flatMap((_, i) => [
            [`heading${i + 2}`, 0],
            [`target${i + 2}`, 0],
          ]),
        ),
      },
      strings: { status: "none", ...Object.fromEntries(settings.more.map((_, i) => [`status${i + 2}`, "none"])) },
      layers: [
        fill,
        // One rotator: its heading large at the top left. Several: each one's, in its colour, down the top left.
        ...(several
          ? bearings(settings, text, idle, background)
          : [
              { id: "heading", x: 12, y: 8, width: 120, height: 28, text: { value: "heading", suffix: "°", ...text(22, ink) }, when: live },
              {
                id: "heading-idle",
                x: 12,
                y: 8,
                width: 120,
                height: 28,
                text: { value: "heading", suffix: "°", ...text(22, idle) },
                when: { ...live, not: true },
              },
              {
                id: "target",
                x: 12,
                y: 36,
                width: 120,
                height: 24,
                text: { value: "target", prefix: "➜ ", suffix: "°", ...text(18, "#FF4400") },
                when: { value: "status", is: "turning" },
              },
            ]),
      ],
      controls: [
        map,
        button("connect", "Connect", "power-plug-off", "connect", width - 52, 4, { value: "status", in: ["disconnected", "error"] }),
        button("disconnect", "Disconnect", "power-plug", "disconnect", width - 52, 4, { value: "status", in: ["connected", "turning", "stale"] }),
        // Under the bearings, by what it stops.
        button("stop", "Stop", "stop-circle-outline", "stop", 4, several ? 8 + (settings.more.length + 1) * 26 + 2 : 62, { value: "status", is: "turning" }),
        button("reset", "Whole map", "fit-to-screen-outline", "resetView", width - 52, height - 52, { value: "zoomNow", min: 1.01 }),
      ],
    },
  }
}

/**
 * A switched array's map: each direction's sector, outlined and clicked to switch to it, under the
 * app's own beam and heading.
 */
export function arrayDecorations(directions: number[]): PanelSceneRotatorLayer[] {
  const half = 180 / directions.length
  return [
    ...directions.map((d): PanelSceneRotatorLayer => ({
      id: `sector-${d}`,
      kind: "wedge",
      az: `az:${d}-${half}deg`,
      az2: `az:${d}+${half}deg`,
      color: "#59FFFFFF",
      width: 1,
      dashed: true,
      aim: true,
    })),
    { id: "defaults", kind: "defaults" },
  ]
}

type TextStyle = (size: number, color: string, weight?: number) => Record<string, unknown>

/**
 * Each rotator's bearing, a line apiece down the top left corner in its own colour, and where it
 * is turning to while it turns: "B 120° ➜ 200°".
 */
function bearings(settings: Settings, text: TextStyle, idle: string, background: string): PanelSceneLayer[] {
  const rows = [
    { n: 1, label: settings.label ?? "1", color: settings.color, heading: "heading", target: "target", status: "status" },
    ...settings.more.map((r, i) => ({
      n: i + 2,
      label: r.label,
      color: r.color,
      heading: `heading${i + 2}`,
      target: `target${i + 2}`,
      status: `status${i + 2}`,
    })),
  ]
  return rows.flatMap(({ n, label, color, heading, target, status }, row): PanelSceneLayer[] => {
    const y = 8 + row * 26
    // Just past the bearing at its widest — the label, a space and three digits and a degree sign,
    // in the mono face at 18, a little under 11 pixels a character — so it reads as the same line.
    const bearingWidth = Math.round((label.length + 5) * 10.8)
    const aimX = 12 + bearingWidth + 6
    // Over the pane's own colour, a little see-through, so each holds up where it crosses the map.
    const back = (id: string, x: number, width: number, when?: PanelSceneLayer["when"]): PanelSceneLayer =>
      ({
        id,
        x,
        y: y + 1,
        width,
        height: 23,
        svg: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} 23"><rect width="${width}" height="23" rx="4" fill="${background}" fill-opacity="0.85"/></svg>`,
        ...(when ? { when } : {}),
      }) as PanelSceneLayer
    return [
      back(`bearing-back-${n}`, 8, bearingWidth + 8),
      {
        id: `bearing-${n}`,
        x: 12,
        y,
        width: 96,
        height: 24,
        text: { value: heading, prefix: `${label} `, suffix: "°", align: "start", ...text(18, color) },
        when: { value: status, in: ["connected", "turning"] },
      } as PanelSceneLayer,
      {
        id: `bearing-idle-${n}`,
        x: 12,
        y,
        width: 96,
        height: 24,
        text: { value: heading, prefix: `${label} `, suffix: "°", align: "start", ...text(18, idle) },
        when: { value: status, in: ["connected", "turning"], not: true },
      } as PanelSceneLayer,
      back(`aim-back-${n}`, aimX - 4, 78, { value: status, is: "turning" }),
      {
        id: `aim-${n}`,
        x: aimX,
        y: y + 2,
        width: 74,
        height: 22,
        text: { value: target, prefix: "➜ ", suffix: "°", align: "start", ...text(15, color, 400) },
        when: { value: status, is: "turning" },
      } as PanelSceneLayer,
    ]
  })
}

/** `#RRGGBB` mixed [share] of the way to white: a lighter colour, still opaque. */
const lighter = (color: string, share: number) =>
  `#${[1, 3, 5]
    .map((i) =>
      Math.round(parseInt(color.slice(i, i + 2), 16) + (255 - parseInt(color.slice(i, i + 2), 16)) * share)
        .toString(16)
        .padStart(2, "0"),
    )
    .join("")
    .toUpperCase()}`

/** `#RRGGBB` at [alpha] (0–255), as `#AARRGGBB`. */
const faded = (color: string, alpha: number) => `#${alpha.toString(16).padStart(2, "0").toUpperCase()}${color.slice(1)}`

/**
 * One rotator, in its colour: a light beam; the heading, solid where it points, paler while it
 * turns, dragged to turn it; and the target, dashed, while it turns. Its name and bearing are in the
 * corner readout rather than on the arrow.
 * The control's own rotator is the one with no [rotator].
 */
function rotatorDecorations(n: number, color: string, beamWidth: number, rotator?: string): PanelSceneRotatorLayer[] {
  const half = beamWidth / 2
  const whose = rotator ? { rotator } : {}
  return [
    ...(beamWidth > 0
      ? [
          {
            id: `beam-${n}`,
            kind: "wedge",
            ...whose,
            az: `heading-${half}deg`,
            az2: `heading+${half}deg`,
            // Enough to read the beam over sea and land alike, with an edge to say where it ends.
            fill: faded(color, 0x50),
            color: faded(color, 0xcc),
            casing: "#B3FFFFFF",
            width: 1.5,
          } as PanelSceneRotatorLayer,
        ]
      : []),
    {
      id: `target-${n}`,
      kind: "line",
      ...whose,
      from: { r: 0 },
      to: { az: "target", r: "rim" },
      color,
      // Dashes thin enough to tell from the heading, cased so they hold up over the map.
      casing: "#FFFFFF",
      dashed: true,
      width: 2.5,
      head: { width: 12, length: 12 },
      clip: false,
    },
    {
      id: `heading-${n}`,
      kind: "line",
      ...whose,
      from: { r: 0 },
      to: { az: "heading", r: "rim" },
      color,
      // Where it was, paler, while the dashed target says where it is going. Opaque, so the head,
      // filled over the map, matches the shaft drawn over its casing.
      turningColor: lighter(color, 0.5),
      casing: "#FFFFFF",
      width: 4.5,
      head: { width: 16, length: 16 },
      drag: "turn",
      clip: false,
    },
  ]
}

/**
 * The map's decorations: a switched array's sectors, each rotator in its own colour, and, unless
 * the pane turns it off, the station in the call field, clicked to aim the main rotator at it.
 */
export function decorationsFor(settings: Settings): PanelSceneRotatorLayer[] {
  const rotators = [
    ...rotatorDecorations(1, settings.color, settings.beamWidth),
    ...settings.more.flatMap((r, i) => rotatorDecorations(i + 2, r.color, r.beamWidth, r.id)),
  ]
  return [
    ...(settings.directions ? arrayDecorations(settings.directions).filter((d) => d.kind !== "defaults") : []),
    // Every beam before any arrow, so one rotator's beam never covers another's arrow; the station
    // being logged last, over them all.
    ...rotators.filter((d) => d.kind === "wedge"),
    ...rotators.filter((d) => d.kind !== "wedge"),
    ...(settings.callMarker
      ? [{ id: "call", kind: "circle", at: { place: "call" }, radius: 5, fill: "#FF0000", color: "#FFFFFF", width: 1.5, aim: true } as const]
      : []),
  ]
}

/** What the operator's zoom or pan, reported once it ends, leaves [view] at. */
export function viewAfter(view: View, gesture: string | undefined, value: number | undefined, at: Record<string, unknown> | undefined): View {
  if (gesture === "zoom" && typeof value === "number" && Number.isFinite(value)) {
    // 0 is the map's own reset: the whole map, unpanned.
    return value > 0 ? { ...view, zoom: value } : {}
  }
  if (gesture === "pan" && typeof at?.x === "number" && typeof at?.y === "number") return { ...view, x: at.x, y: at.y }
  return view
}

export function createRotatorPanel(host: RotatorHost): PanelHook {
  const rotators = async () => (await host.listEquipment()).filter((e) => e.kind === "rotator")
  // Each placed pane's view, read once from storage and written back as it changes.
  const views = new Map<string, View>()
  const viewOf = async (instanceId: string | undefined): Promise<View> => {
    const key = instanceId ?? ""
    if (!views.has(key)) {
      const stored = await host.kvGet(`view:${key}`)
      views.set(key, stored && typeof stored === "object" && !Array.isArray(stored) ? (stored as View) : {})
    }
    return views.get(key)!
  }
  const keep = async (instanceId: string | undefined, view: View) => {
    views.set(instanceId ?? "", view)
    await host.kvSet(`view:${instanceId ?? ""}`, view as unknown as JSONValue)
  }
  return {
    async getPanels() {
      return [
        {
          key: "rotator",
          title: "Rotator",
          description: "Where the antenna points, on a map centred on the station. Click the map to turn it.",
          icon: "compass-outline",
          multiple: true,
          form: form(await rotators()),
        },
      ]
    },
    async render(args): Promise<PanelContent> {
      const size = { width: Math.max(1, args.environment?.width ?? 300), height: Math.max(1, args.environment?.height ?? 300) }
      return sceneFor(settingsFrom(args.config, await rotators()), size, await viewOf(args.instanceId), args.environment?.brightness === "dark")
    },
    async onEvent(args): Promise<PanelSceneEventResult> {
      const { action, gesture, value, at } = args.event
      const settings = settingsFrom(args.config, await rotators())
      // Every rotator the map shows: the others have no buttons of their own.
      const shown = [...(settings.rotator ? [settings.rotator] : []), ...settings.more.map((r) => r.id)]
      switch (action) {
        case "connect":
        case "disconnect":
          for (const id of shown) await host.setEquipmentConnection({ id, connected: action === "connect" })
          return { values: {} }
        case "stop":
          // Stopping one that is not turning does nothing.
          for (const id of shown) await host.stopRotator({ id })
          return { values: {} }
        case "resetView":
          await keep(args.instanceId, {})
          return { values: { zoom: 1, panX: 0, panY: 0 } }
        case "view": {
          const before = await viewOf(args.instanceId)
          const after = viewAfter(before, gesture, value, at as Record<string, unknown> | undefined)
          if (after !== before) await keep(args.instanceId, after)
          return { values: { zoom: after.zoom ?? 1, panX: after.x ?? 0, panY: after.y ?? 0 } }
        }
        default:
          return { values: {} }
      }
    },
  }
}
