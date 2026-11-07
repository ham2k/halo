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
  /** The frequency, in Hz: where the app has the radio, a tune ahead of its report while it is live; the last it reported, kept while it is disconnected. Extension API 13. */
  | "radio.frequencyHz"
  /** The frequency, in Hz, the radio itself last reported. Extension API 19. */
  | "radio.reportedFrequencyHz"
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
 * - `bandScope`: a band scope — the radio's spectrum and waterfall, drawn by the host from sweeps
 *   that never reach the extension. Needs `requiresRadioRead`; a host without the feature, or a
 *   radio without a scope, shows why instead. A click sends `commit` with the frequency as `value`.
 *   Takes no `value`; see `PanelSceneSpectrum` for the rest. Extension API 17; before it the same
 *   control is `spectrum` (extension API 6), which still reads the same.
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
  | "bandScope"
  | "spectrum"
  | "zoom"

/** A literal, or the name of a scene value — which a slider with no `event` retunes with no bridge call. */
export type PanelSceneSpectrumNumber = number | string

/**
 * A band scope's display (`bandScope`, or `spectrum` before extension API 17). All of it happens
 * on the host after the sweep arrives, so it means the same on every radio; the radio's own scope
 * (span, reference level, sweep speed) is `host.setRadioSpectrum`'s. Colors are `#RRGGBB`, or
 * `#AARRGGBB` with transparency. Defaults follow the app's theme.
 */
