# Ham2K Logger Project Rules & Guidelines

This is a multi-platform app for Amateur Radio Logging, called "Ham2K Logger" (or "HaLo" for short). On desktop versions it identifies itself as "Ham2K Logger" while on mobile versions it uses "Ham2K Portable Logger".


## Design & Architecture

- [DESIGN.md](../DESIGN.md) contains high-level design documentation.

- User interface conventions and branding are documented in [user-interface.md](../docs/design/user-interface.md).

- The logging controls' parts, and the focus and keyboard-navigation rules for the main logging fields, are specified in [logging-fields.md](../docs/design/logging-fields.md). Read it before changing anything about focus in the logging panel — the rules are a contract, not defaults.

- The Font Scale setting scales the **whole** UI from one root wrapper ([ui-scaling.md](../docs/design/ui-scaling.md)). Write all dimensions in plain logical pixels and **never multiply a size, padding, or font size by the font scale** — that double-scales it. Read ui-scaling.md before any scaling-, layout-, or macOS-window-related change.

- **Never call `DateTime.now()`.** Every "now" in app code goes through the app clock — `nowUtc()` / `nowLocal()` / `nowMillis()` from `halo_core` — so that developer time travel (`DEVTT`) moves the whole app at once ([time.md](../docs/design/time.md)). `./scripts/test.sh` fails the build on a direct read. A value that must NOT travel calls the explicit `realNowUtc()` / `realNowMillis()` instead — a sync revision stamp (it persists, so it escapes the session), a protocol timeout, anything whose remainder becomes a `Timer` duration. Read time.md before adding a clock read, a staleness check, or anything the extension sandbox reads a date for — and its §7 before writing a test that waits for one, because a timer can fire late but never early, and faking a timer without faking the clock the code reads makes a test pass while testing nothing.

- A coordinate measures, a grid displays ([locations.md](../docs/design/locations.md)). Wherever a location is captured, capture the `lat`/`lon` too — and where a pair is present it OUTRANKS the grid, so **a writer that sets a grid without a coordinate must clear the pair in the same write**. Read locations.md before storing, resolving, or displaying a location.

- What an escaped exception deserves — a user notice, a silent upload, the console, or nothing — is decided in ONE place, `ErrorPolicy` ([error-reporting.md](../docs/design/error-reporting.md)). Never add an ad-hoc "ignore this error" check at a handler or catch site; add a rule there instead.

- The extension system and hooks are defined under `docs/extensions/`.

- User-facing strings live in `packages/halo_i18n` — edit **both** `en` and `es`, then regenerate there (its README says how); the gate fails on a stale output.

- We often mention app-polo and web-lofi, which are the existing mobile version and a web-based log browser that shares a lot of logic with PoLo. These are available in separate sibling repositories that can be used for reference.


## Development Process

- **`main` is the only base.** Branch off the latest `main` on `origin`, and do not trust the branch a session hands you — a worktree created for you may already be on the wrong base, and nothing about it looks unusual. Check before editing:
  `git fetch origin main && git rev-list --count $(git merge-base HEAD origin/main)..origin/main`
  A large number means the branch was cut from the wrong place; re-cut it with `git checkout -b <task-name> origin/main` rather than rebasing. `.claude/hooks/base-branch-guard.sh` enforces this and will block edits, but the check is yours to make first.

- Keep `main` updated. Rebase your branches on top of the latest `main` before finalizing or merging.

- **Work lands on `main` as one squash commit per task, and landing it is the maintainer's decision, every time.** Never land work on `main` on your own initiative. **No test runs anywhere but here** — the Checks workflow re-runs the guards, the extensions' typecheck and `dart analyze` on a push to `main` (and on a pull request), and nothing else, so the local `./scripts/test.sh` run before merging is not merely the first gate for the suite, it is the only one. A green run there is the sole evidence the tests passed; treat a skipped or partial run as shipping untested code.

- Steps when tackling a new task:
  - Open a new branch, off the latest `main`. Look for updates to AGENTS.md.
  - Do a quick analysis of the problem, ask the developer a short round of pointed questions to pin down scope and assumptions, then record the plan before implementing anything.
  - Take a full pass at the problem and then present the results to the developer. If possible and relevant, start a web build of the app for the developer to verify on.
  - Iterate with the developer. Don't pile up trivial commits. When iterating on a feature or approach, feel free to amend the commits in the branch if it makes sense to keep work organized and easier to review, and skip running tests for short iterations unless it's useful.
  - If the work gives a Dev/Next tester something new to go and try, add a note under the `upcoming` key of `app/assets/tester-notes.yaml`, in the same commit — about ten words on one line, label first ("New …", "Added …"), one per change and never one per detail. Most changes get no note at all: a new feature or control earns one, bug fixes and refinements to existing behaviour usually don't, and work with no tester-visible surface never does. **Anything behind an experiment never does either** — neither tester notes nor release notes ever mention an experiment, the `EXP` word that toggles it, or the feature it gates; that work earns a note only once it ships without the gate. The release cut renames that key to the build that ships it, so never type a build number there. [releases.md §2.7](../docs/releases.md) is the spec for both these and the public `release-notes.yaml` — the YAML files carry no guidance of their own, so read it before writing a note.
  - Once the work has settled, run a code review, present the results to the developer and ask for followups.
  - When the followups have been addressed, rebase on top of an updated `main`, run the full suite, and ask the developer to approve the merge.

