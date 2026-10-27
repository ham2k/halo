# Account, settings & sync hooks

The [hook reference](hooks.md) says how hooks are registered and invoked, and what every hook is handed.

## ✅ `account` — account connections

Account connections (QRZ, LoFi, SOTA): credential fields, `testCredentials`,
and optional OAuth2, surfaced in `SettingsView`'s Accounts panel via
`ExtensionService.getAccounts`/`testCredentials`. Credentials live in the
platform keychain, keyed by the account's `kvKey`. Implemented by: `qrz`
(username/password) and `sota` (OAuth2 via Keycloak — `sso.sota.org.uk`; the
host runs the whole PKCE flow itself, see `_doOAuth` in
`app/lib/views/settings/accounts_panel.dart`).

**`label` / `description` / `fields`** — each either a plain value, or a
function `(args, ctx) => value` called the same way any other hook method is,
so extensions can localize them from `ctx.locale` (via the SDK's
`createTranslator`). The same `Localizable<T>` convention applies to a
`dataFile` registration's `name`/`description`. QRZ localizes its account
description and field labels this way.

**`oauth2`** (optional) — either a plain `OAuth2Config`
(`{issuer, clientId, redirectUrl, scopes}`), or, for a client that varies by
build edition, a function `(args, ctx) => OAuth2Config` called the same way
any other hook method is (`ctx.edition` is `'dev' | 'next' | 'prod'` — see
`HookContext.edition` below). SOTA is the one such hook: every edition
authenticates as the SAME Keycloak client, and what varies is the redirect
URL — `com.ham2k.logger.<edition>.auth://sota`, one per edition, each
registered against that one client.

**`synchronizable`** (optional, default `false`) — on Apple platforms (macOS
and iOS), when `true` the account's stored credentials and session sync across
the user's devices via iCloud Keychain (`kSecAttrSynchronizable`); when `false`
they stay device-local. No effect on other platforms. Set it `true` only for
account-level logins that are genuinely the same on every device — QRZ.com sets
it, since one QRZ login is shared across a user's installs. **Never** set it for
per-device identifiers or bearer tokens: the LoFi sync **device key** is a
per-install identifier and deliberately stays device-local (it isn't even an
`account` hook — it lives in `SettingsService`, non-synchronizable, and must
stay that way, or two devices would present as the same sync client).

The flag must be consistent for a `kvKey` across its whole lifetime: a
synchronizable and a non-synchronizable keychain item are *distinct entries*,
so the host resolves each account's flag once at runtime start
(`ExtensionService._accountSynchronizable`) and applies it to every
read/write/delete. Flipping the flag on an account that already has stored
credentials makes the old entry invisible — the credentials must be re-entered
once (there is no automatic migration between the two entries).

## ✅ `settingsPanel` — extension settings forms

Declarative settings panels rendered by the core's `FormRenderer` — full
schema, kernel dispatch, `ExtensionService`, and `SettingsView` wiring; see
[settings.md](./settings.md). Complementary to `account`, not a replacement.
Implemented by: `settings` (the core General panel).

An extension puts all its settings in one panel, placed in the section that
fits its main purpose and declared in the manifest's `settings` — see
[Where an extension's settings go](./settings.md#where-an-extensions-settings-go).
A category of its own, a sidebar entry or Common Preferences rows are reviewed
on the catalog.

## ✅ `syncTransport` — sync backends

The transport seam for LoFi (and future) sync. The Dart core owns the
loop, batching, and dirty flags (`packages/halo_core`'s `SyncEngine`); the
hook only moves an already-selected payload over the network, so sync keeps
working even if the JS runtime is wedged (DESIGN.md §4). Registered as a
single object with `sync`/`getAccountData`/`linkClient`/
`linkClientWithEmail` methods — `linkClient` (optional) requests a link
permission (pending challenge code for an email, immediately-active for an
already-permitted account, or a blank permission for QR-code linking) and
returns server rejections as `{ error, error_status }` data.

`sync`'s payload and reply carry `claims` beside `operations` and `qsos`
(docs/design/claims.md §7) once the server's reply has said it takes them
with `meta.flags.claims`. A transport passes the array through like the
other two, both ways.

`linkClient` must NOT mail anything. The core shows the challenge code on
screen and offers the email as a separate choice, so a transport that mails
here sends a confirmation nobody asked for — and one more on every renewal,
since an expiring code re-requests through this same call.
`linkClientWithEmail` is the call the operator reaches by choosing the
email over the code, and the only one in this seam that mails. A server
that mails by default (LoFi does) has to be told not to.

The account-management methods are all optional and all follow that same
"a rejection is data, not a throw" convention, because every one of them
reports to an operator in the middle of an action: `setAccountEmail` /
`resendAccountEmail` change the address that identifies the account (it
stays pending until the operator opens a mailed confirmation link, so a
typo can never hand the account to a stranger), and `findLinkRequest` /
`findLinkRequestByClient` / `approveLinkRequest` are the CONFIRMING side of
linking — where `linkClient` asks to join some other account, these let
this device admit another one into its own, from a typed challenge code or
from the `com.ham2k:///link_client?id=…&token=…` deep link a requesting
device's QR code carries. `approveLinkRequest` must be given the
`challenge_token` for a blank/QR permission: that token is what binds a
permission created with no account behind it to this one.

`submitReport`
(optional) files a report the host composed — the equipment editor's radio
report — as a real CaBo card; the host writes the title, body and kind, the
transport adds who/where/what-build and owns the account gate.
Implemented by: `ham2k-lofi`.

`uploadStashFile` / `listStashFiles` / `emailStashLink`
(optional) back the Exports pane's Stash button, which sends export files
to a store the operator fetches from any browser (Ham2K's File Stash, at
stash.ham2k.net). `uploadStashFile` takes ONE file and the `groupUuid` of
the batch it belongs to — the host mints it, since the sandbox has no uuid
source, and calls once per file: its call timeout does not stop a hook, so a
whole batch in one call would go on uploading unseen after the host had
told the operator it failed. It answers `{ uploaded: true }` or `{ error }`,
never a throw, with `fatal: true` on any failure but the server refusing
that one file — sync off, no account or permission, no answer — so the host
stops instead of having every remaining file fail the same way. No answer
says the file may have arrived: a body can reach the server after the reply
is lost.
`listStashFiles` answers the server's `{ stash_files: [...] }`, newest
first, which the host reads to warn a free account before a new stash
replaces one not yet fetched; `emailStashLink` mails the account's own
address a link to its stash. Both answer `{ error }` for a refusal. All
three own the same sync gate `submitReport` does.
Implemented by: `ham2k-lofi`.

## ✅ `bench` — kernel diagnostics

Registered by the kernel itself (`bench/kernel`): `echo` (bridge round-trip
measurement) and `spin` (JS compute). Used by the spike screen; not for
extensions.
