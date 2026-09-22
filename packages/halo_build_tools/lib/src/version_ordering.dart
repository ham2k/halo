// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

/// Whether [available] names a strictly newer *release line* than [current] —
/// used to decide whether to prompt the user that a newer binary is out (the
/// `latestRelease` feature flag vs the running [kPublicVersion]). A port of
/// app-polo's `_isNewerVersion`, made total and order-correct.
///
/// Pre-release modifiers are dropped from both sides first (everything from the
/// first `-` or space), so `26.8.1-alpha1` compares as `26.8.1`: a pre-release
/// of a line you are already on is not a newer *binary*. The remaining
/// dot-separated integers are compared position by position, shorter one padded
/// with zeros, so `26.8` and `26.8.0` are equal and `26.9` beats `26.8.5`.
///
/// Any part that is missing or non-numeric on either side is treated as `0`;
/// an empty or unparseable [available] therefore just returns false (no prompt),
/// which is the safe direction.
bool isNewerRelease({required String current, required String available}) {
  final currentParts = _releaseParts(current);
  final availableParts = _releaseParts(available);
  final length = currentParts.length > availableParts.length ? currentParts.length : availableParts.length;

  for (var i = 0; i < length; i++) {
    final c = i < currentParts.length ? currentParts[i] : 0;
    final a = i < availableParts.length ? availableParts[i] : 0;
    if (a > c) return true;
    if (a < c) return false;
  }
  return false; // equal
}

/// The numeric dotted parts of [version], with any pre-release/build modifier
/// (from the first `-` or whitespace) stripped and non-numeric parts read as 0.
List<int> _releaseParts(String version) {
  final base = version.trim().split(RegExp(r'[\s-]')).first;
  if (base.isEmpty) return const [];
  return base.split('.').map((p) => int.tryParse(p) ?? 0).toList();
}
