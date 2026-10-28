// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Spotting section: what it stores, what the logging panel reads back,
// that the Spotting control's tune button finds its fields, and the DX
// Cluster section it carries below them.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ham2k_logger/services/cluster/cluster_settings.dart';
import 'package:ham2k_logger/services/extensions/extension_info.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/spotting_settings.dart';
import 'package:ham2k_logger/settings/settings_registry.dart';
import 'package:ham2k_logger/settings/spotting_settings_group.dart';

import '../support/halo_test_support.dart';

class _FakeCluster extends SettingsGroup {
  _FakeCluster(this.elements);

  final List<Map<String, dynamic>> elements;
  final committed = <String, dynamic>{};

  @override
  String get key => 'cluster';
  @override
  String get title => 'DX Cluster';
  @override
  int get order => 0;
  @override
  Future<List<Map<String, dynamic>>> buildElements() async => elements;
  @override
  Future<void> commit(String fieldKey, dynamic value) async => committed[fieldKey] = value;
}

void main() {
  Future<SettingsService> fresh([Map<String, Object> stored = const {}]) async {
    SharedPreferences.setMockInitialValues(stored);
    return SettingsService(await SharedPreferences.getInstance());
  }

  test('defaults to every ten minutes, offering rather than starting, and pulsing', () async {
    final settings = await fresh();
    expect(SpottingSettings.respotInterval(settings), const Duration(minutes: 10));
    expect(SpottingSettings.autoRespotByDefault(settings), isFalse);
    expect(SpottingSettings.pulseBeforeRespot(settings), isTrue);
  });

  test('what the section commits is what the panel reads back', () async {
    final settings = await fresh();
    final group = SpottingSettingsGroup(settings);
    await group.commit('respotIntervalMinutes', '20');
    await group.commit('autoRespotByDefault', true);
    await group.commit('pulseBeforeRespot', false);
    expect(SpottingSettings.respotInterval(settings), const Duration(minutes: 20));
    expect(SpottingSettings.autoRespotByDefault(settings), isTrue);
    expect(SpottingSettings.pulseBeforeRespot(settings), isFalse);
  });

  // A string under a toggle's key would make its getter throw where the
  // logging panel reads it.
  test('a value of the wrong kind for its key is not stored', () async {
    final settings = await fresh();
    final group = SpottingSettingsGroup(settings);
    await group.commit('autoRespotByDefault', 'yes');
    await group.commit('pulseBeforeRespot', 'no');
    await group.commit('respotIntervalMinutes', true);
    await group.commit('someRenamedKey', true);
    expect(settings.settingsGroup(SpottingSettings.group), isEmpty);
    expect(SpottingSettings.autoRespotByDefault(settings), isFalse);
  });

  // A value the picker never offered — another build's list, a hand-edited
  // store — would otherwise show one interval while respotting on another.
  test('a stored interval the picker does not offer snaps to the nearest one it does', () async {
    final settings = await fresh({'settings.spotting': '{"respotIntervalMinutes": "45"}'});
    expect(SpottingSettings.respotInterval(settings), const Duration(minutes: 30));
    final interval = (await SpottingSettingsGroup(settings).buildElements()).firstWhere((e) => e['key'] == 'respotIntervalMinutes');
    expect(interval['value'], '30');
  });

  test('a stored interval that is no number at all takes the default', () async {
    final settings = await fresh({'settings.spotting': '{"respotIntervalMinutes": "NaN"}'});
    expect(SpottingSettings.respotInterval(settings), const Duration(minutes: 10));
  });

  // The tune button opens `target: 'spotting'`: a field without it would be
  // in All settings and missing from the dialog.
  test('every field is in the tune dialog', () async {
    final elements = await SpottingSettingsGroup(await fresh()).buildElements();
    expect(elements, hasLength(3));
    expect(elements.map((e) => e['target']), everyElement('spotting'));
    final options = elements.firstWhere((e) => e['key'] == 'respotIntervalMinutes')['options'] as List;
    expect([for (final o in options) (o as Map)['value']], [for (final m in SpottingSettings.respotIntervalOptions) '$m']);
  });

  group('DX Cluster section', () {
    // Without the header the cluster's rows would read as more auto-respot
    // options; without the target check they would crowd the tune dialog,
    // which is about respotting only.
    test("the cluster's rows follow spotting's under a header of their own, outside the tune dialog", () async {
      final group = SpottingSettingsGroup(await fresh())
        ..cluster = _FakeCluster([
          {'type': 'field', 'fieldType': 'checkbox', 'key': 'connect', 'label': 'Connect', 'value': true},
        ]);
      final elements = await group.buildElements();
      expect(
        [for (final e in elements) e['key'] ?? e['type']],
        ['respotIntervalMinutes', 'autoRespotByDefault', 'pulseBeforeRespot', 'cluster', 'connect', 'sectionEnd'],
        reason: 'the section ends with the cluster: an extension row placed in Spotting is not one of its rows',
      );
      expect(elements[3], {'type': 'header', 'style': 'section', 'key': 'cluster', 'title': 'DX Cluster'});
      expect(elements.where((e) => e['target'] == 'spotting'), hasLength(3));
    });

    // A header over nothing, where no extension uses the cluster.
    test('no section while the cluster offers no rows', () async {
      final group = SpottingSettingsGroup(await fresh())..cluster = _FakeCluster(const []);
      expect(await group.buildElements(), hasLength(3));
    });

    // The Settings panel and SET commit through the group that shows the
    // field: a cluster key kept here would be dropped, and a spotting key
    // passed on would land in the cluster's store.
    test("each key's commit reaches the store it belongs to", () async {
      final settings = await fresh();
      final cluster = _FakeCluster(const []);
      final group = SpottingSettingsGroup(settings)..cluster = cluster;
      await group.commit('connect', false);
      await group.commit('pulseBeforeRespot', false);
      await group.commit('autoRespotByDefault', 'yes');
      expect(cluster.committed, {'connect': false});
      expect(SpottingSettings.pulseBeforeRespot(settings), isFalse);
    });

    // The wiring, not the group: a cluster group registered on its own again
    // would be a second DX Cluster category beside this section.
    test('the app shows the cluster only inside Spotting, once an extension uses it', () async {
      final HaLoHarness(:services) = await makeHaLoServices();
      expect(services.settingsRegistry[ClusterSettings.group], isNull);
      final spotting = services.settingsRegistry[SpottingSettings.group]!;
      expect((await spotting.buildElements()).where((e) => e['type'] == 'header'), isEmpty);

      services.extensions.clusterCalls.allow([
        const ExtensionInfo(key: 'reader', file: 'reader.js', source: ExtensionSource.dev, core: true, name: 'reader', requiresClusterRead: true),
      ]);
      final keys = [for (final e in await spotting.buildElements()) e['key']];
      expect(keys, containsAll([ClusterSettings.connectKey, 'password', ClusterSettings.scrollbackKey]));
    });
  });
}
