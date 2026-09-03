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
   ├── EquipmentRegistry              equipment_registry.dart   — models, and the variants derived from them
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

The (model × transport) pair is still what a configured node is bound to — that pair is what decides
the connection settings, and `EquipmentVariant.key` is what a node stores. What changed is who
authors it and what the operator picks.

The authoring and picking unit is an **`EquipmentModel`**: one radio, named once, holding a variant
per transport it can be reached over. The operator picks "Icom IC-705" and then how it is
connected; a model with one variant never asks. The registry **derives** the flat `EquipmentType`
list from the models, so a model and its pairings cannot disagree about which variants exist.

Everything that varies between a radio's transports lives on the variant, and that list is longer
than it looks — for the IC-705 the driver's overrides, the prefilled defaults, the hardware-verified
status and the troubleshooting notes *all* differ between WiFi and USB. Hoisting any of them onto
the model would be wrong for the one radio that has two variants.

The reason this beats a flat list of pairs is not tidiness, it is that the flat list asked the
operator the wrong question first. Finding an IC-705 under "Icom (CI-V) — USB serial" requires
already knowing the radio speaks CI-V. The name on the front of the radio is what they have.

Two consequences worth stating, because both are load-bearing:

- **Variant keys are persisted, and renaming one requires a forwarding entry.** Nothing fails when a
  key changes on its own — the node simply stops resolving, and the panel shows it as a type that no
  longer exists with everything the operator configured still inside it. So a rename goes in two
  places: the variant, and `renamedTypeKeys` in `equipment.dart`, which is applied when a record is
  read so the new key is what gets written back at the next save. Those entries are permanent —
  the record being migrated was written by a build with no upper bound on its age. The shipped key
  set and every forwarding entry are asserted in `cat_equipment_registry_test.dart`, so a rename has
  to be a deliberate edit and cannot point at a pairing that no longer exists.
- **A secret belongs to the catalogue, not to the pairing a node is on.** The editor renders every
  variant's fields at once, so a node bound to a transport with no credentials of its own still
  arrives at storage carrying the password belonging to the transport beside it. `_stashSecrets`,
  `storedSecretFields` and `removeNode` therefore all ask `EquipmentRegistry.allSecretFields`;
  scoping any of them to the node's own pairing writes that password into the plain prefs blob, or
  strands it in the keychain, or hides that it exists. Only `_configWithSecrets` — "what does THIS
  connection need?" — is the pairing's question.
- **Two variants of one model may not disagree about a default.** All of their `defaultConfig`s seed
  the form together (that is what makes switching transport land on sensible values with no
  re-seeding logic), so a key they prefill differently has one box and one of the two answers is
  unreachable. A registry self-check forbids it, because there is no run-time symptom.
- **Re-typing a node drops its connection.** Switching transport replaces both the transport and
  the driver, and a live runtime holds a session the old driver built over a connection the old
  transport opened. `CatService.updateNode` disconnects on a typeKey change *only* — an edited host
  or a corrected name must not drop a working radio.

The editor renders every supported variant's fields at once and narrows them with FormRenderer's
`visibleWhen`, rather than rebuilding per transport. That inherits one contract, stated in
FormRenderer's own `_visibleElements` doc: a hidden field is still registered, still holds its
value, and is **still passed to the validator on submit**. So the editor resolves the pairing from
the form's `transport` value and asks only that one — otherwise the IC-705's serial port, required
and invisible, would refuse to save a perfectly good WiFi radio. The upside of the same contract is
why it is worth it: switching transport and back keeps what was typed, with no state to thread.

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

The sink carries five kinds of report, and the differences between them are load-bearing:

| Report | Lands on | Says |
|---|---|---|
| `report` | `EquipmentState.vfo` | where the radio is |
| `reportPower` | `.power` | RF output, watts; never called by a driver that has not asked |
| `reportDiagnostic` | `.diagnostic` | what the driver worked out, developer mode only |
| `reportProblem` | `.problem` | connected, answering, and unable to do what was configured |
| `reportChannels` | `.channels` | every channel the equipment offers, for equipment with several |

**A problem is not a connection error.** `EquipmentStatus.error` feeds the retry ladder, and the
conditions that belong there are ones a retry can clear — a radio switched off, a port held by
another program. A Flex pointed at a slice the radio is not running is neither: the link is up, the
radio is answering, and only the operator can fix it. Routing it through the failure path would poke
the radio forever over a setting; leaving it unsaid is worse, because a connected row whose
frequency never arrives is indistinguishable from a dead radio. So it is its own field, rendered
with an error's weight and none of its behaviour.

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
- **`SSB` is resolved to `USB`/`LSB` before a driver ever sees it** — at the VFO for anything this
  device tunes, and again at the manager boundary for anything that reaches a driver without passing
  through it. No CAT protocol has an "SSB" mode. The convention: 160/80/40 m are LSB, everything else
  USB (including 60 m, which is channelized USB by international agreement despite being below
  10 MHz).

## Testing a radio with no radio

1. **Codec tests** — sessions are pure given a fake sink. The FlexRadio fixtures are real lines
   captured from a live FLEX-6600 (SmartSDR v4.2.20.41343), carried over from polo's spec.
2. **Session timing** — `fakeAsync` for the resync interval. Keep these out of `testWidgets`.
3. **Loopback** — a real `ServerSocket` on 127.0.0.1 playing a scripted dialogue against
   `CatService`. This is the only tier that catches framing across chunk boundaries, cancellation,
   and the ordering races above.
