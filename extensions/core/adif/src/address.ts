// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// QSON mailing address → ADIF `ADDRESS`.

const text = (value: unknown): string => (typeof value === "string" ? value.trim() : "")

/// ADIF `ADDRESS` is the station's complete mailing address — name, street,
/// town and postal code, country — as a MultilineString, whose lines break on
/// CR LF.
///
/// Written only from a source that has a street: without one, what is left is
/// a town, which QTH already says, and nothing a card can be mailed to.
/// [source] is one station map (`their`, or `their.guess`), never a blend of
/// the two — the lookup merge keeps a guess's address lines from one source,
/// and splicing an operator's correction into them here would undo that.
export function adifAddress(name: unknown, source: Record<string, unknown>): string | undefined {
  const street = text(source.street)
  if (!street) return undefined
  const region = [text(source.state), text(source.postal)].filter((part) => part).join(" ")
  const town = [text(source.city), region].filter((part) => part).join(", ")
  return [text(name), street, town, text(source.country)].filter((line) => line).join("\r\n")
}
