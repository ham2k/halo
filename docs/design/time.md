# The App Clock — one "now", and how to move it

> Status: as-built · Last updated: 2026-08-08

A logger is an application about time. Every QSO carries a timestamp, duplicate
checking is a time window, contests open and close, spots and data files go
stale, and half the UI shows either the clock or an age. Testing any of it
against the real clock means waiting — for midnight UTC, for a contest weekend,
for a 30-day staleness threshold.

So the app reads its "now" from **one** place, and a developer can move it.

---

## 1. The rule

**Nothing in app code calls `DateTime.now()`.** Library code calls `nowUtc()`,
`nowLocal()` or `nowMillis()` — top-level functions from `halo_core`
(`src/app_clock.dart`), all reading `AppClock.instance`.

This is enforced, not encouraged: `scripts/test.sh` runs a `check_clock_discipline`
sweep over `app/lib`, `packages/*/lib` and `app_dist/lib`, and fails the build on
any `DateTime.now()` / `DateTime.timestamp()` that isn't marked. It runs in
`--quick` and in the full gate, first, because it costs a fraction of a second
and its failure is a one-line fix.

A grep rather than a `custom_lint` package: the repo has no custom-lint
infrastructure, and a grep catches the same thing for none of the cost.

The strictness is the point. **A clock only part of the app reads is worse than
no override at all.** A QSO stamped on the travelled clock, sitting next to a
duplicate check run on the real one, produces failures that look like logic
bugs in the logging path — and the developer testing something else pays for
debugging them.

### When you genuinely need real time: `realNowUtc()`

Some reads must not travel. They do not get an exemption comment — they get an
**explicit, named API**: `realNowUtc()` / `realNowMillis()`, whose doc comment is
the contract. `DateTime.now()` stays banned outright.

The test for which one you want: *would a developer time-travelling three days
forward want this value three days forward?* For a QSO time, yes. For the
revision counter that decides whose edit wins, absolutely not.

Two categories qualify. Every real-clock call site in the tree is listed below —
keep these tables complete, because they are what an audit greps against:

**1. Values that leave the app and are compared against someone else's clock.**

| Site | Why |
|---|---|
| `repositories.dart` — `updatedAtMillis` on operations and QSOs | The sync revision stamp |
| `sequences.dart` — `updatedAtMillis` | Same |
| `sync_engine.dart` — `backfillFrom` | Leaves as `syncedUntilMillis`; the server pages backwards from it |
| `data_file_manager.dart` — `data_file_updated_*` | Persists, and outlives the travel that wrote it |
| `switch_accounts_dialog.dart` — the challenge clock | Compared against the server's `challenge_expires_at` |

This is the case that bites hardest, and being unable to sync *while*
travelling does not cover it: **the stamp persists**. It sits in the database
long after the offset is gone and reaches the server the moment sync resumes,
where it wins or loses every conflict against another device for the length of
that offset — silently discarding the operator's real edits on whichever device
loses. A shared anonymous account (what the Switch Accounts QR flow links) is
enough; no email is needed.

Note what stays travelled next to it: an operation's `createdAtMillis` and a
QSO's `startAtMillis` are dates the operator reads, and logging into a moved
clock is the entire point of the feature.

**2. Real elapsed time.**

| Site | Why |
|---|---|
| `icom_network_transport_io.dart` — handshake deadline | A protocol timeout |
| `cat_service.dart` — auto-reconnect cooldown, knob-speed clock | Rate limiting a real radio; real-world physics |
| `extension_panel.dart` — render throttle | Its remainder becomes a `Timer` duration |
| `sync_engine.dart` — debounce window | Same |
| `main.dart` — panel-catalog boot budget, DEVHAMMER's run length | Real work, real seconds |
| `dev_log.dart` — event timestamps | Read against the operator's own wall clock |

A `Timer` fires on real time and knows nothing about travel, so any duration
handed to one has to be measured on the same clock it will be counted on.

Tests are not policed: a test constructs the times it needs.

---

## 2. How travel works

Travel is an **offset** plus a **speed factor**, and it is defined by an
*anchor pair* rather than by a bare offset: the real and virtual instants at
which travel was last configured.

