# Shared operations

> Status: **contract, nothing built on the app side** — [HALO-711](https://cabo.ham2k.com/halo/c/711).
> LoFi already serves part of it (operation-scoped sync, the participant list,
> and an invite flow this retires); §4 marks what exists and what changes.

An operator shares one of their operations with other Ham2K accounts. Those
accounts see it, log into it, or help run it, each at the level the owner
gave them, and every copy of it stays the owner's log: it syncs through the
owner's account, on the owner's plan, and over peer links between the devices
in the room. It never lands in a guest's own account. The single exception is
the end: when the owner declares it over, a guest whose callsign is one of the
operation's station calls may keep a copy in their own account.

This document is the contract between LoFi and HaLo. The screens that drive
it are not designed yet, and nothing here depends on how they look.

## 1. Who is who

| | Is | Carries |
|---|---|---|
| **Owner** | the account the operation belongs to | every right, always |
| **Member** | another account admitted to the operation, by its join code or by the owner or a manager | one level: `watch`, `log`, `edit` or `manage` |
| **Device** | one install of an app, signed in to one account | its own LoFi client, and, per shared operation it holds as a guest, a second client LoFi mints for it |
| **Account tag** | `sha256("ham2k-peer-account:" + account uuid)`, first 32 hex characters | the only form in which a device ever holds another operator's account identity |
| **Device tag** | `sha256("ham2k-device:" + the device's own LoFi client uuid)`, first 32 hex characters | the identity a contact's creator is recorded under (§2) |

Membership belongs to the **account**, not the device: admitting KI2D admits
every device signed in to KI2D, and changing KI2D's level changes it on all of
them.

The account tag is the value `peerAccountTag` already puts in a peer `hello`.
LoFi computes the same function server-side so that the member list it hands
out can be compared against peers without anyone holding a raw account uuid
that is not their own.

## 2. Levels

What each level may do. LoFi enforces all of it; HaLo enforces it locally as
well, so a device never makes a write it knows the server will refuse. A
refused sync record stays dirty for ever.

| | watch<br>viewer | log<br>logger | edit<br>editor | manage<br>manager | owner |
|---|---|---|---|---|---|
| See the operation and its log | ✓ | ✓ | ✓ | ✓ | ✓ |
| Add contacts; edit and delete the ones **this device** created | | ✓ | ✓ | ✓ | ✓ |
| Edit and delete **any** contact | | | ✓ | ✓ | ✓ |
| Change the operation's attributes and refs; add or remove **break** events | | | | ✓ | ✓ |
| Add or remove **start**, **pause** and **restart** events, and the `active` and `paused` statuses they lead to | | | | ✓ | ✓ |
| Approve join requests, change any member's level up to `manage` (managers included), remove any member | | | | ✓ | ✓ |
| Add or remove **end** events, and the `completed`, `processed` and `archived` statuses | | | | | ✓ |
| Start or end sharing, rotate the join code, turn auto-admit on or off, delete the operation | | | | | ✓ |

`edit` is a new LoFi level, between `log` and `manage`.

**The lifecycle is split at the end.** A manager runs the operation: they
may start it, pause it and restart it, and the `active` and `paused` statuses
those events lead to are theirs to write. Declaring the log done is the
owner's. That means the end event and the three statuses on the far side of
it: `completed`, `processed` and `archived` (data-model.md §The Log Data). An
export or QSL upload from a manager's device goes out, but it does not
promote the operation to `processed`.

**Manager and up** is every other attribute on the operation record: title,
refs, callsigns, location, dates, anything an extension keeps there.
Bookkeeping the apps and LoFi stamp themselves — revision stamps, counts,
`sharing` — is not an attribute, and changes on any write. A logger or editor
never writes the operation record at all.

**Events** are contacts with `band: "event"`, so they follow the rows above
rather than the contact rows. A **break** opens a segment and restates its
refs and callsign (contests.md §5.1.3), which makes it an attribute change.

Both kinds of row that open a segment, start and break, are a manager's to
write. So the restamp that follows a manager's change to the refs or the
callsign (contests.md §5.1.3) is theirs too.

### Which device created a contact

A logger's own contacts are the ones **this device** created. Nothing records
that today:
- LoFi keeps the **last** client to write a contact (`updated_by_id`), not
  the first. An editor's fix would take the contact away from the logger who
  made it.
- A contact relayed over a peer link reaches LoFi as the relaying device's
  write.
- HaLo stamps no creator at all.

So every contact names its creator in **`data.createdBy`**: the device tag
(§1) of the device that created it. It never changes afterwards.

- A HaLo device stamps its own device tag on every contact it creates,
  shared or not. A device signed in to no account stamps nothing.
- A contact with no `createdBy` belongs to the owner. That covers everything
  logged before an operation was shared.
- LoFi sets `createdBy` on a contact a **device** client creates, from the
  device it was minted for, whatever the payload says. It keeps what the
  owner's own clients send, because those relay contacts from peer links and
  the stamp arrives with them (§6.4).
- Changing `createdBy` on an existing contact is refused at every level below
  owner.
- A peer names its device tag in its `hello` (`dev`, beside `acct`), so a
  receiving device can hold a logger's edits to the same rule offline.

A reinstall is a new LoFi client, so it is a new device: a logger cannot edit
what they logged before reinstalling. The tag is not the operator either.
`our.operatorCall` says who was at the key; `createdBy` says which device
entered the row.

## 3. The life of a sharing

```
private ──share──▶ shared ──end──▶ ended
                     │
                     └─ rotate code (stays shared)
```

- **private** is every operation that has never been shared, and needs
  nothing new.
- **shared** is the only state that admits anyone: the join code is taken,
  requests are decided, members sync.
- **ended** is terminal. Members' access turns read-only at once and their
  devices remove the operation (§6.7). The owner keeps it as an ordinary
  operation of their own. An ended operation cannot be shared again.

Ending sharing is **not** the operation lifecycle's END. `completed` can be
reopened with RESTART; ending sharing cannot, and a log the owner has only
paused or completed stays shared.

Only the owner starts or ends a sharing, and only from an account-level
permission. A manager's device holds an operation-scoped one and cannot.

**Deleting** a shared operation ends its sharing first, with the same effect
on members.

## 4. LoFi

### 4.1 What a request is made as

Two kinds of credential reach a shared operation, and they answer different
questions:

- **The member's own client**, the one it signs in to its own account with,
  asks the account-level questions: which operations am I a member of, let
  me join this one, give me access to that one, copy it for me.
- **A device client**, minted by LoFi on the **owner's** account for one
  (device, operation) pair, does everything inside the operation: sync, the
  member list, member management. Its permission is operation-scoped (LOFI-14) at the
  member's level. Because it belongs to the owner's account, every
  plan-derived limit it meets — cutoff, cooldown, retention — is the owner's,
  by construction.

A device client has no secret and can never sign in on its own:
`POST /v1/client` refuses one. Its tokens come from `access` (§4.3), asked by
the member's own client, and last as long as any LoFi token. Refreshing one
is asking again. Removing a member revokes every device client they hold, so
their tokens stop working at the next request.

One device client per device, not per account, is what gives each device its
own operation-sync cursor. A member's two devices sharing one would each read
the other's progress as their own.

### 4.2 The operation record

Every read of an operation (REST, sync, push) carries a `sharing` object,
null while private:

```json
"sharing": {
  "state": "shared",
  "since": "2026-09-25T14:00:00Z",
  "endedAt": null,
  "ownerCall": "KI2D",
  "ownerTag": "3f9a…",
  "autoAdmit": null
}
```

`autoAdmit` is `"watch"` when anyone holding the join code is let in as a
viewer without asking, and `null` when every join waits for the owner or a
manager (§5).

It is **server-owned**. A client echoing it back inside `data` changes
nothing, and a client removing it removes nothing. The join code is not in
it: the operation record is pushed to every holder of the channel, and the
code is for the owner and managers to hand out (§4.3).

### 4.3 Endpoints

Paths are under `/v1`. `:uuid` is the operation's. **Own** means the member's
own client, **device** a device client (§4.1), **owner** an account-level
owner permission on the operation's account.

**Sharing — owner**

| | |
|---|---|
| `POST operations/:uuid/sharing` | private → shared. Mints the join code. `{autoAdmit?}`, default `null`. |
| `PATCH operations/:uuid/sharing` | `{autoAdmit: "watch" \| null}`. Turning it on admits every pending request as a viewer, so nobody who asked before the switch waits behind someone who arrived after it. |
| `GET operations/:uuid/sharing` | `{ sharing, code }`. Also open to a `manage` device, who needs the code to show a QR. |
| `POST operations/:uuid/sharing/code` | New join code. The old one stops admitting and taking requests; members and pending requests stand. |
| `POST operations/:uuid/sharing/end` | shared → ended. Terminal. |

**Members — owner or device**

| | |
|---|---|
| `GET operations/:uuid/members` | `watch` and up. `{ owner: {call, accountTag}, members: [ {uuid, call, name, accountTag, level, status, requestedAt, lastSeenAt} ] }`. `status` is `active`, `pending` or `removed`. Pending and removed rows are shown to `manage` and up only. Supersedes `participants`. |
| `PATCH operations/:uuid/members/:member` | `manage` and up. `{level}` changes a level; `{status: "active", level}` approves a request; `{status: "removed"}` removes. A manager may set any level up to `manage`. |

There are no invites. LOFI-16's invite endpoints, `POST invites/:token/redeem`
and the invite expiry sweep are retired; no app ever called them. Their
redemptions become memberships at the level they granted. Every way in is the
join code, and every level above viewer is given by a person after the member
is in.

**Joining and leaving — own client**

| | |
|---|---|
| `GET shared_operations` | Every membership of the caller's account: `[ {operation, member: {uuid, level, status}, copy} ]`, where `operation` is a summary (uuid, title, stationCall, `sharing`) and `copy` is `null`, `"eligible"` or `{operation: <uuid>}` (§4.5). Lists `active` and `pending` rows, plus rows of ended sharings for as long as a copy may still be taken. |
| `POST shared_operations/:uuid/join` | `{code, note?}`. With `autoAdmit: "watch"`, the membership is `active` at `watch` at once; without it, `pending`. Returns the entry `shared_operations` lists, the existing one if there is one, never lowering a level already held. **No token**: the device asks `access` next. Refused when the code is wrong, the operation is not shared, or the account was removed. |
| `POST shared_operations/:uuid/access` | Mints or reuses this device's device client and returns `{token, expiresAt, level, operation, pushChannel}`. Refused unless the membership is active and the operation shared. |
| `DELETE shared_operations/:uuid` | Leave. The account may join again later; a removal by the owner or a manager is not undone that way, auto-admit or not. |
| `POST shared_operations/:uuid/copy` | §4.5. |

**Inside the operation — device**

| | |
|---|---|
| `POST operations/:uuid/sync` | As LOFI-18, with these changes. `watch` may **pull**; anything inbound needs `log`. Each inbound record is held to §2 for the device's level: whose contact it is, which events, and which operation fields. It is refused one record at a time, as today. After the sharing ends, inbound is refused at every level. |
| `GET`/`PUT operations/:uuid`, `…/qsos` | The same per-record rules. Writes are refused once ended. |

### 4.4 Push

Channels stay public-by-name. A removed member who kept a channel name keeps
receiving it, which was accepted with LOFI-7.

| Channel | Event | When |
|---|---|---|
| member's **own account** | `shared_operation` (the `shared_operations` entry) | their membership is created, approved, re-levelled or removed; the sharing ends; a copy is ready |
| **operation** | `operation` (with `sharing`) | as today, and on every sharing change |
| **operation** | `member` (the member row) | a request arrives, a member joins, is approved, re-levelled or removed |
| owner's **account** | `member` | the same, so the owner's devices hear a request when the operation is not open |

### 4.5 Ending and the copy

`sharing/end` makes every device client read-only and stops `access` minting
new tokens. `shared_operations` keeps listing the ended membership, with its
`copy` state, for 7 days.

A member is **eligible** for a copy when their account's callsign, reduced to
its base call, is one of the operation's station calls. Those are the calls in
`data.stationCall` (a comma-separated list) together with the distinct
`our.call` of its contacts. The second half is how LoFi sees a per-segment
callsign (HALO-510): the restamp rewrites a segment's contacts, and LoFi knows
nothing of segments otherwise.

`POST shared_operations/:uuid/copy` from an eligible member's own client
clones the operation and all of its contacts into **their** account under new
uuids. `sharing` is cleared on the copy, and `data.copiedFrom` names the
original operation and its owner's call. The copy reaches every one of their
devices through ordinary account sync. Asking again returns the same copy.

The copy is the whole log, not one call's share. Several calls in one segment
each owe a complete submission (HALO-507), and HaLo's export fan-out already
takes each call's part.

### 4.6 A guard on the other side

`POST /v1/sync` from a member's own client refuses an operation, and any
contact of one, whose uuid is a shared operation that account is a member of.
HaLo never sends one (§6.3). The guard exists so that an older build, or a
bug, cannot make a second copy of somebody else's log inside the member's
account.

## 5. Discovery

Discovery hands out one thing: the **join code**. Holding it lets an account
ask to join, or, with auto-admit on, join as a viewer straight away. It never
grants more than `watch` by itself; `log`, `edit` and `manage` are always a
person's decision, made after the member is in.

| Carrier | Deep link |
|---|---|
| QR shown by the owner or a manager | `com.ham2k:///join?op=<uuid>&code=<code>` |
| A link sent by message | the same |
| LAN beacon | — |

The beacon gains a `share` field — `{op, code, title, call}` — only while the
open operation is shared **and** the device is the owner's or a manager's. An
added field needs no protocol bump (peer_protocol.dart).

**Auto-admit and the beacon together** let anyone nearby with a Ham2K account
watch the log. That is the point of it for a public event, and the setting's
wording has to say so. Auto-admit is off unless the owner turns it on, and
only the owner can.

The code is 32 hex characters. It travels by QR, link and beacon and is never
typed, so it is not a guessing target. A short code someone could read aloud
would need rate limiting on `join` first, with auto-admit in front of it.

A join code needs an account: a viewer shows up in the member list by
callsign. Watching with no account at all is a different idea, LOFI-31's
spectator link.

HaLo has no QR scanner. A code is read by the phone's camera and arrives as a
deep link, as `link_client` does today.

Joining needs LoFi reachable from the joining device, and admission over a
peer link needs the owner's (or a manager's) device to have fetched the member
list since then (§6.6). A site with no internet at all keeps working for the
members it already has and takes no new ones.

