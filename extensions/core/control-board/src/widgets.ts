// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// Each widget, drawn into its cell: layers and controls in the cell's own pixels, bound to the
// readings and vars it names. An event a control sends is `<what>:<path>`, the path the widget's
// place in the board, so the action it stands for is found in the board again.

import type { PanelEnvironment, PanelSceneControl, PanelSceneLayer, SceneBinding } from "@ham2k/extension-sdk"
import { BoardError, type BoardItem } from "./board.ts"
import type { RenderText } from "./compile.ts"

export interface Theme {
  colors: PanelEnvironment["colors"]
  face: string
  ink: string
  dim: string
  track: string
  lit: string
  active: string
  onActive: string
  warn: string
  body: TextRole
  label: TextRole
  title: TextRole
  display: TextRole
  mono: TextRole
}
interface TextRole {
  size: number
  family?: string
}

export interface WidgetContext {
  cell: string
  width: number
  height: number
  theme: Theme
  text: RenderText
  path: string
  /** The board's stamp, which every event carries: see compile.ts. */
  stamp: string
}

/** What a control sends: `<kind>:<stamp>:<path>`, and an index for a menu entry or an option. */
const sends = (ctx: WidgetContext, kind: string, index?: number) => `${kind}:${ctx.stamp}:${ctx.path}${index === undefined ? "" : `:${index}`}`

export interface WidgetCell {
  layers: PanelSceneLayer[]
  controls: Omit<PanelSceneControl, "cell">[]
  values?: Record<string, number>
  strings?: Record<string, string>
}

const svg = (width: number, height: number, body: string) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${height}">${body}</svg>`
// An item as `parseBoard` gives it: every field it has checked, every one a widget needs present.
const num = (item: BoardItem, key: string, fallback: number) => (item[key] as number | undefined) ?? fallback
const str = (item: BoardItem, key: string, fallback = "") => (item[key] === undefined ? fallback : String(item[key]))
const ref = (item: BoardItem) => item.value as string
const varRef = (item: BoardItem) => `var.${item.var as string}`

/** A color by theme role, as the theme gives it, or as written (`#RRGGBB`). */
function paint(theme: Theme, name: string | undefined, fallback: string): string {
  if (!name) return fallback
  return (theme.colors as Record<string, string>)[name] ?? name
}

function face(ctx: WidgetContext, id = "face", color = ctx.theme.face): PanelSceneLayer {
  const { width: w, height: h } = ctx
  return { id: `${ctx.cell}-${id}`, x: 0, y: 0, width: w, height: h, svg: svg(w, h, `<rect width="${w}" height="${h}" rx="6" fill="${color}"/>`) }
}

function words(
  ctx: WidgetContext,
  id: string,
  literal: string,
  at: { x: number; y: number; width: number; height: number },
  role: TextRole,
  color: string,
  align?: "start" | "center" | "end",
): PanelSceneLayer {
  return {
    id: `${ctx.cell}-${id}`,
    ...at,
    text: { literal, size: role.size, color, ...(role.family ? { fontFamily: role.family } : {}), ...(align ? { align } : {}) },
  }
}

function bound(
  ctx: WidgetContext,
  id: string,
  value: string,
  at: { x: number; y: number; width: number; height: number },
  role: TextRole,
  color: string,
  extra: Record<string, unknown> = {},
): PanelSceneLayer {
  return {
    id: `${ctx.cell}-${id}`,
    ...at,
    text: { value, size: role.size, color, ...(role.family ? { fontFamily: role.family } : {}), ...extra },
  } as PanelSceneLayer
}

function ramp(value: string, min: number, max: number, hold?: number, extra: Partial<SceneBinding> = {}): SceneBinding {
  return { value, input: [min, max], output: [0, 1], ...extra, ...(hold ? { hold: { ms: hold } } : {}) } as SceneBinding
}

/** A caption at the top of a cell, and the room left under it. */
function caption(ctx: WidgetContext, item: BoardItem): { layers: PanelSceneLayer[]; top: number } {
  if (item.label === undefined) return { layers: [], top: 0 }
  const role = ctx.theme.label
  return {
    layers: [words(ctx, "caption", ctx.text(str(item, "label")), { x: 6, y: 3, width: ctx.width - 12, height: role.size + 4 }, role, ctx.theme.dim)],
    top: role.size + 5,
  }
}

