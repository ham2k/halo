// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Asks the browser to mark this origin's storage persistent, so the log
/// can't be evicted under storage pressure (or by Safari's script-writable
/// -storage expiry). Without the grant, every byte of the web log is
/// best-effort: the browser may silently wipe OPFS/IndexedDB wholesale.
///
/// Returns whether the grant is held after asking, or null when the API
/// itself is unavailable (insecure context, very old browser). A false is
/// normal on browsers that gate the grant behind engagement heuristics —
/// asking again on a later boot is free, so the caller just calls this
/// every time.
Future<bool?> requestPersistentWebStorage() async {
  try {
    final storage = web.window.navigator.storage;
    if ((await storage.persisted().toDart).toDart) return true;
    return (await storage.persist().toDart).toDart;
  } catch (_) {
    return null;
  }
}
