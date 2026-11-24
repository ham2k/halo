// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

export 'country_boundary_packs_storage_io.dart' if (dart.library.js_interop) 'country_boundary_packs_storage_web.dart' show createCountryBoundaryPackStorage;

/// One atomic record per country. The record owns the version and ZIP together.
abstract interface class CountryBoundaryPackStorage {
  Future<Uint8List?> read(String country);
  Future<void> replace(String country, Uint8List bytes);
  Future<void> remove(String country);
}
