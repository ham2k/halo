// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

/// Native builds store the database in a real file the OS never evicts —
/// there is nothing to request.
Future<bool?> requestPersistentWebStorage() async => null;