4. **Placeholder Radio** — a catalogue entry, not a test fixture: a transport with no I/O at all
   and a driver that holds frequency, mode and power and reports every set straight back
   (`placeholder_transport.dart`, `placeholder_radio_driver.dart`). Offered to every operator, in
   every edition — its name, "Generic Placeholder Radio (no control)", is the whole warning. It
   proves nothing about any driver — what it makes reachable is everything *above* one, on a build
   where §Platforms leaves no other radio connectable: the Station panel, Smart VFO Snap, zero
   beat, the radio1/radio2 assignment, power. Its knobs (connect delay, drop-after, refuse to
   connect, reply delay) are there because the states worth checking by hand are the slow and
   failing ones. It claims `hardwareVerified` — the one entry for which that flag's usual meaning
   does not apply, since the caveat below warns about a driver that may not survive contact with a
   radio and this one never meets one. A protocol emulator — real driver bytes parsed and answered
   — would live at the transport and is a different thing; this is not it.

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
application. The usage description is set; the multicast entitlement is not, and iOS ships no
entitlements file at all until Apple approves that request, so multicast discovery finds nothing
there; manual entry still works.

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
- **"Already configured" is per channel, not per radio**, for equipment that offers several
  (`EquipmentDriver.channelKey` — a FlexRadio's slices, and nothing else today). A Flex with slice A
  set up is still something you could add, so it keeps being offered, each offer carrying the lowest
  channel not yet spoken for and named after it from the second on. Filtering per radio instead is
  what left the second slice reachable only by typing the address in from the catalogue.

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
  change re-sends the frequency to a radio that hasn't confirmed the previous one. It is also what
  completes a partial reading: a rig echoing a mode with no frequency in it is answered with the
  frequency it was last TOLD, not the one it last said, so the panel doesn't bounce back to where
  the rig came from between the two halves of a tune. The two agree except while a tune is
  unconfirmed — and a tune the rig REFUSED (out of range, VFO locked) is indistinguishable from one
  it has not answered yet, so for that window the app shows where it asked the rig to be. The rig's
  next frequency report settles it either way.
- **An order for the two commands**, because rigs disagree about what a tune means. Within a band
  the mode leads and the frequency follows: some radios read an incoming frequency against the mode
  in force — a per-mode offset or band edge — so tuning first and switching mode after lands
  off-target. Crossing a band it is **frequency, mode, frequency again**, with the mode sent even
  when it hasn't changed: a rig that recalls a per-band mode would overwrite a mode stated before
  the frequency, and the app would then follow the rig into a mode nobody asked for, so the mode is
  stated once the rig is on the new band and the frequency restated in case setting the mode moved
  it. The band is measured against what was last sent, and with nothing to compare against it counts
  as changed — a freshly connected rig is wherever its operator left it, which is exactly when the
  recall bites, as is a frequency outside every band plan. A **band pick** has no frequency to send
  at all, so only the mode goes out; what protects it is `RadioService.setVfo` re-deriving the
  sideband against the band being picked, so the mode the rig is told is already the right one.
- **Dropping no-op writes at the store.** `Vfo` gained value equality, so a radio restating what it
  already reported — every status push, every 60 s resync — is not a change and notifies nobody.
  This has to live *at the store*, and only there. `CatService` deduping against its own cache as
  well looks like the same saving and is not: clear `vfoA.freq` (pick a band, empty the frequency
  field) and the radio has not moved, so every later report matches CAT's cache and is swallowed —
  permanently, until the operator turns the knob.

`SSB` is resolved to `USB`/`LSB` where a mode is **requested** — `RadioService.setVfo`, which every
writer of the VFO goes through: a tapped spot, the `setVfo` command, the mode picker. A sideband
already stored is still a derived value, so **moving band re-derives it** unless the write states a
mode of its own: a band pick carries no mode at all, and carrying USB from 20 m onto 40 m would log
and transmit the wrong sideband. A mode named in the write is taken as stated — an operator
deliberately on the far sideband keeps it, and a rig reporting its own mode is never second-guessed. `SSB` is what
those say; it is not a mode a radio can be put in, and it is not what an operator on 40 m is running,
so the panel, the logged QSO and the rig all name the same sideband. Resolving it only at the CAT
boundary left a shack with no radio attached resolving nothing at all, and logging "SSB" for a spot
that named a band. `halo_core`'s `resolveSideband` is the one implementation.

`CatService` still calls it on the way to a driver — no CAT protocol has an "SSB" mode, and a mode
can reach one without passing through this device's VFO (a peer driving a rig we offer). It is
idempotent, so the second call is a guard, not a decision.

160/80/40 m are lower sideband; everything else is upper, including 60 m, which is channelized USB by
international agreement despite being below 10 MHz. The band comes from the frequency when there is
one and from the band when there isn't — a manual band pick leaves exactly that state behind, and
resolving it without the fallback answered USB on 40 m. With neither, the generic mode stands: there
is nothing to resolve against, and picking a sideband would be a coin flip.

### A paired device's panel, over the peer link

Peer device sync's ephemeral channel carries the VFO between paired devices
(`PeerChannels`, `app/lib/services/peer/peer_channels.dart`): the phone at the
picnic table sees — and tunes — the radio plugged into the laptop.

It is a bridge through `RadioService`, deliberately NOT a peer-backed
equipment node in the registry. Everything in this document above the
`EquipmentSession` boundary is transport-blind, so feeding `vfoA` directly
inherits the whole two-direction machinery — the origin tag, the per-node
exchange record, the store's no-op dropping, Smart VFO Snap — where a
registry node would need a live session injected into a const-constructed
transport map and the radio1 reconnect loops taught about session lifetimes.
The accepted cost: a remote radio has no Station-panel inventory row and no
settings of its own.

**A remote radio is picked, never inferred.** A device offers every
transceiver it has *connected* as a `catOffer`, and the peers list those
beside their own rigs in the Station panel's one Main VFO dropdown —
`CatService.remoteRadio1` is the pick, plain stored state beside `radio1`
and mutually exclusive with it, because `vfoA` is one VFO. It persists like
`radio1` does: a peer that is away shows as unavailable rather than handing
the panel silently back to a local rig, and re-engages by itself when it
returns. For the same reason, `addNode`'s "newest transceiver wins" rule
stops at a remote pick — configuring a rig is not reaching for it.

Offering and controlling are independent, and a device does both at once
without either being a mode it falls into. As an **offerer** it reports each
offered radio's VFO as `catStatus` and honors a `catSet` naming one of them,
through `PeerStationRadios` — `radio1` via `RadioService.setVfo` (the funnel
a local keystroke takes, so the logging panel follows and the snapper
measures), any other node via `CatService.tuneNode`, which is
`_onVfoChanged`'s echo discipline extracted so a rig that is not `radio1`
can be driven at all. As a **controller** it applies `catStatus` from the
picked device *and* radio, and forwards its operator's own tunes to that
peer alone, addressed rather than broadcast. Everything else on the wire is
dropped: a report nobody picked, a tune for a radio this device does not
offer, and — because only connected radios are offered — a tune to a rig
whose link is down, which would otherwise move app state and reach the
asker looking exactly like the rig confirming.

Only trusted, established sessions carry any of this (`peer_session.dart`'s
gates); the pick is what stands between a paired device and a transmitter
nobody pointed it at. `catStatus`/`catSet` naming a radio is what took
`peerProtocolVersion` to 3: a v2 controller broadcasts `catSet` on every
tune with no pick behind it, so a v3 offerer reading one without a radio id
would hand out a transmitter on an older build's say-so.

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

### Avoiding zero beat

Everyone who taps the same CW spot otherwise transmits on exactly the same frequency, and a pileup
stacked on one note is one the activator cannot pick a callsign out of. **Avoid Zero-Beating on
Spots** (`app/lib/services/cat/zero_beat.dart`) moves a CW suggestion a few Hz off the spotted
frequency. It is **off** by default, for the same reason Smart VFO Snap is: the frequency an operator
transmits on and logs is theirs to choose, so anything that moves it is opted into rather than out
of. That this one only redirects a retune the operator just asked for, rather than moving the radio
uninvited, makes it the milder of the two — not an automatic one. Its range knob is offered
alongside it, without developer mode: whoever switched the feature on is exactly who might want to
tune the spread.

**Only with `radio1` connected.** With no rig under CAT the app changes no frequency at all — the
operator reads the number off the screen and dials it in, so an offset would hand them digits to
hand-tune for no benefit and leave the log claiming a frequency they never transmitted on. A rig
connected in the shack but not driving the logging panel doesn't count either; nothing would retune.

The offset is applied in **`OperationView._suggestQso`** — the one place every suggestion passes
through that can also read the settings, `halo_widgets` being a package below the app. Applying it
there, once, is also what keeps the frequency field, the logged QSO and the VFO on the same number:
everything downstream reads that one value. Two rejected placements say why:

- **In `CatService`, offsetting only what goes to the radio.** The app would then display a
  frequency the rig is not on, and a CAT read-back could pull the field to the offset value anyway.
  Worse, the de-dupe guard there compares against the value actually sent, so a redraw on each push
  would retune the rig on every rebuild.
- **In `suggestedQsoFromSpot`.** It reaches exactly the same taps, so it buys nothing — and it sits
  in `spots_panel.dart`, which would then need the settings and the CAT state threaded into a
  function whose job is mapping a spot's fields.

**The draw excludes a dead zone.** Offsets land between 40% and 100% of the range either side, and
never closer than an absolute 8 Hz whichever is larger — so the 10 Hz setting spans 8–10 Hz, not
4–10 Hz. A uniform draw across ±25 Hz puts some operators within a couple of Hz of the spot, which
is a zero beat, so for them the feature did nothing; and 4 Hz against a ~600 Hz sidetone is no
better. A range narrower than the floor collapses to a fixed offset at its own edge rather than
inverting into an empty span. The side is taken from which half of the draw it fell in, not from its
low bit: the low bit ties side to distance, making every offset above the spot a near one and every
offset below a far one.

**CW only**, via `superModeForMode` — a few Hz is separable by ear on CW, inaudible on phone, and
wrong for a data decoder expecting the tone where the spot said it would be. Note that only literal
`CW` maps to `'CW'` there, so a `CWR` spot is classed Digital and left alone.

**An offset that would leave the band flips to the other side**, and is dropped entirely if that
side fails too — `staysInBand` is shared with Smart VFO Snap, which needs the same answer for its
own reason. Without it a spot near a band edge would retune the rig outside the band, log the
contact there, and clear the VFO's band — which the Spots panel's `auto` filter reads, so the
filter would quietly stop filtering.

**Below 1000 kHz nothing moves**, so 630 m and 2190 m are left exactly on the spot. The cutoff is
re-applied to the MOVED value as well as the spot's, since it is the frequency the field will be
asked to round-trip that matters. The offsetted
value round-trips through the frequency field (`fmtFreqInput` out, `parseFreq` back), and
`parseFreq` reads a sub-1000 value carrying a decimal point as MHz — a 630 m spot at a whole `474`
kHz works today and would come back as `474.021` → `474021` kHz, logged and sent to the rig. The
weakness is `parseFreq`'s, and fixing it there would change how hand-typed input is read; the guard
keeps this feature from turning a working case into a broken one meanwhile.

**The draw is remembered per spot — the draw, and nothing else.** Two requirements pull against each
other here, and `ZeroBeatOffsetter` exists to hold both:

- *The same spot must land on the same frequency.* Each tap builds a fresh suggestion, which
  `LoggingControls` pushes to the VFO, so re-drawing would physically retune the rig tens of Hz — an
  operator tapping a spot again to re-read its reference info would hear the radio move mid-exchange.
- *Every call must return a new map.* `didUpdateWidget` re-applies a suggestion only when the map is
  a different instance. Caching the **result** therefore breaks far more than this feature: the panel
  stops refilling, the callsign stops restoring, the spot sources stop reloading and the VFO push
  stops firing — on every spot, phone included, and with the feature switched off.

So the draw is cached and everything else is re-evaluated per call, which is also why switching the
setting off takes effect on the very next tap of the same spot rather than after tapping some other
one. The cache holds 32 spots, evicting by last use — insertion order would drop the spot being
worked all session in favour of one glanced at once — and a spot that is never offset spends no
slot, so browsing a phone-heavy list cannot evict the CW spot in progress.

`services.cat` is only read once the CAT experiment is on. That getter is a `late final`, so reading
it builds a CatService — registry, stored equipment, a RadioService listener held for the process —
and this runs on every spot tap; without the experiment there is no Station Configuration to connect
a radio from, so the answer would be "not connected" regardless. Checking `avoidZeroBeat` alone
would not do, since it defaults to on.

Smart VFO Snap does not undo it: the snapper only reacts to readings from the radio, app writes
arrive as `VfoOrigin.user` and rebase it, and its smallest-move rule leaves anything under 200 Hz
where it is regardless.

## Power

Power travels with the radio exactly as frequency and mode do, and takes the same route:
`Vfo.power` is the app's one value for it, every surface writes it through
`RadioService.setVfo('vfoA', power:)`, and `CatService._onVfoChanged` forwards an operator's write to
`radio1`'s session. There are four such surfaces — Station Configuration's compact Power field, the
optional Power logging control, the More pane's Power field, and the POWER command (`extensions/core/radio-commands`'s
`PowerCommand`, e.g. "5W" typed into the call field, dispatched through `main.dart`'s
`handleCommandAction` `setPower` case because it has no QSO-scoped widget state to touch, unlike
BAND/MODE/frequency) — and one value is what keeps them agreeing.

