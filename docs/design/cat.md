# CAT — station equipment and radio control

Controlling radios — and eventually antenna switches, rotators and relay boards — from the app.
Everything here is behind the Station Configuration experiment (`EXP CAT` in the call field; its stored key is still `gato`, see experiments.yaml) until it is ready.

This document records the shape of the layer and, more importantly, *why* it is that shape. The
model it serves is in [data-model.md](data-model.md) § Stations.

## The constraint that decides everything: JS cannot hold a connection

The obvious design is "equipment is another extension type" — extensions already contribute
activities, contests, spots, lookups and exports. That does not work here, and it is worth being
precise about why, because the reason is structural and not going to change on its own.

`packages/halo_quickjs/src/halo_qjs.h` exports exactly ten `halo_qjs_*` functions. There is no
`setTimeout`, no `setInterval`, and no socket. The JS job queue is pumped from Dart by
`ExtensionHost._ensurePumping` — a 5 ms `Timer.periodic` that **cancels itself the moment no hook
call is outstanding**. JS runs only while Dart is waiting on it.

So a JS hook cannot:

- poll a radio on a timer,
- hold a socket or serial handle,
- buffer a partial frame across time,
- push an unsolicited frequency change up to the app.

All three app-polo drivers do all four of those things (`FlexRadioDriver` runs a 60 s resync
`setInterval`; the FT-891 and IC-705 drivers run 5 s poll loops; all three keep mutable session
closures). That code does not port. On top of that, the JS runtime restarts on any extension
enable/disable and on a crash-backoff — driver state in JS would evaporate mid-QSO while the
socket stayed open, a failure mode polo had no analogue for.

HaLo's own precedent already answers this. Every long-lived concern in the app keeps its loop in
Dart and lets the extension supply one stateless call:

| Concern | Dart owns | Extension supplies |
|---|---|---|
| Sync | `SyncEngine`'s loop | `syncTransport` — moves one payload |
| Data files | `DataFileManager`'s scheduling, download, cache | `dataFile` — a URL and a row mapper |
| Spots | `SpotsPanel`'s `Timer.periodic` | `spots.fetchSpots` — one fetch |

**CAT follows the same rule: Dart owns transports, sessions, timers, framing and state.**
Handlers are Dart classes in a registry. There is no `equipment` hook category, and adding one for
a capability with no author waiting on it would be speculative surface.

When a third-party author does need to define a rig, the bolt-on point already has a precedent:
`SettingsView` merges Dart `SettingsGroup`s and JS `settingsPanel` hooks into one sorted list.
`EquipmentRegistry` can gain an extension-fed source the same way. The likely shape is a
*declarative* rig definition — command templates, response patterns, a poll list, interpreted by
Dart — not executable JS.

## Layering

```
Settings → Station Configuration      app/lib/views/station_panel.dart
   │ reads/writes
CatService (ChangeNotifier)          app/lib/services/cat/cat_service.dart
   ├── EquipmentRegistry              equipment_registry.dart   — the type catalogue
   ├── transports                     transports/tcp_transport.dart (conditional export)
   └── per-node _NodeRuntime          connection + session + status, keyed by node uuid
   │ writes vfoA (P3)
RadioService                          app/lib/services/radio_service.dart
   │ VfoStore
LoggingControls                       packages/halo_widgets/lib/src/logging_controls.dart
```

### Transport ≠ driver

A **transport** knows about sockets and bytes and nothing about radios. A **driver** knows about a
radio's protocol and is handed nothing but already-framed bytes. This is what polo concluded and
wrote into its own code — `Ic705Driver.js`'s header: *"This driver only deals in already-framed
bytes handed to it by a transport — it has no idea whether those bytes arrived over the network,
USB-serial, or anything else."* Its architecture review explicitly *undid* the one place the
separation had leaked (radio-model identification by USB VID/PID had ended up inside the transport).

