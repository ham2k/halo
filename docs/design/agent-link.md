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

Connected Apps, in Settings › Application Preferences, lists the apps
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

`watch` lets the agent read: the operation, its QSOs, spots, the radio and
equipment, and the events the operator's activity raises. It also lets the
agent show the operator messages, on the FYI line and as notices, which any
assistant may do without a permission. `change` adds everything else an
assistant may do. The endpoint receives the access with every
message and offers only the tools it allows.