```
virtual = anchorVirtual + (real - anchorReal) × speed
```

Anchoring is what makes the two properties the rest of the app depends on true:

- **A speed change is continuous.** Recomputing from a fixed epoch would
  multiply the whole epoch and teleport the clock by decades the moment the
  factor changed.
- **Virtual time is monotonic** for any positive speed. Elapsed-time labels,
  sequence numbers and every staleness check assume time moves forward, so a
  zero or negative speed is refused rather than passed through to break them
  subtly.

Three details that look like nitpicks and are not:

- `travel()` takes **one** real-clock read and derives both anchors from it.
  Two reads are microseconds apart, and a clean `+1h` comes out as
  `59m 59.999s` — which any label rounds down to "+59m 59s".
- `offset` is derived from the anchors, never by subtracting two clock reads,
  for the same reason.
- Both the offset and the speed are **bounded** (`AppClock.maxTravel`, a
  century; `AppClock.maxSpeed`, 1000x), and the offset bound is checked on the
  *accumulated* result rather than one hop's argument. Neither bound is
  tidiness: `DateTime.add` **wraps** on int64 microsecond overflow instead of
  throwing, so a large enough offset lands the clock in a negative epoch where a
  logged QSO's `startAtMillis` renders as garbage and loses every sync
  comparison — and an unbounded speed collapses the UI heartbeat (§5).

There is also a distinction worth keeping straight: `anchoredOffset` is how the
clock was **set**, `offset` is where it has **got to**. Under a factor the second
grows every second, which gives two labels for two kinds of surface:

- `travelLabel` (from `anchoredOffset`) never changes on its own — for a surface
  that rebuilds on its own schedule, like the Sync settings row, where a growing
  string would be stale every time it was read.
- `liveTravelLabel` (from `offset`) is what the clock reads now — for a surface
  that refreshes, like the status-bar item (§4).

**Travel is in-memory only.** It is never persisted, so every launch starts on
the real clock and no one can forget they left the clock three days ahead.

---

## 3. The command

`DEVTT` (or `DEVTIMETRAVEL`), typed into the call field or the ⌘K bar:

| Input | Effect |
|---|---|
| `DEVTT +3h` | jump 3 hours forward |
| `DEVTT -1d` | jump a day back |
| `DEVTT 90m` | unsigned is forward |
| `DEVTT 2x` | run at twice speed |
| `DEVTT 0.5x` | run at half speed |
| `DEVTT +1d 10x` | both, in either order |
| `DEVTT +1d +2h` | offsets sum |
| `DEVTT` | back to real time |

Units are `s`, `m` (minutes, not months), `h`, `d`, `w`, and may be fractional.

**Offsets are cumulative** — `DEVTT +1d` three times lands three days out, so
the command steps. Resetting is the bare form, deliberately, rather than an
offset that happens to cancel out.

An argument it can't read is an **error**, not a non-match: silently dropping
`+3hours` would run a bare `DEVTT` and reset the clock, the opposite of what
was asked.

The parser lives in `extensions/core/dev-commands/src/timetravel.ts`. Everything
that decides whether travel is *allowed* lives app-side, in `HaLoServices`,
because none of it is visible from inside the sandbox.

### It is not discoverable

The hook has **no `catalog`** — not even a developer-mode-gated one, which is
what every other dev command has. The ⌘K palette and the empty-field
suggestions are discovery surfaces, and a clock that disagrees with the
operator's wristwatch must not be something anyone finds by browsing. It also
gets no tester note and no release note.

Outside developer mode `interpret` returns null, so the command does not exist
there at all.

---

## 4. Guard rails

Travel is a developer tool that writes to a real log, so:

- **Developer mode is required**, and turning developer mode off ends travel —
  enforced by one `settings` listener in `HaLoServices`, so it holds no matter
  which surface turned it off. Resetting still works without developer mode, so
  nobody is stranded on a fake clock.
