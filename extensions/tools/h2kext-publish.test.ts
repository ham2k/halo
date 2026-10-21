// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The catalog publisher (catalog.ham2k.net SPEC §5.1 and §15). What it sends
// is the server's contract, most of what it does is refuse before sending, and
// the one thing it must never do is let the token out — onto a terminal, into
// a CI log, or through a crash.

import { test } from "node:test"
import assert from "node:assert/strict"
import { createHash } from "node:crypto"
import { mkdir, mkdtemp, readFile, writeFile } from "node:fs/promises"
import { createServer } from "node:http"
import type { AddressInfo } from "node:net"
import { tmpdir } from "node:os"
import { join } from "node:path"

// @ts-ignore — deliberately plain JS, like the packer it sits beside.
import { H2KEXT_API_VERSION, pack } from "./h2kext.mjs"
// @ts-ignore
import { DEFAULT_CATALOG, EXIT_REFUSED, EXIT_USAGE, PublishError, TOKEN_ENV, main, readManifestFromBundle } from "./h2kext-publish.mjs"

const TOKEN = "h2kc_0123456789abcdefSECRET"
const authed = { [TOKEN_ENV]: TOKEN }

const validManifest = {
  key: "w7abc-notes",
  name: "W7ABC Notes",
  version: "1.2.3",
  description: "Notes about the stations I work",
  category: "dashboard",
  api: H2KEXT_API_VERSION,
}

async function bundleDir(manifest: Record<string, unknown> = validManifest) {
  const dir = await mkdtemp(join(tmpdir(), "h2kext-publish-test-"))
  await writeFile(join(dir, "manifest.json"), JSON.stringify(manifest))
  await writeFile(join(dir, "index.js"), "(() => {})()")
  return dir
}

async function bundleFile() {
  const dir = await bundleDir()
  return (await pack(dir, { outPath: join(dir, "out.h2kext") })).outPath
}

/// A catalog that answers every request the same way, remembering each one.
/// `answer` can be a function of the request for a catalog that answers the
/// upload and the notes differently.
type Answer = { status: number; body: unknown }
function catalogAnswering(status: number, body: unknown, answer?: (url: string, init: any) => Answer) {
  const calls: { url: string; init: any }[] = []
  const fetch = async (url: string, init: any) => {
    calls.push({ url, init })
    const a = answer?.(url, init) ?? { status, body }
    return new Response(typeof a.body === "string" ? a.body : JSON.stringify(a.body), { status: a.status })
  }
  return { fetch, calls }
}

/// A catalog that must never be asked anything.
const unreachable = () => assert.fail("fetch was called")

/// Runs the command in-process with captured output. `env` defaults to a fixed
/// fake token rather than `process.env`, so a real token in the developer's
/// shell can never make a test pass or fail by accident; the missing-token
/// test passes an empty one on purpose.
/// An empty working directory, so a `screenshots/` folder wherever the suite
/// happens to run can never turn a publish test into a screenshot sync.
const emptyCwd = await mkdtemp(join(tmpdir(), "h2kext-publish-cwd-"))

async function run(
  argv: string[],
  { fetch, env = authed, cwd = emptyCwd, thumbnail }: { fetch: any; env?: Record<string, string>; cwd?: string; thumbnail?: any },
) {
  let stdout = ""
  let stderr = ""
  const code = await main(argv, {
    env,
    fetch,
    cwd,
    thumbnail: thumbnail ?? (() => assert.fail("a thumbnail was made")),
    stdout: {
      write(s: string) {
        stdout += s
        return true
      },
    },
    stderr: {
      write(s: string) {
        stderr += s
        return true
      },
    },
  })
  return { code, stdout, stderr }
}

const accepted = {
  key: "w7abc-notes",
  version: "1.2.3",
  channel: "stable",
  status: "pending",
  submissionId: "sub_42",
  url: `${DEFAULT_CATALOG}/w7abc-notes`,
}

