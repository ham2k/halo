# Web Deployment & Cloudflare Hosting

How to build, deploy, and host the web version of **Ham2K Logger** on
**Cloudflare Pages**, including URL redirections and CORS proxy setup. For the
overall versioning and distribution architecture, see [releases.md](releases.md).

## Overview
Flutter web builds compile to static assets (HTML, CSS, JS, WASM, and the
CanvasKit graphics engine). We host them on Cloudflare Pages, which provides
edge caching and SSL termination.

---

## 1. Local Build & Deploy CLI

We have automated the build and deploy pipeline. You can run it directly using `mise` tasks:

```bash
mise run deploy-web
```

*By default, this builds and deploys to the Cloudflare project name `halo-dev-ham2k-net`. If you want to deploy to a custom project name, run:*
```bash
./scripts/deploy-web.sh --project <your-project-name>
```

### What the script does:
1. Installs dependencies and builds the TypeScript extension bundles in `extensions/` (moving the output JS files to `app/assets/extensions/`).
2. Runs the Flutter compiler in release mode with icon tree-shaking disabled (`flutter build web --release --no-tree-shake-icons`).
3. Checks for the local `wrangler` installation and uploads the compiled assets in `app/build/web` to your Cloudflare Pages account.

---

## 1b. Automatic Deployment from CI

Every push to the `dist` branch of `app-halo-dist` runs CI, and when CI passes, the **Deploy Web** GitHub Actions workflow (`.github/workflows/deploy-web.yml`) runs the same build steps as the local script and deploys to the `halo-dev-ham2k-net` Pages project via wrangler direct upload. A CI failure skips the deploy silently. The workflow can also be run manually from the Actions tab (`workflow_dispatch`), bypassing the CI gate.

The workflow requires two repository secrets on `app-halo-dist`:
- `CLOUDFLARE_API_TOKEN` — an API token with the **Cloudflare Pages: Edit** permission (create at Cloudflare Dashboard → My Profile → API Tokens).
- `CLOUDFLARE_ACCOUNT_ID` — the account id (visible in the dashboard URL or on any zone's overview page).

---

## 2. Cloudflare Project Setup

To deploy the application successfully, you need to configure your Cloudflare account.

### Step A: Authenticate Wrangler CLI Locally
Before your local script can push builds, authenticate your terminal with Cloudflare:
```bash
npx wrangler login
```
*This opens a browser window where you can authorize the Wrangler CLI to access your account.*

### Step B: Create the Pages Project in Cloudflare Dashboard
1. Log in to the [Cloudflare Dashboard](https://dash.cloudflare.com/).
2. Navigate to **Workers & Pages** in the left sidebar.
3. Click **Create Application** at the top, and select the **Pages** tab.
4. Select **Upload assets** *(we deploy pre-built static files locally rather than using Git integration)*.
5. Set the project name to: `halo-dev-ham2k-net`.
6. Click **Create project** (you can skip the zip file upload step).

### Step C: Bind the Custom Domain (`halo-dev.ham2k.net`)
1. Open the project settings for your `halo-dev-ham2k-net` Pages application.
2. Select the **Custom Domains** tab.
3. Click **Set up a Custom Domain**.
4. Enter `halo-dev.ham2k.net`.
   * *If the main domain `ham2k.net` is managed in your Cloudflare DNS account, Cloudflare will automatically provision the CNAME routing and SSL certificate.*

---

## 3. Web Architecture Configuration

### A. SPA Route Redirection (`_redirects`)
To support deep-linking/client-side routing (e.g. refreshing `halo-dev.ham2k.net/settings` without hitting a server 404), we utilize a Cloudflare redirection rule.
* Located at: [app/web/_redirects](file:///Users/sd/Work/ham2k/app-halo/app/web/_redirects)
* Content: `/*  /index.html  200`
This tells Cloudflare Pages to fall back to serving `index.html` for all paths, allowing Flutter's internal router to handle path parsing client-side.

### B. Web CORS Proxy (`services.ham2k.net`)
When running on the web, browsers enforce **CORS** restrictions on outgoing requests. Direct calls to API endpoints like POTA, QRZ, and SOTA fail if they do not explicitly return CORS wildcards.

To resolve this:
- Outgoing fetches in `ExtensionHost` and file downloads in `DataFileManager` automatically intercept and check if the runtime target is Flutter Web (`kIsWeb`).
- If web-based, requests matching standard domains are rewritten to route through the CORS proxy at `services.ham2k.net`:
  - `https://api.pota.app/park/K-0001` ➡️ `https://services.ham2k.net/api.pota.app/park/K-0001`
  - `https://logbook.qrz.com/xml/` ➡️ `https://services.ham2k.net/logbook.qrz.com/xml/`
  - `https://country-files.com/xxx` ➡️ `https://services.ham2k.net/country-files.com/xxx`
  - `https://pota.app/all_parks_ext.csv` ➡️ `https://services.ham2k.net/pota.app/all_parks_ext.csv`
  - `https://www.sotadata.org.uk/summitslist.csv` ➡️ `https://services.ham2k.net/www.sotadata.org.uk/summitslist.csv`
