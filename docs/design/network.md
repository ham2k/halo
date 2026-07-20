# Network calls & User-Agent

HaLo makes many outbound HTTPS calls — from the Dart app core (OAuth, data-file
downloads) and from extensions (spot sources, lookups, sync). Every one of these
that lets us set request headers **must** identify the app with HaLo's canonical
`User-Agent`, so third-party services (SOTA, POTA, QRZ, LoFi, …) see a
consistent, honest client string instead of a bare platform default or a
per-call-site ad-hoc value.

## The canonical User-Agent

Defined in one place: [`app/lib/config/user_agent.dart`](../../app/lib/config/user_agent.dart),
via `ham2kUserAgent()`.

Shape:

```
Ham2K Logger/{publicVersion} ({platform} {flavor} {build})
```

e.g. `Ham2K Logger/26.8.0 (macos next 1)`.

- **publicVersion** — `kPublicVersion` from
  [`app/lib/config/version.dart`](../../app/lib/config/version.dart) (the
  patchable public version, e.g. `26.8.0`). Never hard-code a version into a UA
  string; it silently drifts as the app bumps.
- **platform** — `web` / `macos` / `ios` / `android` / `windows` / `linux`.
- **flavor** — the product line / build channel, `kAppFlavor` (currently
  `next` for the Logger Next line). It lives in `version.dart` beside
  `kPublicVersion` and is bumped deliberately at release time — it is the
  product line, *not* the `-preN` pre-release counter, so it is not derived
  from `PublicVersion.preRelease`.
- **build** — the native build number (via `package_info_plus`); omitted when
  unavailable.

The value is resolved once and cached for the process life.

### Web caveat

`User-Agent` is a [forbidden request header](https://fetch.spec.whatwg.org/#forbidden-request-header):
on the web build the browser silently drops any we set (`package:http` uses
XHR under the hood), so **web requests do not carry this UA** — they go out
with the browser's own User-Agent. The `web` platform token above is therefore
only observable if a proxy adds it server-side (web `host.fetch` and data-file
traffic are already routed through `services.ham2k.net`, which is where a
web-side UA would be stamped if we want one). Native builds send it directly.

## The rule

**Any outgoing network call that allows request headers must send this
User-Agent.** Concretely:

- **Dart app core** — there is no shared HTTP wrapper; call sites use
  `package:http` directly. Add `'User-Agent': await ham2kUserAgent()` to the
  request headers. Current call sites: the OIDC OAuth flow in
  `settings_view.dart` and downloads in `data_file_manager.dart`.
- **Extensions** — you get this for free. Every `host.fetch` is stamped with the
  canonical UA by the extension host
  ([`packages/halo_extension_host/lib/halo_extension_host.dart`](../../packages/halo_extension_host/lib/halo_extension_host.dart),
  `_hostFetch`), which the app seeds via `ExtensionHost.start(userAgent: …)`.
  The host sets it **last**, so it overrides any `User-Agent` an extension puts
  in its `headers` — **do not set your own** in an extension; it will be ignored,
  and hard-coded version strings only rot.

If a service instead wants an app identifier in the URL path or a query field
(e.g. HamDB's `/json/{agent}`), that's a separate service-specific requirement —
still keep the HTTP `User-Agent` above as well.

### Whitelisted overrides (rare)

An extension that genuinely must send a specific `User-Agent` — a third-party
API that rejects anything else — can opt into keeping its own. Add
`allowUserAgentOverride: true` to its entry in
[`extensions/build.mjs`](../../extensions/build.mjs) (alongside `domains`); it
flows to the host via the `index.json` manifest, exactly like the network
allowlist. The host then keeps the `User-Agent` that extension sets, and only
that extension's. A whitelisted extension that sets *no* `User-Agent` still gets
the canonical one, so no request goes out unidentified.

This is an escape hatch, not a default: **no extension is whitelisted today**,
and consistency is the goal. Prefer the canonical UA unless a service forces
otherwise. The gate lives in `resolveFetchUserAgent`
([`halo_extension_host.dart`](../../packages/halo_extension_host/lib/halo_extension_host.dart)),
seeded by the app from the manifest capability.

## Not covered here

Tile-layer identifiers such as `flutter_map`'s `userAgentPackageName`
(`osm_map_view.dart`) are set by that library on its own tile requests and use a
package-name form (`com.ham2k.poloNext`), not this UA. Leave those as the
library expects.
