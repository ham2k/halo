# Accounts & sync

An **account** is a login the operator keeps in the platform keychain and
your hooks read from their context. A **sync transport** moves the app's
log to a server and back. [How hooks work](hooks.md) covers registration,
keys, priority and `ctx`.

## `account`

**For:** credentials for a service your extension talks to: a username and
password, an API key the operator was issued, an OAuth login. The app
renders the connection screen, stores what the operator enters in the
platform keychain, and hands it to your hooks on `ctx.account`. You never
store a password yourself.

**Called:** the app reads the registration to build its Accounts list and
calls `testCredentials` when the operator connects.

```ts
interface AccountHook {
  label: Localizable<string>
  description?: Localizable<string>
  kvKey?: string                       // defaults to your key; else your key or <key>_suffix
  fields?: Localizable<AccountField[]> // { key, label, type: 'text' | 'email' | 'secret', preface?, postface? }
  oauth2?: OAuth2Config | ((args, ctx) => OAuth2Config)
  synchronizable?: boolean
  testCredentials(credentials: Record<string, string>, ctx): Promise<string>
}
```

```ts
registerHook("account", {
  hook: {
    label: "HamQTH",
    description: (_, ctx) => createTranslator(resources, ctx.locale ?? "en")("accountDescription"),
    fields: [
      { key: "username", label: "Username", type: "text" },
      { key: "password", label: "Password", type: "secret" },
    ],
    async testCredentials(credentials, ctx) {
      const session = await logIn(credentials)
      await host.setAccountSession({ sessionId: session.id, expiresAt: session.expiresAt })
      return `Connected as ${credentials.username}`
    },
  },
})
```

- **`label`, `description` and `fields`** take a plain value or a function
  `(args, ctx) => value`, called like any hook method, so they can be
  localized from `ctx.locale`.
- **`testCredentials`** answers a sentence for the operator. Throw, or
  answer a sentence that says so, when the login fails; the app shows it.
- **`host.setAccountSession(session)`** stores a session (a token, an
  expiry) beside the credentials, in the keychain. Your hooks then find both
  on `ctx.account.credentials` and `ctx.account.session`.
- **`oauth2`** is `{ issuer, clientId, redirectUrl, webhookRedirectUrl?,
  scopes }` and the app runs the whole PKCE flow itself. `redirectUrl` is
  the native custom-scheme redirect, `com.ham2k.logger.<edition>.auth://…`,
  which the OS delivers as a deep link on macOS, iOS and Android; register
  one per edition with the provider, and give the configuration as a
  function of `ctx` so it can read `ctx.edition`. `webhookRedirectUrl` is
  the relay callback the app uses instead on Web, Linux and Windows; without
  it those three platforms cannot start the login at all.
- **`synchronizable: true`** syncs the stored credentials across the
  operator's Apple devices through iCloud Keychain; false keeps them on the
  device. No effect elsewhere. Set it only for a login that is genuinely the
  same on every device, never for a per-device identifier or a bearer token.
  A synchronizable and a non-synchronizable item are distinct keychain
  entries, so the flag must stay the same for a `kvKey`'s whole lifetime;
  flipping it hides the old entry and the credentials must be entered again.
- A `kvKey` outside your namespace is ignored, and the account is stored
  under the hook's key instead; a read or a session write naming another
  extension's key is refused.

A settings panel shows the account's connection status with a field of
`fieldType: 'account'` ([Settings panels](settings.md#the-account-field-type)),
which opens this account's own dialog; it never defines or stores the
account itself. A `secret` settings field is for a bare API key with no
login behind it; a login belongs here.

**Examples:** `k2hrc-hamqth` in the SDK's samples; `ham2k-qrz` (username and
password) and `ham2k-sota` (OAuth) in
[ham2k/extensions](https://github.com/ham2k/extensions).

## `syncTransport`

**For:** moving sync payloads over the network. The app owns the sync loop,
the batching and the dirty flags; the transport only sends an
already-selected payload and returns the reply, so sync keeps working even
if the runtime is wedged. One transport exists, Ham2K's own LoFi; the seam
is documented so a reader knows what it is, not because a second is
expected soon.

**Called:** one hook, the registered transport, by the app's sync engine.
`SyncTransportHook` in `dist/index.d.ts` is the contract; the required
methods are `sync`, `getAccountData`, `linkClient` and
`linkClientWithEmail`, and the rest (`setAccountEmail`,
`resendAccountEmail`, `findLinkRequest`, `findLinkRequestByClient`,
`approveLinkRequest`, `submitReport`, `uploadStashFile`, `listStashFiles`,
`emailStashLink`) are optional. The conventions every method follows:

- **A rejection is data, not a throw**: `{ error, error_status }`. Every one
  of these methods reports to an operator in the middle of an action.
- **`sync`** passes `claims` through beside `operations` and `qsos`, both
  ways, once the server's reply has said it takes them
  (`meta.flags.claims`).
- **`linkClient` must not mail anything.** It asks to join another account
  and answers a pending challenge code, an immediately active permission for
  an already-permitted account, or a blank permission for QR linking; an
  expiring code re-requests through the same call. The app shows the code
  on screen and offers email as a separate choice; `linkClientWithEmail` is
  the one call that mails. `setAccountEmail` and `resendAccountEmail` change
  the address that identifies the account, which stays pending until the
  operator opens a mailed confirmation. The `findLinkRequest*` and
  `approveLinkRequest` methods are the confirming side, where this device
  admits another into its own account, from a typed code or from the deep
  link a requesting device's QR code carries; `approveLinkRequest` must be
  given the `challenge_token` for a blank permission, which is what binds it
  to this account.
- **`uploadStashFile`** takes one file and the `groupUuid` of its batch,
  minted by the app since the sandbox has no uuid source, and is called once
  per file, since a call's timeout does not stop a hook and a whole batch in
  one call would go on uploading unseen. It answers `{ uploaded: true }` or
  `{ error }`, with `fatal: true` on any failure but the server refusing that
  one file, so the app stops instead of failing every remaining file the
  same way; no answer means the file may have arrived. `listStashFiles`
  answers the server's `{ stash_files: [...] }`, newest first;
  `emailStashLink` mails the account's own address a link. All three own the
  same sync gate `submitReport` does.
- **`submitReport`** files a report the app composed; the transport adds who,
  where and what build, and owns the account gate.
