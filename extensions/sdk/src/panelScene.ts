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

export interface PanelSceneControl {
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