test("the upload is one bearer-authorised POST of the raw bytes, the channel in the query", async () => {
  // SPEC §5.1: no multipart — the server never calls formData(), so a form
  // body would be stored as the bundle and fail zip validation with a message
  // about the author's own file. The bytes on the wire are the file's bytes,
  // not a re-pack: the catalog stores the sha256 of what it receives, and the
  // author's file is what they compare it against.
  const file = await bundleFile()
  const catalog = catalogAnswering(201, accepted)

  const { code } = await run([file, "--channel", "stable"], catalog)

  assert.equal(code, 0)
  assert.equal(catalog.calls.length, 1)
  const { url, init } = catalog.calls[0]
  assert.equal(url, `${DEFAULT_CATALOG}/api/v1/publish?channel=stable`)
  assert.equal(init.method, "POST")
  assert.equal(init.headers.authorization, `Bearer ${TOKEN}`)
  assert.equal(init.headers["content-type"], "application/zip")
  assert.ok(!(init.body instanceof FormData), "multipart body")
  assert.ok(init.body instanceof Uint8Array, "body is not raw bytes")
  assert.ok(Buffer.from(init.body).equals(await readFile(file)), "bytes on the wire differ from the file")
})

test("on the wire, Content-Length is the bundle's size", async () => {
  // A fake fetch is handed a Buffer and shows no header: undici derives
  // Content-Length from the body as it writes the request. The catalog refuses
  // a request without one before reading a byte (§5.1 step 2), so only a real
  // socket can prove the upload is accepted.
  const file = await bundleFile()
  const expected = await readFile(file)
  const received: { url?: string; headers?: Record<string, any>; body?: Buffer } = {}
  const server = createServer((req, res) => {
    const chunks: Buffer[] = []
    req.on("data", (c) => chunks.push(c))
    req.on("end", () => {
      received.url = req.url
      received.headers = req.headers
      received.body = Buffer.concat(chunks)
      res.writeHead(201, { "content-type": "application/json" }).end(JSON.stringify(accepted))
    })
  })
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve))
  try {
    const port = (server.address() as AddressInfo).port
    const { code, stderr } = await run([file, "--channel", "stable", "--catalog", `http://127.0.0.1:${port}`], { fetch: globalThis.fetch })
    assert.equal(code, 0, stderr)
    assert.equal(received.url, "/api/v1/publish?channel=stable")
    assert.equal(received.headers!["content-length"], String(expected.length))
    assert.equal(received.headers!["content-type"], "application/zip")
    assert.equal(received.headers!.authorization, `Bearer ${TOKEN}`)
    assert.ok(received.body!.equals(expected), "bytes on the wire differ from the file")
  } finally {
    server.close()
  }
})

test("no --notes means one request and nothing more", async () => {
  // The notes are a second call, and an absent option is not an empty note:
  // a PUT of '' would store a blank where the site shows nothing.
  const file = await bundleFile()
  const catalog = catalogAnswering(201, accepted)
  const { code } = await run([file, "--channel", "bleeding"], catalog)
  assert.equal(code, 0)
  assert.equal(catalog.calls.length, 1)
})

test("--notes is a second request, PUT to the submission the 201 named", async () => {
  // The id comes from the upload's answer, not from the key and version: the
  // notes belong to a (version, channel) submission, and only the server knows
  // its id. The field name and the JSON shape are the server's contract.
  const file = await bundleFile()
  const catalog = catalogAnswering(201, accepted)

  const { code } = await run([file, "--channel", "stable", "--notes", "First release"], catalog)

  assert.equal(code, 0)
  assert.equal(catalog.calls.length, 2)
  const { url, init } = catalog.calls[1]
  assert.equal(url, `${DEFAULT_CATALOG}/api/v1/submissions/sub_42/notes`)
  assert.equal(init.method, "PUT")
  assert.equal(init.headers.authorization, `Bearer ${TOKEN}`)
  assert.equal(init.headers["content-type"], "application/json")
  assert.deepEqual(JSON.parse(init.body), { releaseNotes: "First release" })
})

