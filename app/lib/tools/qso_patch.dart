// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Merging an extension's `processQsoBeforeSave` patch into a QSO.
//
// A pure function, deliberately separate from `ExtensionService`: this is the
// contract extensions are held to, and it needs to be exercised against the
// awkward shapes a hook can return without standing up the JS runtime.

/// [qso] with [patch] merged in.
///
/// Shallow at the top level, EXCEPT `our` and `their`, which merge one level
/// deep. That exception is the whole point: a contest returns
/// `{'their': {'exchange': 'ZN14'}}` meaning "set this one field", and a plain
/// shallow merge would replace the whole `their` map — taking the callsign,
/// the RST and the lookup's `guess` with it.
///
/// Neither input is mutated: the caller's QSO may be the one a call-list batch
/// is still iterating over, so writing through would leak one call's exchange
/// onto the next.
Map<String, dynamic> mergeQsoPatch(Map<String, dynamic> qso, Map<String, dynamic> patch) {
  if (patch.isEmpty) return qso;

  final merged = Map<String, dynamic>.from(qso);
  for (final entry in patch.entries) {
    final key = entry.key;
    final value = entry.value;

    // `refs` is the extension's own storage and the core's — a patch that
    // rewrote it could drop another activity's ref, or the serial the core is
    // about to allocate onto it. Extensions already own their ref through the
    // control descriptors; this hook is for projecting OUT of it.
    if (key == 'refs' || key == 'uuid') continue;

    if ((key == 'our' || key == 'their') && value is Map) {
      final existing = merged[key];
      merged[key] = {
        if (existing is Map) ...existing.cast<String, dynamic>(),
        ...value.cast<String, dynamic>(),
      };
    } else {
      merged[key] = value;
    }
  }
  return merged;
}
