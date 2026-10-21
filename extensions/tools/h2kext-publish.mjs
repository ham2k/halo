#!/usr/bin/env node
// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// Publishes a `.h2kext` to the extension catalog — catalog.ham2k.net, whose
// SPEC.md lives in the ham2k/catalog.ham2k.net repo; the § references below
// are to it (§5.1 is the publish request, §15 this command).
//
//   H2K_CATALOG_TOKEN=h2kc_… h2kext-publish <bundle.h2kext | build dir>
//                  [--channel <stable|unstable|bleeding>] [--notes "…"] [--catalog <url>]
//                  [--force-name] [--screenshots <dir>] [--screenshots-only]
//
// One POST of the raw bytes, then one PUT for the notes, then the screenshot
// sync (§4.8); no retries: a refusal is the catalog's verdict on these bytes,
// and sending them again can only repeat it. The token is read from the environment for those requests and
// never written anywhere — not to a config file, not to the terminal, not into
// an error message.

import { createHash } from "node:crypto"
import { realpathSync } from "node:fs"
import { mkdtemp, readdir, readFile, rm, stat } from "node:fs/promises"
import { tmpdir } from "node:os"
import { extname, join, resolve } from "node:path"
import { pathToFileURL } from "node:url"
import { inflateRawSync } from "node:zlib"

import { MANIFEST_ENTRY, pack, PackError } from "./h2kext.mjs"

export const DEFAULT_CATALOG = "https://catalog.ham2k.net"
export const PUBLISH_PATH = "/api/v1/publish"
export const SUBMISSIONS_PATH = "/api/v1/submissions"
export const TOKEN_ENV = "H2K_CATALOG_TOKEN"
/// How finished a release is, steadiest first — NOT an app edition. The
/// catalog cascades, so a release on `stable` is visible to everyone and one
/// on `bleeding` only to somebody who asked for it.
export const CHANNELS = ["stable", "unstable", "bleeding"]

/// What `--channel` means when it is not given. Publishing without saying is
/// publishing something finished; anything rougher is a choice worth typing.
export const DEFAULT_CHANNEL = "stable"

/// The catalog refuses a larger upload before reading it (§5.1 step 2),
/// because the app never downloads more than this (`kMaxDownloadBytes`).
/// Checked here so the refusal costs nothing instead of a wasted upload.
export const MAX_BUNDLE_BYTES = 16 * 1024 * 1024

/// Screenshots (§4.8). The catalog checks every one of these again; checking
/// here turns a refusal after a round trip into one before any upload.
export const SCREENSHOTS_DIR = "screenshots"
export const CAPTIONS_FILE = "screenshots.json"
export const MAX_SCREENSHOTS = 8
export const MAX_SCREENSHOT_BYTES = 2 * 1024 * 1024
export const THUMB_SIDE = 480
export const CAPTION_MAX = 200
const SCREENSHOT_TYPES = { ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".webp": "image/webp" }

/// Exit codes. Usage problems — including a missing token — are 2 so a script
/// can tell "you called this wrong" from "the catalog said no" (1).
export const EXIT_REFUSED = 1
export const EXIT_USAGE = 2

/// How a submission status reads on the result line. `pending` means a
/// reviewer has not looked yet; saying "review" is what stops an author
/// waiting for the extension to appear.
const STATUS_WORDS = { pending: "pending review" }

export class PublishError extends Error {
  constructor(message, exitCode = EXIT_REFUSED) {
    super(message)
    this.exitCode = exitCode
  }
}