test("a refused notes request warns, exits 1, and leaves the publish alone", async () => {
  // By then the bundle is stored and the submission open, and the notes can
  // be written on the site at any time — so a rollback would destroy the part
  // that worked to make up for the part that did not. Exit 0 would hide that
  // anything is missing from a CI log; exit 1 without the "published" line
  // would send the author to upload again into a 409.
  const file = await bundleFile()
  const catalog = catalogAnswering(201, accepted, (url) =>
    url.includes("/notes") ? { status: 403, body: { error: "notes are not yours to set", code: "forbidden" } } : { status: 201, body: accepted },
  )

  const { code, stdout, stderr } = await run([file, "--channel", "stable", "--notes", "First release"], catalog)

  assert.equal(code, EXIT_REFUSED)
  assert.match(stdout, /^published w7abc-notes 1\.2\.3 → stable \(pending review\)$/m)
  assert.match(stderr, /warning: w7abc-notes 1\.2\.3 is published, but its release notes were not set/)
  assert.match(stderr, /HTTP 403.*notes are not yours to set \(forbidden\)/)
  assert.equal(catalog.calls.length, 2, "a retry or a rollback was sent")

  // A 201 with no submissionId is the same failure one step earlier; without
  // this, the PUT goes to /submissions/undefined/notes and the warning
  // quotes a 404 that points nowhere.
  const nameless = catalogAnswering(201, { ...accepted, submissionId: undefined })
  const missing = await run([file, "--channel", "stable", "--notes", "First release"], nameless)
  assert.equal(missing.code, EXIT_REFUSED)
  assert.equal(nameless.calls.length, 1)
  assert.match(missing.stderr, /warning: .*submissionId/)
})

test("a 201 prints the result line the spec promises, with the status in words", async () => {
  // `published <key> <version> → <channel> (<status>)` is the line a script
  // greps; the status is the SERVER's answer, not the requested channel echoed
  // back. `pending` reads as "pending review", which is what stops an author
  // waiting for the extension to appear in the app.
  const file = await bundleFile()
  const pending = await run([file, "--channel", "stable"], catalogAnswering(201, accepted))
  assert.equal(pending.code, 0)
  assert.match(pending.stdout, /^published w7abc-notes 1\.2\.3 → stable \(pending review\)$/m)
  assert.match(pending.stdout, new RegExp(`^${DEFAULT_CATALOG}/w7abc-notes$`, "m"))

  const approved = await run([file, "--channel", "unstable"], catalogAnswering(201, { ...accepted, channel: "unstable", status: "approved" }))
  assert.match(approved.stdout, /\(approved\)$/m)
})

test("a refusal prints the server's error and code, and exits 1", async () => {
  // The catalog names what is wrong in `error` and machine-tags it in `code`;
  // an exit code alone would send the author to the site to find out which of
  // eight rules refused them.
  const file = await bundleFile()
  const { code, stderr } = await run([file, "--channel", "stable"], catalogAnswering(409, { error: "version 1.2.3 is frozen", code: "version-frozen" }))
  assert.equal(code, EXIT_REFUSED)
  assert.match(stderr, /HTTP 409/)
  assert.match(stderr, /version 1\.2\.3 is frozen/)
  assert.match(stderr, /version-frozen/)
})

test("a non-JSON refusal shows the raw body", async () => {
  // A proxy or a Cloudflare error page answers in HTML. Hiding it behind
  // "unexpected response" would hide the only clue.
  const file = await bundleFile()
  const { code, stderr } = await run([file, "--channel", "stable"], catalogAnswering(502, "<html>bad gateway</html>"))
  assert.equal(code, EXIT_REFUSED)
  assert.match(stderr, /HTTP 502.*bad gateway/)
})

test("a missing token exits 2 before any request, naming the variable", async () => {
  // Sent without one, the server's 401 would be the first the author hears of
  // it — after uploading the whole bundle. The env var is named in the message
  // because it is the only way to supply one.
  const file = await bundleFile()
  const { code, stderr } = await run([file, "--channel", "stable"], { fetch: unreachable, env: {} })
  assert.equal(code, EXIT_USAGE)
  assert.match(stderr, new RegExp(TOKEN_ENV))
})

