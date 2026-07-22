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

  test('setField/action delegate to the logging handlers, no-op when unset', () {
    DevBridge.instance.setFieldHandler = null;
    DevBridge.instance.actionHandler = null;
    // No logging screen active — never throw.
    expect(() => DevBridge.instance.setField('call', 'W1AW'), returnsNormally);
    expect(() => DevBridge.instance.action('log'), returnsNormally);

    String? field;
    String? value;
    String? action;
    DevBridge.instance.setFieldHandler = (f, v) {
      field = f;
      value = v;
    };
    DevBridge.instance.actionHandler = (a) => action = a;

    DevBridge.instance.setField('call', 'W1AW');
    expect(field, 'call');
    expect(value, 'W1AW');
    DevBridge.instance.action('log');
    expect(action, 'log');

    DevBridge.instance.setFieldHandler = null;
    DevBridge.instance.actionHandler = null;
  });
}
