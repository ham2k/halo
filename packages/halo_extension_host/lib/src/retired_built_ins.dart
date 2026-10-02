// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The extensions the app used to build in, for everything that still has to
// know them once they are gone: the app, carrying an install's state onto
// their catalog copies, and halo-ext, deciding which pre-loads are on by
// default.

/// Every extension the app used to build in beyond its core ones, and whether
/// it was on by default — what an install that ran them still needs to know
/// once they are gone (docs/extensions/distribution.md, "Retired built-ins").
///
/// Each one's catalog copy is the same extension under the reserved prefix
/// (`ham2k-pota` for `pota`): the catalog cannot serve a bare `pota`, since the
/// keys it hands Ham2K's own publishers all carry `ham2k-`. Everything the app
/// stores per extension — its settings group, its panel values, its account
/// credentials, the operator's on/off choice — hangs off the name, so the twin
/// inherits it from the built-in.
///
/// The default matters as much as the key. An installed extension is on
/// unless switched off, so without it SOTA and WWFF, off by default as
/// built-ins, would arrive switched on for every install whose operator never
/// touched them.
///
/// `ham2k-lookup` is absent: it was built in under the name its catalog copy
/// has, so there is nothing to carry. Never shrinks — an install may skip any
/// number of releases between the last one with its built-ins and this one.
const kRetiredBuiltIns = <String, bool>{
  'qrz': true,
  'call-notes': true,
  'spot-history': true,
  'call-history': true,
  'pota': true,
  'sota': false,
  'wca': false,
  'gma': false,
  'mota': false,
  'siota': false,
  'wwbota': false,
  'zlota': false,
  'wwff': false,
  'llota': false,
  'tota': false,
  'bca': false,
  'blha': false,
  'eca': false,
  'ela': false,
  'pga': false,
  'custom': false,
  'satellites': false,
  'simple-contest': false,
  'cqww': false,
  'arrl-dx': false,
  'cqwpx': false,
  'iaru-hf': false,
  'naqp': false,
  'stateparks': false,
  'fd': false,
  'wfd': false,
  'arrl-vhf-tests': false,
  'r1-vhf-tests': false,
  'rsgb-vhf-tests': false,
  'r1-fd': false,
  'nrrl-nfd': false,
  'cwt': false,
  'qp': false,
  'parksnpeaks': false,
  'custom-text': false,
};
