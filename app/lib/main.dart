// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// App shell for phase 2 (core logging loop). Deliberately thin: opens the
// database, builds the repositories, and hands them to the screens. State
// management stays at "constructor injection + streams" until it earns more
// machinery — the database is the source of truth (DESIGN.md §6).

import 'dart:io' show Platform;

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:polo_core/polo_core.dart';
import 'package:polo_widgets/polo_widgets.dart';

import 'screens/operation_screen.dart';
import 'screens/operations_screen.dart';
import 'services/export_service.dart';
import 'services/extension_service.dart';
import 'services/settings_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = PoloDatabase(driftDatabase(name: 'polo_next'));
  final extensions = ExtensionService();
  // Fire-and-forget, and kicked off before awaiting settings below so these
  // two independent boot steps run concurrently instead of serialized; the
  // core logging loop never waits on the extension runtime either way.
  extensions.start();
  final settings = await SettingsService.load();
  final services = PoloServices(db, settings, extensions: extensions);
  if (settings.hasQrzCredentials) {
    services.extensions.setQrzCredentials(username: settings.qrzUsername, password: settings.qrzPassword);
  }
  runApp(PoloNextApp(services: services));

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
          builder: (_) => OperationScreen(services: services, operationUuid: operations.first.uuid),
        ));
      }
    });
  }
}

/// The core services bundle passed down to screens.
class PoloServices {
  final PoloDatabase db;
  final SettingsService settings;
  late final OperationsRepository operations = OperationsRepository(db);
  late final QsosRepository qsos = QsosRepository(db);
  final ExtensionService extensions;
  late final ExportService exports = ExportService(extensions: extensions, qsos: qsos);

  PoloServices(this.db, this.settings, {ExtensionService? extensions}) : extensions = extensions ?? ExtensionService();

  /// Persists QRZ credentials and seeds them into the extension host in one
  /// call, so a future call site can't update one store and forget the
  /// other the way main.dart's boot path and SettingsScreen's save handler
  /// used to have to coordinate by hand.
  Future<void> setQrzCredentials({required String username, required String password}) async {
    await settings.setQrzCredentials(username: username, password: password);
    await extensions.setQrzCredentials(username: username, password: password);
  }
}

class PoloNextApp extends StatelessWidget {
  final PoloServices services;

  const PoloNextApp({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    // Rebuilds when Settings changes themeMode, so toggling it in the
    // Settings screen takes effect immediately rather than needing a restart.
    return AnimatedBuilder(
      animation: services.settings,
      builder: (context, _) => MaterialApp(
        title: 'PoLo Next',
        navigatorKey: navigatorKey,
        theme: buildPoloTheme(Brightness.light),
        darkTheme: buildPoloTheme(Brightness.dark),
        themeMode: services.settings.themeMode,
        // No debug-mode ribbon — the OperationsScreen's logo is tinted red
        // in debug builds instead (see operations_screen.dart), a signal
        // that doesn't cover any content or collide with window chrome.
        debugShowCheckedModeBanner: false,
        home: OperationsScreen(services: services),
      ),
    );
  }
}