The user-facing **equipment type** is the (model × transport) pair — the picker offers
"FlexRadio (SmartSDR) — Network" and would offer "Yaesu FT-891 — USB serial" and
"Yaesu FT-891 — Bluetooth" as separate entries, each with its own transport and its own connection
parameters. That is the duplication that is worth having: it is glue, it is small, and it lets each
combination present exactly the settings it needs.

The **protocol codec stays one shared pure file per protocol family**. Duplicating glue is cheap;
duplicating frame parsing duplicates parsing bugs. Polo's evidence is unambiguous — its pure codec
files were its highest-confidence code, and every bug it had to fix lived in an I/O layer.

### Drivers never touch app state

A session is constructed with an `EquipmentSink` — `send` and `report` — and never sees a socket,
a timeout, a reconnect policy, or any store. Polo's drivers called `dispatch(setVFO(...))`
directly, which works for exactly one radio and couples every driver to the app's state shape.
Reporting readings to the manager instead is what makes a driver testable with a plain fake sink,
and what makes a second device a map lookup rather than a rewrite.

`CatService` is the only writer of CAT-sourced state.

## Cancellation, and the races it prevents

`EquipmentTransport.connect` takes a `CatCancelToken` **in its first signature**, deliberately.
Dart has no `AbortController`, and `Socket.connect(..., timeout:)` returns a future that cannot be
cancelled — so without an explicit token, a superseded connection attempt holds its socket through
the entire handshake timeout. Polo's comment on why that matters is worth keeping: *"some radios
don't take kindly to two overlapping connection attempts hitting them at once."* Retrofitting
cancellation across every transport is exactly what cost polo a whole hardening pass.

Every piece of per-connection state is **keyed by node uuid**, not held in a service-level field.
Polo's connection layer was module-level singletons (`activeConnection`, `connectAttemptSeq`,
`vfoSubscriberCount`), and that is what blocked a second device. Doing it per-node costs nothing
now and is a rewrite later.

The guards, and the polo bug each one prevents:

| Guard | Without it |
|---|---|
| Per-node attempt sequence, checked after `connect` resolves | Overlapping connects leak the loser's socket |
| Session identity compared in the `closed` handler | A stale connection's close clobbers the live one's status |
| Cancel token passed into `connect` | A superseded attempt runs its full handshake against the radio |
| `session.teardown()` before `connection.close()`, each in its own guard | Abandoned sessions accumulate on the radio — polo saw an IC-705 refuse new connections *across a power cycle* |
| `send` swallows write errors | A stale write throws into an unguarded driver timer |
| Updates start on connect, refcounting only governs *stopping* | Connect-before-any-UI-subscriber connects successfully and then never asks the radio anything: green status, frozen frequency |

## Framing

`EquipmentSession.handleData` receives raw chunks and **must not assume a chunk is a whole frame**.
Polo's FlexRadio driver split each chunk on `\n` with no residual buffer, so a status line
straddling two TCP reads was mangled. The Dart port keeps a residual buffer; there is a test for it.

## Persistence

Equipment lives in one versioned JSON map under a single SharedPreferences key, via the existing
`_jsonMapPref` primitive — the same shape as `profiles`, `layout`, `syncState` and `radioVfoState`,
and for the same reason given in DESIGN.md § 6: a handful of config records, not per-row data.

It is **device-local and not synced**. Physical equipment is per-shack, and every comparable
setting in the app is device-local already.

**Live status is never persisted.** Polo shipped a stale `connected` flag, and then a data-loss bug
from renaming a persisted key that needed a rehydrate reducer to recover from. The stored record is
what the user configured; everything about a connection is rebuilt at runtime.

## Units and modes, fixed at the manager boundary

- **Frequency is kHz with decimals**, matching `Vfo.freq`. Polo shipped a driver reporting Hz and
  got frequencies 1000× too large; it also learned not to round to whole kHz.
- **`SSB` is resolved to `USB`/`LSB` before a driver ever sees it.** No CAT protocol has an "SSB"
  mode. The convention: 160/80/40 m are LSB, everything else USB (including 60 m, which is
  channelized USB by international agreement despite being below 10 MHz).

## Testing a radio with no radio