const USAGE = `Publish an extension bundle to the Ham2K extension catalog.

  ${TOKEN_ENV}=h2kc_… h2kext-publish <bundle.h2kext | build dir> [--channel <stable|unstable|bleeding>]
                 [--notes "<release notes>"] [--catalog <url>] [--force-name]
                 [--screenshots <dir>] [--screenshots-only]

A directory is packaged first, exactly as h2kext-pack would. A bundle over
16 MiB is refused here, as the catalog would refuse it.

The token comes from the ${TOKEN_ENV} environment variable and only from
there — a flag would land in shell history and \`ps\`. Get one at
${DEFAULT_CATALOG}/publish. Nothing here stores it.

  --channel      how finished this release is (default ${DEFAULT_CHANNEL});
                 stable is visible to everyone, bleeding only to somebody
                 who asked for it
  --notes        release notes for this version, markdown; sent in a second
                 request once the upload is accepted
  --catalog      defaults to ${DEFAULT_CATALOG}
  --force-name   waive the key naming convention when packaging a directory
                 (Ham2K's own builds; the catalog checks it again regardless)
  --screenshots  the folder holding the extension's screenshots (default
                 ./${SCREENSHOTS_DIR}, when it exists). The folder is the whole
                 set: PNG, JPEG or WebP files in file-name order, at most
                 ${MAX_SCREENSHOTS}, captions from an optional ${CAPTIONS_FILE}
                 ({ "<file name>": "<caption>" }). Thumbnails are made with the
                 optional \`sharp\` package. An unchanged folder sends nothing.
  --screenshots-only
                 sync the screenshots without publishing the bundle

Exits 0 once the catalog holds the submission and its notes, 1 when it refuses
or cannot be reached, 2 for a usage problem.`

/// The manifest inside a bundle's bytes.
///
/// A reader for one entry of a zip whose writer is ours — h2kext.mjs via yazl:
/// stored or deflated, no zip64, no encryption — which is why this is forty
/// lines and not a dependency. Sizes come from the central directory, never
/// the local header: yazl streams, so the local header's sizes are zero and
/// the truth sits in the data descriptor after the entry.
export function readManifestFromBundle(bytes) {
  const buf = Buffer.isBuffer(bytes) ? bytes : Buffer.from(bytes)
  if (buf.length < 22 || buf.readUInt32LE(0) !== 0x04034b50) {
    throw new PublishError("not a .h2kext: not a zip")
  }
  // The end-of-central-directory record is the last 22 bytes plus a comment of
  // up to 64 KiB, so the search walks backwards over that much and no more.
  let eocd = -1
  for (let i = buf.length - 22; i >= Math.max(0, buf.length - 22 - 0xffff); i--) {
    if (buf.readUInt32LE(i) === 0x06054b50) {
      eocd = i
      break
    }
  }
  if (eocd < 0) throw new PublishError("not a .h2kext: no zip central directory")

  const count = buf.readUInt16LE(eocd + 10)
  let offset = buf.readUInt32LE(eocd + 16)
  for (let n = 0; n < count; n++) {
    if (offset + 46 > buf.length || buf.readUInt32LE(offset) !== 0x02014b50) {
      throw new PublishError("not a .h2kext: damaged zip central directory")
    }
    const method = buf.readUInt16LE(offset + 10)
    const compressedSize = buf.readUInt32LE(offset + 20)
    const nameLength = buf.readUInt16LE(offset + 28)
    const extraLength = buf.readUInt16LE(offset + 30)
    const commentLength = buf.readUInt16LE(offset + 32)
    const localOffset = buf.readUInt32LE(offset + 42)
    const name = buf.toString("utf8", offset + 46, offset + 46 + nameLength)
    if (name === MANIFEST_ENTRY) {
      // Every offset here comes from the file itself, so a truncated or
      // doctored bundle can point past its own end: refused as a bundle,
      // not as a RangeError out of Buffer.
      const damaged = `not a .h2kext: ${MANIFEST_ENTRY} entry is truncated or damaged`
      if (localOffset + 30 > buf.length || buf.readUInt32LE(localOffset) !== 0x04034b50) throw new PublishError(damaged)
      const start = localOffset + 30 + buf.readUInt16LE(localOffset + 26) + buf.readUInt16LE(localOffset + 28)
      if (start + compressedSize > buf.length) throw new PublishError(damaged)
      const data = buf.subarray(start, start + compressedSize)
      let raw
      if (method === 0) raw = data
      else if (method === 8) {
        try {
          raw = inflateRawSync(data)
        } catch (e) {
          throw new PublishError(`${damaged}: ${e.message}`)
        }
      } else throw new PublishError(`not a .h2kext: ${MANIFEST_ENTRY} uses zip compression method ${method}`)
      try {
        return JSON.parse(raw.toString("utf8"))
      } catch (e) {
        throw new PublishError(`${MANIFEST_ENTRY} inside the bundle is not valid JSON: ${e.message}`)
      }
    }
    offset += 46 + nameLength + extraLength + commentLength
  }
  throw new PublishError(`not a .h2kext: no ${MANIFEST_ENTRY} inside`)
}

