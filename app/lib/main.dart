// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// App shell for phase 2 (core logging loop). Deliberately thin: opens the
// database, builds the repositories, and hands them to the screens. State
// management stays at "constructor injection + streams" until it earns more
// machinery — the database is the source of truth (DESIGN.md §6).

import 'dart:async';
import 'dart:io' show Platform;

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'views/operation_view.dart';
import 'views/home_view.dart';
import 'services/export_service.dart';
import 'services/extension_service.dart';
import 'services/metrics_service.dart';
import 'services/purchase_service.dart';
import 'services/settings_service.dart';
import 'services/update_service.dart';
import 'services/data_file_manager.dart';
import 'i18n/strings.g.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  final services = await bootstrap();
  runApp(TranslationProvider(child: HaLoApp(services: services)));

  // Dev nicety: launch with POLO_OPEN_FIRST_OP=1 in the environment (e.g.
  // SIMCTL_CHILD_POLO_OPEN_FIRST_OP=1 simctl launch ...) to jump straight
  // into the most recent operation.
  const openFirstOpDefine = bool.fromEnvironment('POLO_OPEN_FIRST_OP');
  final openFirstOp = openFirstOpDefine || Platform.environment['POLO_OPEN_FIRST_OP'] == '1';
  debugPrint('[boot] openFirstOp=$openFirstOp (define=$openFirstOpDefine)');
  if (openFirstOp) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final operations = await services.operations.watchAll().first;
      if (operations.isNotEmpty) {
        navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => OperationView(services: services, operationUuid: operations.first.uuid),
        ));
      }
    });
  }
}

/// Runs the shared boot sequence (database, extensions, settings, sync) and
/// returns the assembled services bundle. Distribution-specific entrypoints
/// (e.g. a private `main_dist.dart`) call this with real implementations of
/// the distribution-only services instead of the OSS no-op defaults.
Future<HaLoServices> bootstrap({
  MetricsService? metrics,
  PurchaseService? purchases,
  UpdateService? updates,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = HaLoDatabase(driftDatabase(name: 'halo_next'));
  final extensions = ExtensionService();
  // Fire-and-forget, and kicked off before awaiting settings below so these
  // two independent boot steps run concurrently instead of serialized; the
  // core logging loop never waits on the extension runtime either way.
  extensions.start();
  final settings = await SettingsService.load();
  LocaleSettings.setLocaleRaw(settings.locale);
  final services = HaLoServices(
    db,
    settings,
    extensions: extensions,
    metrics: metrics,
    purchases: purchases,
    updates: updates,
  );
  if (settings.hasQrzCredentials) {
    await services.extensions.setAccountCredentials('qrz', {
      'username': settings.qrzUsername,
      'password': settings.qrzPassword,
    });
    await settings.setQrzCredentials(username: '', password: '');
  }
  services.extensions.setSyncCredentials(deviceKey: settings.syncDeviceKey, operatorCall: settings.operatorCall);
  services.syncEngine.start();

  // Await the extension system being fully booted, then initialize and sync data files
  unawaited(extensions.start().then((_) async {
    await services.dataFiles.loadRawDataFiles();
    await services.dataFiles.syncAllDataFiles();
  }).catchError((e) {
    debugPrint('[boot] failed to initialize data files: $e');
  }));

  return services;
}

/// The core services bundle passed down to screens.
class HaLoServices {
  final HaLoDatabase db;
  final SettingsService settings;
  final ExtensionService extensions;
  final MetricsService metrics;
  final PurchaseService purchases;
  final UpdateService updates;

  late final OperationsRepository operations = OperationsRepository(db, onChange: () => syncEngine.notifyChanged());
  late final QsosRepository qsos = QsosRepository(db, onChange: () => syncEngine.notifyChanged());
  late final LookupRepository lookups = LookupRepository(db);
  late final ExportService exports = ExportService(extensions: extensions, qsos: qsos);
  late final DataFileManager dataFiles = DataFileManager(
    lookups: lookups,
    extensions: extensions,
    prefs: settings.prefs,
  );

  /// The dirty-flag sync loop (DESIGN.md §4) — batching and bookkeeping stay
  /// here in Dart; only the network call crosses into the `ham2k-lofi`
  /// extension via `_syncTransportCall`.
  late final SyncEngine syncEngine = SyncEngine(
    operations: operations,
    qsos: qsos,
    transport: _syncTransportCall,
    settings: settings,
  );

  HaLoServices(
    this.db,
    this.settings, {
    ExtensionService? extensions,
    MetricsService? metrics,
    PurchaseService? purchases,
    UpdateService? updates,
  })  : extensions = extensions ?? ExtensionService(),
        metrics = metrics ?? const NoopMetricsService(),
        purchases = purchases ?? const NoopPurchaseService(),
        updates = updates ?? const NoopUpdateService() {
    this.extensions.settings = settings;
    this.extensions.lookups = lookups;
  }



  /// Same one-call pattern as `setQrzCredentials`, for the sync device
  /// identity + operator callsign.
  Future<void> setOperatorCall(String call) async {
    await settings.setOperatorCall(call);
    await extensions.setSyncCredentials(deviceKey: settings.syncDeviceKey, operatorCall: settings.operatorCall);
  }

  Future<void> setSyncEnabled(bool enabled) async {
    await settings.setSyncEnabled(enabled);
    if (enabled) syncEngine.start();
  }

  /// Handles a command action from the call field (currently just
  /// `SYNCALL` — see `extensions/sync/ham2k-lofi`'s command hook). Returns
  /// a message for the caller to show in a SnackBar, or null for nothing.
  Future<String?> handleCommandAction(String action) async {
    switch (action) {
      case 'syncAll':
        if (!settings.syncEnabled) return 'Enable sync in Settings first.';
        await syncEngine.forceFullResync();
        return 'Full resync started — local data was backed up first.';
      default:
        return null;
    }
  }

  Future<Map<String, dynamic>> _syncTransportCall(String method, Map<String, dynamic> args) async {
    final host = extensions.host;
    if (host == null) throw StateError('extension runtime is not ready yet');
    final result =
        await host.invokeHook('syncTransport', method: method, args: args, timeout: const Duration(seconds: 30));
    return (result as Map).cast<String, dynamic>();
  }
}



class HaLoApp extends StatelessWidget {
  final HaLoServices services;

  const HaLoApp({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    // Rebuilds when Settings changes themeMode, so toggling it in the
    // Settings screen takes effect immediately rather than needing a restart.
    return AnimatedBuilder(
      animation: services.settings,
      builder: (context, _) => MaterialApp(
        // Android task-switcher card title / web tab title — matches each
        // platform's own OS-level app name (see isWindowedPlatform's other
        // uses: macos/Runner/Configs/AppInfo.xcconfig "Ham2K Logger",
        // android's AndroidManifest.xml label "HaLo").
        title: isWindowedPlatform ? 'Ham2K Logger' : 'HaLo',
        navigatorKey: navigatorKey,
        locale: TranslationProvider.of(context).locale.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildHaLoTheme(Brightness.light),
        darkTheme: buildHaLoTheme(Brightness.dark),
        themeMode: services.settings.themeMode,
        debugShowCheckedModeBanner: false,
        home: HomeView(services: services),
      ),
    );
  }
}