## 6. HaLo

### 6.1 What a device keeps

The operation itself and its contacts live in the ordinary `Operations` and
`Qsos` tables, whatever their origin, so every view, export and scorer works
on a shared operation unchanged.

A new device-local table, **`SharedOperations`**, never synced, holds one row
per operation this device holds a sharing role in:

| Column | |
|---|---|
| `uuid` | the operation |
| `role` | `owner` or `member` |
| `level` | the member's level; null for the owner |
| `memberStatus` | `active`, `pending`, `removed` |
| `state` | `shared` or `ended` |
| `ownerTag`, `ownerCall` | from `sharing` |
| `members` | the cached member list: `[{accountTag, call, level, status}]` |
| `membersFetchedAtMillis` | when that list was last fetched |
| `copy` | `null`, `eligible`, `taken`, `declined` |

A `pending` row with no operation behind it yet is a request waiting on an
answer. The home screen's separate bucket is the rows with `role = member`,
and the ordinary list excludes them.

Tokens are never persisted. The `ham2k-lofi` extension already keeps its own
token in memory and re-registers on launch; device tokens follow it, asked
from `access` on first need and again when refused.

### 6.2 The write gate

`WritePolicy` is already the single place a write is refused, and a shared
operation is the reason it was built for. For an operation with a `member`
row it refuses:

