# HaLo Architecture & Code Review

*Date: 2026-07-14 · Scope: full repo at commit `a584f83` (branch `62-day-headers`)*

Method: four parallel deep-review passes (halo_core, halo_extension_host, app/halo_widgets UI
layer, TypeScript extensions/SDK) plus a cross-cutting pass against DESIGN.md and
docs/. Every finding below was verified against actual code paths; the highest-severity
ones were independently re-verified. `npx tsc --noEmit` passes clean and all 49 TS unit
tests pass.

---

## 1. Executive summary

The architecture is being executed faithfully to DESIGN.md, and the parts that were
designed to be load-bearing genuinely are: hooks are pure JSON functions with no UI or
store entanglement, the logging fast path never crosses the bridge, sync policy lives
entirely in Dart with the transport injected, repositories are the sole DB writers, and
the riskiest logic (mergeLookup, sync state machine, settings panels) is factored into
plain-testable modules with real tests. That discipline is the repo's biggest asset.

The problems cluster in four themes, roughly in priority order:

1. **Sync conflict handling was simplified out of the app-polo port.** No
   `updatedAtMillis` on rows, unconditional `markSynced` after an awaited network call,
   unconditional overwrite on inbound merge, and local-clock watermarks. Several races
   that were benign in app-polo are silent data-loss paths here (§3.1).
