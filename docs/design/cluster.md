# DX cluster connection

The app holds one telnet connection to a DX cluster node, and extensions post
spots and read lines through it. The code is in
[`app/lib/services/cluster/`](../../app/lib/services/cluster/), and the host
calls are in
[`cluster_host_calls.dart`](../../app/lib/services/extensions/cluster_host_calls.dart).

## The network

DXSpider, AR-Cluster and CC Cluster nodes are linked into one worldwide
network. A spot entered at any well-linked node reaches all of them, and the
web aggregators too (DX Summit, HamQTH and others). One spot posted at K1TTT
showed up at W3LPL (DXSpider), VE7CC-1 (CC Cluster), NC7J (AR-Cluster) and
DX Summit in under half a second.

Every node drops a duplicate before passing it on. A duplicate is the same
call and frequency within about a minute, or the same call and comment
within five minutes. So **a spot is posted once, to one node**:

- A second node adds no reach.
- Repeats count against the node's flood control.
- A flood block outlives the session and costs the operator their spotting on
  that node.

## Why the app holds it, not each extension

**One session per call.** A node logs a call in once: a second session under
the same call knocks the first off. Two extensions each holding their own
connection would take turns disconnecting each other. The operator's own
cluster client (N1MM, a band map) is a third party to the same fight, which is
why the session is held only while something needs it.

**Extensions have no TCP.** They have `host.fetch` and `host.webSocket` only,
and a cluster node speaks neither.

## Lifecycle

The connection opens on demand, at the first `clusterPostSpot`, `clusterSend`
or `clusterSubscribe`.

- **Idle close.** With nothing subscribed, the session closes after five idle
  minutes.
- **Subscribed.** A subscribed session stays up. If it drops, it reconnects
  after 5 s, then 15 s, then 1 min, then every 5 min.
- **Unconfirmed commands.** A command or spot whose connection drops under
  it, that gets no reply, or that cannot reconnect is sent again on a fresh
  session, as long as its deadline (see Timing) leaves room. A node that
  stops answering is treated as dropped: a connection the network lost
  without a reset reads as open until the OS gives up on it, minutes later.
  A node that answered before it hung up took the command (`bye` is answered
  that way), so that one is not sent again; a spot or announcement from the
  network arriving meanwhile is no answer.
  A spot the node took just before the drop goes out twice; the node drops
  the duplicate, and a spot that silently never went out is the worse harm.
  Any other command can go out twice the same way, and nothing drops that
  duplicate: an `ANNOUNCE` can repeat. That is accepted, for one rule
  covering every command.
- **Runtime restart.** A restart of the extension runtime drops every
  subscription, because the old runtime's hooks are gone.

**Login call.** The session logs in as the operator of the operation in front
(`operatorCallFor`), or as the profile's operator when no operation is open.
It uses the plain call with no SSID, so a spot reads `DX de KI2D` exactly as
the operator would post it by hand. A different operator at the next command
means a new login before the command is sent.

