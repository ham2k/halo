// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Settings reloads its extension panels on every runtime generation, and an
// extension update brings several in a row. Each load decides the "settings
// are unavailable" notice from the runtime it saw, so a load that decides
// from an outdated runtime tells the operator something no longer true.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/views/settings_view.dart';

import '../support/halo_test_support.dart';

const _unavailable = 'settings_extensions_unavailable';

/// One settings panel with one common field, whose catalog answer a test can
/// hold back and release later.
class _SettingsHost extends FakeExtensionHost {
  String title;
  final String panelKey;
  final held = <Completer<List<Map<String, dynamic>>>>[];
  bool holding = false;

  _SettingsHost(this.title, {this.panelKey = 'ext', String fieldLabel = 'Example field'})
    : super({
        'settingsPanel:$panelKey:getDefinition': {
          'elements': [
            {'type': 'field', 'fieldType': 'text', 'key': 'example', 'label': fieldLabel, 'value': '', 'common': true},
          ],
        },
      });

  List<Map<String, dynamic>> get _panels => [
    {
      'key': panelKey,
      'ok': true,
      'value': {'panelKey': panelKey, 'hookKey': panelKey, 'extensionKey': panelKey, 'title': title, 'kind': 'dynamic', 'order': 50},
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> invokeHookAll(
    String category, {
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
    bool partialOnTimeout = false,
  }) {
    if (category != 'settingsPanel' || method != 'getPanels') return Future.value(const []);
    if (!holding) return Future.value(_panels);
    final answer = Completer<List<Map<String, dynamic>>>();
    held.add(answer);
    return answer.future;
  }
}

/// A runtime that is either up (a host) or down (none), as `ready` reads it.
class _SwappableExtensions extends ExtensionService {
  ExtensionHost? current;

  _SwappableExtensions(this.current);

  @override
  ExtensionHost? get host => current;

  @override
  bool get ready => current != null;

  /// The app's own, so each panel keeps the sidebar entry it asks for — an
  /// installed one would need its manifest to declare it (settings_placement.dart).
  @override
  List<ExtensionInfo> get availableExtensions => [
    for (final key in const ['ext', 'old', 'new', 'first', 'second']) ExtensionInfo(key: key, file: '$key.js', core: true, name: key),
  ];

  @override
  Future<void> start() async {}
}

Finder _sidebarEntry(String title) => find.widgetWithText(ListTile, title).hitTestable();

void main() {
  testWidgets('the unavailable notice goes away once a later generation loads', (tester) async {
    // Left up, it keeps telling the operator the runtime is broken for the
    // rest of the session, long after an update has brought it back.
    final extensions = _SwappableExtensions(null);
    final harness = await pumpHaLo(
      tester,
      (services) => SettingsView(services: services),
      extensions: extensions,
      size: const Size(1000, 4000),
    );
    await tester.pumpAndSettle();
    expect(harness.services.statusBar.activeNotices.where((notice) => notice.key == _unavailable), hasLength(1));

    extensions.current = _SettingsHost('Recovered Extension');
    extensions.runtimeGeneration.value++;
    await tester.pumpAndSettle();

    expect(harness.services.statusBar.activeNotices.where((notice) => notice.key == _unavailable), isEmpty);
    expect(_sidebarEntry('Recovered Extension'), findsOneWidget);
  });

  testWidgets('a load that finishes after a newer one does not replace its panels', (tester) async {
    // A late activation bumps the generation on the SAME host: the load it
    // triggers sees the whole hook set, while the one before it saw part of
    // it — and can still be waiting on its answer.
    final host = _SettingsHost('Partial Extension');
    final extensions = _SwappableExtensions(host);
    await pumpHaLo(
      tester,
      (services) => SettingsView(services: services),
      extensions: extensions,
      size: const Size(1000, 4000),
    );
    await tester.pumpAndSettle();

    host.holding = true;
    extensions.runtimeGeneration.value++;
    await tester.pump();
    expect(host.held, hasLength(2), reason: 'the sidebar and Application Preferences each load');

    host
      ..holding = false
      ..title = 'Whole Extension';
    extensions.runtimeGeneration.value++;
    await tester.pumpAndSettle();
    expect(_sidebarEntry('Whole Extension'), findsOneWidget);

    host.title = 'Partial Extension';
    for (final answer in host.held) {
      answer.complete(host._panels);
    }
    await tester.pumpAndSettle();

    expect(_sidebarEntry('Whole Extension'), findsOneWidget);
    expect(find.text('Partial Extension'), findsNothing, reason: 'neither the sidebar nor Application Preferences takes the older answer');
  });

  testWidgets('Application Preferences shows the new panel when another takes the old one\'s place', (tester) async {
    // A panel fetches its definition once, for the descriptor it was built
    // with. Left in the slot of the panel before it, it goes on showing the
    // departed extension's fields under the new one's heading.
    final extensions = _SwappableExtensions(_SettingsHost('Old Extension', panelKey: 'old', fieldLabel: 'Old field'));
    await pumpHaLo(
      tester,
      (services) => SettingsView(services: services),
      extensions: extensions,
      size: const Size(1000, 4000),
    );
    await tester.pumpAndSettle();
    expect(find.text('Old field').hitTestable(), findsOneWidget);

    extensions.current = _SettingsHost('New Extension', panelKey: 'new', fieldLabel: 'New field');
    extensions.runtimeGeneration.value++;
    await tester.pumpAndSettle();

    expect(find.text('New field').hitTestable(), findsOneWidget);
    expect(find.text('Old field'), findsNothing);
  });

  testWidgets('choosing another extension in the sidebar shows that extension\'s fields', (tester) async {
    // Every extension's page is built in the same place in the pane, and a
    // panel fetches its definition once, for the descriptor it was built with.
    Map<String, dynamic> panel(String key, String title) => {
      'key': key,
      'ok': true,
      'value': {'panelKey': key, 'hookKey': key, 'extensionKey': key, 'title': title, 'kind': 'dynamic', 'order': 50},
    };
    Map<String, dynamic> definition(String label) => {
      'elements': [
        {'type': 'field', 'fieldType': 'text', 'key': 'example', 'label': label, 'value': ''},
      ],
    };
    final extensions = _SwappableExtensions(
      FakeExtensionHost({
        'settingsPanel:*:getPanels': [panel('first', 'First Extension'), panel('second', 'Second Extension')],
        'settingsPanel:first:getDefinition': definition('First field'),
        'settingsPanel:second:getDefinition': definition('Second field'),
      }),
    );
    await pumpHaLo(
      tester,
      (services) => SettingsView(services: services),
      extensions: extensions,
      size: const Size(1000, 4000),
    );
    await tester.pumpAndSettle();

    await tester.tap(_sidebarEntry('First Extension'));
    await tester.pumpAndSettle();
    expect(find.text('First field').hitTestable(), findsOneWidget);

    await tester.tap(_sidebarEntry('Second Extension'));
    await tester.pumpAndSettle();
    expect(find.text('Second field').hitTestable(), findsOneWidget);
    expect(find.text('First field'), findsNothing);
  });

  testWidgets('a superseded load that settles on a failed runtime still raises the notice', (tester) async {
    // A failed boot bumps no generation, so no newer load follows it: the one
    // already waiting when the runtime went down is the only one that sees it.
    final host = _SettingsHost('Some Extension');
    final extensions = _SwappableExtensions(host);
    final harness = await pumpHaLo(
      tester,
      (services) => SettingsView(services: services),
      extensions: extensions,
      size: const Size(1000, 4000),
    );
    await tester.pumpAndSettle();

    host.holding = true;
    extensions.runtimeGeneration.value++;
    await tester.pump();
    host.holding = false;
    extensions.runtimeGeneration.value++;
    await tester.pumpAndSettle();
    expect(harness.services.statusBar.activeNotices.where((notice) => notice.key == _unavailable), isEmpty);

    extensions.current = null;
    for (final answer in host.held) {
      answer.complete(const []);
    }
    await tester.pumpAndSettle();

    expect(harness.services.statusBar.activeNotices.where((notice) => notice.key == _unavailable), hasLength(1));
  });
}
