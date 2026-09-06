# The App Clock — one "now", and how to move it

> Status: as-built · Last updated: 2026-08-19

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
| `peer_trust.dart` — `pairedAtMillis`, `lastSeenAtMillis` | Per-peer, and outlives the session that paired |
| `extension_service.dart` — `extensionDisabledSince` | Persists; it gates a 7-day purge grace window |
| `geoshape_service.dart` — the cached shape's stamp | Persists, and outlives the travel that wrote it |

This is the case that bites hardest, and no bar on *running* sync ever covered
it: **the stamp persists**. It sits in the database
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
| `peer_outbox.dart` — scan debounce window | Its remainder becomes a `Timer` duration |
| `peer_service.dart` — beacon `lastSeenMillis` and the stale-peer cutoff | Both sides of one elapsed-time comparison |
| `peer_ble_transport.dart` — the link keepalive cutoff (`PeerBleLink.now`), candidate `lastSeenMillis` and dial cooldowns, link uptime | Protocol timeouts and rate limiting a real radio. The keepalive's clock is behind a default argument so a test can drive it; the DEFAULT is the contract, and `peer_ble_transport_test.dart` pins it |
| `weather_panel.dart` — fetch-attempt throttle | Rate limiting a real request |
| `map_ready_watchdog.dart` — the visible-time the map's give-up horizon accumulates (`MapReadyWatchdog.now`) | Its remainder becomes a `Timer` duration. Behind a default argument so a test can put it on the same timeline as those timers; the DEFAULT is the contract, and `map_ready_watchdog_test.dart` pins it |

A `Timer` fires on real time and knows nothing about travel, so any duration
handed to one has to be measured on the same clock it will be counted on.

Tests are not policed on *which* clock they use: a test constructs the times
it needs. What a test does have to get right is driving the code's clock and
its timers off the same one — see §7.

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
- **Only TEST data may be written while travelling.** This is the guard rail
  the others used to substitute for. `WritePolicy` (`halo_core/src/repo/
  write_policy.dart`) refuses every operator-initiated write to a record that
  is not test data: editing or deleting a real operation, logging into one,
  editing or deleting a real contact, and bulk-importing into one. A record is
  test data when its station call carries `T` or `TEST` as a whole segment
  (`isTestCall` — `KI2D/T`, `KI2D/TEST`, `KI2D/T/P`, never `W1AW/TESTER`);
  neither is a standard modifier, those being `/P`, `/M`, `/MM`, `/AM`. A
  contact counts when EITHER its operation is a test operation or its own call
  is a test call, which is what lets an operation-less contact be written at
  all.

  Three properties make it hold:

  - It judges the **stored** record, never the incoming edit. Judging the edit
    would let one that adds `/TEST` to a real operation write its own
    permission slip, and every write after it.
  - Its **mirror** is refused too: `/TEST` cannot be cleared from an operation
    while travelling. That one is for the operator rather than the log —
    allowing it would commit the edit and then lock them out of the operation
    on the very next write.
  - An operation **created** while travelling is marked rather than refused,
    per comma-separated callsign. An operation is judged by its stored call and
    there is nothing stored yet to judge, so a refusal there would be
    unescapable; a call-less operation becomes `/TEST`, which is deliberately
    still a test call.

  **Inbound records are never refused.** Receiving real data is fine — the gate
  is about what this device authors — and refusing there would break sync
  itself the moment a developer travelled.
- **Sync runs normally while travelling**, LoFi and peer alike, because
  everything a travelled session can produce is identifiable and purgeable. The
  two DESTRUCTIVE entry points still refuse *before* they act: `forceFullResync`
  (the `SYNCALL` command) and `resolveAccountChange` each back up and WIPE local
  data and then rely on a later round to refill it. That is a different hazard
  from the one the write gate covers — it is about a dev tool triggering a wipe
  at all, not about which records a round carries — so `travelRefusesSync`
  survives for exactly those two, and both return `false` when refused with
  every caller reporting it. The operator's `syncEnabled` setting is never
  written by any of this: a dev tool that switched a persisted preference off
  would leave it off for good if the app were quit before travel ended, with
  nothing on screen attributing the silent loss of sync to the clock.
- **The sync account is not consulted.** Travel used to be refused against an
  email-identified account, with `/TEST` on the account callsign as the opt-out.
  That gate is gone: it keyed on the account, which is informative only, while
  what actually needed bounding was the write. It also depended on
  `syncState['accountData']`, a cache refreshed only when the operator opens
  Settings › Sync — so it failed closed on absence but **open on staleness**,
  which is the wrong way round for a check standing between a dev tool and
  somebody's real log.
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

Two things this design got wrong before, both worth keeping in view because the
shape of the mistake recurs:

**Real-clock stamps and a bar on sync cover different halves.** A revision stamp
PERSISTS, so it reaches the server whenever sync next resumes, long after the
offset is gone — barring sync never protected it. That is why `updatedAtMillis`
and the sequence stamps read the real clock (§1), and it is why removing the bar
costs nothing: the stamps were always the part that mattered.