**Login prompt.** The call goes out at the node's prompt, never at a banner
line. Every node probed ends the prompt on the word and a colon (`login: `,
`Please enter your call: `); most leave it unterminated, K3LR ends it with a
newline. Banners name the callsign too ("At the login prompt please enter
your amateur radio callsign.", NC7J's "Enter your callsign"), and the network
splits them anywhere. So:
- the text must END on `call`, `callsign`, `login` or `password` and a
  colon, whether it is the unterminated tail or the last complete line;
- and the node must then go quiet for 300 ms. A real prompt waits for its
  answer; a banner or welcome text that only ends like one at a read
  boundary ("…use set/password:") is followed by more, which cancels it.
Answered wrongly, a call goes out before the node listens, or the stored
password goes out as a command that every reading extension then sees.

**Login.** The login succeeds at the node's first `<call> de <node> … >`
prompt and at nothing else. A node that takes the call and never shows one
fails the login: it may still be asking something, and the next command would
be the answer. An operator who turned prompts off on a node turns them back on
there (`SET/PROMPT`).

**Timing.** A command has 14 seconds from when it is asked for, under the 15
a spots hook has: past that the hook reports a timeout while the spot may
still go out. The wait behind other commands and every attempt fit inside
it. The connect, the login and the reply get five seconds each, or what is
left when that is less, and no attempt starts with under two seconds left:
the command would go out with no time to be answered. A wait the deadline
cut short is a `timeout`, never a refused login, and leaves the session
open. A session closed while a login or a command waits on it — the server
changed, the app closed it — ends them at once, and a superseded login
never reports the service as connected. A node that hangs up during the
login refuses the call, and is not logged in to again for that command:
repeated logins are how a node comes to ban a call.

**Password.** A node that asks for a password gets the one stored for it (per
`host:port`, in secure storage). With none stored, the login fails as
`needsPassword` instead of hanging.

## Lines and replies

Every line carries a `seq` that increases for the app's whole session, across
reconnects. `clusterLines({ after })` therefore never misses or repeats a
line. The scrollback keeps 500 to 5,000 lines (Settings; default 1,000).

**Subscribers.** A subscriber gets new lines through its `cluster` hook's
`onLines`, at most once a second, whatever the node's rate. A failed delivery
is not retried; the lines stay readable through `clusterLines`.

**Replies.** Commands go out one at a time. A command's reply is whatever the
node sent between the command and its next `<call> de <node> … >` prompt,
which includes any spots it interleaved meanwhile.

**Spots.** A spot is refused when the reply holds a refusal (`Sorry…`,
`… not in band`). That holds even when the node also echoed the spot:
**an echo never proves a spot went anywhere.** DXSpider builds from late 2021
to early 2025 keep an HF self-spot on the local node only and still echo it.
Sysop `badspotter` and bad-IP lists do the same.

**Spacing.** The host spaces spots at least five seconds apart, so an
extension in a loop cannot trip the node's flood block.

**Comments.** The host sends at most 60 characters of a comment. A node shows
30 in an 80-column `DX de` line but forwards the rest, and the aggregators
show all of it, so what matters most goes first.

## Grants

Each level includes the ones before it, and the consent screen names the
strongest one declared:

| Manifest | Calls | Why it is separate |
|---|---|---|
| `requiresClusterRead` | `clusterStatus`, `clusterLines`, `clusterSubscribe`, `clusterUnsubscribe`, the `cluster` hook | logs the operator in |
| `requiresClusterSpot` | `clusterPostSpot` | a spot read worldwide as the operator's |
| `requiresClusterCommand` | `clusterSend` | any command: `ANNOUNCE/FULL` reaches every node, and `SET/PASSWORD` changes the operator's account on this one |

`clusterPostSpot` builds the command itself:
- It drops control characters, so a comment cannot carry a second command
  past the newline. Every line sent doubles a 0xFF byte, as telnet
  requires, so a `ÿ` cannot start a telnet command either.
- It refuses a call no node would take.

## Choosing a node

Settings offers five nodes, each seen to forward a spot to the whole network:

| Node | Address | Software |
|---|---|---|
| K3LR | `dx.k3lr.com:23` | AR-Cluster 6.6, linked to W3LPL |
| K1TTT | `k1ttt.net:7373` | AR-Cluster 6.6 |
| W3LPL | `dxc.w3lpl.net:7373` | DXSpider 1.57, a current build |
| NC7J | `dxc.nc7j.com:7373` | AR-Cluster 6.6 |
| VE7CC-1 | `ve7cc.net:23` | CC Cluster |

K3LR is the default. Settings shows the choice as a Cluster Server row, which
opens a Select Server dialog listing these five and Other; picking Other adds
a server and port row to the same dialog. Other with no server typed keeps the
previous choice.

A node that requires registration refuses an unregistered call's spot.
Registration is per node and is the operator's to arrange with its sysop.

These settings are the DX Cluster section of Settings' Spotting category. It
appears only when a loaded extension declares a cluster grant: a node nothing
posts to is a setting with nothing behind it.

**Connect to cluster** (on by default) is the operator's way to keep the app
off every node. Turned off, an open session closes at once, a connect under
way never logs in, reconnecting stops, and every send, spot and subscription answers `off`. Turned back on,
the session comes back if anything is subscribed.

## Console

The Cluster Console — Settings' Show Console row, or the `CLUSTER` command
(`spot-commands`), where the DX Cluster section shows — shows the session as it happens: every line the node
sends, every line sent (the login call, commands typed there, extensions'
commands and spots; never the password), each change of state, and each
command sent again or given up on, with why. It keeps as many entries as the
scrollback keeps lines. A command typed there goes out like an extension's,
retries included.

Opening it connects nothing. **Connect** logs in and keeps the session up —
reconnecting it if it drops — while the console is open; closing the console
returns the session to the usual rules. **Disconnect** closes the session
now — or drops a connect under way — and it stays closed, even with
subscribers, until something next asks for it: only a drop the node or the
network causes reconnects on its own. A command waiting to go out again
gives up instead.

## Platforms

Desktop and mobile only. A browser cannot open a telnet connection, so on
web every call answers `unsupported`.
