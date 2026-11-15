# The station model: devices, capabilities, positions

Status: proposal (HALO-947). Only what a device offers and how it is addressed is built (§ 4.1 to
§ 4.3, phase 2 of § 11); the rest is in the order § 11 gives. What is built today is otherwise in
[cat.md](cat.md), and this document changes none of the rules there about transports, drivers,
framing or cancellation.

A station is configured once as a list of **devices**. Each device **offers capabilities**: a
receiver, a transmitter, a scope, an audio channel, a keyer, a switch port, a rotator. The parts of
the app that need one of those pick among the capabilities every device offers, never among the
devices. An **operating position** links a set of capabilities into something an operator sits at,
and a **logging set** says which position's receiver an entry logs from.

## 1. Why

One configured thing offering several things to the app already exists four times, built four
ways:

| Where | How it is done today |
| --- | --- |
| FlexRadio slices | One equipment node per slice, each with its own TCP connection, told apart by a `slice` config field. SO2R recognizes "two nodes at one address" to offer the radio's own audio switching |
| Elecraft K4, secure link | One node per receiver (`receiver: main` or `sub`), over one pooled connection, each a facade on a shared session (`K4SharedSession`) |
| Green Heron Everyware | A server node, and a child node for each rotator or switch it announces, each riding the server's one socket |
| A linked SDR | A node of its own whose config names the radio it draws the spectrum for (`sdrRadio`) |

And what links one piece of equipment to another is a set of separate pointers, each with its own
storage and its own rules: `mainVfo` (radio1), `radio2`, the `radio → category → uuid` table of
antenna and key picks, `so2rSwitch`, the per-radio voice keying source, `spectrumNodeFor`, and the
`operatorRadio` global that says which radio the keys act on.

