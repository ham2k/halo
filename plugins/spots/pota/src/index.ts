// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// POTA spots source. Deliberately imports @ham2k/lib-operation-data (the
// same npm package app-polo uses) to prove the spike goal that existing
// ham-js-libs run unchanged inside the plugin runtime.

import { bandForFrequency } from "@ham2k/lib-operation-data"

import { definePlugin, host } from "@ham2k/polo-sdk"
import type { HookContext, Spot } from "@ham2k/polo-sdk"

interface POTAApiSpot {
  spotId: number
  activator: string
  frequency: string
  mode: string
  reference: string
  name: string
  locationDesc: string
  spotTime: string
  spotter: string
  comments: string
  source: string
  count: number
}

const SpotsHook = {
  sourceName: 'POTA.app',

  async fetchSpots(_args: Record<string, never>, ctx: HookContext): Promise<Spot[]> {
    if (!ctx.online) return []

    const response = await host.fetch('https://api.pota.app/spot/activator')
    if (response.status !== 200) throw new Error(`POTA API returned HTTP ${response.status}`)
    const apiSpots = JSON.parse(response.body) as POTAApiSpot[]

    return apiSpots
      .filter((spot) => !spot.comments?.match(/QRT/i))
      .map((spot) => {
        const freq = parseFloat(spot.frequency)
        return {
          their: { call: spot.activator },
          freq,
          band: freq ? bandForFrequency(freq) : undefined,
          mode: spot.mode,
          refs: [{ ref: spot.reference, type: 'potaHunting' }],
          spot: {
            timeInMillis: Date.parse(spot.spotTime + 'Z'),
            source: 'pota-spots',
            label: `${spot.reference}: ${[simplifyStates(spot.locationDesc), spot.name].filter((x) => x).join(' • ')}`,
            sourceInfo: {
              source: spot.source,
              id: spot.spotId,
              comments: spot.comments,
              spotter: spot.spotter,
              count: spot.count,
            },
          },
        }
      })
  },
}

function simplifyStates(locationDesc: string): string {
  if (!locationDesc) return ''
  const states = locationDesc.split(',')
  const oneState = states[0].split('-', 2)[1]?.trim()
  return states.length > 1 ? `${oneState}+${states.length - 1}` : (oneState ?? '')
}

// definePlugin activates synchronously, so it must come after the hook
// definitions it registers.
definePlugin({
  key: 'pota-spots',
  name: 'POTA Spots',
  version: '0.0.1',
  onActivation({ registerHook }) {
    registerHook('spots', { hook: SpotsHook, key: 'pota' })
  },
})
