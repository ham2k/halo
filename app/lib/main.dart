// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// App shell for phase 2 (core logging loop). Deliberately thin: opens the
// database, builds the repositories, and hands them to the screens. State
// management stays at "constructor injection + streams" until it earns more
// machinery — the database is the source of truth (DESIGN.md §6).

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:polo_core/polo_core.dart';

import 'screens/operations_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final db = PoloDatabase(driftDatabase(name: 'polo_next'));
  runApp(PoloNextApp(services: PoloServices(db)));
}

/// The core services bundle passed down to screens.
class PoloServices {
  final PoloDatabase db;
  late final OperationsRepository operations = OperationsRepository(db);
  late final QsosRepository qsos = QsosRepository(db);

  PoloServices(this.db);
}

class PoloNextApp extends StatelessWidget {
  final PoloServices services;

  const PoloNextApp({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PoLo Next',
      theme: ThemeData(colorSchemeSeed: const Color(0xFFD32F2F), useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: const Color(0xFFD32F2F), brightness: Brightness.dark, useMaterial3: true),
      home: OperationsScreen(services: services),
    );
  }
}