**A travelled `startAtMillis` on a REAL contact was the actual exposure**, and
it was accepted rather than fixed. QSO times travel by design, so a contact
logged while travelled carried a fabricated time into a real log and reached the
server once travel ended, indistinguishable from a genuine one. The write gate
is what closes it: a travelled session cannot author a real contact at all, so
the worst it can now produce is an obviously-fake `/TEST` operation that the
Test Operation purge machinery removes and propagates.

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

## 7. Time in tests

Two clocks are in play whenever a test drives a delay: the one the test
advances, and whatever the code under test reads the time from. Getting one
right and not the other is the whole of this section.

### Real timers are the default, and the direction of the assertion decides

A timer can fire **late, never early**. So an assertion that something has
**not happened yet** is safe on the real clock — a loaded machine only makes
it more true — and a test built that way stays honest with no machinery at
all. `app/test/peer_ble_transport_test.dart` is written to this rule and says
so in its header.

The other direction has no such protection. *Still* alive after a while, it
retried *at least* n times, the gap *grew* — each of these is falsified by a
timer that merely ran late, which is precisely what a loaded CI box produces.
An assertion of that shape does not belong on real timers at any margin;
widening the durations buys probability, not correctness, and pays for it in
suite runtime.

So: **assert in the safe direction on real timers, or move to a fake clock.**
There is no third option that is merely "careful".

### Faking the timer is not enough

`fakeAsync` replaces `Timer` and `clock`. It does **not** replace
`DateTime.now()`, and therefore does not replace `realNowMillis()` — which is
exactly what §1 tells you to use for a staleness check or a protocol timeout.

Put those two facts together and the failure is silent. The code's timer fires
on fake time while its own comparison still reads the wall clock, so the
elapsed value it computes is always about zero however far the test elapses.
Nothing throws. The branch under test simply never runs, and the test passes
for the rest of its life without exercising the thing it names.

**Both halves have to come off one clock.** Inside a `fakeAsync` zone, `clock`
IS the fake clock that `elapse` advances, so a `now`-shaped seam handed
`clock.now()` puts the code's arithmetic on the same timeline as its timers:

```dart
fakeAsync((async) {
  final link = PeerBleLink(..., now: () => clock.now().millisecondsSinceEpoch);
  async.elapse(const Duration(milliseconds: 150));   // exact, not a bet
});
```

### A clock seam's DEFAULT is the contract, so pin it

Code that reads a clock needs that read behind a parameter before a test can
drive it, and the parameter must default to the real function so production is
unchanged. That default is then load-bearing and completely unguarded: swapping
`realNowMillis` for `nowMillis` reads as an ordinary application of §1's own
"everything goes through the app clock" rule, and `check_clock_discipline`
greps for `DateTime.now()` — which this still isn't — so nothing catches it.
The suite stays green while a travelled session silently expires every timeout
at once.

A seam therefore ships with a test that travels the clock and asserts the value
does **not** follow. Assert it through behaviour rather than by comparing
function references — what matters is that the number does not move, not which
function produced it.

### Elapse inside the boundary, not onto it

`elapse` lands the clock on an exact instant, which makes it easy to write an
assertion that pins `>` against `>=` at the boundary of a comparison. A
millisecond either side of a sixty-second timeout is nobody's intended
behaviour, and a test that fails a behaviourally identical refactor is a cost
with no benefit. Land comfortably inside the interval on one side and
comfortably past it on the other; the boundary itself is not the contract.

### The same shape, for things that are not clocks

A test that races the machine for a **port** fails the same way and for the
same reason — the resource is shared, the timing is not the test's to control,
and the failure lands on whichever test happens to be running. The answer has
the same shape: a seam, an in-memory stand-in, and a small number of real
tests kept to pin what the stand-in assumes.
`app/test/peer_network_fakes.dart` is the worked example.

---

## 8. Where the tests are

Each layer is tested where its failure would actually appear:

| What | Where |
|---|---|
| The clock's arithmetic, anchoring, monotonicity, label | `packages/halo_core/test/app_clock_test.dart` |
| The command's grammar | `extensions/core/dev-commands/src/timetravel.test.ts` |
| The gates, sync interaction, status item, palette absence | `app/test/devtimetravel_command_test.dart` |
| The sandbox really travelling, in the engine that ships | `packages/halo_extension_host/test/sandbox_clock_test.dart` |
| The UI heartbeat's cadence and floor | `packages/halo_widgets/test/wall_clock_test.dart` |
| The `Date` substitution's whole surface | `extensions/sdk/src/appClock.test.ts` |
| Ordinary rounds running while travelled, and the destructive pair still refusing | `packages/halo_core/test/sync_engine_test.dart` |
| **The write gate** — what a travelled session may author, and its escape hatches | `packages/halo_core/test/travel_write_gate_test.dart` |
| **A clock seam's default** — that an injected real-clock read does not follow travel (§7) | `app/test/peer_ble_transport_test.dart`, `app/test/map_ready_watchdog_test.dart` |

The sandbox test runs the real kernel and the real clock-dashboard bundle
deliberately. Replacing a global `Date` either works completely or fails
completely, and only in the engine that ships — no unit test of the formula can
see any of it.
