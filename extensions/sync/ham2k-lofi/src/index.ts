// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The `syncTransport` for Ham2K's LoFi sync server, ported from app-polo's
// Ham2KLoFiSyncExtension.js. Batching and dirty-flag bookkeeping stay in
// Dart (DESIGN.md §4) — this extension only knows how to authenticate as a
// device and move a payload of already-selected records over HTTP.
//
// The host seeds this extension's KV namespace at boot (see
// ExtensionService.setSyncCredentials): `key` (stable per-install device
// id), `call` (operator callsign), and — in builds that define
// HAM2K_LOFI_SECRET — `secret`, the app-attestation value app-polo gets
// from its build config; without it registration sends the same
// 'no-secret' fallback app-polo dev builds use. `token` is deliberately
// NOT seeded: `host.kv` is in-memory per process, so the token written
// below only survives within one run and each launch re-registers,
// matching app-polo's memory-only `GLOBAL.syncLoFiToken`. In builds that
// define HAM2K_BACKUP_TOKEN, the same seeding also sets `backupToken` —
// unset means `sync`'s fallback capture (below) is a no-op, same shape as
// the LoFi secret.

import { defineExtension, host } from "@ham2k/extension-sdk"
import type { CommandCatalogEntry, CommandInterpretation, HookContext, JSONValue, SyncPayload, SyncResponse } from "@ham2k/extension-sdk"

import { LoFiRequestError, shouldCaptureToBackup, backupCaptureAlsoFailedMessage } from "./backupCapture.ts"
import { clientIdentityFrom, requireWebhookIdentity } from "./clientIdentity.ts"
import { isRecognizableSyncResponse, isUnparseableBody, loFiErrorMessage, normalizedEmail, REPORTS_PATH, reportFailureMessage } from "./errors.ts"
import { tFor } from "./i18n.ts"
import { attachReportContext, buildReportPayload } from "./report.ts"
import type { ReportContext, ReportPayload } from "./report.ts"

import manifest from "../manifest.json" with { type: "json" }

export const DEFAULT_LOFI_SERVER = "https://lofi.ham2k.net"
export const DEFAULT_BACKUP_SERVICE_URL = "https://backup.ham2k.online"
const DEFAULT_SECRET = "no-secret"
// The host stamps HaLo's canonical User-Agent on every host.fetch call (see
// docs/design/network.md), so this extension doesn't set its own.

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("syncTransport", {
      hook: {
        sync,
        getAccountData,
        linkClient,
        linkClientWithEmail,
        setAccountEmail,
        resendAccountEmail,
        findLinkRequest,
        findLinkRequestByClient,
        approveLinkRequest,
        ensureClientRegistered,
        fetchWebhookEvents,
        submitReport,
      },
    })
    registerHook("command", { key: "ham2k-lofi-syncall", hook: { interpret: syncAllCommand, catalog: syncAllCatalog } })
    registerHook("command", { key: "ham2k-lofi-report", hook: { interpret: reportCommand, catalog: reportCatalog } })
  },
})

// Debug/utility command: wipes local operations/QSOs (backed up first, on
// the Dart side — see SyncEngine.forceFullResync) and re-runs a full
// backfill from the server. Typed into the call field, same as
// radio-commands' band/frequency/mode shortcuts.
async function syncAllCommand({ input }: { input: string }, ctx: HookContext): Promise<CommandInterpretation | null> {
  if (input.trim().toUpperCase() !== "SYNCALL") return null
  const t = tFor(ctx)
  return {
    describe: t("syncAllDescribe"),
    confirm: t("syncAllConfirm"),
    commands: [{ syncAll: {} }],
  }
}

async function syncAllCatalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
  const t = tFor(ctx)
  return [
    {
      command: "SYNCALL",
      describe: t("catalogSyncAll"),
      category: t("catalogCategory"),
    },
  ]
}

/// `[^]` rather than `.`, which excludes newlines: a description pasted from
/// an error message can carry a CR (Windows clipboard) or a line separator,
/// and the field's whitespace filter is off while a command takes free text.
/// Without this the whole paste stops matching and the Home bar clears it.
const REPORT_PATTERN = /^REPORT(?:\s+([^]*))?$/i

