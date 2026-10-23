# CAT — station equipment and radio control

Controlling radios — and eventually antenna switches, rotators and relay boards — from the app.
Station Configuration itself is available to everyone; keying, Enter Sends Messages and the CAT
server are still experiments (app/experiments.yaml).

This document records the shape of the layer and, more importantly, *why* it is that shape. The
model it serves is in [data-model.md](data-model.md) § Stations.

## The constraint that decides everything: JS cannot hold a connection

The obvious design is "equipment is another extension type" — extensions already contribute
activities, contests, spots, lookups and exports. That does not work here, and it is worth being
precise about why, because the reason is structural and not going to change on its own.

`packages/halo_quickjs/src/halo_qjs.h` exports exactly ten `halo_qjs_*` functions, and none of
them opens a serial port or a raw TCP socket. What the sandbox does have — timers, and WebSockets
to hosts a manifest names — the host lends it, and neither is a serial port or a raw TCP stream.
JS runs only when Dart calls into it: a hook, a socket frame, a timer's wake.

So a JS hook cannot:

- hold a serial or raw TCP handle to a radio,
- buffer a partial frame from one across time,
- push an unsolicited frequency change up to the app.

All three app-polo drivers do all of those things (`FlexRadioDriver` runs a 60 s resync
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
   ├── EquipmentRegistry              equipment_registry.dart   — the variants derived from the models
   │     └── models                   equipment_models_<family>.dart, equipment_bridges.dart
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
- **Every real transceiver also runs as the placeholder.** The registry derives one more variant
  per model with a maker (key `<model>-placeholder`, `placeholderVariantFor`): the model's name on
  the placeholder radio's driver and transport, offered last in the editor's connection choice. It is
  how an operator puts their own rig on the log before there is a cable or an address for it.
  Bridges and the stand-alone placeholder get none. The keys are derived but still persisted, so
  the shipped-key test lists them one by one.
- **A node with no port or address is *unconfigured*, not invalid.** `EquipmentTransport.isUnconfigured`
  says so (a blank serial port, a blank host); the editor then skips that transport's own checks,
  the row says "Not configured" and its plug is disabled, and `_connect` answers
  `_ConnectOutcome.unconfigured` without trying — which the retry ladders treat as done, not as a
  failure to retry.
- **Bluetooth serial is the serial transport under another name.** A paired radio's SPP profile is
  one more serial port to the OS, so `BluetoothSerialTransport` subclasses `SerialTransport` and
  changes only its key and which ports it ranks first (those with no USB identity). A model offers
  it only where the radio, or the interface made for it, has one — the IC-705, the Q900, and the
  TX-500MP through a LiNK500MP — with the same defaults as its USB variant, which the registry's
  self-checks require. Bluetooth **LE** is a different transport altogether; see § Bluetooth LE
  serial.
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
| `reportAlive` | `.stale` (re-armed) | the equipment answered with nothing about its state; only ever for something the radio sent. The CI-V driver calls it for every frame from its radio, since a TX-status or meter answer carries no reading and a radio answering only those is still there |

A capability few drivers have reports through a **sink of its own** instead,
which `CatService`'s sink implements and a driver reaches with
`if (sink case final TunerSink t)` — so the many fakes and sinks with no use
for it need not grow a method:

| Sink | Lands on | Says |
|---|---|---|
| `SpectrumSink` | `CatService.spectrumFrames`, `.spectrum`, `.spectrumProblem` | the scope's sweeps and settings (§ Spectrum) |
| `TunerSink` | `.tuner` | the radio's antenna tuner: in line, bypassed, tuning, or failed; null for a radio that answered it has none |
| `PassbandSink` | `.passband` | the receive filter's edges in Hz from the tuned frequency; null once it cannot be known (a mode the driver cannot read it in) |
| `RadioAntennaSink` | `.antennas` | the transceiver's own antenna ports and which it uses — not an antenna switch's, which are `reportSwitchState` |

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

**CI-V goes out one command at a time.** The bus has no flow control, and an IC-7300 keeps only the
LAST of several commands that arrive back to back: a DEVLOGCAT recording showed the five-query poll
answered once, and the frequency read — first in the burst — never, while the TX watch sent alone
was answered every time. So `IcomCivSession` queues everything it sends and releases the next
command when the radio answers the last — a data answer repeating its command byte, or an ACK or
NAK, which name none — or after a second, over a cable and the network pairing alike. The wait is
long on purpose: inside the radio CI-V is one half-duplex line, so a command sent while a slow
answer is still going out collides with it, and the radio may read the wreckage as a command of its
own. hamlib waits 700-1000 ms on the same radios. A transceive broadcast is not an answer, and
neither is a data answer for a command that already timed out. The first unanswered command of a
session is reported as a driver diagnostic.
Only polls are merged — a read identical to one already waiting is not queued twice, so a radio that
is switched off builds no backlog of stale questions; sets and read-backs always queue in order,
because a band change restates its frequency after its mode. A stop (CW `0x17 0xFF`, voice
`0x28 0x00 0x00`) or a PTT set goes ahead of everything waiting and drops the queued frames it
stops — but still waits out the one exchange on the wire, so behind a command the radio never
answers it goes out up to a second late. That is deliberate: sent over an answer still coming in,
the stop is the frame the collision garbles, and a lost unkey is worse than a late one. hamlib keeps
the same one-at-a-time discipline.

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
- **A digital mode reaches a driver as `DATA-USB`.** No radio has an FT8 mode. A driver handed
  one sends nothing, and a cross-band tune leaves the rig in whatever its band recall brought back.
  `CatService.tuneNode` translates the mode through `halo_core`'s `radioModeForAppMode`, the same
  translation the CAT server uses to answer "what mode is the radio in?". The reverse direction keeps
  the operator's word: when the Main VFO's radio reports exactly the radio form of VFO A's mode
  (DATA-USB for FT8), VFO A keeps FT8. That holds for a local radio1 and for a peer's radio alike,
  through one rule, `appModeForRadioReport`. Any other report, plain USB included, is the operator
  changing the rig, and the app follows. Each driver puts DATA-USB on its own name for it: `MD0C;` on a Yaesu, `PKTUSB` for
  rigctld, `USB-D` for flrig, `DIGU` on a Flex, DATA A (`MD6;DT0;`) on a K4. Where the protocol has
  only a DATA *submode* beside the base mode (Icom `0x1A 0x06`, the TS-590's `DA`), the driver sets
  the base mode, then switches the submode on. For plain USB/LSB/FM it switches the submode off.
  The Station dialog's **Radio Mode** picker speaks the radio's modes directly. Each driver's
  `settableModes` lists what its own `setMode` table can send, in its own names (the ones its session
  reports), and `CatService.setRadio1Mode` sends one without touching VFO A: the report comes back
  the usual way and `appModeForRadioReport` decides whether the logged mode follows. One driver
  can serve radios with different modes — CI-V covers an IC-705 with DV and WFM and an IC-7300
  with neither — so a named model pins its own list in `overrides` (`civRadioModesConfigKey`);
  the family's generic entry offers everything the driver can send.
  It takes the flag as set at once: the poll's mode answer arrives before the radio confirms the
  flag, and reported against the old one it would put USB in the log. The poll also asks for the
  submode before the mode, and the driver reads it back, so a rig in USB-D reports DATA-USB rather
  than USB. An Icom without the submode on the generic entry, which cannot pin it, stops being
  asked as any read the radio may lack does (§ Tuner, passband and the radio's own antenna ports),
  and a diagnostic says so. An entry whose radio has no submode (`civDataMode: false` on the IC-706MKIIG and G90; any Kenwood
  without `dataMode`) is put in the base mode. It then reports USB, so the log says USB.
- **A Kenwood-protocol radio can have its own `MD` table**, pinned per entry as `modeDialect`. Lab599's
  TX-500 and TX-500MP have no RTTY, and in their LAB599 CAT protocol `MD6` is DIG — so `6` reads and
  sets as DATA-USB there, and RTTY is not offered. The same radios also offer the TS-2000 protocol,
  which has no command for DIG, and the operator picks between them in the radio's own menu. The
  session asks `ID;` once to know which: `500`/`505` is LAB599, `019` is TS-2000, and on TS-2000 a DIG
  request goes out as its USB base, as on any radio without a DATA submode.
- **The TX-500 line's stream drops GPS sentences.** The LiNK500MP can mix its GPS receiver's NMEA-0183
  into the CAT channel, and a sentence holds no `;`: framed as CAT it fuses with the command after it
  and loses that command. So the LAB599 dialect's framer cuts each `$`-led sentence out through its
  line end, before framing (`AsciiCatFramer.dropsNmea`), holding one split across reads until it
  ends — but never longer than NMEA's 82 characters, after which the `$` is noise. Only that dialect:
  the Elecraft line uses `$` inside its own commands (`MD$`, the sub receiver).
- **A CI-V mode set carries no filter byte**, so the operator's filter survives a mode change (polo
  sent `01` and forced FIL1 every time). The exception is an entry pinning `civModeWithFilter` —
  the Xiegu G90, which ignores a set without one: it sends the filter the radio last reported for
  that mode, or the one in use for a mode not yet seen, or FIL1 if the radio's answers carry none.
  A set asked for before the radio's first mode answer waits for it rather than being dropped.

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

For a rig nobody here has, the field has to record what it emits: `DEVLOGCAT` logs every chunk
each way, timestamped in real time, beside what `CatService` decided about the link (connecting,
connected, not responding, answering again, closed) and what the driver reported as a diagnostic,
then sends the file — see [telemetry.md](telemetry.md) § The traffic recording. It is fed in
`CatService` and `_NodeSink.send`, so every transport and driver is covered without either knowing.

## Serial, and what it costs

The FT-891 is the first driver on a second transport, and it is what proves the split: Yaesu CAT is
ASCII terminated by `;` over a serial port, FlexRadio is a different text protocol over a socket, and
neither driver nor transport had to learn anything about the other.

The **older** Yaesu portables — FT-817/818, FT-857, FT-897 — are on a serial port too and share
nothing else with that: five binary bytes per command, four parameters then an opcode
(`yaesu_binary_codec.dart`). One manufacturer, two protocols, one transport, and the split is what
lets the second cost a codec and a driver rather than a rework.

The ASCII line is one protocol, not one radio. Where a model leaves it, its catalogue entry pins
the difference as driver config the operator never sees, rather than a new driver: the FTX-1's
`PC` names the unit it drives (`yaesuHeadPower`, §Power), and the FT-450 carries eight digits of Hz
in `FA` and `IF` instead of nine (`yaesuFrequencyDigits`) and has three CW text memories of forty
characters instead of five of fifty (`yaesuKeyerMemory`, the one the app writes and plays through;
`yaesuKeyerMemoryChars`). The FT-710 plays a text memory with `KY0n;` rather than the line's
`KY6;`–`KYA;` (`yaesuKeyerPlayByChannel`). A width is never guessed from an answer: an eight-digit
read on a nine-digit radio is a frame that lost a byte.

### RTS and DTR

Every serial connection drives both control lines to a stated level, on every platform, and never
leaves them where opening the port put them — macOS, Linux and most Windows drivers raise both on
open, and libserialport's `setFlowControl(none)` does not lower them (a line it is not told about is
left alone). Two node settings say where they go (`rtsHigh`, `dtrHigh` in
`serial_transport_config.dart`), and **both are off unless the operator turns them on**, on every
entry in the catalogue but the few whose radio is known to wait for RTS — the Orions, whose port uses
RTS/CTS as its handshake. Each of those prefills RTS high as a default the operator can turn off,
and `cat_serial_lines_test.dart` names every one, so a new one is a deliberate edit. The Yaesus
reached through their own USB port raise it a different way, because the same entry is just as often
used through a Digirig: their `port` restriction carries `rtsHigh: true`, and picking a port in the
editor ticks **Hold RTS high** when the restriction suggests that port — the radio's CP2105 — and
unticks it for any other, Windows' "Standard COM Port" included. On Linux and the web nothing tells
the bridge's two ports apart, so the second (PTT and keying) ticks it too, and transmits if the
radio's PC KEYING is set to RTS. A port no longer present leaves the box alone, an action that picks
a port (the web's "add a USB device") sets it the same way, and a node keeps what it stored; nothing
changes at connect:

- **RTS** is the PTT line on a Digirig, a SignaLink and most home-made cables, so a high RTS keys the
  transmitter the moment the app connects. The radio that wants it is a Yaesu with CAT RTS on, which
  waits for it before answering, and with RTS low it may answer once as the port opens — the burst
  it was holding — and then nothing. The troubleshooting notes name both fixes: CAT RTS off at the
  radio, or the setting.
- **DTR** keys CW or PTT on many cables, and a radio's own USB port can be set to transmit from it
  (an Icom's USB SEND). What wants it high is an older RS-232 interface that draws its power from the
  line — some FT-817 cables — and the FT-8x7 notes say so.

Absent keys read as low, so a node saved before these settings existed holds both lines low. A
radio's own Bluetooth serial profile has no wire behind either line, so it offers neither and its
target says so (`noControlLines`): the transport leaves the lines alone and reads nothing back, since
a Bluetooth driver that refused a modem-control write would otherwise fail a link that never had
them.

**The desktop connection reads the lines back and refuses the port when they are not where it asked**
(`serialLinesMismatch`). libserialport can report success without having set them: it never clears
hardware flow control another program left on the port — it tests and clears `CRTSCTS` in `c_iflag`,
where the bit is not — and with that flag on, the driver raises RTS by itself; and a setup error that
sets no errno is never thrown. The readback goes through a second wrapper around the same open port
(`SerialPort.fromAddress`), because the port's own `config` answers from what was just written.
A refusal is its own failure class, `serial:lines`, so it reads distinctly on the row, in
`radio_connect_failed` and in a DEVLOGCAT recording — and it stops the idle retry until the operator
presses Connect. Left flow control lasts until the cable is replugged, and every retry would open the
port again, which raises RTS: a key-up per attempt for the rest of the session. libserialport opens
with `HUPCL` cleared, so closing a refused port does not lower the lines either; the message sends the
operator to replug, which does. Every equipment report states the levels the
connection applies (`effectiveSettingLines`), whether or not the node stores them. Android's plugin
cannot report a refused line change, and Web Serial's `setSignals` is best effort; on those two the
lines are set without confirmation. The open itself still raises both lines for the few
milliseconds before the configuration lands; nothing in libserialport can open a port with them held.

The lines and both cadences are fields most operators never touch, so the equipment editor folds
every field a transport or driver marks `advanced` under an **Advanced Settings** disclosure,
closed by default (FormRenderer's `type: 'disclosure'`; an error inside it opens it).

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

### Ten-Tec's Orion command set

The Eagle (599), the Orion (565) and the Orion II (566) speak one plain-text command set
(`tentec_codec.dart`, `tentec_driver.dart`), written from Ten-Tec's programmer's reference guides
for the Orion (Rev 1.2) and the Eagle (Rev 1.001) and the Orion's V3 firmware addendum. A set is
`*AF14074000`, a query `?AF`, an answer `@AF14074000`, each line ending in a carriage return. The
Eagle's set is the Orion's with things taken away, so one codec serves both and the differences are
asked of a `TenTecDialect` the catalogue entry pins.

Answers name what they answer, which would allow several questions on the wire at once, except for
one thing: **the Eagle's refusal is a bare `Z`.** With two questions out, a refusal cannot be pinned
on either, and pinned on the wrong one it is blamed on a read the radio has while the command it
refused goes unreported. So the driver keeps one question in flight (`request_queue.dart`), and
every set — PTT included, sent ahead of the queued polls — is followed by the 200 ms pause the
Eagle's guide asks for "to maintain proper transmit and receive transition timing". The refusal of a
set therefore arrives while nothing is outstanding, and is not mistaken for the answer to the
read-back behind it. An Orion names what it refused (`Z!xx`), so its refusal of a CW character,
written past the queue, is never taken for the question's either. An Eagle older than firmware 1.736
refuses the filter-width set and answers the width query, which is exactly the case this protects.

What the guides leave open, the driver does not guess:

- **`?S` answers `@SRM` while receiving and `@STF` while keyed.** The shape of the answer is the
  transmit state, and the transmit answer carries forward and reflected power. The receive number is
  not reported as a meter: the Eagle's guide calls `16` "dbm" and the Orion's calls `10` an
  S-meter reading, so its unit needs a capture first.
- **The Orion keys CW one character per command** (`/c`) and its guide says nothing of buffering,
  so each character is written at its own PARIS start time rather than all at once.
- **No probe uses `X`.** The Eagle answers it with its name, but on an Orion `XX` restarts the
  radio. The firmware is read with `?V`.
- **An Eagle in split is taken out of split before a retune to another band.** Its front panel
  refuses a cross-band split and its guide warns that the serial port does not.
- **RTS is prefilled high**, an exception to [RTS and DTR](#rts-and-dtr): the Orion wires RTS/CTS
  as its handshake and may not answer with RTS low. A default, not an override, because on an
  interface that keys PTT from RTS it transmits; the notes say so.

Ten-Tec's other CAT radios, the Omni VII, Argonaut VI and Jupiter, speak other protocols and are not
covered.

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

## Bluetooth LE serial

**Behind `EXP 500MP`**, with the Lab599 TX-500 line it was built for: neither has met hardware. The
gate (`isBehindTx500Experiment`, applied by `EquipmentRegistry.offeredVariants`) holds
back only the catalogue's offer — the Lab599 models, and the `-ble` pairing of every radio. A node
already on one keeps it in its editor and keeps connecting with the experiment off.

A BLE serial bridge — a LiNK500MP in its iOS mode, an HM-10 module on a CAT cable — carries a radio's
serial CAT without the OS ever presenting a port. `BleSerialTransport` scans for the bridge,
connects, and moves the bytes through two GATT characteristics itself. That is what reaches iOS,
which has no serial ports at all and no Classic Bluetooth serial without Apple's MFi program.

- **Every serial radio gets it, derived.** `bleSerialVariantFor` gives each real transceiver with a
  serial variant a `<model>-ble` one: the same driver, with the driver's own pins, prefills and
  restrictions, and none of the port's — no port, no baud, no RTS/DTR, because the bridge has the
  wire to the radio and its rate is set there. Every model rather than a chosen few, because which
  bridge is on the operator's radio is not the catalogue's to know. The keys are derived but
  persisted, so the shipped-key test lists them.
- **No published GATT table for the LiNK500MP exists**, so the pipe is found rather than declared
  (`ble_serial_profiles.dart`): Nordic UART, the HM-10/CC254x `FFE0`/`FFE1`, and Microchip's
  Transparent UART are recognized by name; anything else is used by shape only when it is the ONLY
  non-standard service with one writable and one notifying characteristic — counting only the
  services the device advertised, where any candidate is among them. That is Lab599's own guidance
  for the LiNK500MP (its read, write and notify UUIDs come from the advertisement), and the
  advertised list is stored with the device (`bleDeviceServices`) so a connect after a restart has
  it without a scan. Two candidates fail rather than guess, since writing CAT into the wrong vendor characteristic could change the bridge's own
  settings. A failure names the device's services, which is what an operator can send to get a
  bridge added. The HM-10 layout drops writes over 20 bytes without refusing them, so it is held to
  20 whatever the MTU says.
- **Writes are serialized and chunked** to the negotiated MTU, without response wherever the
  characteristic allows: two writes in flight may land in either order, and a command split across
  them would be garbled.
- **The device is stored as the platform's handle** (`bleDevice`) — an address on Android, Windows
  and Linux, a per-host UUID on Apple platforms — with its advertised name beside it
  (`bleDeviceName`) and its advertised services, set through `EquipmentTransport.fieldChanged` as the
  operator picks. A node is
  device-local, so a per-host handle is enough. Connecting needs no scan: Apple's plugin path falls
  back to `retrievePeripherals` for a known UUID.
- **Only the platform's failures are the bridge's.** The gateway wraps what the Bluetooth stack
  reports (`UniversalBleException`, `PlatformException`) as `BleSerialPlatformError`, and only that,
  or a connect timeout, becomes the `CatUnreachable` `BleSerialUnavailable` that stays out of the
  crash reports. Anything else out of the gateway is this app's bug and stays loud. A timeout gets
  the bridge's message, not the shared one that tells the operator to check the radio.
- **Permission is asked only by the editor's Scan.** A background connect prepares without prompting
  and fails with the reason, so no permission dialog appears out of a reconnect ladder at launch.
- **One platform scan, shared.** `universal_ble` runs a single scan per process: a second
  `startScan` replaces the first's filter and any `stopScan` ends it for everybody. Peer discovery
  and the device picker both take a lease from `BleScanCoordinator`, which runs the union — filtered
  while every lease names services, unfiltered while any does not — and gives each lease only the
  results it asked for. Nothing else may call the plugin's scan. A stop that fails still clears the
  record of what is running: Android refuses one while Bluetooth is off, and a kept record would skip
  the start that follows Bluetooth coming back.
- **Every step is a DEVLOGCAT note** (`BleSerialTransport.onNote`, wired by `HaLoServices`): a scan's
  sightings, the GATT table a connect discovered, the pipe and chunk size picked from it, and each
  failure in the platform's own words — a field recording is the only way a bridge nobody here has
  met gets debugged. The handle never appears: on Android it is the bridge's hardware address, so
  it is scrubbed from platform errors and left out of the setup lines (`configLines`), and a scan
  names only devices advertising a serial profile or a vendor UUID, not the phones and earbuds
  around the operator.
- **Not on web.** The plugin is kept off that build, as for peer sync; the transport reports itself
  unsupported there and its variants are not offered.

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
there; manual entry still works. Bonjour browsing through the OS (`NSBonjourServices`) is not
multicast the app sends, and works without it.

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

A **SOTAcat** is found by Multicast DNS rather than broadcast: it publishes a `_sotacat._tcp` service
record (SRV = its rigctld port, TXT `id=` a stable id and `fw=` its firmware), and the app asks for
it with one-shot PTR queries every few seconds (`mdns_io.dart`). A found unit is stored by its SRV
**host name** (`sotacat.local`), not the address it answered from: it goes to the field on whichever
hotspot is at hand, and an address taken at discovery is wrong by the next activation.

### `.local` host names

Any TCP or Icom network host ending in `.local` is resolved by racing the OS resolver against a
one-shot mDNS A query sent from each IPv4 interface (`lookupHost`); the first ADDRESS wins, and a
fast failure from one side does not settle the race. Android, and a Linux without nss-mdns, do not
resolve `.local` at all, and there the mDNS answer is the only one; Windows does, but not reliably.
On macOS and iOS, mDNSResponder IS the OS resolver, so the race is skipped and the OS answers alone.
A TCP connect dials the NAME when the OS resolves it (`connectTarget`), so `Socket.connect` still
tries every address the name has rather than the one the race found.

"One-shot" (RFC 6762 §5.1) is what keeps this small: a query sent from an ephemeral port, with the
QU bit set, is answered by unicast to that port. The app never binds 5353 (the OS responder holds it
on macOS and Windows) and never joins the group (Android delivers multicast only under a Wi-Fi
multicast lock). One socket per interface because a multicast datagram leaves by one interface, and
a laptop on Ethernet and on a SOTAcat's own access point must ask both.

iOS refuses to send multicast without the restricted entitlement (§ Entitlements), so there the OS
resolver answers lookups alone, and the browse goes through `NetServiceBrowser` on the
`ham2k/bonjour` channel — which needs the type listed under `NSBonjourServices` in Info.plist, and
finds nothing, silently, for one that is not.

Discovery holds a bound socket, so it runs only while the Add dialog that shows its results is open.
What it found is the dialog's FIRST shelf and the one that opens itself; its spinner is a row of that
shelf, retired after a few seconds, because a UDP listen has no terminal state and a spinner tied to
the activity would turn for the whole visit.

The rest of the dialog is the catalogue, shelved by maker: one shelf per brand in `featuredBrands`
(equipment_brands.dart), then the software intermediaries — flrig, rigctld, Ham Radio Deluxe, N3FJP
and DXLab Commander, which name a program rather than a maker — then Other Brands, then the equipment added by name rather than picked by
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

- **An origin tag.** `RadioService.setVfo` takes a `VfoOrigin` (`user`, `radio` or `dial`) as an
  extra optional parameter beyond `VfoStore`'s signature — which Dart lets an override add, so every
  existing caller keeps meaning `user` and only CAT says otherwise. CAT ignores notifications it
  caused: forwarding one would tell the radio to go where it already is, and the radio's
  confirmation of that would arrive as another notification. `dial` is the operator turning an
  on-screen dial (an extension's `setRadio` with `dial: true`): forwarded exactly as `user` is, and
  different only to Smart VFO Snap (§ Smart VFO Snap).
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

A spot this app **posts** is a display too — read by other operators on someone else's board, next to
the frequency that already says which sideband that place runs — so it carries the same collapsed
mode. `ExtensionService.sendSpot` is the one seam, and it has to correct **both** spot paths: a
self-spot carries `mode` as an argument, while spotting someone else's QSO carries no mode at all and
each poster reads `qso.mode` JS-side, so the QSO copy sent out is what gets normalized. SOTA narrows
it further on its own (`ham2k-sota`'s `src/spotMode.ts`), because SOTAwatch accepts only
`AM/CW/Data/DV/FM/SSB` — a deliberately odd sideband folds to `SSB` there rather than being rejected.

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
its own — it is named in the Station panel's Current Transceiver band, as
the thing driving the VFO, but there is nothing there to connect or edit.

**A remote radio is picked, never inferred.** A device offers every
transceiver it has *connected* as a `catOffer`, and the peers list those
beside their own rigs in the Station panel's one Main VFO picker —
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

`avoidZeroBeat` is checked before `services.cat` is read. That getter is a `late final`, so reading
it builds a CatService — registry, stored equipment, a RadioService listener held for the process —
and this runs on every spot tap.

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
BAND/MODE/frequency) — and one value is what keeps them agreeing. An extension's `setRadio` with
`powerWatts` takes the same route on radio1, so the power a panel sets is the power the next QSO
logs; on any other radio it goes to that node alone (`CatService.setNodePower`, with the same echo
guard), since there is no app-wide value to keep in step.

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
`power` at all.

Every driver's protocol represents power differently, and confidence differs between reading and
writing it:

- **flrig** has a genuine absolute-watts concept on both sides (`rig.get_power`/`rig.set_power`), so
  no conversion is guessed either way. `get_power` answers a typed `<i4>` where frequency and mode
  answer bare text, so the driver reads XML-RPC values in both forms. flrig answers 0 with no rig
  behind it, and the driver reads that as no reading — passed on, it would reset the operator's
  power on every poll.
- **rigctld** reports no power reading. Hamlib's watts level, `RFPOWER_METER_WATTS`, is a measured
  output meter — 0 W between overs, a speech sample on SSB — so it fills the meter strip while the
  radio is keyed and never the station's power: reported as power, the 0 W between overs would replace
  the operator's on every QSO logged. It is read-only too — a `set_level` against it is rejected by
  every correct backend. Writing goes through `RFPOWER` instead, a 0.0-1.0 fraction of the rig's own
  maximum with no command that states what that maximum is, so the write path carries the same
  assumed-ceiling guess as the four below it.
- **The K4** is the exception on the Kenwood driver: `PCX` reads real watts in explicit L/H/X ranges
  ([k4-cat.md](k4-cat.md)).
- **Kenwood, FT-891, Icom CI-V, FlexRadio** represent power as a relative scale (Kenwood/FT-891's
  `PC` 0-100; CI-V's 0-255 level; SmartSDR's `rfpower` 0-100) with no command that states the radio's
  own maximum, on both reads and writes. Each driver documents its own assumption (see
  `civ_power.dart`'s `civAssumedMaxWatts`). The Icom CI-V driver is model-agnostic — the ceiling
  comes from `IcomCivSession.maxWatts`, sourced from the pairing's config rather than hardcoded — so
  every named radio in `equipment_models_icom.dart` rated anything but 100W overrides it with its
  real SSB/CW ceiling (the IC-705 and X6100 10W, the G90 20W, the IC-7760 200W), and a registry test
  lists every named CI-V entry's rating so a new one cannot fall back to the guess unnoticed. A radio
  whose 100% level is worth different watts on different bands pins `civBandMaxWatts` — the IC-9700's
  75W on 70cm and 10W on 23cm, the IC-905's 2W above 1200MHz — and the session rates reads and sets
  against the band of its last frequency, reported or set — a power set sent right behind a tune is
  rated for the band tuned to. Crossing a ceiling, the level is read again rather than re-rated: a
  radio may hold a different one per band. A lower AM ceiling (the IC-7760's 50W carrier)
  is not modeled. At 20W and below the 0-255 level actually resolves to sub-watt
  steps, so the driver reports one decimal place there instead of rounding to a whole watt. The
  FTX-1 is the exception on the Yaesu side: its `PC` names the unit first (`PC1010;` the field head,
  0.5-10 W; `PC2100;` the SPA-1, 5-100 W), so its entry pins `yaesuHeadPower` and a power change
  waits until the radio's first answer says which unit to address. That form is hamlib's, not a
  capture, so an answer in the FT-891's form is taken in that form, and one in neither form stops
  the wait with a console line rather than holding every change forever. None of
  the six drivers' power path has met real hardware — each driver's header says what it has been
  tried against, and that is always its frequency/mode path rather than every capability it carries.
- The IC-705's SET level (0x14 0x0A) doesn't drop when it's running off its own battery, even though
  actual output does — confirmed LIVE (5W actual against a 10W SET level on battery). CI-V has no
  command for actual transmitted power outside a live transmission (the RF-power METER, 0x15 0x11,
  reads 0 at rest — Icom's guide says so outright), so `IcomCivSession` infers battery vs. external DC
  from the DC-input meter (0x15 0x15) instead, and clamps the reported watts to `batteryMaxWatts` (5,
  from `ic705Model`'s override) whenever that reading is below `civBatteryMeterCeiling`. The threshold
  and both wattage figures come from one bench session each, not a published spec. That comparison is
  against the RAW reading, which is what saved it: the meter was long documented here as tenths of a
  volt, and Icom's own guide gives a two-segment curve instead (`00 13`=10 V, `02 41`=16 V on an
  IC-7300MK2). No voltage is reported from it at all now — that curve is a 13.8 V radio's, and the
  file describes the whole line.

## CW keying

A radio whose CAT protocol can key CW from text keys the app's messages: F1-F8 in the operation
view send the eight templates under Radio settings (`cwMessage1..8`), the Station dialog's keyer row
picks the speed and opens the editor, and `20WPM` typed into the call field sets the speed the way
`5W` sets power. The editor is the **CW Keyer** dialog — the message sets, saved together on Save, and message 1's
repeat and Enter Sends Messages, which apply as they change — reached from that row, the keyer area
and a row of its own in Settings → Radio; the settings it edits stay declared for SET/SHOW but are not Settings rows
(`listed: false`). Everything here is behind the `keyer` experiment (`EXP KEYER`, aliases `CW`/`MACROS`).

It is a **capability, not a transceiver method**: `CwKeyerSession` (driver.dart) sits beside
`AntennaSwitchSession` rather than adding three methods to `TransceiverSession`, because most
protocols in this layer (flrig, HRD, N3FJP, Commander) have no such command, "this radio ignores sendCw"
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
through `KY` on the entries that name a dialect (below). A sixth, rigctld, keys through Hamlib's `+b`
(`send_morse`), stops with `+\stop_morse` and sets the speed as the `KEYSPD` level — on the entries
that pin `cwKeyer` (the SOTAcat). Neither takes a VFO argument even on a `--vfo` daemon:
`send_morse` reads the rest of the line as its text, so a `currVFO` there is keyed. Both go out in
the extended form so a refusal comes back under its own header: a refused `send_morse` keyed
nothing, so the queue is dropped and the strip stops showing it, and either refusal is left as a
developer diagnostic.

**Whether a radio keys is a fact about its entry, asked of its node.** `EquipmentDriver.canKeyCw` is
the driver's word, but a driver serves a line — the CI-V driver an IC-706 as much as an IC-7300, the
Kenwood driver a QMX as much as a K4 — so what the service reads is `canKeyCwWith(config)`, the
driver's answer for THAT node's merged config (`CatService._radioKeysCw`): `cwKeyer` on Icom and
Yaesu (absent means yes, the line's documented default), `cwDialect` on Kenwood (absent means no),
`cwKeyer` on rigctld (absent means no: which backend is behind a daemon cannot be asked without keying
it, and most answer `send_morse` with `RPRT -4`).
The named entries pin these as overrides, the way the IC-705 pins its addresses; the GENERIC entries
(and rigctld, whose absent `cwKeyer` already means no) prefill them off and, under developer mode,
show them as fields (keyer_config.dart; the
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
it. A template that does not parse is shown as a notice, not keyed with its braces in Morse. One
message can include another, rendered (`{{ keyer.msg1 }}`); the render carries the chain of messages
being expanded, and one that reaches itself is an error naming the loop rather than a message
silently missing the part that looped. A key's label is a template too, and a blank one stands for
the message itself (`{{ keyer.msgN }}`), so a key reads what it sends. The
handler is a `HardwareKeyboard` handler in `OperationView` (which owns the draft QSO), claimed only
while that route is front-most — a dialog over it, the message editor included, keeps the keyboard —
and only for a bare function key with a message behind it — or its stand-in ⌥1-⌥8 (Alt+1-8), by the
physical key since Option turns the digits into other characters on a Mac, for a laptop or tablet
keyboard with no function row, and not while the keyboard is in free text (any text field outside the
entry row — notes, keyboard mode's own field), where on Spanish, Nordic and German Mac layouts
⌥-digits type '@', '[' and '|'; Escape is claimed only while
something — a message, a chain, a repeat — is running, and stops all of it.

**Neither protocol says when its keyer is free**, and both hold less than a CQ. CI-V's `0x17` takes
30 characters and NAKs a second command while the first is still keying; a Yaesu memory takes 50.
`CwSendQueue` (cw_send_queue.dart) sanitizes to the characters both keyers document, splits on word
boundaries to what fits, and sends the next piece only after the previous one's Morse duration at the
current speed (PARIS timing, the default 20 WPM until the radio has said) — a chunk boundary falling
on a word gap is what makes the wait invisible on the air.

**Keyboard mode** keys what the operator types, as they type it (`CwLiveTyping`,
cw_live_typing.dart): the keyboard button at the end of the CW strip, or ⌥K / Alt+K (by the physical
key, since Option makes K a '˚' on a Mac; not ⌘K, the command dialog's), puts a field beside the
message going out. What is typed is held in the app and handed to the key in use through `sendCw`, a piece at
a time — only while the key is idle, and only what is ready: every word finished with a space at once,
the rest after a 500 ms pause. Handed over is "sent": no keyer here can take back what it was given,
so Backspace reaches exactly what is still held, the line is the same on every keyer (a peer's radio
included), and nothing below `sendCw` knows the mode exists. Words are the piece because the queue
ends every piece with a word gap; a piece cut mid-word keys a gap inside the word. Enter or ⌥K again ends the mode
and hands everything held over behind what is keying; five seconds without a keystroke ends it the way
Enter does, and so does the strip closing. Escape in the field ends it and stops the key. Any other
stop — a tap on the message — drops every word typed, handed over or held, and leaves the mode on and
empty for a fresh message: a stop abandons what was being sent, all of it. Either way the mode listens to `cwStops`, bumped
ahead of every stop, because the quiet a stop leaves reads exactly like a message ending, and taken as
"free" it would key what is held right after the operator asked for silence — Escape reaches the
operation view's handler, and its stop, before the field. The
key going away ends it too, since `sendCw` would take the rest to nothing. Starting it ends a CQ repeat,
as a message key does. The field binds Space
itself, since the logging panel's Space moves to the next field.

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
  and KX3 entries pin the Elecraft dialect, the TS-590SG and TS-480 the Kenwood one; the QMX and
  QCX pin none. The K4 entry keys Elecraft-style at its own 8-100 WPM; see [k4-cat.md](k4-cat.md).
- **Yaesu CAT has no "key this text" command at all.** What it has is five text memories the
  operator can also fill from the front panel: `KM<n><text>;` writes one, `KY6;`-`KYA;` play them
  back. Keying from the app is therefore WRITE-THEN-PLAY through memory 5 (`yaesuAppKeyerMemory` —
  the last, so the four most people fill first survive), and whatever the operator had there is
  gone. The FT-450 (three memories of forty) and the FT-710 (`KY0n;`) pin their own, see §Serial. There is no stop: `Ft891Session.stopCw` only empties the queue, and the piece already
  playing plays out — reported to its estimated end, so the keyer area does not claim it stopped. `KS;` is the speed, 4-60. The session polls the keyer's status every ten seconds (`0x15`) because a keyer in host mode
  pushes nothing while idle, and the reply restates the speed so the node never reads as stale; a
  port that answers nothing within three seconds of host open is reported as having no keyer on it,
  and a message whose echoes stop arriving is given up on past its own timeline plus a grace, with
  the queue cleared and a problem shown until the keyer speaks again.

**What is going out is shown** in a strip between the logging panel's call-info area and its entry
row — the keyer area (`KeyerArea`, through `ControlStripSettings.aboveEntryRow`): the message with its sent characters
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
Turning Enter Sends Messages on (`EXP ESM`) adds one more, **ESM Messages**, and puts it in use: ESM
reads messages by position, N1MM's — F1 CQ, F2 exchange, F3 thanks, F4 my call, F5 their call, F8
again ([logging-fields.md](logging-fields.md) § Enter Sends Messages) — which the Default, whose F2
answers a caller in one key, is not laid out for. It is added once, ever: a set the operator
renamed or deleted stays that way when the experiment comes back.

**Message 1 can repeat**, and only message 1: it is the CQ, and a repeating exchange would key over
the contact it is answering. `cwRepeatDelay` (and `voiceRepeatDelay` for the memories) is the wait
between the message ENDING and it going again — from the end, not from the keypress, or a chain
would key over its own message. One engine serves both keyers (`CatService.armKeyerRepeat`): the
send is supplied by whoever armed it, since rendering a template against the draft is the operation
view's job while a voice memory needs nothing prepared. The keyer area shows the wait as a bar that
EMPTIES, with the buttons down for the whole chain — including the render-long gap between a wait
ending and the next message reaching the radio, which is why `keyerRepeatActive` is a notifier and
not a getter. A chain ends on Escape or a stop, on a tap of the countdown, on another message, on a
call entered, on the setting going to No, and in any case after five minutes — an unattended CQ that
keys forever is a transmitter nobody is watching. A keypress by itself stops nothing.

**A chain also ends when the VFO leaves its frequency**: more than 50 Hz for CW, 300 Hz for voice,
or onto another band, measured from where the LAST repeat went out (`KeyerRepeat.noteVfo`). Any move
counts — the radio's own knob as much as a frequency typed, a band picked, or a spot tapped in the
app — since the operator has gone to chase a caller or dodge QRM, and the next CQ would call where
nobody answered. Re-measured at every send, so a few hertz of nudging per repeat never adds up to a
stop. The band is what a station with no frequency to read goes on; a frequency that merely goes
missing on the same band — an emptied Frequency field — is no move. The radio's own readings while it
transmits are skipped: working split, a rig may report its transmit frequency while keyed, and every
split CQ would end at its first send. Like a keypress, a QSY leaves a message already keying to play
out — and a repeat that was mid-render when its chain ended keys nothing.

What stops is decided by what the operator did, the same for CW and voice:

- **Escape** stops every message, Enter Sends Messages chain and repeat (`CatService.stopKeying`),
  whoever started it — a peer's included — and is claimed only when there was something to stop.
  The operation view's key handler does the stopping; the logging fields, which hear the same
  keystroke after it, read its answer (`escapeStoppedKeying`) rather than asking again, since asked
  again the stop just made reads as nothing running and the Escape also ends a QSO edit.
- **A tap** on the keyer area's message line stops that keyer's message and everything behind it; a
  tap on the countdown ends the repeat.
- **A call entered** — any operator input into the callsign field: a key, the on-screen keyboard, a
  paste, the numbers row (`LoggingSession.onCallTyped`, which hears none of the panel's own writes,
  the wipe after an Enter above all) — stops message 1, any Enter Sends Messages chain holding it,
  and any repeat (`CatService.stopMessageOne`). A command typed there is input like any other: its
  first character stops the CQ. Every other message plays out: an exchange or a TU
  keying while the call is corrected is the contact being worked. The CW queue carries no message
  numbers, so "message 1 is on the air" is "the newest send held message 1 and the key is still
  busy" — a message queued behind it makes it not message 1, and one queued ahead of it goes with
  the stop. A voice chain holding memory 1 stops whole, whichever memory is playing, since CW keys
  the same chain as one message the queue cannot split. Only this operator's own message 1: the
  mark is set only on a send the keyer (or the peer link) took, ends with the message it marked, and
  a peer's play or message on a shared transmitter never carries it — their CQ is theirs to stop.

Every send that keys NOTHING cancels too (a failed render, a dead runtime, a message that
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

**The state poll's idle rate is the operator's as well** (`pollInterval`, `poll_config.dart`). On an
`AdaptivePoller` it moves the slow end only (3 s by default) and leaves the 200 ms it drops to while
the dial moves alone, because that half is what makes a spun dial look live; the staleness ceiling
moves with it (three idle intervals). CI-V's fallback poll is fixed, not adaptive, and the setting is
simply its period (5 s by default). It is capped at 10 s, a third of `catStaleAfter`: for most
polling drivers the poll is the only proof the radio is still there, and a slower one would show a
healthy radio as not responding between answers. The reason to raise it is the same as for the meter
cadence: a bridge or a shared line that should be asked less often.

Three consequences that bit during the build, all worth keeping:

- **A fast watch starves a guarded state poll.** flrig serializes one request at a time, and its
  state poll originally waited for an idle socket. With a watch running many times faster there is
  almost always a request in flight, so the frequency stopped updating altogether — visible as a
  driver that had gone quiet, with nothing pointing at the cause. The guard is the QUEUE alone: one
  request in flight and an empty queue is a healthy session, not a backlog.
- **A fast watch's answers starve a deferred state poll.** A poll that waits whenever the radio has
  just said something (`AdaptivePoller.noteData`) must count only the answers to the state poll
  itself. rigctld answers every `+t` with a header, a value and a status (`get_ptt:`, `PTT: 0`,
  `RPRT 0`) several times a second. Counting any of those lines as news re-arms the poll before it
  fires, so the frequency is read only on the 9-second staleness ceiling. The driver therefore keeps
  an allow-list of the state answers (`Frequency:`, `Mode:`). A deny-list of telemetry lines is
  starved again by the next line a new question brings.
- **A level's value is unlabeled.** Hamlib labels `+f`'s answer (`Frequency: …`) but not `+l`'s:
  `get_level: SWR`, then a bare `1.5`, then `RPRT 0` (`get_level: currVFO:SWR` on a `--vfo` daemon;
  captured from rigctld 4.7.2, the same in 4.5). The level is named only by the header line before
  it, so that is what the driver reads it by.
- **Nothing goes out before `\chk_vfo` is answered.** A read sent ahead of the probe reaches a
  `--vfo` daemon with no VFO; it takes the next line it is sent as the missing argument and runs what
  is left of that line as one-letter commands (`get_level: None:+l`, captured from 4.7.2 `-o`). So
  the session sends the probe alone and starts polling from its answer: `ChkVFO: 0/1`, an `RPRT` from
  a daemon too old to know it (plain), or two seconds of silence (plain).
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

**Each node keeps an SWR average per transmission** (`_NodeRuntime`, `CatService.swrAverageFor` and
`lastTransmissionFor`): the running one while the radio is keyed, and the last finished one —
`swrAverage` and `endedAtMillis`, in real time — after. A single reading is the wrong thing to hold
on screen once the over ends: it is whichever sample the poll happened to land on. Three rules decide
what counts:

- **Only readings with RF out.** Between words on SSB a radio reads SWR 1.0 at no power, which would
  flatter every average. A reading counts only while the last power-out reading is above zero.
- **A reading in the second before keying counts.** A polled driver reads its meters on the
  transition, and reports the first of them just BEFORE it reports the transmission itself; dropped,
  a short over would have nothing to average.
- **A key-down within 500 ms of the last key-up continues that transmission.** CW break-in unkeys
  between characters, and averaging each element alone would leave a reading or two per average; a
  break-in over averages as one.

The averages are for what draws the radio live — an extension's `readRadio().lastTransmission` and a scene's
`radio.swrAverage` ([panel-scenes.md § Radio values](panel-scenes.md#radio-values)). Every meter
reading and TX change also fires `CatService.meterReadings`, which, unlike the service's own
notification, includes the receive signal: only those scenes listen to it.

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
| flrig | `rig.get_ptt` | `get_pwrmeter` (watts outright), `get_swrmeter` (a ratio); flrig 2.0.12 has no ALC or voltage method |
| rigctld | `+t` | `RFPOWER_METER_WATTS`, `SWR`, `ALC`, `VD_METER`; a level refused with `RPRT -1`/`-4`/`-11` is not asked again on that connection |
| Ham Radio Deluxe | `get button-select TX`, where `get buttons` lists a TX button; slowed after two unanswered | none: HRD's meters are per-radio sliders in unstated units |
| DXLab Commander | `CmdSendTX`, slowed after two unanswered | none: Commander publishes no meter message |
| N3FJP | none: the API has no PTT read | none |
| FlexRadio | `interlock state=`, PUSHED — costs nothing | power out and SWR: the transmitter's `FWDPWR` (dBm, turned to watts) and `SWR` meters, from the VITA-49 meter stream that carries the slice's LEVEL; tenths, at most four a second |
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
its `TX;` is the command that KEYS the radio, which this app never sends to ask anything, only to key
the operator's own PTT (§ PTT) — so the flag in `IF` is the only way to ask. It sits immediately before the mode (P8, then P9) on every documented
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
voice memories, Escape stops one, and the **Phone Keyer** dialog names each memory and — on a radio
whose CAT can — records into it, beside memory 1's repeat and Enter Sends Messages, which apply as
they change. Under the same `keyer` experiment (renamed "Keying"; `VOICE` is an
alias). The draft's mode and not the radio's, the same reasoning as the messages being templates
against the draft: the message is for the contact being logged, and a rig left in USB while the
operator logs CW keys CW.

**The messages are audio in the radio, so the app stores only a label.** `voiceMessageLabel1..8`
(Radio settings, like the CW ones) is the whole of it — nothing to render, nothing to sanitize, and
no `voiceMessage$n` beside it. A memory is keyed by NUMBER, and every surface offers exactly as many
as radio1's session says it has (`voiceMemoryCount`: 8 on an Icom, 5 on a Yaesu, 4 on a TS-590, 8
on a K4, 2 on a KX2/KX3, 8 of a FlexRadio's 12), which is why the labels are eight and a radio with fewer shows fewer.

**Unless the radio names them itself.** A FlexRadio's DVK holds a name and an exact length per slot,
which every SmartSDR client sees. A `RadioNamedVoiceMemories` session reports them
(`EquipmentSink.reportVoiceMemories`, into `EquipmentState.voiceMemories`), and while that radio is
radio1 — or is the radio a peer keys — they ARE the labels and lengths: the settings' copies are for
radios that keep neither, and one shown over the radio's own would name audio by a label no other
client of that radio sees. Renaming in the Phone Keyer dialog writes to the radio — only when the
label was changed, since the field may hold what showed before the radio said otherwise — and a play
is not measured, since the radio already said how long the memory runs; a memory with no length
reads "Empty" rather than "Unknown length". Disconnected, the settings answer
again.

**Radio1 plays, not the key in use** — a peer's radio1 included, whose memories play over the link
and whose labels and measured lengths come with them (§ Keying a peer's radio). `VoiceKeyerSession` (driver.dart) sits beside `CwKeyerSession`,
a capability for the same reasons — but `CatService.canPlayVoice` is radio1's session being one, and
connected, with no designation in between: the memories are the transceiver's, a WinKeyer has none,
and a second radio's are that radio's. A driver shared across a line (Kenwood CAT) creates sessions
that implement it for rigs that have no voice keyer at all, which is what a `voiceMemoryCount` of
zero is for — a QMX on the Kenwood driver is not a voice keyer, and the catalogue entry, not the
driver, says so (`voiceDialect`/`voiceMemories` overrides, the way `ifModeOffset` is pinned). The
TS-590SG and TS-480 pin zero too: their memories need an optional voice unit the app cannot detect.
The Icom and Yaesu drivers honour `voiceMemories` the same way (the IC-706, IC-7100, X6100 and G90
pin zero), and the generic entries prefill zero and ask under developer mode — see § CW keying on why
a generic asks. rigctld is the same, with `voiceMemories` absent meaning none: Hamlib's
`\send_voice_mem N` and `\stop_voice_mem`, plain and with no VFO argument even on a `--vfo` daemon
(the `+` form there waits for an argument it never gets), on the entries that pin a count — the
SOTAcat's two. Hamlib has no command that records.

**The radio says when it is done, or the ceiling does.** No protocol here reports a memory's
progress, and only some answer "still playing?", so a session reports `VoiceActivity` (memory,
playing or recording — `EquipmentSink.reportVoiceActivity`, `CatService.voiceActivity`) as it sends
the command and then asks its own question every second (voice_activity_tracker.dart): Yaesu's `PB0;`
answers the channel playing, the K4's `DA;` answers `DA0;` when idle, Icom and the KX line have no
such read so they are asked whether they are transmitting (`0x1C 0x00`, `TQ;`, and rigctld's `+t`) —
a voice memory transmits. Past the radio's own memory length — `VoiceKeyerSession.voiceMemoryCeiling`, pinned per
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
  pins its `voiceMemories` (eight on the modern line, zero on the IC-706, the IC-7100, the X6100
  and the G90); an absent key is a generic entry's node and means none.
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
- **FlexRadio** (SmartSDR+ only — its DVK is a licensed feature), from FlexRadio's own API reference,
  [TCPIP-dvk](https://github.com/flexradio/smartsdr-api-docs/wiki/TCPIP-dvk), with the status and
  licence lines captured from a FLEX-6600 on 4.2.20 and play, stop, record and rename verified on it.
  `dvk playback_start id=n` plays and keys the radio itself, `dvk rec_start id=n` records (without
  keying, ten seconds at most, the radio stopping and saving it there), and the stops are bare —
  `dvk playback_stop`, `dvk rec_stop` — since there is one keyer doing one thing. `dvk set_name
  id=n name="…"` names a slot: at most 61 characters, no `"` or `|`, runs of spaces collapsed, which
  is how the name is shown before the radio confirms it. `sub dvk all` answers the status and one
  `dvk added id=n name="…" duration=<ms>` per slot, and every state change after that — the radio
  ending a play or a recording by itself included — is pushed to every subscribed client, as is the
  bare `dvk id=n name="…" duration=<ms>` update after a rename or a recording. So nothing is polled:
  the status (`playback`, `recording`, `preview`, `idle`) confirms and ends an activity, and a play's
  ceiling — its slot's own length plus 3 s; a recording's is `voiceCeilingSeconds` — is only a
  backstop. A non-zero `R` reply to a start is the radio REFUSING it (an unparseable command, no
  such slot, no licence), which no status says, so it is doubtful at once — matched to the start it
  answers, not to whatever plays that memory now. A start stops whatever is going first: the
  reference warns that an operation started over another can leave the keyer inconsistent. A slot
  the radio says is EMPTY is refused here and never sent, because a play of one answers `0` and can
  leave the radio keyed. A refused rename re-reads the slots (`sub dvk all`), so the slot does not
  keep a name the radio never took. SmartSDR's default names (`Recording 3`) read as no name.

  An unlicensed radio answers every `dvk` command with `50004001`, and the status line's `enabled=`
  is always 1. `sub license all` answers at once with every feature, the keyer's among them
  (`license feature name=DIGITAL_VOICE_KEYER enabled=1 reason=PLUS`, captured). Either the licence
  line's `enabled=0` or a `50004001` reply makes the session hold NO memories — `voiceMemoryCount` 0
  and an empty `reportVoiceMemories`, which is what makes the surfaces read the new count — and so
  does the `status=disabled` or `enabled=0` the reference defines as unavailable. A radio without
  SmartSDR+ is then a radio without a voice keyer: its keys disabled, F1-F8 free, and no problem on
  its row. Until any of these has said, the memories are offered.
- The **placeholder radio** "plays" for four seconds and records until stopped, so the surfaces run
  on a web build.

## PTT

**Control PTT with [']** (Radio settings, just before Smart VFO Snap; under the `keyer` experiment,
off by default): in a Phone mode — the DRAFT's, as for the voice memories — `'` keys radio1 over CAT
and `'` again unkeys it. Escape unkeys it too, alongside every message it stops. Not with ⌘, Ctrl or
⌥ held. The key is matched by the CHARACTER it typed (`event.character`), not by its name: US
Shift+`'` types `"` and a German or Swiss layout types `'` with Shift, and the platforms disagree
about which key name either one reports. The view tracks the draft whenever PTT is possible, not only
for the keyers — on a radio with no voice memories and a station with no CW messages, the draft's
mode would otherwise never be known — and before it has heard one it reads the radio's mode, which is
what a fresh draft takes: turning the setting on mid-operation publishes no new draft to hear.

**Keying PTT ends this operator's own keying first** — a CQ repeat, an Enter Sends Messages sequence, a
memory or a CW message going out — the way Escape does. The operator's voice replaces whatever was
queued: a repeat left armed would play its CQ over them when its wait ran out, and a memory left
playing ends with the radio's own unkey under their key (the FT-891's `TX0;`).

**One handler for the station** (`PttKeyboard`, cat_ptt.dart), registered with the keyboard once and
kept for the service's life, however many surfaces can key. While a key is held, `'` or Escape drops
it from anywhere — another field, a dialog, Settings, an operation that has since closed — because
the transmitter is on and the key that put it there has to take it off. Only KEYING asks the surfaces:
each operation view registers a `PttKeyTarget` that names the radio `'` keys from it, or null, and
only the view in front ever names one. Two views each handling the key themselves would disagree
about whether it is held — the one behind would unkey and the one in front key again on the same
press. The auto-repeats and the release of a press that went to PTT go nowhere, or holding `'` down to
talk would type a run of apostrophes into the field.

**Where the keyboard is decides whether `'` keys** (`fieldTakesKey`, key_bindings.dart — the rule
every shortcut on a typing key follows, [keyboard-shortcuts.md](keyboard-shortcuts.md)). In the
main fields — the call, the reports and every exchange field, a name or a state included — `'` is PTT:
that is where the operator works a contact. The one exception is the call field while it reads a
command that takes free text, as NOTE does, which keeps the character; it is asked of the field's own
formatters, so the call field answers for the mode it is in. In the secondary controls the formatters
decide outright: a field that lets the character through keeps it (a note), one that would filter it
out (the frequency) lets it key the radio — asked without the length limit, since a field that is full
right now still takes `'` as text. Any other text field keeps it whatever it filters — outside the
logging fields `'` never keys while the operator types — and with no field focused it is PTT.

`PttSession` (driver.dart) is a capability like the keyers, on every protocol with a documented PTT
set: CI-V `0x1C 0x00 01/00`, Yaesu `TX1;`/`TX0;` and the FT-8x7's binary `0x08`/`0x88`, Kenwood and
Elecraft `TX;`/`RX;`, FlexRadio `xmit 1/0`, flrig `rig.set_ptt`, rigctld `T 1/0`, the Guohetec
radios, and Ten-Tec `*TK`/`*TU`. HRD, Commander and N3FJP document none and are not keyed. A session that keyed unkeys in its
teardown, ahead of anything queued: no protocol here has a dead-man's switch, and only the driver can
put the unkey ahead of its own queue. A driver marks itself keyed BEFORE a key goes out and clears the
mark only AFTER an unkey has: either command throwing leaves the teardown an unkey to send. PTT on a serial line (RTS/DTR, § RTS and DTR) is not offered;
neither is a peer's radio.

**The key belongs to the radio it keyed** (`CatPtt`), not to the Main VFO role. Its TX reports and its
release go to that radio's session whatever Main VFO points at since: moving the role, or adding a
radio that takes it, leaves the key where it is, and `'`, Escape and the timeout still reach it. A
session that closes is forgotten (`forget`): its own teardown unkeys the radio, and the next `'` keys
the new session rather than spending a press on an unkey for a closed connection.

**One transmitter at a time, whoever asks** (`CatService.yieldTransmitter`). Before anything transmits
on a radio — a PTT key, a CW message, a voice memory, this operator's or a peer's request on a radio
this station offers — every other radio of the station goes quiet: its CW queue stops and its voice
memory stops (`CatKeying.quietOthers`). The app's PTT key drops before a CW message or a voice memory
on ANY radio, the one it is on included: the message takes the transmitter over. What it stops is
stopped the way every other stop is — a memory cut short is not timed, and only the chain of what was
stopped is cancelled: left armed, a stopped CQ would come back after its wait and take the transmitter
back, and the chain whose own send is quieting the others is not what went quiet. A CW message's radio
is the one whose keyer sends it — the key in use itself when that is a radio's own keyer, radio1 when
it is a keyer of its own. A keyer that is no radio (a Winkeyer) is left alone: it keys for radio1, and
a message about to go to it queues behind what it is sending. This is the interlock two-radio
operation builds on — the operator starts a message on one radio while the other is still on the
air, and the one they reached for is the one that transmits.

**The app's key follows the radio.** What the app holds is its own key; whether the radio TRANSMITS is
the radio's report. A radio that said it was transmitting and then says it is not has dropped the key
itself — its own time-out timer, a mic switch — and the app's key goes with it, so the next `'` keys
again rather than unkeying a key nobody holds. The unkey is sent anyway: a CAT key is latched, and a
report that was transient or misread would otherwise leave the radio keyed with no timeout left. Before the radio has confirmed, a "not transmitting" is
the poll that was already on the wire and is ignored. Nothing else is read into silence: a slow TX
watch (a shared serial line, a busy flrig), a radio that cannot report, and one that refused the key
all look the same, and a fixed wait before calling a key refused would unkey a working radio whose
watch is slower than the wait. The **one-minute** timeout (`pttTimeout`) bounds them all: a key
forgotten under a mic cable is a minute of dead carrier, not an hour. One protocol cannot promise the
teardown unkey: flrig drops a request that arrives while it is answering another, and its TX watch
keeps a `get_ptt` in flight most of the time, so a disconnect mid-answer can lose the unkey; the
radio's own time-out timer is what is left. flrig and rigctld also answer a refused PTT set with a fault
the drivers do not surface, so a refused unkey reads as done until the radio's TX watch says otherwise.

**On the air means either** (`radio1IsTransmitting`): radio1 says it is transmitting, or the app holds
its key — which a radio that cannot report TX never confirms. The radio's own word goes stale with its
silence; the app's key does not: RF in the CAT cable silences a radio exactly while it transmits, and a
key read as "off" then would reopen the antenna lock under the carrier. The key has its own minute. A
radio that refused the key (TX inhibit) likewise reads as on the air until `'`, Escape or the timeout
— the cost of reading nothing into silence. The antenna lock and Smart VFO Snap read it (§ The alert,
and the two things TX state is allowed to stop), so neither acts on a transmitter the app just keyed.
The indicators read it too, and ALSO light for a key the app holds on any other radio — one left behind
when Main VFO moved is still the operator's to drop: the Radio chip's glyph becomes a red dot and the
keyer area's Voice pill reads "TX" beside one, at the width "Voice" gives it, so the strip does not
shift each time the operator keys.

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
this station has never played, so while a peer radio is picked the Phone Keyer dialog shows that
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
the operator who armed it (`armKeyerRepeat` supplies the send), and breaks on their own Escape or entered call.

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
`app/lib/services/cat/vfo_snap.dart`; when to ask them is `_noteSnapReading` in
`app/lib/services/cat/cat_vfo_snap.dart`.

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
| flrig, rigctld, HRD, Commander | poll only — these servers push nothing at all | `AdaptivePoller.interval` |
| N3FJP | pushes every change (API 0.8 on); the `READBMF` poll is the backstop | `AdaptivePoller.interval` |
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
  arrive as `VfoOrigin.user` and both cancel a pending snap and become the new resting point. An
  on-screen dial is not exact: its moves arrive as `VfoOrigin.dial` and are fed to the snapper as
  readings, so a knob turned in an extension's panel settles like the radio's own.
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

**The operator's antennas are linked to the switch's ports, not renamed by it.**
A switch calls its port whatever somebody typed into the switch's own web page,
possibly years ago; the app already has antenna nodes with the operator's own
names and band coverage. The link field is emitted by the station panel
(`station_panel_annotations.dart`), not by the driver, for exactly the reason
the antenna `bands` field beside it is: a driver is pure catalogue data with no
access to the station's inventory. When the switch is disconnected the editor
falls back to `EquipmentDriver.antennaPortCount` — the case that matters, since
setting a switch up is something an operator does before ever connecting it.

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

## Tuner, passband and the radio's own antenna ports

Three more capabilities beside `CwKeyerSession` (driver.dart), each a session interface with a sink
of its own (§ Drivers never touch app state): `AntennaTunerSession.setTuner(inline:)`,
`PassbandSession.setPassband` and `RadioAntennaSession.setAntenna(rx:, tx:)`. `CatService`'s
`setNodeTuner`, `setNodePassband` and `setNodeAntenna` address one node and do nothing for a session
without the capability. Their caller is an extension's `setRadio`
([hooks.md](../extensions/hooks.md)), and what it reads back is `EquipmentState.tuner`, `.passband`
and `.antennas`.

| driver | tuner | passband | antenna ports |
|---|---|---|---|
| Icom CI-V | `0x1C 0x01` | `0x1A` filter-width index, SSB/CW/RTTY and AM tables | `0x12`, for an entry that pins its port count |
| Yaesu (FT-891 driver) | `AC` | `SH` with `IS` and `NA`, tables chosen by the radio's `ID` answer | `AN`, ports by `ID` |
| Kenwood | `AC` (TS-480/590/890/990) | per a dialect the entry pins: the TS-590SG's `SL`/`SH`, `FW` and `IS`; Elecraft's (the K4 included) `BW` and `IS` | `AN`, per a dialect the entry pins (one port of two, or the TS-590's with its RX ANT jack); never the K4's |
| FlexRadio | `atu` | the slice's `filter_lo`/`filter_hi` | the slice's `rxant`/`txant`, chosen separately |

- **Switching a tuner never transmits; a tune is its own act, and only ever the operator's.** On
  Icom, Yaesu and Kenwood "in line" puts the tuner in on the setting it remembers, without
  transmitting. Each protocol's start-a-tune value (CI-V's `0x02`, Yaesu's `AC002;`, Kenwood's P3
  `1`, sent with P2 `1` so the tune goes through the tuner) goes out only from
  `AntennaTunerSession.startTune`, whose one caller is an extension's `setRadio({startTune: true})`
  — an operator pressing a button. Nothing in the app starts a tune on its own. The driver refuses
  one while the radio transmits, while its tuner reads as tuning, and on a radio that has not yet
  answered its tuner read, where a carrier would go into an antenna nothing matches; `CatService`
  also drops a second start within three seconds, before the first shows in the radio's reports.
  Escape (`stopKeying`) ends a tune the app started — `AntennaTunerSession.stopTune`, which puts
  the tuner in line and is sent even while transmitting — but not one started at the radio, which
  is the operator's there. The start and stop values come from the CAT manuals, not a capture. A FlexRadio has no in-line switch: its tuner
  engages only by TUNING, so there "in line" is a carrier on the air, briefly, from its memory for
  the frequency when it has one, and `canStartTune` is false — a separate tune would be the same
  carrier again. Kenwood's set touches only the transmit-side AT and hands the receive-side one back
  as the radio last reported it, since that one is the operator's choice.
- **A passband is edges, not a width.** Hz from the tuned frequency as the radio draws them — `100`
  to `2800` in USB, negative in LSB — so one shape describes a Flex's free edges and a table radio's
  width plus shift. A radio that sets only a width from a table takes the nearest one and keeps its
  own shift; its report says where it landed. Yaesu does not say where `SH`'s width sits, so an SSB
  passband is placed about 1500 Hz from the carrier (`yaesuSsbPassbandCentreHz`) and moved from
  there by the IF shift.
- **A port count is catalogue data.** Nothing in an Icom's `0x12` answer or a Kenwood's `AN` says how
  many ports the radio has, and a one-port radio may still answer — the KX3 accepts every K3 command.
  So the entry pins it (Icom's `civAntennaPortsConfigKey`, Kenwood's `antennaDialectKey`, Yaesu's
  table by `ID`), and an unpinned radio is never asked: a choice offered that the radio does not have
  is worse than none.
- **A read the radio may lack is asked slowly, and given up on.** The tuner, the filter and the
  ports move when someone presses a button, so the Yaesu and Kenwood drivers read them every fifth
  state poll (about every fifteen seconds at the default idle rate) and the filter again at once on a
  mode change; CI-V reads them on its own slow state poll. A radio without one refuses on every poll
  for the whole connection, so two refusals with no answer between stop the asking — two, not one,
  because a CI-V NAK and a Kenwood or Yaesu `?;` name no command, and one arriving late for
  something else must not cost a radio its readout. A CI-V radio may instead ignore the read — the
  Xiegus' way — and since CI-V sends one command at a time, each silence holds the bus for a whole
  answer timeout; three of them stop the asking too, three because a lost answer says less than a
  refusal. A silence counts only once the radio is heard sending something after it, and not if
  another command went unanswered first, so a radio switched off for a while keeps its reads however
  often it is; a late answer clears it. Neither counts on the air,
  where a radio may set aside a read it answers on receive — the K3 line answers `?;` to whatever it
  will not take while transmitting. The bookkeeping is one
  class, `OptionalRead` (drivers/optional_read.dart), used for every such read — the Icom DATA
  submode's included. What a known model lacks is pinned instead of learned, and no answer reopens
  a pinned read: the G90 and X6100 have no filter-width command (`civFilterWidth: false`, hamlib's
  `x1ax03_supported`).

## Software intermediaries

A program the operator already runs may own the radio's port — flrig, a rigctld daemon, Ham Radio
Deluxe's Rig Control, an N3FJP logger, DXLab Commander — and answer for it over TCP. Each is a
catalogue model of its own (equipment_bridges.dart) on the shared TCP transport, with a driver for
its protocol. Where HaLo also *serves* that protocol (§ CAT server), the driver and the server share
one codec file (`hrd_codec.dart`, `n3fjp_codec.dart`).

flrig and rigctld were built against the real programs. **HRD, N3FJP and Commander were built from
published protocol descriptions alone**, with no capture of any of them; their troubleshooting notes
say so and ask for a report. The HRD and N3FJP drivers are run against HaLo's own emulations
(`cat_server_own_drivers_test.dart`), which proves only that the two halves agree — both were read
from the same documents.

- **One request at a time, and none waits forever** (`request_queue.dart`). HRD's replies name no
  command, so an answer belongs to the oldest question, as with flrig. Commander's do, but its
  document says nothing about two messages in one read, and a server that parses only the first
  would drop the second. So both keep one message on the wire. Unlike flrig, a question that goes
  unanswered is given up on (2 s for HRD, 1 s for Commander): without a capture there is no knowing
  which commands a given version ignores, and one it ignores would otherwise stop every poll behind
  it. A Commander set, which has no answer, is followed by a 100 ms pause instead.
- **A timeout is followed by silence.** An answer that arrives after its question was given up on
  would be read as the answer to the next one, and on HRD every answer after it too, for the life of
  the connection. So nothing is sent for 500 ms after a timeout, and a late answer lands while
  nothing is outstanding. HRD also checks each answer's shape (whole Hz for a frequency, `0`/`1` for
  PTT), which catches an answer later still.
- **A PTT watch the peer ignores slows down rather than stopping.** Some radios behind HRD or
  Commander have no readable PTT, and each unanswered question holds the wire for a timeout while the
  frequency poll waits. After two misses the watch asks every five seconds, and one answer restores
  it: a peer that was only busy keeps its PTT.
- **HRD's mode is an item in the radio's own dropdown.** The dropdown's name (`Mode`, `Main Mode`)
  and its items (`PKT-U`, `USB-D`, `DATA-U`) differ by radio family, so a session learns both at
  connect (`get dropdowns`, `get dropdown-list`), reads every family's spellings
  (`appModeForHrdMode`), and sets a mode by the radio's own item and its index. Before the list is
  known, or for a mode the radio lacks, nothing is sent: a guessed index selects whatever sits there.
  The dropdown is `Mode`, else one starting with it (`Mode A`), else `Main Mode`, and only then any
  naming a mode — `AGC Mode` listed first is not the radio's mode. An opening question that goes
  unanswered is asked again ahead of the polls, up to three times; one answered with an error (HRD
  up, its radio not yet) is asked again with the polls until it answers. Either way, a missed one
  would leave the session without what it teaches until a reconnect, while the frequency kept the
  row looking healthy. A radio with no recognisable mode dropdown says which dropdowns it has, as a
  diagnostic.
- **Commander reads a set's frequency in its machine's locale** — `14074,5` in Germany — while
  `CmdGetFreq` answers in a fixed form. A session asks `CmdSendFreq` (locale form) with every poll
  until an answer settles the separator: one that could be either (`0,000` from a radio that is off,
  `14,010`, `1,296,100`) teaches nothing. After three go unanswered it stops asking. Until then, or
  for good, a set goes out in whole kHz, which reads the same in every locale — half a kHz off
  rather than 1000×. Both questions reply as `CmdFreq`, so the frequency read accepts only the fixed
  form, and a late locale answer is also kept off it by the silence after a timeout.
- **N3FJP speaks a log's modes**: `SSB`, `FT8`, `DATA`. A report goes through `radioModeForAppMode`
  like any other app mode, so `SSB` becomes the sideband for its frequency and `FT8` DATA-USB. N3FJP
  answers `READBMF` with or without a radio behind it, so `RIGENABLED` answering `None` is reported
  as a problem: the row is connected, and what it follows is what was typed into N3FJP. It is asked
  with every poll, so the problem follows N3FJP's rig interface being set up or lost mid-session.
- **None of the three sets power or keys the transmitter.** HRD's power is a per-radio slider,
  N3FJP's API has no power, and Commander's `cwchars` (CW from text) is not wired to the keyer.

## CAT server

The other direction: HaLo as the thing other programs connect to. Ham Radio Deluxe, flrig, rigctld
and N3FJP's loggers all offer a TCP port through which WSJT-X, fldigi, GridTracker and friends read
and tune the radio. HaLo can stand in for any of them, so those programs follow the Main VFO radio
while HaLo holds the connection to it. It lives in `app/lib/services/cat_server/`, and its settings
are one row in the Radio section (behind `EXP SERVER`), opening a dialog: the protocol (or Disabled), the port, and
"Open access" (off by default).

| Protocol | Default port | Pinned against |
|---|---|---|
| Hamlib `rigctld` | 4532 | a real `rigctld -m 1`, and what Hamlib's NET client (`rigctl -m 2`, the backend WSJT-X uses) sends while opening a radio |
| flrig XML-RPC | 12345 | what Hamlib's flrig backend (`rigctl -m 4`) sends |
| Ham Radio Deluxe® IP server | 7809 | published descriptions of the frame and command set; no capture yet |
| N3FJP API | 1100 | N3FJP's published API document; band, mode and frequency only |

**One server at a time.** The operator picks which program HaLo stands in for. Picking another
closes the first. Each program keeps its own port, starting at the port that program uses by
default, which is where its clients look first. A custom port is usually there because the real
program still holds the usual one, so it survives a switch to another program, or to Disabled, and
back. Until **Open access** is turned on, only this computer can connect (both `127.0.0.1` and `::1`, because a client told
`localhost` may resolve either). The port field saves as
it is typed, so a change waits a moment before the server rebinds. Otherwise every prefix of the port
being typed would be a socket opened and closed. A rebind waits for the old socket to close, since a
port still held cannot be bound again. A bind that fails is retried every ten seconds, because the
usual cause is the program being replaced still holding the port. If something already holds `::1` on
that port, the bind fails rather than serving `127.0.0.1` alone. Otherwise `localhost` clients would
reach the other program while the status said "listening".

**What the servers serve is `vfoA`, not a driver session.** Reads come from `RadioService.vfoA` and
writes go to `setVfo` with the default `user` origin, which is the funnel a keystroke in the logging
panel takes. That is what moves the panel along with the radio, lets Smart VFO Snap and the echo guard
see the change, and reaches a peer's radio when that is the Main VFO. A `radio` origin would be taken
for the radio's own echo and never sent to it.

**No radio, no answers.** Every server refuses to report or tune unless a Main VFO radio is connected
(`CatServerRig.available`): a local node that is connected and not stale, or a peer radio its device is
offering. A client that saw a frequency with nothing behind it would believe it was in control. Each
refuses in its own protocol's words (`RPRT -6`, an XML-RPC fault, `ERROR:`), and N3FJP answers
`READBMF` the way N3FJP does with no rig attached.

**No PTT.** HaLo's drivers cannot key a transmitter, so every protocol says so: rigctld's `dump_state`
claims `ptt_type=0` and `T` answers `RPRT -11`, flrig faults `rig.set_ptt`, HRD errors on the `TX`
button, and N3FJP ignores `RIGTX`. A client falls back to its own keying (VOX, a serial line).

Three things the captures showed, each of which fails a client with nothing on screen but a timeout:

- Hamlib's flrig backend starts every request with `<?clientid="hamlib(…)"?>`, which is not a
  well-formed processing instruction. flrig tolerates it, and a strict XML parser faults every call,
  so the request body is read with patterns.
- Hamlib compares flrig's status line against exactly `HTTP/1.1 200 OK`.
- rigctld's `\get_lock_mode` answers a value and then an `RPRT` line, and Hamlib's client reads both.
  With one line, every later reply is read one command late.

N3FJP speaks first: a `READBMFRESPONSE` goes to every client when band, mode or frequency changes,
and GridTracker relies on that rather than polling. A push that follows a client's own `CHANGEFREQ`
waits until that command's reply is out.

**What a client sends is checked.** A frequency must be finite and inside the radio spectrum:
`NaN`, `Infinity` and `1e400` all parse as numbers, and any of them in `vfoA` reaches the logging
panel, a logged contact and the radio. A mode must be one the app knows, and `CW-R` becomes `CW`,
as it does for a radio's own report. A client that sends more than a request's worth without
finishing one, or leaves more than a megabyte of replies unread, is hung up on.

**A failure says what to do.** When another program holds the port, or the system won't let the app
listen there, the status says so in the app's language and suggests what to try; any other network
error shows the system's text. A bind that fails for a reason other than the network is a bug. It is
reported, still shown, and not retried.

**Browsers are turned away.** A web page open in the operator's browser can POST to
`localhost:<port>` without asking, and a line-based protocol would read each line of the body as a
command, so any page could retune the radio. flrig refuses a request carrying an `Origin` header;
browsers always send one on a POST, and no flrig client does. rigctld, N3FJP and HRD's text form hang
up when a connection's first line is an HTTP request line, which none of their clients ever sends.
HaLo's peer link refuses browsers for the same reason.

Web cannot listen, so the section is hidden there and the socket stub throws.

## Spectrum

A radio's panadapter and waterfall, drawn in an extension's scene panel
([panel-scenes.md § Spectrum](panel-scenes.md#spectrum)).

**The sweeps never cross the extension bridge.** A sweep arrives up to thirty
times a second with hundreds of points; pushed through `render` as artwork,
every one would re-validate and re-draw a whole scene. So a driver streams
`SpectrumFrame`s in Dart (`spectrum.dart`), the host paints them, and the
extension only places the control and reads or sets the radio's scope settings
(`readRadio().spectrum`, `setRadioSpectrum`).

**The scope runs only while a display that is seen listens.**
`CatService.spectrumFrames(uuid)` is a broadcast stream: its first listener
calls the session's `startSpectrum`, its last one leaving calls
`stopSpectrum`, and a pane behind another dock tab or a hidden app does not
listen. On a serial line a sweep nobody draws is most of the bandwidth the VFO
and the keyer share. The stream outlives a reconnect, so a display keeps
drawing when the radio drops and comes back. Sweeps are never
`EquipmentState` — they would wake every listener of the station thirty times
a second — but the scope's settings and its problem are, and both are cleared
when it stops: what a stopped scope was set to is not what it is, since the
radio's own knob moves it while nothing listens. `setSpectrum` on a stopped
scope answers false, and the host API says `stopped`, rather than queueing a
change for whenever a display next opens.

Levels are dB on the radio's own scale — not calibrated dBm — with a drawing
floor and ceiling reported by the radio or estimated locally. A display maps
that range to its height and an operator's contrast moves from there.

### Elecraft K4 (LAN TCP 9201)

The K4 Ethernet pairing opens a separate spectrum connection to the same
host on port 9201 while a visible display listens. It receives passively,
decodes checksum-verified main-pan `A` frames, and closes when the last
listener leaves or the CAT session stops. Failed or stalled spectrum links
retry independently; they do not disconnect CAT or interrupt keying.

The packet's center and sample rate place its 2048 ascending bins. Its
center can stay fixed while VFO A moves, so the VFO only places the receive
marker. Local zoom selects actual bins and reports their frequency endpoints;
it never stretches the entire sampled width into the chosen visible span.
Zoom is bounded by the available samples. The K4 controls which source
window is available; HaLo sends no pan-center or span CAT commands.

Reference adjustment and sweep-speed controls are local to HaLo. The
existing noise-floor estimator supplies a drawing range, without claiming
to reproduce the radio's AutoRef or calibrated dBm. USB spectrum, sub/mini-pan
display and remote services on 9204/9205 are not part of this pairing.
See [k4-cat.md](k4-cat.md) for wire fixtures and hardware evidence.

### Elecraft KX3 (stereo I/Q audio)

The named KX3 pairing can opt into local stereo I/Q capture on every HaLo
platform: macOS, Windows, Linux, Android, iOS and web. CAT
continues over its existing serial connection; a visible spectrum opens the
explicitly selected audio input, and the last listener leaving releases it.
An audio failure reports a spectrum problem without interrupting CAT/keying.
There is no audio permission retry loop: reopen the display after fixing the
input or permissions. Nothing is recorded to a file.

The source must supply two channels at the selected 48/96/192 kHz rate.
Native capture rejects mono inputs, missing devices and mismatched rates;
it never substitutes the default microphone or upsampling for RF bandwidth.
Web capture validates the browser-delivered track and worklet channels;
browser APIs cannot attest the physical ADC clock. Mobile and web users
grant access through the input selector before choosing the interface.
The complex FFT labels its bins around the last CAT dial plus the operator's
center correction. I/Q swap, zoom, reference and sweep speed are local.
Tuning discards FFT history while preserving stereo frame alignment.

KX3 RX SHFT, mode and passband choices need hardware calibration against a
known signal. HaLo neither guesses these offsets nor manipulates radio
menus to read them. The PX3's buffered I/Q output can supply the same audio,
but its serial screenshots cannot supply a live waterfall. Stock KX2 has
no external I/Q output. See [kx3-panadapter.md](kx3-panadapter.md) for wiring,
source references and the remaining hardware validation.

### Icom (CI-V `0x27`)

The IC-705/7300/7610/7760/9700/905/7850/7851 entries pin `civScope`. Captured from an IC-705 over
WiFi:

- Over the network a sweep is one `27 00` frame — `00, receiver, division 1 of
  1, mode, center (5 BCD), span (5 BCD), out-of-range` and 476 amplitude bytes
  0–160 — four a second at slow speed, thirty at fast. A serial radio splits it
  into divisions; `CivScopeAssembler` puts them back and drops a sweep with a
  gap rather than drawing two halves of different ones side by side.
- **A sweep is never an answer.** It repeats the scope's command byte, and the
  session's one-command-on-the-wire discipline frees the wire on an answer: a
  sweep taken as the answer to a pending scope read would release a burst the
  radio drops.
- The data output (`27 11`) is switched on with the display and off with it.
  The scope itself (`27 10`) is the radio's own screen, so it is turned off
  again only if the display turned it on. The output is sent again after the
  scope is turned on, because whether turning it on resets the output has not
  been pinned down.
- **Requires CAT at 115200 bps.** At fast speed the sweeps alone are ~15 kB a
  second over the network; on a much slower line they would leave little room
  for the VFO, the TX watch and the keyer. The network pairing has no line to
  budget, and the registry hands a driver no baud rate its transport has no
  field for — a node switched from serial to WiFi keeps the one it had in its
  config, and with it a meter cadence paced like a 19200 cable.

### Flex: mirrored through DAX IQ

This app is a non-GUI client bound to the GUI client that owns the slice.
Captured on a FLEX-6600 (4.2.20) with AetherSDR as that client:

- A bound client receives every `display pan`/`display waterfall` status and
  none of their FFT or waterfall packets.
- Its `display pan create` is answered with ids, but the pan belongs to the
  GUI client, brings a slice with it, and appears in the GUI client's window.
  Its data still goes there.
- DAX IQ does reach it. `flex_spectrum.dart` assigns a free channel (1–4) to
  the slice's pan — or uses the one it already has, which is then someone
  else's to keep — opens `stream create type=dax_iq`, and computes the
  spectrum locally (`spectrum_fft.dart`). On stop it removes the stream and
  hands back a channel it assigned.
- The stream's status line arrives **before** the `stream create` reply, and
  carries its rate; it is held until the reply names the stream. A reply that
  arrives after the display stopped, or the slice moved pans, is handed
  straight back. A refused stream gives its channel back, says why, and is not
  asked for again until the display or the pan changes — pan statuses arrive
  several times a second.
- The DAX decimation filter rolls off the outer sixteenth of each side —
  measured, 30 dB down at the edge and flat a sixteenth in — so that much is
  cut, and the spans offered are the half-widths actually shown (±10.5, ±21,
  ±42, ±84 kHz for 24–192 kHz streams).
- The window is the app's to place (`SpectrumCapabilities.canRecenter`): a
  `SpectrumRequest.centerHz` sends `display pan set <pan> center=`, which a
  scene's `follow` uses. The IQ is centred on the slice's pan, so this moves
  the operator's SmartSDR panadapter too — one window, not two that disagree.
  The new centre is applied locally at once: the radio may not echo the change
  to the client that made it, and every sweep is placed by it. A refusal puts
  the old centre back, or every sweep after would be labelled where the IQ is
  not.

Mirroring shows the operator's own panadapter, which is what a logger beside
SmartSDR or AetherSDR wants. A slice no client owns — HaLo alone on the radio
— would instead need HaLo to be the GUI client: its own multiFLEX station,
pan and slice, with the radio's FFT. That session mode does not exist yet.

## SDR receivers

A receive-only SDR — an RTL-SDR or Nooelec NESDR, an SDRplay RSP, an Airspy —
as equipment of its own category (`kCategorySdr`), listed under Other
Equipment and offered only while `EXP SDR` is on (stored as `fall`). With it
off, a linked SDR already in the station draws nothing and the radio shows its
own scope; the scene's source reads the experiment live, as `readRadio` does,
so both follow a toggle together. It exists to be a spectrum source: it has no
VFO, nothing logs from it, and nothing tunes it but the app.

**It draws a radio's spectrum, not its own.** Its config links it to a radio —
a specific node, or whichever is Main (`sdrRadio`). `CatService.spectrumNodeFor`
answers "where does this radio's spectrum come from" in one place, for the
scene control (`CatSpectrumSource`) and for `readRadio().spectrum` and
`setRadioSpectrum` alike: a linked SDR when there is one — it wins over the
radio's own scope, since linking it is the operator saying which picture they
want — otherwise the radio. An SDR the operator disconnected hands the radio
its own scope back; one that failed to connect does not, and says why, so the
picture does not swap each time a server comes and goes. The dial marker, overlays and a scene's `radio.`
values still read the radio, so no extension needs to know an SDR exists.
An SDR no display has connected reports its spectrum as waiting (or the
reason it could not connect) rather than absent, so a panel that shows its control only for a radio with a spectrum
still shows the one display that connects it.

**Two ways to wire one** (`sdrTuning`):

- *Its own antenna*: the app tunes it to the linked radio's dial and may place
  its window (`canRecenter`). In fixed mode it moves only when the dial leaves
  the window, so a panel's `follow` places it with margins and is not fought
  over; in center mode it sits on the dial, retuned at most four times a
  second. An upconverter's oscillator is a frequency offset added to what the
  device is told and never to a label.
- *The radio's IF output*: tuned once to the IF, and every sweep is relabelled
  around the dial, mirrored for an inverted IF. Its window is the radio
  mixer's, so it cannot be recentered.

The session reads the linked dial through its sink (`SdrSink.linkedVfoHz`) on
each sweep: a driver never reaches into app state, and a sweep is when the
dial is needed.

**Connected only while a display wants it.** An rtl_tcp server streams for as
long as a client holds it — megabytes a second, with no pause command — and
serves one client at a time, so an SDR held open idle wastes the link and
locks every other program on the station out of the dongle. The first display
connects it, it is let go a few seconds after the last one leaves, and a
failed connect or a drop is retried after a pause while a display waits. The
operator overrides both ways: their Connect keeps it connected with no
display, their Disconnect keeps it off. A release is neither.

One function, `_settleSdr`, makes every one of those decisions, from the state
as it is when called — on a display arriving or leaving, at the end of every
connect and disconnect, and from its timers. While a connect, a release or an
edit of the SDR is under way it does nothing, and each settles it again as it
ends: a display that comes and goes before a connect has said `connecting`
would otherwise start a second one, which supersedes the first on a server
that takes one client. Any edit to an SDR's setup reconnects it, since the
session reads it all at the start. Its connects skip the auto-connect crash
mark, which guards a native open that can wedge the process — a socket
cannot. Its IQ is kept out of the CAT
traffic log, which a few megabytes a second would fill in moments.

**The samples are mostly thrown away.** `SdrSpectrum` converts one FFT window
per sweep — a few thousand samples out of millions a second — and skips the
rest unread. After every retune or rate change it discards a tenth of a second
of IQ, which belongs to the old setting and drawn at the new one smears a
signal sideways. The DC spike every zero-IF receiver has is removed from the
middle bin, where the dial marker sits in center mode.

**rtl_tcp** (`rtl_tcp_driver.dart`) opens with `RTL0`, the tuner type and its
gain count, then streams unsigned 8-bit I/Q; commands are five bytes, never
answered. SDRplay's rsp_tcp speaks the same protocol. None of this has been
on the bench: the edge trim, the settle time and rsp_tcp's rates are
untested assumptions, and `equipment_models_sdr.dart` says so.

Still to come: SpyServer (Airspy and RTL-SDR over the network, with the
server computing the FFT), and USB on desktop through the vendors' libraries
— libairspy and libairspyhf bundled, SDRplay's API installed by the operator.
An RTL-SDR has no USB path: librtlsdr is GPL-2.0, and a sandboxed macOS app
cannot load a copy the operator installed.

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

### The LAN-port Icoms: the IC-705's protocol, unproven on them

The IC-7300 MK2, IC-7610, IC-7760, IC-9700, IC-905, IC-7850 and IC-7851 are listed with the same
RS-BA1 server function as the IC-705 in Icom's RS-BA1 guide (A7463-2EX-8), and each has a network
variant on the same transport. None has been connected. Each pins the network controller address
0xE1 and prefills its factory CI-V address — a prefill rather than the IC-705's pinned A4, because
CI-V ADDRESS is in each radio's menu and nothing shows the network ignores it.

Every network entry, the IC-705's included, takes the radio's **Control Port** and **Serial Port**
(UDP) as fields named after the radio's own menu, prefilled with the factory 50001 and 50002. Both
can be changed on the radio, and a radio reached from outside its network is forwarded to on
whatever ports the router gives it. A node saved without them connects on the factory port, which is
what every such node always did; in the editor, a cleared or unparseable port, a fractional one and
the same port for both are refused rather than replaced by a guess. The list row names the control port only
when it is not 50001, so two radios behind one router read differently. The audio port is not a
field: the radio's audio port is never addressed, and the one the stream request names is our own.

The radio names itself. Its unsolicited `0xa8` carries, after the stream token at 66, a 32-byte
zero-padded name at 82 (`IC-705` on the capture; then `ICOM_VAUDIO` at 114 and the CI-V address
at 148), and the `0x90` stream request sends that name back in the same field. So nothing
hardcodes a model name, and a renamed radio is still named the way it named itself.

What would break first, from what only the IC-705 has shown:

- **The capabilities layout.** Read at the IC-705's offsets. The packet is matched by type 0 and a
  length header that agrees with the datagram, at 168 bytes or more — its first byte, `a8`, IS the
  length, so a match on it would take only 168. What is read (length, name, CI-V byte) goes to the
  log, the one trace of a layout that differs.
- **A scope sweep over the network** was seen as one division on the IC-705. Icom's IC-7850/7851
  firmware notes say a sweep's fifteen divisions arrive together over the LAN, which
  `CivScopeAssembler` reassembles like a serial radio's.
- **The IC-905's 10 GHz band** takes six-byte frequencies (its CI-V guide, A7711-9EX-2:
  "When the 10 GHz band is selected, the number of digits is 12"). `encodeBcdFrequency` writes six
  from 10 GHz up. The sweep header's frequencies are six bytes there too, and the assembler reads
  five, so from 10 GHz up the session draws no sweep and says the band cannot be shown. Whether the
  header's second frequency also grows is not in the guide.

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