- everything, when the row is `ended` or `removed`, or the level is `watch`;
- at `log`, a change to a contact whose `createdBy` is not this device's;
- below `manage`, any write to the operation record, and adding or removing
  any event;
- below owner, an end event, and the `completed`, `processed` and `archived`
  statuses.

The owner's own devices meet no new refusal.

**Writes the app makes on its own** are skipped on a member's device, not
refused. HALO-460's lifecycle sweep, the revert to `active` when a contact
arrives, and the promotion to `processed` after an export are the owner's
device's job (data-model.md §The Log Data).
`WriteRefused` exists to reach an operator who asked for something. Raising it
from a background pass would surface an error nobody caused.

### 6.3 Sync

- **Account sync** never selects a `member` operation, or a contact of one.
  That filter, in `unsyncedBatch` on both tables, is what keeps the log out of
  the member's own account. It is not a check at the push.
- **Operation sync** runs a round per active `member` row, through a new
  transport call, with its own cursor kept per operation. It pushes this
  device's own writes at `log` and up (§6.4), and pulls at every level.
  Inbound records go through `mergeFromSync`, as account sync's do.
- **Membership refresh** reads `shared_operations` at each loop, and whenever
  a `shared_operation` event arrives, and brings `SharedOperations` in line.
  The owner's device, and a manager's, read `members` for each shared
  operation they hold, so the cached list peers are checked against stays
  current.

