// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// SAMPLE — a callsign lookup source, with the credentials one needs.
//
// HamQTH's XML API is free and its shape is the common one: log in once with a
// username and password, get a session id back, and spend that id on lookups
// until it expires. So this sample is really two things an extension author
// needs together — the `lookup` hook that answers about a callsign, and the
// `account` hook that is the ONLY way to ask an operator for a secret.
//
// Never put a password in a settings field of your own: `account` stores
// credentials in the platform keychain, keeps the session out of your hands,
// and gives the operator one place to see what they have connected. A `secret`
// field in a settings panel is for a bare API key with no login behind it.
//
// What this sample leaves out: the country-file cross-checks, the
// already-know-enough short circuits, and the per-call caching a production
// source wants. Read `docs/hooks.md` §`lookup` before shipping one.

import { defineExtension, host } from "@ham2k/extension-sdk"
import type { AnnotatedCallInfo, CallInfoLookup, HookContext, JSONValue, LookupResult } from "@ham2k/extension-sdk"
import { cleanLocationParams } from "@ham2k/lib-geo-tools"

import manifest from "../manifest.json" with { type: "json" }

const API = "https://www.hamqth.com/xml.php"

/// HamQTH asks every caller to identify itself, and rejects an empty `prg`.
const PROGRAM = "ham2k-sample"

/// HamQTH's XML is flat and carries no attributes worth reading, so a tag
/// extractor beats a parser the sandbox would have to ship.
function tag(xml: string, name: string): string | undefined {
  return xml.match(new RegExp(`<${name}[^>]*>([^<]*)</${name}>`, "i"))?.[1]?.trim() || undefined
}

/// Trades the operator's credentials for a session id, and hands it to the
/// host to hold.
///
/// `host.setAccountSession` rather than a module variable or `host.kvSet`: the
/// session outlives a reload of this extension, and it is a credential — the
/// host keeps it beside the password rather than in your storage.
async function login(ctx: HookContext): Promise<string> {
  const username = ctx.account?.credentials?.username
  const password = ctx.account?.credentials?.password
  if (!username || !password) throw new Error("No HamQTH account configured")

  const response = await host.fetch(`${API}?u=${encodeURIComponent(username)}&p=${encodeURIComponent(password)}`)
  const sessionId = tag(response.body, "session_id")
  if (!sessionId) throw new Error(tag(response.body, "error") ?? `HTTP ${response.status}`)

  await host.setAccountSession({ sessionId })
  return sessionId
}

/// One lookup, renewing the session if this one has aged out.
///
/// HamQTH sessions expire on their own schedule, so an expired one is a normal
/// Tuesday rather than an error: the retry is the happy path, not recovery.
/// Note that it re-logs-in only ONCE — a second failure is a real one, and
/// looping on it would hammer the API behind the operator's back.
async function fetchCall(call: string, ctx: HookContext): Promise<string> {
  const search = (id: string) => host.fetch(`${API}?id=${id}&callsign=${encodeURIComponent(call)}&prg=${PROGRAM}`)

  const sessionId = ctx.account?.session?.sessionId ?? (await login(ctx))
  const response = await search(sessionId)

  if (/session does not exist|expired/i.test(tag(response.body, "error") ?? "")) {
    await host.setAccountSession({})
    return (await search(await login(ctx))).body
  }
  return response.body
}