1. **Codec tests** — sessions are pure given a fake sink. The FlexRadio fixtures are real lines
   captured from a live FLEX-6600 (SmartSDR v4.2.20.41343), carried over from polo's spec.
2. **Session timing** — `fakeAsync` for the resync interval. Keep these out of `testWidgets`.
3. **Loopback** — a real `ServerSocket` on 127.0.0.1 playing a scripted dialogue against
   `CatService`. This is the only tier that catches framing across chunk boundaries, cancellation,
   and the ordering races above.

None of that tests what a radio actually emits. Polo shipped **one** hardware-verified driver and
deleted the one it could not make reliable. `EquipmentDriver.hardwareVerified` records which is
which, and the type picker shows it, rather than presenting every driver as equally trustworthy.

## Serial, and what it costs

The FT-891 is the first driver on a second transport, and it is what proves the split: Yaesu CAT is
ASCII terminated by `;` over a serial port, FlexRadio is a different text protocol over a socket, and
neither driver nor transport had to learn anything about the other.

Serial is `flutter_libserialport` (FFI, the same shape as the existing `halo_quickjs` plugin), behind
the same conditional-export barrel as TCP. Desktop only: Android's USB host stack needs a different
package and a runtime permission flow, and iOS has no USB host API at all without MFi.

**Baud is the operator's to set.** app-polo hardcoded 4800 with no UI, which its own notes call out
as a silent-failure mode — a radio whose CAT menu says 38400 answers with garbage and no error, and
nothing on screen suggests why.

**Enumeration must not throw.** The port list comes through `dart:ffi`, so it fails outright when the
native library is missing — a Linux box without libudev at runtime, or any test process. It degrades
to an empty list, because the port picker saying "no serial ports found" is far better than the
equipment editor failing to open.

Platform cost, none of it optional:

- `com.apple.security.device.serial` in **both** macOS entitlement files. A sandbox relaxation, not
  one of the AMFI-restricted entitlements that break spawning — but verify against a real port on a
  **signed Release build**, since Debug passes regardless.
- `libudev-dev` in the Linux CI dependency list, and `libudev-dev:arm64` in the arm64 cross build.
  libserialport configures through udev; without it the build fails with a CMake error in a
  transitive dependency that never mentions serial.

### The IC-705's held session, and why a retry cannot break it

Observed on hardware, not inferred. With the radio holding a session, a
connect attempt still completes the whole UDP handshake — pkt3 -> pkt4 ->
pkt6 all succeed, and the radio then sends its own idle keepalives at us
continuously (2,936 of them across ten attempts). What never arrives is the
`0x60` login answer. So the transport is healthy and the login is simply
ignored: from the app, a busy radio and a refused one are indistinguishable,
which is why `IcomLoginTimeout` says what it says instead of reporting a
bare timeout.

Two things follow, and both matter:

- **A wrong credential is probably NOT this, but that is inherited, not
  observed.** The `0xffff...fe` rejection check exists in both the transport
  and the spike, and neither has ever been run against a radio with a bad
  password — it comes from the wfview/kappanhang lineage. If this radio
  IGNORES a bad login rather than refusing it, a stale credential and a held
  session are indistinguishable from here. So retyping the password is the
  cheapest first test, not the one to rule out. Confirming it needs one
  deliberate wrong-password attempt against a known-good radio, which would
  settle it permanently.
- **A failed attempt cannot release anything.** `logout()` returns early
  when `_authId` is null, and after a login timeout it always is — so the
  only cleanup is the UDP-level disconnect. If the radio counts the login
  ATTEMPT as holding the session, we have no way to say otherwise, which
  would explain why retrying tends to prolong the state rather than clear
  it. Worth testing a logout with a zeroed or echoed auth id, but that needs
  the radio in a known-good state to try, not more retries against a wedged
  one.

Sockets are not the problem: ten failed attempts left three UDP sockets
open, which is one in-flight attempt. Teardown works.

