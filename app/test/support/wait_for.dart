// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Waiting on work that is not a timer (docs/design/time.md §7).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Polls [condition] until it holds, for an outcome that real I/O — a socket,
/// a database, an isolate — delivers when it delivers. [timeout] guards
/// against a hang, not a deadline the code has to meet: a fixed sleep before
/// the check would be a bet on the machine instead.
Future<void> waitFor(String what, FutureOr<bool> Function() condition, {Duration timeout = const Duration(seconds: 20)}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('timed out waiting for: $what');
}
