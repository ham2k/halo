# Error reporting

What happens to an exception that escapes the code that raised it: where it
is classified, who acts on the classification, and how to change either.

Related: [telemetry.md](telemetry.md) covers deliberate event tracking, which
is a separate system with a separate (consent-gated) privacy model.

## The decision, in one place

`app/lib/services/error_policy.dart` classifies **every** escaped error into
one of four dispositions. Nothing else may hardcode a "but not this one"
check — if an error isn't worth a notice, or isn't worth uploading, that
belongs in `ErrorPolicy.rules` with the reasoning attached.

| disposition | console | backend upload | user notice |
| --- | --- | --- | --- |
| `ignore` | once per session | no | no |
| `logOnly` | every time | no | no |
| `report` | every time | yes | no |
| `notify` | every time | yes | yes |

**`notify` is the default**, and deliberately so: an error nobody has
classified is a bug we haven't seen yet, and it should be noisy. Only a
matching rule can quieten one.

The notice is the once-per-session *"Something went wrong"* StatusBar entry,
with a **Copy details** action. One per session, however many errors follow —
a session with a repeating error must not bury the operator's real notices.
In Next and Regular builds its text is a reassurance; in a Dev build it is the
error itself (cut to a few lines) and the innermost stack frame in our own
code, since whoever runs Dev is whoever will fix it.

### Current rules

