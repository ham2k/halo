# @ham2k/extension-sdk

Write extensions for the [Ham2K Logger](https://ham2k.com) — the typed hook
contracts and the host API an extension is built against.

```sh
npm install @ham2k/extension-sdk
npm install --save-dev @ham2k/extension-tools esbuild
```

```ts
import { defineExtension } from '@ham2k/extension-sdk'
import type { PanelHook } from '@ham2k/extension-sdk'

import manifest from '../manifest.json'

const HelloPanel: PanelHook = {
  async getPanels() {
    return [{ key: 'hello', title: 'Hello World', icon: 'hand-wave-outline' }]
  },
  async render() {
    return { kind: 'markdown', content: '# Hello, World!' }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook('panel', { key: 'ki2d-hello-world', hook: HelloPanel })
  },
})
```

A panel returns *content*, not widgets — which is what keeps extensions out of
the app's UI toolkit.

`@ham2k/extension-tools` builds and packages it into a `.h2kext` the app can
install. See [the extension docs](https://github.com/ham2k/halo/tree/main/docs/extensions)
for hooks, forms, templates and distribution.

## About the peer dependencies

This package lists the libraries the extension host carries — `@ham2k/lib-*`,
`i18next`, `liquidjs` — as **optional** peers, and you almost certainly do not
need to install any of them.

Your extension declares in its `manifest.json` which of them it uses, and the
build rewrites each one into a lookup on the host's single instance before
esbuild ever reaches the filesystem. Taking the host up on that is worth
roughly thirty times the bundle size. The published types have theirs rolled
in, so your editor works with only this package installed.

Install one only to `inline` it — to ship your own copy because you need a
version the host does not carry.

## License

MPL-2.0
