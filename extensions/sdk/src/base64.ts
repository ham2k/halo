// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// Base64 for binary socket frames, which cross the host bridge as JSON.
// Hand-written because QuickJS-NG, which runs every native build, has no
// `atob`/`btoa` — and code that reached for them would work only on web.

const ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
const VALUES = new Map<string, number>([...ALPHABET].map((c, i) => [c, i]))

export function bytesToBase64(bytes: Uint8Array): string {
  let out = ""
  for (let i = 0; i < bytes.length; i += 3) {
    const a = bytes[i]
    const b = i + 1 < bytes.length ? bytes[i + 1] : 0
    const c = i + 2 < bytes.length ? bytes[i + 2] : 0
    const n = (a << 16) | (b << 8) | c
    out += ALPHABET[(n >> 18) & 63] + ALPHABET[(n >> 12) & 63]
    out += i + 1 < bytes.length ? ALPHABET[(n >> 6) & 63] : "="
    out += i + 2 < bytes.length ? ALPHABET[n & 63] : "="
  }
  return out
}

/// Throws on anything that is not canonical padded base64, rather than
/// decoding it to something else: the host only ever sends that.
export function base64ToBytes(text: string): Uint8Array {
  if (text.length % 4 !== 0) throw new Error("invalid base64")
  const padding = text.endsWith("==") ? 2 : text.endsWith("=") ? 1 : 0
  const bytes = new Uint8Array((text.length / 4) * 3 - padding)
  let o = 0
  for (let i = 0; i < text.length; i += 4) {
    let n = 0
    for (let j = 0; j < 4; j++) {
      const ch = text[i + j]
      const value = ch === "=" && i + 4 === text.length && j >= 4 - padding ? 0 : VALUES.get(ch)
      if (value === undefined) throw new Error("invalid base64")
      n = (n << 6) | value
    }
    if (o < bytes.length) bytes[o++] = (n >> 16) & 255
    if (o < bytes.length) bytes[o++] = (n >> 8) & 255
    if (o < bytes.length) bytes[o++] = n & 255
  }
  return bytes
}
