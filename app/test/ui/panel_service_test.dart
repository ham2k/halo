// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The panels catalog's contract: what an extension entry has to carry before
// it becomes a panel, how the two sources share one list, and the identity
// rules that keep a saved layout pointing at the right pane.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/panel_service.dart';

void main() {
  Map<String, dynamic> entry({String? hookKey = 'wx', String? key = 'forecast', String? title = 'Forecast', Object? on, Object? form}) => {
    'hookKey': ?hookKey,
    'key': ?key,
    'title': ?title,
    'on': ?on,
    'form': ?form,
  };

  test('an extension panel is namespaced by the hook that registered it', () {
    final panel = PanelDefinition.fromExtensionEntry(entry())!;
    // Two extensions may both call a panel 'forecast'; the id is what a
    // saved layout stores, so it has to survive that.
    expect(panel.id, 'ext:wx:forecast');
    expect(panel.source, PanelSource.extension);
  });

  test('an entry missing what a panel cannot work without is dropped, not guessed at', () {
    // An extension bug costs that panel, never the rest of the catalog.
    expect(PanelDefinition.fromExtensionEntry(entry(title: null)), isNull);
    expect(PanelDefinition.fromExtensionEntry(entry(key: null)), isNull);
    expect(PanelDefinition.fromExtensionEntry(entry(hookKey: null)), isNull);
  });

  test('junk in a trigger or form list costs only the junk', () {
    final panel = PanelDefinition.fromExtensionEntry(
      entry(
        on: ['operation', 42, 'tick:30'],
        form: [
          {'key': 'units'},
          'not a field',
        ],
      ),
    )!;
    expect(panel.triggers, ['operation', 'tick:30']);
    expect(panel.formFields.length, 1);
  });

  test('a panel with no form and no settings target offers no settings', () {
    // What decides whether a gear appears beside it in Layout Setup.
    expect(PanelDefinition.fromExtensionEntry(entry())!.hasSettings, isFalse);
    expect(
      PanelDefinition.fromExtensionEntry(
        entry(
          form: [
            {'key': 'units'},
          ],
        ),
      )!.hasSettings,
      isTrue,
    );
    expect(const PanelDefinition(id: 'logging', title: 'QSOs', source: PanelSource.native, settingsTarget: 'logging').hasSettings, isTrue);
  });

  test('re-registering an identical native panel notifies nobody', () {
    // Never asked anything: these tests are about the catalog's own half.
    final service = PanelService(ExtensionService());
    var notifications = 0;
    service.addListener(() => notifications++);

    const panel = PanelDefinition(id: 'map', title: 'Map', source: PanelSource.native);
    service.registerNative(panel);
    // Native panels are registered from didChangeDependencies, which runs far
    // more often than their identity changes, and every notification rebuilds
    // everything watching the catalog.
    service.registerNative(panel);
    expect(notifications, 1);

    service.registerNative(const PanelDefinition(id: 'map', title: 'Chart', source: PanelSource.native));
    expect(notifications, 2, reason: 'a genuine change still gets through');
    expect(service['map']?.title, 'Chart');
  });
}
