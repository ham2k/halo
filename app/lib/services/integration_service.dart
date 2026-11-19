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

  /// Anything but a list reads as none on, as a descriptor's mistyped field
  /// does: the switches are read from build and from timers.
  static List<String> _idsIn(Map<String, dynamic>? localData) => switch (localData?[localDataKey]) {
    final List<dynamic> ids => [...ids.whereType<String>()],
    _ => [],
  };

  static List<String> _onIn(Operation? operation) => _idsIn(operation?.localData);

  /// Whether [integration] is on for [operation].
  static bool isOnIn(WatcherDefinition integration, Operation? operation) => _onIn(operation).contains(integration.id);

  /// On for [feed] only when it is the oldest view open on its operation: a
  /// second view of the same operation (the command bar's, or the Logs
  /// edit panel's, pushed over the first) would otherwise hand every
  /// contact to the integration twice. Closing the first hands the
  /// operation to the next, which hears `open` ([feedClosed]).
  @override
  bool isOnFor(WatcherDefinition watcher, WatcherFeed feed) => isOnIn(watcher, feed.context.operation) && _leads(feed);

  bool _leads(WatcherFeed feed) {
    final uuid = feed.context.operation?.uuid;
    return identical(openedFeeds.firstWhereOrNull((open) => open.context.operation?.uuid == uuid), feed);
  }

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

  /// The integrations whose `open` fired before their feed's log was read:
  /// the first log the view reads is where their `changes` start.
  final Set<(String, WatcherFeed)> _awaitingLog = {};

  /// `open` starts from the log as it stands when it fires, not when its
  /// call runs: a contact logged in the pacing gap between the two is a
  /// change, not part of what was there.
  @override
  void fired(WatcherDefinition watcher, WatcherFeed feed, String reason) {
    if (reason != 'open') return;
    final key = (watcher.id, feed);
    final log = feed.context.log;
    if (log == null) {
      _seen.remove(key);
      _awaitingLog.add(key);
    } else {
      _awaitingLog.remove(key);
      _seen[key] = _stampsOf(log);
    }
  }

  @override
  void contextMoved(WatcherFeed feed, PanelRenderContext previous) {
    final log = feed.context.log;
    if (log == null || _awaitingLog.isEmpty) return;
    _awaitingLog.removeWhere((key) {
      if (key.$2 != feed) return false;
      _seen[key] = _stampsOf(log);
      return true;
    });
  }

  @override
  Future<bool> observe(WatcherDefinition watcher, WatcherFeed feed, Map<String, dynamic> args) async {
    final key = (watcher.id, feed);
    final seen = _seen[key];
    final (changes, now) = _changes(key, feed.context.log);
    // Used up by a call the extension was handed, even one that threw or
    // ran out of time, as the docs promise; not by one that never went out
    // for want of a runtime. Nor over an `open` that fired meanwhile, which
    // set a newer start.
    void commit() {
      if (now != null && identical(_seen[key], seen)) _seen[key] = now;
    }

    try {
      final called = await extensions.observeIntegration(hookKey: watcher.hookKey, integrationKey: watcher.key, args: {...args, 'changes': changes});
      if (called) commit();
      return called;
    } catch (_) {
      commit();
      rethrow;
    }
  }

  static Map<String, int?> _stampsOf(List<Qso> log) => {
    for (final qso in log)
      if (!qso.deleted && !qso.isEvent) qso.uuid: qso.updatedAtMillis,
  };

  /// What moved in [log] since [key]'s previous call, as the hook is handed
  /// it, and the stamps a call that goes out leaves for the next. Best
  /// effort, by stamp: an edit that leaves `updatedAtMillis` alone goes
  /// unseen, and a contact edited and edited back between two calls reads
  /// as edited once. Event markers are no contact, and a deleted row the
  /// view shows is one that left the log.
  ///
  /// A log the view has not read yet moves nothing. With no start yet — no
  /// `open` seen — this log is where it starts, rather than every contact in
  /// it reading as new.
  (Map<String, dynamic>, Map<String, int?>?) _changes((String, WatcherFeed) key, List<Qso>? log) {
    final logged = <Map<String, dynamic>>[], updated = <Map<String, dynamic>>[], deleted = <String>[];
    final changes = {'logged': logged, 'updated': updated, 'deleted': deleted};
    if (log == null) return (changes, null);
    final seen = _seen[key];
    final now = _stampsOf(log);
    if (seen == null) {
      _seen[key] = now;
      return (changes, null);
    }
    for (final qso in log) {
      if (!now.containsKey(qso.uuid)) continue;
      if (!seen.containsKey(qso.uuid)) {
        logged.add({...qso.data, 'uuid': qso.uuid});
      } else if (seen[qso.uuid] != qso.updatedAtMillis) {
        updated.add({...qso.data, 'uuid': qso.uuid});
      }
    }
    deleted.addAll(seen.keys.where((uuid) => !now.containsKey(uuid)));
    return (changes, now);
  }

  @override
  void feedClosed(WatcherFeed feed) {
    _seen.removeWhere((key, _) => key.$2 == feed);
    _awaitingLog.removeWhere((key) => key.$2 == feed);
    // A view still open on the same operation takes it over, and hears `open`.
    reconcile();
  }
}
