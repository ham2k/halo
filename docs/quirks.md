# Build & Platform Quirks

Workarounds we carry for upstream or platform bugs. Each entry records what
breaks, why, and where the fix lives — so nobody later "cleans up" a
load-bearing workaround without knowing what it protects.

## flutter_js: quickjs bridge library not bundled on Linux

**Symptom** — the Linux app builds and launches, but the extension runtime dies
at startup:

```
[extensions] failed to start extension runtime: Failed to load dynamic library
'libquickjs_c_bridge_plugin.so': cannot open shared object file: No such file or directory
```

**Cause** — `flutter_js` 0.8.7 ships a prebuilt
`linux/shared/libquickjs_c_bridge_plugin.so`, but its `linux/CMakeLists.txt`
exports it under a **misnamed** variable: `flutter_qjs_bundled_libraries`
instead of the `flutter_js_bundled_libraries` that Flutter's Linux tooling
reads. The library therefore never enters `PLUGIN_BUNDLED_LIBRARIES`, Flutter
never copies it into `build/linux/<arch>/release/bundle/lib/`, and at runtime
the app `dlopen`s it by name and can't find it.

**Workaround** — `app/linux/CMakeLists.txt` installs the prebuilt `.so`
explicitly (right after the `PLUGIN_BUNDLED_LIBRARIES` loop), from the plugin's
ephemeral symlink:

```
app/linux/flutter/ephemeral/.plugin_symlinks/flutter_js/linux/shared/libquickjs_c_bridge_plugin.so
```

This fixes every Linux build — local `flutter build linux` and CI alike. The
Codemagic `linux-release` workflow also copies the `.so` from the pub cache as a
redundant safety net.

**Remove when** — `flutter_js` fixes the variable name upstream. Verify the
`.so` lands in `bundle/lib/` from a clean build *without* the install step, then
drop both this install block and the CI safety net.
