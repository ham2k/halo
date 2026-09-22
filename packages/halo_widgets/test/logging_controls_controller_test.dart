// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  const chord = KeyDownEvent(physicalKey: PhysicalKeyboardKey.keyZ, logicalKey: LogicalKeyboardKey.keyZ, timeStamp: Duration.zero);

  test('delegates to the attached LoggingControls, and no-ops when detached', () async {
    final controller = LoggingControlsController();

    // Before attach (or after detach) every call is a safe no-op — the widget
    // may not be mounted when the bridge fires.
    expect(controller.isAttached, isFalse);
    expect(() => controller.setField('call', 'W1AW'), returnsNormally);
    await controller.submit();
    expect(() => controller.wipe(), returnsNormally);
    expect(controller.isFieldsLocked, isFalse);
    // Ignored, not handled: a detached controller must leave the key to
    // whoever is next, or Cmd/Ctrl+Z dies above an unmounted panel.
    expect(controller.handleChord(chord), KeyEventResult.ignored);
    expect(() => controller.focusCall(), returnsNormally);
    expect(() => controller.focusSecondaryControls(), returnsNormally);
    expect(() => controller.focusLastPrimaryField(), returnsNormally);

    String? field;
    String? value;
    var submitted = false;
    var wiped = false;
    var locked = false;
    var focusedCall = false;
    var focusedPills = false;
    var focusedLastField = false;
    controller.attach(
      setField: (f, v) {
        field = f;
        value = v;
      },
      submit: () async => submitted = true,
      wipe: () => wiped = true,
      isFieldsLocked: () => locked,
      handleChord: (event) => KeyEventResult.handled,
      focusCall: () => focusedCall = true,
      focusSecondaryControls: () => focusedPills = true,
      focusLastPrimaryField: () => focusedLastField = true,
    );

    expect(controller.isAttached, isTrue);
    controller.setField('call', 'W1AW');
    expect(field, 'call');
    expect(value, 'W1AW');
    await controller.submit();
    expect(submitted, isTrue);
    controller.wipe();
    expect(wiped, isTrue);
    locked = true;
    expect(controller.isFieldsLocked, isTrue);
    expect(controller.handleChord(chord), KeyEventResult.handled);
    // The focus ladder's two ends (APP-19): Escape from the list hands the
    // keyboard back to the call field, Enter on a row back to whichever main
    // field the operator was last in, and walking off the newest row onto
    // the pills.
    controller.focusCall();
    expect(focusedCall, isTrue);
    controller.focusSecondaryControls();
    expect(focusedPills, isTrue);
    controller.focusLastPrimaryField();
    expect(focusedLastField, isTrue);

    controller.detach();
    expect(controller.isAttached, isFalse);
    field = null;
    controller.setField('call', 'K1ABC'); // detached → no-op, doesn't reach the widget
    expect(field, isNull);
    focusedCall = false;
    controller.focusCall();
    expect(focusedCall, isFalse);
    expect(controller.isFieldsLocked, isFalse);
    expect(controller.handleChord(chord), KeyEventResult.ignored);
  });
}