export interface PanelSceneSpectrum {
  /** A radio's id from `listRadios`. Omitted, the designated radio. */
  radio?: string
  /** Default `both`. `pan` is `spectrum`'s name before extension API 17. */
  display?: "both" | "spectrum" | "pan" | "waterfall"
  /**
   * Which way the waterfall moves; the spectrum sits on the side it comes from. Frequency rises
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
  /** The spectrum's share of the height with `both`, 0.1–0.9. Default 0.4. */
  split?: number
  /** dB added to the radio's own floor. */
  floor?: PanelSceneSpectrumNumber
  /** The spectrum's height in dB. Omitted, the radio's. */
  range?: PanelSceneSpectrumNumber
  /** Written as the pointer moves: the frequency and level under it. */
  hoverHz?: string
  hoverDb?: string
  /**
   * Written by the app as they change, in Hz: the width shown, what a click rounds to, and this
   * control's radio's tuned frequency. Extension API 17.
   */
  widthHz?: string
  stepHz?: string
  vfoHz?: string
  /** 0–99: the share of the trace each sweep keeps from the last. Default 40. The waterfall stays raw. */
  average?: PanelSceneSpectrumNumber
  /** The most times a second the spectrum redraws, 1–60. Default 15. The waterfall keeps its own pace. */
  fps?: PanelSceneSpectrumNumber
  /** Waterfall rows a second, 0.1–60; each row keeps the loudest reading since the last. Omitted, one per sweep. */
  waterfallSpeed?: PanelSceneSpectrumNumber
  /** The waterfall's own dB window, like `floor` and `range`. Omitted, the spectrum's. */
  waterfallFloor?: PanelSceneSpectrumNumber
  waterfallRange?: PanelSceneSpectrumNumber
  /** Default `classic`. */
  palette?: "classic" | "gray" | "heat"
  /** 2 to 8 stops, lowest level first, in place of `palette`. */
  waterfallColors?: string[]
  traceColor?: string
  /** 0.25–8. Default 1. */
  traceWidth?: PanelSceneSpectrumNumber
  /** Under the trace. With `fillColorBottom`, a gradient from the top of the spectrum to its bottom. */
  fillColor?: string
  fillColorBottom?: string
  /**
   * The trace's colors by level, 2 to 8 stops lowest first: colors spread evenly from the spectrum's
   * bottom to its top, or stops each at its own level, so a level keeps its color as the floor and
   * range move. In place of `traceColor`. API 17.
   */
  traceColors?: string[] | PanelSceneSpectrumStop[]
  /** The fill's colors by level, as `traceColors`. In place of `fillColor` and `fillColorBottom`. API 17. */
  fillColors?: string[] | PanelSceneSpectrumStop[]
  /** The trace in dashes. API 17. */
  traceDashed?: boolean
  /**
   * 0–20: the trace averaged across this many pixels of frequency and drawn as a curve. The
   * waterfall, the hover level and the noise stay raw. API 17.
   */
  traceSmooth?: PanelSceneSpectrumNumber
  backgroundColor?: string
  /** The spectrum's dB and frequency lines. */
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
  /**
   * The narrowest a zoom goes, in Hz, or `'radio'` (omitted): a hundred Hz or the narrowest sweep
   * the radio's scope can be made to send with its points 10 pixels apart. Extension API 20.
   */
  minWidthHz?: number | "radio"
  /**
   * The widest a zoom goes, in Hz, or `'radio'` (omitted): what the radio's scope can be made to
   * show. Wider than that, the picture is drawn over the swept part only; a pan stops where the
   * sweep reaches the window's edge, and with `follow` the scope follows the dial rather than the
   * window, where the radio lets the app place it. Extension API 20.
   */
  maxWidthHz?: number | "radio"
  /**
   * A click tunes to the nearest multiple of this many Hz, the wheel moves by it and a dragged line
   * lands on it. Omitted, steps that follow the zoom along 1, 2, 5, 10, 20, 50… Hz from the smallest
   * covering a pixel: a fine step one above it, which a dragged line lands on, a medium one and a coarse two above that
   * (no coarser than 1 kHz unless the fine one is). Within 5 s of the last tune, a click within 1 kHz
   * of the dial is fine and within 3 kHz medium; any other coarse. The wheel is fine a notch at a
   * time, medium briskly, coarse spun. Before extension API 17, omitted, a click went out where it
   * landed.
   */
  tuneStep?: PanelSceneSpectrumNumber
  /** Dashes the spectrum's grid lines. */
  gridDashed?: boolean
  /**
   * The gap between the spectrum and the waterfall, with frequency labels and ticks — the axis a
   * drag zooms on. `true` takes the defaults; omitted, so does the app from extension API 17 (with
   * ticks), and before it there was none; `false` is none, and no axis to zoom on.
   */
  scale?: boolean | PanelSceneSpectrumScale
  /**
   * The tuned frequency at the top of its line, over the passband the scene draws (its first area
   * anchored to the dial). `false` hides it; an object says how it is drawn. Extension API 17.
   */
  vfoLabel?: boolean | PanelSceneSpectrumVfoLabel
  /**
   * A strip along the flow: dB along the spectrum (no unit) and the waterfall's age in seconds.
   * Omitted, the app draws one at the end; `false` is none. A drag along it changes the waterfall's
   * speed, the spectrum's floor (the third by its base) or its range (beyond), as
   * `gestures.levels` says; a double click puts the scene's own back. Its background, labels and
   * ticks are the frequency axis's (`scale`'s) where it names none. Extension API 17.
   */
  levelScale?:
    | boolean
    | {
        /**
         * Which end of the frequency's way across the screen: the right (`end`, the default) or left
         * of a band scope flowing `down` or `up`, the bottom or top of one flowing `right` or `left`.
         */
        side?: "start" | "end"
        /** Over the picture on a see-through background (the default), or `false`, beside it. */
        over?: boolean
        /** How deep it is. Default 40 upright, 24 sideways. */
        width?: PanelSceneSpectrumNumber
        background?: string
        labels?: { fontFamily?: string; size?: PanelSceneSpectrumNumber; weight?: PanelSceneSpectrumNumber; italic?: boolean; color?: string }
        ticks?: { color?: string; width?: PanelSceneSpectrumNumber; length?: PanelSceneSpectrumNumber }
      }
  /**
   * Who handles each gesture: `native`, the app; `event`, the extension, sent the control's event;
   * `off`, nobody. `tune` is a click, a scroll that tunes (see `scroll`), or a drag of
   * the tuned frequency's line — native, the app tunes the radio itself, where the
   * panel declares `requiresRadioWrite` (elsewhere the click is the event); as an event, a `commit`
   * with the frequency. `zoom` is a drag along the axis, a pinch, or a trackpad pinch; `pan` a drag
   * along the frequency over the spectrum or waterfall, or a scroll that pans; `split` a drag across
   * the axis, moving it between the spectrum and the waterfall — as events, `change` while it moves
   * and `commit` when it ends, with `gesture` naming which and `value` the width or the middle in Hz,
   * or the spectrum's share of the height; `levels` a drag on the level strip, sent as `floor`,
   * `range` or `speed`. Native, the `commit` still comes when the gesture ends, for a panel that keeps
   * the operator's choice (a saved width back as `span`, a share as `split`); a double click on the
   * axis sends a zoom of `0`, the scene's own width again. Omitted, each is `native`, except a bundle
   * declaring an extension API before 17, whose `tune` is `event` and whose wheel scrolls the scene as
   * it did. Extension API 17.
   */
  gestures?: {
    tune?: "native" | "event" | "off"
    zoom?: "native" | "event" | "off"
    pan?: "native" | "event" | "off"
    split?: "native" | "event" | "off"
    levels?: "native" | "event" | "off"
    /**
     * What scrolling up and down, and sideways, does — the wheel or a trackpad's swipe — whichever
     * way the band scope lies. Default: up and down tune, sideways pans. Along the frequency on
     * screen it moves the dial or the window the way it goes; across it, up and right are higher.
     */
    scroll?: { vertical?: "tune" | "pan" | "off"; horizontal?: "tune" | "pan" | "off" }
  }
  /** The tuned-frequency line, styled per part; a part it leaves out has none. Omitted, the theme's on both. */
  center?: { spectrum?: PanelSceneSpectrumStyle; pan?: PanelSceneSpectrumStyle; waterfall?: PanelSceneSpectrumStyle }
  /** Up to 16 lines and areas at Hz offsets — a passband, a CW offset. */
  overlays?: PanelSceneSpectrumOverlay[]
  /** Up to 256 pieces of text at frequencies — a spot, a net, a beacon; 64 before extension API 20. */
  annotations?: PanelSceneSpectrumAnnotation[]
  /**
   * Up to 512 rectangles, lines, text and artwork placed by frequency, over the picture under the
   * annotations, moving with every zoom and pan. Extension API 17; 128 before API 20.
   */
  layers?: PanelSceneSpectrumLayer[]
}