**Retrying makes it worse, and it is worth knowing why that is surprising.**
Riding out a transient state by retrying inside the transport is the obvious
move — the operator can do nothing with "try again shortly" that the app
cannot do for them. Measured on the radio, it is wrong:

| attempts per Connect | pkt4/pkt6 handshake timeouts |
|---|---|
| 1 | **0** across ~10 attempts |
| 3 | **2** |

Each attempt opens a session the radio has to track, so retrying moves it
from "completes the handshake, ignores the login" to "ignores the handshake
too". Fifteen seconds of retries was never going to be the time it needs; it
was only ever enough to add three more sessions. `connect` makes ONE attempt,
and the comment above it carries this table so the idea is not re-derived.

**Two things left to try, both needing the radio in a known-good state**
rather than a wedged one:

1. **Wait for the logout to be acknowledged.** The logout is fire-and-forget
   over UDP; a wfview capture reportedly shows the radio acking it, but the
   capture committed here is from a FAILED run and contains no successful
   logout to derive the packet shape from. Guessing a matcher risks
   rejecting a good ack, which would be worse than not checking.
2. **Keep the session id stable across reconnects.** `localSid` is derived
   from an ephemeral local port, so every reconnect looks to the radio like a
   DIFFERENT client — while it is still holding the previous one. If it keys
   held sessions by SID, binding a stable port would let a reconnect replace
   our own session instead of queueing behind it. That is a plausible root
   cause for the whole limitation, and it is a guess about protocol
   semantics until it is tried.

## Platforms

**Serial works on web**, through the Web Serial API — so a USB-attached rig is controllable from a
browser build, and the settings section is NOT hidden there. Sockets are what web lacks: TCP and the
Icom network transport have no web implementation, so a radio needing either throws on connect.

The transport layer sits behind the codebase's conditional-export barrel
(`export 'x_stub.dart' if (dart.library.io) 'x_io.dart';`) and the socket stubs **throw**, per the
convention `web_download_stub.dart` states: a silent no-op is the failure mode to avoid.

The one deliberate exception is **discovery**, whose stub returns an empty stream instead. The rule
exists because a silent no-op turns "this cannot work here" into "this didn't happen to work" — but
discovery's honest answer genuinely *is* "nothing announced itself", and every caller already has to
handle that. A throw there would be an error the UI has to special-case to say the same thing.

A consequence for development: the usual "here's a web build to check" hand-off DOES work, for a
serial rig. A radio on TCP or the Icom network needs `flutter run -d macos`.

### Entitlements

Discovery binds a UDP port, which is a *listening* socket — that needs
`com.apple.security.network.server`, not just `network.client`. It was in `DebugProfile.entitlements`
and **absent from** `Release.entitlements`, so discovery would have worked in every development build
and failed silently in the shipped, signed app. It is now in both.

Like `network.client` and the Sparkle mach-lookup exceptions, this is a sandbox relaxation, not one
of the AMFI-restricted entitlements that make the app fail to spawn without a provisioning profile.
Even so: **verify discovery on a signed Release build**, because Debug passes regardless. That is
this repo's own hard-won rule.

Still to come as transports grow: serial needs `com.apple.security.device.serial`, and Linux CI
needs `libudev-dev`.

On **iOS**, receiving broadcasts additionally needs `NSLocalNetworkUsageDescription`, and multicast
needs `com.apple.developer.networking.multicast` — a restricted entitlement Apple grants only on
application. Neither is set up, so discovery finds nothing there; manual entry still works.

## Discovery

A FlexRadio announces itself over UDP broadcast on 4992 — the same port number as its TCP API, but a
different protocol and a different socket. The payload is a VITA-49 frame wrapping plain ASCII
`key=value` pairs (`model`, `serial`, `nickname`, `version`, `ip`, `port`).

**Discovery is a capability of an equipment TYPE, not of a transport.** The announcement is protocol
knowledge — a Flex broadcast means nothing to a rigctld bridge reachable over the same transport —
and putting radio identification inside a transport is precisely the inversion polo's own
architecture review called out and undid. So the shared UDP plumbing is transport-level
(`udp_broadcast.dart`, behind the same conditional-export barrel), and the parsing lives next to the
driver that owns that protocol.

