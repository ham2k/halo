// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Reading a downloaded `sqlite` data file (halo_core's sqlite_data_file.dart)
// with the platform's SQLite: natively the library linked into the app, on a
// background isolate, since SCP.DB's 69,000 rows and the lookup rows made of
// them take a noticeable fraction of a second the UI would otherwise stop
// for; on web a wasm instance of its own beside drift's, which runs in a
// worker and answers only drift, read in stretches between frames.

export 'sqlite3_loader_io.dart' if (dart.library.js_interop) 'sqlite3_loader_web.dart';