/// The bundle's bytes: the file as given, or a directory packaged the way
/// h2kext-pack packages it, into a temporary file that is gone before this
/// returns.
async function loadBundle(source, { forceName }) {
  let info
  try {
    info = await stat(source)
  } catch (e) {
    throw new PublishError(`${source}: ${e.code === "ENOENT" ? "no such file or directory" : e.message}`)
  }
  if (!info.isDirectory()) return await readFile(source)

  const tmp = await mkdtemp(join(tmpdir(), "h2kext-publish-"))
  try {
    const { outPath } = await pack(source, { outPath: join(tmp, "bundle.h2kext"), forceName })
    return await readFile(outPath)
  } catch (e) {
    if (e instanceof PackError) throw new PublishError(`${source} is not ready to publish:\n${e.message}`)
    throw e
  } finally {
    await rm(tmp, { recursive: true, force: true })
  }
}

/// One request to the catalog, its answer parsed as JSON when it is JSON. A
/// network failure is a [PublishError] naming the catalog, not a stack trace.
async function call(fetch, catalog, path, init) {
  let response
  try {
    response = await fetch(`${catalog}${path}`, init)
  } catch (e) {
    throw new PublishError(`could not reach ${catalog}: ${e.cause?.message ?? e.message}`)
  }
  const text = await response.text()
  let body
  try {
    body = JSON.parse(text)
  } catch {
    body = undefined
  }
  return { response, text, body }
}

/// What a refusal says: the server's `error` and `code`, or its raw body when
/// it sent no JSON — a proxy's HTML is still worth seeing.
function refusal({ response, text, body }) {
  return body?.error ? `${body.error}${body.code ? ` (${body.code})` : ""}` : text.trim() || response.statusText || "no response body"
}

/// Uploads [bytes] as the raw request body (§5.1: no multipart) and
/// returns the catalog's 201 body. Any other answer is a [PublishError].
///
/// `Content-Length` is not set here: fetch derives it from a Buffer body, and a
/// header set by hand that disagreed with the body would be the request's
/// failure, not the catalog's.
export async function publish({ bytes, manifest, channel, catalog, token }, { fetch = globalThis.fetch } = {}) {
  const answer = await call(fetch, catalog, `${PUBLISH_PATH}?channel=${channel}`, {
    method: "POST",
    headers: { authorization: `Bearer ${token}`, "content-type": "application/zip" },
    body: bytes,
  })
  if (answer.response.status === 201 && answer.body) return answer.body
  throw new PublishError(`${catalog} refused ${manifest.key} ${manifest.version} with HTTP ${answer.response.status}: ${refusal(answer)}`)
}

/// Sets a submission's release notes (§5.1, the second call). Any answer
/// outside 2xx is a [PublishError]; the submission it was for stands.
export async function setReleaseNotes({ submissionId, notes, catalog, token }, { fetch = globalThis.fetch } = {}) {
  const answer = await call(fetch, catalog, `${SUBMISSIONS_PATH}/${encodeURIComponent(submissionId)}/notes`, {
    method: "PUT",
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: JSON.stringify({ releaseNotes: notes }),
  })
  if (answer.response.ok) return
  throw new PublishError(`${catalog} refused the release notes for submission ${submissionId} with HTTP ${answer.response.status}: ${refusal(answer)}`)
}

