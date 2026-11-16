// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The clock DataFileManager's purge reads: since when each extension that
// owns downloaded data has been gone from the app. An installed extension
// keeps its data however long it stays switched off — the operator may turn
// it back on — so only one that is no longer here at all is ever stamped.
//
// Kept apart from ExtensionService because it is bookkeeping over prefs
// maps rather than anything the runtime does, and because the purge it feeds
// is destructive — a reader deciding whether a stamp is right should not have
// to find it inside four thousand lines of extension host.

import 'package:halo_core/halo_core.dart';

import 'extension_info.dart';
import 'preloaded_extensions.dart';
import '../settings_service.dart';

/// The stamp an uninstall leaves: the purge at the next launch takes the
/// extension's data at once, with no grace — the operator removed it.
const kGoneAtUninstall = 0;

/// How long an extension that went away WITHOUT an uninstall keeps its data:
/// a retired built-in once its catalog twin runs, a bundle a build stopped
/// carrying. Long enough for an update that brings it back.
const kGoneGrace = Duration(days: 7);

/// The extensions that are here, switched on or off: listed by the runtime,
/// or recorded as installed (one missing from the store is not one deleted).
/// Data owned by any of these is the operator's to keep. A pre-loaded bundle
/// or a retired built-in's twin the operator uninstalled is not here, though
/// its switch is kept ([pruneForgottenExtensionChoices]): its data goes.
Set<String> presentExtensionKeys({required SettingsService settings, required List<ExtensionInfo> available}) => {
  for (final info in available) info.key,
  ...settings.extensionsInstalled.keys,
};

/// Stamps each extension in [owners] (the extensions data files were
/// downloaded for) that is not present, keeping an earlier stamp; clears the
/// stamp of one that is present again; and drops stamps that name nothing
/// either way. Answers the stamps for the purge.
///
/// Answers nothing while [available] is still empty: before the extension
/// index first loads, an empty list means "not loaded yet", every owner would
/// read as gone, and a stamp an extension back in the app should have shed
/// would still be handed to the purge.
Future<Map<String, int>> updateExtensionGoneSince({
  required SettingsService settings,
  required List<ExtensionInfo> available,
  required Set<String> owners,
}) async {
  await settings.forgetLegacyExtensionStamps();
  if (available.isEmpty) return const {};
  final goneSince = {...settings.extensionGoneSince};
  final present = presentExtensionKeys(settings: settings, available: available);
  // REAL: this stamp persists, and the reader is a LATER LAUNCH's clock,
  // which is back on real time. Travelled, `DEVTT -30d` writes a stamp 30
  // days old, and the next boot purges inside the grace that exists so an
  // update bringing the extension back keeps everything.
  final now = realNowMillis();
  var changed = false;
  for (final key in owners) {
    if (!present.contains(key) && !goneSince.containsKey(key)) {
      goneSince[key] = now;
      changed = true;
    }
  }
  for (final key in goneSince.keys.toList()) {
    if (present.contains(key) || !owners.contains(key)) {
      goneSince.remove(key);
      changed = true;
    }
  }
  if (changed) await settings.setExtensionGoneSince(goneSince);
  return goneSince;
}

/// Prunes `extensionOverrides` of any key absent from [available] entirely,
/// and from what the operator installed — an extension deleted from the
/// build or uninstalled, not merely missing from the store, disabled, or
/// gated behind an experiment (which still keeps its entry there; see
/// `ExtensionService.isExtensionAvailable`). Without this, a key an install
/// migrated (like a former `hamdb: false` override) outlives the extension
/// it named forever: nothing else ever visits an unknown key to remove it.
///
/// Kept, besides what is present: the retired built-ins' choices, which a
/// twin inherits when it arrives — for one the app does not pre-load, that
/// is whenever the catalog is next reachable. And the switches of the bundles
/// the app has pre-loaded and of the built-ins' twins, which leave the store
/// switched off with their state kept: one pre-loaded comes back with an app
/// update carrying a newer copy unless its switch says off, and pruning the
/// switch says on.
///
/// Skipped while [available] is still empty — an empty list means "not
/// loaded yet", and pruning then would wipe out overrides set before boot
/// finishes (e.g. ONBOARD_AS picks written while the index is loading).
Future<void> pruneForgottenExtensionChoices({required SettingsService settings, required List<ExtensionInfo> available}) async {
  if (available.isEmpty) return;
  final known = {
    ...presentExtensionKeys(settings: settings, available: available),
    ...kRetiredBuiltIns.keys,
    for (final builtIn in kRetiredBuiltIns.keys) twinOf(builtIn),
    ...settings.extensionPreloaded.keys,
  };
  final overrides = settings.extensionOverrides;
  final pruned = {
    for (final entry in overrides.entries)
      if (known.contains(entry.key)) entry.key: entry.value,
  };
  if (pruned.length != overrides.length) await settings.setExtensionOverrides(pruned);
}
