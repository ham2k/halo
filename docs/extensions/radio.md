# Radio control

An extension reads and commands the operator's local radios through host
calls: what a radio reports, setting its frequency, mode, power and more,
keying it, running its scope, and, with the operator's leave, any command
in its own protocol. The station's antenna switches and rotators come under
the same capabilities. A [panel scene](scenes.md) is the usual place for them,
and its `spectrum` control and radio values draw from the same radio.

## Capabilities

The radio calls are manifest capabilities, refused unless declared and shown
to the operator at install:

- **`requiresRadioRead`** allows `host.listRadios()` and `host.readRadio()`,
  a scene's `spectrum` control and `radio` values, and a panel's `radio`
  trigger; from API 23, `host.listEquipment()` and the `equipment` trigger.
- **`requiresRadioWrite`** allows `host.setRadio()`,
  `host.setRadioConnection()` and `host.setRadioSpectrum()`, and
  transmitting with `host.sendRadioCw()`, `host.playRadioVoice()`,
  `host.setRadioPtt()` and `host.stopRadioTransmit()`; from API 23,
  `host.setAntenna()`, `host.setRotator()` and `host.stopRotator()`.
  Implies read, since a command answers with the radio's state.
- **`requiresRadioRaw`** (extension API 11) also allows
  `host.sendRadioRaw()`, any command in the radio's own protocol. Implies
  write.

An undeclared call rejects rather than answering null. A capability belongs
to the bundle that declared it and to the sub-extensions it defines under
its own key; a separately installed bundle never inherits one through its
name.

## Reading a radio

`host.listRadios()` lists the configured local transceivers.
`host.readRadio(id?)` answers a local radio's state, or `null` on a host
without this API. `id` is a radio's `id`, or from API 19 `A` or `B` for the
radio a logging set works: `A` the logging radio, `B` SO2R's Radio B, whose
answer has every field empty while there is none. Omitted, the logging radio.

- `frequency` (Hz), `mode`, the connection state, `power`, the transmit
  state. While the radio is live, the frequency is where the app has it: a
  tune set through the app shows there from the moment it is accepted,
  ahead of the radio's report of it.
- `meters`: `signalDbm`, `powerOut`, `swr`, `alc`, `supplyVolts` and
  `compression` (dB, API 22), each only while its driver has a fresh
  reading. `signalDbm` is receive power in whole dBm, refreshed a few times
  a second, expiring two seconds after the last reading. A scene that only draws meters reads them as radio values
  instead, at the radio's rate. The answer never substitutes the app's
  manually entered VFO for a reading the radio did not give.
- `spectrum`: the scope, below.

Extension API 7 adds to the answer:

- `maxWatts`: the model's rated output, where the app knows it; `modes`:
  what `setRadio` accepts for this radio, in its order.
- `tuner`: `inline`, `bypassed`, `tuning` or `failed`; `null` for a radio
  without one or whose driver cannot read it. `canStartTune` (API 9): the
  radio starts a tune apart from putting its tuner in line; false on a radio
  whose in-line already is the tune, and wherever `tuner` is null.
- `passband`: `{ lowHz, highHz }`, the receive filter's edges from the tuned
  frequency as the radio shows them (`100`…`2800` in USB, `-2800`…`-100` in
  LSB, around zero in CW), or `null` where its driver cannot read it.
- `antennas`: `{ rxPorts, txPorts, rx, tx, separate }`, the radio's ports by
  its own names and which it uses, or `null` where its driver cannot read
  them; `separate` means it picks receive and transmit independently,
  otherwise one port serves both.