test("--token is not an option: exit 2, the env var named, the value never shown", async () => {
  // SPEC §15: a flag lands in shell history and `ps`. Ignored like any other
  // unknown flag, `--token h2kc_…` from an older script would upload with no
  // token and be told 401 — after the secret already sat in the history. And
  // the refusal must not quote the value it is refusing.
  const file = await bundleFile()
  const { code, stderr } = await run([file, "--channel", "stable", "--token", TOKEN], { fetch: unreachable, env: {} })
  assert.equal(code, EXIT_USAGE)
  assert.match(stderr, /--token/)
  assert.match(stderr, new RegExp(TOKEN_ENV))
  assert.ok(!stderr.includes(TOKEN), `token leaked: ${stderr}`)

  // Any other unknown option is refused the same way, rather than silently
  // dropped and its value taken for the bundle path.
  const typo = await run([file, "--chanel", "stable"], { fetch: unreachable })
  assert.equal(typo.code, EXIT_USAGE)
  assert.match(typo.stderr, /unknown option '--chanel'/)
})

test("the token comes from the environment", async () => {
  // The only path: a secret in the environment and nothing on the command
  // line. The header is the one place it may appear.
  const file = await bundleFile()
  const catalog = catalogAnswering(201, accepted)
  const { code } = await run([file, "--channel", "stable"], { fetch: catalog.fetch, env: { [TOKEN_ENV]: TOKEN } })
  assert.equal(code, 0)
  assert.equal(catalog.calls[0].init.headers.authorization, `Bearer ${TOKEN}`)
})

test("an unknown channel exits 2 before any request", async () => {
  // Three channels, each a degree of finished. A typo would upload the bundle
  // and then be refused; checking here costs nothing and names the choices.
  // `prod` is the interesting typo: it was a channel until channels stopped
  // meaning app editions, so it is what a stale script or an old habit sends.
  const file = await bundleFile()
  for (const bogus of ["prod", "nightly"]) {
    const { code, stderr } = await run([file, "--channel", bogus], { fetch: unreachable })
    assert.equal(code, EXIT_USAGE, bogus)
    assert.match(stderr, /stable, unstable, bleeding/)
  }
})

test("no --channel publishes something finished", async () => {
  // Publishing without saying is publishing to stable; anything rougher is a
  // choice worth typing. Before the default existed this was a usage error,
  // which made the commonest publish the one with the most to remember.
  const file = await bundleFile()
  const catalog = catalogAnswering(201, accepted)
  const { code } = await run([file], catalog)
  assert.equal(code, 0)
  assert.match(catalog.calls[0].url, /\?channel=stable$/)
})

test("a bundle over 16 MiB is refused before any request, naming the cap", async () => {
  // The catalog refuses it from the Content-Length alone (§5.1 step 2), which
  // the author learns after the whole upload; the app would never download it
  // anyway. The boundary is pinned from both sides: a file of exactly the cap
  // gets past the size check (and fails as the non-zip it is), one byte more
  // does not. The literal, not the module's constant, so a moved cap fails here.
  const dir = await mkdtemp(join(tmpdir(), "h2kext-publish-test-"))
  const cap = 16 * 1024 * 1024

  const over = join(dir, "over.h2kext")
  await writeFile(over, Buffer.alloc(cap + 1))
  const refused = await run([over, "--channel", "stable"], { fetch: unreachable })
  assert.equal(refused.code, EXIT_REFUSED)
  assert.match(refused.stderr, /16 MiB/)
  assert.doesNotMatch(refused.stderr, /not a zip/)

  const exact = join(dir, "exact.h2kext")
  await writeFile(exact, Buffer.alloc(cap))
  const allowed = await run([exact, "--channel", "stable"], { fetch: unreachable })
  assert.equal(allowed.code, EXIT_REFUSED)
  assert.match(allowed.stderr, /not a zip/)
  assert.doesNotMatch(allowed.stderr, /16 MiB/)
})

test("a directory argument is packaged first, with the same packer", async () => {
  // The documented one-step path: `h2kext-publish build --channel prod`. What
  // goes up must be exactly what h2kext-pack would have written, or the
  // catalog's validation and the author's local pack disagree.
  const dir = await bundleDir()
  const catalog = catalogAnswering(201, accepted)

  const { code, stdout } = await run([dir, "--channel", "stable"], catalog)

  assert.equal(code, 0)
  assert.match(stdout, /^publishing w7abc-notes 1\.2\.3 — W7ABC Notes → stable/m)
  const sent = Buffer.from(catalog.calls[0].init.body)
  assert.deepEqual([...sent.subarray(0, 4)], [0x50, 0x4b, 0x03, 0x04])
  assert.deepEqual(readManifestFromBundle(sent), validManifest)
})

