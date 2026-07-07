# HaLo Next

Next-generation Ham2K Portable Logger: a Flutter core ("the machine") with
TypeScript extensions ("the knowledge") for activities, contests, callsign
lookups, spotting, exports, and sync transports.

Successor to [app-polo](https://github.com/ham2k/app-polo), designed to run on
mobile, tablet, and desktop — including multi-window contest-station setups —
while keeping the extension ecosystem in TypeScript, updatable without app
releases.

**Start here: [DESIGN.md](DESIGN.md)** — architecture, extension model, hook
taxonomy, data layer, sequencing plan. For writing extensions, see
[docs/extensions/](docs/extensions/README.md).

## Status

- **Spike 01 — extension bridge**: done, all platforms green
  ([docs/spike-01-extension-bridge.md](docs/spike-01-extension-bridge.md)).
- **Phase 2 — core logging loop**: operations, QSO entry, reactive QSO list
  on drift/SQLite ([docs/phase-02-core-logging.md](docs/phase-02-core-logging.md)).

```sh
cd extensions && npm install && npm run build   # extension bundles → app assets
cd app && flutter run -d macos               # flutter provided via mise
```

## License

MPL-2.0, following the rest of the Ham2K projects.
