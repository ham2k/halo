// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The glue between a spot suggestion and the zero-beat offset
// (docs/design/cat.md § Avoiding zero beat).
//
// zero_beat_test.dart proves the rules; nothing there can prove they are
// WIRED to anything. Each joint below fails silently — the feature goes dead,
// or fires with no radio and rewrites a logged frequency nobody tuned to,
// with every rule test still green.
//
// The suggestion maps are built by the real `suggestedQsoFromSpot`, so a
// rename of the keys it writes fails here rather than in production.

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/zero_beat.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/spots_panel.dart';
import 'package:ham2k_logger/services/peer/peer_station_radios.dart';
import 'package:ham2k_logger/views/operation_view.dart';

import '../support/fake_cat_radio.dart';

const _spotFreqKHz = 14050.0;

/// A spot as a source publishes one, put through the real spot-to-suggestion
/// mapping the Spots panel uses on tap.
Map<String, dynamic> _suggestion({String mode = 'CW', double freq = _spotFreqKHz}) =>
    suggestedQsoFromSpot({
      'their': {'call': 'N0DX'},
      'freq': freq,
      'band': '20m',
      'mode': mode,
      'refs': const [],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService settings;
  late RadioService catRadio;
  late CatService cat;
  late HaLoServices services;

  /// Services with a fake CAT radio, connected as radio1 or not.
  Future<void> build({
    required bool connected,
    bool avoidZeroBeat = true,
    bool catExperiment = true,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (catExperiment) 'experiments': jsonEncode({
          'gato': {'enabled': true},
        }),
    });
    final prefs = await SharedPreferences.getInstance();
    settings = SettingsService(prefs);
    await settings.setAvoidZeroBeat(avoidZeroBeat);

    catRadio = RadioService(prefs, writeDelay: Duration.zero);
    cat = fakeCatService(settings, catRadio);
    if (connected) await connectFakeRadio1(cat);

    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    addTearDown(cat.dispose);
    addTearDown(catRadio.dispose);
    services = HaLoServices(db, settings, cat: cat);
  }

  Map<String, dynamic> resolve(Map<String, dynamic> qso, {double draw = 0.0}) =>
      zeroBeatSuggestionFor(qso, services: services, offsetter: ZeroBeatOffsetter(nextDraw: () => draw));

  test('with radio1 connected, a CW suggestion is moved off the spot', () async {
    await build(connected: true);
    final moved = resolve(_suggestion())['freq'] as double;
    expect(moved, isNot(_spotFreqKHz), reason: 'the offset is not wired to the suggestion at all');
    // closeTo, not an exact bound: the subtraction of two kHz doubles leaves
    // a float residue, and draw 0.0 lands exactly on the dead zone's edge.
    expect((moved - _spotFreqKHz).abs() * 1000, closeTo(10, 0.001));
  });

  test('with no radio connected, the spot frequency is used exactly', () async {
    // Reading "connected" from the wrong place — any node, or ignoring CAT
    // altogether — rewrites a logged frequency nobody ever tuned to.
    await build(connected: false);
    expect(resolve(_suggestion())['freq'], _spotFreqKHz);
  });

  test("a peer's radio the peer is offering counts, because a move reaches it", () async {
    // The offset is gated on something acting on it. Something does here:
    // `PeerChannels._onRadioChanged` forwards an operator's vfoA move to the
    // peer as `catSet`, so treating a peer pick as "no radio" tunes the far
    // rig exactly zero beat — the one outcome this setting exists to avoid.
    await build(connected: false);
    await cat.setRadio1(const PeerRadio(PeerRadioSelection(
      deviceId: 'device-a',
      radioId: 'rig-1',
      radioName: 'FTDX10',
    )));
    services.peerRemoteRadios.setOffers('device-a', "VE1SK's iPad", const [
      PeerRadioOffer(id: 'rig-1', name: 'FTDX10'),
    ]);

    final moved = resolve(_suggestion())['freq'] as double;
    expect(moved, isNot(_spotFreqKHz));
  });

  test("a peer's radio nobody is offering does not count", () async {
    // The pick survives the peer walking away — and while it is away nothing
    // acts on a tune, so an offset would hand the operator digits to dial by
    // hand and leave the log claiming a frequency they never transmitted on.
    await build(connected: false);
    await cat.setRadio1(const PeerRadio(PeerRadioSelection(
      deviceId: 'device-a',
      radioId: 'rig-1',
      radioName: 'FTDX10',
    )));

    expect(resolve(_suggestion())['freq'], _spotFreqKHz);
  });

  test('a radio connected but not driving the panel does not count', () async {
    // The real shape of it: two rigs, the connected one is NOT radio1. Built
    // out of states the app can actually produce — pointing radio1 at a
    // sentinel would kill the same mutations while modelling nothing.
    await build(connected: true);
    final idle = await cat.addNode(typeKey: 'fake-type', config: {'host': 'second.local'});
    await cat.setRadio1(LocalRadio(idle.uuid));
    expect(cat.stateFor(idle.uuid).status, isNot(EquipmentStatus.connected));
    expect(resolve(_suggestion())['freq'], _spotFreqKHz);
  });

  test('without the CAT experiment the spot frequency is used exactly', () async {
    // The experiment gate also keeps `services.cat` unread on a CAT-less
    // install — but that part is NOT pinned here: this fixture injects an
    // already-built CatService, so construction is unobservable either way,
    // and reordering the gate below `final cat = services.cat` would leave
    // every assertion green. Only the frequency is claimed.
    await build(connected: true, catExperiment: false);
    expect(resolve(_suggestion())['freq'], _spotFreqKHz);
  });

  test('with the setting off, the spot frequency is used exactly', () async {
    // Proves `enabled` comes from settings.avoidZeroBeat.
    await build(connected: true, avoidZeroBeat: false);
    expect(resolve(_suggestion())['freq'], _spotFreqKHz);
  });

  test('a phone suggestion is passed straight through', () async {
    await build(connected: true);
    final qso = _suggestion(mode: 'SSB');
    expect(identical(resolve(qso), qso), isTrue);
  });

  test('the range setting reaches the draw', () async {
    // A wrong key here would silently pin every operator to the default.
    await build(connected: true);
    await settings.setSettingValue(SettingsService.radioGroup, 'zeroBeatRangeHz', '75');
    final moved = resolve(_suggestion(), draw: 0.499)['freq'] as double;
    expect((moved - _spotFreqKHz).abs() * 1000, closeTo(75, 0.5));
  });
}