test("--force-name reaches the packer", async () => {
  // A granted prefix that is not a callsign (SPEC §15) packs only with the
  // waiver; without the pass-through the directory path is closed to it and
  // the author must pack by hand first.
  const dir = await bundleDir({ ...validManifest, key: "ham2k-notes" })
  const catalog = catalogAnswering(201, { ...accepted, key: "ham2k-notes" })

  const refused = await run([dir, "--channel", "stable"], { fetch: unreachable })
  assert.equal(refused.code, EXIT_REFUSED)

  const { code } = await run([dir, "--channel", "stable", "--force-name"], catalog)
  assert.equal(code, 0)
  assert.equal(readManifestFromBundle(Buffer.from(catalog.calls[0].init.body)).key, "ham2k-notes")
})

test("a directory the packer refuses is not uploaded, and says why", async () => {
  // The packer's refusals exist to stop a bundle that installs and then
  // misbehaves in someone else's app; publishing is the one place that
  // matters most, so nothing reaches the catalog until they pass.
  const dir = await mkdtemp(join(tmpdir(), "h2kext-publish-test-"))
  await writeFile(join(dir, "manifest.json"), JSON.stringify(validManifest))
  const { code, stderr } = await run([dir, "--channel", "stable"], { fetch: unreachable })
  assert.equal(code, EXIT_REFUSED)
  assert.match(stderr, /this packages, it does not compile/)
})

test("a trailing --notes with no value is a usage error, not a publish without notes", async () => {
  // `argv[++i]` past the end is undefined, which reads exactly like the
  // option never given — and the author's notes are silently dropped after
  // an otherwise successful publish. Refused before any request, exit 2.
  const file = await bundleFile()
  const { code, stderr } = await run([file, "--channel", "stable", "--notes"], { fetch: unreachable })
  assert.equal(code, EXIT_USAGE)
  assert.match(stderr, /--notes needs a value/)
  const channel = await run([file, "--channel"], { fetch: unreachable })
  assert.equal(channel.code, EXIT_USAGE)
  assert.match(channel.stderr, /--channel needs a value/)
})

test("a truncated bundle is refused as a bundle, not as a crash in the zip reader", async () => {
  // The central directory survives at the tail of a file whose data was
  // cut, and every offset in it points into what is gone: read unguarded,
  // Buffer throws a RangeError and the command reports a bug of its own.
  const whole = await readFile(await bundleFile())
  const eocd = whole.length - 22
  const central = whole.readUInt32LE(eocd + 16)
  const cut = Buffer.concat([whole.subarray(0, 40), whole.subarray(central)])
  // The end-of-central-directory record still has to point at the copied
  // central directory for the reader to get as far as the entry.
  cut.writeUInt32LE(40, cut.length - 22 + 16)
  assert.throws(
    () => readManifestFromBundle(cut),
    (e: any) => e instanceof PublishError && /truncated or damaged/.test(e.message),
  )

  // Deflated bytes that are not deflate at all.
  const garbled = Buffer.from(whole)
  garbled.fill(0xff, 30 + 13, 30 + 13 + 8)
  assert.throws(
    () => readManifestFromBundle(garbled),
    (e: any) => e instanceof PublishError,
  )
})

test("a file that is not a zip is refused before any request", async () => {
  const dir = await mkdtemp(join(tmpdir(), "h2kext-publish-test-"))
  const file = join(dir, "notes.h2kext")
  await writeFile(file, "not a zip at all")
  const { code, stderr } = await run([file, "--channel", "stable"], { fetch: unreachable })
  assert.equal(code, EXIT_REFUSED)
  assert.match(stderr, /not a zip/)
})

