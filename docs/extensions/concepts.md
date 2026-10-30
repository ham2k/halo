# How extensions run

This page is the mental model the reference pages assume: what the sandbox
is, how a bundle comes to life, what a hook is, what the host is, where an
extension keeps things, and what the budgets are. Read it once before the
reference, and come back to it when something behaves in a way the reference
did not prepare you for.

## The sandbox

An extension is one script, evaluated by one ES2020 engine inside the app.
Natively that engine is QuickJS-NG; in the web build it is the browser's
own, inside a Worker. Either way:

- There is **no Node, no DOM, no `window`, no `fetch`, no filesystem**. The
  outside world is reached through `host`, the object `@ham2k/extension-sdk`
  exports, and only through it.
- **Everything in and out is JSON.** A hook receives plain objects and returns
  plain objects. A value JSON cannot carry (a `Date`, a `BigInt`, a circular
  structure, a function) fails the call it travels in.
- **`Intl` does not exist** on native builds, and the fallbacks are silent:
  `toLocaleString` runs but ignores its options. Format numbers and dates
  yourself, in UTC. [Text and locale](localization.md) says how.
- **The engine's own timers are gone.** `host.setTimeout` and friends are the
  only timers, and they are budgeted. From extension API 3 the build points a
  bare `setTimeout` at them too, so a library that schedules work still
  works.
- Each bundle carries **its own copy of the SDK**. The libraries the app
  shares (`@ham2k/lib-*`, `i18next`, `liquidjs`) live once, in the kernel, and
  a bundle that declares them reaches that one copy.

## From file to running code

The app evaluates the **kernel** first, then every extension bundle, then
activates them all. Your `index.js` runs once at evaluation; its one job is
to call `defineExtension`, which registers your definition and nothing more.
Activation comes after every bundle has been evaluated, so the order bundles
load in never matters, and nothing in your module scope may depend on another
extension or on the host.

```ts
defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("lookup", { hook: MyLookup, priority: 50 })
    registerHook("ref:w7abc-lakes", { hook: MyRefHandler })
  },
  onShow() { /* the app came back into view */ },
  onHide() { /* the app went out of view */ },
})
```

`onActivation` is where hooks are registered. It is called on your own
definition object, so state you keep on `this` at activation is there for
`onShow` and `onHide` later. It may be `async`: the app waits for it to
settle, whatever it awaited included, before it treats the runtime as
started, so a hook registered after an `await host.getSettings()` is in
place for the first call. Register what needs no read first all the same.
The build's activation check runs your bundle against a stand-in host whose
timers never fire, and an activation that waits on one makes that check time
out and warn.

`onShow` and `onHide` fire when the app comes into view and goes out of it,
and only on a change. `onHide` also fires as activation completes if the app
is hidden by then, so an extension always learns the state it starts in; one
whose activation failed hears neither, and the timers it set while
activating are cancelled. The app does not pause your timers while hidden,
though the platform may; work worth doing only while someone can see it
stops and starts here.

**The runtime restarts** whenever the set of running extensions changes: an
extension installed, updated, enabled or disabled. A restart evaluates every
bundle again and runs every `onActivation` again. Your open sockets are closed
without an `onclose`, your timers are cancelled, and what you kept in module
scope is gone, and so is the key-value store. What the app holds for you
survives: settings, credentials, panel configuration. Open sockets and set
timers from `onActivation`, never only from module scope.

## Hooks

A hook is an object whose methods the app calls. You register it under a
**category** (`lookup`, `panel`, `scoring`…) with an optional **key** and an
optional **priority**:

- The key defaults to your extension's key. Where you register several hooks
  in one category, each key is your key or your key followed by `_` and a
  suffix. The key is what the app shows when it says where something came
  from, and what addresses storage that belongs to the hook.
- Priority orders hooks within a category. Higher runs first; the default
  is 0.

The app invokes hooks three ways, and which one a category uses is stated on
its reference page:

- **The best hook**: the highest-priority registration under the category, or
  the one with the key the app names. A reference handler is reached this way.
- **Every hook in the category**, in one round trip, each answering on its
  own. Spot sources and command interpreters are reached this way.
- **A batch of single calls**, in one round trip, each reaching the hook it
  would reach alone. Reference decoration is batched.

