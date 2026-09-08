# HaLo Next

Next-generation Ham2K Portable Logger: a Flutter core ("the machine") with
TypeScript extensions ("the knowledge") for activities, contests, callsign
lookups, spotting, exports, and sync transports.

Successor to [app-polo](https://github.com/ham2k/app-polo), designed to run on
mobile, tablet, and desktop — including multi-window contest-station setups —
while keeping the extension ecosystem in TypeScript, updatable without app
releases.

**Start here: [DESIGN.md](DESIGN.md)** — architecture, extension model, hook
taxonomy, data layer, sequencing plan. Setting up to build and hack on it?
[DEVELOPMENT.md](DEVELOPMENT.md) covers environment setup, running/building,
tests, and the dev-only flags (`ONBOARD_AS`, …) and call-field commands. The
full documentation index is at [docs/README.md](docs/README.md); for writing
extensions, see [docs/extensions/](docs/extensions/README.md). Want to send a
change? [CONTRIBUTING.md](CONTRIBUTING.md) is the path, from setup to merge.

## Status

The core architecture is built and working: logging loop, extension runtime
and bridge, declarative UI catalog, sync, spots, map, scoring, and exports.
Remaining gaps are tracked in [docs/backlog.md](docs/backlog.md).

```sh
mise install && mise trust && mise run setup   # tools, extension bundles, JS engine, deps
cd app && flutter run -d macos
```

`mise run setup` is idempotent; [DEVELOPMENT.md](DEVELOPMENT.md#first-time-setup)
says what it does and how to do each step by hand.

### Building locally on macOS or iOS

By default the macOS build signs ad-hoc (no Apple Developer team), which
works fine but re-derives the code signature on every rebuild — so macOS
treats each build as a new, unrecognized app and re-prompts for keychain
access (e.g. for stored account credentials) every single time.

If that gets annoying, copy
[`app/macos/Runner/Configs/Local.xcconfig.sample`](app/macos/Runner/Configs/Local.xcconfig.sample)
to `Local.xcconfig` in the same folder (gitignored, never committed) and
fill in your own Apple Developer team ID:

```sh
cp app/macos/Runner/Configs/Local.xcconfig.sample app/macos/Runner/Configs/Local.xcconfig
# then edit Local.xcconfig and set DEVELOPMENT_TEAM to your team ID
```

Once in place, rebuilds sign consistently and you only need to click
"Always Allow" on the keychain prompt once.

The same mechanism exists for iOS builds — copy
[`app/ios/Flutter/Local.xcconfig.sample`](app/ios/Flutter/Local.xcconfig.sample)
to `Local.xcconfig` in the same folder and set `DEVELOPMENT_TEAM` there too.

### Windows

Setup:
```
Install Visual Studio 2026, with C++ Desktop development
Install Git
Install Node.js
Install VSCode
Install Flutter extension for VSCode
winget install Microsoft.NuGet
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
start ms-settings:developers # Enable Developer Mode

# Close and reopen the terminal

cd app/lib/config
copy secrets.dart.example secrets.dart
cd ../../..
```

Build:
```
cd extensions && npm install && npm run build
cd app && flutter run -d windows
```

## License

MPL-2.0, following the rest of the Ham2K projects.