| rule | disposition | why |
| --- | --- | --- |
| `write-refused` | `logOnly` | The app declined a write rather than failing at one — a travelled clock over a record that is not test data (`WritePolicy`, [time.md §4](time.md)). An expected outcome carrying its own operator-facing reason, so it is never uploaded and never wears the generic "Something went wrong" notice; `ErrorReportingService.noticeWriteRefused` shows the reason instead, keyed so repeats replace rather than stack. Reaching a global handler at all means a write site did not deal with its own refusal, which is what the console line is for. |
| `web-focus-traversal-null` | `ignore` | An unsound `!` in Flutter's own `ReadingOrderTraversalPolicy`, thrown on every browser focus change on web (ham2k/halo-dist#271). |
| `hot-restart-stale-object` | `logOnly` | An object stranded by a hot reload/restart, read after its class lost the field: DDC returns `undefined` and the failure surfaces as `TypeError: Cannot read properties of undefined (reading 'Symbol(…)')`, typically from framework internals with no line of ours in it. A development artifact that a cold start clears, so it never wears a notice and never uploads. Guarded by `kDebugMode` **and** `kIsWeb` — a reload cannot happen in profile or release, where the same TypeError would be a real compiler or interop bug and stays loud. |
| `renderflex-overflow` | `logOnly` | A debug-only layout assertion; release builds clip silently and never throw it. Flutter already stripes the offending widget on screen. |
| `web-semantics-node-map-inconsistent` | `logOnly` | The web engine's own reachability check over its semantics node map, thrown when a subtree is replaced wholesale in one update and a leaf of the old one is left behind (`_finalizeTree` misses a child whose parent was itself replaced). Costs a stale DOM node and a map entry; nothing on screen changes. Doubly out of a user's reach: the throw sits inside an `assert`, and the accessibility tree is only turned on at all in dev builds (`main.dart`'s `ensureSemantics`, for agent tooling). Reproduced by the pinned `CollapsibleBand`s of the Settings pane; upstream it is the family of flutter/flutter#170753. |
| `set-state-during-build` | `logOnly` | A build-ordering bug of ours, invisible to the operator: the frame renders stale, the next one is correct. Repeats on every rebuild, so uploading it would bury real crashes. |
| `focus-node-cannot-request-focus` | `logOnly` | `EditableText` losing a race with its own teardown — a field disposed or disabled in the same frame something asks it to focus. The framework recovers; nothing is lost but a caret. |
| `extension-host-disposed` | `logOnly` | An in-flight hook call cut off by a deliberate runtime replacement (extension toggle, `restartOnChange` commit, shutdown). The caller self-heals against the new runtime; every subsystem with a call in flight reports the same teardown at once, so uploading it buries real crashes. |
| `extension-runtime-dead` | `logOnly` | A hook call refused fast because the runtime already crashed. The crash itself is reported once with its real diagnostic (`extensions:restart`); these are per-call duplicates of that known state. |
| `hook-timed-out` | `report` | A hook that did not answer within the timeout its caller allowed (`HookTimeoutException`) — a slow upstream service, or an extension taking too long over a large local pass. Every caller already degrades on its own: a lookup returns nothing and the next keystroke asks again, a fan-out keeps the hooks that did answer. The callsign lookup pipeline is why this exists — it reports every timeout it catches, and since the notice fires only once per session, a slow lookup service spends that one notice on something the operator cannot act on and the next real error arrives silently. Uploaded rather than dropped: the rate is what says whether a timeout is too tight or a hook is genuinely hung. Matched on the TYPE alone, so a hook throwing its own "timed out" message stays loud, and a timeout wrapped in another exception (`ScoringHookFailure`) keeps its own rule. |
| `connectivity-backend-unavailable` | `logOnly` | connectivity_plus's Linux backend needs NetworkManager over D-Bus and throws out of its own stream setup without it, unreachable by any onError of ours. The app degrades to no reconnect-resync. |
| `cat-equipment-unreachable` | `logOnly` | A radio that didn't answer a connect attempt — off, unplugged, held by another program, or refusing the login. The equipment row already shows it, and `CatService` retries the designated radio all session, so a rig left switched off would otherwise notify and upload every few minutes. Scoped by the `CatConnectFailure` wrapper `CatService` reports through: only a connect-time `SocketException`/`TimeoutException`/`CatUnreachable` is quiet, so a bug raised inside a connect stays loud. |
| `peer-media-unreachable` | `logOnly` | A peer that refused or never answered the media link a screen pane dials (HALO-369) — a firewall between the two, a peer that left mid-dial. The pane already says "not connected" and re-dials every few seconds; the view reports through the failure streak, which asks the policy before counting, so a refusal this rule matches neither uploads nor spends the streak's one report — a firewall between two peers is not a defect, and the defect that may follow it still reports. Scoped by the `PeerMediaDialFailure` wrapper `PeerScreenViews` reports through: only an `IOException` or `TimeoutException` inside it is quiet, so a bug raised by a dial stays loud. |
| `keychain-cannot-enumerate` | `logOnly` | The keychain refused to LIST its items (`errSecParam`, -50). macOS answers that for a `readAll` against the file keychain this app has to use, so it is a property of the platform rather than a fault of ours. The two callers that ask — copying an extension's secrets onto its new key, and removing them on uninstall — fall back to the account names they can construct without a listing, and carry on; what they cannot construct is a settings-panel secret's field name, so those are left behind there. Console-only because it says the same thing every time and the thing it says is already known, and because the fallback means nothing is lost that a louder tier would recover. Scoped to that one `OSStatus`, read as an int from `details` — the same reading `keychain-locked` does, and -34018 stays loud for the same reason. |
| `keychain-locked` | `report` | The keychain refused an operation with `errSecInteractionNotAllowed`, which it returns whenever it cannot serve one without an unlock it has no way to ask for — a read or a write, on any of the secrets the app keeps there. Usually a locked device with the app still working behind it (the CAT idle-retry loop reopening a radio, an extension fetching an account), which the next unlock resolves; a macOS session that can never prompt is refused for the length of the process. Neither is something the operator can act on mid-activation, and the notice fires once per session — spending it on a background retry leaves the next real error to arrive silently. Uploaded, because the rate says how often the app reaches for a secret it cannot have. Scoped to that ONE `OSStatus`, read as an int from the `details` the darwin plugin puts it in and paired with the one `code` that plugin gives every keychain failure: -34018, a missing entitlement, is a signing defect of ours and stays loud. |
| `network-unreachable-while-offline` | `logOnly` | A network call that got no answer, raised while `ConnectivityService` already believes we have no internet — no route at all, or nothing answering over the one there is. In the field that is the session's normal state, and one event per retry per subsystem for the length of an activation would bury the online failures the two rules below exist to surface. Matched on SHAPE as well as state: only the two internet-facing transport shapes (`host.fetch` wrapped in an `ExtensionHostException`, and `package:http`'s `ClientException`), so a parse bug or a bad token raised during an outage still uploads, and the same timeout online keeps its `report` tier. A bare `SocketException` is deliberately excluded — peer sync's LAN transport throws those, and a LAN or BLE link failing has nothing to do with internet reachability. |
| `fetch-transport-transient` | `report` | A `host.fetch` call failed at the transport layer (connection reset, refused, closed mid-body, or timed out) rather than because of anything our code did; the caller (e.g. `SyncEngine`'s backoff loop) already retries. |
| `extensions-not-wired` | `report` | The extension service was handed no catalog, so nothing can be fetched, adopted or restored. A wiring defect rather than a server that cannot be reached, so it uploads without a notice: the operator can do nothing about it, and the audience is whoever changes the service graph. Matched on `CatalogNotWired`, a type that exists for this rule to name. |
| `catalog-unreachable` | `report` | The extension catalog did not answer — a connection failure or the request timeout — or answered with an error status other than 404 (`CatalogRefused`; a 404 is an answer about a key that does not exist), on a check the operator did not ask for. The service reports it as a failure streak, so a dead catalog is visible in aggregate while a captive portal never wears a notice. Only a 200 resets the streak: a catalog refusing every request would otherwise never report. |
| `bundle-would-not-evaluate` | `report` | An installed extension the JS engine refused, now kept out of the runtime so the rest can load. The operator is told in a notice and on the panel row, so it uploads without a notice — and it must upload, because a refused bundle never loads again and its boot failure stops arriving under `extensions:restart`: the rate is the only thing that tells one bad download from a release the catalog is serving broken to everybody. |
| `upgrade-left-no-runtime` | `report` | Extensions that just arrived — pre-loaded, adopted or restored — left the runtime unable to start even with every bundle the boot named set aside, so the install is running no extensions at all. The operator is told, so this uploads without a notice: what the backend adds is the rate, which is the only way to tell one corrupt download from a bundle the catalog is shipping broken to everybody. |
| `extension-timers-suspended` | `report` | An extension's timers broke their budget and were stopped (`extensions/sdk/src/timerQueue.ts`) — a defect in that one extension, whose hooks keep answering. Developer mode names it in a notice of its own, so the policy adds none; uploaded because in the field it is otherwise invisible: the operator sees a feature stop, and only the rate says whether an extension trips its budget on real hardware. |
| `data-file-remove-hook-absent` | `logOnly` | Removing a data file offers its extension an `onRemoveRawData` hook and most do not implement one, so the kernel answers "no hook registered" — the ordinary case, not a fault, and nothing the operator can act on mid-removal. Matched on that one answer rather than on the `DataFileRemoveHookFailed` wrapper: a hook that exists and threw left raw data behind, and falls through to the default tier where an unclassified failure belongs. |
| `http-client-connection-transient` | `report` | A direct `package:http` call (`DataFileManager`'s download, not `host.fetch`) failed at the connection layer (DNS, refused, reset), reaching the policy as a raw `http.ClientException` rather than an `ExtensionHostException`. Scoped to the type alone — deliberately excludes a bare `TimeoutException`, too generic a type to match app-wide; the download's own timeout arrives wrapped (`data-file-unavailable`). |
| `data-file-unavailable` | `report` | A data file's server did not answer within the headers or body timeout, or answered with a status other than 200 or 304 (`DataFileUnavailable`, naming the key, the host, and which wait ran out or the status). The offline data already on the device stays and the next pass retries; a refresh the operator asked for (a Refresh tap, Update All, RELOAD) raises its own translated notice, so the unattended boot and reconnect passes stay quiet. Uploaded for the rate per host. |
| `data-file-import-shrank` | `report` | A data file mapped to fewer than 30% of the rows its category already holds, so `DataFileManager` refused it before the stale sweep could delete the rest (`DataFileImportShrank`). The file stays unstamped for the next pass and its Offline Data row says the last download was refused; an explicit refresh (a Refresh tap, Update All, RELOAD) is forced, accepts it, and is reported the same way (`forced`). Uploaded because only the rate tells a source serving short bodies from a broken mapper. |
| `malformed-qson-data` | `report` | A QSON record reached storage with a field typed differently than the model reads it — a `String` freq, a `bool` mode (`qson_values.dart`'s normalizer, raised on the write paths, `encodeQsoData`/`encodeOperationData` in `repo_support.dart`). Nothing is broken by the time it is raised: the value has already been parsed or dropped and the record stored. It is uploaded purely to identify the WRITER, which read-side coercion alone leaves unknown, and reported at the first occurrence per write path and field rather than once per sync round. The same normalizer also runs on the READ path (`qsoFromRow` in `repo_support.dart`, `_operationFromRow`), healing a record stored before the writers coerced anything, and reports there too under the contexts `qsos:read`/`operations:read` — it has to, because healing on read hands the write path a clean map, so an edit to such a record would otherwise stop reporting it and the fix would cost the very signal that says those records exist. Read-path reports are sampled per decode batch rather than emitted per row: the question is which fields arrive wrong-typed, and the first few answer it. The violations travel back out of the decode isolate as data rather than reporting in place, so a large operation reports the same as a small one. |
| `map-offline` | `logOnly` | A `MapError` stamped offline at arrival (`ConnectivityService`): with no network every style and tile fetch fails as a matter of course, and that is the normal state of an off-grid activation. The same error online stays loud — that's the evidence a "why is my map blank" report needs. |
| `database-closed-on-exit` | `logOnly` | A write that landed after the database was closed on the way out. Usually a sync round or a peer event whose reply arrived during the quit, but it covers the operator's own last edit just as much: past the close, no write of any origin has anywhere to go, and a notice the process outlives by milliseconds helps nobody. Matched on the message drift's BACKGROUND isolate raises (the shipped connection type; the in-process wording is matched too, for tests and any future same-isolate connection). Scoped to the quit itself (`ErrorPolicy.appIsExiting`, set by `shutdownOnExit`) as well as to drift's two post-close messages: nothing else ever closes the database, so the same error mid-session means something closed it that shouldn't have, and that stays loud. |
| `unclean-database-quit` | `report` | The **previous** run's teardown did not finish: its stage mark (`markQuitStage`'s pref) survived the process, naming the step that was still running — saying goodbye to the radios, draining the database, or closing it. Whichever it was, writes the run still had queued went with it. Each step marks itself BEFORE it runs, so the stage found is the step in progress rather than the last one that succeeded; the radios matter most, because a serial close wedges instead of failing and a wedged quit leaves a process that never dies to report anything. Reported from the next boot, which is the first moment anything can be: the quit itself has no time to reach the backend. Uploaded rather than noticed — what was lost is already lost, and the rate across installs, per step, is what says whether the quit path is sound. A quit that died AFTER the teardown finished, in the engine's own VM shutdown, leaves no mark at all: it is cleared by then and no Dart runs afterwards to write another. |
| `log-from-newer-build` | `logOnly` | The log on disk was written by a build with a higher `schemaVersion`, and drift's downgrade path refuses it rather than stamping it back down (`LogFromNewerBuild`, [database.dart](../../packages/halo_core/lib/src/db/database.dart)). The operator has already been told more than a generic notice could say: the database is opened deliberately in `bootstrap()`, so boot posts a notice naming both storage versions and the folder the log is in, instead of an app that quietly stops saving. Console-only rather than uploaded because a refused database refuses **every** query — each stream rebuild, sync round and list read — and `report()` has no dedup, so a single session would upload the same fact thousands of times. The cost is that a downgrade in the field is invisible to the backend; recovering that needs a once-per-session upload path, not a louder tier here. Matched through `LogFromNewerBuild.within`: the app opens its database over a background isolate, so the refusal arrives wrapped in a `DriftRemoteException` and a bare `is` test would never fire outside a test harness. |
| `preferences-file-unreadable` | `report` | The preferences file did not parse and `guardPreferencesFile` repaired it at boot — the backup put back, or defaults where there was no usable one ([app_storage.dart](../../app/lib/services/app_storage.dart)). Uploaded rather than noticed only because the operator has ALREADY been told, by a status notice that names which of the two happened and where the unreadable file was moved to; the generic notice on top of it would say strictly less. The rate is what says whether the atomic write actually closed the window it exists to close. |

Each rule carries its full reasoning as a doc comment on its predicate. The
console line for a quiet error names the rule and its tier, so an error that
"vanished" can always be traced back to the rule that claimed it — and, for
everything but the `ignore` tier, carries the stack trace: a quiet tier
returns before `FlutterError.presentError`, so that line is the *only* output
the error gets, and the framework's message names the widget that suffered,
never the call that did it. The one exception is a quiet failure handed to
`reportIfRepeated` (below): it prints nothing here, because its call site
prints its own attempt line and the call may repeat every few seconds.

### Adding a rule

Add an `ErrorRule` to `ErrorPolicy.rules` with a stable `id`, a one-line
`reason` (it is what prints to the console), and a matcher. Then keep it
**narrow** — a rule that matches by message alone will eventually swallow a
real bug of ours that merely reads the same. Every existing rule has tests in
`app/test/errors/error_policy_test.dart` asserting both that it matches its target
*and* that a near-miss stays loud; match that.

Set `logOncePerSession` only for `ignore`-tier noise, where the whole point
is that it fires constantly.

**Check the type before the message.** Every matcher runs against every
error, from inside the error handler itself, so a matcher that calls
`toString()` on an object it hasn't type-checked can raise a second exception
where the first one is lost — and, on the async path, re-enter the handler
that raised it. Matching a framework type first also keeps the rule narrow:
an exception of ours quoting a framework message stays loud.

## Who applies it

`app/lib/services/error_reporting_service.dart` is the plumbing. It installs
the hooks around `runApp()` — long before `bootstrap()` exists — and carries
each decision out to the console, the backend, and the StatusBar:

- **`FlutterError.onError`** — framework errors (build, layout, paint). The
  chain stops before `previousOnError` (where a real backend's own capture
  hook lives) for anything below the `report` tier.
- **the fallback zone** — uncaught async errors when no backend took
  ownership of startup.
- **`ErrorReportingService.report(error, stack, context:)`** — an explicit
  catch. Also policy-gated, so a `try/catch` added later can't force known
  noise into the backend.
- **`ErrorReportingService.reportIfRepeated(key, error, stack)`** — a
  retried call that reports once it has failed three times running. It asks
  the policy *before* counting: a quiet failure neither advances the streak
  nor resets it, so a call whose common failure is noise (a firewalled peer,
  no internet) still reports the defect that follows.
- **the backend's own capture hook** — for the real (Sentry) backend, this is
  the *only* path an uncaught async error takes: on web it arrives through
  Sentry's zone rather than `PlatformDispatcher.onError`, so the local hook
  never sees it. It applies the same policy and drops the event outright
  below the `report` tier.

A widget whose build throws also degrades to the compact `HaLoErrorTile` in
its own slot (`ErrorWidget.builder`) rather than taking the app — or the raw
grey box — with it.

## What this is *not*

Local `catch` blocks that recover at the point of failure — an extension host
call falling back to an empty list, a data file refetch, a lookup timing out
— are not part of this. They pick their own fallback value and log with their
own `[tag]` prefix; only what escapes them reaches the policy. Some of them
also call `report()` deliberately, which is how a swallowed-but-notable
failure gets uploaded without a notice.

`SyncEngine.onAuthError` is likewise separate: an expired token is an outcome
of the sync flow, not a bug, so it is never crash-reported and gets its own
status-bar notice instead.

`ErrorReportingService.breadcrumb(message, category:)` is separate too: it
records context, not an event, so there is nothing for the policy to decide —
it always reaches the backend and rides along with whatever that backend
captures next, including a native crash that reaches none of the hooks above
at all. A *synchronous* backend failure is swallowed (call sites run this
right before their own `dispose()`, which must always still run); an
asynchronous one is not — same as any other unawaited call — and can still
reach the fallback zone above.

`ErrorReportingService.diagnostic(title:, body:)` and
`updateEquipmentContext(radio:)` are outside the policy for the same reason:
neither is an error, so there is nothing to decide. The diagnostic is an
info-level report that groups by its title — a benchmark result, or the
first-success radio report, which is app-initiated and gated on
`consentAppData` at its call site ([telemetry.md](telemetry.md) § Radios owns
that rule). The equipment context is a scope tag naming the connected radio's
catalogue key, so every later event says what was on the other end of the
cable. Both swallow a synchronous backend failure, exactly as `breadcrumb`
does and for the same reason: they ride along with something the operator
actually asked for, and a reporting backend that cannot send must not take
that with it.

## Vendor split

The public repo contains only the `ErrorReportingBackend` interface (no-op by
default) and everything above. The Sentry SDK, the DSN, and the
callsign/account-id attachment live entirely in `app_dist`. A plain
`flutter run` of the public repo uploads nothing at all, but still logs and
still shows notices.

Crash reporting itself is **not** consent-gated (unlike telemetry); only the
identifying user context is, via `SettingsService.consentAppData`, and that
gate lives in the public service so the backend can't bypass it.
