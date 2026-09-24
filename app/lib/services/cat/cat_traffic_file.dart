// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Where DEVLOGCAT writes. The web build has no file system to leave a log
// in, so it records nothing.

export 'cat_traffic_file_web.dart' if (dart.library.io) 'cat_traffic_file_io.dart';
