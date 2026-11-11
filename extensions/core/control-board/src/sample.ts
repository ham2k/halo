// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The Sample Control Board: a station board to start from, copied into a placement when it is
// placed, and from then on that pane's own.

export const sampleBoard = `# Ham2K Logger board
ham2k-board: 1
name: Station
params:
  rig: { type: radio, label: Transceiver }
  rot: { type: rotator, label: Rotator }
sources:
  rig: { radio: "{{ params.rig }}" }
  rot: { rotator: "{{ params.rot }}" }
vars:
  drive: 100
items:
  - type: group
    title: Receive
    columns: 6
    items:
      - { type: frequency, value: rig.frequencyHz, span: [4, 1] }
      - type: segmented
        value: rig.mode
        span: [2, 1]
        options: [CW, USB]
        onSelect: { setRadio: { source: rig, mode: $value } }
      - { type: needle, value: rig.signalDbm, min: -130, max: -20, label: Signal, minLabel: S0, maxLabel: "+60", hold: 1500 }
      - type: ledBar
        value: rig.signalDbm
        min: -127
        max: -19
        segments: 18
        span: [3, 1]
        label: S
        zones: [[-73, error]]
  - type: group
    title: Transmit
    columns: 6
    items:
      - { type: bar, value: rig.powerOut, min: 0, max: 100, label: Power, span: [3, 1] }
      - { type: bar, value: rig.swr, min: 1, max: 3, label: SWR, color: error, span: [3, 1] }
      - type: knob
        var: drive
        min: 5
        max: 100
        step: 5
        label: Drive
        onChange: { setRadio: { source: rig, powerWatts: $value } }
      - type: button
        label: Tune
        onPress: { setRadio: { source: rig, startTune: true } }
      - type: readout
        value: rig.alc
        label: ALC
        decimals: 1
  - type: group
    title: Rotator
    columns: 6
    items:
      - { type: readout, value: rot.azimuth, label: Heading, suffix: "°", decimals: 0 }
      - { type: button, label: N, span: [1, 1], onPress: { turnRotator: { source: rot, azimuth: 0 } } }
      - { type: button, label: E, span: [1, 1], onPress: { turnRotator: { source: rot, azimuth: 90 } } }
      - { type: button, label: S, span: [1, 1], onPress: { turnRotator: { source: rot, azimuth: 180 } } }
      - { type: button, label: W, span: [1, 1], onPress: { turnRotator: { source: rot, azimuth: 270 } } }
      - { type: button, label: Stop, onPress: { stopRotator: { source: rot } } }
`