- **A real sync account refuses travel**, and the check **fails closed**. An
  `email` or `pending_email` on the LoFi `current_account` means a real account
  with real logs; `/TEST` as a callsign SEGMENT (`N0DEV/TEST`, never
  `W1AW/TESTER`) is the deliberate opt-out. An anonymous account is fine, since
  nothing else shares it. Sync switched ON with no account payload in hand is
  **refused**: `syncState['accountData']` is a cache of the last successful
  fetch, so a launch that hasn't fetched yet leaves it absent while a real
  account sits behind it, and "absent" read as "anonymous" is the same wrong
  answer as no check at all.
- **Sync does not run while travelling** — and the operator's `syncEnabled`
  setting is **not touched** to achieve it. The two DESTRUCTIVE entry points
  refuse *before* they act: `forceFullResync` (the `SYNCALL` command) and
  `resolveAccountChange` each back up and WIPE local data and then rely on the
  round they schedule to refill it, and that round is exactly what the bar stops
  — so refusing late would empty the live tables with no UI onto the backups and
  nothing that would ever refill them. Both return `false` when refused, and
  every caller reports it; a manual round asked for by a human does too, rather
  than no-op'ing silently. `SyncEngine._mayRun` is
  `settings.enabled && !AppClock.instance.isTravelling`, checked live in the one
  place every path through the engine already consults. A dev tool that switched
  the persisted preference off instead would leave it off for good if the app
  were quit before travel ended — the clock resets itself on launch, a `false` in
  prefs does not — with nothing on screen attributing the silent loss of sync to
  the clock. Nothing is remembered, so nothing can be restored wrongly.
  Separately, turning sync ON is refused while travelling, in
  `HaLoServices.setSyncEnabled`, so every surface (the Sync panel, the All
  Settings row, a settings command) hits the same refusal — the declarative form
  system has no "disabled" flag, so this is what makes it an invariant rather
  than a convention. The Sync row explains itself, and listens to
  `ClockTravel.instance` as well as to settings: ending travel writes no setting,
  so a row listening only to settings would keep saying "unavailable" over a
  control that works again.
- **It is visible.** A status-bar item stands for as long as travel does,
  showing how far the clock is from real time and how fast it is running —
  `+5m at 100x`. It shows the offset and factor rather than a fake time, because
  a time reads as *the* time; the clock face itself is the logging panel's Time
  chip, which ticks on the same `AppClock`.

  It is one line in the item's **title**, with no separate `text`: the collapsed
  footer (the always-visible one) renders `title ?? text`, so a fixed title with
  the changing part in `text` reads as a bare "Time travel" until the bar is
  expanded — which is the one thing this item must not require.

  The item is re-read once per second off the shared `WallClock`, not posted
  once, because **the offset grows**: `DEVTT 100x` sets no offset at all, and a
  snapshot would sit at "at 100x" for a whole session while the clock ran days
  ahead. It is only re-posted when the label actually CHANGES — every post
  notifies the whole status bar, and at 1x with a fixed offset the label never
  changes, so an ordinary travelled session is silent after the first one. The
  subscription is taken when travel starts and dropped when it ends, and
  `WallClock` arms no timer until something listens, so an app that never
  travels pays nothing.

Being unable to sync while travelling is **not** what protects the sync data,
and the first version of this design wrongly assumed it was: a revision stamp
PERSISTS, so it reaches the server whenever sync next resumes, long after the
offset is gone. That is why `updatedAtMillis` and the sequence stamps read the
real clock (§1) — the bar on running sync and the real-clock stamps cover
different halves of the same problem, and neither substitutes for the other.

One residual is known and accepted: a QSO's `startAtMillis` travels, by design,
so QSOs logged while travelled carry travelled times and *will* reach the server
once travel ends. The account gate (above) is what bounds that — and it bounds it
to accounts with no email, which the Switch Accounts QR flow can still have
shared with another device. A developer time-travelling against a linked
anonymous account should expect future-dated QSOs to show up on the other
device.

---

## 5. The UI heartbeat

`WallClock`/`OncePerSecond` (`halo_widgets`) drive every per-second display.
Two things travel changes there:

- Boundaries are boundaries of the *app* clock, but the wait to reach one is
  real time — a `Timer` knows nothing about travel — so the remaining virtual
  milliseconds are divided by the speed. At 2x a displayed second lasts half a
  real second, which is the point of the factor.
