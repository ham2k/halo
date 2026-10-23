// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extensions/extension_info.dart';
import 'package:ham2k_logger/services/extensions/settings_placement.dart';

Map<String, dynamic> _panel({String? section, bool sidebar = true}) => {
  'panelKey': 'w7abc-notes',
  'hookKey': 'w7abc-notes',
  'extensionKey': 'w7abc-notes',
  'title': 'Notes',
  'kind': 'simple',
  'sidebar': sidebar,
  'dataFilesSection': false,
  'section': section,
};

void main() {
  group('placeSettingsPanel', () {
    test("the app's own extensions keep whatever they registered", () {
      final placed = placeSettingsPanel(_panel(section: 'privacy'), trusted: true);
      expect(placed['section'], 'privacy');
      expect(placed['sidebar'], isTrue);
      expect(placed['mayBeCommon'], isTrue);
    });

    test('with no settings in the manifest: no sidebar entry, no Common Preferences', () {
      final placed = placeSettingsPanel(_panel(), trusted: false);
      expect(placed['sidebar'], isFalse);
      expect(placed['mayBeCommon'], isFalse);
      expect(placed['section'], isNull);
    });

    test("with no settings in the manifest, the panel's own section is kept only when it is a listed one", () {
      expect(placeSettingsPanel(_panel(section: 'spotting'), trusted: false)['section'], 'spotting');
      expect(placeSettingsPanel(_panel(section: 'privacy'), trusted: false)['section'], isNull);
    });

    test("the manifest's section wins over the panel's, listed or not — it is the reviewed one", () {
      const declared = ExtensionSettingsPlacement(section: 'activities');
      expect(placeSettingsPanel(_panel(section: 'lookups'), trusted: false, declared: declared)['section'], 'activities');
      const reviewed = ExtensionSettingsPlacement(section: 'cluster');
      expect(placeSettingsPanel(_panel(), trusted: false, declared: reviewed)['section'], 'cluster');
    });

    test('a sidebar entry needs both the panel asking and the manifest declaring it', () {
      const declared = ExtensionSettingsPlacement(sidebar: true);
      expect(placeSettingsPanel(_panel(), trusted: false, declared: declared)['sidebar'], isTrue);
      expect(placeSettingsPanel(_panel(sidebar: false), trusted: false, declared: declared)['sidebar'], isFalse);
      expect(placeSettingsPanel(_panel(), trusted: false, declared: const ExtensionSettingsPlacement())['sidebar'], isFalse);
    });

    test('Common Preferences only with the manifest declaring it', () {
      expect(placeSettingsPanel(_panel(), trusted: false, declared: const ExtensionSettingsPlacement(common: true))['mayBeCommon'], isTrue);
      expect(placeSettingsPanel(_panel(), trusted: false, declared: const ExtensionSettingsPlacement(section: 'lookups'))['mayBeCommon'], isFalse);
    });

    test('everything else about the panel is passed through', () {
      final placed = placeSettingsPanel({..._panel(), 'dataFilesSection': true, 'order': 7}, trusted: false);
      expect(placed['dataFilesSection'], isTrue);
      expect(placed['order'], 7);
      expect(placed['title'], 'Notes');
    });
  });

  group('ExtensionSettingsPlacement.fromJson', () {
    test('reads the three keys', () {
      final placement = ExtensionSettingsPlacement.fromJson({'section': 'contests', 'sidebar': true, 'common': true})!;
      expect(placement.section, 'contests');
      expect(placement.sidebar, isTrue);
      expect(placement.common, isTrue);
    });

    test('reads what it cannot parse as the narrowest placement, never as a refusal', () {
      expect(ExtensionSettingsPlacement.fromJson(null), isNull);
      expect(ExtensionSettingsPlacement.fromJson('activities'), isNull);
      final placement = ExtensionSettingsPlacement.fromJson({'section': 7, 'sidebar': 'yes', 'common': 1})!;
      expect(placement.section, isNull);
      expect(placement.sidebar, isFalse);
      expect(placement.common, isFalse);
    });

    test("is carried by an installed manifest's ExtensionInfo", () {
      final info = ExtensionInfo.fromJson({
        'key': 'w7abc-notes',
        'name': 'Notes',
        'core': false,
        'source': 'installed',
        'settings': {'section': 'lookups'},
      });
      expect(info.settings?.section, 'lookups');
      expect(ExtensionInfo.fromJson({'key': 'w7abc-notes', 'core': false}).settings, isNull);
    });
  });

  group('owningExtension', () {
    String keyOf(String key) => key;

    test('a key is its own owner', () {
      expect(owningExtension('pota', ['pota', 'pota-all'], keyOf), 'pota');
    });

    test('a sub-extension belongs to the longest key it extends', () {
      expect(owningExtension('pota-all-parks', ['pota', 'pota-all'], keyOf), 'pota-all');
      expect(owningExtension('pota_spots', ['pota'], keyOf), 'pota');
    });

    test('a key merely starting with another is not its sub-extension', () {
      expect(owningExtension('potato', ['pota'], keyOf), isNull);
    });
  });

  test('every listed section but the five the app already had is one of its new sections', () {
    expect(extensionSettingsSections.difference({'spotting', 'logging', 'radio', 'map', 'exports'}), {
      'activities',
      'hunting',
      'contests',
      'lookups',
      'dashboard',
    });
  });
}
