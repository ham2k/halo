# Ham2K Logger Project Rules & Guidelines

This is a multi-platform app for Amateur Radio Logging, called "Ham2K Logger" (or "HaLo" for short). On desktop versions it identifies itself as "Ham2K Logger" while on mobile versions it uses "Ham2K Portable Logger".

## Design & Architecture

- [DESIGN.md](file:///Users/sd/Work/ham2k/app-halo/DESIGN.md) contains high-level design documentation.
- User interface conventions are listed in [user-interface.md](file:///Users/sd/Work/ham2k/app-halo/docs/design/user-interface.md) and branding is documented in [branding.md](file:///Users/sd/Work/ham2k/app-halo/docs/design/branding.md).
- The extension system and hooks are defined under `docs/extensions/`.
- We often mention app-polo and web-lofi, which are the existing mobile version and a web-based log browser that shares a lot of logic with PoLo. These are available in separate sibling repositories that can be used for reference.

## Process Conventions

- Agents should make commits to the repository when relevant changes are made. If the agent is continuing during a session (such as making updates based on developer feedback), they may amend the previous commit if it is related.
- When working on a feature, the agent might want to run the mac or web versions in the background, and use hot reload to see changes without rebuilding the app.
- We do most work on the `app-halo-dist` repository, with branches out of the `main-dist-private` branch. We use "squash-and-merge" to merge PRs. Any commits that include changes to `app_dist` are split into separate commits in `app-halo-dist`. The non `app_dist` changes are then cherry-picked to `main-public`.
- New branches should be pushed to the `app-halo-dist` origin, never to regular `origin`.

## Tooling
- On the development environment, we use `mise` to manage dependencies and tool versions.
- When adding commits, identify yourself as "Ham2K Bot <bot@ham2k.com>"
- When interacting with Github, use `export GH_TOKEN="$(security find-generic-password -a claude-code -s gh-bot-token -w)"` in the session to authenticate API requests as ham2k-bot.

---

# Rules

These rules apply to every task in this project unless explicitly overridden.
Bias: caution over speed on non-trivial work.

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
