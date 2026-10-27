# Radio control

An extension reads and commands the operator's local radios through host
calls: what a radio reports, setting its frequency, mode, power and more,
keying it, running its scope, and — with the operator's leave — any command
in its own protocol. A [panel scene](scenes.md) is the usual place for them,
and its `spectrum` control and *Radio values* draw from the same radio.

## Capabilities

The radio host calls are manifest capabilities, refused unless declared — the
same shape as `requiresLocation`, and shown to the operator at install:
`"requiresRadioRead": true` allows `host.listRadios()` and `host.readRadio()`;
`"requiresRadioWrite": true` allows `host.setRadio()`,
`host.setRadioConnection()` and `host.setRadioSpectrum()` — and transmitting
with them: `host.sendRadioCw()`, `host.playRadioVoice()`, `host.setRadioPtt()`
and `host.stopRadioTransmit()` — and implies read, since a command answers with the
radio's state. `"requiresRadioRaw": true` (extension API 11) also allows
`host.sendRadioRaw()`, any command in the radio's own protocol, and implies
write. An undeclared call rejects rather than answering null.
A capability belongs to the bundle that declared it, and to the sub-extensions
that bundle defines under its own key. A separately installed bundle never
inherits one through its name: `rigpanel-themes` gets nothing from `rigpanel`.

`"requiresSettingsWrite": true` is the same shape for a `command` hook: it
lets the extension's commands carry the actions that change the app's own
settings (see [`command`](commands.md)), and the install screen names it.

## Reading a radio

**KI2D’s Radio Panel** is the CAT reference extension. `host.listRadios()` lists configured
local transceivers. `host.readRadio(id?)` returns
a **local** radio's reported frequency (Hz), mode, connection state,
power, TX state and fresh telemetry, or null on hosts without this API.
`meters` holds `signalDbm`, `powerOut`, `swr`, `alc` and `supplyVolts`, each
only while its driver has a fresh reading. `meters.signalDbm` is receive power in whole dBm when supported, refreshed a few
times a second; it expires after two seconds without a reading. The Flex driver receives the selected slice’s LEVEL
meter, and the transmitter's forward power and SWR, through its native UDP channel. The reference panel draws a segmented
receive meter and leaves it unlit when unavailable, stale, or transmitting. It does
not substitute the app's manually entered VFO for a radio reading. A scene
that only draws meters reads them as *Radio values* instead, at the radio's
rate. Extension API 7 adds to the answer:

- `maxWatts`: the model's rated output, where the app knows it; `modes`: the
  modes `setRadio` accepts for this radio, in the radio's order.
- `tuner`: `inline`, `bypassed`, `tuning` or `failed`; null for a radio
  without one, or whose driver cannot read it.
- `canStartTune` (extension API 9): the radio starts a tune apart from
  putting its tuner in line — `setRadio`'s `startTune`. False on a FlexRadio,
  whose in line already is the tune, and wherever `tuner` is null.
- `passband`: `{lowHz, highHz}`, the receive filter's edges in Hz from the
  tuned frequency as the radio shows them — `100`…`2800` in USB,
  `-2800`…`-100` in LSB, around zero in CW — or null where its driver cannot
  read it.
- `antennas`: `{rxPorts, txPorts, rx, tx, separate}`, the radio's own antenna
  ports by the radio's names and which it uses, or null where its driver
  cannot read them. `separate`: it picks receive and transmit independently,
  as a FlexRadio does; otherwise one port serves both.