Both directions therefore need the same echo discipline the VFO does. `EquipmentState.power` (a
plain `num?` watts, parallel to `vfo`) is set by `EquipmentSink.reportPower`, which also writes the
reading to the VFO as `VfoOrigin.radio` so it doesn't come straight back at the radio;
`_NodeRuntime.lastSentPower` is `lastSent`'s counterpart for the other direction, without which
every VFO notification — a typed frequency, a band pick — would re-send a power command the radio
already obeyed. What is displayed is the live reading when there is one and `Vfo.power` when there
isn't. `SettingsService.currentPower` is the pre-VFO home of the manual value: it is migrated into
the VFO once, at startup (`HaLoServices._buildRadioService`), and never written again — a fallback
read inside `displayedPower` instead would leave the surfaces that read `Vfo.power` directly (the
logging control, the More pane) showing nothing while Station Configuration showed 100.

Only a *change* of `Vfo.power` is a command to the radio (`_lastSeenVfoPower`). Every VFO
notification reaches `_onVfoChanged`, so sending on each one would re-assert a remembered power
nobody stated this session — and since a driver's reading rides into the VFO too, an IC-705's
battery-derated *display* value (`icom_civ_driver`) would come back out as a real RF-power set.

A cleared power (`clearPower: true`) is the operator saying they don't know it, not a command to run
the radio at nothing: nothing is sent to the rig, and a QSO logged with the field empty carries no
`power` at all. Unlike its BAND/MODE/frequency
siblings in the same extension, PowerCommand checks `ctx.enabledExperiments` (docs/extensions/hooks.md)
and stays invisible while `gato` is off — CAT power control has no surface anywhere else without it.