2. **The extension containment promised by DESIGN.md §3 does not exist yet.** No
   capability/manifest gating (any extension can read any other's keychain credentials),
   no fetch allowlist, no QuickJS interrupt/memory limits, and a dead extension isolate
   is silent and unrecoverable (§3.2). Acceptable while all bundles are first-party
   assets; a hard blocker for the OTA/registry channel.
3. **Two data-corrupting bugs in the hottest UI path** — opening the Time chip silently
   freezes auto-timestamping, and a manually-set operator name leaks onto the next QSO
   (§3.3).
4. **No CI, and extension bundles are gitignored build artifacts** with nothing tying
   `flutter build` to `node build.mjs` — the most likely source of "works on my machine"
   drift today (§5).

None of these require redesign. The sync fixes need one schema addition (a revision
timestamp) and a reconciliation lock; the containment work is already sketched in
DESIGN.md and just needs to be built before third-party extensions ship.

---

## 2. Architecture assessment

### What's working as designed

- **The core split holds.** halo_core is pure Dart with zero Flutter imports; the
  keystroke → QSO list path is pure Dart; extension involvement is debounced and
  coarse-batched (`scoring/core` and `lookups/core` collapse whole pipelines into one
  bridge call, composing hooks in-runtime via `invokeLocal`).
- **Sync-engine testing is unusually good for this stage** — account identity, backfill
  paging, and watermark behavior are covered, and the tests document at least one real
  caught bug.
- **DESIGN.md §11's "credentials in plaintext" risk row is stale (in a good way):**
  account secrets already use `FlutterSecureStorage` with a boot-time migration.
- **The recent QSO-list/day-header work is sound at the sliver level**
  (`SliverMainAxisGroup` pinning, single-pass bucketing, value-equal marker data); its
  defects are edge cases and inherited rebuild amplification, not structure.

### Structural deviations worth deciding on (fix code or update DESIGN.md)

| Deviation | Where | Impact |
|---|---|---|
| `Operation` state is not reactive — `OperationView`, `ActivitiesView`, `OperationLocationScreen` each hold manually refreshed copies with re-fetch-on-pop; a hand-rolled `localData` merge papers over the races | [operation_view.dart:85](app/lib/views/operation_view.dart:85) | A `watchOperation(uuid)` stream (DESIGN §6: "reactive queries feed the UI") would delete a whole class of staleness bugs, incl. §3.3-M5 |
| `LoggingControls` is a 2,570-line god-widget (keyboard shortcuts, command dispatch, VFO mirroring, undo slots, batch logging, form building) with ~40 label constructor params fighting the i18n boundary | [logging_controls.dart](packages/halo_widgets/lib/src/logging_controls.dart) | Both high-severity UI bugs live here; a labels object/localization delegate plus extraction of command & time concerns would shrink the blast radius |
| `ExtensionService` inverts layering: imports `halo_widgets`, uses `main.dart`'s `navigatorKey`, shows dialogs | [extension_service.dart](app/lib/services/extension_service.dart) | Pragmatic for `showForm`, but the service→view arrow now points both ways; `_dispatchActions` is duplicated with silent divergence between [logging_controls.dart:1285](packages/halo_widgets/lib/src/logging_controls.dart:1285) and [home_view.dart:464](app/lib/views/home_view.dart:464) |
| Generic host package hardcodes extension-specific domains + the ham2k.net web proxy | [halo_extension_host.dart:500](packages/halo_extension_host/lib/halo_extension_host.dart:500) | List silently rots (SOTA's `api2.sota.org.uk` is already missing → SOTA half-broken on web); belongs in per-extension manifests |
| `lookups` table not extension-namespaced (`(category, key)` PK, no `extension` column); `extension_kv` table absent; no `updatedAtMillis` column | [database.dart:84](packages/halo_core/lib/src/db/database.dart:84) | The missing `updatedAtMillis` is the one schema omission with teeth — it's the primitive every sync-conflict fix needs |
| `Hook` TS union ends in `\| Record<string, unknown>`, making it non-discriminating — any object typechecks as a Hook | [types.ts:404](extensions/sdk/src/types.ts:404) | "Typed contracts" (DESIGN §12) are enforced socially, not mechanically; no SDK/contract versioning exists for the OTA story to negotiate against |
| `docs/extensions/hooks.md` documents a `command` contract (`tryCommand → {freq, band, mode}`) that no code implements; spots/syncTransport/settingsPanel implementation status wrong | docs/extensions/hooks.md | A third-party author following the doc writes a hook that never fires |

---

## 3. Findings

Severity: **P0** = data loss/corruption or security, fix before next release ·
**P1** = user-visible defect or reliability hazard · **P2** = quality/perf/robustness.

### 3.1 Sync engine & repositories (halo_core)

**P0-1 · Edits made while a sync round is in flight are silently marked synced and never
pushed.** [sync_engine.dart:241](packages/halo_core/lib/src/sync/sync_engine.dart:241)
`selectBatch()` runs, the transport call is awaited (seconds), then `markSynced()` flips
the batch's uuids unconditionally. Edit QSO X → round starts → edit X again mid-flight
(`synced=false`) → `markSynced` sets it back to `true`. The second edit never syncs.
*Fix:* mark conditionally (compare a revision/`updatedAtMillis`, or `WHERE data =
<sent data>`).

**P0-2 · `mergeFromSync` overwrites local rows unconditionally — regression vs app-polo.**
[repositories.dart:357](packages/halo_core/lib/src/repo/repositories.dart:357) (QSOs),
[repositories.dart:166](packages/halo_core/lib/src/repo/repositories.dart:166) (ops).
Both paths `insertOnConflictUpdate` with `synced: true` without looking at the existing
row; app-polo skips inbound records where `existing.updatedAtMillis >= incoming`. On
account relink + **combine**, backfill pulls the account's *older* copies of this
device's own QSOs and clobbers the newer local dirty data. Same clobber whenever a pull
races a local edit. *Fix:* add `updatedAtMillis` to the schema and compare on merge.

**P0-3 · Backfill→forward watermark uses the local clock and drops the backfill window.**
[sync_engine.dart:389](packages/halo_core/lib/src/sync/sync_engine.dart:389)
On backfill completion the forward cursor is set to local `DateTime.now()`. Records
synced by *other devices during* backfill fall between the cursors and are never pulled;
device clock ahead of server skips the skew window. app-polo tracks
`max(syncedAtMillis)` from records actually merged and never substitutes the local
clock. *Fix:* restore that behavior.

**P1-4 · Backfill cursor can stall on a page of identical `syncedAtMillis` values.**
[sync_engine.dart:261](packages/halo_core/lib/src/sync/sync_engine.dart:261)
Cursor only advances when strictly smaller; a full page sharing one timestamp (server
bulk import) either hot-loops with `Duration.zero` rescheduling or silently skips the
same-timestamp remainder, depending on server paging semantics. Same tie hazard on the
forward boundary. *Fix:* page on `(syncedAtMillis, uuid)`.

**P1-5 · No mutual exclusion between `forceFullResync`/`resolveAccountChange` and an
in-flight round.** [sync_engine.dart:120](packages/halo_core/lib/src/sync/sync_engine.dart:120)
`SYNCALL` mid-round: the wipe runs, then the in-flight round resumes, merges its
pre-wipe page into the cleared tables, and its short page sets `completedFullSync: true`
— cancelling the backfill the user just requested; the device believes it's fully synced
with a mostly-empty log. Related lost-update: `runOneRound` spreads a pre-await `state`
snapshot into `setState`, clobbering settings written during the await. *Fix:* a sync
generation counter/lock; re-read `settings.state` after awaits.

**P1-6 · Replace/SYNCALL wipe is not atomic.**
[sync_engine.dart:122](packages/halo_core/lib/src/sync/sync_engine.dart:122)
Operations and QSOs are backed up and cleared in two separate transactions, with the
settings flip after both. A crash between them leaves orphaned QSOs still eligible for
`unsyncedBatch`. *Fix:* one transaction (backup tables share the DB).

**P2-7 · Blanket `catch (_)` with zero logging in the sync loop; failed small-batch
rounds aren't rescheduled at all.** [sync_engine.dart:266](packages/halo_core/lib/src/sync/sync_engine.dart:266) — violates the project's own Rule 12.

**P2-8 · `dispose()` doesn't stop an in-flight round from rescheduling** — no
`_disposed` flag; a zombie loop can run against a closed DB. [sync_engine.dart:413](packages/halo_core/lib/src/sync/sync_engine.dart:413)

**P2-9 · Assorted repository issues:** operations `mergeFromSync` lacks the transaction
its QSO twin has ([repositories.dart:166](packages/halo_core/lib/src/repo/repositories.dart:166));
QSO merge keeps `uuid`/`syncedAtMillis` inside the `data` blob while op merge strips them
(defeats future content comparison); `queryLookups` uses unescaped `LIKE '%…%'` — user
`%`/`_` act as wildcards and every suggestion full-scans the category
([repositories.dart:499](packages/halo_core/lib/src/repo/repositories.dart:499));
`deleteCategoryStale` never deletes rows with NULL `updated`
([repositories.dart:486](packages/halo_core/lib/src/repo/repositories.dart:486));
`watchAll` re-decodes and re-sorts every operation's JSON on every QSO add (counter
refresh writes `operations`) ([repositories.dart:65](packages/halo_core/lib/src/repo/repositories.dart:65)).

**P2-10 · `parseFreq` misparses MHz input ≥ 1000** — "1296.2" (23cm, where MHz entry is
the universal convention) is taken as kHz and stored as a 160m frequency.
[radio.dart:117](packages/halo_core/lib/src/ham/radio.dart:117)

*Verified clean:* all persistence is epoch-millis with consistent `isUtc: true`; grid
math correct; migration history (v1 index, additive v2/v3) hazard-free.

### 3.2 Extension host & bridge (halo_extension_host + kernel)

**P0-11 · No capability gate: any extension can read any other's keychain credentials.**
[extension_service.dart:411](app/lib/services/extension_service.dart:411),
[kernel.ts:392](extensions/sdk/src/kernel.ts:392)
The SDK namespaces KV/account access by `currentExtensionKey`, but raw `hostCall` is a
public kernel API and every Dart handler trusts the JS-supplied `ns`/`kvKey`:
`__polo.hostCall('getAccount', {kvKey: 'qrz'})` returns the user's QRZ password from
secure storage to any bundle. Same hole for `kvGet/kvSet` (read the lofi device key),
`setAccountSession`, statusBar namespaces, and the global `sendMessage` primitive (forge
`{type:'result', id:…}` to hijack another hook's in-flight response). Fine while all
bundles are first-party assets baked at build time (no remote-code path exists today —
good); **must be closed before the registry/OTA channel.** *Fix:* the host, not the JS
side, must derive the caller's identity — e.g. hand each extension a token at activation
and check it in the Dart handlers.

**P0-12 · `host.fetch` has unrestricted HTTPS egress on native.**
[halo_extension_host.dart:520](packages/halo_extension_host/lib/halo_extension_host.dart:520)
Only the scheme is checked; DESIGN promises per-extension domain allowlists. Combined
with P0-11, a compromised extension exfiltrates any stored credential anywhere. Also:
redirects are followed (https-only check applies only to the first URI), and there's no
response-size cap.

**P1-13 · No QuickJS interrupt handler or memory limit — a runaway hook permanently
wedges the engine.** [engine_runtime_io.dart:31](packages/halo_extension_host/lib/src/engine_runtime_io.dart:31)
`flutter_js` defaults: no interrupt, no memory limit. A `while(true)` hook blocks the
extension isolate forever — every subsequent hook times out, nothing restarts. In the
in-process fallback (silently entered whenever isolate spawn fails) the same loop
**freezes the UI thread**, contradicting DESIGN's "never hangs the app." DESIGN §3
called for direct FFI binding precisely for interrupt/memory control.

**P1-14 · Extension isolate death is silent and unrecoverable.**
[halo_extension_host.dart:103](packages/halo_extension_host/lib/halo_extension_host.dart:103)
`Isolate.spawn(..., errorsAreFatal: true)` with no `onError`/`onExit` ports. Any uncaught
isolate error (e.g. a bad cast on a malformed JS message) kills it; sends are then
silently dropped, all hooks hang to timeout forever, `fatalError` never fires. And there
is no recovery path anywhere: `ExtensionService.start()` memoizes failure
([extension_service.dart:52](app/lib/services/extension_service.dart:52)), and after
`fatalError` the host stays dead until app restart — while `main.dart` routes *sync*
through this runtime, directly against DESIGN's "sync must work even if the JS runtime
is wedged." *Fix (cheapest big win):* wire `onError`/`onExit` into the existing
`fatalError` path + a restart in `ExtensionService`.

**P1-15 · `invokeHookAll` lacks the top-level try/catch `invokeHook` has.**
[kernel.ts:222](extensions/sdk/src/kernel.ts:222)
`JSON.parse(argsJson)` and the final `post(...)` run outside any try; a non-serializable
aggregate (circular ref) → unhandled rejection → no result message → the Dart caller
burns its full timeout and reports a misleading "timed out". The Settings screen's
`getPanels` sits on this path.

**P1-16 · The hang-until-timeout family.** Never-resolving hooks leak `_outstanding`
and leave the 5 ms pump timer running forever (battery drain on an all-day field app)
([halo_extension_host.dart:419](packages/halo_extension_host/lib/halo_extension_host.dart:419));
a non-JSON-encodable host-call result is only logged and no `hostResponse` is ever
delivered — the awaiting hook wedges
([halo_extension_host.dart:482](packages/halo_extension_host/lib/halo_extension_host.dart:482));
`_hostFetch`'s 15 s timeout covers headers only — a server stalling mid-body hangs the
hook indefinitely ([halo_extension_host.dart:531](packages/halo_extension_host/lib/halo_extension_host.dart:531)).
Each is a small local fix.

**P1-17 · Every hook invocation makes 1–2 extra bridge round trips, including keychain
reads.** [kernel.ts:114](extensions/sdk/src/kernel.ts:114)
`getSettings` always, `getAccount` (→ two `FlutterSecureStorage` reads on the main
isolate) for account-owning extensions, before *every* hook method — multiplied by N in
`invokeHookAll`. On the debounced per-keystroke lookup path this is real latency and
battery. Contradicts "bridge APIs are coarse by design". *Fix:* push settings/account
context once per change, or piggyback on the invoke message.

**P2-18 · Assorted host issues:** `response.body` decodes as latin1 when no charset
header (mojibake for XML/CSV endpoints; no bytes path at all for `fetchType: 'raw'`)
([halo_extension_host.dart:533](packages/halo_extension_host/lib/halo_extension_host.dart:533));
`logLines` unbounded (samples list next to it is capped at 2000);
`dispose()` neither drains pending completers nor closes the ReceivePort, and kills the
isolate with `immediate` so the JS-side dispose branch is dead code;
`_IoEngineRuntime.dispose()` is empty — the QuickJS runtime leaks;
web always logs a misleading "isolate mode failed" warning (branch on `kIsWeb`);
console shim lacks `info`/`debug` — calling them throws inside the hook;
duplicate/forged `result` messages can drive `_outstanding` negative and stall the pump;
`host.showForm` from a settings action will hit the caller's 10 s timeout while the
dialog is still open (latent — first user will be confused).

### 3.3 App & widgets (UI layer)

**P0-19 · Opening the Time control silently freezes automatic timestamping.**
[logging_controls.dart:840](packages/halo_widgets/lib/src/logging_controls.dart:840)
`_timeController`/`_dateController` listeners have no programmatic-set guard, so the
`_seedTimeFields()` call in `_onSelectControl` fires them: tap the Time chip just to
peek → `_manualStartAtMillis` set to the seeded minute → live clock stops → every
subsequent QSO logs at that frozen time. Worse, "Now" (`_resetTimeToNow`) nulls the
override then re-seeds, re-triggering the listener — **auto-timestamping cannot be
restored from the UI.** Existing tests pass only because both seeds land in the same
wall-clock minute. *Fix:* a `_populating` guard around programmatic sets (pattern
already used elsewhere in the file).

**P0-20 · A manually-set operator name leaks onto the next QSO.**
[logging_controls.dart:1767](packages/halo_widgets/lib/src/logging_controls.dart:1767)
`_wipe()` resets touched-flags, extras and refs but never nulls `_theirNameOverride`
(only `didUpdateWidget`'s editing transition does, line 485). Set Name via "More" for
W1AW, log it, type K1ABC → K1ABC is stored with W1AW's name, overriding its own lookup.
Also: `_wipe` doesn't clear `_unmatchedRefs`, and `_hasComposedValues` ignores the name
override (name-only entry shows a disabled wipe button).

**P1-21 · Frequency precision silently lost on every edit round-trip.**
[logging_controls.dart:527](packages/halo_widgets/lib/src/logging_controls.dart:527)
Edit fields are populated via `fmtFreq` (rounds to 100 Hz) while storage/display support
1 Hz: selecting a QSO stored at 14074.25 immediately flags it as changed and saving
writes back the rounded value. Any FT8/CAT-imported log degrades on edit.

**P1-22 · Whole logging panel + QsoList rebuild on every call-field keystroke.**
[logging_controls.dart:1637](packages/halo_widgets/lib/src/logging_controls.dart:1637) →
[logging_panel.dart:142](app/lib/views/operation/logging_panel.dart:142)
`_onCallChanged` unconditionally fires `onCommandMessageChanged(null)`; the panel
responds with an unconditional `setState`, re-running day bucketing, per-column
`TextPainter` measurement, and `scoresByDay` — O(n) over the whole log per keystroke,
twice once the describe-debounce fires. *Fix:* skip when the message didn't change.
Related: `OperationView` re-creates the QSO watch stream inside `build()`
([operation_view.dart:186](app/lib/views/operation_view.dart:186)) — drift re-runs the
query on every rebuild; cache it in state.

**P1-23 · Day-header score badges go stale after every logged QSO.**
[scoring_service.dart:29](app/lib/services/scoring_service.dart:29)
Known DESIGN §11 TODO, but the new pinned headers make it user-visible: the header's
QSO-count (computed fresh) and score badges (from stale `localData`) diverge within the
same header until the operation is reopened. Even the `onCallListLogged` batch path
never re-fetches the rescore result into `_operation`. The fingerprint approach in the
DESIGN TODO (exclude `score_cache` from the change signal) is the right shape.

**P1-24 · UTC day-header labels future days "Yesterday".**
[qso_list.dart:644](packages/halo_widgets/lib/src/qso_list.dart:644)
A day 2+ days in the future falls past the Tomorrow/Today branches into
`diffInDays <= 2 → 'Yesterday'`. A date typo or clock-skewed synced device produces a
QSO three days ahead whose header reads "Yesterday". (The UTC bucketing math itself is
correct — no local-time leakage found.) Also: null `startAtMillis` buckets under a
"Jan 1 1970" header.

**P1-25 · `setState` after `await` without `mounted` checks** in
[operation_view.dart:59](app/lib/views/operation_view.dart:59) (`_load`),
[settings_view.dart:1164](app/lib/views/settings_view.dart:1164), and
[settings_view.dart:1295](app/lib/views/settings_view.dart:1295) (`_doOAuth` success
path) — every *other* await in these files has the guard.

**P1-26 · Data-file ETag persisted before processing succeeds.**
[data_file_manager.dart:96](app/lib/services/data_file_manager.dart:96)
If bridge processing throws after download, the next sync gets a 304 and stamps the
dataset fresh — missing/stale for up to `maxAgeInDays` (14) unless the user knows to run
RELOAD. Persist the ETag only after processing completes.

**P2-27 · Dark-theme and i18n gaps:** hardcoded `Colors.black` in the info area renders
black-on-dark-brown in dark mode
([logging_controls.dart:2498](packages/halo_widgets/lib/src/logging_controls.dart:2498));
day-header weekday/month abbreviations and EventRow labels are hardcoded English inside
the widget package while the app ships `es`
([qso_list.dart:610](packages/halo_widgets/lib/src/qso_list.dart:610)).

**P2-28 · Assorted UI issues:** undisposed controllers in `_newOperation`
([home_view.dart:134](app/lib/views/home_view.dart:134) — violates the convention
documented in operation_dialogs.dart); `showFormDialog` sets
`barrierDismissible: false`, contradicting docs/design/user-interface.md, and leaks its
`ValueNotifier` ([form_renderer.dart:1020](packages/halo_widgets/lib/src/form_renderer.dart:1020));
form `submit` snapshots values before per-field awaits — edits during slow validation are
silently dropped; removed-field controllers/values leak and still submit
([form_renderer.dart:266](packages/halo_widgets/lib/src/form_renderer.dart:266));
`DropdownButtonFormField` crashes on a definition value not in options;
extension-supplied regex compiled without try/catch in
[activities_view.dart:149](app/lib/views/operation/activities_view.dart:149) (the same
contract is guarded correctly in ref_chips_input.dart:163);
`removeDataFile` deletes lookups by `key` but rows are written under
`category ?? key` ([data_file_manager.dart:360](app/lib/services/data_file_manager.dart:360));
concurrent `LocationService.start()` calls leak a position stream; restored notices
reappear active but with action buttons stripped; `_appVersion` hardcoded in
settings_view.dart with a keep-in-sync comment — use `package_info_plus`.

### 3.4 TypeScript extensions & SDK

**P0-29 · The lofi device `secret` is never seeded — every client registers with the
constant `'no-secret'`.**
[extension_service.dart:378](app/lib/services/extension_service.dart:378),
[index.ts:62](extensions/sync/ham2k-lofi/src/index.ts:62)
`setSyncCredentials` seeds only `key` and `call`; the extension's header comment claims
`key`/`secret` are seeded and is wrong. The per-install `key` UUID (SharedPreferences,
not secure storage) becomes the sole bearer credential for the user's entire synced log.
*Fix:* generate and seed a real per-install secret (secure storage), or update the
comment + threat model deliberately.

**P1-30 · HamDB `"NOT_FOUND"` sentinel handled for names only; a NOT_FOUND grid crashes
the merge and discards the whole result.**
[hamdb/src/index.ts:62](extensions/lookups/hamdb/src/index.ts:62),
[mergeLookup.ts:79](extensions/core/lookups/src/mergeLookup.ts:79)
`city`/`state`/`country`/`grid` pass through unfiltered → literal "NOT_FOUND" reaches
the UI and ADIF exports; verified experimentally, `gridToLocation('NOT_FOUND')` throws
inside the merge fold, silently discarding HamDB's valid name/city data too. Common for
Canadian/German records. Compounded by **P1-31**.

**P1-31 · Per-hook lookup failures are swallowed with no logging.**
[lookups/src/index.ts:24](extensions/core/lookups/src/index.ts:24)
`invokeAllSequential`'s `{ok:false, error}` entries are ignored — not even `host.log`.
Makes P1-30-class bugs invisible in the field. Violates Rule 12.

**P1-32 · Silent sync-account fork on persistent 401.**
[ham2k-lofi/src/index.ts:89](extensions/sync/ham2k-lofi/src/index.ts:89)
On 401 the token is dropped and `registerClient` runs unconditionally; if the 401 means
the account link was revoked (not token expiry), the device silently becomes a new
anonymous client and pushes land in a different account — data "vanishes" from the
linked account with no signal.

**P1-33 · QRZ credentials in GET query strings transit Ham2K's web proxy; no login
backoff.** [qrz/src/index.ts:75](extensions/lookups/qrz/src/index.ts:75)
QRZ's API forces credentials-in-URL, but on web `_resolveFetchUri` routes
`xmldata.qrz.com` through `services.ham2k.net` — passwords land in proxy access logs
(privacy/consent issue worth an explicit decision). With bad credentials, every
debounced keystroke lookup re-attempts login (rate-limit/lockout risk; app-polo
throttles).

**P2-34 · Assorted extension issues:** ADIF export fabricates `MODE: SSB` for
mode-less QSOs and computes ADI field lengths in UTF-16 units (byte-counting importers
misparse non-ASCII names) ([adif/src/index.ts:51](extensions/core/adif/src/index.ts:51));
QRZ `tag()` never decodes XML entities (`&amp;` exported literally);
dupe detection never resets at UTC-day boundaries — valid day-2 repeats in a multi-day
POTA activation flag as dupes ([scoring/src/index.ts:40](extensions/core/scoring/src/index.ts:40));
`parkCache`/`summitCache` unbounded and permanently cache 404s (a park added mid-session
never resolves); SOTA `ValidTo` parsed in local time, `ValidFrom` ignored;
POTA `Date.parse(spotTime + 'Z')` breaks if POTA ever adds a zone suffix (SOTA guards);
JS-side `hostCall` promises never time out; SOTA sends `spot.icon` which the `Spot` type
doesn't declare; stale identifiers (`AGENT = 'polo-next-spike'`, lofi UA `0.1.0`).

---

## 4. What's *not* broken (verified)

Worth recording so future reviews don't re-litigate:

- UTC handling in halo_core persistence and QSO-list day bucketing (epoch millis,
  `isUtc: true` throughout, `millis % day` on UTC epoch).
- Maidenhead grid math, including pole/antimeridian clamping.
- Drift migration history (index present since v1; v2/v3 purely additive).
- Bridge request/response correlation (monotonic ids, late results dropped,
  `fatalError` fails all pending).
- No remote-code-execution path: extension bundles load exclusively from baked assets.
- Coarse-batching where it matters: scoring and lookup pipelines are one bridge call.

---

## 5. Process & tooling gaps

1. **No CI.** No `.github/workflows` in this repo; `tsc --noEmit`, `node --test`,
   `flutter test`, and `flutter analyze` are never enforced. (If CI lives in
   `app-halo-dist`, document that here; the four test suites in this repo are healthy
   and cheap to run.)
2. **Extension bundles are gitignored build artifacts with no build coupling.**
   `app/assets/extensions/*.js` regenerates only when someone remembers
   `npm run build`; only `scripts/deploy-web.sh` automates it. A developer editing
   `extensions/` and hot-reloading the app tests stale bundles. *Fix:* a pre-build hook
   (Flutter build step or mise task) + CI check that committed source and `index.json`
   are consistent.
3. **`build.mjs` semver externalization check is a tautology** — it passes the root
   `package.json` deps as every extension's "requested range"
   ([build.mjs:41](extensions/build.mjs:41)).
4. **Docs drift:** `hooks.md` command contract wrong (§2 table); DESIGN §11's
   plaintext-credentials row stale; DESIGN §6 schema shows namespaced `lookups` +
   `extension_kv` that don't exist; lofi extension header comment describes seeding that
   doesn't happen.

---

## 6. Suggested remediation order

**Milestone A — data integrity (small, high-stakes): ✅ done 2026-07-14**
1. ~~Add `updatedAtMillis` to operations/qsos; conditional `markSynced` (P0-1) and
   compare-on-merge (P0-2).~~ Done (`ef7b4da`, schema v4).
2. ~~Server-derived watermarks (P0-3) + tie-safe paging (P1-4).~~ Done (`17260b0`;
   cursors page to `earliest+1`, single-stamp full pages grow the pull limit).
3. ~~Sync generation lock around reconciliation (P1-5); single-transaction wipe (P1-6);
   log sync errors (P2-7).~~ Done (`17260b0`; P2-8's dispose flag included).
4. ~~Fix `_wipe`/time-freeze logging bugs (P0-19, P0-20).~~ Done (`44fabd5`; also the
   More-dialog save variant of the freeze, and name restore on wipe-undo).
5. ~~Seed a real lofi secret or consciously accept key-only auth (P0-29).~~ Done
   (`2eb90a2`): the secret is app-polo's build-config *app attestation* value, now
   injectable via `--dart-define=HAM2K_LOFI_SECRET`; stale comments fixed. Residual:
   the per-install device key stays in SharedPreferences as the de-facto bearer
   credential — move to secure storage in Milestone C.

**Milestone B — extension-runtime robustness: ✅ done 2026-07-14**
6. ~~Isolate `onError`/`onExit` → `fatalError` → restart in `ExtensionService`
   (P1-14).~~ Done (`3d913dd`; includes fail-fast `isDead`, full `dispose()`
   cleanup, restart with capped backoff + KV re-seed, and the misleading web
   "isolate mode failed" warning). Isolate-mode death can't be exercised under
   flutter_test — that path is review-verified only.
7. ~~The hang-family fixes: `invokeHookAll` try/catch, encode-before-deliver, body
   timeout, `_outstanding` cleanup (P1-15, P1-16).~~ Done (`3d913dd`; outstanding
   ids also close L6's forged-result pump stall).
8. ~~Cache settings/account context per invocation (P1-17).~~ Done (`3d913dd`;
   in-flight-promise cache, 3s TTL, host-side `invalidateHookContext` on
   settings/credential writes).
9. ~~Lookup error logging (P1-31) + HamDB NOT_FOUND filtering (P1-30).~~ Done
   (`b35a77f`; mergeLookup also drops malformed grids instead of voiding the
   source's whole result).

**Milestone C — before any third-party / OTA extension channel (blocking):**
10. Host-derived caller identity for all host calls (P0-11); manifest-declared fetch
    allowlists (P0-12); QuickJS interrupt + memory limits (P1-13) — likely the direct
    FFI binding DESIGN already planned.
11. SDK contract versioning (`minCatalog`-style) + discriminated `Hook` union;
    fix hooks.md.

**Milestone D — quality-of-life (fold into feature work):**
12. `watchOperation(uuid)` reactive stream; retire manual refresh + localData merge
    (also resolves P1-23's staleness half).
13. Keystroke rebuild fixes (P1-22) and stream caching; frequency round-trip precision
    (P1-21).
14. CI + bundle build coupling (§5); i18n/dark-mode sweep (P2-27); extract command/time
    concerns from `LoggingControls`.

---

*Generated by Claude (four-agent deep review + manual verification), 2026-07-14.*