Two rules the UI follows:

- **A manual path is always offered.** A radio on another subnet, or behind a router that doesn't
  forward broadcasts, never announces. Neither polo branch had a manual path, and both were unusable
  without one.
- **Already-configured equipment is filtered out of the found list.** A Flex re-announces every few
  seconds; offering to add it again each time is how you end up with six copies of one radio.
  Findings are keyed by serial where the protocol offers one, so a radio that changes address
  updates in place instead of appearing twice.

Discovery holds a bound socket, so it runs only while the Add dialog that shows its results is open.
A bind that fails — the port already held, or a sandbox refusing it — surfaces as a reason in that
dialog rather than an empty list, since "nothing found" and "we never got to look" are otherwise
indistinguishable.

## The VFO, in both directions

The radio designated **`radio1`** — data-model.md's term for the transceiver providing `vfoA` —
drives the logging panel, and the logging panel drives it back. It's auto-assigned to the first
transceiver added, so a one-radio shack never has to think about it.

The two directions have to not chase each other, and three things make that work:

- **An origin tag.** `RadioService.setVfo` takes a `VfoOrigin` (`user` or `radio`) as an extra
  optional parameter beyond `VfoStore`'s signature — which Dart lets an override add, so every
  existing caller keeps meaning `user` and only CAT says otherwise. CAT ignores notifications it
  caused: forwarding one would tell the radio to go where it already is, and the radio's
  confirmation of that would arrive as another notification.
- **A per-node record of what was last exchanged**, compared per field. Without it, a mode-only
  change re-sends the frequency to a radio that hasn't confirmed the previous one.
- **Dropping no-op writes at the store.** `Vfo` gained value equality, so a radio restating what it
  already reported — every status push, every 60 s resync — is not a change and notifies nobody.
  This has to live *at the store*, and only there. `CatService` deduping against its own cache as
  well looks like the same saving and is not: clear `vfoA.freq` (pick a band, empty the frequency
  field) and the radio has not moved, so every later report matches CAT's cache and is swallowed —
  permanently, until the operator turns the knob.

`SSB` is resolved to `USB`/`LSB` at the manager boundary, before any driver sees it. No CAT protocol
has an "SSB" mode. 160/80/40 m are lower sideband; everything else is upper, including 60 m, which
is channelized USB by international agreement despite being below 10 MHz. The band comes from the
frequency when there is one and from `vfoA.band` when there isn't — a manual band pick leaves exactly
that state behind, and resolving it without the fallback answered USB on 40 m.

### The persist was the hot spot

`RadioService.setVfo` used to call `notifyListeners()` **and** an unawaited full SharedPreferences
write on *every* call. Turning a push-model radio's knob reports every step, so that was a
`jsonEncode` plus a platform-channel write per step, with unordered `unawaited` futures able to land
stale. Writes are now debounced (2 s trailing) and chained rather than concurrent, and
`flushPendingWrites()` is there for anything that needs them landed.

### Never over the operator

The panel follows the VFO only when the operator has nothing newer. The guard is a `_freqTouched`
dirty flag, **not** a focus check: expanding the Radio control focuses the frequency field, so
refusing to follow while focused would refuse exactly when the operator is watching the radio.

The dirty flag is set on a real edit only. A `TextEditingController` notifies on *selection* changes
too, and focusing the field moves the cursor — so without a text baseline, merely opening the Radio
control would look like an edit. `_onTimeOrDateFieldChanged` had already hit this exact trap and
solved it the same way; `_lastFreqText` mirrors `_lastTimeDateText`.

Seeding also had a latent bug that live CAT would have made obvious: it set the mode without
re-deriving the default RSTs, so a radio on CW left `59` sitting in the report fields. It now does
what `_setMode` and the setVfo command both do — re-derive them, unless the operator has edited one.

