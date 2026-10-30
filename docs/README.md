# Documentation index

## Getting started

- [CONTRIBUTING.md](../CONTRIBUTING.md) (repo root) — how a change from
  outside gets in: setup, the gate, the pull request, what it needs to carry,
  and what the maintainer does with it.
- [DEVELOPMENT.md](../DEVELOPMENT.md) (repo root) — environment setup, running
  and building per platform, tests, the build-time/runtime flags (`HALO_EDITION`,
  `ONBOARD_AS`, …), and the developer commands typed into the call field.

## Architecture and design

- [DESIGN.md](../DESIGN.md) (repo root) — the architecture: core split, extension
  runtime, data layer, UI modules, risks. Start here.
- [design/user-interface.md](design/user-interface.md) — UI concepts, views,
  panels, logging controls, branding.
- [design/logging-fields.md](design/logging-fields.md) — the logging controls'
  three parts, and the focus and keyboard-navigation rules for the main
  logging fields. **Read before changing anything about focus in the logging
  panel.**
- [design/ui-scaling.md](design/ui-scaling.md) — how the Font Scale setting
  scales the whole UI, and the rules that keep it working. **Read before any
  scaling-, layout-, or macOS-window-related change.**
- [design/error-reporting.md](design/error-reporting.md) — what happens to an
  escaped exception: the four dispositions, the one place that decides between
  them, and how to add a rule. **Read before adding any "ignore this error"
  check.**
- [design/telemetry.md](design/telemetry.md) — event tracking, its consent
  gate, and the event vocabulary.
- [design/contests.md](design/contests.md) — **RFC (draft):** the core
  infrastructure needed to port app-polo's contest extensions, and the porting
  sequence. Open questions at the end need decisions before M0 starts.

## Extensions

The pages under `extensions/` are the extension authors' documentation,
shipped inside `@ham2k/extension-sdk` and published on catalog.ham2k.net;
they are written for an author with the SDK from npm.

- [extensions/README.md](extensions/README.md) — the overview, the reading
  path and the index of every page.
- [extensions/concepts.md](extensions/concepts.md) — how extensions run: the
  sandbox, activation, hooks, the host, budgets, API levels.
- [extensions/manifest.md](extensions/manifest.md), [extensions/host.md](extensions/host.md),
  [extensions/hooks.md](extensions/hooks.md) — the manifest, the host API and
  the hook context, how hooks work; then one page per hook group.
- [extensions/packaging.md](extensions/packaging.md), [extensions/publishing.md](extensions/publishing.md)
  — the bundle, the build, keys, API levels; the catalog.
- [extensions/agents.md](extensions/agents.md) — the suggested `AGENTS.md`
  for an extension project; the SDK build ships it as the package's own.
- [extensions/in-repo.md](extensions/in-repo.md) — **for contributors to this
  repository:** the extensions workspace, the dev server, `halo-ext`, the
  test harness, build secrets, pre-loads.
- [design/extension-install.md](design/extension-install.md) — the app's side
  of installed extensions: pre-loads, the retired built-ins, tracks,
  pulling, replacement, the store.
- [design/extension-docs.md](design/extension-docs.md) — how the extension
  docs are written: audience, voice, where each fact lives, and what the
  guard test refuses. **Read before changing a page under `extensions/`.**

## Shipping

- [releases.md](releases.md) — versioning, distribution, and update
  architecture across all platforms (binary / Dart patch / JS extension planes).
- [deployment.md](deployment.md) — runbook for building and deploying the web
  version to Cloudflare Pages.

## Keeping it working

- [maintenance.md](maintenance.md) — what to check periodically and how each
  item fails if nobody does: pinned upstreams (quickjs-ng), reference data,
  certificates and tokens, build expiration, toolchain pins.

## Work tracking

- [backlog.md](backlog.md) — known issues, planned features, and larger TODOs
  not yet turned into [CaBo](https://cabo.ham2k.com/halo) cards.

## History

Records of completed work phases (spike-01, phases 2–5) and the 2026-07-14
architecture review were removed from the tree on 2026-07-15 — everything
still actionable in them was extracted into [backlog.md](backlog.md). The
files remain retrievable from git history under `docs/`.