// ---------------------------------------------------------------------------
// Screenshots (§4.8)
// ---------------------------------------------------------------------------

function sha256Of(bytes) {
  return createHash("sha256").update(bytes).digest("hex")
}

/// The type the catalog will read from the bytes, by the same magic numbers,
/// or null: a file named `.png` that is not one is refused here, by name.
export function sniffImageType(bytes) {
  const b = Buffer.isBuffer(bytes) ? bytes : Buffer.from(bytes)
  if (b.length >= 8 && b.readUInt32BE(0) === 0x89504e47 && b.readUInt32BE(4) === 0x0d0a1a0a) return "image/png"
  if (b.length >= 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) return "image/jpeg"
  if (b.length >= 12 && b.toString("latin1", 0, 4) === "RIFF" && b.toString("latin1", 8, 12) === "WEBP") return "image/webp"
  return null
}

/// The folder as a set: every image file in file-name order — numeric-aware,
/// so `2-…` comes before `10-…` — with its bytes, hash and caption. Anything
/// else in the folder is ignored, so a README beside the pictures is fine.
export async function readScreenshotFolder(dir) {
  let entries
  try {
    entries = await readdir(dir, { withFileTypes: true })
  } catch (e) {
    throw new PublishError(`${dir}: ${e.code === "ENOENT" ? "no such directory" : e.message}`)
  }
  // Files only: a directory named `old.png` is not a screenshot.
  const names = entries.filter((entry) => entry.isFile()).map((entry) => entry.name)
  let captions = {}
  if (names.includes(CAPTIONS_FILE)) {
    try {
      captions = JSON.parse(await readFile(join(dir, CAPTIONS_FILE), "utf8"))
    } catch (e) {
      throw new PublishError(`${join(dir, CAPTIONS_FILE)} is not valid JSON: ${e.message}`)
    }
    if (typeof captions !== "object" || captions === null || Array.isArray(captions)) {
      throw new PublishError(`${join(dir, CAPTIONS_FILE)} must map file names to captions`)
    }
  }
  const files = names
    .filter((name) => SCREENSHOT_TYPES[extname(name).toLowerCase()] && !name.startsWith("."))
    .sort((a, b) => a.localeCompare(b, "en", { numeric: true }))
  if (files.length > MAX_SCREENSHOTS) {
    throw new PublishError(`${dir} holds ${files.length} screenshots; the catalog takes at most ${MAX_SCREENSHOTS}`)
  }
  for (const name of Object.keys(captions)) {
    // A caption for a file that is not there is almost always a renamed file.
    if (!files.includes(name)) throw new PublishError(`${join(dir, CAPTIONS_FILE)} has a caption for '${name}', which is not a screenshot in ${dir}`)
  }
  const shots = []
  for (const name of files) {
    const bytes = await readFile(join(dir, name))
    const type = sniffImageType(bytes)
    if (!type) throw new PublishError(`${join(dir, name)} is not a PNG, JPEG or WebP image`)
    if (bytes.length > MAX_SCREENSHOT_BYTES) {
      throw new PublishError(`${join(dir, name)} is ${bytes.length} bytes; a screenshot is at most 2 MiB (${MAX_SCREENSHOT_BYTES} bytes)`)
    }
    const caption = captions[name]
    if (caption !== undefined && caption !== null && typeof caption !== "string") {
      throw new PublishError(`${join(dir, CAPTIONS_FILE)}: the caption for '${name}' must be a string`)
    }
    const trimmed = caption?.trim() || null
    if (trimmed && [...trimmed].length > CAPTION_MAX) {
      throw new PublishError(`${join(dir, CAPTIONS_FILE)}: the caption for '${name}' is longer than ${CAPTION_MAX} characters`)
    }
    shots.push({ name, bytes, type, sha256: sha256Of(bytes), caption: trimmed })
  }
  return shots
}

