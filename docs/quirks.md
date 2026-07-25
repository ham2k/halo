# Build & Platform Quirks

Workarounds we carry for upstream or platform bugs. Each entry records what
breaks, why, and where the fix lives — so nobody later "cleans up" a
load-bearing workaround without knowing what it protects.

**Currently: none.** The one long-standing entry — `flutter_js` failing to
bundle its prebuilt quickjs bridge on Linux — went away with `flutter_js`
itself in Phase 3 of the JS engine work ([design/js-engine.md](design/js-engine.md)).
Add the next one here rather than leaving it to be rediscovered.