Every method has the shape `async method(args, ctx)`. `args` is what the
page documents for that method; `ctx` is the [hook context](host.md#the-hook-context),
the same for every hook: whether the device is online, the locale, the
operator's number and date conventions, and reads into the log and the spots
board.

Three rules follow from the bridge:

- **A hook that throws costs only itself.** Other extensions' answers stand,
  and the error is reported against your key. Throw for a bug. For an
  expected condition (not configured, not found, offline with no local data)
  return the empty answer the page names, usually `[]` or `null`.
- **A hook that hangs costs more.** The app times out the whole fan-out, not
  your hook alone. A caller that asked for partial results keeps what the
  other hooks returned and is told which went quiet and which answered with
  an error, as separate lists; any other caller gets an error and nothing.
  Bound every optional network request with
  `host.fetch`'s `timeout`, and keep the per-keystroke paths cheap:
  `lookup`, a command's `interpret`, a panel on the `qso` trigger.
- **Method names are routed by string.** The app finds your hook by key and
  calls the method by name, so `renderPanel` where `render` was meant is an
  extension that installs, activates, and does nothing. Type every hook with
  its SDK interface (`PanelHook`, `LookupHook`, …) and `tsc` catches it.

The categories are a closed list; [How hooks work](hooks.md) has it.
Extensions may also call each other's hooks inside the runtime, with no
bridge crossing, through `hooks.invokeAll`, `hooks.invokeOne` and
`hooks.invokeForRefs`; [The host API](host.md#calling-other-extensions) says
when.

## The host

`host` is how an extension reaches the app: network, timers, storage,
settings, dialogs, the status bar, the radio, the DX cluster, the log of
calls it keeps. Every call crosses to the app and is answered, and every
call is budgeted. The budgets are refused at the call that would exceed them,
never queued and never quietly dropped, so a runaway loop fails where it
runs and the error names the budget.

| Resource | Budget |
| --- | --- |
| Host calls awaiting an answer | 32 per bundle, 256 across every extension |
| `host.fetch` in flight | 8 per bundle; a ninth is refused, not queued |
| Key-value storage | 10 keys per bundle, each key plus value at most 4,096 characters of JSON |
| Status bar | 8 keys per extension; strings at most 1,024 characters; updates reach the footer at most every 100 ms |
| Notices | 10 a minute; text at most 16,384 characters |
| Dialogs (`showForm`, `showMessage` as a dialog) | one extension's at a time; 3 open, 3 waiting, 10 a minute |
| WebSockets | 4 per extension; 1 MiB per frame; 12 opens a minute per bundle |
| Timers | 16 live; callbacks average at most 10% of real time, with 5 s of burst |
| Radio commands | 4 of yours queued at once; one that cannot go out within 2 s expires |
| Panel content | 262,144 characters of markdown, 1,048,576 of SVG, 4,194,304 of HTML |

[The host API](host.md) has every call and the rule behind each budget.

## Identity and storage

Your extension's **key** is `<yourcallsign>-<name>`, lowercase. It is a
namespace you already hold, so two authors who never met cannot collide, and
the app leans on it everywhere:

- key-value entries, the settings group (`extension_<key>`), footer keys and
  notices are namespaced to it, invisible to other extensions;
- panels are addressed as `ext:<hook key>:<panel key>`, and that id is what a
  saved layout stores;
- an account's `kvKey`, a settings panel's key and a chasing program's key
  are your key or your key plus `_suffix`.

There are four places to keep things, and they are not interchangeable:

| Where | Call | Lives | For |
| --- | --- | --- | --- |
| Key-value store | `host.kvGet` / `host.kvSet` | in memory, for the session; a runtime restart clears it | session state: a token, a cursor, a cache of one answer |
| Settings | `host.getSettings` / `host.setSettings`, a `settingsPanel` | persisted by the app, shown to the operator | preferences, anything the operator should be able to see and change |
| Account credentials | the `account` hook | the platform keychain | logins, API keys the operator owns |
| Panel configuration | a panel's `form` | persisted per placed panel | what one pane shows |

`host.secret()` reads a value built into the app, and answers `null` for an
installed extension whatever key it claims. Nothing you ship can depend on
one.

Updating an extension keeps everything it stored. Removing it removes
everything it stored.

## Capabilities and consent

What an extension may reach is declared in its manifest and shown to the
operator before they install it: the hosts `host.fetch` may call
(`domains`), the hosts it may hold a socket to (`webSockets`), and the
capability grants (`requiresLocation`, `requiresRadioRead`,
`requiresRadioWrite`, `requiresRadioRaw`, `requiresClusterRead`,
`requiresClusterSpot`, `requiresClusterCommand`, `requiresSettingsWrite`).
An undeclared call is refused where it is made, not at build time, so an
extension that reaches for something it did not ask for fails in front of
the operator. Declare the least you need: the consent screen names every
item. [The manifest](manifest.md) lists them all.

## API levels

The extension API is numbered. Each level adds calls, hook methods, scene
features or manifest fields. Your manifest declares `api`, the lowest level
that has everything you use, and:

- an app that speaks an older level refuses to install the bundle, and says
  so, rather than failing deep inside a hook;
- the catalog offers each app the newest release it can run;
- the packer refuses a manifest whose features outrun its declared level
  where it can tell: `webSockets` needs 2, a `chasing` hook needs 9, a
  cluster grant or a `cluster` hook needs 10, `requiresRadioRaw` needs 11.

The SDK's minor version is the API it describes, and `API_VERSION` exports
it. [Packaging](packaging.md#api-levels) lists what each level added.

## When your code runs

- **Hooks run on demand**, when the app has a question: a callsign typed, an
  export requested, a panel due to render.
- **Panels render on triggers** you declare, with at least 750 ms between one
  render finishing and the next starting, and never while the panel is behind
  another tab or the app is hidden.
- **Timers and socket callbacks run outside any hook call.** There is no
  `ctx` there; what they need from the host they ask the host for.
- **Only a callback's synchronous part is measured** against the timer
  budget. What happens after an `await` runs later, where nothing can tell
  whose work it is.

## Failure

- A hook that throws: reported against your extension; the feature it serves
  does nothing for that call; everything else continues.
- A bundle the engine will not evaluate (a syntax error, a top-level throw)
  would take the whole runtime down, so the app puts it aside, restarts
  without it and tells the operator; the Extensions panel marks it, and an
  update is the way back.
- A timer budget broken: your timers are suspended until the runtime
  restarts; your hooks keep working.
- A socket refused: `onerror` then `onclose` with code 1006, never a throw.

`host.log(message)` writes to the app's debug output, prefixed with your key.
A desktop build prints it to the terminal it was started from, which is the
quickest way to watch an extension while you work on it.
