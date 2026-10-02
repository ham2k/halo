// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The clock DataFileManager's grace-period purge reads: when each non-core
// extension became disabled, and nothing at all once it is enabled again.
//
// Kept apart from ExtensionService because it is bookkeeping over two prefs
// maps rather than anything the runtime does, and because the purge it feeds
// is destructive — a reader deciding whether a stamp is right should not have
// to find it inside four thousand lines of extension host.

import 'package:halo_core/halo_core.dart';

import 'extension_info.dart';
import 'preloaded_extensions.dart';
import '../settings_service.dart';

/// Stamps the moment each non-core extension became disabled, and clears the
/// stamp when it is enabled again.
///
/// Only meaningful for extensions that could own data, but harmless (and
/// simpler) to track for all non-core keys.
///
/// Also prunes both this map and `extensionOverrides` of any key absent from
/// [available] entirely, and from what the operator installed
/// (`SettingsService.extensionsInstalled`) — an extension deleted from the
/// build or uninstalled, not merely missing from the store, disabled, or
/// gated behind an experiment (which still keeps its entry there; see
/// `ExtensionService.isExtensionAvailable`). Without this, a key an
/// install migrated (like a former `hamdb: false` override) outlives the
/// extension it named forever: nothing else ever visits an unknown key to
/// remove it.
///
/// Pruning is skipped while [available] is still empty — before
/// `loadAvailableExtensions` first resolves, an empty list means "not loaded
/// yet", not "nothing exists", and treating it as the latter would wipe out
/// overrides set before boot finishes (e.g. ONBOARD_AS picks written while
/// the extension index is still loading).
Future<void> updateExtensionDisabledSince({
  required SettingsService settings,
  required List<ExtensionInfo> available,
  required bool Function(ExtensionInfo info) isActive,
}) async {
  final disabledSince = {...settings.extensionDisabledSince};
  // With what the operator installed: an extension missing from the store is
  // not one deleted from the build, and pruning its choice would bring it
  // back switched on — or SOTA and WWFF, off by default — once it is restored.
  // And with the retired built-ins: their choices are what a twin inherits
  // when it arrives, which for one the app does not pre-load is whenever the
  // catalog is next reachable.
  final knownKeys = {for (final info in available) info.key, ...settings.extensionsInstalled.keys, ...kRetiredBuiltIns.keys};
  final canPrune = available.isNotEmpty;
  // REAL: this stamp persists, and the reader is a LATER LAUNCH's clock
  // (DataFileManager.purgeStaleExtensionData, at boot), which is back on real
  // time. Travelled, `DEVTT -30d` then disabling an extension writes a stamp
  // 30 days old, and the next boot purges its lookup rows and downloaded data
  // on the spot — deleting inside the 7-day grace window that exists so a
  // re-enable keeps everything. Testing the purge is done by travelling the
  // READER forward, which still works.
  final now = realNowMillis();
  var changed = false;
  // By KEY, not entry by entry: should the list ever hold a key twice, the
  // inactive copy, judged on its own, would stamp the key its live twin runs
  // under, and seven days on the purge would delete the running extension's
  // downloaded data.
  final nonCoreKeys = <String>{};
  final activeKeys = <String>{};
  for (final info in available) {
    if (info.core) continue;
    nonCoreKeys.add(info.key);
    if (isActive(info)) activeKeys.add(info.key);
  }
  for (final key in nonCoreKeys) {
    final disabled = !activeKeys.contains(key);
    if (disabled && !disabledSince.containsKey(key)) {
      disabledSince[key] = now;
      changed = true;
    } else if (!disabled && disabledSince.remove(key) != null) {
      changed = true;
    }
  }
  // A retired built-in never runs again, so its data files are the purge's to
  // clear a week on — the rows its twin still fills excepted. Listed nowhere,
  // it would otherwise never be stamped, and its cache would stay forever.
  for (final key in kRetiredBuiltIns.keys) {
    if (!nonCoreKeys.contains(key) && !disabledSince.containsKey(key)) {
      disabledSince[key] = now;
      changed = true;
    }
  }
  if (canPrune) {
    for (final staleKey in disabledSince.keys.where((key) => !knownKeys.contains(key)).toList()) {
      disabledSince.remove(staleKey);
      changed = true;
    }
  }
  if (changed) await settings.setExtensionDisabledSince(disabledSince);

  if (canPrune) {
    final overrides = settings.extensionOverrides;
    final prunedOverrides = {
      for (final entry in overrides.entries)
        if (knownKeys.contains(entry.key)) entry.key: entry.value,
    };
    if (prunedOverrides.length != overrides.length) await settings.setExtensionOverrides(prunedOverrides);
  }
}
