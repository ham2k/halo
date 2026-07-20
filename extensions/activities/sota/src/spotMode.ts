// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { ADIF_SUBMODES } from "@ham2k/lib-operation-data"

// The SOTAwatch spot API only accepts these mode values (note the mixed
// case — they are not ADIF modes). Ported from app-polo's SOTAPostSelfSpot.
const VALID_SPOT_MODES = ['AM', 'CW', 'DATA', 'DV', 'FM', 'SSB']

/// Maps a logged ADIF mode/submode to the closest SOTAwatch spot mode.
export function spotModeFor(mode: string | undefined): string {
  const upper = (mode ?? '').toUpperCase()
  if (VALID_SPOT_MODES.includes(upper)) {
    // The API wants 'Data' capitalized exactly so
    return upper === 'DATA' ? 'Data' : upper
  }
  if (ADIF_SUBMODES.SSB.includes(upper)) return 'SSB'
  if (upper === 'DIGITALVOICE' || ADIF_SUBMODES.DIGITALVOICE.includes(upper)) return 'DV'
  return 'Data' // Reasonable guess
}
