// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  test('delegates to the attached LoggingControls, and no-ops when detached', () async {
    final controller = LoggingControlsController();

    // Before attach (or after detach) every call is a safe no-op — the widget
    // may not be mounted when the bridge fires.
    expect(controller.isAttached, isFalse);
    expect(() => controller.setField('call', 'W1AW'), returnsNormally);
    await controller.submit();
    expect(() => controller.wipe(), returnsNormally);

    String? field;
    String? value;
    var submitted = false;
    var wiped = false;
    controller.attach(
      setField: (f, v) {
        field = f;
        value = v;
      },
      submit: () async => submitted = true,
      wipe: () => wiped = true,
    );

    expect(controller.isAttached, isTrue);
    controller.setField('call', 'W1AW');
    expect(field, 'call');
    expect(value, 'W1AW');
    await controller.submit();
    expect(submitted, isTrue);
    controller.wipe();
    expect(wiped, isTrue);

    controller.detach();
    expect(controller.isAttached, isFalse);
    field = null;
    controller.setField('call', 'K1ABC'); // detached → no-op, doesn't reach the widget
    expect(field, isNull);
  });
}
