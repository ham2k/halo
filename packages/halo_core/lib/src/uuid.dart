// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:uuid/uuid.dart';

/// The one UUID generator for the app and its packages: record ids, device
/// keys, export groups, name-based claim ids. Use it instead of constructing
/// a `Uuid` at the call site.
const uuidGenerator = Uuid();