/// Files a bug report as a real CaBo card — works anywhere, no operation
/// needed. Only hits the network on the `execute: true` call (see
/// CommandHook.interpret's doc); a describe-preview call is free, the same
/// discipline SEED uses for its expensive work.
async function reportCommand(
  { input, operation, execute }: { input: string; operation?: Record<string, JSONValue>; execute?: boolean },
  ctx: HookContext,
): Promise<CommandInterpretation | null> {
  const match = REPORT_PATTERN.exec(input.trim())
  if (!match) return null

  const t = tFor(ctx)
  const text = match[1]?.trim()
  if (!text) return { expectsParams: true, mixedCase: true }

  // The describe states what a report may carry and does NOT quote the typed
  // text back: the dialog renders `describe` as one ellipsized line of
  // markdown (hooks.md), so interpolating the description both truncates this
  // warning away and reformats the user's own prose. The row's title already
  // shows what was typed, verbatim.
  if (!execute) return { mixedCase: true, describe: t("reportDescribe") }

  const filed = await fileReport((context) => buildReportPayload(text, context), {
    operation,
    needsSyncMessage: t("reportNeedsSync"),
    needsAccountMessage: t("reportNeedsAccount"),
  })
  if (filed.error != null) return { mixedCase: true, error: filed.error }
  const ref = filed.ref
  return { mixedCase: true, confirm: ref ? t("reportConfirmWithRef", { ref }) : t("reportConfirm") }
}

/// The one path to `POST v1/reports`: the sync gate, the context block, and
/// the request. Both surfaces that can file a report go through it, so the
/// refusal and the footer can't drift apart between them.
///
/// [compose] rather than a ready payload, because the context a payload needs
/// is exactly what this function fetches. Never throws — every caller here
/// wants the failure as operator-facing text, and the command surface in
/// particular must not throw (see [reportCommand]'s catch).
async function fileReport(
  compose: (context: ReportContext) => ReportPayload,
  {
    operation,
    needsSyncMessage,
    needsAccountMessage,
  }: {
    operation?: Record<string, JSONValue>
    needsSyncMessage: string
    needsAccountMessage: string
  },
): Promise<{ ref?: string | null; error?: string }> {
  try {
    // Only the version is required; the callsign merely decorates the card. A
    // bare Promise.all would let its failure destroy a report the operator has
    // already written — at the exact moment things are already going wrong,
    // which is when a report gets filed.
    const [version, settings] = await Promise.all([host.getVersionInfo(), host.getSettings().catch(() => null)])
    // Checked before request(), which registers this device with the server as
    // a side effect when no token is cached — persisting credentials for an
    // operator who never asked for sync, and then failing anyway, because a
    // client with no account behind it gets a 404 from v1/reports. Refusing on
    // an unreadable settings map is the fail-safe direction: the cost is a
    // report the operator can retry, against a write they never asked for.
    //
    // `syncEnabled` is the same gate the SYNCALL action uses host-side
    // (main.dart's handleCommandAction). It says sync is configured, not that a
    // link succeeded, so a linked-then-revoked account still reaches the 404 —
    // that error is at least about the account rather than a silent side effect.
    if (settings?.syncEnabled !== true) return { error: needsSyncMessage }
    const operatorCall = (typeof settings.operatorCall === "string" && settings.operatorCall) || null
    const payload = compose({ version, operatorCall, operation })
    const response = await request("POST", REPORTS_PATH, payload)
    const card = response.card as { ref?: JSONValue } | undefined
    return { ref: typeof card?.ref === "string" ? card.ref : null }
  } catch (e) {
    // Always an `error` result, never a throw. A command hook that throws is
    // wrapped by the kernel as a not-ok entry, and the host's interpret
    // fan-out keeps only the ok ones — so throwing here would leave the
    // operator staring at an unchanged field with no message at all, which is
    // the worst outcome for the one command whose job is reporting failure.
    return { error: reportFailureMessage(e, needsAccountMessage) }
  }
}