/// A thumbnail at most [THUMB_SIDE] pixels on its longest side, in the
/// image's proportions, as WebP — a PNG screenshot's thumbnail kept as PNG is
/// often past the catalog's 128 KiB, and every client decodes WebP. `sharp`
/// is optional so packing and plain publishing never need a native module;
/// it is loaded only when a new picture needs a thumbnail.
export async function sharpThumbnail(bytes) {
  let sharp
  try {
    sharp = (await import("sharp")).default
  } catch {
    throw new PublishError(
      "making screenshot thumbnails needs the optional 'sharp' package — `npm install --save-dev sharp` in your project, or manage screenshots on the catalog site instead",
    )
  }
  const data = await sharp(bytes).resize({ width: THUMB_SIDE, height: THUMB_SIDE, fit: "inside", withoutEnlargement: true }).webp({ quality: 80 }).toBuffer()
  return { bytes: data, type: "image/webp" }
}

const sameItems = (set, shots) =>
  set !== null &&
  set !== undefined &&
  set.items.length === shots.length &&
  set.items.every((item, i) => item.image === shots[i].sha256 && (item.caption ?? null) === shots[i].caption)

/// Makes the catalog's set for [key] the folder's [shots], sending only what
/// it lacks: nothing at all when the waiting set — or the live one, with none
/// waiting — already is the folder; otherwise a thumbnail made only for a
/// picture no set of the key already has one for, the uploads the catalog
/// does not hold, and the set. Answers what happened, for the result line.
export async function syncScreenshots({ key, shots, catalog, token }, { fetch = globalThis.fetch, thumbnail = sharpThumbnail } = {}) {
  const base = `/api/v1/extensions/${encodeURIComponent(key)}`
  const auth = { authorization: `Bearer ${token}` }
  const current = await call(fetch, catalog, `${base}/screenshots`, { headers: auth })
  if (!current.response.ok) {
    throw new PublishError(`${catalog} refused to show the screenshots of ${key} with HTTP ${current.response.status}: ${refusal(current)}`)
  }
  const { approved = null, pending = null } = current.body ?? {}
  if (pending ? sameItems(pending, shots) : sameItems(approved, shots)) return { changed: false, set: pending ?? approved }

  // A picture already in a set keeps that set's thumbnail: making it again
  // with another sharp could give other bytes, and a new set to review.
  const known = new Map()
  for (const set of [approved, pending]) for (const item of set?.items ?? []) known.set(item.image, item.thumb)
  const held = new Set([...known.keys(), ...known.values()])

  const upload = async (bytes, type, what) => {
    const sha256 = sha256Of(bytes)
    if (held.has(sha256)) return sha256
    const answer = await call(fetch, catalog, `${base}/media/${sha256}`, { method: "PUT", headers: { ...auth, "content-type": type }, body: bytes })
    if (!answer.response.ok) throw new PublishError(`${catalog} refused ${what} with HTTP ${answer.response.status}: ${refusal(answer)}`)
    held.add(sha256)
    return sha256
  }

  const items = []
  for (const shot of shots) {
    const image = await upload(shot.bytes, shot.type, shot.name)
    let thumb = known.get(shot.sha256)
    if (!thumb) {
      let made
      try {
        made = await thumbnail(shot.bytes)
      } catch (e) {
        // A file whose header looks right and whose body does not: said by
        // name, as a refusal, not as a stack trace that hides whether the
        // version went out.
        if (e instanceof PublishError) throw e
        throw new PublishError(`could not make a thumbnail of ${shot.name}: ${e.message}`)
      }
      thumb = await upload(made.bytes, made.type, `the thumbnail of ${shot.name}`)
    }
    items.push({ image, thumb, ...(shot.caption ? { caption: shot.caption } : {}) })
  }

  const answer = await call(fetch, catalog, `${base}/screenshots`, {
    method: "PUT",
    headers: { ...auth, "content-type": "application/json" },
    body: JSON.stringify({ screenshots: items }),
  })
  if (!answer.response.ok || !answer.body?.set) {
    throw new PublishError(`${catalog} refused the screenshots of ${key} with HTTP ${answer.response.status}: ${refusal(answer)}`)
  }
  return { changed: true, set: answer.body.set }
}

