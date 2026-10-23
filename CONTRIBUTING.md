# Contributing to Ham2K Logger

This is the whole path for a change from outside the project: how to build
and test, how to propose it, what it needs to carry, and what happens after.

## The two repositories

Development happens in a private repository whose history is filtered into
the public one, `ham2k/halo`, which is the one you are reading and the one a
contribution goes to. There is no issue tracker in either repository that an
outside contributor writes to: the project's tasks live in a private tracker,
and the maintainer files what comes in. So:

- **A change** is a pull request on `ham2k/halo`.
- **A bug or an idea without a patch** is an issue on `ham2k/halo`. Say what
  you expected, what happened, on which platform and build, and what you did
  to get there. Settings → About shows the version, and tapping that row
  copies the full details for pasting.

## Setting up

```sh
mise install && mise trust && mise run setup   # tools, extension bundles, JS engine, deps
cd app && flutter run -d macos                 # or any other device
```

Setup prepares the generated recorder dependencies before resolving the app.
Windows builds prepare recorder sources automatically during CMake configuration.
For direct analysis/tests or native builds on other platforms, run
`mise run prepare-record` first and again after pulling recorder changes. The
[dependency setup notes](DEVELOPMENT.md#patched-recorder-dependencies) include
the equivalent Windows PowerShell command.

[DEVELOPMENT.md](DEVELOPMENT.md) covers the environment, running on each
platform, the flags that skip onboarding (`ONBOARD_AS`) and label a build
(`DEV_LABEL`), and the developer commands typed into the call field.
[DESIGN.md](DESIGN.md) is the architecture; [docs/README.md](docs/README.md)
indexes the design documents, several of which are contracts you read before
touching their area (the logging fields' focus rules, UI scaling, error
handling, the app clock, locations).

## The gate

```sh
./scripts/test.sh
```

That run — every package analyzed and tested, the extensions typechecked and
tested, the browser-platform tests — is the only place the suite runs. The
Checks workflow on a pull request runs the cheap half (`--quick`: the
source-scanning guards, the extensions' typecheck, `dart analyze`), and
nothing on GitHub runs the tests. A green local run is the evidence, so run
it before you open the PR, and say in the PR that you did.

For the inner loop, `./scripts/test.sh --list` shows the groups and
`./scripts/test.sh --changed` runs the subset your diff touches.

## What a change carries

- **Tests that encode why.** A test states the failure it exists to catch, not
  the assertion; a test that cannot fail when the logic changes is not one.
  New app tests go in `app/test/<group>/` (a group is a directory) and start
  from the harness in `app/test/support/` — DEVELOPMENT.md's "Writing an app
  test" shows the shape.
- **The rules in [.agents/AGENTS.md](.agents/AGENTS.md).** They are written
  for the agents that do much of the work here, and they bind a human just
  the same: surgical changes, no speculative abstractions, comments that state
  constraints rather than history, the design-document contracts, and never
  `DateTime.now()`.
- **Strings in both languages.** A user-facing string is an edit to `en` and
  `es` in `packages/halo_i18n`, then regenerated there (its README says how);
  the gate fails on a stale output.
- **A tester note, if a tester has something new to try.** One line of about
  ten words under the `upcoming` key of `app/assets/tester-notes.yaml`, in
  the same commit; most changes get none. [docs/releases.md §2.7](docs/releases.md)
  is the spec.
- **A commit message that reads on its own.** The title states the outcome —
  what is now true — and the body says why. It is what lands on `main`, word
  for word.

Keep a pull request to one change. Two unrelated changes are two PRs.

## What happens next

The maintainer reviews on the PR. When it is accepted, the patch is applied
to the private repository by hand, run through the full gate there, and
landed on `main` as one squash commit that credits you as the author. It
reaches `ham2k/halo` on the next publish of the mirror, which follows
`main` deliberately rather than automatically — a merged change can take a
while to appear here. The PR is closed with a note saying which commit
carried it.

## License

The project is [MPL-2.0](LICENSE), like the rest of the Ham2K projects, and
every source file carries the SPDX header. A contribution is accepted under
the same license, and opening a pull request says you agree to that.
