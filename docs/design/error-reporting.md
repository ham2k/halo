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

### Current rules

| rule | disposition | why |
| --- | --- | --- |
| `web-focus-traversal-null` | `ignore` | An unsound `!` in Flutter's own `ReadingOrderTraversalPolicy`, thrown on every browser focus change on web (ham2k/halo-dist#271). |
| `renderflex-overflow` | `logOnly` | A debug-only layout assertion; release builds clip silently and never throw it. Flutter already stripes the offending widget on screen. |
| `set-state-during-build` | `logOnly` | A build-ordering bug of ours, invisible to the operator: the frame renders stale, the next one is correct. Repeats on every rebuild, so uploading it would bury real crashes. |
| `focus-node-cannot-request-focus` | `logOnly` | `EditableText` losing a race with its own teardown — a field disposed or disabled in the same frame something asks it to focus. The framework recovers; nothing is lost but a caret. |

Each rule carries its full reasoning as a doc comment on its predicate. The
console line for a quiet error names the rule and its tier, so an error that
"vanished" can always be traced back to the rule that claimed it — and, for
everything but the `ignore` tier, carries the stack trace: a quiet tier
returns before `FlutterError.presentError`, so that line is the *only* output
the error gets, and the framework's message names the widget that suffered,
never the call that did it.

### Adding a rule

Add an `ErrorRule` to `ErrorPolicy.rules` with a stable `id`, a one-line
`reason` (it is what prints to the console), and a matcher. Then keep it
**narrow** — a rule that matches by message alone will eventually swallow a
real bug of ours that merely reads the same. Every existing rule has tests in
`app/test/error_policy_test.dart` asserting both that it matches its target
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

## Vendor split

The public repo contains only the `ErrorReportingBackend` interface (no-op by
default) and everything above. The Sentry SDK, the DSN, and the
callsign/account-id attachment live entirely in `app_dist`. A plain
`flutter run` of the public repo uploads nothing at all, but still logs and
still shows notices.

Crash reporting itself is **not** consent-gated (unlike telemetry); only the
identifying user context is, via `SettingsService.consentAppData`, and that
gate lives in the public service so the backend can't bypass it.