### 6.4 Who uploads

In a room of peers that all have internet:

- **Every device uploads the changes it made itself.** A member's device
  uploads through its device client; the owner's devices upload through the
  owner's account.
- **The owner's devices also upload everything they received from peers**,
  exactly as the owner's own devices relay for each other today. Their
  uploads go into the owner's account, where the log lives, and LoFi accepts
  them at owner level. That is why the owner's device holds every record to
  its sender's level on the way in (§6.6).
- **A member's device never relays.** What it receives over a peer is merged
  clean (`synced: true`), and only its own later edits mark a row dirty.
  Relaying would push a record LoFi judges by the relayer's level: a
  logger's device uploading someone else's contact would be refused, and a
  refused record stays dirty for ever.

So a contact normally reaches LoFi twice: once from the device that made it,
and once from each of the owner's devices in the room. LoFi treats an upload
equal to the revision it holds as a no-op, not a rewrite, so the second copy
costs a request and nothing else. Without that, every duplicate would
re-stamp the row, send a push, and make every other device pull it again.

A member with no internet still reaches LoFi, through any of the owner's
devices that has it. When only members are online, each member's own
changes go up, and everything else waits for the owner's device.

### 6.5 Push

Today only the Sync panel listens to the account channel, and nothing listens
to an operation's. Sharing needs both at the service level:

