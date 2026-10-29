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
  /**
   * Have the host feed a radio's live readings into `values` — the `PanelSceneRadioValue` names —
   * and `strings` — the `PanelSceneRadioString` names — updated as the radio reports them, with no
   * render. `node` is a radio's id; omitted, the logging radio. Needs `requiresRadioRead` and
   * extension API 7 (the dial, API 13); without either, every reading is missing. A missing number
   * binds as the bottom of a binding's range and shows as `—`; a missing string is empty.
   */
  radio?: { node?: string }
  /**
   * A scene longer than its pane along `axis` (default `y`), scrolled by the app itself — wheel,
   * trackpad and drag, a drag begun on a button included — with no call to the extension. Scaled
   * to fill the pane across, it runs on past it along the axis. The position, in scene units from
   * the start, is written to the scene value `value` as it scrolls; a render that changes that
   * value moves the view there, and one that leaves it alone leaves the operator's scroll alone.
   * `event`, when given, is sent as a `commit` with the position as `value` once scrolling comes
   * to rest. Layers and controls marked `fixed` stay put over the pane. No `layout`. Extension API 12.
   */
  scroll?: { axis?: "x" | "y"; value: string; event?: string }
}

/** Host-fed values of a scene with `radio`: its meters, and `radio.transmitting` as 1 or 0. Reserved: a scene may not declare them. */
export type PanelSceneRadioValue =
  | "radio.signalDbm"
  | "radio.powerOut"
  | "radio.swr"
  | "radio.alc"
  | "radio.supplyVolts"
  | "radio.transmitting"
  /** The SWR averaged over the transmission under way, or else the last one. Extension API 7. */
  | "radio.swrAverage"
  /** 0 while transmitting, then counting up; a long time when there has been none. Extension API 7. */
  | "radio.secondsSinceTransmit"
  /** The frequency, in Hz: the last the radio reported, kept while it is disconnected. Extension API 13. */
  | "radio.frequencyHz"
  /** The receive passband's edges and width, in Hz, while the radio is live. Extension API 13. */
  | "radio.passbandLowHz"
  | "radio.passbandHighHz"
  | "radio.passbandWidthHz"
  /** The power the radio is SET to, in watts, while live — `radio.powerOut` is what it measures. Extension API 13. */
  | "radio.powerWatts"
  /** 1 while the app holds the radio's PTT, else 0; given where `readRadio()` gives `keying`. `radio.transmitting` is the radio's own report. Extension API 13. */
  | "radio.ptt"
  /** 1 while the radio is connected and answering, else 0. Extension API 13. */
  | "radio.connected"

/**
 * Host-fed words of a scene with `radio`, in `strings`; empty when the radio has not said.
 * Reserved like the values. Extension API 13.
 */
export type PanelSceneRadioString =
  /** The mode as the radio reports it (`USB`, `CW`, `DATA-USB`…); the last known, like the frequency. */
  | "radio.mode"
  /** `inline`, `bypassed`, `tuning` or `failed`, while live. */
  | "radio.tuner"
  /** The connection: `connected`, `connecting`, `disconnecting`, `disconnected` or `error`. */
  | "radio.status"

/**
 * Shows a layer or control only while a value passes one test, checked by the host with no call
 * to the extension: `is` one value, `in` a list of them, or within `min`…`max` (either may be
 * omitted). `not` inverts it. `value` names a number or a string — the scene's own or a `radio.`
 * one — and the test must suit it: words for a string, numbers for a number. Exactly one of `is`,
 * a non-empty `in`, or a range; the host refuses a scene that gives two. A radio number not given
 * fails the test before `not` inverts it; a radio word not given is empty. Hidden is as at opacity 0: not drawn, no clicks, no focus; a control
 * placed by `layout` keeps its place. Extension API 13.
 */
