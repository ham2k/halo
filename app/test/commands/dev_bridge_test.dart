// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/config/dev_bridge.dart';

void main() {
  test('state() returns the active provider snapshot, else a safe placeholder', () {
    DevBridge.instance.stateProvider = null;
    // No screen registered (e.g. the home screen) — never null/throw.
    expect(DevBridge.instance.state(), {'view': 'none'});
    expect(DevBridge.instance.guess(), isNull);

    DevBridge.instance.stateProvider = () => {
      'view': 'operation',
      'call': 'W1AW',
      'guess': {'grid': 'FN31pr'},
    };
    expect(DevBridge.instance.state()['call'], 'W1AW');
    expect(DevBridge.instance.guess(), {'grid': 'FN31pr'});

    DevBridge.instance.stateProvider = null; // don't leak into other tests
  });

  test('setField/action delegate to the logging handlers, and setField says when it set nothing', () {
    DevBridge.instance.setFieldHandler = null;
    DevBridge.instance.actionHandler = null;
    // No logging screen active: a script must hear that nothing was set,
    // not carry on as if the field held its value.
    expect(DevBridge.instance.setField('call', 'W1AW'), contains('error'));
    expect(() => DevBridge.instance.action('log'), returnsNormally);

    String? field;
    String? value;
    String? action;
    DevBridge.instance.setFieldHandler = (f, v) {
      field = f;
      value = v;
    };
    DevBridge.instance.actionHandler = (a) => action = a;

    expect(DevBridge.instance.setField('call', 'W1AW'), {'set': 'call'});
    expect(field, 'call');
    expect(value, 'W1AW');
    // The logging controls set only the call; any other field would vanish
    // there without a word.
    field = null;
    expect(DevBridge.instance.setField('rst', '59'), contains('error'));
    expect(field, isNull);
    DevBridge.instance.action('log');
    expect(action, 'log');

    DevBridge.instance.setFieldHandler = null;
    DevBridge.instance.actionHandler = null;
  });

  test('ready resolves on signalReady() and is idempotent', () async {
    DevBridge.instance.resetReadyForTest();

    var resolved = false;
    // ignore: unawaited_futures — we assert on the flag, not by awaiting.
    DevBridge.instance.ready.then((_) => resolved = true);

    // Not resolved until the app signals it (this is what lets agents await
    // instead of guessing a delay).
    await Future<void>.delayed(Duration.zero);
    expect(resolved, isFalse);

    DevBridge.instance.signalReady();
    await Future<void>.delayed(Duration.zero);
    expect(resolved, isTrue);

    // Idempotent: a second signal (stream re-emit, another home mount) is a
    // no-op, not a "already completed" throw.
    expect(() => DevBridge.instance.signalReady(), returnsNormally);
  });
}