The flag holds off the **frequency**, not the whole update. A mode the rig reports while a frequency
is being typed still lands — otherwise it is dropped, and the pending push then sends the panel's
stale mode back and takes the rig out of CW. And because nothing else ever reset the flag, it is
cleared at each QSO boundary (`_wipe`, an editing session closing): an abandoned partial entry of
three characters or fewer arms no debounce, so live follow used to stay off for the rest of the
session.

An open QSO is never followed. Its recorded freq/band/mode is where the contact actually happened,
and ambient radio state must not rewrite it.

### A suggestion moves the radio

Tapping a spot is the other direction, and the sharpest one: a suggested QSO is specific operator
intent — *work THIS station* — so it sets the VFO immediately, and with a radio connected that
retunes the rig. This is the opposite of the ambient seed it overrides, which only ever reads.

Two limits. It fires only when the suggestion actually carried radio state, so a bare callsign (a
deeplink, say) never retunes anything; and never while an existing QSO is open for editing, matching
the guard every other write site uses.

## Smart VFO Snap

Off by default, and it is the only thing in the app that moves the operator's radio without being
asked to — so almost all of its design is about when to keep its hands off. The rules are
`app/lib/services/cat/vfo_snap.dart`; when to ask them is `CatService._noteSnapReading`.

The shape: the knob's own moves are watched, and once the VFO has held still for the settle delay
the app decides whether the operator was *arriving somewhere* or *tuning a signal*. Arriving
somewhere gets rounded to a grid; tuning a signal is left exactly where it is.

**Distance decides the grid. Speed only ever disqualifies.** In order, against the four numbers the
operator can set (defaults in brackets):

1. moved ≥ **long move** [2 kHz] → round to a whole kHz, *and stop here* — speed is not consulted;
2. moved < **smallest move** [0.2 kHz] → leave it alone;
3. average speed < **slowest move** [0.5 kHz/s] → leave it alone;
4. otherwise ≥ half a long move → 250 Hz, else → 100 Hz.

Each rule is answering a specific way of being wrong:

- **The long-move rule is checked FIRST, before the speed floor**, because a sweep across the band
  usually *ends* slowly — easing in over the last turn of the knob is how anyone lands on a signal,
  and averaging that over the burst drags the speed under any useful floor. A long haul is a search
  for a clear slot however it finished.
- **The smallest-move rule holds whatever the speed was.** A 120 Hz correction made quickly measures
  at 6 kHz/s, and rounding it moves the rig off the voice the operator was zero-beating — the single
  worst thing this feature can do.
- **The speed floor** is what separates a nudge that *arrives* from a deliberate creep that is
  someone placing the VFO exactly.
- **An unmeasurable speed is not a slow one.** A burst of a single reading — which is every burst on
  a polled radio — yields no speed at all, and the floor is skipped rather than applied against a
  zero. Treating it as slow would turn the feature off on that hardware entirely.
- **The speed is measured strictly between the burst's own readings.** Nothing says *when* the VFO
  left the resting frequency, only that it had by the first reading of the burst — so that first
  step's distance is deliberately not counted. Charging it to an interval that begins after it
  divides a longer journey by a shorter time, and on a polled radio (whose poller sits at 3 s until
  it sees a change, then drops to 200 ms) the overestimate is big enough to carry a deliberate creep
  over the floor.

The **settle delay** [300 ms] is the one that decides whether this feels immediate or laggy, and it
costs something at both ends: too short chops a slow move into pieces that each measure as a fine
adjustment, too long leaves the frequency jumping after the operator has moved on to the callsign
field. It is read per reading, so changing it takes effect on the next turn of the knob rather than
at the next reconnect.

All four are `select` fields over preset values rather than free-entry numbers: trying one is a
single tap, and no half-typed value is ever committed and acted on. They sit in the
`current-radio-extended` bucket, behind the tune dialog's "show more settings", and are **developer
mode only** — they exist to find the defaults, not to be shipped as choices.

They are *emitted* only in developer mode rather than merely flagged `devMode: true`. The flag hides
an element inside `FormRenderer`, but `showSettingsForTarget` decides whether to offer "show more
settings" from whether the bucket is empty — so flagging alone would leave every other operator a
disclosure that expands to nothing. The flag is set as well, for the dev-mode accent colour and for
All Settings.