export interface SceneCondition {
  value: string
  is?: string | number
  in?: (string | number)[]
  min?: number
  max?: number
  not?: boolean
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
  /** Supply exactly one of svg, text or icon. SVG must be self-contained. */
  svg?: string
  /**
   * A named icon — MDI, or FontAwesome with `fa-` — drawn by the app to fit the layer, in `color`
   * (`#RRGGBB`) or the theme's. Extension API 12.
   */
  icon?: { name: string; color?: string }
  /**
   * Take the clicks that land on this layer. Off by default: layers are click-through, so
   * artwork painted over a control does not stop it working. On, it covers the controls under it.
   */
  blocksPointer?: boolean
  /** In a scene with `scroll`: drawn over the pane where it is, in pane coordinates, not scrolled. Extension API 12. */
  fixed?: boolean
  /**
   * While a `zoom` strip is dragged, scaled along the scroll about the pane's middle, rather than
   * moved there at its own size: for a background, or a line that runs the whole way. Extension API 12.
   */
  stretch?: boolean
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
    /** `#RRGGBB`: a soft halo of this colour around the letters, to keep them legible over artwork. Extension API 7. */
    glow?: string
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
  /** Scale about `pivot` — a bar's fill with `pivot: [0, 0.5]`. Extension API 7. */
  scaleX?: SceneBinding
  scaleY?: SceneBinding
  opacity?: SceneBinding
  /** Drawn only while this holds. Extension API 13. */
  when?: SceneCondition
  /** Rotation and scale origin as fractions of this layer's dimensions; default [0.5, 0.5]. */
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
 * - `zoom`: a strip of a scene with `scroll`, drawn by nothing, where a drag along the scroll zooms
 *   about the pane's middle — away from it in, toward it out, by the ratio of the distances. While
 *   the drag lasts the app moves each layer and control to where the zoom puts its middle, at its
 *   own size (a `stretch` layer scales instead), and on release sends `commit` with the factor as
 *   `value`; `min` and `max` are the factors allowed. A tap on it still reaches what lies there,
 *   and a drag elsewhere still scrolls. Needs `event`. Extension API 12.
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
  | "zoom"

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
   * as `rising` says: by default left to right for `down` (the default) and `up`, bottom to top for
   * `right` and top to bottom for `left` — `down` turned a quarter either way. Text stays upright;
   * offsets and `corner`s are measured as if flowing down.
   */
  flow?: "down" | "up" | "right" | "left"
  /**
   * Which way frequency rises, across the `flow`: `right` or `left` for `down` and `up`, `down` or
   * `up` for `right` and `left`. Omitted, `right` for `down` and `up`, `up` for `right`, `down` for
   * `left`. Offsets, `align` and `corner`s are still measured as if frequency rose to the right.
   * Extension API 12; before it, `left` rose bottom to top as `right` does.
   */
  rising?: "right" | "left" | "down" | "up"
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
  /**
   * Keeps the tuned frequency at least this share of the width (0–0.45) from either edge, by
   * moving the radio's scope just far enough to put it at that margin. Only where the radio lets
   * the app place its scope — a FlexRadio, whose panadapter in SmartSDR moves with it — and the
   * panel declares `requiresRadioWrite`; elsewhere it changes nothing. Extension API 7.
   */
  follow?: number
  /**
   * Hz shown across the control, from the middle of each sweep. A sweep wider than this is cropped
   * to it, so a radio whose scope comes in a few widths can be shown at any narrower one — set the
   * scope (`setRadioSpectrum`) to the narrowest that covers it. Where the radio's `spectrum` says
   * `autoSpan`, the app sets the scope itself, wide enough for the widest `span` on screen.
   * Extension API 7; `autoSpan` 12.
   */
  span?: PanelSceneSpectrumNumber
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
        /** Decimals of MHz every label shows, 0–6. Omitted, as many as tell one label from the next. Extension API 7. */
        decimals?: number
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
  /**
   * A button can open a native dropdown. Picking an item sends its event as the action. On a knob
   * (extension API 7) a click opens it, while a scroll or a drag still turns the knob.
   */
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
  /** In a scene with `scroll`: placed over the pane, in pane coordinates, not scrolled. Needs a rect. Extension API 12. */
  fixed?: boolean
  /**
   * A drawn control only (`button`, `slider`, `knob`): while the pointer is over it, the scene value
   * `value` reads `to`, set by the host with no call to the extension; leaving puts back the scene's
   * own value. Artwork bound to it lights up under the pointer — a spot's line with its call.
   * Survives renders while the pointer stays. Extension API 12.
   */
  hoverSet?: { value: string; to: number }
  /**
   * A `button` only: a click sends, as the event's `value`, where along the button's longer side it
   * landed — 0 at its top or left end, 1 at its bottom or right — so a scale can be clicked at a
   * place. Keys and screen readers activate it with no value, as does an app before this. It needs an
   * `event`, and takes no `menu`, whose click opens the menu instead. Extension API 12.
   */
  tapAt?: boolean
  /**
   * 0 to 1, fixed or bound like a layer's. At 0 the control is gone: it takes no clicks,
   * keyboard focus or screen-reader node. Anything between is only drawn fainter.
   */
  opacity?: number | SceneBinding
  /** Shown only while this holds, hidden as at opacity 0. Extension API 13. */
  when?: SceneCondition
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
  /**
   * A knob only: a drag moves the value the other way — content held under the finger, scrolled
   * by dragging, rather than a dial turned. Scrolling is unchanged. Extension API 12.
   */
  invertDrag?: boolean
  /**
   * A slider or knob only: it also takes the scrolls that land on drawn buttons over it — labels
   * drawn over a knob that scrolls the artwork. A native control, a `blocksPointer` layer or another
   * slider or knob in between keeps the scroll. Extension API 12.
   */
  scrollThrough?: boolean
  /**
   * A knob's second axis: with `valueY`, horizontal scrolling, dragging and the left/right keys set
   * `value`, and vertical ones (and up/down) set `valueY` — sent as its own event, `eventY`, which a
   * knob with an `event` must give, different from it. Its range and feel are `minY`, `maxY`, `stepY`
   * and `sensitivityY`. Extension API 7.
   */
  valueY?: string
  eventY?: string
  minY?: number
  maxY?: number
  stepY?: number
  sensitivityY?: number
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
