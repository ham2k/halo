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

The sink carries twelve kinds of report, and the differences between them are load-bearing:

| Report | Lands on | Says |
|---|---|---|
| `report` | `EquipmentState.vfo` | where the radio is |
| `reportPower` | `.power` | RF output, watts; never called by a driver that has not asked |
| `reportDiagnostic` | `.diagnostic` | what the driver worked out, developer mode only |
| `reportProblem` | `.problem` | connected, answering, and unable to do what was configured |
| `reportChannels` | `.channels` | every channel the equipment offers, for equipment with several |
| `reportTransmitting` | `.telemetry.transmitting` | keyed or not; gates relays and the snap, so "receiving" and "nobody asked" must differ, and a driver that cannot tell never calls it |
| `reportMeter` | `.telemetry.meters` | one meter's reading, stamped; readings expire rather than clear, so an unkeyed radio keeps its last panel |
| `reportKeyerSpeed` | `.keyerSpeed` | the radio's WPM as it reports it, only from a `CwKeyerSession` |
| `reportCwProgress` | `CatService.cwProgress` | what the keyer is sending on the app's behalf, null when idle |
| `reportVoiceActivity` | `CatService.voiceActivity` | what the voice keyer is playing or recording for the app, null when idle |
| `reportSwitchState` | `.switchAntennas`, `.switchPorts` | what an antenna switch routes where — both lists together, since a port names its antenna by key |
| `reportAlive` | `.stale` (re-armed) | the equipment answered with nothing about its state; only for something the radio sent on the readings' own path |

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
   every edition — its entry says what it is for — a rig to name on the log, controlling nothing. It
   proves nothing about any driver — what it makes reachable is everything *above* one, on a build
   where §Platforms leaves no other radio connectable: the Station panel, Smart VFO Snap, zero
   beat, the radio1/radio2 assignment, power. Its knobs (connect delay, drop-after, refuse to
   connect, reply delay) are there because the states worth checking by hand are the slow and
   failing ones. A protocol emulator — real driver bytes parsed and answered — would live at the
   transport and is a different thing; this is not it.

None of that tests what a radio actually emits. Polo shipped **one** driver proven against real
hardware and deleted the one it could not make reliable. What each driver has and has not met is
recorded in its own header comment and nowhere else. Deliberately not in the UI: a caveat on a
catalogue entry reads as a warning about the RADIO rather than about our definition of it, and an
operator picking the only entry their rig has cannot act on it either way — so it worries everyone
and helps no one. What a driver has been tried against belongs in the source, where the person who
could change it is reading.

## Serial, and what it costs

The FT-891 is the first driver on a second transport, and it is what proves the split: Yaesu CAT is
ASCII terminated by `;` over a serial port, FlexRadio is a different text protocol over a socket, and
neither driver nor transport had to learn anything about the other.

The **older** Yaesu portables — FT-817/818, FT-857, FT-897 — are on a serial port too and share
nothing else with that: five binary bytes per command, four parameters then an opcode
(`yaesu_binary_codec.dart`). One manufacturer, two protocols, one transport, and the split is what
lets the second cost a codec and a driver rather than a rework.

### A protocol with no framing at all

Every other protocol here delimits its messages — `;` for Yaesu ASCII and Kenwood, `FE FE … FD` for
CI-V, a newline for FlexRadio. This one has **nothing**: no preamble, no terminator, no length, and
no echo of the command. A reply is bare bytes, and the only thing that says what they mean is which
question is outstanding.

So `YaesuBinarySession` sends **one command at a time** and reads back exactly that command's reply
length, which the codec carries on the command itself. A whole exchange is ten bytes — 21 ms at 4800
baud — so serialising costs nothing, and it is what keeps a one-byte status answer from being read as
the head of a five-byte frequency.

Three rules hold it together, and each exists for a failure that is otherwise silent:

- **The deadline is between BYTES, not around the answer.** Yaesu's own chart allows 200 ms between
  the bytes of a command, so a five-byte answer may legitimately take 800 ms; a whole-answer deadline
  abandons a radio that is answering perfectly well, every time.
- **Giving up on an answer starts a resync, not the next command.** The abandoned reply's remaining
  bytes are still coming and are indistinguishable from the next one's, so nothing is sent until the
  line has been quiet and everything arriving meanwhile is dropped. Skip this and a stalled `01 42 34`
  hands its late `56` to the following TX-status read, where bit 7 clear reports a *receiving* radio
  as keyed — a reading that gates antenna relays.
- **A byte arriving with nothing outstanding is discarded, never buffered.** Keeping it offsets every
  later reply by one for the life of the connection.

What the chart does not settle is recorded where it is read rather than worked around: whether Set
Frequency acknowledges (tolerated either way, so a guess cannot desynchronise anything), and the
polarity of the PTT bit, which Note 4 labels and never defines — taken as `0 = keyed`, the only
reading under which a receiving radio's idle `0xFF` is not also a high-SWR alarm.

These three radios have no auto-information either, so the poll is not a backstop the way it is on
the ASCII line: it is the only way a dial turn is ever seen, which is why the TX watch's own answers
never defer it.

### The costume and the radio underneath

A Guohetec Q900 answers that same five-byte chart, and its manual tells people to pick an FT-817 in
their logging software. Doing so is why one arrived as a bug report. The compatibility is an
emulation — undocumented, partial, and sharing its port with the radio's *own* protocol, which is
the worst possible neighbour for a stream that carries no framing: one packet the emulation does not
account for and the count is lost for good, leaving a connected radio that never reports a
frequency.

So the Q900 is driven natively instead (`guohetec_codec.dart`, `guohetec_driver.dart`), from the
protocol its manual publishes in full and licenses for free distribution. That one is framed —
`A5 A5 A5 A5`, a length, a command, a CRC-16 — which is what lets its driver skip everything the
section above describes: no one-command-at-a-time pump, no inter-byte deadline, no resync. It also
answers more, and in one exchange: both VFO frequencies, both modes, the transmit state, the supply
voltage and the meters. The FT-817 chart needs three exchanges for less and cannot read the second
VFO at all, so a split operator's transmit frequency is invisible to it.

Its own sharp edge is the reverse of the Yaesu one. Nothing about the wire is ambiguous; what is
missing is a command that sets **one** VFO. Tuning means transmitting a value for the other one too,
so the session tunes only from a picture the radio has given it, and holds a retune that arrives
before the first status sync rather than inventing the half it cannot see.

The PMR-171 speaks the same protocol and gets an entry when someone can test one.

Serial is `flutter_libserialport` (FFI, the same shape as the existing `halo_quickjs` plugin), behind
the same conditional-export barrel as TCP. Android goes through the `usb_serial` plugin instead
(`UsbManager` over a MethodChannel, with a runtime permission flow), and iOS has no USB host API at
all without MFi.

**Baud is the operator's to set.** app-polo hardcoded 4800 with no UI, which its own notes call out
as a silent-failure mode — a radio whose CAT menu says 38400 answers with garbage and no error, and
nothing on screen suggests why.

**Enumeration must not throw.** The port list comes through `dart:ffi`, so it fails outright when the
native library is missing — a Linux box without libudev at runtime, or any test process. It degrades
to an empty list, because the port picker saying "no serial ports found" is far better than the
equipment editor failing to open.