What it refuses, and why each one is not an edge case:

- **Anything but phone**, checked on *every* reading rather than once when the movement starts. CW
  and data operators tune to exact frequencies; a rig switched to CW mid-sweep must abandon the
  movement, not settle it under the mode it started in.
- **A snap that would reach a band edge.** Rounding to nearest moves the VFO at most half a grid
  step, and half a step is enough: 7299.7 rounds to 7300.0. The check is *strictly* inside the
  band's limits, because `bandForFrequency` answers with the band at either limit, and a carrier on
  the edge puts its sideband outside.
- **Anything the operator stated exactly** — a typed frequency, a band pick, a tapped spot. Those
  arrive as `VfoOrigin.user` and both cancel a pending snap and become the new resting point.
- **A radio that isn't `radio1`.** One snapper, not one per node: the setting is about the VFO the
  app is driving, which is also why it is a plain app setting rather than per-equipment config.

The settled value is written back as `VfoOrigin.user`, deliberately: the snap is a decision about
where the operator meant to be, so it takes the same path a typed frequency does and the existing
`_onVfoChanged` retunes the rig. Tagging it `radio` would leave the app showing a frequency the rig
is not on. `settle()` takes its own answer as the new resting point, so the radio's confirmation of
the snap reads as no movement rather than as the start of another one.

**A polled radio reports a whole knob turn as one jump.** The FT-891 and the CI-V drivers report
every few seconds, so distance decides alone (see the unmeasurable-speed rule above). What they
cannot do is tell a still-turning knob from a settled one, so on those radios a snap can land
mid-turn; the operator's next move overrides it.

**A restated frequency is not movement.** Every polled driver calls `report` on each poll whether or
not the value changed, and `AdaptivePoller`'s fast cadence is 200 ms — shorter than any settle delay
on offer. So `VfoSnapper.report` answers false for a reading that repeats the last one: the burst
survives, but the caller does not re-arm its quiet period. Re-arming there would push the settle out
for as long as the poller stayed fast — seconds, on a 300 ms setting.

The settings live under `target: 'current-radio'` (settings_registry.dart), reached from the tune
icon beside the Station panel's transceiver picker.

## Where this is going

Shipped: the type registry, the TCP transport, the FlexRadio driver, UDP discovery, a Station
Configuration panel that finds a radio and connects to it, and the VFO wired in both directions.

### Reconnecting at launch

The designated radio is reconnected on launch, with a couple of retries — the radio may still be
powering up, or the WiFi still associating. It gives up quietly after those rather than nagging;
Settings is always there.

The retry never fights the operator, and that is the whole design. app-polo's auto-reconnect was the
source of all four of its connection races, because it could not tell "the connect failed" from
"someone else took this over". So `_connect` returns an outcome — connected, failed, or
**superseded** — and the loop stops dead on anything but a failure. It also checks before each
attempt whether the node is already connected *or mid-connect*, so a Connect that lands between
retries ends the loop instead of being stomped on. Both cases have tests.

Not shipped: reconnect after a live connection drops mid-session. That one needs a backoff and a
superseded sentinel of its own, or a retry storm ends up fighting the user.

Next, in order:

1. **Hardening** — a manager-level staleness watchdog (`lastExchangeAt` plus a per-driver expected
   update interval) rather than each driver hand-rolling a resync timer; reconnect with a
   superseded sentinel.
2. **A second driver for breadth** — Hamlib `rigctld` over TCP. Same transport, a completely
   different protocol, so it is what actually validates the driver abstraction, and it buys
   hundreds of radios for one codec.
3. **Desktop serial**, then the rest of the data model — ports, port-to-port connections, and named
   station configurations.

