// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Extension integrations (docs/extensions/integrations.md): hooks that carry
// an operation's log to and from somewhere else — an online log, a
// scoreboard, another program on the network — with nothing on screen of
// their own. The operator switches each on per operation, on this device, in
// the operation's Integrations dialog; what it is called with is the
// contacts that changed since its previous call. When it is called is
// [WatcherService]'s.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

import '../views/operation/panel_scene/cat_spectrum_source.dart';
import 'cat/cat_service.dart';
import 'panel_service.dart';
import 'settings_service.dart';
import 'watcher_service.dart';

/// The slice of [ExtensionService] the integrations use, named so their rules
/// can be tested without a JS runtime.
abstract interface class IntegrationExtensionSource {
  /// Ticks after every runtime (re)start: the integrations a runtime offers
  /// are only knowable by asking it.
  Listenable get runtimeGeneration;

  /// Null when the runtime could not be asked.
  Future<List<Map<String, dynamic>>?> getExtensionIntegrations();

  /// Throws when the hook does; false when there was no runtime to call.
  Future<bool> observeIntegration({required String hookKey, required String integrationKey, required Map<String, dynamic> args});

  Future<Map<String, dynamic>> readPanelConfig({required String panelKey, required List<Map<String, dynamic>> fields});

  /// Whether [hookKey]'s extension may read the radio (`requiresRadioRead`).
  bool canReadRadio(String? hookKey);
}

/// Writes an operation's device-local state from what it holds at the
/// moment of writing — `OperationsRepository.updateLocalDataWith`.
typedef IntegrationSwitchWriter = Future<void> Function(String operationUuid, Map<String, dynamic>? Function(Map<String, dynamic> localData) patchFor);

class IntegrationService extends WatcherService {
  final IntegrationExtensionSource extensions;
  final IntegrationSwitchWriter writeLocalData;

  /// The operation's `localData` key holding the ids of the integrations on
  /// for it. Device-local by where it lives: a contact synced from another
  /// device joins this log like any other, so an operation logged on several
  /// devices needs an integration on in only one of them, and a port another
  /// program reaches is this machine's.
  static const localDataKey = 'integrations';

  /// The app's: switches in the operation's local data, the radio's dial from
  /// its CAT connections. Asks the extensions at once.
  factory IntegrationService.forApp(
    IntegrationExtensionSource extensions, {
    required OperationsRepository operations,
    required SettingsService settings,
    required CatService cat,
  }) {
    final dial = CatSpectrumSource(cat, settings: settings);
    final service = IntegrationService(
      extensions,
      writeLocalData: operations.updateLocalDataWith,
      radio: (changes: dial.readingChanges, state: dial.dialState),
    );
    unawaited(service.refresh());
    return service;
  }

  IntegrationService(this.extensions, {required this.writeLocalData, super.radio}) : super(runtimeGeneration: extensions.runtimeGeneration);

  @override
  String get kind => 'integration';

  /// The draft is the operator's keystrokes: nothing an integration carries
  /// anywhere.
  @override
  Set<String> get refusedTriggers => const {'qso', 'lookup'};

  static List<String> _idsIn(Map<String, dynamic>? localData) => [...?(localData?[localDataKey] as List?)?.whereType<String>()];

  static List<String> _onIn(Operation? operation) => _idsIn(operation?.localData);

  /// Whether [integration] is on for [operation].
  static bool isOnIn(WatcherDefinition integration, Operation? operation) => _onIn(operation).contains(integration.id);

  @override
  bool isOnFor(WatcherDefinition watcher, WatcherFeed feed) => isOnIn(watcher, feed.context.operation);

  @override
  bool switchesMoved(PanelRenderContext previous, PanelRenderContext next) =>
      !const ListEquality<String>().equals(_onIn(previous.operation), _onIn(next.operation));

  /// Switches [integration] on or off for the operation [operationUuid]. Its
  /// view hears of the write as any other change to the operation, which is
  /// what calls it.
  Future<void> setOn(WatcherDefinition integration, String operationUuid, bool on) => writeLocalData(operationUuid, (localData) {
    final ids = _idsIn(localData);
    if (ids.contains(integration.id) == on) return null;
    on ? ids.add(integration.id) : ids.remove(integration.id);
    return {localDataKey: ids};
  });

  @override
  Future<List<Map<String, dynamic>>?> fetchCatalog() => extensions.getExtensionIntegrations();

  @override
  bool canReadRadio(String hookKey) => extensions.canReadRadio(hookKey);

  @override
  Future<Map<String, dynamic>> readConfig(WatcherDefinition watcher) => extensions.readPanelConfig(panelKey: watcher.id, fields: watcher.formFields);

  /// Per integration and feed, the contacts its previous call saw, by uuid,
  /// with their stamps: what the next call's `changes` are told against.
  final Map<(String, WatcherFeed), Map<String, int?>> _seen = {};

  @override
  Future<bool> observe(WatcherDefinition watcher, WatcherFeed feed, Map<String, dynamic> args) {
    final key = (watcher.id, feed);
    // Nothing from before it was on, or before the operation opened, is
    // replayed: `open` starts from the log as it stands.
    if ((args['reasons'] as List).contains('open')) _seen.remove(key);
    return extensions.observeIntegration(hookKey: watcher.hookKey, integrationKey: watcher.key, args: {...args, 'changes': _changes(key, feed.context.log)});
  }

  /// What moved in [log] since [key]'s previous call, as the hook is handed
  /// it. Best effort, by stamp: an edit that leaves `updatedAtMillis` alone
  /// goes unseen, and a contact edited and edited back between two calls
  /// reads as edited once. Event markers are no contact, and a deleted row
  /// the view shows is one that left the log.
  ///
  /// A log the view has not read yet sets nothing: the first one it does is
  /// where this starts, rather than every contact in it reading as new.
  Map<String, dynamic> _changes((String, WatcherFeed) key, List<Qso>? log) {
    final logged = <Map<String, dynamic>>[], updated = <Map<String, dynamic>>[], deleted = <String>[];
    final changes = {'logged': logged, 'updated': updated, 'deleted': deleted};
    if (log == null) return changes;
    final seen = _seen[key];
    final now = <String, int?>{};
    for (final qso in log) {
      if (qso.deleted || qso.isEvent) continue;
      now[qso.uuid] = qso.updatedAtMillis;
      if (seen == null) continue;
      if (!seen.containsKey(qso.uuid)) {
        logged.add({...qso.data, 'uuid': qso.uuid});
      } else if (seen[qso.uuid] != qso.updatedAtMillis) {
        updated.add({...qso.data, 'uuid': qso.uuid});
      }
    }
    _seen[key] = now;
    if (seen != null) deleted.addAll(seen.keys.where((uuid) => !now.containsKey(uuid)));
    return changes;
  }

  @override
  void feedClosed(WatcherFeed feed) => _seen.removeWhere((key, _) => key.$2 == feed);
}
