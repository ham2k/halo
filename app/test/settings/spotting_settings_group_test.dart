// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Spotting section: what it stores, what the logging panel reads back,
// that the Spotting control's tune button finds its fields, and the
// Destinations and DX Cluster sections it carries below them.
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart' show ExtensionIconTile, SpotDestinationPolicy;
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

  test('defaults to every ten minutes, offering rather than starting, pulsing, and spotting what is worked', () async {
    final settings = await fresh();
    expect(SpottingSettings.respotInterval(settings), const Duration(minutes: 10));
    expect(SpottingSettings.autoRespotByDefault(settings), isFalse);
    expect(SpottingSettings.pulseBeforeRespot(settings), isTrue);
    expect(SpottingSettings.localSpots(settings), isTrue);
  });

  test('what the section commits is what the panel reads back', () async {
    final settings = await fresh();
    final group = SpottingSettingsGroup(settings);
    await group.commit('respotIntervalMinutes', '20');
    await group.commit('autoRespotByDefault', true);
    await group.commit('pulseBeforeRespot', false);
    await group.commit('localSpots', false);
    expect(SpottingSettings.localSpots(settings), isFalse);
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
    expect(elements, hasLength(4));
    expect(elements.map((e) => e['target']), everyElement('spotting'));
    final options = elements.firstWhere((e) => e['key'] == 'respotIntervalMinutes')['options'] as List;
    expect([for (final o in options) (o as Map)['value']], [for (final m in SpottingSettings.respotIntervalOptions) '$m']);
  });

  group('Destinations section', () {
    SpottingSettingsGroup withDestinations(SettingsService settings) => SpottingSettingsGroup(settings)
      ..destinations = () async => {
        'ham2k-sota': (name: 'SOTAwatch', icon: 'image-filter-hdr', accentColor: '#8D6E63', postsSelfSpots: true),
        'ham2k-pota': (name: 'POTA.app', icon: 'pine-tree', accentColor: '#2E7D32', postsSelfSpots: true),
      };

    // Every row carries the target, the header and the section's close
    // included: the tune dialog keeps only what does, and the section is
    // what the operator opens it for.
    test('one row per destination, by name, under a header of its own, in the tune dialog', () async {
      final elements = await withDestinations(await fresh()).buildElements();
      expect(
        [for (final e in elements) e['key'] ?? e['type']],
        [
          'respotIntervalMinutes',
          'autoRespotByDefault',
          'pulseBeforeRespot',
          'localSpots',
          'destinations',
          'destination-ham2k-pota',
          'destination-ham2k-sota',
          'sectionEnd',
        ],
      );
      expect(elements.map((e) => e['target']), everyElement('spotting'));
      final pota = elements.firstWhere((e) => e['key'] == 'destination-ham2k-pota');
      expect(pota['label'], 'POTA.app');
      expect(pota['value'], 'all');
      expect([for (final o in pota['options'] as List) (o as Map)['label']], ['All spots', 'Only QRV and QRT', 'Any except auto re-spots', "Don't send spots"]);
      final tile = pota['leading'] as ExtensionIconTile;
      expect((tile.icon, tile.accentColor), ('pine-tree', '#2E7D32'));
    });

    // The value's color is how much the destination gets at a glance: a
    // policy mapped to the wrong tone reads as sending what it holds back.
    test('the value shows green for all spots, yellow for some, red for none', () async {
      final settings = await fresh();
      final group = withDestinations(settings);
      Future<Object?> toneFor(SpotDestinationPolicy policy) async {
        await SpottingSettings.setDestination(settings, 'ham2k-pota', policy);
        return (await group.buildElements()).firstWhere((e) => e['key'] == 'destination-ham2k-pota')['tone'];
      }

      expect(await toneFor(SpotDestinationPolicy.all), 'good');
      expect(await toneFor(SpotDestinationPolicy.qrvQrt), 'partial');
      expect(await toneFor(SpotDestinationPolicy.exceptAuto), 'partial');
      expect(await toneFor(SpotDestinationPolicy.none), 'bad');
    });

    // The two choices about self-spots change nothing for a destination
    // that is sent none: picked, its row would turn yellow while it goes on
    // getting every spot it ever got.
    test('a destination that only spots other stations offers all or none', () async {
      final group = SpottingSettingsGroup(await fresh())
        ..destinations = () async => {'ham2k-hunter': (name: 'Hunter', icon: null, accentColor: null, postsSelfSpots: false)};
      final hunter = (await group.buildElements()).firstWhere((e) => e['key'] == 'destination-ham2k-hunter');
      expect([for (final o in hunter['options'] as List) (o as Map)['value']], ['all', 'none']);
    });

    test('no section while no extension posts spots', () async {
      final group = SpottingSettingsGroup(await fresh())..destinations = () async => const {};
      expect(await group.buildElements(), hasLength(4));
    });

    // Only what is held back is stored: a destination installed later, or
    // one the operator set back, is sent every spot.
    test('what a row commits is what the panel reads back, and All drops the entry', () async {
      final settings = await fresh();
      final group = withDestinations(settings);
      await group.commit('destination-ham2k-pota', 'qrvQrt');
      await group.commit('destination-ham2k-sota', 'none');
      expect(SpottingSettings.read(settings).destinations, {'ham2k-pota': SpotDestinationPolicy.qrvQrt, 'ham2k-sota': SpotDestinationPolicy.none});
      final pota = (await group.buildElements()).firstWhere((e) => e['key'] == 'destination-ham2k-pota');
      expect(pota['value'], 'qrvQrt');

      await group.commit('destination-ham2k-pota', 'all');
      await group.commit('destination-ham2k-sota', 'sometimes');
      expect(settings.settingsGroup(SpottingSettings.group)[SpottingSettings.destinationsKey], {'ham2k-sota': 'none'});
    });

    // The panel rebuilds its controls only when a value changes; a record
    // compared with `==` holds a fresh map every read and never matches, and
    // one that skipped the destinations would leave the control sending
    // where the operator just said not to.
    test('two reads of the same store are the same values, and a changed destination is not', () async {
      final settings = await fresh({'settings.spotting': '{"destinations": {"ham2k-pota": "exceptAuto"}}'});
      final before = SpottingSettings.read(settings);
      expect(SpottingSettings.same(before, SpottingSettings.read(settings)), isTrue);
      await SpottingSettings.setDestination(settings, 'ham2k-pota', SpotDestinationPolicy.none);
      expect(SpottingSettings.same(before, SpottingSettings.read(settings)), isFalse);
    });

    // The setting goes on holding the destination back whether or not the
    // listing names it; without a row there is nothing to undo it with.
    test('a destination held back keeps a row when the listing leaves it out', () async {
      final settings = await fresh({'settings.spotting': '{"destinations": {"ham2k-sota": "none"}}'});
      final group = SpottingSettingsGroup(settings)
        ..destinations = () async => {'ham2k-pota': (name: 'POTA.app', icon: 'pine-tree', accentColor: '#2E7D32', postsSelfSpots: true)};
      final rows = [
        for (final e in await group.buildElements())
          if (e['fieldType'] == 'select' && e['key'] != 'respotIntervalMinutes') e,
      ];
      expect(
        [for (final e in rows) (e['key'], e['label'], e['value'])],
        [('destination-ham2k-sota', 'ham2k-sota', 'none'), ('destination-ham2k-pota', 'POTA.app', 'all')],
      );

      final nothingListed = SpottingSettingsGroup(settings)..destinations = () async => const {};
      expect([for (final e in await nothingListed.buildElements()) e['key']], contains('destination-ham2k-sota'));
    });
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
        ['respotIntervalMinutes', 'autoRespotByDefault', 'pulseBeforeRespot', 'localSpots', 'cluster', 'connect', 'sectionEnd'],
        reason: 'the section ends with the cluster: an extension row placed in Spotting is not one of its rows',
      );
      expect(elements[4], {'type': 'header', 'style': 'section', 'key': 'cluster', 'title': 'DX Cluster'});
      expect(elements.where((e) => e['target'] == 'spotting'), hasLength(4));
    });

    // A header over nothing, where no extension uses the cluster.
    test('no section while the cluster offers no rows', () async {
      final group = SpottingSettingsGroup(await fresh())..cluster = _FakeCluster(const []);
      expect(await group.buildElements(), hasLength(4));
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