/**
 * Along the frequency: `freq:` and a number of Hz or a scene value, or `vfo` (this control's tuned
 * frequency), then any of `±<n>hz` (moving with the zoom) and `±<n>px` (not) — `freq:14074000`,
 * `vfo-1500hz`, `freq:spotHz+4px`. With no frequency, or as a number, pixels from the window's low
 * edge.
 */
export type PanelSceneSpectrumAlong = string | number

/**
 * Across the frequency: `spectrum`, `axis` or `waterfall` for that part's top edge (`:bottom` for
 * its bottom), then any of `±<n>%` (a share of that part's height), `±<n>s` (on the waterfall,
 * seconds of its history) and `±<n>px` — `spectrum+30%`, `waterfall+5s`, `spectrum:bottom-12px`. Or
 * `noise` (the spectrum's noise as the app estimates it), then `±<n>db` above it, `±<n>%` of the
 * spectrum's height and `±<n>px` — `noise+20db`, which stays that far above the noise as the floor and range change. With neither,
 * or as a number, from the control's top edge, a share being of the control's height. A part not
 * shown draws nothing on it, nor the noise with no spectrum.
 */
export type PanelSceneSpectrumAcross = string | number

/**
 * Drawn where its coordinates put it: `x` and `x2` along the frequency, `y` and `y2` across it,
 * whichever way the control is turned. A `rect` or an `svg` fills the box between the corners, a
 * `line` runs from one to the other, and `text` sits at the first, upright.
 */
export interface PanelSceneSpectrumLayer {
  /** Unique within the control. */
  id: string
  kind: "rect" | "line" | "text" | "svg"
  x: PanelSceneSpectrumAlong
  /** Needed by a `rect` and an `svg`; a `line` defaults to `x`. */
  x2?: PanelSceneSpectrumAlong
  /** Default the control's top. */
  y?: PanelSceneSpectrumAcross
  /** Default the control's bottom. */
  y2?: PanelSceneSpectrumAcross
  /** A rect's outline, a line's color, or the text's. */
  color?: string
  /** A rect's inside. A rect needs this or `color`. */
  fill?: string
  /** The outline's or the line's width. Default 1. */
  width?: PanelSceneSpectrumNumber
  /** A line drawn in dashes. */
  dashed?: boolean
  /**
   * Drawn behind the spectrum's grid, areas and trace rather than over the picture, and so hidden
   * under the waterfall. A click reaches it only where no layer over the picture takes it.
   */
  behind?: boolean
  /** A rect's corners, or the text's background. */
  radius?: PanelSceneSpectrumNumber
  /** Text as given (at most 256 characters), or `value`. */
  text?: string
  /** A scene value shown with `decimals` (0 to 6), between `prefix` and `suffix`. */
  value?: string
  decimals?: number
  prefix?: string
  suffix?: string
  /** Which end of the text is at `x`. Default `start`. */
  align?: "start" | "center" | "end"
  /** Which edge of the text is at `y`. Default `top`. */
  valign?: "top" | "center" | "bottom"
  fontFamily?: string
  size?: PanelSceneSpectrumNumber
  weight?: PanelSceneSpectrumNumber
  italic?: boolean
  background?: string
  /** Around the text. Default 2 with a background, else 0. */
  padding?: PanelSceneSpectrumNumber
  /** Artwork for an `svg` layer, stretched to its box. */
  svg?: string
  /**
   * Sent as `activate`, with the frequency clicked as `value`, the `id` as `layer` and where it
   * was clicked as `at`; the click tunes nothing.
   */
  event?: string
  /** Opened where it is clicked, in place of an `event`; the item picked is sent the same way. */
  menu?: { label: string; event: string }[]
}

