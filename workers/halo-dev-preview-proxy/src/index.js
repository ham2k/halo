// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Serves web preview deployments under flat subdomains of ham2k.net:
// <name>-halo-dev.ham2k.net proxies to the Cloudflare Pages preview alias
// <name>.halo-dev-ham2k-net.pages.dev (see .github/workflows/
// deploy-web-preview.yml, which creates the previews and their DNS records).
//
// Routed on `*-halo-dev.ham2k.net/*` (zone ham2k.net). Deploy with
// `npx wrangler deploy` from this directory.

export default {
  async fetch (request) {
    const url = new URL(request.url)
    const match = url.hostname.match(/^([a-z0-9-]+)-halo-dev\.ham2k\.net$/)
    if (!match) {
      return new Response('Not found', { status: 404 })
    }
    url.hostname = `${match[1]}.halo-dev-ham2k-net.pages.dev`
    return fetch(new Request(url, request))
  }
}