/// The result line's words for a set's state.
function screenshotState({ changed, set }) {
  const count = set?.items.length ?? 0
  const what = count === 0 ? "no screenshots" : `${count} screenshot${count === 1 ? "" : "s"}`
  if (!changed) return `screenshots unchanged (${what}${set?.status === "pending" ? ", pending review" : ""})`
  return `screenshots → ${what} (${STATUS_WORDS[set.status] ?? (set.status === "approved" ? "live" : set.status)})`
}

/// The command. Returns the exit code rather than exiting, so the same code
/// runs under a test with a fake `fetch` and captured output.
export async function main(
  argv,
  { env = process.env, fetch = globalThis.fetch, stdout = process.stdout, stderr = process.stderr, cwd = process.cwd(), thumbnail = sharpThumbnail } = {},
) {
  if (argv.length === 0 || argv.includes("--help") || argv.includes("-h")) {
    stdout.write(`${USAGE}\n`)
    return argv.length === 0 ? EXIT_USAGE : 0
  }

  const token = env[TOKEN_ENV]

  // Every line out goes through this, so the token cannot reach a terminal or
  // a CI log by way of an error that happened to quote a header or a URL.
  const redact = (s) => (token ? String(s).split(token).join("<token>") : String(s))
  const say = (s) => stdout.write(`${redact(s)}\n`)
  const complain = (s) => stderr.write(`h2kext-publish: ${redact(s)}\n`)

  try {
    // Walked by index, like h2kext-pack: `indexOf` finds the FIRST occurrence,
    // and a value can repeat an option's name. Unlike h2kext-pack, an option
    // this does not know is a refusal: `--token h2kc_…` from an older script
    // would otherwise be ignored and the token sent nowhere, after sitting in
    // the shell history — the reason the flag does not exist.
    let source
    let channel
    let notes
    let catalog = DEFAULT_CATALOG
    let forceName = false
    let screenshotsDir
    let screenshotsOnly = false
    // An option at the end of the line has no value, and `--notes` with none
    // would silently publish without notes — the one option whose absence
    // looks like success.
    const valueOf = (i) => {
      if (i + 1 >= argv.length) throw new PublishError(`${argv[i]} needs a value`, EXIT_USAGE)
      return argv[i + 1]
    }
    for (let i = 0; i < argv.length; i++) {
      const arg = argv[i]
      if (arg === "--channel") channel = valueOf(i++)
      else if (arg === "--notes") notes = valueOf(i++)
      else if (arg === "--catalog") catalog = valueOf(i++)
      else if (arg === "--force-name") forceName = true
      else if (arg === "--screenshots") screenshotsDir = valueOf(i++)
      else if (arg === "--screenshots-only") screenshotsOnly = true
      else if (arg === "--token") throw new PublishError(`there is no --token option; set ${TOKEN_ENV} instead`, EXIT_USAGE)
      else if (arg.startsWith("-")) throw new PublishError(`unknown option '${arg}'`, EXIT_USAGE)
      else if (source === undefined) source = arg
    }

    if (!source) throw new PublishError("name the bundle or directory to publish", EXIT_USAGE)
    channel ??= DEFAULT_CHANNEL
    if (!CHANNELS.includes(channel)) {
      throw new PublishError(`--channel must be one of ${CHANNELS.join(", ")}${channel ? `, not '${channel}'` : ""}`, EXIT_USAGE)
    }
    if (!token) {
      throw new PublishError(`no token — set ${TOKEN_ENV} (get one at ${catalog}/publish)`, EXIT_USAGE)
    }
    try {
      catalog = new URL(catalog).href.replace(/\/$/, "")
    } catch {
      throw new PublishError(`--catalog must be a URL, not '${catalog}'`, EXIT_USAGE)
    }

    // The folder is read before anything is sent, so what can be checked
    // without decoding — type, size, count, captions — stops the command
    // before the version is published rather than after; the rest is the
    // catalog's to refuse. Without `--screenshots`, only a folder that exists
    // and holds pictures is a set: a project with none, or a stray empty
    // `screenshots/` where the command happens to run, has not asked for its
    // screenshots to be taken down. Naming the folder is how to ask.
    let shots
    const folder = resolve(cwd, screenshotsDir ?? SCREENSHOTS_DIR)
    if (
      screenshotsDir !== undefined ||
      (await stat(folder).then(
        (s) => s.isDirectory(),
        () => false,
      ))
    ) {
      shots = await readScreenshotFolder(folder)
      if (screenshotsDir === undefined && shots.length === 0) {
        say(`./${SCREENSHOTS_DIR} holds no screenshots; leaving the catalog's as they are (name it with --screenshots to remove them all)`)
        shots = undefined
        if (screenshotsOnly) return 0
      }
    } else if (screenshotsOnly) {
      throw new PublishError(`--screenshots-only, but there is no ./${SCREENSHOTS_DIR} folder; name one with --screenshots`, EXIT_USAGE)
    }

    const bytes = await loadBundle(source, { forceName })
    if (bytes.length > MAX_BUNDLE_BYTES) {
      throw new PublishError(
        `${source} is ${bytes.length} bytes; the catalog takes at most 16 MiB (${MAX_BUNDLE_BYTES} bytes), because the app downloads no more than that`,
      )
    }
    const manifest = readManifestFromBundle(bytes)
    for (const field of ["key", "version"]) {
      if (typeof manifest[field] !== "string" || manifest[field].trim() === "") {
        throw new PublishError(`${MANIFEST_ENTRY} inside the bundle has no '${field}'`)
      }
    }
    const syncShots = async () => {
      say(screenshotState(await syncScreenshots({ key: manifest.key, shots, catalog, token }, { fetch, thumbnail })))
    }
    if (screenshotsOnly) {
      await syncShots()
      return 0
    }

    say(`publishing ${manifest.key} ${manifest.version}${manifest.name ? ` — ${manifest.name}` : ""} → ${channel} at ${catalog}`)

    const result = await publish({ bytes, manifest, channel, catalog, token }, { fetch })
    say(`published ${result.key} ${result.version} → ${result.channel} (${STATUS_WORDS[result.status] ?? result.status})`)
    if (result.url) say(result.url)

    if (notes !== undefined) {
      try {
        if (result.submissionId === undefined || result.submissionId === null) {
          throw new PublishError(`the catalog's answer named no submissionId to attach them to`)
        }
        await setReleaseNotes({ submissionId: result.submissionId, notes, catalog, token }, { fetch })
      } catch (e) {
        if (!(e instanceof PublishError)) throw e
        // The version is published and stays published: the notes are the
        // site's to edit at any time, so nothing is rolled back — but the
        // exit code says the command did not do all it was asked.
        complain(`warning: ${result.key} ${result.version} is published, but its release notes were not set — ${e.message}. Edit them on the site instead.`)
        return EXIT_REFUSED
      }
    }
    if (shots !== undefined) {
      try {
        await syncShots()
      } catch (e) {
        if (!(e instanceof PublishError)) throw e
        complain(`warning: ${result.key} ${result.version} is published, but its screenshots were not updated — ${e.message}`)
        return EXIT_REFUSED
      }
    }
    return 0
  } catch (e) {
    if (e instanceof PublishError) {
      complain(e.message)
      return e.exitCode
    }
    // Anything else is a bug here, not a refusal — but it still goes through
    // the redactor rather than to an uncaught-exception stack trace.
    complain(e.stack ?? e)
    return EXIT_REFUSED
  }
}

// Run only as the command. `realpathSync` because npm installs a bin as a
// symlink while `import.meta.url` resolves to the real file — compared raw,
// `npx h2kext-publish` would import this module and then do nothing.
if (process.argv[1] && import.meta.url === pathToFileURL(realpathSync(process.argv[1])).href) {
  process.exit(await main(process.argv.slice(2)))
}
