# Ham2K Logger Project Rules & Guidelines

This is a multi-platform app for Amateur Radio Logging, called "Ham2K Logger" (or "HaLo" for short). On desktop versions it identifies itself as "Ham2K Logger" while on mobile versions it uses "Ham2K Portable Logger".


## Design & Architecture

- [DESIGN.md](file:///Users/sd/Work/ham2k/app-halo/DESIGN.md) contains high-level design documentation.

- User interface conventions and branding are documented in [user-interface.md](file:///Users/sd/Work/ham2k/app-halo/docs/design/user-interface.md).

- The logging controls' parts, and the focus and keyboard-navigation rules for the main logging fields, are specified in [logging-fields.md](file:///Users/sd/Work/ham2k/app-halo/docs/design/logging-fields.md). Read it before changing anything about focus in the logging panel — the rules are a contract, not defaults.

- The Font Scale setting scales the **whole** UI from one root wrapper ([ui-scaling.md](file:///Users/sd/Work/ham2k/app-halo/docs/design/ui-scaling.md)). Write all dimensions in plain logical pixels and **never multiply a size, padding, or font size by the font scale** — that double-scales it. Read ui-scaling.md before any scaling-, layout-, or macOS-window-related change.

- What an escaped exception deserves — a user notice, a silent upload, the console, or nothing — is decided in ONE place, `ErrorPolicy` ([error-reporting.md](file:///Users/sd/Work/ham2k/app-halo/docs/design/error-reporting.md)). Never add an ad-hoc "ignore this error" check at a handler or catch site; add a rule there instead.

- The extension system and hooks are defined under `docs/extensions/`.

- We often mention app-polo and web-lofi, which are the existing mobile version and a web-based log browser that shares a lot of logic with PoLo. These are available in separate sibling repositories that can be used for reference.


## Development Process

- **Tasks, bugs and ideas live in [CaBo](https://cabo.ham2k.com/halo), not GitHub Issues.** Cards are referenced as `HALO-24` and deep-link as `https://cabo.ham2k.com/halo/c/24`. Read and write them through the `cabo` MCP server — `list_projects`, `search_cards`, `get_board`, `get_card`, `create_card`, `update_card`, `move_card`, `add_comment`, `get_activity`. Leave a comment on the card whenever the state a human would want to see changes: the PR link once the branch exists, findings that redefine the task, and the merge. GitHub still owns **pull requests**, code review and CI — only issue tracking moved.

- Agents should always work on a worktree, with a branch off of the `dist` branch on the `app-halo-dist` origin (that branch is usually available as `dist` locally too, tracking `app-halo-dist/dist`). As new tasks come in, use new branches and rename the worktree to keep the name relevant.

- **`app-halo-dist/dist` is the only base.** Never `main` or `main-public`: both are stale local-only branches, absent from every remote, and every commit on them is already in `dist` under a different SHA. Do not trust the branch a session hands you — a worktree created for you may already be on the wrong base, and nothing about it looks unusual. Check before editing:
  `git fetch app-halo-dist dist && git rev-list --count $(git merge-base HEAD app-halo-dist/dist)..app-halo-dist/dist`
  A large number means the branch was cut from the wrong place; re-cut it with `git checkout -b <task-name> app-halo-dist/dist` rather than rebasing. `.claude/hooks/base-branch-guard.sh` enforces this and will block edits, but the check is yours to make first.

- Keep `dist` updated. Rebase your branches on top of the latest `dist` before submitting or updating a PR.

- The `/next` skill (`.claude/skills/next/SKILL.md`) runs the start-of-task
  steps below — refreshing `dist`, naming the branch and worktree, bootstrapping
  a fresh worktree, opening a draft PR with the plan, then a first pass and
  updating that PR. Invoke it as `/next <card ref, PR number, or description>`;
  keep it in step with this section.

- The `/iterate` skill (`.claude/skills/iterate/SKILL.md`) covers the
  "iterate with the developer" step: it keeps a build running and refreshed and
  skips commits and test runs until the user says iteration is done, at which
  point the steps below resume.

- The `/finalize` skill (`.claude/skills/finalize/SKILL.md`) covers the "work
  has settled" step: closes out an `/iterate` cycle if one's running, makes
  sure the PR exists and is current, runs the full test and checks suite,
  ensures a code review has run (re-running it if more than trivial changes
  landed since), and hands over a fresh build for the developer to check.

- The `/merge` skill (`.claude/skills/merge/SKILL.md`) covers the last step:
  rebases the branch onto the latest `dist`, resolves any conflicts, verifies
  the full test and checks suite is green, and squash-merges the PR without
  waiting on a recorded GitHub review — then asks what's next.

- Steps when tackling a new task:
  - Open a new branch, off the latest `dist`. Look for updates to AGENTS.md.
  - Do a quick analisys of the problem, prepare a plan and open a **draft** PR to document this, before implementing anything. An empty commit is enough to open it. That PR is how the developer tracks which branch carries the task, what the plan is, and what's been found — so give them the link right away.
  - Take a full pass at the problem and then present the results to the developer. Bring the PR body up to date as the plan turns into findings — rewrite it, don't append. If possible and relevant, start a web build of the app for the developer to verify on.
  - Iterate with the developer. Don't pile up trivial commits. When iterating on a feature or approach, feel free to ammend the commits in the branch if it makes sense to keep work organized and easier to review, and skip running tests for short iterations unless it's useful.
  - Once the work has settled, run a code review, present the results to the developer and ask for followups.
  - When the followups have been addressed, rebase on top of an updated `dist`, solve any merge conflicts, run tests and present the PR for user approval.
  - Apart from that early draft PR, don't push to the PR branch until it's ready for review. Avoid pushing to the remote repository until necessary. Test locally first.

- Whenever running the app (any `flutter run`, including the web dev server), always pass a `DEV_LABEL` set to your session name or a brief description of the work at hand, so the running build is identifiable in the home-screen header — e.g. `flutter run -d macos --dart-define=DEV_LABEL="header work"` or `DEV_LABEL="header work" flutter run -d web-server`. See [DEVELOPMENT.md](file:///Users/sd/Work/ham2k/app-halo/DEVELOPMENT.md).

- When starting the app for developer checks, use `--dart-define=ONBOARD_AS="N0DEV,pota"` to provide a default setup and avoid the onboarding dialog (unless working on an onboarding feature).

- We do most work on the `app-halo-dist` repository, where the `dist` branch is. We use "squash-and-merge" to merge PRs. Any commits that include changes to the `app_dist` folder, or other private and distribution-related parts of the app, must be split into separate commits in `app-halo-dist`. The non `app_dist` changes are then cherry-picked to `main` in the public repo `app-halo` (the `origin` remote).

- New branches should be pushed to the `app-halo-dist` origin, never to regular `origin`.

- Branches for CaBo cards should be named `halo-<number>-<short-description>` (e.g. `halo-24-cabo-tracker` for `HALO-24`) and should be based off the `dist` branch of the `app-halo-dist` repository (available as `dist` locally too). Keep the `halo-` prefix: CaBo numbers restart at 1, so a bare `24-…` is ambiguous against the older branches named after GitHub Issue numbers.

- PRs should cite the CaBo card ref and link to it. GitHub's "closes"/"fixes"/"resolves" keywords do **not** reach CaBo, so nothing auto-closes a card — `/merge` comments on it and moves it to the board's done column instead.

- Agents should name their sessions with "[HaLo]" as a prefix, followed by a very short description of the work at hand. It's ok to update the name of the session as we go along.

- Except for trivial work, open the draft PR before implementing, and when completing the first round of planned work bring it up to date and run a code review.


## Tooling

- **Verify with `./scripts/test.sh`** (or `mise run test`) before saying tests
  pass or opening a PR — it is what CI runs. Per-package `flutter test` is right
  for a fast inner loop but is NOT the gate: it skips the extensions'
  `npm run typecheck`, skips `halo_build_tools`, and skips rebuilding the
  extension bundles that the Dart integration tests load, so stale bundles pass
  silently. `--quick` for analyze+typecheck only. See DEVELOPMENT.md.

- On the development environment, we use `mise` to manage dependencies and tool versions.

- When adding commits, identify yourself as "Sebastian Delmont <sd@ham2k.com>"

- When interacting with Github, use `export GH_TOKEN="$(security find-generic-password -a claude-code -s gh-bot-token -w)"` in the session to authenticate API requests as ham2k-bot.

- CaBo authenticates over OAuth through its MCP server — there is no shell token and no CLI, so it can only be reached via the `cabo` tools. It's registered at user scope in `~/.claude.json`, so every worktree gets it, but MCP servers only load at session start: if the tools are missing, the fix is a session restart, not a config change.

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

## Rule 6 — Token budgets are not advisory
Per-task: 4,000 tokens. Per-session: 30,000 tokens.
If approaching budget, summarize and start fresh.
Surface the breach. Do not silently overrun.

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
