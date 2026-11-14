// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Reading a FlexRadio node's `slice` setting. The driver's session, its
// editor's validator and the key of the receiver the node offers all read
// the stored value through here, so no two of them can disagree about which
// slice a spelling means.

/// The radio's own letters for its slices, by index.
const flexSliceLabels = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

/// Null for anything that isn't a slice the driver offers. A value
/// round-tripped through JSON (or a form) arrives as a String or a num
/// depending on the path, so both are read.
int? parseFlexSlice(dynamic raw) {
  final value = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}'.trim());
  if (value == null) return null;
  return (value >= 0 && value < flexSliceLabels.length) ? value : null;
}