Deliberately *not* on that ladder until something needs them: boot auto-reconnect (the source of
every one of polo's connection races), BLE, Bluetooth Classic, and iOS.

### IC-705 over WiFi: SOLVED, with one robustness gap

Bench session 2026-07-29 with a real IC-705, `app/tool/ic705_spike.dart`. **A complete CI-V exchange
over WiFi now works** — connect, login, auth, stream request, serial open, read frequency, decode —
in **292 ms**, returning the radio's true frequency. app-polo never reached this and deleted its
attempt; the protocol is no longer the unknown.

The breakthrough came from capturing wfview's traffic. To be precise about the boundary: **the wire
protocol is a fact about the radio, not wfview's copyrightable expression**, so observing packets is
clean-room. wfview's *source* was not read, and must not be — it is GPLv3 and this codebase is
MPL-2.0.

**Five bugs, four of which app-polo also had:**

1. **The `0x90` stream request must name OUR OWN local ports**, not 50002/50003. polo sent the
   radio's own port numbers back at it, which told the radio to send CI-V to itself. This is the
   whole of the "serial stream alive, no payload" symptom, in both implementations.
2. **The audio fields cannot be zeroed.** A real bound audio port and a real sample rate (48000) are
   required or the radio rejects the request — it answers `0x50` with `ffff` at offset 56 instead of
   echoing its ports. The socket is bound and never read; nothing says we have to listen.
3. **The answer to our request is an `0x50`, not a `0x90`.** The radio also sends a `0x90`, but
   afterwards and unprompted. Waiting for the `0x90` times out on a request that was already
   accepted.
4. **The CI-V controller address is `0xE1`**, not the `0xE0` a PC conventionally uses on a wire.
   polo's removal commit credits a wrong controller address as a bug it found on hardware and lost.
5. **The serial-open magic byte is `0x04`**, not `0x05` — polo's other lost fix.

Plus two of our own: **the local session ID derives from the local PORT alone**, little-endian in the
top half (control port `0xFCC2` → SID `c2fc0000`), not from the IP; and **idle packets must share the
outer sequence counter** rather than all sending zero.

**Session release — the "inconsistent run to run" mystery, solved.** wfview sends a `0x40` auth
packet with **magic `0x01` — a logout — immediately before the control disconnect**, and the radio
acknowledges it. Without that the radio keeps the login alive and refuses every later login. That is
the entire symptom that killed polo's attempt, and polo never diagnosed it: its transport built a
disconnect packet it never called, and never had a logout at all.

**The remaining gap:** the gate is 10 consecutive cold starts and we reach **1/10**. A single
connection is fast and correct; back-to-back reconnects still fail at login roughly nine times in
ten. The logout is sent and acknowledged, so the radio needs either more settling time than the
spike's one-second gap, or something further in the teardown. This is a robustness problem with a
known mechanism, not an unknown protocol — a very different position from where polo stopped.

**Also established:** the radio IS discoverable. polo's transport says there is no known beacon and
callers should offer manual entry — but a **unicast `pkt3` sweep of the subnet** finds it instantly
and it answers with a valid `pkt4`.

`ic705-spike-capture.log` holds an annotated exchange.

### Known, not fixed here

- **`parseFreq` misreads sub-MHz frequencies.** `fmtFreqInput(475.5)` gives `"475.5"`, which
  `parseFreq` reads back as 475500 kHz, because of its "a decimal point below 1000 means MHz"
  heuristic. That makes 630 m (472–479 kHz) and 2190 m (135.7–137.8 kHz) round-trip wrong. It is
  pre-existing and equally reachable by typing, but a CAT-connected radio on those bands would hit
  it without anyone typing anything.
- **`spots_panel`'s recompute is NOT unconditional** — an earlier draft of this document said it
  was, and that was wrong. It already returns early when band and mode are both unchanged. What is
  true is that the merge pipeline behind it is uncached and roughly quadratic, so it is expensive
  whenever it *does* run. That is independent of CAT.
- **`RadioService` and `CatService` are never disposed** — both are `late final` on `HaLoServices`,
  which has no `dispose()`. Their timers and listeners live for the process. Harmless for
  process-lifetime services, but it means neither can own anything that must be torn down.
