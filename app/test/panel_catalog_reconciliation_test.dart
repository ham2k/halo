// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The rules that keep a saved dock arrangement alive across a launch. The
// extensions are asked for their panels asynchronously, so for the first
// frames of every launch the catalog holds only the native panels — and an
// arrangement holding an extension panel must survive that gap rather than
// being judged unbuildable, replaced, and then overwritten by the first tab
// tap. These pin the two halves of that: the catalog knows the difference
// between "no panels" and "could not ask", and a trigger nobody fires is
// rejected where it can still be reported.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/panel_service.dart';

void main() {
  group('resolved', () {
    test('a catalog that could not be read stays unresolved and keeps what it had', () async {
      final service = PanelService(_FakeExtensions(entries: null));
      expect(service.resolved, isFalse, reason: 'nothing has been asked yet');

      await service.refreshExtensionPanels();

      // The caller reconciling a SAVED LAYOUT against this must not read a
      // failed call as "that panel no longer exists".
      expect(service.resolved, isFalse);
    });

    test('a catalog that genuinely holds no panels IS resolved', () async {
      final service = PanelService(_FakeExtensions(entries: const []));
      await service.refreshExtensionPanels();
      // Distinct from the case above, and the distinction is the whole point.
      expect(service.resolved, isTrue);
      expect(service.catalog, isEmpty);
    });

    test('panels from a successful read reach the catalog', () async {
      final service = PanelService(_FakeExtensions(entries: [
        {'hookKey': 'wx', 'key': 'forecast', 'title': 'Forecast'},
      ]));
      await service.refreshExtensionPanels();
      expect(service.resolved, isTrue);
      expect(service['ext:wx:forecast']?.title, 'Forecast');
    });
  });

  group('triggers', () {
    test('only names the host actually fires are accepted', () {
      for (final t in ['operation', 'qso', 'qsoLogged', 'lookup', 'spots', 'tick:5', 'tick:3600']) {
        expect(isKnownPanelTrigger(t), isTrue, reason: '$t is documented in hooks.md');
      }
      // A panel that renders once and never again is indistinguishable from
      // one that meant to, so a name nothing fires is rejected where it can
      // still be reported rather than sitting in the descriptor looking live.
      for (final t in ['qso_logged', 'qsoAdded', 'tick:', 'tick:30s', 'tick:0', 'tick:-5']) {
        expect(isKnownPanelTrigger(t), isFalse, reason: '$t fires nothing');
      }
    });

    test('an unrecognized trigger is dropped from the descriptor, not carried', () {
      final panel = PanelDefinition.fromExtensionEntry({
        'hookKey': 'wx',
        'key': 'forecast',
        'title': 'Forecast',
        'on': ['operation', 'qso_logged', 'tick:30'],
      })!;
      expect(panel.triggers, ['operation', 'tick:30']);
    });
  });

  test('a config field with no key never reaches the form', () {
    // It would render a control the operator can fill in, which is then
    // never persisted and never handed back as `config` — the panel appears
    // to ignore its own settings.
    final panel = PanelDefinition.fromExtensionEntry({
      'hookKey': 'wx',
      'key': 'forecast',
      'title': 'Forecast',
      'form': [
        {'key': 'units', 'fieldType': 'select'},
        {'fieldType': 'text', 'label': 'Nameless'},
      ],
    })!;
    expect(panel.formFields.map((f) => f['key']), ['units']);
  });

  test('editing a config bumps the revision the live panel watches', () {
    final service = PanelService(_FakeExtensions(entries: const []));
    var notifications = 0;
    service.addListener(() => notifications++);

    expect(service.configRevision('ext:wx:forecast'), 0);
    service.markConfigChanged('ext:wx:forecast');
    // A panel with no triggers would otherwise show content rendered against
    // the old config forever.
    expect(service.configRevision('ext:wx:forecast'), 1);
    expect(notifications, 1);
    expect(service.configRevision('ext:other:panel'), 0, reason: 'one panel\'s config is not another\'s');
  });
}

/// Answers the one call the catalog makes. `entries: null` is the host
/// saying "could not ask" — no runtime, or the call failed.
class _FakeExtensions implements PanelExtensionSource {
  final List<Map<String, dynamic>>? entries;

  _FakeExtensions({required this.entries});

  @override
  Future<List<Map<String, dynamic>>?> getExtensionPanels() async => entries;

  @override
  Future<Map<String, dynamic>?> renderPanel({
    required String hookKey,
    required String panelKey,
    required Map<String, dynamic> args,
  }) async => null;

  @override
  Future<Map<String, dynamic>> readPanelConfig({
    required String panelKey,
    required List<Map<String, dynamic>> fields,
  }) async => const {};
}
