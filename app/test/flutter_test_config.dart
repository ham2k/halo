// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Runs once per test file, before its `main`. An empty mock
// SharedPreferences store is the one thing every test file used to open
// with; a test that needs prefs of its own still sets them (and
// `makeHaLoServices` always does), since the mock store is shared by every
// test in the file.
//
// Deliberately NOT `TestWidgetsFlutterBinding.ensureInitialized()`: the test
// binding replaces `HttpClient` with one that answers 400 to everything, and
// the peer transport tests talk real sockets. A widget test file calls it in
// its own `main`, where it is meant.

import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SharedPreferences.setMockInitialValues({});
  await testMain();
}