- With a **floor** of 100ms on the real interval, independent of
  `AppClock.maxSpeed`. Every subscriber rebuilds on each notification, so a
  heartbeat driven straight off the factor becomes a rebuild storm that takes the
  UI — including the call field the operator needs to type `DEVTT` into — with
  it. Past the floor the displayed seconds simply skip, which is honest at speed.
- A travel change **repaints immediately** and re-aims the timer, rather than
  leaving every subscriber showing the old time until a stale timer fires.

One surface reads the clock outside this heartbeat: the native Clock pane's
sweeping second hand rebuilds per FRAME off an `AnimationController` and reads
`nowUtc()` in its builder (`clock_panel.dart`). It is the only such place, and
it is worth knowing about, because that pane arrived with its animated path on
`DateTime.now()` while its `OncePerSecond` path was already travelling — so an
analog face read real time beside an LCD face reading the offset. The guard
caught it; nothing else would have.

---

## 6. Extensions

Extensions read the clock too — the clock and solar dashboards, `shared/freshness.ts`,
spot ages, ADIF export stamps. An extension on real time while the app is
travelled contradicts everything around it, and reads as an extension bug.

Rather than adding a clock API for every extension to remember to call, **the
kernel replaces the sandbox's `Date`** (`extensions/sdk/src/appClock.ts`, installed
by `kernel.ts` before any bundle evaluates). Ordinary `Date.now()` and
`new Date()` travel for free, including in bundles the SDK never sees, and only a
no-argument construction means "now" — every explicit form is passed through, so
`new Date(ms)` still means exactly what it says.

It is a **`Proxy` around the real constructor, not a `class … extends Date`**.
The class is the obvious shape and is subtly wrong: `Date()` *without* `new` is
legal JS returning a date string, and a class constructor throws when called
that way — so any bundle (or minified date helper) doing it would break with a
TypeError naming a class no extension author has ever heard of. The proxy also
keeps `Date.parse`, `Date.UTC`, `Date.prototype`, `Date.length` and
`instanceof Date` as they were rather than re-deriving them.

The kernel keeps a pristine `realDate`/`realNow` captured before the swap, for
its **own** use: the hook timings it reports to the host (`jsMillis`) and its
context-cache TTLs measure real elapsed work, and a speed factor would silently
skew both — poisoning the numbers we profile with.

The host has to **hand it over**, because travel is main-isolate state while the
runtime lives in another isolate or a worker. Two routes, and both are needed:

- **At boot**, as `ExtensionHost.start`'s `clock:` argument, applied between the
  kernel and the bundles. `start` evaluates every bundle *and* runs their
  activations, so a clock that arrives after it returns has already missed them —
  and an extension reading a date while activating bakes in the real one. This is
  also the path a runtime crash-restart takes while travel is on.
- **On change**, via `setClockTravel` (modelled on `invalidateContext`), from
  `ExtensionService`'s `AppClock` listener.

It sends the **anchor pair**, not an offset, so both sides compute the same
virtual time from the same formula. An offset would already be stale by the
time the message arrived, and under a factor the error would keep growing.

---

## 7. Where the tests are

Each layer is tested where its failure would actually appear:

| What | Where |
|---|---|
| The clock's arithmetic, anchoring, monotonicity, label | `packages/halo_core/test/app_clock_test.dart` |
| The command's grammar | `extensions/core/dev-commands/src/timetravel.test.ts` |
| The gates, sync interaction, status item, palette absence | `app/test/devtimetravel_command_test.dart` |
| The sandbox really travelling, in the engine that ships | `packages/halo_extension_host/test/sandbox_clock_test.dart` |
| The UI heartbeat's cadence and floor | `packages/halo_widgets/test/wall_clock_test.dart` |
| The `Date` substitution's whole surface | `extensions/sdk/src/appClock.test.ts` |
| Sync actually not reaching the transport while travelled | `packages/halo_core/test/sync_engine_test.dart` |

The sandbox test runs the real kernel and the real clock-dashboard bundle
deliberately. Replacing a global `Date` either works completely or fails
completely, and only in the engine that ships — no unit test of the formula can
see any of it.