- the device's **own account** channel for `shared_operation` and `member`;
- the **operation** channel of every operation with a `SharedOperations` row
  in `shared` state, for `operation`, `qso`/`qsos` and `member`.

An event starts a sync round for its target at once. It is never applied
as data: sync stays the only thing that writes.

### 6.6 Peer links

A peer's identity is the account tag in its `hello`. For a shared operation, a
peer is admitted by comparing that tag with the owner's tag and the cached
member list:

| This device receives operation X from the peer when | This device serves X to the peer when |
|---|---|
| the peer is on the same account (as today), or X has a `SharedOperations` row, the peer is the owner or an active member at `log` or up, and this device's own role in X is not `ended` or `removed` | the same, with `watch` or up |

- **An operation this device has never seen** arrives from another account
  only when `SharedOperations` already says this device is an active member
  of it. LoFi admitted the member; the peer link only carries the data. A
  member approved while the owner's device sits on a slow link gets the log
  from the room rather than from the server.
- **An unshared operation** no longer flows between accounts at all. HALO-365
  let a foreign peer feed an operation both devices already held, pending "a
  consent step that does not exist yet". Membership is that step.
- **Each record is held to the sending peer's level** (§2), exactly as LoFi
  holds a device's writes, with the peer's `dev` tag standing in for LoFi's
  device client. This matters most on the owner's device: what it takes from a
  peer goes up through the owner's own account, and LoFi accepts anything from
  there (§6.4). A logger's edit to someone else's contact is dropped where it
  first lands, and no later hop can launder it.
- **What a member's device receives** over a peer is merged clean, and never
  uploaded from there (§6.4). On the owner's device it is merged dirty, as
  today, and goes up through the owner's account.
