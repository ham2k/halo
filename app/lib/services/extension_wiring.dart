// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the extension service reaches back through — the repositories, the
// radio, the spots, and the callbacks that need the whole services graph —
// handed over once that graph exists.

import 'dart:async';

import '../settings/cluster_settings_group.dart';
import '../settings/settings_command.dart';
import '../settings/spotting_settings_group.dart';
import '../views/dock_host.dart' show DockLayoutControl;
import '../views/settings/accounts_panel.dart';
import 'cat/equipment.dart';
import 'cluster/cluster_service.dart';
import 'cluster/cluster_settings.dart';
import 'extensions/extension_catalog_migration.dart';
import 'halo_services.dart';
import 'panel_equipment_service.dart';
import 'spots_for_extensions.dart';
import 'spotting_settings.dart';

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
  extensions.fyi = services.fyi;
  extensions.operations = services.operations;
  extensions.qsos = services.qsos;
  extensions.location = services.location;
  extensions.radioCalls.radio = services.panelRadio;
  extensions.radioCalls.equipment = PanelEquipmentService(services.cat);
  services.systemLists.equipment = (kind) {
    final category = switch (kind) {
      'radio' => kCategoryTransceiver,
      'rotator' => kCategoryRotator,
      _ => kCategoryAntennaSwitch,
    };
    return [
      for (final node in services.cat.nodes)
        if (services.cat.typeFor(node)?.category == category) {'label': services.cat.displayNameFor(node), 'value': node.uuid},
    ];
  };
  _wireOpStyle(services);
  _wireCluster(services);
  (services.settingsRegistry[SpottingSettings.group]! as SpottingSettingsGroup)
    ..destinations = extensions.getSpotDestinations
    ..destinationChanges = extensions.runtimeGeneration;
  extensions.spots = services.spots;
  extensions.catalog = services.catalog;
  extensions.onOpenAccount = (key, {subkey}) => unawaited(showAccountDialogByKey(services, key, subkey: subkey));
  extensions.onSearchSettings = (args, kind) => searchSettingsForCommand(services, args: args, kind: kind);
  extensions.appCalls
    ..settings = ((key, value, callerKey) => writeSettingForExtension(services, key: key, value: value, callerKey: callerKey))
    ..layouts = DockLayoutControl(services)
    ..statusBar = services.statusBar;
  extensions.onGetSpots = ExtensionSpotsReader(services).read;
  extensions.onSuggestQso = (qso, operationUuid) {
    final front = services.frontOperationContext;
    final suggest = front?.suggestSpot;
    // The operation the panel belongs to, or none: filling another one's
    // fields would put the station in a log the operator is not looking at.
    if (suggest == null || (operationUuid != null && front!.uuid != operationUuid)) return false;
    suggest(qso);
    return true;
  };
  extensions.onUpdateDraft = (patch, operationUuid, {required replace}) {
    final front = services.frontOperationContext;
    final update = front?.updateDraft;
    // The operation the extension was called about, or the one in front: a
    // draft in an operation the operator is not looking at is not changed.
    if (update == null || (operationUuid != null && front!.uuid != operationUuid)) return false;
    return update(patch, replace: replace);
  };
  // The boot starts the runtime before the services exist, so one quick to
  // come up has already run its catch-up — and stood it down, with no
  // settings to carry choices or record installs in. Without this that
  // session runs on the core extensions alone.
  if (extensions.ready && !extensions.firstCatchUpSettled) unawaited(catchUpOnCatalogExtensions(extensions));
}

/// `ctx.opStyle` moves with no setting saved — message 1, a QSY, a spot —
/// so a set's style changing drops the cached hook context.
void _wireOpStyle(HaLoServices services) {
  services.cat.styleChanges.addListener(services.extensions.invalidateHookContext);
}

/// The DX cluster connection extensions post spots through
/// (docs/design/cluster.md), and its section of Settings' Spotting category. Built on first use;
/// it connects only when an extension sends or subscribes.
void _wireCluster(HaLoServices services) {
  final extensions = services.extensions;
  final settings = services.settings;
  final passwords = ClusterPasswords();
  ClusterService? cluster;
  ClusterService clusterService() => cluster ??= services.closedOnExit<ClusterService>(
    'cluster',
    ClusterService(
      settings: settings,
      // The operator of the operation in front, or the profile's with none open.
      loginCall: () {
        final operatorCall = services.frontOperationContext?.operatorCall ?? '';
        return operatorCall.isNotEmpty ? operatorCall : settings.activeProfile.operatorCall;
      },
      password: passwords.read,
    )..deliver = (subscriber, lines) => extensions.deliverClusterLines(subscriber, [for (final line in lines) line.toJson()]),
    (cluster) => cluster.closeForExit(),
  );
  extensions.clusterCalls.cluster = clusterService;
  (services.settingsRegistry[SpottingSettings.group]! as SpottingSettingsGroup).cluster = ClusterSettingsGroup(
    settings,
    passwords: passwords,
    cluster: clusterService,
    offered: () => extensions.clusterCalls.offered,
    changes: () => extensions.runtimeGeneration,
  );
}
