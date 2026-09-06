// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The web half: a tab has no isolate with its own thread and no process to
// end, and neither of the calls the watchdog exists for — the serial open and
// close — is synchronous FFI there. Declining is the whole implementation.

Future<void Function(Object message)?> spawnWatchdog({
  required Duration silence,
  required Duration grace,
  required int exitCode,
}) async =>
    null;
