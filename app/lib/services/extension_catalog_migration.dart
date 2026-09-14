// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Moving an install from the app's own extensions to the catalog's
// (docs/extensions/distribution.md).
//
// One operation, offered once and deferrable: the operator is asked at start
// and may say later, so nothing is withdrawn until the replacements are in
// hand. `SettingsService.extensionsMigrated` is the switch, and it is written
// LAST — until then the built-ins run exactly as they always did, which is
// what makes "later" cost nothing and an offline launch harmless.

import 'dart:async';

import 'error_reporting_service.dart';
import 'extension_service.dart';
import 'settings_service.dart';

/// True while a migration or catch-up is in flight.
///
/// Both entry points run off a runtime start, and a start happens again on
/// every restart — an extension toggled in the panel, a runtime that died.
/// Without this a restart during the ~30 downloads begins a second pass over
/// the same `extensionAdopted` snapshot: the same keys fetched and installed
/// twice, and whichever pass writes its records last discards the other's.
bool _inFlight = false;

/// Whether the catalog can be reached right now.
///
/// Asked before the upgrade is offered, so nobody is shown a dialog whose
/// button cannot work. Forced past the listing cache: a five-minute-old yes is
/// not evidence about the connection this launch has.
Future<bool> canReachCatalog(ExtensionService service) async =>
    await service.catalog?.fetchCatalog(force: true) != null;

/// Moves this install's extensions to the catalog, and answers whether it
/// finished.
///
/// The downloads happen while the built-ins are still working, and the flag
/// that withdraws them is reverted if anything did not arrive. An upgrade that
/// fails half way leaves the operator exactly where they were, which is what
/// lets it be offered again next launch.
Future<bool> migrateToCatalogExtensions(ExtensionService service) async {
  final settings = service.settings;
  if (settings == null || _inFlight) return false;
  _inFlight = true;
  try {
    return await _migrate(service, settings);
  } catch (e, stack) {
    // The flag is written FIRST, so a throw anywhere after it leaves the one
    // state this must never end in: migrated, with nothing adopted — every
    // non-core built-in withdrawn and no replacement on disk. Reverting here
    // puts the operator back where they were and lets the offer return next
    // launch, which is what the whole shape of this is for.
    ErrorReportingService.report(e, stack, context: 'extensions:migrate');
    await settings.setExtensionsMigrated(false);
    return false;
  } finally {
    _inFlight = false;
  }
}

Future<bool> _migrate(ExtensionService service, SettingsService settings) async {
  await settings.setExtensionsMigrated(true);
  await service.preloadShippedExtensions();
  // BEFORE the adoption looks: it decides what to fetch from the installed
  // list, and the seven the pre-load just installed are not in a memoized one.
  // They would be downloaded again from the catalog over bytes already on
  // disk — and one of those downloads failing would roll the whole upgrade
  // back over bundles that had shipped inside the app.
  await service.reloadAvailableExtensions();
  if (!(await service.adoptTwins()).complete) {
    await settings.setExtensionsMigrated(false);
    return false;
  }
  await service.reloadAvailableExtensions();
  await service.restartRuntime();
  return true;
}

/// The boot-time half: whatever is still owed from an upgrade already taken.
///
/// A pre-load the app update brought, and any twin a previous launch could not
/// download. Never throws into the caller — this is fire-and-forget off the
/// end of a boot, and an exception escaping here has no one left to catch it.
Future<void> catchUpOnCatalogExtensions(ExtensionService service) async {
  if (_inFlight) return;
  _inFlight = true;
  try {
    var landed = await service.preloadShippedExtensions();
    // Re-read before the adoption looks, or "after the pre-load" is not true
    // of the list it reads: what the pre-load just installed would be fetched
    // from the catalog as well.
    if (landed) await service.reloadAvailableExtensions();
    landed = (await service.adoptTwins()).landed || landed;
    if (landed) {
      await service.reloadAvailableExtensions();
      await service.restartRuntime();
    }
  } catch (e, stack) {
    ErrorReportingService.report(e, stack, context: 'extensions:preload');
  } finally {
    _inFlight = false;
  }
}