Each was the right local answer. Together they mean a new kind of equipment needs a new mechanism,
and a question like "which antenna is this contact on" has a different answer path for each
combination. [data-model.md § Stations](data-model.md#stations) already describes ports and
operating positions, and marks them not built. This is that design.

## 2. Vocabulary

- **Device**: one configured piece of equipment. What it is, how the app reaches it, and the
  connection parameters. Today's `EquipmentNode`.
- **Capability**: one thing a device offers, with an address, options and live state of its own.
- **Position**: an operating position. Named slots, each pointing at a capability.
- **Logging set**: a set of logging fields, A or B ([logging-fields.md § SO2R](logging-fields.md)),
  bound to one receiver of one position.
- **Wiring**: which port is fed by which, for the antenna side of the station (§ 7).
- **Logical address**: how the rest of the app names any of these by role, such as "set A's
  scope" or "the first rotator" (§ 8).

"VFO" names what a position works, not what a device offers: a transmit frequency, a receive
frequency when it differs, and a mode. That is what `vfoA` and `vfoB` already are in
`RadioService`. A device offers receivers and transmitters, and a position makes a VFO of them.

## 3. Devices

A device is the inventory entry: one row in Station Configuration, one model from the catalogue,
one transport, one set of connection parameters. Everything
[cat.md § Transport ≠ driver](cat.md#transport--driver) says about models, variants, persisted
type keys and secrets holds unchanged.

**A device owns its connections, and its driver decides how many.** One is the rule, because most
equipment takes one client or behaves badly with two. A driver opens more where the equipment
gives it a reason: a FlexRadio whose slices belong to two GUI clients, since a connection binds to
one of them, or a stream that travels apart from the commands. However many there are, they are
the device's: they come up and go down together, and the operator sees one row with one status.

**The computer is a device.** It is always there, is never added or removed, and has nothing to
connect, so it is not in the stored list and its address is the fixed word `computer`. It offers
each sound card the system lists as an `audio` capability, the app's own `audioMixer`, and the
recordings of [the computer's voice keyer](cat.md#the-computers-voice-keyer) as a `voice`. A sound
card is not a device of its own: the operator never says how to reach one, which is what a device
is for. A card that is unplugged is a capability its device says it does not have (§ 4.3), and a
slot pointing at it keeps its pick.

What changes is that a device is no longer also "the radio". A FlexRadio is one device however
many of its slices the station uses, an Everyware server is one device however many rotators hang
off it, and a K4 is one device with two receivers.

## 4. Capabilities

### 4.1 Kinds

| Kind | What it is | Examples |
| --- | --- | --- |
| `rx` | A receiver: a frequency, a mode, a passband, receive levels | A Flex slice, the K4's Main or Sub, an FT-891's receiver, an RTL-SDR |
| `tx` | A transmitter: power, PTT, the meters while keyed, the tuner | One per transceiver. A Flex has one, riding whichever slice holds the TX flag |
| `scope` | A spectrum and waterfall for a receiver | An IC-705's scope, a K4 panadapter, anything computed from an `iq` |
| `iq` | A stream of IQ samples | Flex DAX IQ, TCI, an SDR |
| `audio` | A source of audio, a sink for it, or both, with its channels addressed under it | A sound card, a USB microphone, a Flex slice's audio and its `dax_tx`, the K4's and the Icoms' network audio |
| `keyer` | Something that sends CW | A radio's own keyer, a Winkeyer |
| `voice` | Voice memories held in the equipment | A radio's DVK |
| `switch` | Routes its inputs to its outputs | An Antenna Genius, a Flex's or an Icom's own antenna ports |
| `rotator` | Points an antenna | One per rotor on a controller or a server |
| `audioMixer` | Combines audio channels and routes them to stereo and mono outputs | The computer's own, a Flex across its slices |
| `so2rController` | Sits between two radios and one operator: which radio the headphones hear, and which one the key, the PTT and the microphone reach | An OTRSP box: a YCCC SO2R Box, a RigSelect Pro |
| `antenna`, `key` | A thing with no connection, there to be picked and credited | A dipole, a paddle |

The list is open, as the category strings are today. A kind exists when some slot picks it.

A radio's own antenna ports are a `switch`, the same kind an external switch offers. `RadioAntennas`
already carries a radio's receive and transmit ports and whether it picks them separately; the one
difference from an Antenna Genius is that a radio's switch outputs are wired inside it, to its own
receivers and transmitter, where an external switch's are wired by the operator (§ 7).

An `audio` says which channels it has in each direction, and either may be none: a microphone or
a receiver's audio only arrives, a speaker or a transmitter's modulation input only leaves, and a
sound card usually does both. The direction is the app's: `in` is audio the app receives and `out`
is audio it sends, so a channel is `…/audio:<name>/in:0` or `…/audio:<name>/out:0`. A slot that
needs one direction offers only what has it. A position's receive audio is picked among `in`
channels, and its transmit audio and the headphones among `out` channels.

What devices offer:

| Device | Offers |
| --- | --- |
| FT-891 | 1 `rx`, 1 `tx` (which may transmit off the receive frequency), `keyer` |
| IC-705 | 1 `rx`, 1 `tx`, 1 `scope`, `keyer`, `voice`, network `audio` |
| K4 | 2 `rx`, 1 `tx`, 2 `scope`, `keyer`, `voice`, audio, a `switch` |
| FLEX-6600 | An `rx` per slice, 1 `tx`, a `scope` and an `iq` per panadapter, audio per slice, an `audioMixer`, `keyer`, `voice`, a `switch` |
| Antenna Genius 8x2 | 1 `switch` with two outputs |
| OTRSP box | 1 `so2rController` |
| Everyware server | A `rotator` per rotor, a `switch` per switch |
| RTL-SDR | 1 `rx`, 1 `iq`, and so 1 `scope` |
| The computer | An `audio` per sound card, an `audioMixer`, a `voice` (its own recordings) |

### 4.2 Addresses

A capability is addressed as `<device uuid>/<kind>:<key>`, where the key is the equipment's own
name for it: `…/rx:0` for a Flex slice, `…/rx:sub` for the K4's sub receiver, `…/rotator:Tower 1`
for a rotor as its Everyware server names it. A switch's ports are addressed under it
(`…/switch:ant/in:ANT1`, `…/switch:ant/out:A`). Never an index into a reported list, for the reason
`AntennaSwitchSession.selectAntenna` gives: equipment that numbers from one or leaves a gap is
silently mis-addressed.

**A bare device uuid means the device's first receiver**, or the one thing a device with no
receiver offers: a rotator's uuid is its rotator. The transmitter that goes with that receiver is
the same device's `tx`, asked for by its own address.
Today a node's uuid is "the radio" in extension calls (`listRadios`, a scene's `radio`), in peer
offers, in the VFO store's keys and in the pick table. Kept as an alias, none of those change
meaning for a one-receiver radio, which is nearly every radio.

Addresses are persisted wherever a slot holds one, so a key that changes follows
`renamedTypeKeys`'s rule: a forwarding entry, applied on read, permanent.

*Status: built — `CapabilityAddress` in `app/lib/services/cat/capability.dart`, resolved by
`CatService.resolveCapability`. A remote K4's Sub and an Everyware server's rotors and switches
are entries keyed by their address (`<K4>/rx:sub`, `<server>/rotator:Tower 1`), which slots
hold like any node id; every other entry is still its device's bare id.*

These are **physical** addresses: which piece of which device. Slots and wiring hold them, and
nothing else should. The rest of the app asks by role (§ 8).

### 4.3 Offered before connecting, corrected by the equipment

A driver answers "what does a device configured like this offer" from the configuration alone,
the way `canKeyCwWith(config)` and `telemetryMetersWith(config)` already answer without a session.
A picker has to work with the radio switched off, and a position has to keep its slots across a
power cycle.

The equipment then corrects it: a Flex says how many slices its model runs and which exist, an
Everyware server announces its devices one at a time. What it said last is kept on the device
(as `everywareKnownDevices` is today) so a pick survives the equipment being away. A capability a
slot points at that the equipment says it does not have is a **problem** in
[cat.md's sense](cat.md#drivers-never-touch-app-state): connected, answering, and unable to do what
was configured. It is never a connection error, and never silently re-pointed.

*Status: built — `EquipmentType.offers` and `offersWith` in `capability_offers.dart`, for the kinds
a node can be picked as today: receiver, transmitter, scope, keyer, voice, switch, rotator, audio
mixer, SO2R controller, antenna and key. A node offers what it is now, so a Flex node offers its own
slice and no other, and a receive-only SDR offers its scope and no receiver until something can tune
it as one. A device's editor lists what it provides, by name and without the
receiver and transmitter every radio has. A radio's own antenna switch is
offered only once the radio has named its ports, and goes when it is switched off: keeping what a
device last said is not built.*

### 4.4 Options and state

Each capability has what `EquipmentState` holds today, divided by what it describes: the frequency,
mode and passband on the receiver; power, transmitting, meters and the tuner on the transmitter;
the heading on the rotator. The connection's own status, error and staleness stay on the device.
Options the operator sets for one capability are stored under it on the device. Live state is
never stored ([cat.md § Persistence](cat.md#persistence)).

### 4.5 Followed or owned

A capability is one or the other, and says which:

- **Followed.** The equipment, or another program controlling it, holds the truth, and the app
  mirrors it and asks for changes: an FT-891's dial, a slice SmartSDR or a Maestro holds, a
  panadapter another client owns. All of [cat.md § The VFO, in both
  directions](cat.md#the-vfo-in-both-directions) is about this case.
- **Owned.** The app holds the truth and the equipment is told: an SDR's tuner, a scope computed
  here from an IQ stream, a slice and panadapter the app creates as the Flex's GUI client
  (HALO-766).

The same distinction applies to a link between two capabilities (§ 5.3).

### 4.6 Derived capabilities

A `scope` can be computed from an `iq`. Flex DAX IQ, TCI and the SDR drivers each do this now
through `spectrum_fft.dart`. As a rule of the model it is said once: a device that offers an `iq`
offers a `scope` on it, owned by the app.

### 4.7 Sharing

A capability declares how many slots may hold it:

- **Exclusive**: one position at a time. A receiver, a key (two keyers on one key stop each
  other's messages) unless an SO2R controller routes it (§ 6.1), an antenna on a switch that
  connects it to one output.
- **Shared, one at a time**: a transmitter two positions use by taking turns. This is the existing
  turn-taking (`KeyingStation.clearToSend`), which two slices of one Flex already need.
- **Shared**: a rotator, a scope's display.

A picker shows as taken what another position holds exclusively, and picking it takes it from that
position. The radio pickers do this now, marking each set's radio with the set's letter. That
replaces the separate refusals in `setRadio2` and `setDesignated`.

## 5. Positions

### 5.1 Slots

```yaml
positions:
  <id>:
    name: Left
    rx:     { from: <flex>/rx:0, antenna: <yagi>, audio: … }
    tx:     { from: <flex>/tx,   antenna: <yagi>, frequency: same }
    rx2:    { from: <flex>/rx:1, antenna: <beverage>, audio: …, follows: rx }
    scope:  <flex>/scope:0
    key:    <winkeyer>/keyer
    voice:  <flex>/voice
    rotator: <everyware>/rotator:Tower 1
```

Only `rx` is required. **Every other slot defaults from the receiver's own device**: its
transmitter, its scope, its keyer, its audio. Picking "IC-705" for `rx` is a whole position, and a
one-radio station configures nothing more than it does now.

A slot keeps the three states the pick table has today
([cat.md § The picks belong to the radio](cat.md#the-picks-belong-to-the-radio)): **absent** takes
the default, **null** is the operator's None and outranks it, anything else is their pick.

Explicit picks are what make a mixed position: an FT-891 for `rx` and `tx`, one of the computer's
sound cards for its audio, and an SDR on its IF output for `scope`. A panel then draws "the
position's scope" and plays "the position's audio" without knowing three devices are involved.
`spectrumNodeFor` and `designatedFor` become one question: what does this slot resolve to.

### 5.2 One receiver or two, one frequency or two

| Configuration | How the position says it | Frequencies | Audio channels |
| --- | --- | --- | --- |
| Simplex | `rx`; `tx.frequency: same` | 1 | 1 |
| Split, one receiver | `tx.frequency: own` | 2 | 1 |
| Split, hearing both sides | as above, and `rx2` with `follows: tx` | 2 | 2 |
| Dual watch (main and sub) | `rx2` with `follows: none` | 2 | 2 |
| Diversity | `rx2` with `follows: rx`, on a different antenna | 1 | 2 |

All five have **one logging set**: the second receiver is there to be listened to. A second
receiver that logs is SO2V, which is a second set (§ 6), not a sixth row.

The position's VFO carries the transmit frequency, the receive frequency when `tx.frequency` is
`own`, and the mode. A contact logs the transmit frequency as its own and the receive frequency
as the other station's, which the log format already has a place for.

### 5.3 Who keeps a link in step

`follows`, and `tx.frequency`, are links between two capabilities, and a link is followed or owned
like a capability is (§ 4.5):

- **The equipment keeps it** when both ends are one device's and it has the mode itself: a K4 in
  diversity, a radio's own split. The driver sends the equipment's command and mirrors the result.
  A device declares which links it keeps (§ 4.3), and its constraints with them, such as a
  diversity pair needing two front ends.
- **The app keeps it** otherwise, retuning the follower itself. A linked SDR following the dial is
  this already (`sdrTuning`).

Two unrelated receivers the app keeps on one frequency are two antennas in two ears. They are not
phase-coherent, and the app does not call that diversity.

### 5.4 Antennas belong to a slot

A position has a transmit antenna and a receive antenna, usually the same and sometimes not, and a
second receiver has its own: diversity is two receive antennas at once. So the antenna is on `rx`,
`tx` and `rx2`, and `rx` and `rx2` default to `tx`'s.

What a slot stores is **the antenna the operator wants**, never a port or a switch position. § 7
says how that becomes relay settings.

### 5.5 What moves with a position

Everything the app keeps per radio today moves to the capability it describes, so it follows the
equipment and not the role: the band memory and the echo guard to the receiver, the keyer speed to
the keyer, voice memory names and lengths to the `voice` capability (they are stored per role, A or
B, today). The operating style and the run frequency belong to the logging set.

## 6. Logging sets

A set binds to one receiver slot of one position:

| Arrangement | Set A | Set B |
| --- | --- | --- |
| Single | position 1, `rx` | none |
| SO2V | position 1, `rx` | position 1, `rx2` |
| SO2R | position 1, `rx` | position 2, `rx` |

- **SO2V** needs `rx2` to follow nothing, and the position's one transmitter goes to whichever set
  is keying.
- **SO2R** is two positions, each with its own antennas, key and audio. Their transmitters may be
  two devices' or one shared by turns (§ 4.7).
- Two slices of one Flex can be either. They differ only in whether antennas, key and audio are
  per set or shared.

**A view acts on a set, and a set names its position and receiver.** The keyer, the VFO keys, the
operating style and the keying dialogs all ask the set of the view they are in. Nothing reads a
global for it, which is what `operatorRadio` is today, and what goes stale when a view stays
mounted under another.

A contact records the rig, antenna, key and power of its set's position, as a contact on Radio B
does today.

### 6.1 What belongs to the operator, not to a position

One operator has one pair of ears, one key and one microphone, however many positions they work.
Two things are therefore picked for the arrangement of sets, beside the positions:

- **What the operator hears.** One rule decides it, from the set in focus, the stereo setting and
  which radio is on the air (`wantedSo2rAudio` today). An `audioMixer` carries it out, taking the
  receivers' audio channels and routing them to the headphones. The same mixer puts one position's
  `rx` and `rx2` in separate ears (§ 5.2), and feeds any mono outputs: a recorder, a decoder, a
  stream to a remote operator. A Flex is a mixer over its own slices (their pan, mute and gain),
  and the computer's is one over every sound card it has.
- **Which radio the key, the PTT and the microphone reach.** An `so2rController` routes all three
  to the radio that is transmitting, so one key and one microphone serve both positions. It also
  switches the headphones itself, in the few fixed ways its box has, and where one is picked it
  carries out the hearing rule in the mixer's place. Without a controller each position keys
  through its own `key` slot.

A mixer or a controller that another hand can move is followed (§ 4.5): told on a change and never
on a timer, and given back as the operator had it when the switching stops, as
[cat.md § The SO2R switcher](cat.md#the-so2r-switcher) has it for both today. The app's own mixer
is owned.

Only a controller's headphone switching is driven today. Its transmit side is new work (§ 11).

## 7. Wiring, and the antenna graph

The station's antenna side is a graph: antennas, switches (a radio's own included), and later
filters, amplifiers, splitters and stack matches, joined by "fed by" edges from one port to
another.

```yaml
wiring:
  - { port: <flex>/switch:ant/in:ANT1,          fedBy: <genius>/switch:main/out:A }
  - { port: <genius>/switch:main/in:3,          fedBy: <yagi> }
```

With it the app can:

- find the combination of switch settings that connects a given antenna to a given slot, and set
  them;
- say which antennas a position can reach, on a band, right now;
- read which antenna a slot is on from the switches' live state, where the operator changed one by
  hand.

**The graph and its solver are a late phase (§ 11).** What the early phases owe it, so that it
arrives without a second migration:

1. **A port has an address as soon as the equipment names it**, from the first phase: a radio's
   own jacks, and both sides of every switch. The one jack of a radio that names none has to be
   given a name before an edge can be stored against it, which is the graph's own work.
2. **A slot stores the antenna wanted** (§ 5.4). Until the graph exists that is a plain pick, as
   now. When it exists the same stored value is what the solver routes to.
3. **Edges are their own list**, not config on either end. Which of the operator's antennas is on
   a switch port is in the switch node's config today, and moves there. An edge is a record, so it
   can later carry a limit of its own, such as the bands a filter passes.
4. **One switch interface.** Internal and external switches report routes as output-to-input pairs
   and take "connect this output to this input", with `selectAntenna`'s refusal under RF.
5. **One resolver.** A single function answers "which antenna is this slot on": the pick at first,
   a walk of the graph later. The antenna a contact credits, and every panel, ask it.

Reserved and not built: the bands an antenna covers (a node holds only its type today), contention
between positions for one antenna, which of a switch's inputs can reach which of its outputs (a
radio's receive-only port reaches its receiver and never its transmitter, which `RadioAntennas` says
and a `switch` capability does not), and which rotator turns an antenna. With that last edge a
position's rotator is found from the antenna it is on, and changes when the antenna does; until then
`rotator` is a slot like the others.

## 8. Logical addresses

A capability's address (§ 4.2) is the binding itself, and belongs in a slot. Everything else, a
panel, a layout, a command, a key binding, an extension, asks **by role**, and the answer is worked
out when it is used:

- Re-pointing a position's receiver re-points everything that showed it, with nothing else to
  edit.
- A layout file or a control board travels to another station
  ([layouts.md § Layout files](layouts.md#layout-files)), where none of this one's uuids exist.
- Rotators, switches and the like are shared between positions, and "the second rotator" has to
  be the same one in every panel.

| Form | Means | Examples |
| --- | --- | --- |
| By set | A slot of the position a logging set is bound to. A bare `set` is the set in focus in the view that asks | `set/scope`, `set:A/rx`, `set:B/tx/antenna` |
| By position | A slot of a position, by its number in the owner's order | `position:2/key` |
| By operator | What belongs to the operator (§ 6.1) | `operator/mixer`, `operator/controller` |
| By order | The nth capability of a kind, in the owner's order | `rotator#1`, `switch#2` |
| By tag | The capabilities carrying a tag the owner gave them | `tag:rotA`, `tag:tower` |

One resolver answers all five, and a physical address passes through it unchanged, so anything
that takes one takes the other. A panel pinned to one particular device still can be.

`set:A/rx` is the receiver set A logs from, which is its position's `rx2` under SO2V: an address
by set never has to know the arrangement. That is the address behind "a view acts on a set" (§ 6).

### 8.1 The owner's order

Station Configuration lists the capabilities of each kind in an order the owner sets, across
devices: an Everyware server's first rotor, then a GS-232, then the server's second. It is stored
as the station's, and what is not in it yet comes after, as it was added or announced.

Every list the app hands out is in that order: a picker, an extension's `listEquipment`, a form's
`$core.rotators`. So a panel that shows "the rotators, in order" needs nothing set up for it, and
`rotator#1` is the first of them. Positions have an order of their own, which `position:1` reads.

*Status: the order is the station's list as configured: what was added first comes first, and a
device's entries sit together, a K4's Sub right after its Main and an Everyware server's rotors
and switches after the server. Every picker and `listEquipment` read that list. An order the owner
sets apart from it is not built.*

### 8.2 Tags

*Status: not built. Tags come with the by-tag addresses that read them, in the extension
surface (§ 11, phase 10).*

An order says first and second. A tag says **which**, where the role matters more than the place:
the tower's rotator, the receive loop's switch.

- A tag is an identifier (`rotA`, `tower`, `rxLoop`), as a scene's source name is. It is matched,
  never shown; a capability's name is shown, and can be anything.
- The owner gives a capability any number of tags, in Station Configuration. They are stored with
  the capability's options, on this device like the rest of the equipment.
- A tag on several capabilities resolves to all of them, in the owner's order. Asked for one, it
  is the first.
- A tag names a role in the station, never an extension. An extension's page says which tags it
  looks for ("tag your rotators `rotA`, `rotB` and `rotC`"), and two extensions that mean the same
  thing by `rotA` share it.

### 8.3 An address that resolves to nothing

It reads as missing, as a scene's source does today for a device that is not there. A panel shows
its empty state. Nothing falls back to another capability: set B with no position keys nothing
rather than keying set A's radio, and `rotator#3` on a station with two rotators is not the second.

### 8.4 What extensions already say

`readRadio('A')` and `readRadio('B')` are `set:A` and `set:B`; a scene's `radio: null` is a bare
`set`; an id from `listRadios` or `listEquipment` is a physical address and goes on working. The
other forms are new surface, with the extension work (§ 11).

## 9. Persistence and migration

The equipment blob keeps its shape and its rules: one versioned JSON map, device-local, never
synced, no live status ([cat.md § Persistence](cat.md#persistence)). It gains `positions`, `sets`,
`wiring` and the owner's order of each kind (§ 8.1) beside the devices, and loses `mainVfo`,
`radio2`, `designated` and `so2rSwitch`. Tags (§ 8.2) are stored with each capability's options.

Station Configuration is in every release, so every step here runs on real stations:

| Stored today | Becomes |
| --- | --- |
| A node | A device, same uuid |
| `mainVfo` naming a local radio | Position 1 with that device's first receiver; set A on it |
| `mainVfo` naming a peer's radio | Position 1 with the peer's offered receiver, as now neither stored as a device nor editable |
| `radio2` | Position 2; set B on it. **SO2R on two positions, always**, two slices of one Flex included |
| `designated[radio][antenna]` | That radio's position's `tx.antenna`, and by default its receivers' |
| `designated[radio][key]` | That position's `key`, absent and null kept apart |
| `so2rSwitch` naming a box | The arrangement's `so2rController` |
| `so2rSwitch` set to the radio's own | The arrangement's `audioMixer`: that Flex's |
| An SDR's `sdrRadio` | The `scope` slot of the position holding that radio; "Main" becomes set A's |
| Several Flex nodes at one address | One device. Each old uuid forwards to that device's `rx:<slice>` |
| K4 nodes with `receiver: main` and `sub` | One device, under Main's uuid, which as a bare id is its `rx:main`. The Sub's uuid forwards to `rx:sub` |
| An Everyware device node | A capability of its server. The old uuid forwards to it |

*Status: positions and sets are built, as blob version 4 (`StationPositions` in
`station_positions.dart`, read and migrated in `cat_equipment_store.dart`), for the rows on
`mainVfo`, `radio2`, `designated` and `sdrRadio`. A position belongs to a radio, a node or a peer's
radio, and is made the first time something is picked for it; its slots hold node ids, not
capability addresses, until devices hold several capabilities (phase 4). `so2rSwitch` is still its
own key. Every save also writes `mainVfo`, `radio2`, `designated` and each SDR's `sdrRadio` in the
version 3 shape, so a build from before positions reads the same station, and its save migrates
back with the radios and their picks whole; an SDR moved there moves here too. They go once such
builds are out of testers' hands. What the move to one `scope` per position gives up: two SDRs
that named one radio leave the second nobody's scope, and one that followed "the Main radio" while
that was a peer's or none is nobody's. A build from before positions cannot show an SDR linked to
nothing, so saving that SDR's editor there makes it follow the Main radio again.*

*Status: the K4 and Everyware rows are built (`cat_devices.dart`): each old id that names
another entry now is stored under `forwarded`, applied on load to everything in the blob that
names a node, and by `CatService.nodeFor` to an id held anywhere else, a layout or an
extension's settings. Not a node's own settings: a K4's `k4ConnectionId` can be the old id of
a Sub configured first, and keeps naming its keychain entry. Flex nodes at one host and port are
one device under slice A's node, made from the address when none tracked slice A, each other
slice's node becoming `<device>/rx:<slice>`. A build from before this reads
every entry under its new id, as a node of its own, but saves without `forwarded`, so an old id
held outside the blob then names nothing. A peer that picked a K4's Sub by its old id finds it
gone, since what it holds is the id this station offered then.*

A forwarding entry from an old node uuid to a capability address is permanent, for
`renamedTypeKeys`'s reason: the record being read was written by a build with no upper bound on
its age, and the same uuid may sit in an extension's stored settings or a layout.

## 10. What changes in the code, and what does not

**Unchanged:** transports and drivers stay apart; Dart owns every connection, timer and frame;
a driver never touches app state and reports through its sink; cancellation, framing and the
per-connection guards; `CatService` as the only writer of CAT-sourced state.

**The device owns the connections, and each capability gets a session facade.** `K4SharedSession`
(one command owner, a facade per receiver) and the Everyware hub (one socket, a connection handed
out per device) are this already, written twice. A driver for a one-receiver radio needs no
facade: its session is the receiver's and the transmitter's both, as now. Where a device holds
more than one connection (§ 3), which capability rides which is the driver's business, and nothing
above it can tell.

**The FlexRadio driver is the large change.** One session per slice becomes one session for the
radio. It already hears every slice (`sub slice all`, and its `_slices` map), so much of the work
is routing reports and commands by slice rather than new protocol. It also removes the need to
recognize two nodes at one address. Slices held by two GUI clients take a connection bound to
each, both owned by the one device.

**`CatService`'s surface narrows to positions and sets.** `radio1`, `radio2`, `designatedFor`,
`spectrumNodeFor`, `vfoKeyFor` and `operatorRadio` become questions asked of a position or a set.
They can stay as thin readers through the migration: `radio1` has about 140 references in app code
and 190 in tests.

**Extensions and peers.** `listRadios` goes on listing what an extension means by a radio: a
receiver with its transmitter. Its ids keep working through the bare-uuid alias (§ 4.2). Naming a
capability, a position or a set from an extension is new surface, and takes an API level and its
pages in `docs/extensions/` when it is added. A peer goes on being offered a receiver and its
transmitter, never a device.

## 11. Phases

Each is a full task. Nothing is visible to the operator before phase 3.

1. **This document.**
2. **Capabilities under the existing surface.** Each catalogue entry declares what a node offers,
   from what its driver already answers without a session, and a test holds every declaration to
   the session the entry creates. Addresses exist and resolve, and developer mode lists what each
   device offers. No behaviour change, no stored change.
3. **Positions and logging sets.** They replace the pointers (§ 9's first nine rows), with the
   stored migration. Station Configuration's Current Transceivers band becomes the position
   editor. Views act on a set, through the resolver and its by-set and by-position addresses
   (§ 8). State is divided per capability (§ 4.4) as each reader of it moves to a slot.
   *Status: the stored positions and sets (§ 9), and the band as one block per set, with the
   SDR link as a position's `scope` slot, are built. Every view logs from set A, and under SO2R
   from A and B, as before; a view choosing its own set is not built.*
4. **Devices with several capabilities**, in two stages. The first: K4 and Everyware nodes
   merged with forwarding, and pickers listing capabilities across devices in the owner's order
   (§ 8.1). The second: one Flex connection for all its slices, its nodes merged the same way,
   and the radio picker listing the slices the radio has. The Flex and Everyware are verified on
   hardware, the K4 against fakes and captures only.
   *Status: the first stage is built, with the owner's order being the configured one (§ 8.1). Of
   the second, the Flex's nodes are merged into one device, and the radio picker lists the slices
   the radio has open, or last said it had while it is off; each slice still opens a connection
   of its own.*
5. **Split, a second receiver, diversity** (§ 5.2). New in the app's VFO, the drivers and the
   logging fields; nothing reads or sets split today.
6. **Owned receivers and scopes.** The Flex as its own GUI client (HALO-766).
7. **Audio and IQ as capabilities, and mixers.** A receiver's audio channels, the mixer that routes
   them (§ 6.1), and the computer's own. After the audio engine work (HALO-932) has settled what an
   audio channel is.
8. **An SO2R controller's transmit side**: routing the key, the PTT and the microphone (§ 6.1).
9. **The antenna graph and its solver** (§ 7).
10. **Extension surface** for capabilities, positions and sets, and logical addresses wherever an
    id is taken today (§ 8.4), with tags (§ 8.2).

Phases 5 to 10 do not depend on each other and can be reordered.

## 12. Open questions

- **When a Flex needs its second connection.** A non-GUI client binds to one GUI client, and the
  driver binds to the owner of its slice today. Two slices held by two stations (multiFLEX) get a
  connection each (§ 3). What one bound connection can and cannot do for a slice another client
  holds, and so exactly when the second is opened, is to settle by capture in phase 4.
- **Flex diversity and antenna constraints.** Which models run a diversity pair, and which slices
  share a receive antenna because they share a front end, are the radio's to report. Neither is
  verified on hardware.
- **Whether SO2V needs anything SO2R on one radio does not.** Two slices of one Flex migrate as
  SO2R (§ 9). SO2V as its own arrangement can wait until something needs antennas, key and audio
  shared between the two sets.
- **What names a sound card.** A slot stores a capability's key (§ 4.2), and a sound card's has to
  survive a replug, a reboot and a second card of the same model. What each platform offers for
  that is phase 7's to settle, with the audio engine's device list in hand.
- **Whether an extension declares the tags it looks for.** Named in its manifest with a line of
  description each, Station Configuration could offer them beside a capability instead of the
  owner copying them from a page. It is new manifest surface, and can wait for an extension that
  asks.
- **More than two positions.** The schema has a map of positions and two sets. A multi-operator
  station on one computer would need more sets, and is not designed here.
