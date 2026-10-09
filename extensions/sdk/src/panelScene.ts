// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT

/** Experimental v1 panel scene contract. All coordinates are in the scene's viewBox. */
export interface PanelScene {
  version: 1
  width: number
  height: number
  values: Record<string, number>
  /** String state for text fields and choices. A key is in `values` or here, never both. At most 256, each up to 4096 characters. */
  strings?: Record<string, string>
  /** Painted in order, each over the ones before. */
  layers: PanelSceneLayer[]
  controls?: PanelSceneControl[]
  /** Where rect-less native controls and the artwork go. Omitted, the artwork fills the panel. */
  layout?: PanelSceneLayoutNode
}

/** A clamped, linear mapping. No expressions or extension code run per frame. */
export interface SceneBinding {
  value: string
  /** Transform the source before mapping (for example selecting a display digit). */
  scale?: number
  truncate?: boolean
  modulo?: number
  input: [number, number]
  output: [number, number]
  /** Optional equally spaced output samples over input; replaces the output ramp. */
  samples?: number[]
}

export interface PanelSceneLayer {
  id: string
  x: number
  y: number
  width: number
  height: number
  /** Supply exactly one of svg or text. SVG must be self-contained. */
  svg?: string
  /**
   * Take the clicks that land on this layer. Off by default: layers are click-through, so
   * artwork painted over a control does not stop it working. On, it covers the controls under it.
   */
  blocksPointer?: boolean
  /** Exactly one of literal/value. A value naming a string shows it as-is. Use text layers, not SVG <text>, for font support.
   * Size is unscaled; the host applies OS text scaling once. */
  text?: {
    value?: string
    literal?: string
    prefix?: string
    suffix?: string
    decimals?: number
    size?: number
    color?: string
    samples?: (number | string)[]
    /** Multiply numeric text values before formatting. Defaults to 1. */
    scale?: number
    /** Numeric formatting after scaling: truncate, then modulo, then zero padding. */
    truncate?: boolean
    modulo?: number
    minIntegerDigits?: number
    fontFamily?: string
    fontWeight?: number
    lineHeight?: number
    letterSpacing?: number
    /** Horizontal alignment within the layer. Defaults to start. */
    align?: "start" | "center" | "end"
  }
  rotation?: SceneBinding
  translateX?: SceneBinding
  translateY?: SceneBinding
  opacity?: SceneBinding
  /** Rotation origin as fractions of this layer's dimensions; default [0.5, 0.5]. */
  pivot?: [number, number]
  transitionMs?: number
  /** Local deterministic flicker/pulse; pauses when hidden, disabled for reduced motion. */
  pulse?: { periodMs: number; minOpacity: number; flicker?: boolean }
}

/**
 * `button`, `slider` and `knob` are invisible hit areas over the extension's own artwork.
 * The `native…` kinds are Material widgets, themed by the app:
 *
 * - `nativeButton`: sends `activate`. `variant`, `icon`, and optionally `menu`.
 * - `nativeSlider`: a number, between `min` and `max` in `step`s.
 * - `nativeTextField`: a string. Commits on Enter, or on leaving the field after typing.
 * - `nativeDropdown`, `nativeRadio`, `nativeSegmented`: a string, one of `options`.
 *   A `multi` segmented control holds its chosen values joined with commas, in option order.
 * - `nativeSwitch`, `nativeCheckbox`: a number, 1 or 0. Shows `label` beside it.
 * - `nativeChip`: with `value`, a toggle (1 or 0); without, an action that sends `activate`.
 * - `nativeText`: shows `label`, or its bound value. Sends nothing.
 * - `spectrum`: the radio's panadapter and waterfall, drawn by the host from sweeps that never
 *   reach the extension. Needs `requiresRadioRead`; a host without the feature, or a radio
 *   without a scope, shows why instead. A click sends `commit` with the frequency as `value`.
 *   Takes no `value`; see `PanelSceneSpectrum` for the rest. Extension API 6: declare `"api": 6`.
 *
 * `label` is every control's accessible name. There are no tooltips.
 */
export type PanelSceneControlKind =
  | "button"
  | "slider"
  | "knob"
  | "nativeButton"
  | "nativeSlider"
  | "nativeTextField"
  | "nativeDropdown"
  | "nativeSwitch"
  | "nativeCheckbox"
  | "nativeRadio"
  | "nativeSegmented"
  | "nativeChip"
  | "nativeText"
  | "spectrum"

