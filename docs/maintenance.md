# Maintenance — things that rot quietly

> Status: living document · Last reviewed: 2026-08-07

Most of what breaks a shipped app is not a bug someone wrote; it is something
that was correct when it was written and stopped being correct while nobody
was looking. Pinned dependencies drift out of support, data files go stale,
certificates and API keys expire, build-expiration dates pass, and upstream
projects get abandoned.

This is the list of those things, what to check, and — the part that matters
most — **how you find out it went wrong if nobody checks**. Anything whose
failure mode is "silently wrong" deserves attention before anything whose
failure mode is "loud build error", because the loud one tells you itself.

Add to this list whenever something bites; that is what it is for.

---

## Suggested rhythm

| When | What |
|---|---|
| Each release cut | Build expiration dates, Shorebird token, appcast health |
| Monthly | Reference data files, extension npm deps, Flutter/Dart pin |
| Quarterly | quickjs-ng, signing certificates, dependency audit, this document |
| Whenever CI goes strange | The "silent failure" column below, top to bottom |

---

## 1. quickjs-ng (the JS engine)

**Pinned at:** `v0.15.1` — see `packages/halo_quickjs/src/quickjs/VERSION`,
which records the tag and the exact commit sha.

We vendor the source and compile it into the plugin
([design/js-engine.md](design/js-engine.md)). That is deliberate, and it means
**nothing updates this for us** — the flip side of not depending on someone
else's prebuilt binaries.

**Check:** <https://github.com/quickjs-ng/quickjs/releases> for new tags, and
skim the changelog for API changes and for anything security-related. The
project is active (multiple releases a year).

```bash
# what we're pinned to
cat packages/halo_quickjs/src/quickjs/VERSION

# what upstream has
git ls-remote --tags --refs https://github.com/quickjs-ng/quickjs.git \
  | awk -F/ '{print $NF}' | sort -V | tail -5
```

**To bump:** replace the four `.c` files and the headers in
`packages/halo_quickjs/src/quickjs/`, update `VERSION`, then run
`packages/halo_quickjs/tool/verify_targets.sh` (cross-compiles every target
ABI, including 32-bit armv7, and asserts the `JSValue` representation) and
the package suite — it covers the API surface we actually use (eval, exceptions and
stacks, the `sendMessage` bridge, promise pumping, interrupt, memory limit,
re-entrancy). Read the upstream changelog for signature changes first;
quickjs-ng has made deliberate breaking changes to the classic Bellard API,
so a clean compile is necessary but not sufficient.

**Why this needs a human:** the API surface we bind is small but load-bearing,
and several invariants live in *our* shim rather than in quickjs — the depth
gate, the interrupt latch, the entry/exit rules. An upstream change to
interrupt or stack handling would not necessarily fail to compile.

**Silent failure:** none for the pin itself — it just stays old. The risk is
missing a security or correctness fix, so this is a "read the changelog" check
rather than a "does it still build" one.

## 2. Reference data files

Extensions declare downloadable datasets: `pota-all-parks`,
`sota-all-summits`, `call-notes`. They refresh at runtime through
`DataFileManager`, so staleness is usually self-correcting — but the
*definitions* (URLs, parsers) are not.

**Check:** that each still downloads and parses. A source changing its URL or
format is the realistic failure.

**Silent failure:** yes, and this is the nasty one — a parser that silently
yields zero records looks exactly like "no nearby parks", not like an error.
Worth spot-checking that a known reference still resolves.

## 3. Amateur-radio reference libraries

`extensions/package.json` pins the `@ham2k/lib-*` packages. Note
`@ham2k/lib-country-files` is version-stamped by date
(`^1.0.202605301` ≈ 2026-05), which is exactly the shape of a dependency that
goes quietly out of date.

**Check:** `cd extensions && npm outdated`. DXCC entities and prefixes do
change — new entities, prefix reassignments, callsign-block changes.

**Silent failure:** yes. Stale country data means wrong entity, wrong flag,
wrong scoring — plausible-looking output, not an error.

## 4. Build expiration dates

