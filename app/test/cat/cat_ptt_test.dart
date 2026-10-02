// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ['] PTT (cat_ptt.dart): the app's key, and how it follows the radio.
//
// The traps are all about a transmitter left on the air, or an unkey sent for
// a key nobody holds: a timeout that never fires, a key the radio dropped by
// itself that the next ['] "unkeys" instead of keying, a key on one radio left
// on while another one keys.

import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/cat_ptt.dart';
import 'package:ham2k_logger/services/cat/driver.dart';

class _FakePtt implements PttSession {
  final sent = <bool>[];
  void Function(bool on)? onSet;

  @override
  void setPtt(bool on) {
    sent.add(on);
    onSet?.call(on);
  }

  @override
  Duration? get expectedUpdateInterval => null;
  @override
  void handleData(Uint8List chunk) {}
  @override
  void startUpdates() {}
  @override
  void stopUpdates() {}
  @override
  void teardown() {}
}

void main() {
  late _FakePtt radio;
  late CatPtt ptt;

  setUp(() {
    radio = _FakePtt();
    ptt = CatPtt();
  });

  tearDown(() => ptt.dispose());

  test("['] keys, and ['] again unkeys", () {
    fakeAsync((async) {
      ptt.toggle(radio);
      expect(ptt.held.value, isTrue);
      ptt.onTransmitting(radio, true);
      ptt.toggle(radio);
      expect(radio.sent, [true, false]);
      expect(ptt.held.value, isFalse);
    });
  });

  test('a held key drops itself at the timeout, and not before', () {
    fakeAsync((async) {
      ptt.toggle(radio);
      ptt.onTransmitting(radio, true);
      async.elapse(pttTimeout - const Duration(seconds: 1));
      expect(radio.sent, [true], reason: 'unkeyed early: an operator mid-over loses the key');
      async.elapse(const Duration(seconds: 1));
      expect(radio.sent, [true, false], reason: 'a forgotten key must not stay on the air');
      expect(ptt.held.value, isFalse);
    });
  });

  test("a radio that drops the key itself clears it, and the next ['] keys again", () {
    fakeAsync((async) {
      ptt.toggle(radio);
      ptt.onTransmitting(radio, true);
      ptt.onTransmitting(radio, false);
      expect(ptt.held.value, isFalse);
      // The unkey goes out anyway: a CAT key is latched, and a report that was
      // transient or misread would leave the radio keyed with no timeout.
      expect(radio.sent, [true, false]);
      // Without following the radio, this ['] would send an unkey for a key
      // nobody holds, and the operator would have to press it twice to talk.
      ptt.toggle(radio);
      expect(radio.sent, [true, false, true]);
      ptt.onTransmitting(radio, true);
      // And the timeout of the dropped key does not cut the new one short.
      async.elapse(pttTimeout - const Duration(seconds: 1));
      expect(radio.sent, [true, false, true]);
    });
  });

  test('a radio that reports TX as it keys is heard, so its own unkey still clears the key', () {
    fakeAsync((async) {
      radio.onSet = (on) => ptt.onTransmitting(radio, on);
      ptt.toggle(radio);
      // The radio's own time-out timer.
      ptt.onTransmitting(radio, false);
      expect(ptt.held.value, isFalse, reason: 'a confirmation that arrived before the key was held went unheard');
    });
  });

  test('a stale "not transmitting" before the radio confirms does not drop the key', () {
    fakeAsync((async) {
      ptt.toggle(radio);
      // The poll that was already on the wire when the key went out.
      ptt.onTransmitting(radio, false);
      expect(ptt.held.value, isTrue);
      expect(radio.sent, [true]);
    });
  });

  test('a radio that never reports TX keeps the key until the timeout', () {
    fakeAsync((async) {
      // A slow TX watch, a radio that cannot say, or one that refused: none
      // of them is told apart from silence, and none unkeys a working key
      // early. The timeout is what bounds them all.
      ptt.toggle(radio);
      async.elapse(pttTimeout - const Duration(seconds: 1));
      expect(ptt.held.value, isTrue);
      async.elapse(pttTimeout);
      expect(radio.sent, [true, false]);
    });
  });

  test('keying one radio first unkeys the other: one transmitter at a time', () {
    fakeAsync((async) {
      final other = _FakePtt();
      ptt.toggle(radio);
      ptt.toggle(other);
      expect(radio.sent, [true, false]);
      expect(other.sent, [true]);
      expect(ptt.heldOn(other), isTrue);
      expect(ptt.heldOn(radio), isFalse);
      // The other radio's TX reports are not about this key.
      ptt.onTransmitting(radio, true);
      ptt.onTransmitting(radio, false);
      expect(ptt.held.value, isTrue);
    });
  });

  test('a key held on a session that closes is forgotten, and not sent anywhere', () {
    fakeAsync((async) {
      ptt.toggle(radio);
      // A reconnect: the old session's teardown unkeys the radio itself.
      ptt.forget(radio);
      expect(ptt.held.value, isFalse);
      // An unkey here would go to a closed connection, and cost the operator
      // a second press to talk.
      expect(ptt.release(), isFalse);
      final replacement = _FakePtt();
      ptt.toggle(replacement);
      expect(radio.sent, [true]);
      expect(replacement.sent, [true], reason: "the first ['] after a reconnect keys");
      // And the old key's timeout does not cut the new one short.
      async.elapse(pttTimeout - const Duration(seconds: 1));
      expect(replacement.sent, [true]);
    });
  });

  test('closing some other session leaves the key alone', () {
    fakeAsync((async) {
      ptt.toggle(radio);
      ptt.forget(_FakePtt());
      expect(ptt.held.value, isTrue);
    });
  });

  test('release says whether there was a key to drop', () {
    fakeAsync((async) {
      // Escape keeps its usual meaning in the logging fields when it had
      // nothing to stop.
      expect(ptt.release(), isFalse);
      expect(radio.sent, isEmpty);
      ptt.toggle(radio);
      expect(ptt.release(), isTrue);
      expect(radio.sent, [true, false]);
    });
  });
}
