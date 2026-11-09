// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

/// [base] with [patch] laid over it, as an extension's `host.updateDraft`
/// patch is laid over the QSO being composed: a map in both merges key by
/// key, all the way down, so `{their: {sent: '599'}}` leaves the call; a null
/// takes the key out; anything else — a list of refs included — replaces
/// what was there whole. Neither argument is written.
Map<String, dynamic> mergeDraftPatch(Map<String, dynamic> base, Map<String, dynamic> patch) {
  final result = {...base};
  for (final MapEntry(:key, :value) in patch.entries) {
    final held = result[key];
    if (value == null) {
      result.remove(key);
    } else if (value is Map && held is Map) {
      result[key] = mergeDraftPatch(held.cast<String, dynamic>(), value.cast<String, dynamic>());
    } else {
      result[key] = value;
    }
  }
  return result;
}