- An `ended` or `removed` row stops both directions for X immediately.

The trust-on-first-use device confirmation stays in front of all of it.

### 6.7 Ending, removal and the copy

When a device learns that its membership is `removed`, or that the sharing
has `ended`:

1. The operation turns read-only at once (§6.2), and peers stop (§6.6).
2. If the sharing ended and LoFi says `copy: "eligible"`, the operator is
   offered the copy. Taking it calls `copy`; the new operation arrives
   through account sync like any other.
3. Once the operation is not open, and any copy offer has been answered, the
   device **purges** it: the operation, its contacts, its peer cursors and
   events, and the `SharedOperations` row. This is a local removal, not a
   tombstone. Nothing about it syncs anywhere, since the log is still the
   owner's.

A removed member is offered no copy.

### 6.8 Transport calls

New `syncTransport` calls, all optional so older transports keep compiling:

| Own client | Device client |
|---|---|
| `listSharedOperations`, `joinSharedOperation`, `leaveSharedOperation`, `copySharedOperation` | `syncSharedOperation(uuid, payload)`, `listMembers`, `updateMember`, `getSharing` (at `manage`) |
| owner only: `startSharing`, `setAutoAdmit`, `getSharing`, `rotateJoinCode`, `endSharing` | |

Device tokens stay inside the extension: the core names an operation, and
the transport works out which credential to present.

## 7. Accepted limits

- **The account tag is self-asserted.** A `hello` crosses before trust, so
  anything on the segment can read a member's tag and replay it. What stands
  between a spoofer and a member's log is the device confirmation. That is the
  v1 posture peer_protocol.dart already states for the LAN, and sharing does
  not extend it to anything wider.
- **A removed member keeps any push feed they subscribed to.** Every read and
  write refuses them.
- **Joining needs the internet** (§5).
- **With auto-admit on, whoever holds the code can watch.** A code that
  travels further than meant admits viewers until the owner rotates it or
  turns auto-admit off. Rotating removes nobody already in.
- **Last write wins**, as between any two devices today. On the operation
  record that is between the owner and managers; on a contact, between its
  author, editors, managers and the owner.
- **`createdBy` is as good as the device tag.** A device can't claim another
  device's contacts through LoFi, which stamps the tag itself. Over a peer
  link, a spoofed `dev` in a `hello` (above) claims them too.

## 8. Build order

LoFi first, since HaLo has nothing to call until it exists.

1. **LoFi — members and device access.** A member record per (operation,
   account), device clients minted per (device, operation), and `access`,
   `shared_operations`, `leave`. Retires the shipped invite flow, whose
   single client per account has no secret and a 24-hour token, and turns its
   redemptions into members. `POST /v1/client` refuses a device client. The
   `edit` level, between `log` and `manage`, since every later step grants
   it.
2. **LoFi — sharing and joining.** Sharing state, join code, auto-admit,
   `join`, member management by managers (with the escalation rule that
   allows it), push on the member's own account channel.
3. **LoFi — the per-record rules.** `createdBy` stamped from the device
   client and kept; the
   event and operation-record rules of §2 on every write path; an upload
   equal to the stored revision is a no-op (§6.4). This replaces LOFI-19's
   `OWNER_ONLY_DATA_FIELDS` with the end-of-lifecycle statuses as owner-only
   and a manager floor for everything else.
4. **LoFi — watch pull, end, copy, and the §4.6 guard.**
5. **HaLo — the transport calls, `SharedOperations`, `createdBy` on every new
   contact, the write gate.**
6. **HaLo — sync routing, push subscriptions, membership refresh.**
7. **HaLo — peer admission, `dev` in the `hello`, per-record checks, clean
   merges on a member's device, and the beacon's `share` field.**
8. **HaLo — end, removal, purge.**

Then the screens.

## 9. Open

- **Owner identity for every operation.** HALO-460 wants an owner recorded on
  all operations, not only shared ones, and took its first attempt out.
  `sharing.ownerTag` answers it for shared operations. Whether unshared ones
  should carry the same tag is HALO-460's call.