test("the token never reaches stdout or stderr, whatever quotes it", async () => {
  // An HTTP client that echoes the failed request, a server that reflects the
  // header it did not like, a bug that throws with the URL in it: every line
  // out passes through one redactor, and this is the test that keeps it there.
  const file = await bundleFile()

  const echoing = async () => {
    throw new Error(`request failed; sent authorization: Bearer ${TOKEN}`)
  }
  const network = await run([file, "--channel", "stable"], { fetch: echoing })
  assert.equal(network.code, EXIT_REFUSED)
  assert.match(network.stderr, /could not reach/)
  assert.ok(!network.stderr.includes(TOKEN), `token leaked: ${network.stderr}`)
  assert.ok(!network.stdout.includes(TOKEN), `token leaked: ${network.stdout}`)
  assert.match(network.stderr, /<token>/)

  const reflecting = await run([file, "--channel", "stable"], catalogAnswering(401, { error: `token ${TOKEN} is not valid`, code: "bad_token" }))
  assert.equal(reflecting.code, EXIT_REFUSED)
  assert.ok(!reflecting.stderr.includes(TOKEN), `token leaked: ${reflecting.stderr}`)
  assert.match(reflecting.stderr, /token <token> is not valid \(bad_token\)/)

  // The notes warning is a second line out, after the publish succeeded; it
  // goes through the same redactor.
  const reflectingNotes = await run(
    [file, "--channel", "stable", "--notes", "x"],
    catalogAnswering(201, accepted, (url) =>
      url.includes("/notes") ? { status: 401, body: { error: `token ${TOKEN} is not valid` } } : { status: 201, body: accepted },
    ),
  )
  assert.equal(reflectingNotes.code, EXIT_REFUSED)
  assert.ok(!reflectingNotes.stderr.includes(TOKEN), `token leaked: ${reflectingNotes.stderr}`)
  assert.match(reflectingNotes.stderr, /warning: .*token <token> is not valid/)

  // A fetch that returns garbage rather than a Response is a bug in this tool,
  // not a refusal — and a stack trace is the easiest place for a secret to
  // hide, so that path is redacted too.
  const broken = await run([file, "--channel", "stable"], { fetch: async () => ({ status: 201 }) })
  assert.equal(broken.code, EXIT_REFUSED)
  assert.ok(!broken.stderr.includes(TOKEN), `token leaked: ${broken.stderr}`)
})

// ---------------------------------------------------------------------------
// Screenshots (§4.8)
// ---------------------------------------------------------------------------

const sha = (b: Uint8Array) => createHash("sha256").update(b).digest("hex")

/// Bytes that sniff as a PNG; `seed` makes each one distinct. Nothing here
/// decodes them — the thumbnailer is a fake — so a signature is enough.
function fakePng(seed: number) {
  return new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, seed])
}

/// A thumbnailer that records what it was asked for and answers bytes derived from them.
function fakeThumbnailer() {
  const made: string[] = []
  const thumbnail = async (bytes: Uint8Array) => {
    made.push(sha(bytes))
    return { bytes: new Uint8Array([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, ...bytes.slice(-1)]), type: "image/webp" }
  }
  return { thumbnail, made }
}

/// A project folder whose `screenshots/` holds [files]; `captions` becomes screenshots.json.
async function projectWith(files: Record<string, Uint8Array | string>, captions?: Record<string, unknown>) {
  const dir = await mkdtemp(join(tmpdir(), "h2kext-publish-shots-"))
  await mkdir(join(dir, "screenshots"))
  for (const [name, data] of Object.entries(files)) await writeFile(join(dir, "screenshots", name), data)
  if (captions) await writeFile(join(dir, "screenshots", "screenshots.json"), JSON.stringify(captions))
  return dir
}

/// A catalog that publishes, holds [current] screenshots, and accepts any upload and set.
function screenshotCatalog(current: { approved?: unknown; pending?: unknown } = {}) {
  return catalogAnswering(0, null, (url, init) => {
    if (url.includes("/api/v1/publish")) return { status: 201, body: accepted }
    if (url.endsWith("/screenshots") && !init?.method) return { status: 200, body: { approved: null, pending: null, rejected: null, ...current } }
    if (url.includes("/media/")) return { status: 200, body: { sha256: url.split("/").pop() } }
    if (url.endsWith("/screenshots")) {
      const { screenshots } = JSON.parse(init.body)
      return { status: 200, body: { set: { id: "set_1", status: "pending", items: screenshots } } }
    }
    return { status: 500, body: "unexpected" }
  })
}

