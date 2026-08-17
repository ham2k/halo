// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The named RSGB VHF+ contest instances, ported from app-polo's
// `rsgb-vhf-tests/all-events.js`. 124 events, almost all monthly recurring
// series (UKAC/FMAC/Trophy/AFS/CW/LP/Xmas) that share one shape: serial +
// 6-character grid exchange, distance × band-multiplier scoring, no bonus.
// Only the five "Backpackers" events diverge — `exchange` adds a postcode
// district, and `bonus` awards extra points per first-worked grid/district/
// DXCC entity on a band, which scorer.ts reads when present.
//
// Generated from polo's data with a throwaway script rather than hand-typed
// (124 near-identical entries invite transcription errors a script doesn't
// make) — verified event-count and no-duplicate-key against the source, and
// corrected one data bug found in the process: RSGB-144-FMAC-MAR's `short`
// read "Jan 144 FMAC" in app-polo (a copy-paste leftover from the January
// entry) — fixed here to "Mar 144 FMAC".

export type RsgbBonusKind = 'newGrid' | 'newDistrict' | 'newDXCC'

export interface RsgbVhfEvent {
  key: string
  name: string
  short: string
  bands: string[]
  /// Absent means the default: `['number', 'grid6']`.
  exchange?: ('number' | 'grid6' | 'district')[]
  /// Points awarded per distinct band×{grid4|district|DXCC-entity} the
  /// operation works during the event — accumulated once per novel
  /// combination, not per QSO (see scorer.ts's `accumulateScore`).
  bonus?: Partial<Record<RsgbBonusKind, number>>
}

