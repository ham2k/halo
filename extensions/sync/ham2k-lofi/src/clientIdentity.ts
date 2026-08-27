// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

/// The identity fields carried on a LoFi `client` payload (`Client#as_json`).
///
/// The two have very different lifetimes, and only one is durable.
/// `push_channel` is stable for the life of the client record.
/// `webhook_client_token` is a signed ONE-HOUR message the server mints per
/// response, so a stored copy goes stale on its own — anything putting it in
/// an OAuth `state` has to have just fetched it.
export type ClientIdentity = { pushChannelName?: string; webhookClientToken?: string }

/// Reads those fields out of a `client` payload, keeping only strings.
///
/// A missing or wrong-typed field comes back undefined rather than throwing
/// or coercing: the caller keeps whatever it already had, which is right for
/// a server that omits a field but wrong if `undefined` were ever written
/// over a good cached value.
export function clientIdentityFrom(client: unknown): ClientIdentity {
  if (!client || typeof client !== 'object') return {}
  const fields = client as Record<string, unknown>
  return {
    pushChannelName: typeof fields.push_channel === 'string' ? fields.push_channel : undefined,
    webhookClientToken:
      typeof fields.webhook_client_token === 'string' ? fields.webhook_client_token : undefined,
  }
}

/// The webhook token off a `GET /v1/client` response, or a throw.
///
/// A refresh that comes back 2xx has NOT necessarily refreshed anything: a
/// captive portal, a maintenance page, or a server that omits the field all
/// answer with a body this cannot read a token out of. Returning the caller's
/// stale token in that case is the exact failure a refresh exists to prevent
/// — it reaches the relay, is refused, and the operator is told the login
/// link expired with nothing to do about it. So an unreadable answer is an
/// error, loudly, naming the endpoint that gave it.
///
/// An empty string counts as absent. It is the one value that is a `string`
/// and still useless: it survives a `typeof` check and a `??`, and reaches
/// the relay as a token that identifies no client at all.
export function requireWebhookIdentity(response: unknown): ClientIdentity & { webhookClientToken: string } {
  const client = (response && typeof response === 'object')
    ? (response as Record<string, unknown>).client
    : undefined
  const identity = clientIdentityFrom(client)
  if (!identity.webhookClientToken) {
    throw new Error('LoFi GET v1/client answered without a webhook token')
  }
  return { ...identity, webhookClientToken: identity.webhookClientToken }
}
