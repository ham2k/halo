# Extension dev link

How a dev tool on the same computer (`h2kext-dev`, or the repository's own
`npm run dev`) asks a running desktop app to load the extension it serves,
and what the operator decides about it. The author's side of it is in
[Getting started](../extensions/getting-started.md#iterate); this page is
the contract between the two ends.

## The pieces

```
h2kext-dev ──TCP 127.0.0.1 (the link)──▶ app (ExtensionDevLink)
     ▲                                          │ operator allows
     └──────── HTTP (the dev server protocol) ──┘ ExtensionDevClient, one per tool
```

- **The link** (`app/lib/services/extensions/dev_link/`) listens, asks the
  operator, and runs a dev client for each tool allowed. It carries the
  question and the session; the code still travels over the dev server
  protocol ([in-repo.md](../extensions/in-repo.md#the-dev-server)), the
  same one the Settings address uses.
- **The tool** (`extensions/tools/h2kext-dev.mjs`) finds the running apps,
  asks one, and keeps serving whatever the answer: the Settings address
  works as before.

## When it listens

In a desktop build, while Developer Mode is on, and never in a browser
(which cannot listen) or on a phone (where no dev tool runs; a phone keeps
the Settings address). Turning Developer Mode off closes the port and every
connection, and forgets every allow.

Loopback only, `127.0.0.1`, one port per edition so the author can pick the
build they mean:

| Edition | Port |
| --- | --- |
| Regular | 47390 |
| Next | 47391 |
| Dev | 47392, else the first free of 47393–47399 |

A Dev build has a range because several worktrees' Dev builds run side by
side. A build that gets none of its ports says so in Developer settings and
tries again every ten seconds: that its ports are taken, when they are held
or reserved (Windows keeps ranges for Hyper-V), or else the error itself,
which is also reported.

## The exchange

Each frame is one JSON object on one line, UTF-8, every one carrying
`"extDevLink": 1`. The tool's first line, within 10 seconds, is either a
probe or an ask. A first line of another version, a probe included, is
answered `{"ok": false, "reason": "protocol"}` carrying the app's own
version, and the tool tells the author to update whichever end is older
rather than that no app is running. A first line that is not JSON with that key is hung up on
without an answer: a web page can make a browser send HTTP to a loopback
port, never that line, and a reply would be something for it to read.

**Probe**: `{"extDevLink":1,"probe":true}` is answered with the app, and
hung up on:

```json
{"extDevLink": 1, "app": {"name": "Ham2K Logger", "edition": "dev", "label": "header work", "version": "26.11 BETA"}}
```

`edition` is `regular`, `next` or `dev`; `label` is the build's `DEV_LABEL`,
empty for a build without one. A tool that finds several apps lists them
from this.

**Ask**:

```json
{"extDevLink": 1, "tool": {"name": "h2kext-dev", "version": "1.29.0"}, "dir": "/Users/w7abc/notes", "keys": ["w7abc-notes"], "server": "http://127.0.0.1:8787/"}
```

`server` must be plain HTTP on this machine (`127.0.0.1`, `::1` or
`localhost`): the dialog shows a folder here, so the code comes from here.
The tool sends the address its server is actually bound to, not the
`--host` typed: `localhost` binds `::1` on one machine and `127.0.0.1` on
the next. For the same reason it takes no port something already answers
on at a loopback address, though the bind would succeed: macOS lets a
wildcard bind share a port with another process's `127.0.0.1` one, and the
app would reach the other process.
Anything missing or malformed is answered
`{"ok": false, "reason": "protocol"}`.

The app answers, a line each:

- `{"asking": true}` while the operator is being asked. The question stays
  until answered or until the tool hangs up, which withdraws it.
- `{"ok": true}` or `{"ok": false, "reason": "denied"}`.
- After an `ok`, the dev client's state whenever it changes:
  `{"state": "connected", "keys": [...], "refused": {"key": "why"}, "notLoaded": {"key": "why"}}`
  or `{"state": "failed", "message": "..."}`. `notLoaded` names a save that
  built but would not load in the app, which only the app can know: the
  tool would otherwise go on saying the extension is running. A failed client is tried again
  every few seconds for as long as the tool stays connected, since the tool
  does not ask again while it is: a build broken when the tool started, or a
  key its previous run is still letting go of, loads once it can.
- `{"ok": false, "reason": "unavailable"}`, at any point, just before it
  hangs up because Developer Mode was switched off. The tool says so and
  keeps looking; the app is not listening again until it is back on.
- `{"closed": "disconnected"}` just before it hangs up because the operator
  disconnected the tool in Developer settings. A tool told that stops
  asking; reconnecting at once would undo the operator's disconnect.

The connection is the session: when it closes, that tool's extensions go
and the app runs its own again. A tool whose connection closes without a
`closed` line (the app quit) looks for an app again every few seconds and
asks the one it finds, which asks its operator anew. Once an app has
allowed it, or the author picked it among several, only that app is asked:
another one running while it restarts is likely the operator's logging app.

## The operator's allow

The dialog names the tool, the keys and the folder, all the tool's own
word, and says the extension runs with everything an installed extension
may do until the app quits.

An allow covers that folder serving those keys, for this app session, and
is kept in memory only: a tool restarted on the same project gets back in
without a second question, and nothing outlives the app. Disconnecting the
tool in Developer settings, or turning Developer Mode off, forgets it. A
different set of keys from the same folder asks again.

A deny is said to the tool, which stops asking; its next run asks again.

## Several at once

Each tool allowed gets a dev client of its own, and `ExtensionService`
keeps each one's extensions apart: connecting or disconnecting one tool
replaces only its keys, and a key one server holds is refused to every
other, so two projects never take turns replacing each other's code. A
client takes only the keys its ask named; anything else its server offers
is refused with a reason the Developer settings row shows. The address in
Developer settings is one more server among them.

What a dev extension may do does not change with how it arrived: a release
build still takes no key it already has an extension for, nor a `ham2k-`
one, and no dev-served extension reads a build secret
([in-repo.md](../extensions/in-repo.md#the-dev-server)).

## What it is not

It keeps other machines out, and puts every tool in front of the operator
before its code runs. It does not stop software already running as the
same user, which could as well write to the app's own data; the dialog
says what allowing does, not that the tool is what it claims.
