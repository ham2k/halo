// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { test } from "node:test"
import assert from "node:assert/strict"

import { canonicalMode, expectedSideband, isUnexpectedSideband, modesMatchForDupe } from "./modes.ts"

test("modesMatchForDupe folds the sideband spellings together", () => {
  // The spot board's whole reason for this: POTA and SOTA say SSB where the
  // radio reported the sideband, and the contact is the same one either way.
  assert.equal(modesMatchForDupe("SSB", "USB"), true)
  assert.equal(modesMatchForDupe("usb", "SSB"), true)
  assert.equal(modesMatchForDupe("USB", "LSB"), true)
})

test("modesMatchForDupe matches a submode against its ADIF parent", () => {
  assert.equal(modesMatchForDupe("MFSK", "FT4"), true)
  assert.equal(modesMatchForDupe("DMR", "DIGITALVOICE"), true)
  assert.equal(modesMatchForDupe("DV", "DMR"), true)
  assert.equal(modesMatchForDupe("RTTY", "ASCI"), true)
})

test("modesMatchForDupe keeps sibling submodes apart", () => {
  // Two submodes of one parent are two emissions, and award and contest
  // credit counts them separately. Folding everything to the parent mode —
  // the obvious shortcut — loses exactly these.
  assert.equal(modesMatchForDupe("FT4", "FT2"), false)
  assert.equal(modesMatchForDupe("DMR", "C4FM"), false)
})

test("modesMatchForDupe keeps unrelated modes apart", () => {
  assert.equal(modesMatchForDupe("CW", "SSB"), false)
  assert.equal(modesMatchForDupe("FT8", "RTTY"), false)
  assert.equal(modesMatchForDupe("FM", "AM"), false)
})

test("modesMatchForDupe reads a coarse candidate as any mode in its category", () => {
  assert.equal(modesMatchForDupe("FT8", "DATA"), true)
  assert.equal(modesMatchForDupe("FT8", "DIGI"), true)
  assert.equal(modesMatchForDupe("FM", "PHONE"), true)
  assert.equal(modesMatchForDupe("USB", "PHONE"), true)
  assert.equal(modesMatchForDupe("CW", "DATA"), false)
  assert.equal(modesMatchForDupe("FT8", "PHONE"), false)
})

test("modesMatchForDupe does not let a coarse mode in the LOG swallow its category", () => {
  // A QSO logged as DATA — which is what tapping a SOTAwatch spot fills the
  // mode field with — is one contact, not a claim on every digital mode. Core
  // scoring never appends a duplicate, so a coarse entry that matched the
  // whole category would strike this station on this band forever.
  assert.equal(modesMatchForDupe("DATA", "FT8"), false)
  assert.equal(modesMatchForDupe("PHONE", "FM"), false)
})

test("modesMatchForDupe widens a coarse candidate only against a mode ADIF names", () => {
  // `superModeForMode` answers 'DATA' for everything it does not recognize,
  // so an unguarded coarse rule matches junk, an imported OTHER, and the
  // other coarse spellings — including PHONE, which is not a phone mode to it.
  assert.equal(modesMatchForDupe("ZZTOP", "DATA"), false)
  assert.equal(modesMatchForDupe("PHONE", "DATA"), false)
  assert.equal(modesMatchForDupe("DATA", "PHONE"), false)
})

test("modesMatchForDupe matches an absent mode only against another absent one", () => {
  // `superModeForMode('')` answers 'DATA', so a mode-less contact would
  // otherwise duplicate against every DATA spot on the board.
  assert.equal(modesMatchForDupe("", ""), true)
  assert.equal(modesMatchForDupe("", "DATA"), false)
  assert.equal(modesMatchForDupe("", "SSB"), false)
})

test("canonicalMode gives one spelling per emission and leaves the rest alone", () => {
  // Core scoring keys its band/mode tallies on this, so what it merges is what
  // an operation reports as one mode worked — and what it must NOT merge is
  // every pair the wider duplicate rule folds.
  assert.equal(canonicalMode("USB"), "SSB")
  assert.equal(canonicalMode("lsb"), "SSB")
  assert.equal(canonicalMode("DV"), "DIGITALVOICE")
  assert.equal(canonicalMode("ft4"), "FT4")
  assert.equal(canonicalMode("MFSK"), "MFSK")
  assert.equal(canonicalMode("DATA"), "DATA")
})