/**
 * The gap sits between the spectrum and the waterfall — above the waterfall with no spectrum,
 * below the spectrum with no waterfall. Labels and ticks are drawn over the whole control, so an
 * `offset` can place them anywhere: it is pixels from the base of the spectrum (the top of the
 * waterfall where there is none), negative rising into the spectrum.
 */
/** How the tuned frequency's label is drawn. Extension API 17. */
export interface PanelSceneSpectrumVfoLabel {
  /**
   * The text of its MHz, its kHz and its Hz. Each part takes what it does not name from the one
   * before it, the MHz from the label's own (the line's color), except that the MHz is bold where
   * the kHz is light (`weight` 300) and the Hz is four fifths the kHz's size.
   */
  mhz?: PanelSceneSpectrumVfoLabelPart
  khz?: PanelSceneSpectrumVfoLabelPart
  hz?: PanelSceneSpectrumVfoLabelPart
  /**
   * Hz digits always shown, 0 to 3, cut rather than rounded. `auto` (the default): as many as the
   * frequency has, each sliding in or out as the dial needs it, and kept while the dial moves.
   */
  hzDigits?: 0 | 1 | 2 | 3 | "auto"
  /**
   * With the dial out of the window the label waits at the edge it is past, an arrow on that side
   * pointing the way; a click on either brings the window back to the dial. The arrow's `color`
   * (the line's) and `size` in pixels (under half the text's height), or `false` for none.
   * Extension API 20.
   */
  arrow?: false | { color?: string; size?: PanelSceneSpectrumNumber }
}

/** The text of one part of the tuned frequency's label. */
export interface PanelSceneSpectrumVfoLabelPart {
  fontFamily?: string
  size?: PanelSceneSpectrumNumber
  weight?: PanelSceneSpectrumNumber
  italic?: boolean
  color?: string
}