- Commit messages are read by people who were not there: the title states the outcome in the project's voice (what is now true, not what was done), and the body says why. What a squash message carries is published as-is, so it describes only what a reader of the published repository can see for themselves.

- A change from outside the project comes in as a pull request on the public repository — [CONTRIBUTING.md](../CONTRIBUTING.md) is the whole path, from setup to what happens after the review.


## Tooling

- **Verify with `./scripts/test.sh`** (or `mise run test`) before saying tests
  pass or merging — it is the whole gate, and the only place the tests run. For the inner loop, run **subsets**
  through the same script: `./scripts/test.sh <group>...` (see `--list`) or
  `./scripts/test.sh --changed` — it keeps the extension bundles and the
  generated strings fresh (the stale-artifact trap raw `flutter test` falls
  into) while skipping npm ci / pub get / analyze. Subset runs are NOT the
  gate: no analyze, no extensions typecheck, no dependent packages, no browser
  step — the full no-arg run is still required before merging. `--quick` for
  analyze+typecheck only. See DEVELOPMENT.md.

- On the development environment, we use `mise` to manage dependencies and tool versions.

- Whenever running the app (any `flutter run`, including the web dev server), pass a `DEV_LABEL` naming the work at hand, so the running build is identifiable in the home-screen header — e.g. `flutter run -d macos --dart-define=DEV_LABEL="header work"`. For developer checks, `--dart-define=ONBOARD_AS="N0DEV,pota"` provides a default setup and skips the onboarding dialog (unless working on an onboarding feature). See [DEVELOPMENT.md](../DEVELOPMENT.md).

---

# Rules

These rules apply to every task in this project unless explicitly overridden.
Bias: caution over speed on non-trivial work.

Be terse, direct and precise in communication. Avoid unnecessary verbosity and praise and focus on delivering clear, actionable information.

## Rule 1 — Think Before Coding
State assumptions explicitly. Ask rather than guess.
Push back when a simpler approach exists. Stop when confused.

## Rule 2 — Simplicity First
Minimum code that solves the problem. Nothing speculative.
No abstractions for single-use code.

## Rule 3 — Surgical Changes
Touch only what you must. Don't improve adjacent code.
Match existing style. Don't refactor what isn't broken.

## Rule 4 — Goal-Driven Execution
Define success criteria. Loop until verified.
Strong success criteria let Claude loop independently.

## Rule 5 — Use the model only for judgment calls
Use for: classification, drafting, summarization, extraction.
Do NOT use for: routing, retries, deterministic transforms.
If code can answer, code answers.

## Rule 6 — The one about token budgets
We no longer use this rule. We expect agent harnesses to have figured this out by now.

## Rule 7 — Surface conflicts, don't average them
If two patterns contradict, pick one (more recent / more tested).
Explain why. Flag the other for cleanup.

## Rule 8 — Read before you write
Before adding code, read exports, immediate callers, shared utilities.
If unsure why existing code is structured a certain way, ask.

## Rule 9 — Tests verify intent, not just behavior
Tests must encode WHY behavior matters, not just WHAT it does.
A test that can't fail when business logic changes is wrong.

## Rule 10 — Checkpoint after every significant step
Summarize what was done, what's verified, what's left.
Don't continue from a state you can't describe back.

## Rule 11 — Match the codebase's conventions, even if you disagree
Conformance > taste inside the codebase.
If you think a convention is harmful, surface it. Don't fork silently.

## Rule 12 — Fail loud
"Completed" is wrong if anything was skipped silently.
"Tests pass" is wrong if any were skipped.
Default to surfacing uncertainty, not hiding it.

## Rule 13 — Comments state constraints, not history
A comment exists to say what the code cannot: contracts, invariants,
deliberate divergences ("polo does X, we deliberately do Y"), warnings
against a tempting change, cross-references to design docs.
Write in the present tense. Never narrate history — no "used to",
"previously", "this was added after…", no review or debugging stories.
If a past bug justifies the code's shape, state the failure mode as a
present-tense counterfactual ("without this guard, a second connect
races the first"), not as an anecdote.
No issue/PR numbers or dates — git blame holds them. Exception: a ref
that IS the defining spec for the code (link it as such).
Don't restate the adjacent code. In tests, comments state the trap or
the mutation the test exists to catch (Rule 9), never the assertion.
