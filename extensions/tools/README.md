# @ham2k/extension-tools

Build and package extensions for the [Ham2K Logger](https://ham2k.com).

```sh
npm install --save-dev @ham2k/extension-tools esbuild
```

## Building

```js
import { build } from 'esbuild'
import { buildExtension } from '@ham2k/extension-tools'

await buildExtension(build, { dir: import.meta.dirname })
```

Reads your `manifest.json`, compiles `src/index.ts` into `build/index.js`, and
copies the manifest alongside it. The esbuild settings it applies are
requirements of the runtime rather than preferences: one IIFE because the
sandbox evaluates a script and has no module loader, `neutral` because there is
no Node and no DOM, and `es2020` because that is what its engine speaks.

esbuild is yours to bring — the preset takes your `build` function rather than
importing its own, so there is only ever one copy of it.

Everything your manifest's `sharedDependencies` names becomes a lookup on the
library the host already holds, which is worth roughly thirty times the bundle
size. Using one **without** declaring it fails the build rather than quietly
shipping a private copy; pass `inline: ['liquidjs']` if that copy is what you
want, which is how you use a version the host does not carry.

## Packaging

```sh
npx h2kext-pack build -o my-extension.h2kext
```

Packages a directory holding a built `index.js`, a `manifest.json` and an
optional `assets/`. It packages; it does not compile.

It reports every problem at once, and refuses what would install cleanly and
then misbehave where you cannot see it. Extension keys are `<callsign>-<name>`
— the namespace every author of this software already holds, so two people who
never met cannot ship the same key.

## License

MPL-2.0
