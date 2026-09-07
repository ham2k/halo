// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The half of the auto-connect hold the operator can see. A launch that holds
// a radio back looks, from the outside, exactly like a radio that is switched
// off: no frequency, no spots following the VFO, nothing tuned. The reason is
// two screens away in Settings, on the row of a rig they may not think to go
// and look at — on the launch right after the app failed to start at all.
//
// So the notice is the whole operator-facing surface of HALO-525, and the trap
// it exists to catch is a hold that is enforced silently.

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/auto_connect_guard.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _heldUuid = 'held-uuid';

Future<HaLoServices> _services({List<String> marks = const []}) async {
  SharedPreferences.setMockInitialValues({
    'stationEquipment': jsonEncode({
      'version': 1,
      'radio1': _heldUuid,
      'nodes': {
        _heldUuid: {
          'typeKey': 'placeholder-radio',
          'name': 'Left Radio',
          'config': <String, dynamic>{},
        },
      },
    }),
    if (marks.isNotEmpty) autoConnectInFlightKey: marks,
  });
  final db = HaLoDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return HaLoServices(db, SettingsService(await SharedPreferences.getInstance()));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an ordinary launch says nothing', () async {
    final services = await _services();
    showAutoConnectHeldNotice(services);
    expect(services.statusBar.activeNotices, isEmpty);
  });

  test('a held radio is named', () async {
    final services = await _services(marks: [_heldUuid]);

    showAutoConnectHeldNotice(services);

    // The name, not just the fact: a shack with two rigs learns nothing from
    // "a radio was not connected", and the operator's next move — check that
    // one is on, press Connect on that one — needs to know which.
    final notice = services.statusBar.activeNotices.single;
    expect(notice.title, contains('Left Radio'));
    expect(notice.text, contains('Left Radio'));
  });

  test('the notice comes down when the Connect it asked for happens', () async {
    // The notice's own instruction is "press Connect on it in Settings". An
    // operator who does that must not be left looking at a card telling them
    // to do it — and in a two-radio shack the card must stop naming the one
    // that is now connected.
    final services = await _services(marks: [_heldUuid]);
    services.cat.onAutoConnectHoldLifted = () {
      services.statusBar.dismissNotice(autoConnectHeldNoticeKey);
      showAutoConnectHeldNotice(services);
    };
    showAutoConnectHeldNotice(services);
    expect(services.statusBar.activeNotices, hasLength(1));

    await services.cat.connect(_heldUuid);

    expect(services.statusBar.activeNotices, isEmpty,
        reason: 'the instruction outlived the pressing of the button it asked for');
  });

  test('a mark left by a radio that has since been deleted says nothing', () async {
    // Nothing prunes the stored marks, so one can outlive its node. A notice
    // about equipment that no longer exists is a fright with no action behind
    // it, and there is nothing left to name in it either.
    final services = await _services(marks: ['some-uuid-that-is-gone']);
    showAutoConnectHeldNotice(services);
    expect(services.statusBar.activeNotices, isEmpty);
  });
}
