// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the extension service reaches back through — the repositories, the
// radio, the spots, and the callbacks that need the whole services graph —
// handed over once that graph exists.

import 'dart:async';

import '../settings/settings_command.dart';
import '../views/settings/accounts_panel.dart';
import 'extensions/extension_catalog_migration.dart';
import 'halo_services.dart';
import 'spots_for_extensions.dart';

/// Hands [services]' extension service everything it reaches back through.
///
/// Reads every collaborator off the built [services], never from inside
/// HaLoServices' constructor body: several of them have a same-named
/// constructor parameter holding the test override, which is null in every
/// production build and shadows the field there. Wiring one of those up from
/// the constructor silently hands over the null — nothing reaches the
/// service, and the feature behind it simply never happens.
void wireExtensions(HaLoServices services) {
  final extensions = services.extensions;
  extensions.settings = services.settings;
  extensions.lookups = services.lookups;
  extensions.statusBar = services.statusBar;
  extensions.operations = services.operations;
  extensions.qsos = services.qsos;
  extensions.location = services.location;
  extensions.radioCalls.radio = services.panelRadio;
  extensions.spots = services.spots;
  extensions.catalog = services.catalog;
  extensions.onOpenAccount = (key, {subkey}) => unawaited(showAccountDialogByKey(services, key, subkey: subkey));
  extensions.onSearchSettings = (args, kind) => searchSettingsForCommand(services, args: args, kind: kind);
  extensions.onGetSpots = ExtensionSpotsReader(services).read;
  // The boot starts the runtime before the services exist, so one quick to
  // come up has already run its catch-up — and stood it down, with no
  // settings to carry choices or record installs in. Without this that
  // session runs on the core extensions alone.
  if (extensions.ready && !extensions.firstCatchUpSettled) unawaited(catchUpOnCatalogExtensions(extensions));
}