export interface PanelSceneSpectrumScale {
  /** Pixels, 0–200. Default 20. */
  gap?: PanelSceneSpectrumNumber
  /**
   * Over the picture on a see-through `background`, taking no height of its own: `waterfall` (or
   * `true`) across the waterfall's head, `spectrum` across the spectrum's foot. Omitted or `false`,
   * in a gap between the parts. Extension API 17.
   */
  over?: boolean | "spectrum" | "waterfall"
  background?: string
  borderTop?: { color?: string; width?: PanelSceneSpectrumNumber }
  borderBottom?: { color?: string; width?: PanelSceneSpectrumNumber }
  /** On by default; `false` hides them. */
  labels?:
    | boolean
    | {
        /** Hz between labels. Omitted, the gridlines' step. */
        interval?: PanelSceneSpectrumNumber
        /** Decimals of MHz every label shows, 0–6. Omitted, every kHz digit and as many Hz as tell one label from the next. Extension API 7. */
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
  /**
   * Off by default. From extension API 17 a label's tick is taller and heavier, with half-length ones
   * between: every 100 Hz once labels are 1 kHz apart or closer and those are 4 pixels apart, else
   * every 1 kHz where those are.
   */
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
 * frequency as `value`, this `id` as `annotation` and where it was clicked as `at`, and does not
 * tune; with a `menu`, it opens there and the item picked is sent the same way; with neither, a
 * click on it tunes like anywhere else.
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
  /** Default `spectrum`; `pan` is its name before extension API 17. */
  part?: "spectrum" | "pan" | "waterfall"
  /** Pixels from the spectrum's bottom up to the text's, or from the waterfall's top down to the text's. Default 4. */
  offset?: PanelSceneSpectrumNumber
  /**
   * Where `offset` measures from in place of that edge, as a layer's `y` is written — `noise+30db`
   * stands the text that far above the noise on any radio's scale. Not drawn until the app has
   * estimated the noise. An app without it measures from the edge.
   */
  y?: PanelSceneSpectrumAcross
  /** Which end of the text sits at `hz`. Default `center`. */
  align?: "start" | "center" | "end"
  /**
   * The point the box makes at `hz`: a drawn-out corner for `start`/`end`, a notch for `center`.
   * With the default `corner`, its tip sits at `offset`; turned the other way, the box's edge
   * does. Shown by default (size 4, pointing toward the spectrum's bottom
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
  /**
   * `near` draws the border on only the edge facing the one `offset` measures from — under the
   * text on the spectrum, over it on the waterfall. Default `all`; an app without it draws all.
   */
  borderEdges?: "all" | "near"
  /**
   * Drawn as a line `width` pixels wide (four fifths of the box with `true`) where the box's near border would be, the
   * box itself only while the pointer is on the line or on it, over any annotation it would overlap,
   * which waits meanwhile: a label there is no room for, shown on demand. A touch with nothing
   * hovered opens it first; a click on it open is a click on the annotation. Extension API 20.
   */
  collapsed?: boolean | { width?: number }
  /** Default 2. */
  padding?: PanelSceneSpectrumNumber
  /** Default 2. */
  radius?: PanelSceneSpectrumNumber
  event?: string
  /** Opened where it is clicked, in place of an `event`. Extension API 17. */
  menu?: { label: string; event: string }[]
  /**
   * An MDI or `fa-` icon before the text, at its size, in `color` or the text's. An app without it
   * draws the text alone.
   */
  icon?: { name: string; color?: string }
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
 * or as frequencies with `anchor: "absolute"` (a band edge, a segment). On the spectrum an area
 * draws behind the trace and a line in front of it unless `behind` — which absolute ones default to.
 * On the waterfall all of it draws over the rows. A part with no style is not drawn on.
 */
export interface PanelSceneSpectrumOverlay {
  at?: PanelSceneSpectrumNumber
  from?: PanelSceneSpectrumNumber
  to?: PanelSceneSpectrumNumber
  anchor?: "vfo" | "center" | "absolute"
  behind?: boolean
  /** The spectrum's style; `pan` is its name before extension API 17. */
  spectrum?: PanelSceneSpectrumStyle
  pan?: PanelSceneSpectrumStyle
  waterfall?: PanelSceneSpectrumStyle
  /**
   * An area's look for the trace and its fill over its frequencies; what it leaves out is the
   * control's, and a later area's covers an earlier one's. Not on a line. Extension API 17.
   */
  trace?: PanelSceneSpectrumTrace
}

/**
 * A color at a level on the spectrum: `noise` and dB above it (`noise+3db`), or the spectrum's
 * edges and a share of its height (`spectrum:bottom+40%`). Placed by the noise, a stop waits for
 * the app's estimate, the stops spread evenly meanwhile.
 */
export interface PanelSceneSpectrumStop {
  color: string
  at: PanelSceneSpectrumAcross
}

/** The trace's look over an overlay's area; `colors` and `fillColors` by level, as the control's. */
export interface PanelSceneSpectrumTrace {
  color?: string
  /** 0.25–8. */
  width?: PanelSceneSpectrumNumber
  dashed?: boolean
  /** In place of `color`. */
  colors?: string[] | PanelSceneSpectrumStop[]
  fill?: string
  /** In place of `fill`. */
  fillColors?: string[] | PanelSceneSpectrumStop[]
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
  /** The `id` of the band scope annotation clicked; `value` is its frequency. */
  annotation?: string
  /** The `id` of the band scope layer clicked; `value` is the frequency clicked. Extension API 17. */
  layer?: string
  /**
   * A band scope's zoom (`value` the width in Hz), pan (`value` its middle), split (`value` the
   * spectrum's share of the height), or a drag on its level strip: `floor` (dB added to the radio's
   * floor), `range` (the spectrum's height in dB) or `speed` (waterfall rows a second). API 17.
   */
  gesture?: "zoom" | "pan" | "split" | "floor" | "range" | "speed"
  /** Where a band scope annotation or layer was clicked. Extension API 17. */
  at?: PanelSceneSpectrumClick
}

/** Where a click on a band scope landed. */
export interface PanelSceneSpectrumClick {
  /** Pixels in the control, the ones a layer's `px` measures. */
  x: number
  y: number
  /** In scene units, for a band scope placed by a rect over the artwork. */
  sceneX?: number
  sceneY?: number
  part?: "spectrum" | "axis" | "waterfall"
  /** The frequency clicked. */
  hz?: number
  /** On the spectrum, the level clicked: dB on the radio's own scale, not calibrated dBm. */
  db?: number
  /** On the spectrum, dB above the noise as the app estimates it. */
  aboveNoiseDb?: number
  /** On the waterfall, how old the row clicked is. */
  ageSeconds?: number
  /** On the waterfall, when the row clicked was taken, on the app's clock. */
  atMillis?: number
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
