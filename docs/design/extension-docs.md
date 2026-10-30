# Writing the extension docs

`docs/extensions/` is the documentation extension authors and their coding
agents read. It ships inside `@ham2k/extension-sdk`, pinned to the SDK
version beside it, and on [catalog.ham2k.net](https://catalog.ham2k.net/docs).
This page is the contract for anyone who changes it: who it is for, how it
sounds, where each kind of fact lives, and what the guard test
(`extensions/docs.test.ts`) refuses.

## Who reads it

An author with `@ham2k/extension-sdk` and `@ham2k/extension-tools` from npm
and no checkout of this repository, and the agent writing code beside them.
They can read `dist/index.d.ts`, the samples, and these pages. They cannot
read `app/`, `packages/`, the kernel, or a design doc, so a page never sends
them there. The one exception is `in-repo.md`, written for a contributor
working in this repository; it is on the site and not in the package.

Two kinds of reader, one text: a person reads a page top to bottom once and
comes back for one section; an agent reads the section for what it is doing
and takes every sentence literally. Write for the literal reader and the
first is served too.

## How it sounds

- **Second person, present tense.** "You return", "the app calls", "the
  packer refuses". Never "we", never "will".
- **A constraint is a rule with its number.** "At most 8 in flight; a ninth
  is refused, not queued." Not "a reasonable number of requests".
- **State what is true now.** No dates, no "planned", no "used to", no issue
  or card references, no comparison with other apps. Git blame holds the
  history; these pages hold the contract.
- **Name the consequence, not the implementation.** "A hook that throws takes
  its feature down for that call" says what an author needs; which Dart
  service catches it does not.
- **One term per thing.** The vocabulary below. An agent that reads "the
  host" in one paragraph and "the runtime" in the next looks for two things.
- **Short sentences, no ornament.** A reference page is read under pressure,
  by someone who has a failing extension in front of them.

Two paragraphs that sound right:

> `host.fetch` reaches only the hosts your manifest's `domains` lists, over
> https. An undeclared host is refused at the call, not at build time. At
> most 8 fetches per bundle are in flight at once; a ninth is refused rather
> than queued, so a `Promise.all` over a long list fails past the eighth. Run
> them in batches.

> Return `[]` for "cannot answer": not configured, not found, offline with no
> local data. Never throw for an expected condition; a hook that throws takes
> its feature down for that call.

And one that does not, with each reason:

> ~~As of October the lookup pipeline (HALO-752) now settles the guess the
> way PoLo does — see `resolveGuess.ts` in `extensions/core/lookups`; the
> old behaviour used to drop the state. 🔜 A future change may revisit
> this.~~

A date, a card reference, a comparison with another app, a repo path, history
and a plan, in two lines. The guard refuses each of them.

## The vocabulary

| Say | Not |
| --- | --- |
| the app | HaLo, the host app, Flutter, the Dart side |
| the operator | the user (except where the app's UI says "user") |
| you, your extension | the developer, the author, the hook author |
| the host, `host.*` | the bridge, the host API object |
| the runtime | the sandbox engine, QuickJS (name the engine only where it matters) |
| the kernel | the shared runtime, `__polo` |
| a hook, a hook category | a handler, a plugin point |
| the packer | `h2kext-pack`, the validator (name the command only in a command line) |
| the catalog | the store, the registry |
| extension API n, "(extension API n)" | version n, v7, API level 7 |
| a bundle, a `.h2kext` | a package, an archive, a plugin |
| the key-value store | KV, kv storage |
| a reference | a ref (in prose; `ref` in code is fine) |
| a contact, a QSO | a log entry |

## Where a fact lives

One home per fact, and the other pages link to it:

| Fact | Page |
| --- | --- |
| A `host.*` call, its arguments, its budget | `host.md` |
| A field of the hook context (`ctx`) | `host.md`, *The hook context* |
| A manifest field, a grant, the packer's rule for it | `manifest.md` |
| What a hook category does, its methods, what it receives and returns | the category's page under *Hook reference* |
| How hooks are registered and invoked, the category list | `hooks.md` |
| A form element or field type | `forms.md`; what settings panels add to it in `settings.md` |
| A scene field, control kind, radio value | `scenes.md` |
| What an API level added | the table in `packaging.md`, one row per level |
| The build, the bundle format, keys | `packaging.md` |
| The catalog: tokens, channels, review, what the app does after | `publishing.md` |
| Translating strings, numbers, dates | `localization.md` |
| A budget's number | where the call is documented, and the summary table in `concepts.md` |
| The app's own handling of installed extensions | `docs/design/extension-install.md`, not these pages |
| The dev server, `halo-ext`, the harness, build secrets | `in-repo.md` only |

A feature gated by an API level says so where it is documented, as
"(extension API n)" or "API n", and the level's row in `packaging.md` names
it. Both, every time: the marker tells an author whether their declared level
has it, the row tells them what raising the level buys.

## The skeleton of a reference section

Every hook category, and every host call with more than a line to say, has
the same parts in the same order. A reader learns the shape once.

```markdown
## `category`

**For:** one sentence, what an extension uses it for.

**Called:** when the app calls it, by which shape (one hook, every hook, a
batch), and how often; what triggers it.

(the interface, as a TypeScript block, with the argument and result shapes
as comments)

**You receive** … **You return** … (or a bullet per method)

**Rules:** a bulleted list, each a rule with its number or its consequence;
the ones a careful author would get wrong first.

**Example:** a short code block where the shape is not obvious, then a
pointer to a sample or a published extension.
```

Lead with the common case. Put the exception after the rule it excepts.
Prefer a bullet per rule to a paragraph of rules.

## Adding or changing a page

A page is read from three places, and a new or renamed page is added to all
three in the same change:

1. `extensions/sdk/build.mjs`, the `shippedDocs` list (or the test's
   `NOT_IN_PACKAGE` list for a page that stays out of the package). The build
   rewrites a relative link that leaves `docs/extensions/` into a GitHub URL;
   a link with a title or a reference-style definition fails it.
2. The catalog's `src/web/docs/nav.ts`, which maps each file to a slug, a
   title and a group. The catalog lands that change only together with a
   docs sync after the page is on the public mirror.
3. The index in `README.md` and the reading path, where the page belongs.

Links between pages are relative (`host.md#the-hook-context`); the anchor is
the heading's GitHub slug, and the guard checks it. Keep a heading that an
anchor points at; the anchors in use are `grep -rn "\.md#" docs/extensions`.
Links out of the directory are relative repo paths
(`../../extensions/samples`), which both consumers turn into GitHub links.

## What the guard refuses

`extensions/docs.test.ts` runs with the extensions' tests and fails on:

- a host call, hook category, manifest field, hook-context field, scene
  control kind or radio value that no page names in a code span;
- an API level up to the current one without its row in `packaging.md`, or
  a page naming a level the SDK does not have;
- a settings section in the pages that is not the packer's, or one of the
  packer's the pages leave out;
- a page the SDK build neither ships nor names as left out;
- a relative link to nothing, an anchor naming no heading, a link form the
  shipping rewrite cannot follow;
- in prose (code spans and blocks aside): a date, an issue or card
  reference, a comparison with another app, a status marker, "used to",
  "previously", "not yet implemented", "Implemented by", and, outside
  `in-repo.md`, a path into `app/`, `packages/` or a `.dart` file.

It cannot tell a true sentence from a false one. That is the reviewer's job,
and the SDK source (`extensions/sdk/src`) is the reference to check against:
`index.ts` for the host object, `types.ts` for the interfaces and the
manifest, `hookCategories.ts`, `panelScene.ts`, and `tools/h2kext.mjs` for
what the packer refuses.

## When the surface changes

A change to any of these lands with its sentence in the same commit, and the
guard holds the first five:

- a method on the `host` object → `host.md`, with its budget and its grant;
- a hook category, or a method on a hook interface → its page, in the
  skeleton above;
- a manifest field or grant → `manifest.md`, and the consent-screen line
  if the operator sees it;
- a scene field, control or value → `scenes.md`;
- an API level → a row in `packaging.md` saying what it adds, and the
  "(extension API n)" marker on each feature it gates;
- a budget or limit → the number where the call is documented and in
  `concepts.md`'s table;
- a packer rule → `manifest.md`'s *What is checked, and where*;
- a sample → the samples table in `README.md`, `getting-started.md` and
  `agents.md`, and the SDK build's `shippedSamples`.

`agents.md` is the condensed version of all of it. A rule an agent must know
before writing code (a budget, a grant, a trap) earns a line there too.