test("after the bundle, ./screenshots becomes the extension's set: file-name order, captions, a thumbnail each", async () => {
  // The folder IS the set (§15): numeric-aware order, so `2-` precedes `10-`
  // the way the author numbered them, and every upload addressed by its hash.
  const file = await bundleFile()
  const cwd = await projectWith({ "10-map.png": fakePng(10), "2-log.png": fakePng(2), "notes.txt": "ignored" }, { "2-log.png": " Logging " })
  const catalog = screenshotCatalog()
  const thumbs = fakeThumbnailer()

  const { code, stdout } = await run([file], { fetch: catalog.fetch, cwd, thumbnail: thumbs.thumbnail })

  assert.equal(code, 0)
  const paths = catalog.calls.map((c) => `${c.init?.method ?? "GET"} ${new URL(c.url).pathname}`)
  assert.equal(paths[0], "POST /api/v1/publish")
  assert.equal(paths[1], "GET /api/v1/extensions/w7abc-notes/screenshots")
  const uploads = catalog.calls.filter((c) => c.url.includes("/media/"))
  assert.equal(uploads.length, 4)
  for (const u of uploads) {
    assert.equal(u.url.split("/").pop(), sha(u.init.body), "an upload is not addressed by its own hash")
    assert.equal(u.init.headers.authorization, `Bearer ${TOKEN}`)
  }
  const set = JSON.parse(catalog.calls.at(-1)!.init.body)
  assert.deepEqual(
    set.screenshots.map((s: any) => [s.image, s.caption]),
    [
      [sha(fakePng(2)), "Logging"],
      [sha(fakePng(10)), undefined],
    ],
  )
  assert.deepEqual(thumbs.made, [sha(fakePng(2)), sha(fakePng(10))])
  assert.match(stdout, /screenshots → 2 screenshots \(pending review\)/)
})

test("an unchanged folder sends nothing past the read, and makes no thumbnail", async () => {
  // A publish on every release must not put the same pictures through review
  // again — nor regenerate thumbnails whose bytes a newer sharp could change.
  const file = await bundleFile()
  const cwd = await projectWith({ "1.png": fakePng(1) }, { "1.png": "One" })
  const catalog = screenshotCatalog({ pending: { status: "pending", items: [{ image: sha(fakePng(1)), thumb: "t", caption: "One" }] } })

  const { code, stdout } = await run([file], { fetch: catalog.fetch, cwd })

  assert.equal(code, 0)
  assert.deepEqual(
    catalog.calls.map((c) => c.init?.method ?? "GET"),
    ["POST", "GET"],
  )
  assert.match(stdout, /screenshots unchanged \(1 screenshot, pending review\)/)
})

test("a picture already in a set keeps that set's thumbnail and is not uploaded again", async () => {
  const file = await bundleFile()
  const cwd = await projectWith({ "1.png": fakePng(1), "2.png": fakePng(2) })
  const catalog = screenshotCatalog({ approved: { status: "approved", items: [{ image: sha(fakePng(1)), thumb: "f".repeat(64), caption: null }] } })
  const thumbs = fakeThumbnailer()

  assert.equal((await run([file], { fetch: catalog.fetch, cwd, thumbnail: thumbs.thumbnail })).code, 0)

  assert.deepEqual(thumbs.made, [sha(fakePng(2))])
  const uploaded = catalog.calls.filter((c) => c.url.includes("/media/")).map((c) => c.url.split("/").pop())
  assert.deepEqual(uploaded, [sha(fakePng(2)), sha((await thumbs.thumbnail(fakePng(2))).bytes)])
  const set = JSON.parse(catalog.calls.at(-1)!.init.body)
  assert.equal(set.screenshots[0].thumb, "f".repeat(64))
})

test("without a screenshots folder, a publish never touches the extension's screenshots", async () => {
  // A project with no folder has not asked for its screenshots to be removed.
  const file = await bundleFile()
  const catalog = catalogAnswering(201, accepted)
  assert.equal((await run([file], catalog)).code, 0)
  assert.equal(catalog.calls.length, 1)
})