/// Files a report the host composed itself — the equipment editor's radio
/// report, whose title, body and kind are built from what the operator typed
/// and from what only Dart knows about the radio.
///
/// The host owns the wording of the card; this owns the account, the context
/// block and the POST — including the sync refusal, which stays here so both
/// surfaces refuse for the same reason in the same words. Errors come back as
/// `{error}` rather than as a throw, for the same reason [reportCommand]'s do:
/// the caller shows this to an operator who has just written something they
/// want sent.
async function submitReport(
  { title, body, kind }: { title: string; body: string; kind: ReportPayload["kind"] },
  ctx: HookContext,
): Promise<{ ref?: string | null; error?: string }> {
  const t = tFor(ctx)
  // Checked at runtime because the type is erased crossing the bridge — these
  // args arrive from JSON.parse. The server silently downgrades an unknown
  // kind to `bug`, so a typo or a renamed enum on the Dart side would file
  // every report, forever, as a bug that nobody could tell from a real one.
  if (!VALID_REPORT_KINDS.includes(kind)) return { error: `unsupported report kind: ${kind}` }
  return fileReport((context) => attachReportContext({ title, body, kind }, context), {
    needsSyncMessage: t("reportNeedsSync"),
    needsAccountMessage: t("reportNeedsAccount"),
  })
}

const VALID_REPORT_KINDS: ReportPayload["kind"][] = ["idea", "task", "bug"]

async function reportCatalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
  const t = tFor(ctx)
  return [
    {
      command: "REPORT",
      params: t("catalogReportParams"),
      describe: t("catalogReport"),
      category: t("catalogCategory"),
      expectsParams: true,
    },
  ]
}

// Cached in module state for the life of the runtime; persisted back to
// `host.kv` so a restart doesn't force re-registering as a "new" device.
let cachedToken: string | null = null

// `sync`, `ensureClientRegistered`, and a user-triggered OAuth login
// can all reach `registerClient()` within the same tick on a
// fresh device — sharing one in-flight attempt (rather than each firing its
// own POST /v1/client) is what keeps their `host.kvSet` writes below from
// interleaving into a mismatched token/push_channel/webhook_token trio.
let registrationInFlight: Promise<string> | null = null

async function serverUrl(): Promise<string> {
  return kvUrlOr("server", DEFAULT_LOFI_SERVER)
}

async function kvUrlOr(key: string, fallback: string): Promise<string> {
  const configured = await host.kvGet(key)
  return typeof configured === "string" && configured ? configured : fallback
}

async function registerClient(): Promise<string> {
  if (registrationInFlight) return registrationInFlight
  registrationInFlight = doRegisterClient()
  try {
    return await registrationInFlight
  } finally {
    registrationInFlight = null
  }
}

async function doRegisterClient(): Promise<string> {
  const [key, secret, call, clientName] = await Promise.all([host.kvGet("key"), host.kvGet("secret"), host.kvGet("call"), host.kvGet("clientName")])
  const server = await serverUrl()

  const response = await host.fetch(`${server}/v1/client`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      // The name another Ham2K app shows when asked to approve this device
      // ("link <name> with this account?"): the app's own product name and
      // edition, seeded by the app alongside the key — the sandbox knows
      // neither platform nor edition itself.
      client: { key, name: (typeof clientName === "string" && clientName) || "Ham2K Logger", secret: secret || DEFAULT_SECRET },
      account: { call: call || undefined },
    }),
  })

  const json = parseJson(response.body)
  if (response.status !== 200 || typeof json.token !== "string") {
    // A LoFiRequestError, not a plain Error: the server can reject a
    // brand-new registration (e.g. a stored callsign that no longer matches
    // its expected format) same as it can reject any other authenticated
    // request, and callers already know how to treat that class of failure
    // as recoverable rather than a hard failure — see `sync`.
    throw new LoFiRequestError(`LoFi registration failed: ${(json.error as string) ?? `HTTP ${response.status}`}`, response.status, "v1/client")
  }
  cachedToken = json.token
  await host.kvSet("token", cachedToken)

  // `client` carries push_channel/webhook_client_token alongside uuid/name
  // (Client#as_json on the server) — cached the same way as the token so a
  // caller that only wants the channel/webhook identity (ensureClientRegistered,
  // used regardless of whether QSO sync is enabled — HALO-66) doesn't force a
  // second round trip.
  await cacheClientIdentity(json.client)

  return cachedToken
}

