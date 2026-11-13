// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// What an agent app can ask of the station. Each tool is one of the host's
// own calls, under the same grants an assistant has.

import type { GetSpotsOptions, host, JSONValue } from "@ham2k/extension-sdk"
import type { Tool } from "./mcp.ts"

export function stationTools(station: Pick<typeof host, "readRadio">): Tool[] {
  return [
    {
      name: "get_radio",
      title: "Radio",
      description: "The radio's frequency (kHz), band, mode, power and meters, as the app last read them. Null when no radio is connected.",
      inputSchema: { type: "object", properties: {}, additionalProperties: false },
      access: "watch",
      run: async () => ((await station.readRadio()) ?? null) as unknown as JSONValue,
    },
    {
      name: "get_spots",
      title: "Spots",
      description: "Spots the app holds, as the operator's Spots panel filters them: call, frequency (kHz), mode and source.",
      inputSchema: {
        type: "object",
        properties: {
          band: { type: "string", description: "A band, as the app writes it: '20m'." },
          mode: { type: "string", description: "A mode ('FT8') or a family ('CW', 'Phone', 'Digital')." },
          maxAgeMinutes: { type: "number", description: "Only spots this recent." },
          limit: { type: "number", description: "At most this many, newest first. Default 50." },
        },
        additionalProperties: false,
      },
      access: "watch",
      run: async (args, ctx) => {
        if (!ctx.getSpots) throw new Error("This app cannot list spots")
        const options: GetSpotsOptions = {}
        if (typeof args.band === "string") options.band = args.band
        if (typeof args.mode === "string") options.mode = args.mode
        if (typeof args.maxAgeMinutes === "number") options.maxAgeMinutes = args.maxAgeMinutes
        const limit = typeof args.limit === "number" && args.limit > 0 ? Math.min(args.limit, 500) : 50
        const spots = await ctx.getSpots(options)
        return { spots: spots.slice(0, limit) } as unknown as JSONValue
      },
    },
  ]
}