export function buildWidget(item: BoardItem, ctx: WidgetContext): WidgetCell {
  return builders[item.type](item, ctx)
}

const builders: Record<string, (item: BoardItem, ctx: WidgetContext) => WidgetCell> = {
  label(item, ctx) {
    const role = ctx.theme[(item.style as "body" | "label" | "title" | "display" | "mono") ?? "body"] ?? ctx.theme.body
    const align = (item.align as "start" | "center" | "end") ?? "start"
    return {
      layers: [
        words(
          ctx,
          "text",
          ctx.text(str(item, "text")),
          { x: 4, y: (ctx.height - role.size * 1.3) / 2, width: ctx.width - 8, height: role.size * 1.3 },
          role,
          paint(ctx.theme, item.color as string, ctx.theme.ink),
          align,
        ),
      ],
      controls: [],
    }
  },

  readout(item, ctx) {
    const top = caption(ctx, item)
    const role = ctx.theme.title
    const extra = {
      ...(item.decimals !== undefined ? { decimals: num(item, "decimals", 0) } : {}),
      ...(item.scale !== undefined ? { scale: num(item, "scale", 1) } : {}),
      prefix: ctx.text(str(item, "prefix")),
      suffix: ctx.text(str(item, "suffix")),
      align: "end",
    }
    return {
      layers: [
        face(ctx),
        ...top.layers,
        bound(
          ctx,
          "value",
          ref(item),
          { x: 6, y: top.top + (ctx.height - top.top - role.size * 1.3) / 2, width: ctx.width - 12, height: role.size * 1.3 },
          role,
          ctx.theme.ink,
          extra,
        ),
      ],
      controls: [],
    }
  },

  frequency(item, ctx) {
    // Three groups bound to one value: MHz, kHz and tens of Hz, as a radio's dial reads.
    const value = ref(item)
    const top = caption(ctx, item)
    const size = Math.min(ctx.theme.display.size, (ctx.height - top.top) * 0.7, ctx.width / 9)
    const role = { size, family: ctx.theme.mono.family }
    const digit = size * 0.62
    const y = top.top + (ctx.height - top.top - size * 1.25) / 2
    const h = size * 1.25
    const kHzX = ctx.width - 6 - digit * 6.4
    return {
      layers: [
        face(ctx),
        ...top.layers,
        bound(ctx, "mhz", value, { x: 6, y, width: kHzX - 6 - digit * 0.4, height: h }, role, ctx.theme.ink, { scale: 1e-6, truncate: true, align: "end" }),
        bound(ctx, "khz", value, { x: kHzX, y, width: digit * 3.6, height: h }, role, ctx.theme.ink, {
          scale: 1e-3,
          truncate: true,
          modulo: 1000,
          minIntegerDigits: 3,
          prefix: ".",
        }),
        bound(ctx, "hz", value, { x: kHzX + digit * 3.7, y, width: digit * 2.7, height: h }, { size: size * 0.7, family: role.family }, ctx.theme.dim, {
          scale: 0.1,
          truncate: true,
          modulo: 100,
          minIntegerDigits: 2,
          prefix: ".",
        }),
      ],
      controls: [],
    }
  },

  button(item, ctx) {
    const active = item.active as BoardItem["when"] | undefined
    const role = ctx.theme.body
    const label = ctx.text(str(item, "label"))
    const at = { x: 4, y: (ctx.height - role.size * 1.3) / 2, width: ctx.width - 8, height: role.size * 1.3 }
    return {
      layers: [
        face(ctx),
        ...(active ? [{ ...face(ctx, "on", ctx.theme.active), when: active } as PanelSceneLayer] : []),
        words(ctx, "label", label, at, role, ctx.theme.ink, "center"),
        ...(active ? [{ ...words(ctx, "label-on", label, at, role, ctx.theme.onActive, "center"), when: active } as PanelSceneLayer] : []),
      ],
      controls: [
        { id: `${ctx.cell}-press`, kind: "button", label: label || "Button", x: 0, y: 0, width: ctx.width, height: ctx.height, event: sends(ctx, "a") },
      ],
    }
  },

  toggle(item, ctx) {
    // A lamp lit while it is on: by its own var, or by a condition on a reading.
    const on = (item.on as BoardItem["when"] | undefined) ?? { value: varRef(item), is: 1 }
    const role = ctx.theme.body
    const label = ctx.text(str(item, "label"))
    const lamp = (id: string, color: string, extra: Partial<PanelSceneLayer> = {}) =>
      ({
        id: `${ctx.cell}-${id}`,
        x: ctx.width - 16,
        y: 7,
        width: 9,
        height: 9,
        svg: svg(9, 9, `<circle cx="4.5" cy="4.5" r="4.5" fill="${color}"/>`),
        ...extra,
      }) as PanelSceneLayer
    return {
      layers: [
        face(ctx),
        lamp("lamp-off", ctx.theme.track),
        lamp("lamp-on", ctx.theme.lit, { when: on }),
        words(ctx, "label", label, { x: 8, y: (ctx.height - role.size * 1.3) / 2, width: ctx.width - 28, height: role.size * 1.3 }, role, ctx.theme.ink),
      ],
      controls: [
        { id: `${ctx.cell}-press`, kind: "button", label: label || "Toggle", x: 0, y: 0, width: ctx.width, height: ctx.height, event: sends(ctx, "a") },
      ],
    }
  },

  bar(item, ctx) {
    const value = ref(item)
    const min = num(item, "min", 0)
    const max = num(item, "max", 100)
    const top = caption(ctx, item)
    const color = paint(ctx.theme, item.color as string, ctx.theme.active)
    const trackY = top.top + (ctx.height - top.top - 10) / 2
    const w = ctx.width - 12
    const adjustable = item.adjustable === true
    return {
      layers: [
        face(ctx),
        ...top.layers,
        {
          id: `${ctx.cell}-track`,
          x: 6,
          y: trackY,
          width: w,
          height: 10,
          svg: svg(w, 10, `<rect width="${w}" height="10" rx="3" fill="${ctx.theme.track}"/>`),
        },
        {
          id: `${ctx.cell}-fill`,
          x: 6,
          y: trackY,
          width: w,
          height: 10,
          pivot: [0, 0.5],
          clipX: ramp(value, min, max, item.hold === undefined ? undefined : num(item, "hold", 0)),
          svg: svg(w, 10, `<rect width="${w}" height="10" rx="3" fill="${color}"/>`),
        } as PanelSceneLayer,
      ],
      // Dragged by its own fill, its scroll the other way from a dial's: a board's adjustable bar.
      controls: adjustable
        ? [
            {
              id: `${ctx.cell}-drag`,
              kind: "slider",
              label: ctx.text(str(item, "label", "Level")),
              x: 6,
              y: 0,
              width: w,
              height: ctx.height,
              value,
              min,
              max,
              step: num(item, "step", 1),
              invertScroll: item.invertScroll !== false,
              event: sends(ctx, "c"),
            },
          ]
        : [],
    }
  },

  ledBar(item, ctx) {
    const value = ref(item)
    const min = num(item, "min", 0)
    const max = num(item, "max", 100)
    const segments = num(item, "segments", 10)
    const top = caption(ctx, item)
    const w = ctx.width - 12
    const h = Math.max(6, ctx.height - top.top - 10)
    const y = top.top + (ctx.height - top.top - h) / 2
    const seg = w / segments
    if (seg < 3) throw new BoardError(`${segments} segments in ${w} pixels leaves each under 3; give it fewer segments or a wider \`span\``)
    // Zones color the segments from a level up: [[level, color], …], the last that starts at or below.
    const zones = (Array.isArray(item.zones) ? item.zones : []) as [number, string][]
    const colorAt = (level: number) => zones.reduce((color, [from, c]) => (level >= from ? paint(ctx.theme, c, color) : color), ctx.theme.lit)
    const lit = Array.from(
      { length: segments },
      (_, i) => `<rect x="${i * seg}" width="${seg - 2}" height="${h}" rx="1.5" fill="${colorAt(min + ((i + 0.5) * (max - min)) / segments)}"/>`,
    ).join("")
    const dim = Array.from({ length: segments }, (_, i) => `<rect x="${i * seg}" width="${seg - 2}" height="${h}" rx="1.5" fill="${ctx.theme.track}"/>`).join(
      "",
    )
    const scale = segments / (max - min)
    const hold = item.hold === undefined ? undefined : num(item, "hold", 0)
    return {
      layers: [
        face(ctx),
        ...top.layers,
        { id: `${ctx.cell}-dim`, x: 6, y, width: w, height: h, svg: svg(w, h, dim) },
        {
          id: `${ctx.cell}-lit`,
          x: 6,
          y,
          width: w,
          height: h,
          pivot: [0, 0.5],
          // A segment at a time, counted from the bar's own bottom: the reading in whole segments
          // above `min`, wherever its range starts.
          clipX: ramp(value, 0, segments, hold, { offset: -min, scale, truncate: true }),
          svg: svg(w, h, lit),
        } as PanelSceneLayer,
      ],
      controls: [],
    }
  },

  needle(item, ctx) {
    const value = ref(item)
    const min = num(item, "min", 0)
    const max = num(item, "max", 100)
    const top = caption(ctx, item)
    const w = ctx.width
    const h = ctx.height - top.top
    const cx = w / 2
    const cy = top.top + h * 0.95
    const r = Math.min(w / 2 - 8, h * 0.85)
    const arc = (deg: number) => {
      const a = ((deg - 90) * Math.PI) / 180
      return `${cx + r * Math.cos(a)} ${cy + r * Math.sin(a)}`
    }
    const role = ctx.theme.label
    const hold = item.hold === undefined ? undefined : num(item, "hold", 0)
    return {
      layers: [
        face(ctx),
        ...top.layers,
        {
          id: `${ctx.cell}-scale`,
          x: 0,
          y: 0,
          width: w,
          height: ctx.height,
          svg: svg(w, ctx.height, `<path d="M${arc(-50)} A${r} ${r} 0 0 1 ${arc(50)}" fill="none" stroke="${ctx.theme.dim}" stroke-width="2"/>`),
        },
        words(
          ctx,
          "min",
          ctx.text(str(item, "minLabel", String(min))),
          { x: 4, y: ctx.height - role.size - 6, width: w / 2 - 8, height: role.size + 4 },
          role,
          ctx.theme.dim,
        ),
        words(
          ctx,
          "max",
          ctx.text(str(item, "maxLabel", String(max))),
          { x: w / 2 + 4, y: ctx.height - role.size - 6, width: w / 2 - 8, height: role.size + 4 },
          role,
          ctx.theme.dim,
          "end",
        ),
        {
          id: `${ctx.cell}-needle`,
          x: cx - 1.5,
          y: cy - r,
          width: 3,
          height: r,
          pivot: [0.5, 1],
          rotation: { ...ramp(value, min, max, hold), output: [-50, 50] },
          transitionMs: 120,
          svg: svg(3, r, `<rect width="3" height="${r}" rx="1.5" fill="${ctx.theme.lit}"/>`),
        } as PanelSceneLayer,
      ],
      controls: [],
    }
  },

  knob(item, ctx) {
    const value = varRef(item)
    const min = num(item, "min", 0)
    const max = num(item, "max", 100)
    const top = caption(ctx, item)
    const size = Math.min(ctx.width, ctx.height - top.top) - 8
    const x = (ctx.width - size) / 2
    const y = top.top + (ctx.height - top.top - size) / 2
    const step = num(item, "step", 1)
    return {
      layers: [
        ...top.layers,
        {
          id: `${ctx.cell}-body`,
          x,
          y,
          width: size,
          height: size,
          svg: svg(
            size,
            size,
            `<circle cx="${size / 2}" cy="${size / 2}" r="${size / 2 - 1}" fill="${ctx.theme.face}" stroke="${ctx.theme.track}" stroke-width="2"/>`,
          ),
        },
        {
          id: `${ctx.cell}-mark`,
          x: x + size / 2 - 1.5,
          y: y + 4,
          width: 3,
          height: size / 2 - 4,
          pivot: [0.5, 1],
          rotation: { value, input: [min, max], output: [-135, 135] },
          svg: svg(3, size / 2 - 4, `<rect width="3" height="${size / 2 - 4}" rx="1.5" fill="${ctx.theme.lit}"/>`),
        } as PanelSceneLayer,
      ],
      controls: [
        {
          id: `${ctx.cell}-turn`,
          kind: "knob",
          label: ctx.text(str(item, "label", "Knob")),
          x,
          y,
          width: size,
          height: size,
          value,
          min,
          max,
          step,
          sensitivity: (max - min) / 200,
          // Always heard, so the board keeps the var where the operator left it: one left only on
          // screen would be put back by the next event's answer, from what the board last knew.
          event: sends(ctx, "c"),
        },
      ],
    }
  },

  slider(item, ctx) {
    const value = varRef(item)
    const min = num(item, "min", 0)
    const max = num(item, "max", 100)
    const top = caption(ctx, item)
    const w = ctx.width - 12
    const trackY = top.top + (ctx.height - top.top - 6) / 2
    return {
      layers: [
        face(ctx),
        ...top.layers,
        { id: `${ctx.cell}-track`, x: 6, y: trackY, width: w, height: 6, svg: svg(w, 6, `<rect width="${w}" height="6" rx="3" fill="${ctx.theme.track}"/>`) },
        {
          id: `${ctx.cell}-fill`,
          x: 6,
          y: trackY,
          width: w,
          height: 6,
          pivot: [0, 0.5],
          clipX: ramp(value, min, max),
          svg: svg(w, 6, `<rect width="${w}" height="6" rx="3" fill="${ctx.theme.active}"/>`),
        } as PanelSceneLayer,
      ],
      controls: [
        {
          id: `${ctx.cell}-slide`,
          kind: "slider",
          label: ctx.text(str(item, "label", "Slider")),
          x: 6,
          y: 0,
          width: w,
          height: ctx.height,
          value,
          min,
          max,
          step: num(item, "step", 1),
          // Always heard, so the board keeps the var where the operator left it: one left only on
          // screen would be put back by the next event's answer, from what the board last knew.
          event: sends(ctx, "c"),
        },
      ],
    }
  },

  menuButton(item, ctx) {
    const entries = item.items as { label: string }[]
    const role = ctx.theme.body
    const label = ctx.text(str(item, "label"))
    return {
      layers: [
        face(ctx),
        words(
          ctx,
          "label",
          `${label} ▾`,
          { x: 4, y: (ctx.height - role.size * 1.3) / 2, width: ctx.width - 8, height: role.size * 1.3 },
          role,
          ctx.theme.ink,
          "center",
        ),
      ],
      controls: [
        {
          id: `${ctx.cell}-menu`,
          kind: "button",
          label: label || "Menu",
          x: 0,
          y: 0,
          width: ctx.width,
          height: ctx.height,
          menu: entries.map((entry, i) => ({ label: ctx.text(entry.label), event: sends(ctx, "m", i) })),
        },
      ],
    }
  },

  segmented(item, ctx) {
    // One key per option, the one the value holds lit: a mode, a band, an antenna.
    const value = ref(item)
    const options = item.options as { label?: string; value: string | number }[]
    const role = ctx.theme.body
    const w = ctx.width / options.length
    const layers: PanelSceneLayer[] = [face(ctx)]
    const controls: WidgetCell["controls"] = []
    options.forEach((option, i) => {
      const label = ctx.text(String(option.label ?? option.value))
      const is = { value, is: option.value } as BoardItem["when"]
      const at = { x: i * w + 2, y: (ctx.height - role.size * 1.3) / 2, width: w - 4, height: role.size * 1.3 }
      layers.push(
        {
          id: `${ctx.cell}-on${i}`,
          x: i * w + 2,
          y: 2,
          width: w - 4,
          height: ctx.height - 4,
          when: is,
          svg: svg(w - 4, ctx.height - 4, `<rect width="${w - 4}" height="${ctx.height - 4}" rx="5" fill="${ctx.theme.active}"/>`),
        } as PanelSceneLayer,
        words(ctx, `label${i}`, label, at, role, ctx.theme.ink, "center"),
        { ...words(ctx, `label-on${i}`, label, at, role, ctx.theme.onActive, "center"), when: is } as PanelSceneLayer,
      )
      controls.push({ id: `${ctx.cell}-opt${i}`, kind: "button", label, x: i * w, y: 0, width: w, height: ctx.height, event: sends(ctx, "s", i) })
    })
    return { layers, controls }
  },
}