const EVENTS: RsgbVhfEvent[] = [
  { key: "RSGB-BACKPACKERS-1", name: "1st 144MHz Backpackers", short: "1st Backpackers", bands: ["2m"], exchange: ["number", "grid6", "district"], bonus: { newGrid: 200, newDistrict: 200, newDXCC: 200 } },
  { key: "RSGB-BACKPACKERS-2", name: "2nd 144MHz Backpackers", short: "2nd Backpackers", bands: ["2m"], exchange: ["number", "grid6"], bonus: { newGrid: 200, newDXCC: 200 } },
  { key: "RSGB-BACKPACKERS-3", name: "3rd 144MHz Backpackers", short: "3rd Backpackers", bands: ["2m"], exchange: ["number", "grid6"], bonus: { newGrid: 500 } },
  { key: "RSGB-BACKPACKERS-4", name: "4th 144MHz Backpackers", short: "4th Backpackers", bands: ["2m"], exchange: ["number", "grid6", "district"], bonus: { newGrid: 200, newDistrict: 200, newDXCC: 200 } },
  { key: "RSGB-BACKPACKERS-5", name: "5th 144MHz Backpackers", short: "5th Backpackers", bands: ["2m"], exchange: ["number", "grid6"], bonus: { newGrid: 500 } },
  { key: "RSGB-70-AFS", name: "70MHz AFS Contest", short: "70MHz AFS", bands: ["4m"] },
  { key: "RSGB-50-AFS", name: "50MHz AFS Contest", short: "50MHz AFS", bands: ["6m"] },
  { key: "RSGB-144-AFS", name: "144MHz AFS", short: "144MHz AFS", bands: ["2m"] },
  { key: "RSGB-432-AFS", name: "432MHz AFS", short: "432MHz AFS", bands: ["70cm"] },
  { key: "RSGB-144-432-MARCH", name: "March 144 432MHz", short: "March 144-432", bands: ["2m", "70cm"] },
  { key: "RSGB-432-245-MAY", name: "May 432MHz-245GHz", short: "May 432MHz-245GHz", bands: ["70cm", "33cm", "23cm", "13cm", "9cm", "6cm", "3cm", "1.25cm", "6mm", "4mm", "2mm", "2.5mm", "1mm", "submm"] },
  { key: "RSGB-432-245-OCT", name: "October 432MHz-245GHz", short: "Oct 432MHz-245GHz", bands: ["70cm", "33cm", "23cm", "13cm", "9cm", "6cm", "3cm", "1.25cm", "6mm", "4mm", "2mm", "2.5mm", "1mm", "submm"] },
  { key: "RSGB-144-MAY", name: "May 144MHz Contest", short: "May 144MHz", bands: ["2m"] },
  { key: "RSGB-70-TROPHY", name: "70MHz Trophy Contest", short: "70MHz Trophy", bands: ["4m"] },
  { key: "RSGB-50-TROPHY", name: "50MHz Trophy Contest", short: "50MHz Trophy", bands: ["6m"] },
  { key: "RSGB-144-TROPHY", name: "144MHz Trophy Contest", short: "144MHz Trophy", bands: ["2m"] },
  { key: "RSGB-432-TROPHY", name: "432MHz Trophy Contest", short: "432MHz Trophy", bands: ["70cm"] },
  { key: "RSGB-2300-TROPHY", name: "2.3GHz Trophy Contest", short: "2.3GHz Trophy", bands: ["13cm"] },
  { key: "RSGB-1300-TROPHY", name: "1.3GHz Trophy Contest", short: "1.3GHz Trophy", bands: ["23cm"] },
  { key: "RSGB-10G-TROPHY", name: "10GHz Trophy Contest", short: "10GHz Trophy", bands: ["3cm"] },
  { key: "RSGB-70-CW", name: "70MHz Contest CW", short: "70MHz CW", bands: ["4m"] },
  { key: "RSGB-50-CW", name: "50MHz Contest CW", short: "50MHz CW", bands: ["6m"] },
  { key: "RSGB-144-LP", name: "144MHz Low Power Contest", short: "144MHz LP", bands: ["2m"] },
  { key: "RSGB-432-LP", name: "432MHz Low Power Contest", short: "432MHz LP", bands: ["70cm"] },
  { key: "RSGB-144-MARCONI", name: "144MHz CW Marconi", short: "144 CW Marconi", bands: ["2m"] },
  { key: "RSGB-70-XMAS", name: "70MHz Christmas Contest", short: "70MHz Xmas", bands: ["4m"] },
  { key: "RSGB-50-XMAS", name: "50MHz Christmas Contest", short: "50MHz Xmas", bands: ["6m"] },
  { key: "RSGB-144-XMAS", name: "144MHz Christmas Contest", short: "144MHz Xmas", bands: ["2m"] },
  { key: "RSGB-432-XMAS", name: "432MHz Christmas Contest", short: "432MHz Xmas", bands: ["70cm"] },
  { key: "RSGB-144-FMAC-JAN", name: "January 144MHz FMAC", short: "Jan 144 FMAC", bands: ["2m"] },
  { key: "RSGB-144-FMAC-FEB", name: "February 144MHz FMAC", short: "Feb 144 FMAC", bands: ["2m"] },
  { key: "RSGB-144-FMAC-MAR", name: "March 144MHz FMAC", short: "Mar 144 FMAC", bands: ["2m"] },
  { key: "RSGB-144-FMAC-APR", name: "April 144MHz FMAC", short: "Apr 144 FMAC", bands: ["2m"] },
  { key: "RSGB-144-FMAC-MAY", name: "May 144MHz FMAC", short: "May 144 FMAC", bands: ["2m"] },
  { key: "RSGB-144-FMAC-JUN", name: "June 144MHz FMAC", short: "Jun 144 FMAC", bands: ["2m"] },
  { key: "RSGB-144-FMAC-JUL", name: "July 144MHz FMAC", short: "Jul 144 FMAC", bands: ["2m"] },
  { key: "RSGB-144-FMAC-AUG", name: "August 144MHz FMAC", short: "Aug 144 FMAC", bands: ["2m"] },
  { key: "RSGB-144-FMAC-SEP", name: "September 144MHz FMAC", short: "Sep 144 FMAC", bands: ["2m"] },
  { key: "RSGB-144-FMAC-OCT", name: "October 144MHz FMAC", short: "Oct 144 FMAC", bands: ["2m"] },
  { key: "RSGB-144-FMAC-NOV", name: "November 144MHz FMAC", short: "Nov 144 FMAC", bands: ["2m"] },
  { key: "RSGB-144-FMAC-DEC", name: "December 144MHz FMAC", short: "Dec 144 FMAC", bands: ["2m"] },
  { key: "RSGB-432-FMAC-JAN", name: "January 432MHz FMAC", short: "Jan 432 FMAC", bands: ["70cm"] },
  { key: "RSGB-432-FMAC-FEB", name: "February 432MHz FMAC", short: "Feb 432 FMAC", bands: ["70cm"] },
  { key: "RSGB-432-FMAC-MAR", name: "March 432MHz FMAC", short: "Mar 432 FMAC", bands: ["70cm"] },
  { key: "RSGB-432-FMAC-APR", name: "April 432MHz FMAC", short: "Apr 432 FMAC", bands: ["70cm"] },
  { key: "RSGB-432-FMAC-MAY", name: "May 432MHz FMAC", short: "May 432 FMAC", bands: ["70cm"] },
  { key: "RSGB-432-FMAC-JUN", name: "June 432MHz FMAC", short: "Jun 432 FMAC", bands: ["70cm"] },
  { key: "RSGB-432-FMAC-JUL", name: "July 432MHz FMAC", short: "Jul 432 FMAC", bands: ["70cm"] },
  { key: "RSGB-432-FMAC-AUG", name: "August 432MHz FMAC", short: "Aug 432 FMAC", bands: ["70cm"] },
  { key: "RSGB-432-FMAC-SEP", name: "September 432MHz FMAC", short: "Sep 432 FMAC", bands: ["70cm"] },
  { key: "RSGB-432-FMAC-OCT", name: "October 432MHz FMAC", short: "Oct 432 FMAC", bands: ["70cm"] },
  { key: "RSGB-432-FMAC-NOV", name: "November 432MHz FMAC", short: "Nov 432 FMAC", bands: ["70cm"] },
  { key: "RSGB-432-FMAC-DEC", name: "December 432MHz FMAC", short: "Dec 432 FMAC", bands: ["70cm"] },
  { key: "RSGB-144-UKAC-JAN", name: "January 144MHz UKAC", short: "Jan 144 UKAC", bands: ["2m"] },
  { key: "RSGB-144-UKAC-FEB", name: "February 144MHz UKAC", short: "Feb 144 UKAC", bands: ["2m"] },
  { key: "RSGB-144-UKAC-MAR", name: "March 144MHz UKAC", short: "Mar 144 UKAC", bands: ["2m"] },
  { key: "RSGB-144-UKAC-APR", name: "April 144MHz UKAC", short: "Apr 144 UKAC", bands: ["2m"] },
  { key: "RSGB-144-UKAC-MAY", name: "May 144MHz UKAC", short: "May 144 UKAC", bands: ["2m"] },
  { key: "RSGB-144-UKAC-JUN", name: "June 144MHz UKAC", short: "Jun 144 UKAC", bands: ["2m"] },
  { key: "RSGB-144-UKAC-JUL", name: "July 144MHz UKAC", short: "Jul 144 UKAC", bands: ["2m"] },
  { key: "RSGB-144-UKAC-AUG", name: "August 144MHz UKAC", short: "Aug 144 UKAC", bands: ["2m"] },
  { key: "RSGB-144-UKAC-SEP", name: "September 144MHz UKAC", short: "Sep 144 UKAC", bands: ["2m"] },
  { key: "RSGB-144-UKAC-OCT", name: "October 144MHz UKAC", short: "Oct 144 UKAC", bands: ["2m"] },
  { key: "RSGB-144-UKAC-NOV", name: "November 144MHz UKAC", short: "Nov 144 UKAC", bands: ["2m"] },
  { key: "RSGB-144-UKAC-DEC", name: "December 144MHz UKAC", short: "Dec 144 UKAC", bands: ["2m"] },
  { key: "RSGB-432-UKAC-JAN", name: "January 432MHz UKAC", short: "Jan 432 UKAC", bands: ["70cm"] },
  { key: "RSGB-432-UKAC-FEB", name: "February 432MHz UKAC", short: "Feb 432 UKAC", bands: ["70cm"] },
  { key: "RSGB-432-UKAC-MAR", name: "March 432MHz UKAC", short: "Mar 432 UKAC", bands: ["70cm"] },
  { key: "RSGB-432-UKAC-APR", name: "April 432MHz UKAC", short: "Apr 432 UKAC", bands: ["70cm"] },
  { key: "RSGB-432-UKAC-MAY", name: "May 432MHz UKAC", short: "May 432 UKAC", bands: ["70cm"] },
  { key: "RSGB-432-UKAC-JUN", name: "June 432MHz UKAC", short: "Jun 432 UKAC", bands: ["70cm"] },
  { key: "RSGB-432-UKAC-JUL", name: "July 432MHz UKAC", short: "Jul 432 UKAC", bands: ["70cm"] },
  { key: "RSGB-432-UKAC-AUG", name: "August 432MHz UKAC", short: "Aug 432 UKAC", bands: ["70cm"] },
  { key: "RSGB-432-UKAC-SEP", name: "September 432MHz UKAC", short: "Sep 432 UKAC", bands: ["70cm"] },
  { key: "RSGB-432-UKAC-OCT", name: "October 432MHz UKAC", short: "Oct 432 UKAC", bands: ["70cm"] },
  { key: "RSGB-432-UKAC-NOV", name: "November 432MHz UKAC", short: "Nov 432 UKAC", bands: ["70cm"] },
  { key: "RSGB-432-UKAC-DEC", name: "December 432MHz UKAC", short: "Dec 432 UKAC", bands: ["70cm"] },
  { key: "RSGB-70-UKAC-JAN", name: "70MHz UKAC", short: "70MHz UKAC", bands: ["4m"] },
  { key: "RSGB-70-UKAC-FEB", name: "February 70MHz UKAC", short: "Feb 70MHz UKAC", bands: ["4m"] },
  { key: "RSGB-70-UKAC-MAR", name: "March 70MHz UKAC", short: "Mar 70MHz UKAC", bands: ["4m"] },
  { key: "RSGB-70-UKAC-APR", name: "April 70MHz UKAC", short: "Apr 70MHz UKAC", bands: ["4m"] },
  { key: "RSGB-70-UKAC-MAY", name: "May 70MHz UKAC", short: "May 70MHz UKAC", bands: ["4m"] },
  { key: "RSGB-70-UKAC-JUN", name: "June 70MHz UKAC", short: "Jun 70MHz UKAC", bands: ["4m"] },
  { key: "RSGB-70-UKAC-JUL", name: "July 70MHz UKAC", short: "Jul 70MHz UKAC", bands: ["4m"] },
  { key: "RSGB-70-UKAC-AUG", name: "August 70MHz UKAC", short: "Aug 70MHz UKAC", bands: ["4m"] },
  { key: "RSGB-70-UKAC-SEP", name: "September 70MHz UKAC", short: "Sep 70MHz UKAC", bands: ["4m"] },
  { key: "RSGB-70-UKAC-OCT", name: "October 70MHz UKAC", short: "Oct 70MHz UKAC", bands: ["4m"] },
  { key: "RSGB-70-UKAC-NOV", name: "November 70MHz UKAC", short: "Nov 70MHz UKAC", bands: ["4m"] },
  { key: "RSGB-70-UKAC-DEC", name: "December 70MHz UKAC", short: "Dec 70MHz UKAC", bands: ["4m"] },
  { key: "RSGB-50-UKAC-JAN", name: "January 50MHz UKAC", short: "Jan 50MHz UKAC", bands: ["6m"] },
  { key: "RSGB-50-UKAC-FEB", name: "50MHz UKAC", short: "50MHz UKAC", bands: ["6m"] },
  { key: "RSGB-50-UKAC-MAR", name: "March 50MHz UKAC", short: "Mar 50MHz UKAC", bands: ["6m"] },
  { key: "RSGB-50-UKAC-APR", name: "April 50MHz UKAC", short: "Apr 50MHz UKAC", bands: ["6m"] },
  { key: "RSGB-50-UKAC-MAY", name: "May 50MHz UKAC", short: "May 50MHz UKAC", bands: ["6m"] },
  { key: "RSGB-50-UKAC-JUN", name: "June 50MHz UKAC", short: "Jun 50MHz UKAC", bands: ["6m"] },
  { key: "RSGB-50-UKAC-JUL", name: "July 50MHz UKAC", short: "Jul 50MHz UKAC", bands: ["6m"] },
  { key: "RSGB-50-UKAC-AUG", name: "August 50MHz UKAC", short: "Aug 50MHz UKAC", bands: ["6m"] },
  { key: "RSGB-50-UKAC-SEP", name: "September 50MHz UKAC", short: "Sep 50MHz UKAC", bands: ["6m"] },
  { key: "RSGB-50-UKAC-OCT", name: "October 50MHz UKAC", short: "Oct 50MHz UKAC", bands: ["6m"] },
  { key: "RSGB-50-UKAC-NOV", name: "November 50MHz UKAC", short: "Nov 50MHz UKAC", bands: ["6m"] },
  { key: "RSGB-50-UKAC-DEC", name: "December 50MHz UKAC", short: "Dec 50MHz UKAC", bands: ["6m"] },
  { key: "RSGB-SHF-UKAC-JAN", name: "SHF UKAC", short: "SHF UKAC", bands: ["13cm", "9cm", "6cm", "3cm"] },
  { key: "RSGB-SHF-UKAC-FEB", name: "February SHF UKAC", short: "Feb SHF UKAC", bands: ["13cm", "9cm", "6cm", "3cm"] },
  { key: "RSGB-SHF-UKAC-MAR", name: "March SHF UKAC", short: "Mar SHF UKAC", bands: ["13cm", "9cm", "6cm", "3cm"] },
  { key: "RSGB-SHF-UKAC-APR", name: "April SHF UKAC", short: "Apr SHF UKAC", bands: ["13cm", "9cm", "6cm", "3cm"] },
  { key: "RSGB-SHF-UKAC-MAY", name: "May SHF UKAC", short: "May SHF UKAC", bands: ["13cm", "9cm", "6cm", "3cm"] },
  { key: "RSGB-SHF-UKAC-JUN", name: "June SHF UKAC", short: "Jun SHF UKAC", bands: ["13cm", "9cm", "6cm", "3cm"] },
  { key: "RSGB-SHF-UKAC-JUL", name: "July SHF UKAC", short: "Jul SHF UKAC", bands: ["13cm", "9cm", "6cm", "3cm"] },
  { key: "RSGB-SHF-UKAC-AUG", name: "August SHF UKAC", short: "Aug SHF UKAC", bands: ["13cm", "9cm", "6cm", "3cm"] },
  { key: "RSGB-SHF-UKAC-SEP", name: "September SHF UKAC", short: "Sep SHF UKAC", bands: ["13cm", "9cm", "6cm", "3cm"] },
  { key: "RSGB-SHF-UKAC-OCT", name: "October SHF UKAC", short: "Oct SHF UKAC", bands: ["13cm", "9cm", "6cm", "3cm"] },
  { key: "RSGB-SHF-UKAC-NOV", name: "November SHF UKAC", short: "Nov SHF UKAC", bands: ["13cm", "9cm", "6cm", "3cm"] },
  { key: "RSGB-1300-UKAC-JAN", name: "January 1.3GHz UKAC", short: "Jan 1.3GHz UKAC", bands: ["23cm"] },
  { key: "RSGB-1300-UKAC-FEB", name: "February 1.3GHz UKAC", short: "Feb 1.3GHz UKAC", bands: ["23cm"] },
  { key: "RSGB-1300-UKAC-MAR", name: "March 1.3GHz UKAC", short: "Mar 1.3GHz UKAC", bands: ["23cm"] },
  { key: "RSGB-1300-UKAC-APR", name: "April 1.3GHz UKAC", short: "Apr 1.3GHz UKAC", bands: ["23cm"] },
  { key: "RSGB-1300-UKAC-MAY", name: "May 1.3GHz UKAC", short: "May 1.3GHz UKAC", bands: ["23cm"] },
  { key: "RSGB-1300-UKAC-JUN", name: "June 1.3GHz UKAC", short: "Jun 1.3GHz UKAC", bands: ["23cm"] },
  { key: "RSGB-1300-UKAC-JUL", name: "July 1.3GHz UKAC", short: "Jul 1.3GHz UKAC", bands: ["23cm"] },
  { key: "RSGB-1300-UKAC-AUG", name: "August 1.3GHz UKAC", short: "Aug 1.3GHz UKAC", bands: ["23cm"] },
  { key: "RSGB-1300-UKAC-SEP", name: "September 1.3GHz UKAC", short: "Sep 1.3GHz UKAC", bands: ["23cm"] },
  { key: "RSGB-1300-UKAC-OCT", name: "October 1.3GHz UKAC", short: "Oct 1.3GHz UKAC", bands: ["23cm"] },
  { key: "RSGB-1300-UKAC-NOV", name: "November 1.3GHz UKAC", short: "Nov 1.3GHz UKAC", bands: ["23cm"] },
  { key: "RSGB-1300-UKAC-DEC", name: "December 1.3GHz UKAC", short: "Dec 1.3GHz UKAC", bands: ["23cm"] },
]

const EVENTS_BY_KEY: Record<string, RsgbVhfEvent> = Object.fromEntries(EVENTS.map((e) => [e.key, e]))

export function eventFor(key: string | undefined | null): RsgbVhfEvent | undefined {
  return key ? EVENTS_BY_KEY[key] : undefined
}

export function exchangeShape(event: RsgbVhfEvent): ('number' | 'grid6' | 'district')[] {
  return event.exchange ?? ['number', 'grid6']
}

export function hasDistrictExchange(event: RsgbVhfEvent): boolean {
  return exchangeShape(event).includes('district')
}

export { EVENTS }