`app/lib/config/version.dart` carries `kDevExpirationDate`,
`kNextExpirationDate`, `kProdExpirationDate` (and `kBuildExpiration`). Past
the date, the app nags on every launch (#339). Dev and Next are short-lived
by design; Regular is roughly six months.

**Check:** at every release cut — this is the one item that is *supposed* to
expire, so the check is that the new build's date is sensible, not that it
hasn't passed.

**Silent failure:** no, it is loud by construction — but it is loud *to
users*, which is worse than loud to us. Do not let a release ship with a date
that has already passed.

## 5. Signing, notarization, and update feeds

Everything here fails at build or install time, often confusingly:

- **Apple Developer ID** certificate — expires; renewal changes the identity.
- **Notarization** credentials (App Store Connect API key).
- **Windows Trusted Signing** — see [releases.md](releases.md).
- **Sparkle / WinSparkle appcasts** — the feeds macOS/Windows self-update
  from. A published appcast pointing at a missing or unsigned artifact breaks
  updates for people who already installed.
- **Shorebird `SHOREBIRD_TOKEN`** — releases.md notes explicitly that **key
  expiry silently starts failing CI**.

**Check:** expiry dates on each; fetch each edition's appcast and confirm the
artifact it names actually downloads.

**Silent failure:** yes, in the worst way — existing installs stop receiving
updates while new builds still work, so nothing looks broken from here.

## 6. Toolchain pins

`mise.toml` pins Flutter (and Node/Bun) with per-platform URLs. CI and local
dev share the pin, which is what keeps them honest.

**Check:** `mise outdated`, plus whether the pinned Flutter is still a
supported stable. Bumping Flutter is a real change — it moves the Dart SDK,
the engine, and plugin compatibility together, so treat it as its own piece of
work with the full suite behind it.

## 7. Housekeeping commands

`halo-ops` already has the tools; they just need running:

```bash
mise run ops -- prune-code-pushes # old code-push trigger tags
mise run ops -- prune-previews    # stale web preview deployments
mise run ops -- status            # released version per edition
```

**Also worth pruning:** merged git branches and stale worktrees — this repo
accumulated 28 worktrees and 90+ branches before a cleanup in July 2026.

## 8. Dependency audit

```bash
(cd app && flutter pub outdated)
(cd extensions && npm outdated)
```

Expect a standing tail of "newer versions incompatible with dependency
constraints" — that is normal and not automatically actionable. What matters
is anything **unmaintained**: check last-release dates, not just version
numbers. `flutter_js` looked maintained (its Dart side still shipped
releases) while the native bridge that actually mattered had been dead for
four years. Judge a dependency by the layer you depend on.

## 9. Icon fonts and glyph tables

**Pinned at:** `@mdi/font` + `@mdi/svg` **7.4.47**, `@fortawesome/fontawesome-free`
**6.7.2** — the versions live in `packages/halo_widgets/tool/update_icons.py`,
which vendors each font *and* its name→codepoint table as a pair from the same
package version, and **proves the pairing** by parsing each TTF's cmap and
failing on any table codepoint the font lacks. That check is the drift guard:
the historical failure mode (font from one upstream, table from another, 177
names silently rendering as blanks) fails the generator instead of shipping.
Never edit the fonts or `tool/data/*.json` directly; change the pin and re-run
`python3 tool/update_icons.py --fetch`.

Both pins are **terminal releases** — MDI is in maintenance with 7.4.47 as its
final release, and Font Awesome 6 Free ended at 6.7.2 — so there is no routine
bump. What can still rot:

- **app-polo moving.** The name sets currently match PoLo's
  (`@react-native-vector-icons` repackages the same upstreams), which is what
  keeps extension icon names portable. If PoLo ever changes icon sets or
  versions, re-verify parity before following.
- **Needing an icon that doesn't exist.** MDI is frozen; a genuinely new icon
  means choosing a successor source (Pictogrammers' Memory set, FA7, …) — a
  design decision, not a version bump.

**Check:** `packages/halo_build_tools/test/icon_names_test.dart` runs in the
full suite and fails on any icon name (extension or core) with no glyph in the
vendored tables, and on any core-Dart `Icons.*` use — our UI is MDI-only; the
built-in MaterialIcons font ships purely as a safety net for glyphs Flutter
renders internally with no override point (docs/design/user-interface.md
§Icons). Don't remove it: those internals can't be enumerated, and each one
would surface as a missing-glyph box one user report at a time.

**Silent failure:** only for icon names that arrive at runtime from
*third-party* extensions — those degrade to a puzzle-piece placeholder by
design and are nobody's bug. Everything in-repo fails loudly in the suite.

## 10. This document

**Check quarterly.** Update the "Last reviewed" date at the top. Remove
sections that stop applying — a section covering a dependency we are removing
should say what condition retires it, so the removal needs no judgment — and
add whatever most recently bit us.
