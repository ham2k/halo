// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Merging an extension's `processQsoBeforeSave` patch into a QSO.
//
// A pure function, deliberately separate from `ExtensionService`: this is the
// contract extensions are held to, and it needs to be exercised against the
// awkward shapes a hook can return without standing up the JS runtime.

/// [qso] with [patch] merged in, on behalf of the extension [owner] — the hook
/// key that produced it.
///
/// Shallow at the top level, EXCEPT three cases.
///
/// `our` and `their` merge one level deep. That exception is the whole point:
/// a contest returns `{'their': {'exchange': 'ZN14'}}` meaning "set this one
/// field", and a plain shallow merge would replace the whole `their` map —
/// taking the callsign, the RST and the lookup's `guess` with it.
///
/// `refs` merges FIELD-WISE into the ref whose `type` is [owner], and can touch
/// nothing else. A contest needs this to record what it actually sent when the
/// operator typed nothing — the country file's zone, written as data of record
/// so the log, the scorer and the export cannot disagree
/// (docs/design/contests.md §8). The narrowness is what makes it safe:
///   * no other activity's ref can be dropped or altered — a patch entry whose
///     type isn't [owner] is ignored;
///   * no ref is ever removed, only merged into or appended;
///   * no field is ever removed, so the serial the core allocates moments later
///     inside `QsosRepository.add`'s transaction cannot be clobbered.
///
/// `uuid` is never patchable.
///
/// Neither input is mutated: the caller's QSO may be the one a call-list batch
/// is still iterating over, so writing through would leak one call's exchange
/// onto the next.
Map<String, dynamic> mergeQsoPatch(Map<String, dynamic> qso, Map<String, dynamic> patch, {required String owner}) {
  if (patch.isEmpty) return qso;

  final merged = Map<String, dynamic>.from(qso);
  for (final entry in patch.entries) {
    final key = entry.key;
    final value = entry.value;

    if (key == 'uuid') continue;

    if (key == 'refs') {
      final refs = _mergeOwnRef(merged['refs'], value, owner);
      if (refs != null) merged['refs'] = refs;
      continue;
    }

    if ((key == 'our' || key == 'their') && value is Map) {
      final existing = merged[key];
      merged[key] = {if (existing is Map) ...existing.cast<String, dynamic>(), ...value.cast<String, dynamic>()};
    } else {
      merged[key] = value;
    }
  }
  return merged;
}

/// [existing] refs with [owner]'s own ref merged from [patchRefs] — or null
/// when the patch carried nothing this extension is allowed to write, so the
/// caller leaves `refs` exactly as it found it.
List<Map<String, dynamic>>? _mergeOwnRef(Object? existing, Object? patchRefs, String owner) {
  if (patchRefs is! List || owner.isEmpty) return null;

  final result = <Map<String, dynamic>>[
    for (final ref in (existing is List ? existing : const []))
      if (ref is Map) ref.cast<String, dynamic>(),
  ];

  var changed = false;
  for (final entry in patchRefs) {
    if (entry is! Map) continue;
    // The only ref an extension may write is the one it owns. A contest trying
    // to stamp POTA's ref — or its own under some other type — is ignored
    // rather than trusted.
    if (entry['type'] != owner) continue;

    final index = result.indexWhere((r) => r['type'] == owner);
    if (index >= 0) {
      result[index] = {...result[index], ...entry.cast<String, dynamic>()};
    } else {
      result.add({...entry.cast<String, dynamic>()});
    }
    changed = true;
  }
  return changed ? result : null;
}
