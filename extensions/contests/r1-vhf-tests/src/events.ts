// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The named IARU Region 1 VHF+ contest instances, ported from app-polo's
// `r1-vhf-tests/all-events.js`. Every event here sends the same exchange
// (serial number + 6-character grid) and scores the same way (great-circle
// distance × a per-band multiplier) — `rsgb-vhf-tests` shares this shape but
// adds a district/postcode exchange field and a district-bonus scoring rule
// neither this file nor scorer.ts needs to know about.

import { EHF_BANDS, SHF_BANDS, UHF_BANDS, VHF_BANDS } from "@ham2k/lib-operation-data"

export interface R1VhfEvent {
  key: string
  name: string
  short: string
  bands: string[]
}

const ALL_BANDS = [...VHF_BANDS, ...UHF_BANDS, ...SHF_BANDS, ...EHF_BANDS]

const EVENTS: R1VhfEvent[] = [
  { key: 'R1-VHF-SUB1-MARCH', name: 'Subregional 1 - March', short: 'March VHF Test', bands: ALL_BANDS },
  { key: 'R1-VHF-SUB2-MAY', name: 'Subregional 2 - May', short: 'May VHF Test', bands: ALL_BANDS },
  { key: 'R1-VHF-SUB3-JULY', name: 'Subregional 3 - July', short: 'July VHF Test', bands: ALL_BANDS },
  { key: 'R1-VHF-50-JUNE', name: '50 MHz CW/SSB - June', short: '50 MHz Test', bands: ['6m'] },
  { key: 'R1-VHF-70-JULY', name: '70 MHz CW/SSB - July', short: '70 MHz Test', bands: ['4m'] },
  { key: 'R1-VHF-145-SEPTEMBER', name: '145 MHz CW/SSB - September', short: '145 MHz Test', bands: ['2m'] },
  { key: 'R1-VHF-UHF-OCTOBER', name: 'UHF - October', short: 'UHF Test', bands: [...UHF_BANDS, ...SHF_BANDS, ...EHF_BANDS] },
  { key: 'R1-VHF-MARCONI-NOVEMBER', name: 'Marconi Memorial CW 145 MHz - November', short: 'Marconi Memorial', bands: ['2m'] },
]

const EVENTS_BY_KEY: Record<string, R1VhfEvent> = Object.fromEntries(EVENTS.map((e) => [e.key, e]))

export function eventFor(key: string | undefined | null): R1VhfEvent | undefined {
  return key ? EVENTS_BY_KEY[key] : undefined
}

export { EVENTS }
