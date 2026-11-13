# Agent link

How a local agent app (Claude, Gemini, Codex, an IDE agent) reaches the
running app over MCP, and what the operator decides about it. Behind the
`mcp` experiment; desktop builds only.

## The pieces

```
agent app ──stdio──▶ halo-mcp ──TCP 127.0.0.1──▶ app (AgentLinkService) ──agentLink hook──▶ core `mcp` extension
```

- **`halo-mcp`** (`packages/halo_mcp`) is the command an agent app is told
  to run. It speaks MCP's stdio transport on one side and the link below on
  the other, and holds the tokens the app handed it. It relays messages; it
  does not read or answer them, beyond saying so when it cannot reach the
  app at all.
- **`AgentLinkService`** (`app/lib/services/agent_link/`) listens, asks the
  operator, keeps the grants, and hands each message to the endpoint.
- **The `mcp` core extension** (`extensions/core/mcp/`) is the MCP endpoint:
  it answers `initialize`, lists its tools and runs them through the host
  calls an assistant has. The `agentLink` hook category reaches it and no
  other extension: the app invokes it by that key, and only for a bundle
  shipped in the app's assets.

## The link

Loopback TCP, never another interface: `127.0.0.1` on one port per
edition, so a Dev and a Regular build on one machine each keep their own
grants.

| Edition | Port |
| --- | --- |
| Regular | 47380 |
| Next | 47381 |
| Dev | 47382 |

Each frame is one JSON object on one line, UTF-8, at most 8 MiB. The first
line, within 10 seconds, is the command's hello:

```json
{"agentLink": 1, "client": {"name": "claude-code", "version": "2.1.0", "launcher": "Claude"}, "token": "…"}
```

`client.name` and `version` are what the agent app's MCP `initialize` said
of itself; `launcher` is the name of the process that started the command,
where the system says. `token` is the command's own for that agent app: 32
random bytes, base64url, minted and kept the first time, before the app is
asked anything. The app answers once:

```json
{"agentLink": 1, "ok": true, "access": "change"}
{"agentLink": 1, "ok": false, "reason": "denied"}
```

`reason` is `denied`, `unavailable` (the endpoint extension is not running)
or `protocol` (no token, one shorter than 32 characters, or a hello of
another version). After an `ok`, every line either way is one MCP JSON-RPC
message, relayed as is; the app answers a line that is not JSON with
-32700 and a batch with -32600. It hangs up when the operator removes the
app, and when the endpoint stops under a connected app, whose next
connection is then answered `unavailable`.

Our own framing rather than HTTP is deliberate: a web page can make a
browser send HTTP to a loopback port, never a JSON hello as its first line,
so a page reaching the port is hung up on before anything is read as a
request.

## Grants

The first time an app connects with a token the app does not recognise,
the operator is asked, wherever they are: allow it to **watch**, to watch
and **make changes**, or deny it. An allow keeps only the token's SHA-256
beside the grant: the client's name, its launcher, the access, when it was
allowed and when it was last connected. The command keeps the token per
client name, per edition, in the user's own config folder.

The question stays up until the operator answers it. Agent apps give up on
a server that is slow to start, often before the operator has read the
question; the token is the command's from the start, so an allow given
after the agent app gave up lets it in the next time it connects, and the
dialog says so. An app that connects again with the same token while the
question is up waits on that question rather than raising another.

Connected Apps, in Settings › Integrations, lists the apps
allowed; changing one's access takes effect on its next message, and
removing one hangs it up and forgets its token, so its next connection asks
again.

What a grant is and is not: it keeps other machines out, and puts every
new agent app — another user's on this machine included — in front of the
operator once before it gets in, with a way to cut it off. It does not stop software already running
as the same user, which can read the command's tokens — as it can read the
app's own data. The dialog says what the app will be able to do, not that
the connection is secure.

## Watch and change

`watch` lets the agent read: the operations, their QSOs, spots, the radio
and equipment, and the events the operator's activity raises. It also lets
the agent show the operator messages, on the FYI line and as notices, which
any assistant may do without a permission. `change` adds what an assistant
may do to the station, short of transmitting: never a tune, CW, voice, PTT
or a spot posted to the cluster, and never logging a contact. The agent
fills in the contact; the operator logs it. The endpoint receives the access
with every message and offers only the tools it allows; a change tool asked
for by name from an app that only watches is refused, saying so.

## Tools

Each tool is one host call, or a few, made as the `mcp` extension:

| Access | Tools |
| --- | --- |
| watch | `wait_for_events`, `list_operations`, `get_operation`, `get_qsos`, `get_call_history`, `find_calls`, `get_radio`, `list_radios`, `list_equipment`, `get_spots`, `get_band_annotations`, `search_settings`, `list_layouts`, `post_fyi`, `clear_fyi`, `show_notice` |
| change | `update_draft`, `set_radio`, `set_antenna`, `set_rotator`, `stop_rotator`, `mark_spots`, `unmark_spots`, `annotate_band`, `clear_band_annotations`, `update_setting`, `switch_layout`, `focus_panel` |

A tool about an operation takes its uuid, and reads the one in front without
it; which operations exist, and which is in front, comes from
`ctx.listOperations`. Every argument is checked against the tool's schema,
and a missing, mistyped or unknown one is refused by name. A change the
host refuses (`accepted: false`) comes back to the agent as a failed tool
call, with the reason, so it is never reported to the operator as done.

## Events

MCP lets the app answer only what the agent asks, so an agent follows the
operator by asking: `wait_for_events` answers at once with the events past
the cursor it passes, or holds the request until one comes, at most 45
seconds. Other requests from the same agent are answered meanwhile.

The extension never holds the request itself: a hook call left open keeps
the extension engine pumping its jobs every few milliseconds, which an
agent looping on `wait_for_events` would keep up all afternoon. With
nothing to answer, the tool answers at once with a hold in the reply's
`_meta` (`ham2k/hold`: for how long, and the arguments to ask again with,
which carry the cursor it read from). The link keeps the request, asks
the extension again each time its assistant has observed something, the
only moment its events change, and sends the last answer, without the
hold, when the time is up or the app hangs up. It holds at most 64
requests across every app, and refuses a 65th rather than answering it
empty, which an agent calling in a loop would repeat at once.

The events come from the `mcp` extension's own assistant, "Agent apps", in
Settings › Application Preferences › Assistants: an operation opening,
contacts logged (with the contacts, the first 50 of a larger batch), the
radio and equipment changing, and the spots board moving, at most once a
minute of real time. An operation counts as changed when anything the
operator sets on it does, not the counters, contact times and status that
logging a contact moves by itself. The radio counts as changed when its
frequency to the kHz, mode, status or transmitting does, once however many
operations are open. Typing is left out: watching the draft would make the
app produce one on every pause in typing, for every open operation. While
no operation is open, or the operator has the assistant switched off, no
events come.

They wait in one queue of the latest 200, which every connection reads with
its own cursor; an agent further behind is told it `missed` some, as is one
holding a cursor from before the extension last started: each start counts
from a cursor of its own, far from any other's.