test("a bad screenshot folder stops the command before the version is published", async () => {
  const file = await bundleFile()
  const nine = Object.fromEntries(Array.from({ length: 9 }, (_, i) => [`${i}.png`, fakePng(i)]))
  for (const [cwd, why] of [
    [await projectWith({ "1.png": "not a picture" }), /is not a PNG, JPEG or WebP image/],
    [await projectWith(nine), /holds 9 screenshots; the catalog takes at most 8/],
    [await projectWith({ "1.png": fakePng(1) }, { "01.png": "renamed" }), /caption for '01.png', which is not a screenshot/],
    [await projectWith({ "1.png": fakePng(1) }, { "1.png": "x".repeat(201) }), /caption for '1.png' is longer than 200 characters/],
  ] as const) {
    const { code, stderr } = await run([file], { fetch: unreachable, cwd })
    assert.equal(code, EXIT_REFUSED)
    assert.match(stderr, why)
  }
})

test("--screenshots-only syncs the set without publishing a bundle", async () => {
  const dir = await bundleDir()
  const cwd = await projectWith({ "1.png": fakePng(1) })
  const catalog = screenshotCatalog()
  const { code } = await run([dir, "--screenshots-only"], { fetch: catalog.fetch, cwd, thumbnail: fakeThumbnailer().thumbnail })
  assert.equal(code, 0)
  assert.ok(!catalog.calls.some((c) => c.url.includes("/api/v1/publish")), "the bundle was published")
  assert.ok(catalog.calls.some((c) => c.init?.method === "PUT" && c.url.endsWith("/screenshots")))

  const none = await run([dir, "--screenshots-only"], { fetch: unreachable, cwd: emptyCwd })
  assert.equal(none.code, EXIT_USAGE)
})

test("a refused screenshot set after a published version warns and exits 1, the version standing", async () => {
  const file = await bundleFile()
  const cwd = await projectWith({ "1.png": fakePng(1) })
  const catalog = catalogAnswering(0, null, (url, init) => {
    if (url.includes("/api/v1/publish")) return { status: 201, body: accepted }
    if (url.endsWith("/screenshots") && !init?.method) return { status: 200, body: { approved: null, pending: null } }
    if (url.includes("/media/")) return { status: 400, body: { error: `token ${TOKEN} says no`, code: "image-too-large" } }
    return { status: 500, body: "unexpected" }
  })
  const { code, stdout, stderr } = await run([file], { fetch: catalog.fetch, cwd, thumbnail: fakeThumbnailer().thumbnail })
  assert.equal(code, EXIT_REFUSED)
  assert.match(stdout, /published w7abc-notes 1.2.3/)
  assert.match(stderr, /warning: w7abc-notes 1.2.3 is published, but its screenshots were not updated — .*image-too-large/)
  assert.ok(!stderr.includes(TOKEN), `token leaked: ${stderr}`)
})

test("an empty ./screenshots found by accident leaves the catalog's alone; naming it takes them down", async () => {
  // A stray empty folder where the command runs must not wipe a live set:
  // the catalog approves an empty set at once.
  const file = await bundleFile()
  const cwd = await projectWith({ "README.md": "pictures go here" })
  const found = await run([file], { ...catalogAnswering(201, accepted), cwd })
  assert.equal(found.code, 0)
  assert.match(found.stdout, /holds no screenshots; leaving the catalog's as they are/)

  const catalog = screenshotCatalog({ approved: { status: "approved", items: [{ image: sha(fakePng(1)), thumb: "t", caption: null }] } })
  const named = await run([file, "--screenshots", join(cwd, "screenshots")], { fetch: catalog.fetch, cwd: emptyCwd })
  assert.equal(named.code, 0)
  assert.deepEqual(JSON.parse(catalog.calls.at(-1)!.init.body), { screenshots: [] })
})

test("a picture sharp cannot read is a refusal naming it, after the version is published", async () => {
  // A stack trace here would hide whether the version went out.
  const file = await bundleFile()
  const cwd = await projectWith({ "1.png": fakePng(1) })
  const { code, stderr } = await run([file], {
    fetch: screenshotCatalog().fetch,
    cwd,
    thumbnail: async () => {
      throw new Error("Input buffer contains unsupported image format")
    },
  })
  assert.equal(code, EXIT_REFUSED)
  assert.match(stderr, /is published, but its screenshots were not updated — could not make a thumbnail of 1.png: Input buffer/)
  assert.ok(!stderr.includes("    at "), `stack trace: ${stderr}`)
})