- `keying`: what the app keys with, while this is the logging radio,
  connected, on a host with keying enabled: `canKeyCw`, `cwSending`,
  `keyerSpeedWpm` (the key's own report, `null` before it has given one),
  `keyerSpeedRange`, `canPtt`, `ptt` (whether the app's own latch holds the
  transmitter) and `voiceMemories` (`[{ number, label }]`, empty for a radio
  that plays none). `null` otherwise.
- `lastTransmission`: `{ swrAverage, endedAtMillis }` for the last
  transmission the radio finished since the app started, or `null`.
  `swrAverage` averages the readings taken with RF out and is `null` when
  there were none; `endedAtMillis` is real time, to compare with
  `clock.realNowMillis`.

Extension API 19 adds:

- `set`: `A` for the logging radio, `B` for SO2R's Radio B, `null` for a
  radio no logging set works.
- `opStyle`: how that set is working it, `run` (calling CQ on a frequency of
  its own) or `normal` (anything else: search and pounce, which the app
  labels S&P, and the default), `null` where `set` is. It is the style each
  new contact records as `opStyle`, and it moves with the operator: message 1
  keyed is `run`, and so is a self-spot, unless its comment starts with QRT,
  which is `normal`; leaving the run frequency, or picking a spot, is
  `normal`; coming back to it within three minutes is `run` again. The `RUN` and
  `SNP` commands set it outright.
- `reportedFrequencyHz`: the frequency the radio itself last reported.
  It trails `frequencyHz` after a tune until the radio reports it there.
  If the radio reports something else and keeps to it past a hold, about
  one and a half seconds and longer on a radio slow to answer, that report
  becomes `frequencyHz` too: a radio that refused or rounded the tune is
  where it says.

Logical receivers keep separate `id`s. When several share a physical radio
the answer may also carry `deviceId`, an opaque string shared by those
receivers, and `channel: { key, label }` (`main` or `sub` on a radio with
two receivers, the label localized); use them to group receiver choices.
Commands and spectrum controls still address the receiver's `id`, never
`deviceId`.

## Setting a radio

`host.setRadio({ id, selection?, ...settings })` sets any of these through
the app's own radio service. API 7.

- `frequencyHz`; `dial: true` says it comes from an on-screen dial turning
  rather than a typed target, and on the logging radio the app settles it as
  it would the radio's own knob.
- `mode`: one of `modes`.
- `powerWatts`: up to `maxWatts` where stated. On the logging radio it goes
  through the app's VFO, so it is the power the next contact logs.
- `keyerSpeedWpm`: the logging radio's keyer, which clamps to its range;
  `keying.keyerSpeedWpm` says what it took.
- `tunerInline`: puts the antenna tuner in line or bypasses it. On a radio
  whose tuner has no other way in, in line is a tune, a carrier on the air;
  other radios switch it without transmitting.
- `startTune: true` (API 9): starts a tune, a carrier on the air until the
  tuner settles, read back through `tuner` as `tuning`. **Only for an
  operator's explicit press**; never on a hook's own initiative. It goes
  alone: in the same call as any other setting it is `invalid`, and it is
  `unsupported` where `canStartTune` is false. It is the radio's own tune,
  not one of the keying calls below, so it reaches whichever radio the panel
  shows, with keying on or off. A start while one is running is ignored, and
  `stopRadioTransmit` (or Escape) ends a tune the app started.
- `passband`: `{ lowHz, highHz }`, as `passband` reports it. A radio that
  sets only a width from a table takes the nearest, keeping its own shift;
  read the result back from `passband`. It applies to the mode the radio is
  in, and a call that also changes `mode` is `invalid`.
- `antenna`: `{ rx?, tx? }`, ports from `antennas`; without `separate`,
  either names the one port and two different ones are `invalid`. An `rx`
  naming the `tx` asked for in the same call is taken even where `rxPorts`
  does not list it yet.

Omitting `selection` follows the designated logging radio; an explicit
`selection` pins the command to that local radio without changing the
designation.

**Answers.** The host rejects a changed designation (`changed`), a
disconnected or stale radio (`disconnected`), a transmission in progress
(`transmitting`), and a malformed command or a value out of range
(`invalid`); a setting this radio cannot take (a tuner, passband or antenna
its readout has as `null`, a keyer speed without `keying.canKeyCw`) answers
`unsupported`. An accepted result means **requested, not confirmed**; only
the state the radio reports afterwards confirms it, as `reportedFrequencyHz`
(API 19) does for a tune. Drivers keep their own
protocol and echo handling.

**Pacing.** Accepted requests are spaced at least 250 ms apart, since a
dragged control would otherwise flood the CAT link, and wait their turn in
one queue for every extension. At most **four** of yours may be in the queue
at once, the one being sent included; a fifth answers `busy` without
sending, so a panel told so sends its latest value again once an earlier
call answers, and a dragged control lands where it is rather than
everywhere it has been. A call that cannot go out within **two seconds** of
being made answers `expired` and sends nothing.

## Keying

The keying calls transmit, and act only on the logging radio on a host with
keying enabled; a panel pinned to another radio is answered `unsupported`
rather than keying the logging radio behind the operator's back. API 7.

- `host.sendRadioCw({ id, selection?, text })` keys `text` (up to 1,000
  characters) on the key in use, as the keyer area's messages do.
- `host.playRadioVoice({ id, selection?, memory })` plays one of
  `keying.voiceMemories` once. It never arms a repeat.
- `host.setRadioPtt({ id, selection?, on })` keys or unkeys PTT through the
  app's own latch, so Escape releases it as it does the operator's own.
  `on: false` releases whatever key the app holds and is never refused; a
  radio that does not take the key answers `on: true` with `disconnected`.
  While the station's other radio is still on the air, `on: true` is
  accepted and the key goes down once that radio is off it, or not at all
  after two seconds; `ptt` reads false until then, and `on: false` takes the
  waiting key back.
- `host.stopRadioTransmit({ id, selection? })` stops every CW message, voice
  memory, PTT and tune the app is keying, as Escape does, whatever radio the
  identity names: a stop is the one call here that is never refused.

A radio that cannot do what is asked answers `unsupported`; one that is not
connected, `disconnected`. These are not paced and not refused for a
transmission in progress.

## Connecting

`host.setRadioConnection({ id, selection?, connected })` starts or ends a
local CAT connection. Acceptance starts the operation; follow the reported
connection state for completion. It does not switch the hardware's power or
transmit.

## Raw commands

`host.sendRadioRaw({ id, selection?, text | bytes, replyMs?, until? })` (API
11, `requiresRadioRaw`) sends commands in the radio's own protocol: exactly
one of `text`, sent as UTF-8, or `bytes` (each 0 to 255), up to 4,096 bytes.
**Nothing about them is checked.** They may transmit, change any setting or
put the radio somewhere the app's own controls never would; that is what the
operator agreed to at install. It reaches any local radio, with keying on or
off, is neither paced nor refused for a transmission in progress, and goes
one call at a time per radio; past eight waiting the next is `busy`.

- `replyMs`, up to 2,000: how long to wait for the reply. Omitted or 0, the
  call answers as soon as the commands are handed to the driver, with no
  `reply`.
- `until`, text or bytes, needs `replyMs`: the reply ends just after its
  first occurrence.
- The answer carries `reply: { text, bytes }`, possibly empty, at most
  64 KiB, with `text` its UTF-8 reading.

What the commands are, and what the reply holds, is the protocol's. Where
the app's driver keeps one question on the wire and reads the next reply as
its answer, a raw command waits its turn in that queue (written beside it,
its answer would be read as the answer to the driver's question), or, on a
FlexRadio, is numbered as the driver's own are; the app's own polls may come
between two calls. The reply is then the answers to the raw commands alone,
once each has come or the window closes:

| Radio | Commands | Reply |
| --- | --- | --- |
| Icom CI-V | `bytes`: whole frames, `FE FE` … `FD`, one at a time; the app addresses each to the radio from itself, whatever its address bytes say | each frame's answer frame (`FB`/`FA`, or its data) |
| Yaesu binary (FT-817/857/897) | `bytes`: five-byte commands | what the radio sends for each before it falls quiet; not read by the app |
| FlexRadio | `text`: one command per line, without `C<seq>\|`; the app numbers each like its own | each one's `R` line |
| Ham Radio Deluxe | `text`: one command per line, without the radio's context, which the app adds | each one's reply text, one per line |
| DXLab Commander | `text`: one whole message (`<command:10>CmdGetFreq<parameters:0>`) | the field it is answered with; without `replyMs` it goes out as a set, waiting for nothing |
| flrig | `text`: one XML-RPC call, which the app posts | the response's body |

Every other radio's commands (Kenwood, Elecraft, Yaesu ASCII, rigctld,
N3FJP, Guohetec, Thetis, TCI) are written as given, several back to back
(`FA00014074000;MD2;`) in one write with none of the app's own between them,
since each of their answers names what it answers. The reply there is
everything the connection received in the window, the answers to the app's
own polls included, so `until` is worth setting.

The app's driver still reads what the radio sends, so a raw command's effect
shows in `readRadio` as a change at the front panel would, and a command
that confuses the driver confuses the app. A radio that is not connected
answers `disconnected`; one whose driver takes no raw commands (a
placeholder radio), `unsupported`; a malformed call, or commands that are
not the protocol's (CI-V bytes that are not whole frames), `invalid`. A
refusal heard within a second of a raw command on a protocol whose refusals
name no command (`?;`, rigctld's `RPRT`) is taken as the raw command's, not
counted against the app's own reads.

## The scope

`readRadio()` carries `spectrum` (absent on an app without a band scope):
`null` for a radio without a scope, otherwise its settings as the radio
reports them (`mode`, `spanHz`, `lowHz`/`highHz`, `refLevelDb`, `speed`),
what it accepts (`spansHz`, `refMinDb` … `refStepDb`, `modes`, `speeds`) and
`problem`, why it cannot run, in the operator's language. The settings are
known only while a `spectrum` control has the scope running, and `null`
otherwise. `autoSpan` (API 12) is true where the app sizes the scope itself
for its displays (a sweep it computes, whose width changes nothing on the
radio): it runs at the narrowest span covering the widest `spectrum`
control's `span` on screen, each control cropping its own width from it, and
narrows again as wider ones go. A panel there names its width with `span`
and leaves `spanHz` alone; setting `spanHz` too has the panels take turns.

`host.setRadioSpectrum({ id, selection?, mode?, spanHz?, refLevelDb?, speed? })`
(API 6) changes them; a span between two the radio offers is snapped to the
nearer. It answers `stopped` when no control is running the scope; nothing
is queued for later.

## Antenna switches and rotators

Extension API 23. `host.listEquipment()` answers every antenna switch and
rotator the operator has set up, connected or not:

```ts
// { id, kind: "antennaSwitch" | "rotator", name, connected,
//   antennas?: [{ key, name }],
//   ports?: [{ key, label, antenna?, auto, band?, transmitting }],
//   azimuth?, elevation?, target?: { azimuth, elevation? }, beamWidth? }
host.setAntenna({ id, port, antenna })        // by the switch's own keys
host.setRotator({ id, azimuth, elevation? })  // true degrees
host.stopRotator({ id })
host.setEquipmentConnection({ id, connected })  // API 23
```

A switch names its antennas and its radio ports by its own keys, never by
position. A port marked `auto` is choosing its antenna from band data
itself, and a selection made there stands until the next band change. No
antenna is switched while a radio the switch may be feeding transmits.
A rotator's `azimuth` and `elevation` are where it points, and `target`
where it was told to turn, until it gets there, is stopped, or stalls short
of it. An `azimuth` is taken modulo 360, so -10 turns it to 350; an
`elevation` outside 0–180 is `invalid`. Its limits may turn it somewhere other
than asked; the answer's `state.target` says where. From API 23, `beamWidth`
is the antenna's beam in degrees where the device knows it, as a directional
switch does; a rotator alone never does.

`setEquipmentConnection` (API 23) connects or disconnects a switch or a
rotator, as the station's own plug does. It never waits behind other
commands, and `accepted` means the connection was asked for: `connected`
says when it is up. Its one refusal is `invalid`, for no such device or a
`connected` that is not a boolean.

A scene's [`rotatorMap` control](scenes.md#rotator-map) shows a rotator under
`requiresRadioRead` and turns it on a click or a drag under
`requiresRadioWrite`.

Each command answers `{ accepted, reason?, state }`, `state` being the
device as `listEquipment` describes it. `accepted` means sent, not done:
the device's reports confirm it. Refusals: `invalid` for no such device of
that kind, or a key it does not have; `disconnected`, also for a switch that
has not yet said what it has; `transmitting`; `failed` when the device's
driver could not send it, which the operator is told of; `busy` and
`expired`. Commands to one device go out at least 250 ms apart, in the order
they were made, under `setRadio`'s rules: four of one extension's may wait at
once, the one being sent included, and a fifth is answered `busy`; one still
waiting two seconds after it was made is answered `expired`. `stopRotator`
never waits, and the turns still waiting for that rotator answer `expired`.

The `equipment` [trigger](panels.md#triggers) fires when a switch routes a
port to another antenna, its antennas or a port's `auto` or `band` change, a
device connects or drops, or a rotator is told to turn, arrives or stops; not
when a port's `transmitting` flips, nor for each heading a turning rotator
reports.

## Example

`ki2d-radio-panel` in [ham2k/extensions](https://github.com/ham2k/extensions)
is a published scene panel, a full front panel: it samples state once a second while visible, keeps
knob motion and readout updates local, sends tuning continuously during a
drag paced by the app, and shows the requested value at once while the
confirmation status tells pending from reported.