/** A literal, or the name of a scene value — which a slider with no `event` retunes with no bridge call. */
export type PanelSceneSpectrumNumber = number | string

/**
 * A `spectrum` control's display. All of it happens on the host after the sweep arrives, so it
 * means the same on every radio; the radio's own scope (span, reference level, sweep speed) is
 * `host.setRadioSpectrum`'s. Colors are `#RRGGBB`, or `#AARRGGBB` with transparency. Defaults
 * follow the app's theme.
 */
export interface PanelSceneSpectrum {
  /** A radio's id from `listRadios`. Omitted, the designated radio. */
  radio?: string
  /** Default `both`. */
  display?: "both" | "pan" | "waterfall"
  /**
   * Which way the waterfall moves; the panadapter sits on the side it comes from. Frequency rises
   * left to right for `down` (the default) and `up`, bottom to top for `right` and `left`. Text
   * stays upright; offsets and `corner`s are measured as if flowing down.
   */
  flow?: "down" | "up" | "right" | "left"
  /** The panadapter's share of the height with `both`, 0.1–0.9. Default 0.4. */
  split?: number
  /** dB added to the radio's own floor. */
  floor?: PanelSceneSpectrumNumber
  /** The panadapter's height in dB. Omitted, the radio's. */
  range?: PanelSceneSpectrumNumber
  /** Written as the pointer moves: the frequency and level under it. */
  hoverHz?: string
  hoverDb?: string
  /** 0–99: the share of the trace each sweep keeps from the last. Default 40. The waterfall stays raw. */
  average?: PanelSceneSpectrumNumber
  /** The most times a second the panadapter redraws, 1–60. Default 15. The waterfall keeps its own pace. */
  fps?: PanelSceneSpectrumNumber
  /** Waterfall rows a second, 0.1–60; each row keeps the loudest reading since the last. Omitted, one per sweep. */
  waterfallSpeed?: PanelSceneSpectrumNumber
  /** The waterfall's own dB window, like `floor` and `range`. Omitted, the panadapter's. */
  waterfallFloor?: PanelSceneSpectrumNumber
  waterfallRange?: PanelSceneSpectrumNumber
  /** Default `classic`. */
  palette?: "classic" | "gray" | "heat"
  /** 2 to 8 stops, lowest level first, in place of `palette`. */
  waterfallColors?: string[]
  traceColor?: string
  /** 0.25–8. Default 1. */
  traceWidth?: PanelSceneSpectrumNumber
  /** Under the trace. With `fillColorBottom`, a gradient from the top of the panadapter to its bottom. */
  fillColor?: string
  fillColorBottom?: string
  backgroundColor?: string
  /** The panadapter's dB and frequency lines. */
  gridColor?: string
  /** The frequency lines carried down through the waterfall. Omitted, none. */
  waterfallGridColor?: string
  /** A click tunes to the nearest multiple of this many Hz. Omitted, wherever it lands. */
  tuneStep?: PanelSceneSpectrumNumber
  /** Dashes the panadapter's grid lines. */
  gridDashed?: boolean
  /** The gap between the panadapter and the waterfall, with frequency labels and ticks. `true` takes the defaults. */
  scale?: boolean | PanelSceneSpectrumScale
  /** The tuned-frequency line, styled per part; a part it leaves out has none. Omitted, the theme's on both. */
  center?: { pan?: PanelSceneSpectrumStyle; waterfall?: PanelSceneSpectrumStyle }
  /** Up to 16 lines and areas at Hz offsets — a passband, a CW offset. */
  overlays?: PanelSceneSpectrumOverlay[]
  /** Up to 64 pieces of text at frequencies — a spot, a net, a beacon. */
  annotations?: PanelSceneSpectrumAnnotation[]
}

/**
 * The gap sits between the panadapter and the waterfall — above the waterfall with no panadapter,
 * below the panadapter with no waterfall. Labels and ticks are drawn over the whole control, so an
 * `offset` can place them anywhere: it is pixels from the base of the panadapter (the top of the
 * waterfall where there is none), negative rising into the panadapter.
 */