**One picker entry per port, where the platform can tell them apart.** On desktop the OS names each
port and nothing in the app knows two of them are siblings. Android is different: `usb_serial` hands
over one *device*, and the felHR85/UsbSerial library under it opens the first interface unless told
which — so a device carrying several serial ports (the X6100's two CDC ports, with CI-V on the
second; a CP2105's or FT2232's two vendor-class ones) could only ever reach one. There
`serial_transport_io.dart` asks its own `UsbInterfacesChannel` for the interface descriptors and
splits such a device into `<device>#<interface>` entries labelled "port N of M" in descriptor order,
passing the index through to `create()`. A radio that knows which port carries CAT declares it as a
`port` restriction on its variant — `{'index': n}`, plus `'vendorId'` to confine it to one maker's
bridges — and the picker then **points at** that port of a split device: it sorts first, renders bold
and is tagged, with every sibling still listed under it.

**It ranks; it never excludes.** What the catalogue knows is where CAT usually is, not where it must
be. Both of an IC-705's ports leave the factory set to CI-V and either can be switched; the same
radio reached through somebody else's two-port cable has a different answer again; and an operator
who moved CI-V deliberately would face a picker with no way to say so and nothing on screen
explaining what became of the other port. A wrong guess costs a bold row. A wrong exclusion costs the
radio. The ordinal stays in the label for the same reason — with both ports on screen under one
description, "port 2 of 2" is the only thing telling them apart. On desktop, where nothing is split,
the model notes still say which port to pick.