async function lookupCall(
  { callInfo }: { callInfo: AnnotatedCallInfo; qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
  ctx: HookContext,
): Promise<LookupResult> {
  const call = (callInfo.call || "").trim().toUpperCase()
  // Offline, or too short to be a callsign: answer with nothing rather than
  // spend a round-trip. `ctx.online` is the host's own answer, and a lookup
  // hook runs on the typing path.
  if (call.length < 3 || !ctx.online) return []

  try {
    const xml = await fetchCall(call, ctx)

    const error = tag(xml, "error")
    if (error) {
      // "Callsign not found" is an ANSWER, not a fault — most operators work
      // stations HamQTH has never heard of, and logging each one would bury
      // the errors that matter (a bad password, a subscription problem).
      if (!/not found/i.test(error)) host.log(`HamQTH said: ${error}`)
      return []
    }

    // `<nick>` is a SHORTER FORM of the same name rather than a handle the
    // operator also goes by: "Martin" against an `<adr_name>` of "Martin
    // Kratoska", "Sebastian Delmont" against "Sebastian D Delmont", and for
    // W1AW the identical string twice. Appending it reads as information and
    // is not, so the full name wins and the nickname is only a fallback.
    //
    // QRZ's `nickname` deliberately goes the other way — there it IS what the
    // operator goes by on the air, and its extension shows both. Same-looking
    // field, opposite verdict; don't make the two consistent.
    const name = tag(xml, "adr_name") ?? tag(xml, "nick")

    const city = tag(xml, "adr_city")
    const state = tag(xml, "us_state")

    // The coordinate AND the grid. HamQTH reports both, and where a pair is
    // present it outranks the locator — a lookup that kept only the grid would
    // throw away the more precise of the two answers it was given. Parsed
    // through `cleanLocationParams` rather than `Number`, because a service
    // that has no fix for a record says so with an empty string, a "0", or a
    // pair of zeroes, and none of those is a place.
    const [lat, lon] = cleanLocationParams(tag(xml, "latitude"), tag(xml, "longitude"))

    const result: CallInfoLookup = {
      // HamQTH answers in lower case, whatever was asked.
      call: tag(xml, "callsign")?.toUpperCase() ?? call,
      // Named so the app can say where this came from, and so the merge can
      // tell your answer from another source's.
      source: "hamqth.com",
      scope: "general",
      name,
      location: [city, state].filter((x) => x).join(", "),
      city,
      state,
      country: tag(xml, "country"),
      grid: tag(xml, "grid"),
      lat,
      lon,
    }
    return [result]
  } catch (e) {
    // A lookup that throws takes down the call-info panel for every source,
    // not just this one.
    host.log(`HamQTH lookup failed for ${call}: ${(e as Error).message ?? e}`)
    return []
  }
}

/// What the operator fills in under Settings → Accounts.
///
/// `testCredentials` returns a STRING to show them — it is the only feedback
/// they get that a password is right, so make it name what was found rather
/// than saying "OK".
const HamQTHAccount = {
  label: "HamQTH.com",
  description: "A free account at hamqth.com, for callsign lookups",
  kvKey: "k2hrc-hamqth",
  // The same login on every device the operator owns, so it rides iCloud
  // Keychain. A per-install credential (a device key, a sync token) must NOT
  // set this.
  synchronizable: true,
  fields: [
    { key: "username", label: "Username", type: "text" as const },
    { key: "password", label: "Password", type: "secret" as const },
  ],

  async testCredentials(credentials: Record<string, string>, _ctx: HookContext): Promise<string> {
    const username = (credentials.username || "").trim()
    if (!username || !credentials.password) return "Enter your HamQTH username and password"

    try {
      const response = await host.fetch(`${API}?u=${encodeURIComponent(username)}&p=${encodeURIComponent(credentials.password)}`)
      const sessionId = tag(response.body, "session_id")
      if (!sessionId) return tag(response.body, "error") ?? `HamQTH returned HTTP ${response.status}`

      const check = await host.fetch(`${API}?id=${sessionId}&callsign=${encodeURIComponent(username)}&prg=${PROGRAM}`)
      const name = tag(check.body, "adr_name")
      return `✅ ${username.toUpperCase()}${name ? `: ${name}` : ""}`
    } catch (e) {
      return `Could not reach HamQTH: ${(e as Error).message ?? e}`
    }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    // No `priority`, which means 0 — and 0 is where a third-party callbook
    // belongs. The ladder it lands in: the operator's own call notes at 100,
    // QRZ at 99, the Ham2K lookup service at 10, and Call History last at -1,
    // deliberately below the 0 an undeclared hook defaults to, because the log
    // describes a station whenever it was last worked while a live source
    // describes it today.
    //
    // So the default already reads "a real source, but not one that outranks
    // what the operator typed or what the core provides". Set a priority only
    // when you mean to move against that, and know which source you are
    // stepping over.
    registerHook("lookup", { hook: { lookupCall }, key: manifest.key })
    registerHook("account", { hook: HamQTHAccount, key: manifest.key })
  },
})