export interface PanelSceneSpectrumScale {
  /** Pixels, 0–200. Default 20. */
  gap?: PanelSceneSpectrumNumber
  background?: string
  borderTop?: { color?: string; width?: PanelSceneSpectrumNumber }
  borderBottom?: { color?: string; width?: PanelSceneSpectrumNumber }
  /** On by default; `false` hides them. */
  labels?:
    | boolean
    | {
        /** Hz between labels. Omitted, the gridlines' step. */
        interval?: PanelSceneSpectrumNumber
        fontFamily?: string
        size?: PanelSceneSpectrumNumber
        /** 100–900. */
        weight?: PanelSceneSpectrumNumber
        italic?: boolean
        color?: string
        /** To the top of the text. Omitted, centered in the gap. */
        offset?: PanelSceneSpectrumNumber
      }
  /** Off by default. */
  ticks?:
    | boolean
    | {
        /** Hz between ticks. Omitted, the labels'. */
        interval?: PanelSceneSpectrumNumber
        color?: string
        width?: PanelSceneSpectrumNumber
        /** To the top of the tick. Default 0. */
        offset?: PanelSceneSpectrumNumber
        /** Default 4. */
        length?: PanelSceneSpectrumNumber
      }
}

/**
 * Text at a frequency, drawn by the host. With an `event`, a click sends `activate` with the
 * frequency as `value` and this `id` as `annotation`, and does not tune; without one, a click
 * on it tunes like anywhere else.
 */
export interface PanelSceneSpectrumAnnotation {
  /** Unique within the control. */
  id: string
  /** At most 256 characters. */
  text: string
  /** A frequency, or an offset from the tuned frequency or the sweep's middle with `anchor`. */
  hz: PanelSceneSpectrumNumber
  /** Default `absolute`. */
  anchor?: "vfo" | "center" | "absolute"
  /** Default `pan`. */
  part?: "pan" | "waterfall"
  /** Pixels from the panadapter's bottom up to the text's, or from the waterfall's top down to the text's. Default 4. */
  offset?: PanelSceneSpectrumNumber
  /** Which end of the text sits at `hz`. Default `center`. */
  align?: "start" | "center" | "end"
  /**
   * The point the box makes at `hz`: a drawn-out corner for `start`/`end`, a notch for `center`.
   * With the default `corner`, its tip sits at `offset`; turned the other way, the box's edge
   * does. Shown by default (size 4, pointing toward the panadapter's bottom
   * or the waterfall's top); `false` or `show: false` hides it.
   */
  pointer?: boolean | { show?: boolean; size?: PanelSceneSpectrumNumber; corner?: "top" | "bottom" }
  fontFamily?: string
  size?: PanelSceneSpectrumNumber
  weight?: PanelSceneSpectrumNumber
  italic?: boolean
  color?: string
  background?: string
  borderColor?: string
  borderWidth?: PanelSceneSpectrumNumber
  /** Default 2. */
  padding?: PanelSceneSpectrumNumber
  /** Default 2. */
  radius?: PanelSceneSpectrumNumber
  event?: string
}

/** `color` and `width` draw a line, or an area's edges; `fill` fills an area. */
export interface PanelSceneSpectrumStyle {
  color?: string
  width?: PanelSceneSpectrumNumber
  fill?: string
}

/**
 * A line at `at`, or an area between `from` and `to`, in Hz from the tuned frequency — from the
 * middle of the sweep with `anchor: "center"` (a Flex's panadapter is not centered on its slice),
 * or as frequencies with `anchor: "absolute"` (a band edge, a segment). On the panadapter an area
 * draws behind the trace and a line in front of it unless `behind` — which absolute ones default to.
 * On the waterfall all of it draws over the rows. A part with no style is not drawn on.
 */
export interface PanelSceneSpectrumOverlay {
  at?: PanelSceneSpectrumNumber
  from?: PanelSceneSpectrumNumber
  to?: PanelSceneSpectrumNumber
  anchor?: "vfo" | "center" | "absolute"
  behind?: boolean
  pan?: PanelSceneSpectrumStyle
  waterfall?: PanelSceneSpectrumStyle
}

