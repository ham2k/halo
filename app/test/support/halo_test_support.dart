// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one import a widget or service test needs before its first expect:
// the service graph (`makeHaLoServices` / `pumpHaLo`), the fake extension
// host and the small fakes that stand in for platform plugins. Heavier
// fakes with a subject of their own — the peer transports, the connected
// CAT radio — are imported from this directory by name.

export 'error_reporting_fakes.dart';
export 'fake_extension_host.dart';
export 'fake_panel_extensions.dart';
export 'fake_secure_storage.dart';
export 'halo_harness.dart';
export 'map_tile_cache.dart';
export 'no_outline_grid.dart';
export 'shipped_extensions.dart';
