// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Generic ref-field readers shared between r1-vhf-tests and rsgb-vhf-tests
// index.ts — both extensions store their exchange fields the same way, in a
// ref keyed by the extension's own type.

import type { JSONValue } from "@ham2k/extension-sdk"

export function str(value: JSONValue | undefined): string {
  return typeof value === "string" ? value : ""
}

export function refOfType(container: Record<string, JSONValue>, type: string): Record<string, JSONValue> | undefined {
  return ((container.refs as Record<string, JSONValue>[] | undefined) ?? []).find((r) => r?.type === type)
}

/// Reads a serial off a QSO's own ref — same coercion cqwpx uses, since a
/// typed `their` number arrives as a string but an allocated `our` one may
/// already be a number.
export function serial(qso: Record<string, JSONValue>, type: string, field: string): string {
  const value = refOfType(qso, type)?.[field]
  if (typeof value === "number") return String(value)
  const digits = str(value).trim()
  return /^\d+$/.test(digits) ? String(parseInt(digits, 10)) : ""
}
