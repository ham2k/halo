// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// Reads and writes for a record keyed on what was logged — a call, a band, a
// mode, a reference. Any of those can be spelled `__proto__` or `constructor`,
// and a plain property access with such a key reaches the prototype instead of
// an entry. Import by relative path; not part of the SDK's public surface.

const hasOwn = Object.prototype.hasOwnProperty

/// [record]'s own entry under [key]; never an inherited property.
export function entry<V>(record: Record<string, V>, key: string): V | undefined {
  return hasOwn.call(record, key) ? record[key] : undefined
}

/// Sets [record]'s own entry under [key]. A first write defines it: assigning
/// `__proto__` replaces the record's prototype instead, and assigning a name
/// the frozen `Object.prototype` holds throws.
export function setEntry<V>(record: Record<string, V>, key: string, value: V): void {
  if (hasOwn.call(record, key)) record[key] = value
  else Object.defineProperty(record, key, { value, writable: true, enumerable: true, configurable: true })
}