- `keying`: what the app keys with — `canKeyCw`, `cwSending`,
  `keyerSpeedWpm` (the key's own report, null before it has given one),
  `keyerSpeedRange`, `canPtt`, `ptt` (whether the app's PTT latch holds the
  transmitter) and `voiceMemories` (`[{number, label}]`, empty for a radio
  that plays none) — while this is the logging radio, connected, on a host
  with keying enabled; null otherwise.
- `lastTransmission`: `{swrAverage, endedAtMillis}` for the last
  transmission the radio finished since the app started — its SWR averaged over the readings
  taken with RF out (null when there were none), and when it ended, in real
  milliseconds to compare with `clock.realNowMillis` — or null.

## Setting a radio

`host.setRadio({id, selection?, ...settings})` sets any of these on that same
radio, through the existing VFO/CAT service. It and the keying calls below are
extension API 7: a bundle using them declares `"api": 7`.

- `frequencyHz`; `dial: true` says it comes from an on-screen dial turning,
  not a typed or clicked target, and on the logging radio Smart VFO Snap
  settles it like the radio's own knob.
- `mode`: one of `modes`.
- `powerWatts`: up to `maxWatts` where that is stated. On the logging radio
  it goes through the app's VFO, so it is the power the next QSO logs.
- `keyerSpeedWpm`: the logging radio's keyer, which clamps to its own range —
  `keying.keyerSpeedWpm` says what it took.
- `tunerInline`: puts the antenna tuner in line or bypasses it. On a
  FlexRadio, whose tuner has no other way in, in line is a TUNE — a carrier
  on the air; other radios switch it without transmitting.
- `startTune: true` (extension API 9): starts a tune — a carrier on the air
  until the tuner settles, read back through `tuner` as `tuning`. Only for an
  operator's explicit press: never send it on a hook's own initiative. It
  goes alone — in the same call as any other setting it is `invalid` — and is
  `unsupported` where `canStartTune` is false. It is the radio's own tune,
  not one of the keying calls below: it reaches whichever radio the panel
  shows, with keying on or off. A start while one is running is ignored, and
  `stopRadioTransmit` (or Escape) ends a tune the app started.
- `passband`: `{lowHz, highHz}`, as `passband` reports it. A radio that sets
  only a width from a table takes the nearest, keeping its own shift — read
  the result back from `passband`. It applies to the mode the radio is in: a
  call that also changes `mode` is `invalid`.
- `antenna`: `{rx?, tx?}`, ports from `antennas`; without `separate`, either
  names the one port, and two different ones are `invalid`. An `rx` naming
  the `tx` asked for in the same call is taken even where `rxPorts` does not
  list it yet.

The host rejects a changed designation (`changed`), a disconnected or stale
radio (`disconnected`), a transmission in progress (`transmitting`) and a
malformed command or a value out of range (`invalid`); a setting this radio
cannot take — a tuner, passband or antenna its readout has as null, a keyer
speed without `keying.canKeyCw` — answers `unsupported`. Accepted requests are
spaced by at least 250 ms, since a dragged control would otherwise flood the
CAT link. Omitting a selection follows the designated logging radio; an explicit `selection`
pins the command to that local radio without changing the logging designation.
An accepted result means requested, not confirmed; only subsequent
reported state confirms it. Drivers retain their own protocol/echo handling.

## Keying

The keying calls transmit, and act only on the logging radio, on a host with
keying enabled — a panel pinned to another radio is answered `unsupported`
rather than keying the logging radio behind the operator's back:

- `host.sendRadioCw({id, selection?, text})` keys `text` (up to 1000
  characters) on the key in use, as the keyer area's messages do.
- `host.playRadioVoice({id, selection?, memory})` plays one of
  `keying.voiceMemories` once. It never arms a repeat: a CQ repeating on a
  panel's say-so is one the operator did not start where they would stop it.
- `host.setRadioPtt({id, selection?, on})` keys or unkeys PTT through the
  app's own latch, so Escape releases it as it does the operator's own.
  `on: false` releases whatever key the app holds and is never refused; a
  radio that does not take the key answers `on: true` with `disconnected`.
- `host.stopRadioTransmit({id, selection?})` stops every CW message, voice
  memory, PTT and tune the app is keying, as Escape does, whatever radio the
  identity names: a stop is never the call that is refused.

A radio that cannot do what is asked (no CW key, no voice memories, no PTT)
answers `unsupported`; one that is not connected, `disconnected`. These are
not paced, and not refused for a transmission in progress.

## Connecting

`host.setRadioConnection({id, selection?, connected})` starts or ends a local CAT
connection using the same selection and identity checks. Acceptance starts the
operation; follow reported connection state for completion. It does not switch
the hardware's mains power or initiate transmission.

## Raw commands

`host.sendRadioRaw({id, selection?, text | bytes, replyMs?, until?})`
(extension API 11, `requiresRadioRaw`) sends commands in the radio's own
protocol — exactly one of `text`, sent as UTF-8, or `bytes`, each 0…255, up
to 4096 bytes. **Nothing about them is checked.** They may transmit, change
any setting or put the radio somewhere the app's own controls never would;
that is what the operator agreed to at install, where the grant is shown in
those words. It reaches any local radio through the same `id`/`selection`
check as `setRadio`, with keying on or off, and is neither paced nor refused
for a transmission in progress. One radio's calls go one at a time, in order,
so that one call's reply window never holds the next one's answer, and past
eight waiting the next is refused as `busy`; the app's own polls may come
between two calls.

- `replyMs`, up to 2000: how long to wait for the reply. Omitted or 0, the
  call answers as soon as the commands are handed to the driver, with no
  `reply`.
- `until`, text or bytes, needs `replyMs`: the reply ends just after its first
  occurrence.
- The answer carries `reply: {text, bytes}`, possibly empty, at most 64 KiB,
  with `text` its UTF-8 reading.

What the commands are, and what the reply holds, is the protocol's. Where the
app's driver keeps one question on the wire and reads the next reply as its
answer, a raw command waits its turn in that queue — written beside it, its
answer would be read as the answer to the driver's question — or, on a
FlexRadio, is numbered as the driver's own are. The reply is then the answers
to the raw commands alone, as the radio sent them, once each has come or the
window closes:

| Radio | Commands | Reply |
|---|---|---|
| Icom CI-V | `bytes`: whole frames, `FE FE` … `FD`, one at a time; the app addresses each to the radio from itself, whatever its address bytes say | each frame's answer frame (`FB`/`FA` or its data) |
| Yaesu binary (FT-817/857/897) | `bytes`: five-byte commands | what the radio sends for each before it falls quiet; not read by the app |
| FlexRadio | `text`: one command per line, without `C<seq>\|` — the app numbers each like its own | each one's `R` line |
| Ham Radio Deluxe | `text`: one command per line, without the radio's context — the app adds it | each one's reply text, one per line |
| DXLab Commander | `text`: one whole message (`<command:10>CmdGetFreq<parameters:0>`) | the field it is answered with; without `replyMs` it goes out as a set, waiting for nothing |
| flrig | `text`: one XML-RPC call (`<?xml …?><methodCall>…`) — the app posts it | the response's body |

Every other radio's commands are written as given — several back to back
(`FA00014074000;MD2;`) in one write, none of the app's own between them —
since each of their answers names what it answers: Kenwood, Elecraft and
Yaesu ASCII, rigctld, N3FJP, Guohetec. The reply there is everything the
connection received in the window, the answers to the app's own polls
included, so `until` is worth setting.

The app's driver still reads what the radio sends, so a raw command's effect
shows in `readRadio` as a change made at the front panel would — and a command
that confuses the driver confuses the app. A radio that is not connected
answers `disconnected`; one whose driver takes no raw commands (a placeholder
radio), `unsupported`; a malformed call, or commands that are not the
protocol's (CI-V bytes that are not whole frames), `invalid`. A refusal heard
within a second of a raw command on a protocol whose refusals name no command
(`?;`, rigctld's `RPRT`) is taken as the raw command's, not counted against the
app's own reads.

## The scope

`readRadio()` carries `spectrum` (absent on an app without a panadapter): null
for a radio without a scope, otherwise its settings as the radio reports them
(`mode`, `spanHz`, `lowHz`/`highHz`, `refLevelDb`, `speed`), what it accepts
(`spansHz`, `refMinDb`…`refStepDb`, `modes`, `speeds`) and `problem`, why it
cannot run, in the operator's language. The settings are known only while a
`spectrum` control has the scope running, and null otherwise. `autoSpan`
(extension API 12) is true where the app sizes the scope for its displays — a
sweep it computes, whose width changes nothing on the radio (a FlexRadio's DAX
IQ): it runs at the narrowest span covering the widest spectrum control's
`span` on screen, each control cropping its own width from it, and narrows
again as wider ones go. A panel there names its width with `span`; setting
`spanHz` too has the panels take turns.
`host.setRadioSpectrum({id, selection?, mode?, spanHz?, refLevelDb?, speed?})`
changes them; a span between two the radio offers is snapped to the nearer. It
answers `stopped` when no control is running the scope: nothing is queued for
later. The reference panel samples
state once per second while visible; knob motion and LCD digit updates run locally,
and tuning is sent continuously during dragging, paced by the CAT adapter. The
main readout follows the requested value immediately; confirmation status distinguishes pending requests from the radio
reporting the requested frequency. Radio-specific hardware verification remains
necessary before considering the experimental control API stable.
