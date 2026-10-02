// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The File Stash upload's request body. Split from index.ts so it can be
// tested without booting the extension host, the same way report.ts is.

/// The stash endpoint, shared so the request and the reading of its
/// rejection cannot name it differently.
export const STASH_FILES_PATH = "v1/stash_files"

/// What the server records as the upload's origin — app-polo sends
/// `com.ham2k.polo/exports` for the same flow.
export const STASH_SOURCE = "com.ham2k.halo/exports"

export type StashFile = {
  filename: string
  content: string
  mimeType?: string
  format?: string
}

export type StashGroup = {
  uuid: string
  title?: string
}

/// A `multipart/form-data` body for one `POST v1/stash_files`, as a string.
///
/// Hand-built because `host.fetch` carries only a string body — there is no
/// FormData in the sandbox. A string is enough: the server accepts plain text
/// and nothing else (`StashFile#file_must_be_plain_text`), so there are no
/// binary bytes a string could mangle; the host sends it as UTF-8.
///
/// [boundary] is the caller's so tests can pin it. It must not occur in any
/// part, or the server splits the file at that line — [stashBoundary] makes
/// one that doesn't.
export function buildStashMultipart(file: StashFile, group: StashGroup, boundary: string): { contentType: string; body: string } {
  const fields: [string, string][] = [
    ["stash_file[filename]", file.filename],
    ...(file.format ? [["stash_file[format]", file.format] as [string, string]] : []),
    ["stash_file[source]", STASH_SOURCE],
    ["stash_file[group_uuid]", group.uuid],
    ...(group.title ? [["stash_file[group_title]", group.title] as [string, string]] : []),
  ]

  const parts = [
    ...fields.map(([name, value]) => `Content-Disposition: form-data; name="${name}"\r\n\r\n${value}`),
    `Content-Disposition: form-data; name="stash_file[file]"; filename="${quotedFilename(file.filename)}"\r\n` +
      `Content-Type: ${file.mimeType || "text/plain"}\r\n\r\n${file.content}`,
  ]

  return {
    contentType: `multipart/form-data; boundary=${boundary}`,
    body: parts.map((part) => `--${boundary}\r\n${part}\r\n`).join("") + `--${boundary}--\r\n`,
  }
}

/// A boundary that appears nowhere in [file] or [group]. Random rather than
/// fixed: a log's comment field is operator-typed text and can hold any line.
export function stashBoundary(file: StashFile, group: StashGroup, random: () => number = Math.random): string {
  const haystack = [file.filename, file.content, file.format ?? "", group.uuid, group.title ?? ""].join("\n")
  for (;;) {
    const boundary = `----HaLoStash${Math.floor(random() * 2 ** 48).toString(16)}${Math.floor(random() * 2 ** 48).toString(16)}`
    if (!haystack.includes(boundary)) return boundary
  }
}

/// The filename as it may sit between the quotes of a Content-Disposition
/// header. A quote would end the value early and a line break would end the
/// header; both are percent-encoded, the way browsers encode them in a form
/// upload (WHATWG HTML, "multipart/form-data encoding algorithm").
function quotedFilename(filename: string): string {
  return filename.replace(/"/g, "%22").replace(/\r/g, "%0D").replace(/\n/g, "%0A")
}