**A picker entry reads as hardware.** The port field is not a `DropdownButtonFormField` but a
`RowSelectField` (halo_widgets), reached by any `select` whose options carry a `trailing` or `tags`:
one string per item cannot give a column of near-identical device nodes anything to be scanned down.
Each row is the hardware's name in bold, then its tags, then the node hard right — `CP2105
Dual USB to UART · [suggested] · usbserial-00F8E1EB0`, with `/dev/` and macOS' `cu.` taken off. A
port whose descriptors are unreadable, or whose description is only its own node again (macOS answers
that for `Bluetooth-Incoming-Port` and `debug-console`), gets a name made from the node — separators
out, words capitalised — and then no node column, because a name derived from the node says nothing
the node did not. The flat one-line form survives as
`SerialPortOption.label` for the equipment report, and inverts on Windows — `COM3 — Silicon Labs
CP2105` — because there the COM number is the identifier the operator sets in every other program.

The control is a `MenuAnchor`, which buys two things a `DropdownButton` cannot: the menu is part of
the field's own tree, so a refresh WHILE IT IS OPEN adds the port that was just plugged in, and a
value that vanishes from the rows renders as an empty field instead of asserting "there should be
exactly one item with [DropdownButton]'s value" — which is what unplugging a cable with the list down
used to do.

**macOS names a bridge's ports after the device, which is enough to pair them.** That platform
appends the port index to the device's serial number — a CP2105 presents `cu.usbserial-00F8E1EB0` and
`…EB1` — so two names differing only in a final digit, under one description, are two ports of one
device (`SerialTransportConfig.withInferredSiblings`). That is the only thing on that platform that
says so: the USB ids do not read, and the OS named the ports separately. The rows then carry the same
"port N of M" Android's split does, and a radio's declared `index` narrows its SUGGESTION to the one
port — the same claim it makes everywhere else. `vendorId` scopes that claim and nothing else: it
cannot be checked on macOS, where no ids read, so gating a `match` pattern on it would switch off the
one clause that works on that platform. Deliberately macOS-only: Linux's `ttyUSB0`/`ttyUSB1` have the
identical shape and are usually two separate adapters, and that platform reads the ids that say what is really one device.

**The picker ranks what it cannot narrow.** Where the ports are siblings only the operator can see —
desktop, where the restriction above has nothing to act on — the same `port` restriction may carry a
`suggest` clause instead: `{'usb': [{'vendorId':…, 'productId':…}], 'match': [<regexp>]}`. Either
clause matching puts that port first, in bold, tagged `[suggested]`. Both describe the same chip on
purpose, because neither works everywhere: on macOS libserialport cannot read `vendorId`/`productId`
at all — they throw per port, per field — while `description` answers in full, so there the pattern
is the clause that bites and the exact ids are the one that bites everywhere else. A malformed clause
suggests nothing rather than throwing — this is catalogue data rendering a picker — and a
registry-wide test pins its shape so a typo is caught in the suite instead of silently switching the
rule off.

**And it says which port just appeared.** No platform exposes a plug-in timestamp, so
`SerialPortSightings` remembers what each enumeration saw: a port absent from the FIRST look and seen
under five minutes ago is marked `✨ … [just now]` and sorts ahead of the rest. The baseline is what
does the suppressing, not the clock — with the window alone the whole thing would stay silent for
five minutes after launch, which is exactly when a cable gets plugged in. A sighting is forgotten
when its port goes, so unplugging and replugging reads as new again. A suggested port outranks a
recent one: what the radio's own definition knows beats what happened to be plugged in last.

The equipment editor re-enumerates every three seconds while it is open (`showFormPane`'s
`refreshElements`) and republishes the form only when the element list actually differs — an
unchanged republish rebuilds every field, which would close an open dropdown under the operator's
cursor. Descriptor reads are cached per port name for the same reason they are not repeated on a
timer: reading them means opening the port, and doing that every three seconds would poke a port a
live CAT session is holding — including the ones that refuse to open, since those ARE the busy ones.
The cache expires after 30 seconds, because a port name does not identify hardware: Windows hands
`COM3` to whatever is plugged in next, and cached for the session an adapter swapped for another
would wear the old one's description and USB ids — which is what a `suggest` pattern matches on and
what an equipment report quotes.

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
convention `web_download_io.dart` states: a silent no-op is the failure mode to avoid.

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
What it found is the dialog's FIRST shelf and the one that opens itself; its spinner is a row of that
shelf, retired after a few seconds, because a UDP listen has no terminal state and a spinner tied to
the activity would turn for the whole visit.

The rest of the dialog is the catalogue, shelved by maker: one shelf per brand in `featuredBrands`
(equipment_brands.dart), then the software intermediaries — flrig and rigctld, which name a program
rather than a maker — then Other Brands, then the equipment added by name rather than picked by
model. One shelf open at a time, headers pinned. A QUERY flattens the lot into one list across every
shelf, since the answer to "which brand?" is the row itself and headings over one-row groups would be
most of what came back.
A bind that fails — the port already held, or a sandbox refusing it — surfaces as a reason in that
dialog rather than an empty list, since "nothing found" and "we never got to look" are otherwise
indistinguishable.

## The VFO, in both directions

The radio designated **`radio1`** — data-model.md's term for the transceiver providing `vfoA` —
drives the logging panel, and the logging panel drives it back. It's auto-assigned to the first
transceiver added, so a one-radio shack never has to think about it.

### The picks belong to the radio

An antenna and a key are attached to a rig, not to a station, so
`CatService.designatedFor`/`setDesignated` answer for whatever is driving
`vfoA` right now: the store is `radio → category → uuid`, keyed by the same
value the main-VFO picker carries (a local node's uuid, `peer:‹device›:‹radio›`
for a peer's radio, `none` for None). A shack whose second rig runs a different
wire and its own paddle states that once; switching `radio1` restores what that
radio was last set to, and switching back restores the first one's.

Three states, not two. An **absent** category is "never decided" and falls to
`_defaultDesignation` — which for a key is the radio itself, when its own CAT
can key, so a keying rig needs no pick at all; nothing about a radio implies an
antenna, so there is no equivalent there. A category stored as **null** is the
operator having answered None, and outranks the default. Anything else is their
pick. Collapsing absent and null would make "None" un-storable on a keying
radio.

Because the effective key changes when `radio1` does, every writer of `_radio1`
owes the outgoing keyer exactly what an explicit pick owes it — stop its
message, clear `cwProgress`, re-read the new one's speed — or a radio the
operator has stepped off goes on keying with nothing showing it and the Stop
control pointing somewhere else. Three paths move it (`setRadio1`, `addNode`
taking the VFO for the newest transceiver, `removeNode` clearing it), and
only one of them is about keys at all, so the
debt is paid by a wrapper — `_withKeyInUseTidied` — rather than by a line each
of them has to remember.

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

**The rule is a split through HF, not a band lookup.** Below 9 MHz voice is lower sideband, at or
above it upper, and the one exception is 5–6 MHz: 60 m is channelized USB by international agreement
despite sitting below the split. Every amateur band lands on the correct side, so nothing has to
agree with a band table for this to be right — and a frequency in a gap between bands, or on an
allocation no table here carries, still gets the answer an operator would give instead of a shrug.
Those shrugs were holes: a frequency nothing allocated had no convention, which let a stored sideband
be silently rewritten and dropped out of an exported file.

With no frequency, the band answers: upper for every band except 160/80/40 m and the LF/MF ones, each
listed under **both** spellings in circulation (`2190m`/`2200m`, `80m`/`75m`) because a contact
carrying the other one arrives from an import or a spot feed. A manual band pick leaves exactly that
state behind.

`expectedSideband` therefore answers **null only when neither a frequency nor a band was stated at
all** — which is the one thing `resolveSideband` cannot say, since a driver has to be told some
sideband and it falls back to upper. Callers that must not guess check `expectedSideband` first:
`RadioService.setVfo`, and the logging panel's `RadioControlModel.resolveMode` for the picks that never
reach the VFO.

#### Showing it back: `SSB` unless it contradicts

Resolving on the way in makes the log correct and the display wrong. Which sideband you run is a
property of where you are, so a panel and a list that spell it out are repeating what the frequency
beside them already says — and worse, they read as **two modes where one was worked**: an operator
who works phone on 20 m and 40 m has `USB` and `LSB` in the log, which grew the QSO list a Mode
column for a single-mode operation.

So the display collapses it. `halo_core`'s **`displayMode`** answers `SSB` for the sideband that
place runs, and spells out the one it doesn't; **`isUnexpectedSideband`** says which case it is, and
the spelled-out sideband is painted in the theme's error color. `SSB` itself never contradicts
anything — it names no sideband.

It applies wherever a mode is *shown*: the Radio chip and its Mode dropdown, QSO rows in the logging
panel and the Logs view, spot rows, the call-info history line and map popups (the last two are plain
text a backend renders, so there the odd sideband is spelled out uncoloured). It does **not** apply
where the point is what the radio is actually doing: the radio front panel shows the driver's own
`USB`/`LSB`, and so does any other view of exact rig state.

What is **stored** is untouched — the sideband, always. The collapse is a rendering rule, and every
scorer, dupe check and exporter still sees what the operator worked.

The QSO list's Mode column earns its place on displayed modes, plus an override: any contact on a
sideband its place does not run forces the column. The count alone cannot reach the case worth
catching — a rig left in `USB` on 40 m for a whole session shows that one mode on every row, so the
column, which is the only thing carrying the warning, would be dropped with it.

The **More pane** is seeded with the displayed mode and resolves whatever comes back, without asking
whether the select moved — the pane can move the frequency, and an untouched `SSB` has to re-derive
against where the contact now is. The round trip loses nothing wherever anything was stated: the
sideband a place runs comes back as `SSB` and resolves to that same sideband, and the one it does not
run is spelled out and passes through untouched.

The exception is the one state with nothing stated at all — neither a frequency nor a band. There the
collapse cannot be undone on the way back in, so the pane is seeded with the **stored** mode instead
(`RadioControlModel.modeForEditing`); otherwise an untouched save would swap a recorded sideband for a generic `SSB`
the select does not even offer back. The Logs view's own editor guards the same state the same way.

Where the display's error color goes, `alert` must not: the chip's alert condition and the coloured
run's are written to match. A frequency in a gap between bands alerts (no band) and still has an
expected sideband, so neither half implies the other, and error text on the chip's own error ground
is faint at best and invisible on a selected one.

The one place the two sides meet is the ADIF export (`extensions/core/adif`). ADIF spells voice SSB
as `MODE=SSB` with `SUBMODE=USB`/`LSB`, and the submode is dropped **only on a positive match** with
the sideband that place runs — never merely because nothing contradicts it, which is equally true of
a contact stating neither a frequency nor a band, and there nothing can re-derive what was dropped.
Submodes that name an emission (`FT4` under `MFSK`) are unconditional: dropping one loses which mode
was worked.

The rule is a TypeScript twin of the Dart pair, in `@ham2k/extension-sdk`'s `modes.ts`. The two must
answer identically — the app decides which sideband to log and the exporter decides whether that is
worth writing down, so where they disagree the file contradicts the panel the operator worked from.
Being arithmetic plus one small set, rather than a band-table lookup, is what keeps them identical by
construction instead of by maintenance: an earlier version delegated to lib-operation-data's
`bandForFrequency`, whose edges are wider, whose 60 m starts at 5300 where ours started at 5250, and
which retries an unmatched argument as MHz — 10300 kHz came back as `3cm`.

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
The accepted cost: a remote radio has no equipment record and no settings of
its own — it is named in the compact dialog's Equipment in Use section, as
the thing driving the VFO, but there is nothing there to connect or edit.

**A remote radio is picked, never inferred.** A device offers every
transceiver it has *connected* as a `catOffer`, and the peers list those
beside their own rigs in the Station panel's one Main VFO dropdown —
`CatService.radio1` is the pick — ONE slot holding a `MainVfo`, a sum of
`LocalRadio` and `PeerRadio`, because `vfoA` is one VFO. Exclusivity is a
property of that type rather than a pair of clears each writer remembers, and
`radio1` means the ROLE throughout the app, filled by a rig here or one on
another device. Code that needs a session, a runtime or an `EquipmentNode`
matches `LocalRadio` and gets a uuid; the peer bridge narrows the same pick
to its own `PeerStationRadios.followedPeerRadio`, which is a device and a
radio to address a message to. It persists like a local pick does: a peer that is away shows as unavailable rather than handing
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

The pick also decides what KEYS — see § Keying a peer's radio, where the same
offer says whether that station will key a message for its controller.

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

The panel follows the VFO only when the operator has nothing newer. The guard is `RadioControlModel`'s
`_freqTouched` dirty flag (`logging_controls_radio.dart`), **not** a focus check: expanding the Radio control focuses the frequency field, so
refusing to follow while focused would refuse exactly when the operator is watching the radio.

The dirty flag is set on a real edit only. A `TextEditingController` notifies on *selection* changes
too, and focusing the field moves the cursor — so without a text baseline, merely opening the Radio
control would look like an edit. The Time control (`TimeControlModel`) had already hit this exact trap and
solved it the same way; the radio model's `_lastFreqText` mirrors the time model's `_lastText`.

Seeding also had a latent bug that live CAT would have made obvious: it set the mode without
re-deriving the default RSTs, so a radio on CW left `59` sitting in the report fields. It now does
what the model's `setMode` and the setVfo command both do — re-derive them, unless the operator has edited one.

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
`PowerCommand`, e.g. "5W" typed into the call field, dispatched through `HaLoServices`'s
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
  the six drivers' power path has met real hardware — each driver's header says what it has been
  tried against, and that is always its frequency/mode path rather than every capability it carries.
- The IC-705's SET level (0x14 0x0A) doesn't drop when it's running off its own battery, even though
  actual output does — confirmed LIVE (5W actual against a 10W SET level on battery). CI-V has no
  command for actual transmitted power outside a live transmission (the RF-power METER, 0x15 0x11,
  reads 0 at rest — Icom's guide says so outright), so `IcomCivSession` infers battery vs. external DC
  from the DC-input meter (0x15 0x15) instead, and clamps the reported watts to `batteryMaxWatts` (5,
  from `ic705Model`'s override) whenever that reading is below `_batteryMeterCeiling`. The threshold
  and both wattage figures come from one bench session each, not a published spec. That comparison is
  against the RAW reading, which is what saved it: the meter was long documented here as tenths of a
  volt, and Icom's own guide gives a two-segment curve instead (`00 13`=10 V, `02 41`=16 V on an
  IC-7300MK2). No voltage is reported from it at all now — that curve is a 13.8 V radio's, and the
  file describes the whole line.

## CW keying

A radio whose CAT protocol can key CW from text keys the app's messages: F1-F8 in the operation
view send the eight templates under Radio settings (`cwMessage1..8`), the Station dialog's keyer row
picks the speed and opens the editor, and `20WPM` typed into the call field sets the speed the way
`5W` sets power. Everything here is behind the `keyer` experiment (`EXP KEYER`, aliases `CW`/`MACROS`)
on top of `gato`, which it needs to reach a radio at all.

It is a **capability, not a transceiver method**: `CwKeyerSession` (driver.dart) sits beside
`AntennaSwitchSession` rather than adding three methods to `TransceiverSession`, because most
protocols in this layer (flrig, rigctld, Kenwood) have no such command, "this radio ignores sendCw"
must never look like "the text was empty" — and a keyer of its own (a K1EL WinKeyer,
`kCategoryKeyer`) has no VFO to be a transceiver with. A transceiver that keys implements both.

**What keys is the key in use** — and it can be on another device, once a peer's radio fills radio1
(§ Keying a peer's radio); everything below is about a key of this station's own. The Station
dialog's "Key in Use" pick offers the plain keys, the
keyers, — as "via ‹radio›" — every radio whose driver says `canKeyCw`, and, while a peer's radio
fills radio1 and its station keys, that peer as "Key on ‹device›"; `CatService.canKeyCw` is
that designated node's session being a `CwKeyerSession`, and connected. A station with a WinKeyer
and a keying radio therefore says which one the messages go through in the place a key is already
chosen, and a radio whose CAT keys is its OWN key until something else is picked (§ The picks belong
to the radio). The function keys and
the WPM command exist only while `canKeyCw` holds; `setKeyerSpeed` returns whether anything could
take the value, so the WPM command fails out loud ("No connected radio can key CW") instead of
confirming a change nothing heard.

The Station dialog's **keyer row is laid out from CAPABILITY, never from the link**: it shows
whenever either side could carry a message (`designatedKeyIsKeyer` for CW, `radio1HasVoiceMemories`
for voice — the session-free counterpart, off `EquipmentDriver.voiceMemoryCountWith`), a peer's
radio answering both of those from its OFFER, since there is no entry here to ask. Both message
buttons are always present, and each is disabled only where its own side cannot send at all. A
control that came and went with the connection would move under the operator every time the radio
blinked, and "this rig has no voice memories" must not look like "the rig is unplugged". A disabled
button says why in `Semantics` or nowhere — the app has no hover tooltips
([user-interface.md](user-interface.md)). Four sessions implement it — the Icom CI-V driver, the Yaesu one,
FlexRadio's and the WinKeyer's — so the IC-7300 and IC-705, the FT-891, FT-710 and FTDX10, the
FLEX-6000 line and a K1EL WinKeyer — plus the placeholder radio, which keys nothing but remembers a
speed, so the surfaces can be driven on a web build with no rig. A fifth, the Kenwood driver, keys
through `KY` on the entries that name a dialect (below).

**Whether a radio keys is a fact about its entry, asked of its node.** `EquipmentDriver.canKeyCw` is
the driver's word, but a driver serves a line — the CI-V driver an IC-706 as much as an IC-7300, the
Kenwood driver a QMX as much as a K4 — so what the service reads is `canKeyCwWith(config)`, the
driver's answer for THAT node's merged config (`CatService._radioKeysCw`): `cwKeyer` on Icom and
Yaesu (absent means yes, the line's documented default), `cwDialect` on Kenwood (absent means no).
The named entries pin these as overrides, the way the IC-705 pins its addresses; the four GENERIC
entries prefill them off and, under developer mode, show them as fields (keyer_config.dart; the
Kenwood driver's own dialect pickers) — the catalogue does not know which rig is behind a generic,
and a rig with no keyer offered as the key in use keys nothing while the strip shows a message going
out. A node stored before the field existed has no key and keys as it always did.

**The speed is the radio's.** `EquipmentState.keyerSpeed` is set only by `EquipmentSink.reportKeyerSpeed`,
sessions read it once at connect and never poll it (neither protocol announces a knob turn, and a
question the radio almost never has a new answer to does not belong in the poll), and every set is
followed by a read-back so what shows is what the radio took — the CI-V level rounds to a WPM and
both radios clamp. The one moment a fresh value matters is the dialog opening, so
`showStationConfigDialog` calls `refreshKeyerSpeed` first. No echo guard, unlike power: a set is
only ever the operator's explicit ask, and neither radio announces a knob turn, so the last value
the app saw is not the value the radio is on.

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

The two dialects differ in a way that shapes what the app can promise. FlexRadio's CWX and the
FTDX10's memory path have keyed on hardware; Icom's `0x17` and the WinKeyer have not.

- **Icom CI-V** has the plain command: `0x17 <text>` keys it, `0x17 0xFF` aborts what is keying,
  `0x14 0x0C` reads and sets the speed (0-255 over 6-48 WPM; the linear conversion is within one
  step of hamlib's table for the same command).
- **FlexRadio SmartSDR** has CWX, a text buffer on the radio: `cwx send "<text>"` (spaces as
  0x7F, the API's rule) queues a whole message, `cwx clear` empties it — a real stop — and `cw wpm`
  sets the speed the `cwx wpm=` status (`sub cwx all`) reports back on its own. The queue still
  paces one message behind another so the indicator tracks what is keying, not what was handed over;
  CWX's own `sent=` progress is not read yet.
- **K1EL WinKeyer** (WK2/WK3, `winkeyer_driver.dart`) is a keyer, not a radio: its own serial port
  at a fixed 1200 baud with TWO stop bits (the serial transport's `stopBits`, pinned by the model,
  never a field). Host mode is opened with serial echoback on, so the keyer echoes each character as
  it keys it and its status byte says when it is busy and when its buffer is nearly full — the only
  keyer here with real feedback. Progress is therefore what it reports
  (`CwSendProgress.sentCount`, which the keyer area shows in place of the estimate), the send is
  throttled by its XOFF rather than by arithmetic, and `stopCw` clears its buffer. The speed pot
  reports as it moves; a set is reported as taken since the keyer does not echo it. Host mode is
  closed on teardown so the paddle keys standalone again. From the host-interface documents alone.

  **The keyer's own registers are ours to write, every connect.** They persist in the box between
  sessions, so one this driver leaves alone keys with whatever the operator's last program chose.
  PINCFG is the one that bites: it selects which of the two key/PTT jacks is live, and a value
  holding PTT with no key output makes the keyer sit on a dead carrier for exactly the length of
  every message and key nothing (HALO-524 — the giveaway is that it stays down through the WORD
  spaces, which no keying parameter on the chip can do). So `_configure()` writes PINCFG, mode,
  weight, ratio, key compensation, the PTT delays and a speed, and it runs only once the version
  byte has come back: until then the keyer is still closed and takes admin commands only, which is
  why the host open goes out ALONE. The two PINCFG choices nothing can discover — which jack the rig
  is on, and whether to drive its PTT — are config fields, defaulting to port 1 with PTT off.

  **The speed is remembered on the node, because this keyer cannot be asked for it.** Every other
  keyer here is a radio, and the radio owns its speed — `refreshKeyerSpeed` reads its keyer menu, so
  the rig is the record. A WinKeyer with no speed pot has nothing to read back, so an unremembered
  speed resets to the default on every reconnect, which mid-contest is a CQ going out slow with no
  notice. `EquipmentDriver.remembersKeyerSpeed` marks the equipment that needs this; `CatService`
  writes `keyerSpeedConfigKey` into the node's config, and the driver reads it at `createSession`.
  Stored in the config but never a FIELD — remembered state, not a setting to edit, the same way the
  IC-705's controller address is read straight out of the map.

  Written only from the OPERATOR'S set, never from a reported speed. A report is also how a pot
  answers — and on a keyer whose pot is absent, how its floating ADC answers — so remembering
  reports would write that reading to disk and hand it back on every connect afterwards.

  Written as individual commands rather than the `<0F>` Load Defaults block the manual recommends,
  deliberately: that block is not portable across firmware. Slot 9 is 1st Extension on WK2 but X2
  Mode on WK3, and slot 15 is unused on WK2 but X1 Mode on WK3, so one block sent to the wrong
  generation loads a millisecond count into a register whose bits are SO2R mode, paddle mute and
  paddle-status reporting.
- **Kenwood CAT** (`kenwood_driver.dart`, on the entries that name a `cwDialect`) is `KY` in two
  shapes: the Kenwood line proper wants `KY ` and the text padded with spaces to a fixed 28-byte
  command, and `KY0;` empties its buffer — from hamlib's account of the TS-590, no Kenwood document
  of ours; the Elecraft line (K3, KX2, KX3, K4, and reportedly a QMX) takes `KY text;` as is, up to
  24 characters, and `KY @;` terminates a message, the `@` the programmer's reference reserves for
  it. `KS` is the speed on both (4-60 and 8-50). `KY;` only ever says whether the buffer is full,
  never when it empties, so the queue paces chunks by arithmetic like the CI-V session's. The KX2
  and KX3 entries pin the Elecraft dialect; the QMX pins none.
- **Yaesu CAT has no "key this text" command at all.** What it has is five text memories the
  operator can also fill from the front panel: `KM<n><text>;` writes one, `KY6;`-`KYA;` play them
  back. Keying from the app is therefore WRITE-THEN-PLAY through memory 5 (`yaesuAppKeyerMemory` —
  the last, so the four most people fill first survive), and whatever the operator had there is
  gone. There is no stop: `Ft891Session.stopCw` only empties the queue, and the piece already
  playing plays out — reported to its estimated end, so the keyer area does not claim it stopped. `KS;` is the speed, 4-60. The session polls the keyer's status every ten seconds (`0x15`) because a keyer in host mode
  pushes nothing while idle, and the reply restates the speed so the node never reads as stale; a
  port that answers nothing within three seconds of host open is reported as having no keyer on it,
  and a message whose echoes stop arriving is given up on past its own timeline plus a grace, with
  the queue cleared and a problem shown until the keyer speaks again.

**What is going out is shown** in a strip between the logging panel's call-info area and its entry
row — the keyer area (`KeyerArea`, through `LoggingControls.aboveEntryRow`): the message with its sent characters
set apart, a bar pacing through it, and what waits behind it, behind a pill with the keyer speed
that opens a quick speed dialog. The strip slides down with the first message; a message leaves it
the moment it ends (or is stopped), and the strip itself STAYS — it goes away when the operator
sends it away (the X, `KEYER`, the Station dialog's switch), never on a timer, since the buttons on
it are what the next message is sent from and a strip that vanished mid-QSO is one the operator has
to summon back before they can key at all. That switch is a setting (`keyerAreaShown`), so the strip
an operator opened is there at the next launch. The pill's dialog also takes a free-text message.
While nothing is keying the area offers a button per message — the function keys for a mouse — and
`KEYER` (or `MACROS`) in the call field, like the Station dialog's toggle, brings the area up without
sending anything; the Station dialog's keyer row carries a switch bound to the same `keyerAreaShown`
flag. The queue reports each message as it starts (`EquipmentSink.reportCwProgress`,
`CatService.cwProgress`) with a per-character timeline from the same PARIS arithmetic the pacing
uses — the radio reports nothing about its progress, so the indicator is an estimate that is right
to the extent the pacing is, and a paddle-stop at the rig is invisible to it.

**Messages come in SETS.** `CwMessageSet` (settings_service.dart) is a name plus the eight templates
and their labels; `cwMessageSets` holds them all and `cwMessageSet` names the one in use, which is
what `cwMessage(n)` reads and what the function keys send. The keys address a message WITHIN the
active set, so Settings and `SET` follow the operator's pick rather than editing a ninth hidden
copy — `RadioSettingsGroup.commit` routes those keys into the set. An install with nothing stored is
seeded with a Default worth keying and a POTA that differs from it only in the CQ; one whose F1-F8
were written before sets existed keeps them as a set of its own, placed first and therefore active,
so an upgrade never changes what the keys send. The editor is a DRAFT of every set at once: its
header picks one, its rows hand their edits up rather than storing them, and Save writes the sets
and the pick together — so Cancel abandons work in a set the operator has already left, which a
dialog that stored as it went could not do. New Set duplicates what is on screen, edits included.

**Message 1 can repeat**, and only message 1: it is the CQ, and a repeating exchange would key over
the contact it is answering. `cwRepeatDelay` (and `voiceRepeatDelay` for the memories) is the wait
between the message ENDING and it going again — from the end, not from the keypress, or a chain
would key over its own message. One engine serves both keyers (`CatService.armKeyerRepeat`): the
send is supplied by whoever armed it, since rendering a template against the draft is the operation
view's job while a voice memory needs nothing prepared. The keyer area shows the wait as a bar that
EMPTIES, with the buttons down for the whole chain — including the render-long gap between a wait
ending and the next message reaching the radio, which is why `keyerRepeatActive` is a notifier and
not a getter. A chain ends on any keypress (an operator typing a call has come back to the radio),
on Escape or a stop, on a tap of the countdown, on another message, on the setting going to No, and
in any case after five minutes — an unattended CQ that keys forever is a transmitter nobody is
watching. Every send that keys NOTHING cancels too (a failed render, a dead runtime, a message that
sanitizes away, a radio gone between repeats): the wait starts on the message ending, so a chain
armed with nothing running would wait for an end that never comes.

Whether either radio actually TRANSMITS is its own break-in setting; with break-in off both key only
the sidetone. Deliberately not touched from here — an app that flips break-in on so its message goes
out has put RF on the air from a radio the operator set up not to.

The CW path has still not met hardware; both drivers say so in their headers, which is where what a
driver has been tried against is recorded. The VOICE path has — see below.

## Telemetry: what the radio is doing

Where the VFO says where the radio is pointed, telemetry says what it is *doing* — keyed or not,
and what its meters read while it is. `EquipmentState.telemetry` holds it, `EquipmentSink`'s
`reportTransmitting` and `reportMeter` are how a driver contributes, and `EquipmentDriver.telemetryMeters`
declares what a driver can offer before it has offered anything.

**Meters are read only while the radio is transmitting.** SWR and ALC read zero at rest and output
power is not a thing that exists there — CI-V's RF-power meter answers 0 outside a live
transmission, which is not a defect but the point. So the cadence has two gears
(`telemetry_poller.dart`), and they are the opposite of `AdaptivePoller`'s: that one polls hardest
while the dial is *moving* and eases off when it settles; this one spends nothing while the radio is
receiving and everything while it is keyed.

**The watch asks on every cycle, transmitting or not.** It is the only question that can hear the
radio UNKEY — CI-V, Yaesu and Hamlib all announce nothing about the PTT — so a cycle that only read
meters while transmitting would leave the app believing the rig was keyed for the life of the
connection. And what it defers is nothing: the state poll (`AdaptivePoller`) backs off on data the
RADIO volunteers, never on an answer to a question of the app's own. Counted as data, a watch
answering several times a second re-arms that timer before it can ever fire, and the frequency
arrives only on the 9-second staleness ceiling — a dial turn nine seconds late, on exactly the
radios where the poll is the only source there is.

**The TX watch is its own poll, not a field on the state poll**, and that is the piece worth
defending. Folded into the CI-V driver's five seconds or the Kenwood's three, a ten-second over is
noticed halfway through and a short one not at all — and a strip that lights up after the operator
has stopped talking is worse than no strip. The watch is one short exchange (16 bytes on CI-V, 7 on
a Yaesu), which is what makes running it several times a second affordable at all.

**One setting, two floors.** The operator states a single interval per node
(`telemetryInterval`, default 200 ms) and each cadence is that number held against its own budget:
`cycleBytes × 10 ÷ baud ÷ 0.25`, the same 25% duty cycle adaptive_poller.dart reasons in. An FT-891
at 4800 can afford the watch at 200 ms and a four-meter cycle no faster than ~430 ms; the same radio
at 38400 affords both. The clamp is **one-directional**: an operator may ask for slower — a shared
line, a bridge, a rig they do not want chattered at — and only the fast end is a wire fact they
cannot overrule. A link that states no speed (TCP, flrig, rigctld) is *unmeasured*, not infinitely
fast, and gets a flat floor rather than an arithmetic answer computed from a baud rate that does not
exist.

Two consequences that bit during the build, both worth keeping:

- **A fast watch starves a guarded state poll.** flrig serializes one request at a time, and its
  state poll originally waited for an idle socket. With a watch running many times faster there is
  almost always a request in flight, so the frequency stopped updating altogether — visible as a
  driver that had gone quiet, with nothing pointing at the cause. The guard is the QUEUE alone: one
  request in flight and an empty queue is a healthy session, not a backlog.
- **The transition burst fires from inside a response.** The meter read that matters most is the one
  triggered by the PTT answer saying the rig has just been keyed — and at that moment the request
  being answered is still the outstanding one. A driver that guarded the burst on "nothing
  outstanding" would drop it for every transmission, at exactly the moment there was finally
  something to measure.

**Readings expire; they are never cleared.** A driver stops polling the instant the radio unkeys,
which is the normal end of every transmission and not a reason to blank the panel the operator is
looking down at. So each reading is stamped (`nowMillis`, never `DateTime.now()` — time.md) and the
reader drops it after `meterLinger`. A strip that kept the last value would show the SWR of a
transmission from an hour ago, on a different band, as though it were current.

**A meter answering with the number it answered last time is not news.** Three meters on a 200 ms
cycle is fifteen state writes a second into a `ChangeNotifier` the whole station listens to. The
timestamp still moves — that is what keeps a steady reading from expiring mid-over — but the write
does not notify. This is the one place in `CatService` where "the state changed" and "something is
worth repainting" genuinely differ.

**"Receiving" and "nobody knows" are different answers**, which is why `transmitting` is nullable
and why a driver's first answer is reported even when it is "receiving". Most drivers here can say
nothing at all, and a shack full of them has to go on working exactly as it did before any of this
existed.

### What each driver can actually say

Every scale a reading is turned by lives in `drivers/info/`, as JSON, one file per model —
`meter_calibration.dart` reads them and `info/README.md` is the format. Not in the drivers, because
they are data: edited far more often than the code, checked against a manual or a bench sheet, and
contributed by anyone with a radio. A radio with no table reports NOTHING rather than a guess.

The two manufacturers differ in a way the mechanism has to carry. Icom publishes ONE set of
breakpoints for the current CI-V line, so its driver names the file (`defaultMeterInfoKey`) and an
entry overrides it only where a radio is known to differ. Yaesu publishes no scale at all and aligns
each meter per radio, per band, in service mode — so there every entry names its own file, and the
generic Yaesu entry names none.

| driver | TX state | meters |
|---|---|---|
| Icom CI-V | `0x1C 0x00`, polled | power out, SWR, ALC (`0x15`, Icom's own published breakpoints) |
| flrig | `rig.get_ptt` | `get_pwrmeter` (watts outright), `get_swrmeter` (a ratio), `get_alcmeter`, `get_vmeter` |
| rigctld | `+t` | `RFPOWER_METER_WATTS`, `SWR`, `ALC`, `VD_METER` |
| FlexRadio | `interlock state=`, PUSHED — costs nothing | none: SmartSDR's meters ride a VITA-49 stream, a project of its own |
| Yaesu (FT-891) | `TX;`, polled | power out, SWR, ALC, volts — for a radio whose entry names a table |
| Yaesu (FT-817/857/897) | bit 7 of `F7`, polled | none: the PO meter is a 0-15 nibble and HI SWR is one bit, neither with a published scale |
| Kenwood | the flag in `IF`, one place ahead of the mode | none — see below |

Two things are still deliberately missing:

- **Kenwood's meter reads require SELECTING which meter the radio displays**, so reading SWR would
  change what is on the operator's own front panel, and the scale behind the answer is unpublished
  besides. (Yaesu's do not: `MS` is a separate command, so `RM4/5/6/8` leave the panel alone.)
- **An Icom's supply voltage.** Icom's Vd scale is a two-segment curve for a 13.8 V radio, and the
  CI-V file describes the whole line — an IC-705 runs on USB, a battery or external DC and almost
  certainly does not share it. The battery-derating check above is unaffected: it compares the raw
  reading against a raw bench threshold.

The Yaesu driver also keeps a **bench capture** — a developer-mode switch that reads `RM` and reports
the raw 0-255 to the diagnostic line and the console, converting nothing. That is how a table gets
built in the first place, and it stays available on a radio that already has one, because measuring a
radio with a table is how a wrong table is found.

Kenwood's TX state is worth one more line: the line has **no readable transmit-status command** —
its `TX;` is the command that KEYS the radio, which this app must never send — so the flag in `IF`
is the only way to ask. It sits immediately before the mode (P8, then P9) on every documented
generation of the packet, so it is read against the mode offset the driver already learns rather
than against a second guess of its own, and says nothing at all until that offset is settled.

### The alert, and the two things TX state is allowed to stop

`swrAlertThreshold` is **1.8** — not where a rig folds back, but where the ANTENNA is telling you
something: a wet feedline, a wrong band, an ATU that never found a solution. The Radio panel's meter
strip lights it in the error weight, with a glyph and a named semantics label beside it, because
colour alone is not a message an operator who cannot use hue can read.

The strip's slots are reserved from `telemetryMeters` — the DRIVER's claim, not what has arrived —
so the first transmission fills them instead of creating them. A row that appeared mid-over would
shove the frequency up the pane at the moment the operator was watching it.

**A silent radio is not a transmitting one.** Nothing in any of these protocols announces an unkey,
so a rig unplugged or switched off mid-over leaves its last word — "transmitting" — standing for the
rest of the session. `radio1IsTransmitting` therefore reads `EquipmentState.stale` as well: a gate
that fails closed on an answer known to be out of date, with nothing on screen to say why, is worse
than one that reopens.

Knowing the radio is keyed is what lets the app refuse two things:

- **No antenna relay moves under RF.** Switching one is what destroys it, and a switch with no RF
  sensing of its own (the Sierra CX-1 has no PTT input) has only what the radio says. Refused, not
  queued: a selection made a moment ago is not worth honouring after the over ends.
- **Smart VFO Snap keeps its hands off a transmitting rig**, checked both when a burst is fed and
  again when the settle timer fires — the operator can key the radio during the delay, and that
  timer is the line that actually moves it.

Tuning commands are deliberately NOT blocked: rigs disagree about what they do with one mid-over,
and a refused tune is worse than a late one.

## Voice keying

The same eight keys, in a Phone mode: while the DRAFT contact's mode is Phone (`superModeForMode`
— SSB, FM, AM and the digital-voice modes), F1-F8 and the keyer area's buttons play the radio's own
voice memories, Escape stops one, and the Voice Messages dialog names each memory and — on a radio
whose CAT can — records into it. Under the same `keyer` experiment (renamed "Keying"; `VOICE` is an
alias). The draft's mode and not the radio's, the same reasoning as the messages being templates
against the draft: the message is for the contact being logged, and a rig left in USB while the
operator logs CW keys CW.

**The messages are audio in the radio, so the app stores only a label.** `voiceMessageLabel1..8`
(Radio settings, like the CW ones) is the whole of it — nothing to render, nothing to sanitize, and
no `voiceMessage$n` beside it. A memory is keyed by NUMBER, and every surface offers exactly as many
as radio1's session says it has (`voiceMemoryCount`: 8 on an Icom, 5 on a Yaesu, 4 on a TS-590, 8
on a K4, 2 on a KX2/KX3), which is why the labels are eight and a radio with fewer shows fewer.

**Radio1 plays, not the key in use** — a peer's radio1 included, whose memories play over the link
and whose labels and measured lengths come with them (§ Keying a peer's radio). `VoiceKeyerSession` (driver.dart) sits beside `CwKeyerSession`,
a capability for the same reasons — but `CatService.canPlayVoice` is radio1's session being one, and
connected, with no designation in between: the memories are the transceiver's, a WinKeyer has none,
and a second radio's are that radio's. A driver shared across a line (Kenwood CAT) creates sessions
that implement it for rigs that have no voice keyer at all, which is what a `voiceMemoryCount` of
zero is for — a QMX on the Kenwood driver is not a voice keyer, and the catalogue entry, not the
driver, says so (`voiceDialect`/`voiceMemories` overrides, the way `ifModeOffset` is pinned). The
Icom and Yaesu drivers honour `voiceMemories` the same way (the IC-706 and X6100 pin zero), and the
generic entries prefill zero and ask under developer mode — see § CW keying on why a generic asks.

**The radio says when it is done, or the ceiling does.** No protocol here reports a memory's
progress, and only some answer "still playing?", so a session reports `VoiceActivity` (memory,
playing or recording — `EquipmentSink.reportVoiceActivity`, `CatService.voiceActivity`) as it sends
the command and then asks its own question every second (voice_activity_tracker.dart): Yaesu's `PB0;`
answers the channel playing, the K4's `DA;` answers `DA0;` when idle, Icom and the KX line have no
such read so they are asked whether they are transmitting (`0x1C 0x00`, `TQ;`) — a voice memory
transmits. Past the radio's own memory length — `VoiceKeyerSession.voiceMemoryCeiling`, pinned per
named entry from its manual (`voiceCeilingSeconds`: an Icom's 90, the FT-891's 20, the FTDX10's 90,
a KX2/KX3's 15) and `voiceActivityCeiling` (15 s) on a generic entry or a radio whose manual has not
been read for it — the session STOPS it on the radio through its own stop and clears what it showed,
since a recording never ends on its own and an activity the app no longer shows is one the operator
can no longer stop. A poll answering "not going" before any answered
"going" is the one thing the polls can say about a REFUSED play — the memory empty, the radio not in
a voice mode, which no protocol reports outright — so it is shown as doubtful (`VoiceActivity.doubtful`,
"Playing M3?") for a second and then stopped and cleared, rather than as a play that simply ended.
Doubt is not an end: the polls and the ceiling run on through it, a "going" on the next poll takes
the question mark away (a radio can need more than a second to key up), and the doubt's own expiry
sends the stop too — a stop to an idle radio costs nothing, and a memory on the air behind a cleared
strip would be one the operator cannot stop. A ceiling stop leaves a developer diagnostic on the
node, since a memory that keeps ending at fifteen seconds is an entry missing its length.
The keyer area paces a memory with a bar once it knows how long it runs, and an INDETERMINATE bar
until then: a bar pacing a duration the app guessed would be a guess dressed as a measurement.
It learns the duration by timing an ordinary play — the command out, the radio's own end signal in
(`voiceMessageDurationMs1..8`, milliseconds because a length rounded to the second finishes visibly
early or late). Every play measures, so a memory is measured the first time it is used and there is
nothing to press; three plays are not measurements, though — one the radio DOUBTED (a refused
memory, whose "length" would be the doubt linger), one the ceiling stopped (that timed the app's own
limit), and one the operator stopped (it never reached its end). Recording is timed by nobody: that
would measure how long a button was held.

Per dialect. The **Yaesu path has met hardware** (an FT-891 and an FTDX10) and cost this section
most of what it says; every other dialect is still from the manuals and hamlib:

- **Icom CI-V**: `0x28 0x00 nn` (01-08) transmits T1-T8, `0x28 0x00 0x00` stops. Documented on the
  IC-7300MK2 and IC-7610, reported working on the IC-7300 and IC-705 whose guides omit it. A play
  the radio refuses (not in a voice mode, the memory empty) ends at the first transmit-status poll,
  a second later, and NOT on the NAK: CI-V's ACK/NAK names no command and sends are not awaited, so
  a NAK in flight from a meter read would end a memory that is on the air. Nothing in CI-V records
  a memory: `canRecordVoice` is false, and the dialog says to use the front panel. Every named entry
  pins its `voiceMemories` (eight on the modern line, zero on the IC-706 and the X6100); an absent
  key is a generic entry's node and means none.
- **Yaesu** (FT-891, FT-710, FT-991A, FTDX10/101 — hamlib lists both commands valid on all of them):
  `PB0n;` plays, `PB00;` stops — but `PB` only starts the DVS, it does NOT key the transmitter, so
  a play is `TX1;` first (an unkeyed radio plays the memory into the monitor and nothing reaches
  the air). **Nothing is polled.** Both DVS reads lie on this radio: `PB0;` answers `PB00;` while a
  memory plays in transmit, and `LM0;` answers `LM00;` while the panel blinks REC — each read as a
  refused activity, each stopping a real one about two seconds in. All of this is hardware, against
  the manual, which documents a channel answer for both.

  What ends a play is the radio's OWN `TX0;`: it unkeys itself when the memory finishes, and
  Auto-Information pushes that unsolicited (`BY10;` … `TX0;` at the end of a capture). So the app
  keys, sends `PB0n;`, and waits — no reads at all — with the ceiling behind it, and every end
  unkeys whatever the app keyed, since a radio left transmitting with an open microphone is the one
  outcome worse than a message cut short. That `TX0;` is also what TIMES a memory
  (`voiceMessageDuration`, § below). Recording does not key: `LM0n;` records from the microphone off
  the air and `LM00;` stops it; its ceiling and the operator's stop are what end one, which is what
  ends a recording anyway. The frequency/mode/power poll stands down for any voice activity. Five memories, pinned on the named entries; absent means none.
- **Kenwood CAT**, by dialect, which a developer picks on the generic entries: `pb` — `PBn;`/`PB0;`,
  the TS-590 generation (the TS-890/990 speak a different `PB`, a message list to open first, and
  are not a dialect yet); `k4` — `PBn;` (an alias of `DAMPn;`) plays, `DA0;`
  stops anything (its reference's one stop for playback and recording alike), and recording is
  `DARM;` then, on stop, `DA0;` and `DAMSn;` to save it as message n; eight. The KX2
  and KX3 are `kx` — no message command at all, only switch emulation: `SWT11;` (MSG) then `SWT19;`
  or `SWT27;` (the 1 and 2 keys), `RX;` to stop, two memories. A K3 with a KDVR3 plays through
  different switches and is not covered.
- **FlexRadio** has no voice memories in its API; the **placeholder radio** "plays" for four
  seconds and records until stopped, so the surfaces run on a web build.

## Keying a peer's radio

A remote radio picked as Main VFO (§ A paired device's panel, over the peer link) is keyed as well
as tuned (HALO-585): F1-F8, the keyer area, `WPM`, Escape and both message dialogs work against it
exactly as against a rig on this desk, because every one of them reads nothing but `CatService` —
`canKeyCw`, `sendCw`, `cwProgress`, `canPlayVoice`, `playVoiceMemory` — and that is where the one
decision about which side keys is made (`app/lib/services/cat/cat_keying.dart`, with the far side's
state in `peer_keying.dart`).

**The far station keys with its own key in use.** A request names a RADIO; what that station puts
the message through is its business, so a shack whose keying goes through a WinKeyer can be keyed
from the phone at the picnic table. That also means a device offering a radio advertises keying only
when it keys with something of its OWN (`CatKeying.keysCwLocally`): a station whose radio1 is itself
a third device's rig offers its radios as unkeyable, and a request is never relayed onward — two
hops would put a transmitter on the air for an operator who picked neither end of them.

**Voice is the radio's, not the station's.** The memories are audio inside the transceiver, so a
request plays the memory of the radio it names — the per-node path, the voice counterpart of
`tuneNode`. The COUNT, the labels and the measured lengths all come from the owner: a label written
here would name somebody else's recording and a length measured here would pace a bar against audio
this station has never played, so while a peer radio is picked the Voice Messages dialog shows that
device's names and will not edit them (`CatService.voiceMessagesAreLocal`).

**A peer's key is a default, not a designation.** The key in use is stored per radio in use
(§ The picks belong to the radio), and a peer's keying is no node of this station to name — so
`peerKeyIsInUse` answers "nothing was chosen for this radio, and the peer says it keys". An explicit
None still means None, and a local key chosen for that radio still wins; the Key in Use picker
lists the peer as `Key on ‹device›` so the choice can be undone. This is also why an ANSWER is
stored even when it matches the default it replaces (`setDesignated`): "nothing chosen" and "chose
None" resolve alike today and decide differently tomorrow.

**Progress is relayed, never re-estimated.** `keyStatus` carries the owner's own pacing arithmetic,
its `CwSendProgress.id` included, plus a WinKeyer's real `sentCount` — the far queue is what is
actually waiting on those numbers, and a second estimate here would drift against it. A status is
the WHOLE state every time and an empty one is the state that matters: it is how a message ending
crosses, which is also what starts a repeat's wait on the controller. The repeat chain stays with
the operator who armed it (`armKeyerRepeat` supplies the send), and breaks on their own keypress.

**A stop is a stop, whoever asked.** A peer's `stopCw` or `stopVoice` ends the local repeat chain too:
the transmitter is shared, and a stop that left an unattended CQ re-keying it five seconds later is
worse than a message cut short. A peer's PLAY arms nothing and ends nothing — the chain belongs to
the operator who armed it, on their own device.

**Trust is the same trust a tune has** (`catSet`, and the security note at the head of
`peer_protocol.dart`): a trusted, established session, and a radio the addressee is currently
offering. Keying puts RF on the air rather than moving a dial, which is a difference of consequence
and not of permission — the same reason that protocol must never ride a transport admitting anything
but the operator's own paired devices. A peer that walks away withdraws what it could key while the
PICK stands, so the strip goes quiet instead of showing a message over a device that is gone — and
takes with it any repeat chain it was going to end, since the report that would end one can no
longer arrive. A withdrawn radio's status goes with its offer for the same reason: kept, it would be
re-adopted when that rig reconnects, as a phantom message over a quiet transmitter.

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
| FT-817/857/897 | poll only — this protocol has no auto-information at all | `AdaptivePoller.interval` |
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
Settings.

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

FlexRadio has the same shape of silence — a slice status is pushed only when
something changes — and its resync is twice the window, so an idle Flex read
as Not Responding for the second half of every minute. Rather than resync at
twice the rate — four commands answered with a full status burst, against
one line each way — `FlexRadioSession` sends `ping` every 25 s
(`flexRadioPingInterval`) and reports every `R` acknowledgement through
`EquipmentSink.reportAlive` — a word that carries no reading, admitted because
on this radio status and acknowledgements share one socket, so the
acknowledgement vouches for the path the readings take. That is the condition
for calling it at all, and it is a driver's call rather than the manager
counting bytes because a CI-V or RS-485 bus echoes our own polls: a byte
counter would keep a dead serial radio green (the `stale` doc on
`EquipmentState` and the sink method carry the contract). The watchdog's
window is `catStaleAfter`, public so both drivers' tests derive from it.

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
`designatedFor(kCategoryAntenna)` is still the operator's own pick, per radio
(§ The picks belong to the radio). That
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
"someone else took this over". So `_connect` returns an outcome — connected, failed,
**superseded** or **held** — and the loop stops dead on anything but a failure. It also checks before each
attempt whether the node is already connected *or mid-connect*, so a Connect that lands between
retries ends the loop instead of being stomped on. Both cases have tests.

And it never repeats a connect that killed the previous launch. The open is synchronous FFI on the
isolate that pumps the UI, so a wedged serial port does not fail — it stops the launch dead, before
any window appears, which on Windows leaves the single-instance guard handing every later launch to
a corpse (HALO-525). So every automatic connect writes the node down before it makes the call and
erases it when the call returns; a launch that finds a mark still standing leaves that node alone,
reports it as **held**, and says so in a notice naming the rig. Only a Connect the operator pressed
lifts a hold — a launch that cleared its own would merely take turns, hanging and starting, which
nobody could tell from a random fault. See `services/cat/auto_connect_guard.dart`.

The connect itself, and the shutdown at quit, run under a watchdog isolate
(`services/hang_watchdog.dart`). The mark keeps the *next* launch out of a call that does not return; the
watchdog ends the process stuck *in* one, so that there is a next launch rather than a corpse
holding the window. It measures silence from a heartbeat, not elapsed time on the call, so a
connect waiting out a TCP timeout or a keychain prompt is never mistaken for a wedged isolate.

Not shipped: reconnect after a live connection drops mid-session. That one needs a backoff and a
superseded sentinel of its own, or a retry storm ends up fighting the user.

Next, in order:

1. **Hardening** — the manager-level staleness watchdog exists (`catStaleAfter`, `_noteAlive`);
   what each push-only driver still hand-rolls is the probe that feeds it (the Antenna Genius
   10 s resync, the FlexRadio 25 s ping). The remaining step is the manager driving that probe
   for sessions with a null `expectedUpdateInterval`, at which point `reportAlive` and the
   per-driver timers go — not before, or the idle-Flex flicker comes back. Also: reconnect with a
   superseded sentinel.
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
