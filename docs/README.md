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

- [extensions/README.md](extensions/README.md) — what extensions are, anatomy,
  host API, build and dev loop.
- [extensions/hooks.md](extensions/hooks.md) — the hook reference, linking a page
  per group of hook categories.
- [extensions/scenes.md](extensions/scenes.md) — panel scenes.
- [extensions/radio.md](extensions/radio.md) — radio control.
- [extensions/forms.md](extensions/forms.md) — the form description schema.
- [extensions/settings.md](extensions/settings.md) — settings panel hooks.

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