Every driver's protocol represents power differently, and confidence differs between reading and
writing it:

- **flrig** has a genuine absolute-watts concept on both sides (`rig.get_power`/`rig.set_power`), so
  no conversion is guessed either way.
- **rigctld** reads real watts (Hamlib's `RFPOWER_METER_WATTS`), but that level is read-only in
  Hamlib — a `set_level` against it is rejected by every correct backend. Writing goes through
  `RFPOWER` instead, a 0.0-1.0 fraction of the rig's own maximum with no command that states what
  that maximum is, so the write path carries the same assumed-ceiling guess as the four below it.
- **Kenwood, FT-891, Icom CI-V, FlexRadio** represent power as a relative scale (Kenwood/FT-891's
  `PC` 0-100; CI-V's 0-255 level; SmartSDR's `rfpower` 0-100) with no command that states the radio's
  own maximum, on both reads and writes. Each driver documents its own assumption (see
  `icom_civ_driver.dart`'s `_assumedMaxWatts`). The Icom CI-V driver is model-agnostic — the ceiling
  comes from `IcomCivSession.maxWatts`, sourced from the pairing's config rather than hardcoded — so
  `equipment_registry.dart`'s `ic705Model` overrides it to the IC-705's real 10W SSB/CW ceiling
  instead of the assumed 100W; below that ceiling the 0-255 level actually resolves to sub-watt
  steps, so the driver reports one decimal place there instead of rounding to a whole watt. None of
  the six drivers' power path has met real hardware; `hardwareVerified` on each driver still reflects
  only its frequency/mode verification, since that flag is per-driver, not per-capability.
- The IC-705's SET level (0x14 0x0A) doesn't drop when it's running off its own battery, even though
  actual output does — confirmed LIVE (5W actual against a 10W SET level on battery). CI-V has no
  command for actual transmitted power outside a live transmission (the RF-power METER, 0x15 0x11,
  reads 0 at rest), so `IcomCivSession` infers battery vs. external DC from the DC-input-voltage
  meter (0x15 0x15) instead, and clamps the reported watts to `batteryMaxWatts` (5, from
  `ic705Model`'s override) whenever that reading is below `_batteryDeciVoltsCeiling`. The threshold
  and both wattage figures come from one bench session each, not a published spec.

## CW keying

A radio whose CAT protocol can key CW from text keys the app's messages: F1-F8 in the operation
view send the eight templates under Radio settings (`cwMessage1..8`), the Station dialog's keyer row
picks the speed and opens the editor, and `20WPM` typed into the call field sets the speed the way
`5W` sets power. Everything here is behind `gato`, with CAT.

It is a **capability, not a transceiver method**: `CwKeyerSession` (driver.dart) sits beside
`AntennaSwitchSession` rather than adding three methods to `TransceiverSession`, because most
protocols in this layer (FlexRadio, flrig, rigctld, Kenwood) have no such command, and "this radio
ignores sendCw" must never look like "the text was empty". `CatService.canKeyCw` is `radio1`'s
session being one, and connected — the keyer row, the function keys and the WPM command all exist
only while it is true; `setKeyerSpeed` returns whether anything could take the value, so the WPM
command fails out loud ("No connected radio can key CW") instead of confirming a change nothing
heard. Three sessions implement it today — the Icom CI-V driver, the Yaesu one and FlexRadio's — so the
IC-7300 and IC-705, the FT-891, FT-710 and FTDX10, and the FLEX-6000 line — plus the placeholder radio, which
keys nothing but remembers a speed, so the surfaces can be driven on a web build with no rig.

**The speed is the radio's.** `EquipmentState.keyerSpeed` is set only by `EquipmentSink.reportKeyerSpeed`,
sessions read it once at connect and never poll it (neither protocol announces a knob turn, and a
question the radio almost never has a new answer to does not belong in the poll), and every set is
followed by a read-back so what shows is what the radio took — the CI-V level rounds to a WPM and
both radios clamp. The one moment a fresh value matters is the dialog opening, so
`showStationConfigDialog` calls `refreshKeyerSpeed` first. The same echo guard as power
(`_NodeRuntime.lastSentKeyerSpeed`) keeps a reported value from being sent straight back.

**Messages are templates.** Liquid (docs/extensions/templates.md), rendered on each keypress through
the core `templates` extension's `template` hook against the operation and the DRAFT contact — the
same `templateContext` a panel gets, so `{{ qso.call }}` means the same thing in a message as in a
pane. The renderer lives in the extension runtime and nowhere else, which is why a hook exists for
it. A template that does not parse is shown as a notice, not keyed with its braces in Morse. The
handler is a `HardwareKeyboard` handler in `OperationView` (which owns the draft QSO), claimed only
while that route is front-most — a dialog over it, the message editor included, keeps the keyboard —
and only for a bare function key with a message behind it; Escape is claimed only while a message is
still going out, and stops it.

**Neither protocol says when its keyer is free**, and both hold less than a CQ. CI-V's `0x17` takes
30 characters and NAKs a second command while the first is still keying; a Yaesu memory takes 50.
`CwSendQueue` (cw_send_queue.dart) sanitizes to the characters both keyers document, splits on word
boundaries to what fits, and sends the next piece only after the previous one's Morse duration at the
current speed (PARIS timing, the default 20 WPM until the radio has said) — a chunk boundary falling
on a word gap is what makes the wait invisible on the air.

The two dialects differ in a way that shapes what the app can promise:

- **Icom CI-V** has the plain command: `0x17 <text>` keys it, `0x17 0xFF` aborts what is keying,
  `0x14 0x0C` reads and sets the speed (0-255 over 6-48 WPM; the linear conversion is within one
  step of hamlib's table for the same command).
- **FlexRadio SmartSDR** has CWX, a text buffer on the radio: `cwx send "<text>"` (spaces as
  0x7F, the API's rule) queues a whole message, `cwx clear` empties it — a real stop — and `cw wpm`
  sets the speed the `cwx wpm=` status (`sub cwx all`) reports back on its own. The queue still
  paces one message behind another so the indicator tracks what is keying, not what was handed over;
  CWX's own `sent=` progress is not read yet.
- **Yaesu CAT has no "key this text" command at all.** What it has is five text memories the
  operator can also fill from the front panel: `KM<n><text>;` writes one, `KY6;`-`KYA;` play them
  back. Keying from the app is therefore WRITE-THEN-PLAY through memory 5 (`yaesuAppKeyerMemory` —
  the last, so the four most people fill first survive), and whatever the operator had there is
  gone. There is no stop: `Ft891Session.stopCw` only empties the queue, and the piece already
  playing plays out — reported to its estimated end, so the keyer area does not claim it stopped. `KS;` is the speed, 4-60.

**What is going out is shown** in a strip between the logging panel's call-info area and its entry
row — the keyer area (`KeyerArea`, through `LoggingControls.aboveEntryRow`): the message with its sent characters
set apart, a bar pacing through it, and what waits behind it, behind a pill with the keyer speed
that opens a quick speed dialog. The strip slides down with the first message; a message leaves it
the moment it ends (or is stopped), the pill lingers a minute after the last one, then the strip
slides back up (or sooner, from the X at its end). The pill's dialog also takes a free-text message.
While nothing is keying the area offers a button per message — the function keys for a mouse — and
`KEYER` (or `MACROS`) in the call field, like the Station dialog's Show, brings the area up without
sending anything. The queue reports each message as it starts (`EquipmentSink.reportCwProgress`,
`CatService.cwProgress`) with a per-character timeline from the same PARIS arithmetic the pacing
uses — the radio reports nothing about its progress, so the indicator is an estimate that is right
to the extent the pacing is, and a paddle-stop at the rig is invisible to it.

Whether either radio actually TRANSMITS is its own break-in setting; with break-in off both key only
the sidetone. Deliberately not touched from here — an app that flips break-in on so its message goes
out has put RF on the air from a radio the operator set up not to.

None of this has met hardware yet; both drivers say so in their headers, and `hardwareVerified`
still reflects only the frequency/mode path.

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

**On a polling session the driver's own cadence is added to it.** The setting means "how long a
settled VFO should sit before the app acts", and on a radio that has to be asked, that is not how
long the app must wait: between polls no readings arrive whether the dial is still or spinning, so
the first poll period is silence carrying no information. `EquipmentSession.expectedUpdateInterval`
is what each driver contributes. Null — FlexRadio, and CI-V once transceive proves itself — is a
different claim from a short interval: it says every quiet millisecond is evidence, so nothing is
added.

**A backstop is not a cadence, and telling them apart is the whole difficulty.** Three of these
drivers poll *and* expect to be pushed to, precisely because the radio-side setting that does the
pushing (Yaesu `AI1;`, Icom transceive) cannot be read back:

| driver | reports | contributes |
|---|---|---|
| flrig, rigctld | poll only — these servers push nothing at all | `AdaptivePoller.interval` |
| FT-891 | `AI1;` pushes, poll is the backstop | `AdaptivePoller.interval` |
| Icom CI-V | transceive pushes, the 5 s poll is the backstop | 5 s **until an unsolicited frame arrives**, null after |
| FlexRadio | streams; the 60 s resync is the backstop | null |

Measured on a bench IC-705 over both WiFi and serial, updates arrive far faster than the 5 s poll —
transceive is on, and reading `_pollInterval` as the cadence would charge the snap five seconds on
the hardware it works best on. So CI-V decides from what it sees: command `0x00` is the radio
announcing on its own, `0x03` is an answer to our read, and only the former proves anything. The
claim is one-way — transceive is a menu setting, not something that lapses between frames.

Two details worth not rediscovering:

- **The interval is read when the timer is ARMED, from the cadence in force during the movement.**
  `AdaptivePoller` is at its fast interval then, having just seen a change (both poll drivers call
  `noteChange()` *before* handing the reading up), and eases off the moment the dial stops — so
  re-reading it when the timer fires would chase the back-off and settle later and later. The 3 s
  slow interval can therefore never be added: a radio quiet enough to reach it has no burst open.
- **FlexRadio's 60 s resync is not a cadence either.** Keying anything to it would treat a live
  stream as a once-a-minute poll and add a minute to every snap.

What this actually buys, in practice, is **200 ms** — `kPollFast` — on the drivers that are really
polling while the dial moves. Small against a 300 ms delay, and worth having only because the
alternative is settling inside a silence that proves nothing.

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
every few seconds, so distance decides alone (see the unmeasurable-speed rule above). Telling a
still-turning knob from a settled one is what the added poll period above buys.

**A restated frequency is not movement.** Every polled driver calls `report` on each poll whether or
not the value changed, and `AdaptivePoller`'s fast cadence is 200 ms — shorter than any settle delay
on offer. So `VfoSnapper.report` answers false for a reading that repeats the last one: the burst
survives, but the caller does not re-arm its quiet period. Re-arming there would push the settle out
for as long as the poller stayed fast — seconds, on a 300 ms setting.

The settings live under `target: 'current-radio'` (settings_registry.dart), reached from the tune
icon beside the Station panel's transceiver picker.

## Antenna switches

The first equipment in this layer that is not a radio, and what it cost is
one interface split.

`EquipmentSession` used to require `setFrequency`/`setMode`/`setPower`. The
type-only categories (antenna, CW key) dodged that by throwing out of
`createSession`, which works only for equipment that never connects. A switch
connects, so it would have had to no-op three tuning methods — leaving "this
radio ignores setFrequency" and "this is not a radio" the same shape. The
base now carries only what is about a *connection*, `TransceiverSession` adds
the three tuning methods, and `AntennaSwitchSession` adds `selectAntenna`.
`CatService` narrows with `is` at the three sites that tune, all of which
already acted on the designated radio alone.

The same rewrite fixed a guard that had quietly become wrong:
`_EquipmentTile` asked `category != kCategoryTransceiver` to decide whether to
draw a plug. That was the same question as "has nothing to connect to" only
while every other category was inert. It asks the **transport** now
(`NoneTransport`), or the first non-radio driver that connects would have had
no way to connect.

**A switch's state is live, and reported as one picture.** `reportSwitchState`
takes the antenna ports and the device ports **together** rather than as two
calls, because a port names its antenna by key and means nothing without the
list to resolve it against — reported separately, every reconnect would put a
frame on screen where each port pointed at an antenna that had not arrived,
and the panel would draw an empty selection over a switch that was answering
perfectly well. Neither list is ever persisted, for the reason § Persistence
gives: a remembered routing is a claim about relays nobody has asked in a
while.

**Which side the radios are on is the operator's to say.** An Antenna Genius
reports `ports=2 antennas=8` because that is how the box is *built*; the same
hardware run backwards is a 2x8, and nothing on the wire can tell. So the
counts come from the device and the wiring is a config field
(`switchLayout`) — the one thing the switch cannot know about itself.

The two options are named by what is on each side — "8 Antennas, 2 Radios" —
rather than as a default and a deviation from it. The operator is looking at
their own coax, and only one of the two counts matches what they plugged in
where; "as sold" asks them to know how the product is marketed instead. The
counts come from the driver's catalogue defaults, which are the 8x2's, and the
Station panel relabels them from what a connected switch actually reported —
an 8x1 has one device port and would otherwise be offered a count it can see
is wrong, on the one field whose whole job is matching the box in front of
it.

**The silence watchdog was fed by `VfoReading`s alone.** So a switch — which
has no VFO and never reports one — was marked `stale` ("Not Responding") 30
seconds after every connect, over a perfectly healthy socket. That was
invisible while this layer held only radios, and it is the shape of bug the
whole category was always going to find: anything the manager derives from a
*reading* silently excludes equipment that does not make readings. Any report
from the equipment now re-arms it (`_noteAlive`), and `staleAfter` joined
`reconnectDelay`/`idleRetryFirst` as injectable, for the reason those give.

That fixed the false positive but not the real silence: a switch that pushes
only on change says nothing at all while nobody touches it. So
`AntennaGeniusSession` re-issues `sub port all` every 10 s — a backstop, not a
cadence, deliberately under the 30 s window with room for one to go missing.
It is the same command bring-up uses, verified idempotent on hardware
(re-subscribing answers with the full port list and accumulates nothing), so
the exchange that proves the link is alive also repairs a push that was never
delivered. `expectedUpdateInterval` stays null regardless: it describes how a
change reaches us, and a change still arrives the moment it happens — the same
distinction FlexRadio's 60 s resync draws.

**The routing lives in the equipment's editor, not on its row.** The equipment
list is what the station is made OF; a control surface there would make the
switch the one row in it that does something. So the editor grows a **Current
State** section for a connected switch — one picker per device port — and the
row stays the same shape as every other node's. It sits ABOVE the **Wiring**
section that holds the layout and the antenna links: an operator opening this
dialog mid-operation wants to know what the switch is doing, where how it is
wired is answered once and rarely revisited. The layout field is the driver's
own, lifted out of the connection block and re-emitted under Wiring so it sits
with the links it belongs with.

Those pickers are the only fields in that form that act as they are touched
rather than on save: routing a port is a command, and an operator who then
cancels the pane has still moved the relay. Their keys are stripped before the
values are stored (`switchPortRoutingFormKey`), because persisting where a
port is pointing is exactly the stale claim § Persistence forbids. Two known
limits: the pickers do not follow the switch while the pane is open —
FormRenderer reads an initial value once — and a port that is transmitting is
rendered disabled, which required teaching `select` to honour `disabled` at
all. It did not: the renderer's own note said a select carrying the attribute
renders fully editable, "worse than the attribute not existing". Offering the
control, taking the tap and having the driver refuse it would put the form out
of step with the hardware, with the refusal landing on a panel the operator
cannot see behind the pane.

**The switch names the radio on each port, and the app does not act on it.**
A port line carries the driving radio's own nickname, its band and its
frequency (`nickname=RadioRoom band=5 freq=14.074000`), so Current State says
what each port is *doing* rather than only what it is connected to.

That is most of the question a transceiver's own antenna ports exist to
answer, arriving for free — and it is deliberately not joined to an
`EquipmentNode`. The operator's name for a radio and the name the radio gave
itself are different strings, and matching them would silently mis-attribute a
QSO the first time they disagreed. `SwitchPort.radioName` is what the switch
said, nothing more.

Two things the wire does not spell out and the code depends on: a port names
the radio it is CONFIGURED to follow whether or not that radio is on a band
(the bench 8x2 named the same Flex on both ports while reporting `band=0` for
one), so this is "which radio feeds this port", not "which radio is using it";
and `freq=0.000000` is "nothing to say" rather than a frequency, the same
one-field-two-meanings convention as `rxant=0` and `band=0`. The frequency is
MHz on the wire and kHz past the driver's boundary, per § Units — the
conversion app-polo shipped wrong.

The line also carries `source=` naming what drives the port (`AUTO` and `FLEX`
observed). It is not parsed: `auto` already carries the behaviour and
`radioName` the identity, so a third field would be surface with no reader.

**A problem stands until the thing that caused it goes away.** Reporting null
on every successful reply looks equivalent to that and is not, once a resync
exists: the 10 s `sub port all`'s own acknowledgement is a successful reply, so
a "that port is transmitting" warning — or a refusal for a verb the firmware
does not have — was wiped within ten seconds while the condition still held.
The session therefore tracks what its standing problem is ABOUT, and only the
matching event clears it: a command succeeding retires a refusal and says
nothing about a keyed port, which only that port unkeying can clear. No unit
test could see the original bug, because none of them let the resync timer
fire.

**Antenna ports are named by number AND name** — "Antenna on port 1 - Hex".
The number is what is printed beside the socket on the back of the box; the
name is what an operator with three antennas actually knows them by. Neither
alone matches a row to a piece of coax.

**The operator's antennas are linked to the switch's ports, not renamed by
it.** A switch calls its port whatever somebody typed into the switch's own
web page, possibly years ago; the app already has antenna nodes with the
operator's own names and band coverage. The link field is emitted by
`station_panel.dart`, not by the driver, for exactly the reason the antenna
`bands` field beside it is: a driver is pure catalogue data with no access to
the station's inventory. When the switch is disconnected the editor falls back
to `EquipmentDriver.antennaPortCount` — the case that matters, since setting a
switch up is something an operator does before ever connecting it.

### 4O3A Antenna Genius

Verified against an 8x2 on firmware 4.1.16. 4O3A does not publish the
protocol, so `antenna_genius_codec.dart` and its test fixtures ARE the
specification — every constant in either is something the switch actually
said, and the verb set was enumerated by probing.

It is the SmartSDR API's envelope, which is no coincidence: `C<seq>|verb sub`
out, `R<seq>|code|payload` back, `S0|payload` unsolicited, `\n`-terminated.
So the framing is shared — `line_framer.dart`, extracted from the FlexRadio
driver, per this document's own rule that duplicated frame parsing duplicates
parsing bugs.

Three findings that a reading of the wire would not have given, and that the
code depends on:

- **`port set N rxant=X` succeeds while the port is in AUTO, and does not
  clear it.** `auto` is not settable over this API at all (`port set 1 auto=1`
  is refused). So the app cannot take a switch out of band-following, and a
  selection the operator makes stands only until the next band change — which
  is why the port rows say `following band data` rather than hiding it. A port
  that silently reverted would read as the app having failed to send.
- **`txant` follows `rxant` on the switch's own side.** One write moves both,
  except on a port its owner configured receive-only — where moving tx is not
  ours to do anyway.
- **A non-zero response code is not a connection error.** The switch is
  answering, and reconnecting cannot make it accept a verb it does not have,
  so it goes through `reportProblem` — the line § Drivers never touch app
  state draws.

Two traps in the payloads, both of which read as working code:

- **`rxant=0` is "no antenna", not antenna zero**, and `band=0` is the band
  table's own `None` entry. The switch uses one field for both meanings, so a
  literal read routes the panel at a port that does not exist.
- **An all-zero band mask marks an unwired port.** An 8x2 with three antennas
  set up still reports all eight, distinguishable only this way; without the
  check the operator picks their antenna from a list padded with five entries
  called `Antenna_4` upwards.

`selectAntenna` **refuses a port that is transmitting** rather than queueing
it. Switching a relay under RF is what destroys one, the switch does not
refuse it for us — it accepted every `port set` it was given on the bench —
and a selection made during someone else's transmission is stale by the time
the port unkeys.

**Nothing is published until bring-up finishes.** The switch answers `antenna
list` with one line per antenna port and sends each in its own TCP segment, so
publishing per line — or per chunk, which is barely better — rebuilds the
Station panel seven to ten times on every connect, each rebuild showing one
more antenna than the last. That was measured against the hardware, not
inferred; the unit tests fed whole chunks and saw none of it. The `sub port
all` reply is answered last and is an exact boundary, which is why it is used
rather than a settle timer. It releases the picture whether the subscription
was accepted or REFUSED — a switch that will not subscribe still answered the
inventory, and a blank panel on an otherwise fine connection is worse than a
partial one.

**It announces itself**, on UDP broadcast 9007 — the same port number its TCP
API listens on, and the same non-relationship a Flex's 4992 has: a different
protocol on a different socket. Unlike the Flex there is no VITA-49 wrapper,
just a CRLF-terminated ASCII line:

    AG ip=10.0.0.67 port=9007 v=4.1.16 serial=00-00-00 name=Antenna_Genius
       ports=2 antennas=8 mode=master uptime=6143110

Keyed by serial, per § Discovery's rule about a re-announcing device. The
announcement carries `ip=` and the address is taken from it rather than from
the datagram's sender: the switch is stating where to connect, which is
something the packet's envelope does not know. A datagram that does not open
with `AG ` is ignored — 9007 is a port number, not a protocol.

**Not wired to anything yet.** The switch knows which antenna is live and the
app knows which of its antenna nodes that is, but nothing reads it —
`designatedFor(kCategoryAntenna)` is still the operator's own pick. That
join, and a transceiver's own antenna ports (a Flex has two, most rigs one),
are the next step and are what § Where this is going means by "ports,
port-to-port connections".

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

1. **Hardening** — a manager-level staleness watchdog rather than each driver hand-rolling a resync
   timer. Half its input already exists: `EquipmentSession.expectedUpdateInterval` is the per-driver
   cadence Smart VFO Snap added, so the watchdog needs `lastExchangeAt` beside it rather than a
   number of its own. Also: reconnect with a superseded sentinel.
2. **A second driver for breadth** — Hamlib `rigctld` over TCP. Same transport, a completely
   different protocol, so it is what actually validates the driver abstraction, and it buys
   hundreds of radios for one codec.
3. **Desktop serial**, then the rest of the data model — ports, port-to-port connections, and named
   station configurations.

Deliberately *not* on that ladder until something needs them: boot auto-reconnect (the source of
every one of polo's connection races), BLE, Bluetooth Classic, and iOS.

### IC-705 over WiFi: SOLVED, with one robustness gap

Bench session 2026-07-29 with a real IC-705, `app/tool/ic705_spike.dart` (dist-only: the tool and its capture are a photograph of one bench, so the publish filter drops both). **A complete CI-V exchange
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

`docs/design/ic705-spike-capture.log` holds an annotated exchange (dist-only, as above).

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
