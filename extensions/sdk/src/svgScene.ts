// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT

/** Experimental v1 scene contract. All coordinates are in the scene's viewBox. */
export interface SvgScene {
  version: 1
  width: number
  height: number
  values: Record<string, number>
  layers: SvgSceneLayer[]
  controls?: SvgSceneControl[]
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

export interface SvgSceneLayer {
  id: string
  x: number
  y: number
  width: number
  height: number
  /** Supply exactly one of svg or text. SVG must be self-contained. */
  svg?: string
  /** Exactly one of literal/value. Use text layers, not SVG <text>, for font support.
   * Size is unscaled; the host applies OS text scaling once. */
  text?: {
    value?: string; literal?: string; prefix?: string; suffix?: string
    decimals?: number; size?: number; color?: string; samples?: (number | string)[]
    /** Multiply numeric text values before formatting. Defaults to 1. */
    scale?: number
    /** Numeric formatting after scaling: truncate, then modulo, then zero padding. */
    truncate?: boolean
    modulo?: number
    minIntegerDigits?: number
    fontFamily?: string; fontWeight?: number; lineHeight?: number; letterSpacing?: number
    /** Horizontal alignment within the layer. Defaults to start. */
    align?: 'start' | 'center' | 'end'
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

export interface SvgSceneControl {
  id: string
  label: string
  kind: 'button' | 'slider' | 'knob'
  /** A button can open a native dropdown. Picking an item sends its event as the action. */
  menu?: { label: string; event: string }[]
  x: number
  y: number
  width: number
  height: number
  /** Omit event for local-only interaction (for example a chart inspection cursor). */
  event?: string
  /** Send coalesced change events during dragging, plus the final commit. */
  continuous?: boolean
  value?: string
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
  phase: 'activate' | 'change' | 'commit'
  sequence: number
  value?: number
}

/** Patch only named scene values. The host ignores stale responses. */
export interface PanelSceneEventResult {
  values: Record<string, number>
}