export interface PanelSceneControl extends PanelSceneSpectrum {
  id: string
  label: string
  kind: PanelSceneControlKind
  /** A button can open a native dropdown. Picking an item sends its event as the action. */
  menu?: { label: string; event: string }[]
  /**
   * The control's rect over the artwork, in scene units. Required for the drawn kinds.
   * A native control omits all four to be placed by `layout` instead.
   */
  x?: number
  y?: number
  width?: number
  height?: number
  /**
   * With a rect: the id of the layer this control paints directly after, so later layers draw
   * over it. Omitted, the control paints above every layer.
   */
  after?: string
  /** Omit event for local-only interaction (for example a chart inspection cursor). */
  event?: string
  /** `slider`, `knob`, `nativeSlider` and `nativeTextField` only: send coalesced change events while dragging or typing, plus the final commit. */
  continuous?: boolean
  /**
   * The name of the value this control shows and sets: in `values`, or in `strings` for a string kind.
   * A choice's string must be `""` or one of its `options` (each part, for `multi`). `nativeButton` takes none.
   */
  value?: string
  /** Choices for `nativeDropdown`, `nativeRadio` and `nativeSegmented`. Values are unique. */
  options?: { label: string; value: string }[]
  /** `nativeSegmented` only: choose several. */
  multi?: boolean
  /** Shown but inert: no clicks, drags, keys or screen-reader adjustments act on it. */
  disabled?: boolean
  /**
   * 0 to 1, fixed or bound like a layer's. At 0 the control is gone: it takes no clicks,
   * keyboard focus or screen-reader node. Anything between is only drawn fainter.
   */
  opacity?: number | SceneBinding
  /** `nativeButton` only. Default `filled`. */
  variant?: "filled" | "tonal" | "outlined" | "text"
  /** `nativeButton` and `nativeChip`: a Material Design Icons name, such as `radio-tower`. */
  icon?: string
  /** `nativeTextField` and `nativeDropdown`: shown while empty. */
  placeholder?: string
  /** `nativeText` only: a typography role from the render environment. Default `body`. */
  style?: "body" | "label" | "title" | "display" | "mono"
  /** `nativeText` only. Default `start`. */
  align?: "start" | "center" | "end"
  min?: number
  max?: number
  step?: number
  /** Equal-width buckets, with one bucket per step (useful for hourly charts). */
  discrete?: boolean
  /** Inspect on hover. Only allowed on local-only sliders; touch/keyboard also work. */
  hover?: boolean
  /** Accessible descriptions indexed by (value - min) / step. */
  valueLabels?: string[]
  /** Knobs use relative horizontal/upward dragging. Value per scene unit; default 1. */
  sensitivity?: number
}

export interface PanelSceneEvent {
  controlId: string
  action: string
  phase: "activate" | "change" | "commit"
  sequence: number
  /** The control's number, for a control bound to `values`. */
  value?: number
  /** The control's string, for a control bound to `strings`. */
  text?: string
  /** The `id` of the spectrum annotation clicked; `value` is its frequency. */
  annotation?: string
}

/** Patch only named scene values and strings. The host ignores stale responses. */
export interface PanelSceneEventResult {
  values: Record<string, number>
  strings?: Record<string, string>
}

/**
 * Flutter's Row, Column and Wrap, with Flexible, Spacer and SizedBox as fields.
 * Sizes are logical pixels, like the render environment's. At most 8 deep and 128 nodes.
 *
 * - `{row: [...]}` / `{column: [...]}` / `{wrap: [...]}` lay out their children.
 * - `{control: "id"}` places a native control that has no rect. Each appears exactly once.
 * - `{scene: true}` places the artwork, scaled to fit. At most once.
 * - `{spacer: flex}` takes a share of the free space.
 *
 * A text field or dropdown given no width (a row child without `flex` or `width`) is 200 wide.
 */
export type PanelSceneLayoutNode = (
  | { row: PanelSceneLayoutNode[] }
  | { column: PanelSceneLayoutNode[] }
  | { wrap: PanelSceneLayoutNode[] }
  | { control: string }
  | { scene: true }
  | { spacer: number }
) & {
  /** Only on a row or column's direct child: share the free space, like Expanded (`tight`, the default) or Flexible (`loose`). */
  flex?: number
  fit?: "tight" | "loose"
  width?: number
  height?: number
  /** All sides, or `[start, top, end, bottom]`. */
  padding?: number | [number, number, number, number]
  /** Gap between children; for a wrap, between items in a run. */
  spacing?: number
  /** Wrap only: gap between runs. */
  runSpacing?: number
  mainAxisAlignment?: "start" | "center" | "end" | "spaceBetween" | "spaceAround" | "spaceEvenly"
  /** `stretch` on a row or column only. */
  crossAxisAlignment?: "start" | "center" | "end" | "stretch"
}

/** @deprecated Renamed to `PanelScene`. */
export type SvgScene = PanelScene
/** @deprecated Renamed to `PanelSceneLayer`. */
export type SvgSceneLayer = PanelSceneLayer
/** @deprecated Renamed to `PanelSceneControl`. */
export type SvgSceneControl = PanelSceneControl