/// Stores the identity fields off a `client` payload, and reports what it
/// stored.
///
/// The two have very different lifetimes and only one of them is durable.
/// `push_channel` is stable for the life of the client record.
/// `webhook_client_token` is a SIGNED, ONE-HOUR message (the server mints it
/// per response, `Client#webhook_client_token`), so what lands in kv is a
/// snapshot that goes stale on its own — see [ensureClientRegistered] for who
/// must not trust it.
async function cacheClientIdentity(client: JSONValue | undefined): Promise<{ pushChannelName?: string; webhookClientToken?: string }> {
  const { pushChannelName, webhookClientToken } = clientIdentityFrom(client)
  if (pushChannelName) await host.kvSet("push_channel_name", pushChannelName)
  if (webhookClientToken) await host.kvSet("webhook_client_token", webhookClientToken)
  return { pushChannelName, webhookClientToken }
}

/// Authenticated request with the same retry-once-on-401 shape as the RN
/// extension: an expired/invalid token drops just the token (key/secret
/// still identify this device), never the caller's request.
async function request(method: "GET" | "POST" | "PATCH", path: string, body?: JSONValue): Promise<Record<string, JSONValue>> {
  const server = await serverUrl()
  if (cachedToken == null) {
    const stored = await host.kvGet("token")
    if (typeof stored === "string") cachedToken = stored
  }

  let retries = 2
  while (retries > 0) {
    retries--
    if (cachedToken == null) await registerClient()

    const response = await host.fetch(`${server}/${path}`, {
      method,
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${cachedToken}`,
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    })

    if (response.status === 401) {
      cachedToken = null
      await host.kvSet("token", null)
      continue
    }
    const json = parseJson(response.body)
    if (response.status < 200 || response.status >= 300) {
      throw new LoFiRequestError(`LoFi request failed: ${loFiErrorMessage(json) ?? `HTTP ${response.status}`}`, response.status, path)
    }
    // A 2xx whose body isn't JSON is a proxy or error page, not the server
    // — parseJson folded it into `{}` above, and callers persist what this
    // returns (getAccountData's snapshot lands in settings). A plain Error,
    // not LoFiRequestError, so sync's backup capture still fires.
    if (isUnparseableBody(response.body)) {
      throw new Error(`LoFi returned HTTP ${response.status} with an unparseable body`)
    }
    return json
  }
  throw new Error("LoFi authentication failed")
}

function parseJson(body: string): Record<string, JSONValue> {
  try {
    return JSON.parse(body) as Record<string, JSONValue>
  } catch {
    return {}
  }
}

// A 422 here is a rejected registration, not a bug: the server refusing a
// brand-new client's account details (e.g. a stored callsign that no longer
// matches its expected format) is part of the periodic sync flow, and
// SyncEngine treats an `error`-shaped response as recoverable — same
// convention `linkClient` already uses below. Any other status (500, 429, a
// real outage, ...) is a genuine failure and must keep propagating so it
// still reaches onError/crash reporting.
async function sync(payload: SyncPayload, _ctx: HookContext): Promise<SyncResponse> {
  try {
    const response = (await request("POST", "v1/sync", payload as unknown as JSONValue)) as SyncResponse
    // A 2xx whose body isn't a recognizable sync reply is a FAILURE, not a
    // success — see isRecognizableSyncResponse for the trap (a proxy's
    // 200-with-HTML would otherwise mark the pushed batch synced forever).
    // Thrown as a plain Error, not LoFiRequestError, so shouldCaptureToBackup
    // also spools the payload to the backup service.
    if (!isRecognizableSyncResponse(response)) {
      throw new Error("LoFi sync returned an unrecognizable response (not a sync reply)")
    }
    return response
  } catch (e) {
    if (e instanceof LoFiRequestError && e.status === 422) return { error: e.message, error_status: e.status }

    // Hand the payload to the backup capture service before the original
    // error keeps propagating. Captured even with no cached token -- the
    // token only lets a later replay skip re-authenticating, the data is
    // worth preserving for manual recovery either way.
    if (shouldCaptureToBackup(e)) {
      try {
        await captureToBackupService(payload)
      } catch (captureError) {
        // Neither LoFi nor the backup service could take this payload -- it
        // has nowhere safe to live but this device.
        throw new Error(backupCaptureAlsoFailedMessage(e, captureError))
      }
    }

    throw e
  }
}

async function backupServiceUrl(): Promise<string> {
  return kvUrlOr("backupUrl", DEFAULT_BACKUP_SERVICE_URL)
}

/// Best-effort only -- a caller that reaches this already has a real LoFi
/// failure to report; this must never replace that error with one of its
/// own on the happy path, only add to it if the capture itself also fails
/// (see `sync`'s catch). No explicit `timeout` -- the fallback triggers
/// exactly when the network is degraded, not just when LoFi itself is down,
/// so this gets the same generous host.fetch defaults (15s headers/30s body)
/// as every other request in this file rather than a tighter one of its own
/// that would turn a slow connection into a false double-failure.
async function captureToBackupService(payload: SyncPayload): Promise<void> {
  const token = await host.kvGet("backupToken")
  if (typeof token !== "string" || !token) return // not configured on this build, skip silently

  const server = await backupServiceUrl()
  const response = await host.fetch(`${server}/v1/capture`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({
      client_jwt: cachedToken ?? "",
      sync_body: payload,
      client_timestamp: new Date().toISOString(),
    }),
  })
  if (response.status < 200 || response.status >= 300) {
    throw new Error(`backup capture returned HTTP ${response.status}`)
  }
}

async function getAccountData(_args: Record<string, never>, _ctx: HookContext): Promise<Record<string, JSONValue>> {
  return request("GET", "v1/accounts")
}

/// Requests a link permission from the server (app-polo's `linkClient` /
/// `prepareBlankPermission`). With an email, a pending permission on that
/// account — the response's `permission.challenge_token` is the code the
/// user confirms from a device already linked to it (or `status: 'active'`
/// right away when this client already holds a permission there, which is
/// how quick account switching works). With no email, a blank "orphaned"
/// permission whose client uuid + challenge_token get encoded into a QR
/// code for an already-linked device to scan and approve. Server rejections
/// are part of the UI flow here (404 = "no account with that email"), so
/// they come back as `{ error, error_status }` data instead of a thrown
/// error — only genuine transport failures still throw.
///
/// `send_email: false` because the server mails a confirmation for every
/// pending permission unless the caller opts out: this call shows the
/// challenge code on screen instead, so without the opt-out the operator
/// gets an email they never asked for, a second one the moment they press
/// "send a confirmation email instead", and another every time the code is
/// renewed on expiry. Mailing is [linkClientWithEmail]'s job alone.
async function linkClient({ email }: { email?: string }, _ctx: HookContext): Promise<Record<string, JSONValue>> {
  try {
    return await request("POST", "v1/client/permissions", email ? { email, send_email: false } : {})
  } catch (e) {
    if (e instanceof LoFiRequestError) return { error: e.message, error_status: e.status }
    throw e
  }
}

/// The same request as [linkClient], made because the operator chose the
/// confirmation by email over reading the code off this device — the only
/// call here that asks the server to mail. Through [asData] for the same
/// reason [linkClient] catches: a rejection the operator can act on (the
/// account removed between the two calls, a rate limit) reported as a
/// transport failure tells them the server could not be reached, about a
/// server that answered and said why.
async function linkClientWithEmail({ email }: { email: string }, _ctx: HookContext): Promise<Record<string, JSONValue>> {
  return asData(() => request("POST", "v1/client/permissions", { email, send_email: true }))
}

/// The uuid of the account this device belongs to. Every account-scoped
/// endpoint below puts it in the path and the server only publishes it
/// through `v1/accounts`, so each of those calls pays one extra GET rather
/// than caching an id that a mid-session account switch would invalidate —
/// they are all one-off user actions, never loops.
async function currentAccountUuid(): Promise<string> {
  const data = await request("GET", "v1/accounts")
  const account = data.current_account as Record<string, JSONValue> | null
  const uuid = account?.uuid
  if (typeof uuid !== "string") throw new LoFiRequestError("This device is not linked to an account", 404)
  return uuid
}

/// Wraps a call whose server rejections belong to the UI flow rather than to
/// error reporting — a taken email address, an expired challenge, a code
/// that matches nothing. Same `{ error, error_status }` shape `linkClient`
/// established; only genuine transport failures still throw.
async function asData(call: () => Promise<Record<string, JSONValue>>): Promise<Record<string, JSONValue>> {
  try {
    return await call()
  } catch (e) {
    if (e instanceof LoFiRequestError) return { error: e.message, error_status: e.status }
    throw e
  }
}

/// Sets the account's email — a change of address, or the first claim on an
/// anonymous account. The server stores it as `pending_email` and mails a
/// confirmation link; it becomes the account's real `email` only once that
/// link is followed, so a typo can never hand the account to a stranger.
async function setAccountEmail({ email }: { email: string }, _ctx: HookContext): Promise<Record<string, JSONValue>> {
  return asData(async () => {
    const response = await request("PATCH", `v1/accounts/${await currentAccountUuid()}`, {
      account: { pending_email: email },
    })
    // A 2xx is not proof the address was taken. A captive portal or proxy
    // answering 200 with HTML parses to `{}`, and strong params drop a
    // field the server declined to accept — both would otherwise reach the
    // operator as "Confirmation sent", for a change that will never arrive.
    // Either landing spot counts: normally the address becomes
    // `pending_email`, but re-entering the CONFIRMED address cancels a
    // pending change, and the server clears `pending_email` rather than
    // echoing it back (`Account#send_confirmation_for_pending_email`).
    const account = response.account as Record<string, JSONValue> | undefined
    const sent = normalizedEmail(email)
    if (normalizedEmail(account?.pending_email) !== sent && normalizedEmail(account?.email) !== sent) {
      throw new LoFiRequestError("The sync server did not accept that address", (response.status as number) ?? 502)
    }
    return response
  })
}

/// Mails the confirmation link again for an address change already in
/// flight. A 422 here means there is no pending address (the change landed,
/// or was never made) — data, not a failure.
async function resendAccountEmail(_args: Record<string, never>, _ctx: HookContext): Promise<Record<string, JSONValue>> {
  return asData(async () => request("POST", `v1/accounts/${await currentAccountUuid()}/resend_email`))
}

/// The confirming side of linking: finds the pending request matching a
/// challenge code the operator read off the other device. The server scopes
/// the search to this account and to unexpired pending permissions, so a
/// stale or wrong code simply matches nothing.
async function findLinkRequest({ challenge_token }: { challenge_token: string }, _ctx: HookContext): Promise<Record<string, JSONValue>> {
  return asData(async () => {
    const account = await currentAccountUuid()
    return request("GET", `v1/accounts/${account}/permissions?challenge_token=${encodeURIComponent(challenge_token)}`)
  })
}

/// The same lookup for a request that arrived as a `link_client` deep link:
/// the other device's uuid plus the token from the QR payload, which
/// identify an "orphaned" permission — one created with no account behind
/// it, precisely so that whoever scans it decides which account it joins.
async function findLinkRequestByClient(
  { client, challenge_token }: { client: string; challenge_token: string },
  _ctx: HookContext,
): Promise<Record<string, JSONValue>> {
  return asData(async () => {
    const account = await currentAccountUuid()
    return request("GET", `v1/accounts/${account}/permissions/${encodeURIComponent(client)}?challenge_token=${encodeURIComponent(challenge_token)}`)
  })
}

/// Grants the request: the other device joins this account. [challenge_token]
/// is required for an orphaned (QR) permission — it is what attaches the
/// permission to this account — and ignored for one already raised against
/// it by email.
async function approveLinkRequest(
  { client, challenge_token }: { client: string; challenge_token?: string },
  _ctx: HookContext,
): Promise<Record<string, JSONValue>> {
  return asData(async () => {
    const account = await currentAccountUuid()
    return request("PATCH", `v1/accounts/${account}/permissions/${encodeURIComponent(client)}`, {
      permission: { status: "active" },
      ...(challenge_token ? { challenge_token } : {}),
    })
  })
}

/// Registers this device with the sync server if it hasn't been already —
/// independent of whether QSO sync is enabled (unlike `sync`/`getAccountData`,
/// this never touches log data, so the host calls it regardless of
/// `settings.syncEnabled`; see HALO-66). Returns the Pusher channel to
/// subscribe to and the signed token used to build the `state` param for a
/// webhook-relayed OAuth flow (HALO-65).
async function ensureClientRegistered(
  args: { refreshWebhookToken?: boolean } | undefined,
  _ctx: HookContext,
): Promise<{ push_channel_name: string; webhook_client_token: string }> {
  const read = () => Promise.all([host.kvGet("push_channel_name"), host.kvGet("webhook_client_token")])
  let [pushChannelName, webhookClientToken] = await read()
  if (typeof pushChannelName !== "string" || typeof webhookClientToken !== "string") {
    await registerClient()
    ;[pushChannelName, webhookClientToken] = await read()
  }

  // A caller about to put the webhook token in an OAuth `state` MUST ask for
  // a fresh one. The cached copy is a one-hour signed message, so a device
  // that registered longer ago than that carries one the relay refuses — and
  // its receiver answers only "this login link has expired or is invalid",
  // which the operator cannot act on and which retrying never clears.
  //
  // Opt-in rather than always: boot and every operator-callsign change call
  // through here too, and they want `push_channel_name`, which does not
  // expire. Making them all pay a round trip would put the network on paths
  // that work offline today. A failure here is deliberately fatal to the
  // caller — a login cannot be completed through a relay we cannot reach,
  // and sending the stale token instead is the very bug this prevents.
  if (args?.refreshWebhookToken) {
    const response = await request("GET", "v1/client")
    // Throws unless the answer really carried a token — see
    // `requireWebhookIdentity`. There is deliberately no fallback to the
    // cached value here: that is the bug, not the safety net.
    webhookClientToken = requireWebhookIdentity(response).webhookClientToken
    await cacheClientIdentity(response.client)
    // Re-read rather than reusing what was read before the request: a 401
    // inside `request` re-registers, which can mint a NEW client record and
    // rewrite this key. Pairing that record's token with the previous
    // record's channel would subscribe to a channel nobody publishes to, and
    // the login would simply wait out its deadline.
    const refreshedChannel = await host.kvGet("push_channel_name")
    if (typeof refreshedChannel === "string") pushChannelName = refreshedChannel
  }

  if (typeof pushChannelName !== "string" || typeof webhookClientToken !== "string") {
    throw new Error("LoFi registration did not return a push channel/webhook token")
  }
  return { push_channel_name: pushChannelName, webhook_client_token: webhookClientToken }
}

/// Fetches this device's pending webhook events (HALO-65) — the poll
/// fallback, and how the app retrieves the actual payload after a Pusher
/// `webhook_event` ping, which intentionally carries only an id.
async function fetchWebhookEvents(_args: Record<string, never>, _ctx: HookContext): Promise<{ webhook_events: Record<string, JSONValue>[] }> {
  const response = await request("GET", "v1/client/webhooks")
  const events = response.webhook_events
  return { webhook_events: Array.isArray(events) ? (events as Record<string, JSONValue>[]) : [] }
}