test("canonicalMode answers nothing for a mode that is only whitespace", () => {
  // A tally keyed on the result would otherwise gain a nameless entry: a
  // phantom mode in the count, and a blank in the breakdown line. `str()` in
  // core scoring does not trim, so this really does arrive.
  assert.equal(canonicalMode(""), "")
  assert.equal(canonicalMode("   "), "")
})

test("expectedSideband splits on the frequency, with the 60m window as the exception", () => {
  // A plain split through HF, not a band lookup — so this needs no band table
  // to agree with the app's, which is what makes the two identical by
  // construction rather than by maintenance.
  assert.equal(expectedSideband({ freqKHz: 7185 }), "LSB")
  assert.equal(expectedSideband({ freqKHz: 14250 }), "USB")
  assert.equal(expectedSideband({ freqKHz: 5357 }), "USB")
  // The edges of the 60m window and of the split itself.
  assert.equal(expectedSideband({ freqKHz: 4999 }), "LSB")
  assert.equal(expectedSideband({ freqKHz: 5000 }), "USB")
  assert.equal(expectedSideband({ freqKHz: 5999 }), "USB")
  assert.equal(expectedSideband({ freqKHz: 6000 }), "LSB")
  assert.equal(expectedSideband({ freqKHz: 8999 }), "LSB")
  assert.equal(expectedSideband({ freqKHz: 9000 }), "USB")
  // Outside every allocation is still answerable, which is the point: an
  // exported file must not lose a sideband just because the frequency sits in
  // a gap no band table names.
  assert.equal(expectedSideband({ freqKHz: 10300 }), "USB")
  assert.equal(expectedSideband({ freqKHz: 2400 }), "LSB")
})

test("expectedSideband falls back to the band, both spellings counted", () => {
  assert.equal(expectedSideband({ band: "40m" }), "LSB")
  assert.equal(expectedSideband({ band: "20m" }), "USB")
  assert.equal(expectedSideband({ band: "60m" }), "USB")
  // A contact carrying the other spelling arrives from an import or a spot
  // feed; answering upper for it puts the wrong sideband in the file.
  assert.equal(expectedSideband({ band: "75m" }), "LSB")
  assert.equal(expectedSideband({ band: "2200m" }), "LSB")
  // The frequency outranks the band.
  assert.equal(expectedSideband({ freqKHz: 7185, band: "20m" }), "LSB")
  // The only undefined left: nothing stated at all.
  assert.equal(expectedSideband({}), undefined)
})

test("isUnexpectedSideband fires only on the sideband that place does not run", () => {
  assert.equal(isUnexpectedSideband("USB", { freqKHz: 7185 }), true)
  assert.equal(isUnexpectedSideband("LSB", { freqKHz: 7185 }), false)
  assert.equal(isUnexpectedSideband("lsb", { freqKHz: 14250 }), true)
  assert.equal(isUnexpectedSideband("LSB", { freqKHz: 5357 }), true)
  assert.equal(isUnexpectedSideband("USB", { band: "80m" }), true)
  // A generic SSB names no sideband, so it contradicts nothing — without this
  // the export would state a submode on every phone contact.
  assert.equal(isUnexpectedSideband("SSB", { freqKHz: 7185 }), false)
  assert.equal(isUnexpectedSideband("FT8", { freqKHz: 7185 }), false)
  assert.equal(isUnexpectedSideband(undefined, { freqKHz: 7185 }), false)
  // Nothing stated, nothing to contradict.
  assert.equal(isUnexpectedSideband("LSB", {}), false)
})

test("isUnexpectedSideband treats whitespace exactly as the Dart twin does", () => {
  // Neither side trims. Pinned because the pair is documented to answer
  // identically and only one of them ever did trim — a mode arriving with a
  // stray space would have been flagged on one side and not the other, which
  // is the app-versus-file contradiction the pairing exists to prevent.
  assert.equal(isUnexpectedSideband(" LSB", { freqKHz: 14250 }), false)
  assert.equal(isUnexpectedSideband("LSB", { freqKHz: 14250 }), true)
})
