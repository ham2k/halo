// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The key a scrollable takes when its rows MOVE between rebuilds, so that the
// web's accessibility DOM does not keep the previous arrangement's geometry
// and hand clicks to the wrong row (docs/quirks.md).

import 'package:flutter/widgets.dart';

/// A [Key] identifying WHICH rows a scrollable currently holds, for a list
/// whose contents change while the same scrollable stays mounted — a search
/// filter narrowing it, a row removed, a re-sort.
///
/// On the web a click never reaches the canvas: rows are hit-tested as
/// `<flt-semantics>` DOM elements layered over it, and a list rebuilt in place
/// can leave them a row's height from what is painted, so the click acts on a
/// neighbouring row. A changed key builds a fresh scrollable, whose nodes are
/// positioned from scratch. docs/quirks.md holds the measurements and the
/// revisit trigger; this is an upstream defect, not a design decision.
///
/// Pass the row IDENTITIES, in the order they are listed — a callsign, a
/// reference, an extension key. Never the row COUNT (two different filters can
/// match the same number of rows) and never a value the row displays but does
/// not identify (a spot's age restates itself every tick, and the list would
/// remount continuously).
///
/// Deliberately hashed rather than joined: this runs on every build of every
/// list that uses it, and a joined string of several hundred callsigns is
/// rebuilt per frame. A collision means a rebuild that should have remounted
/// does not, which is the wrong-row click itself — the case for hashing is
/// that two row sets colliding is vanishingly unlikely, not that the
/// consequence is mild.
///
/// The real trigger is rows MOVING, which the identities are a proxy for and
/// not a complete one: anything that changes a row's HEIGHT moves every row
/// below it while the set is untouched — a locale change rewriting every
/// label, a subtitle that wraps to a second line at one font scale. Identity
/// covers what filtering does; a list whose rows change height under it needs
/// its own thinking.
///
/// NOT for a list that only ever grows at the END. An append moves no existing
/// row, so nothing goes stale, and remounting would throw away scroll position
/// and every row's state for nothing. A PREPEND is not that case — it moves
/// everything below it, which is what a newest-first log does on every entry.
Key listContentsKey(Iterable<Object?> identities) => ValueKey<int>(Object.hashAll(identities));
