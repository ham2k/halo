// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'country_boundary_packs_storage.dart';
import 'extensions/bundle_storage_web.dart' show IndexedDbBundleStorage;

CountryBoundaryPackStorage createCountryBoundaryPackStorage() => IndexedDbCountryBoundaryPackStorage();

/// Keeps the pack in a separate IndexedDB database, using the same atomic
/// record replacement as installed extension bundles.
class IndexedDbCountryBoundaryPackStorage implements CountryBoundaryPackStorage {
  IndexedDbCountryBoundaryPackStorage({String databaseName = 'halo-country-boundary-packs'}) : _storage = IndexedDbBundleStorage(databaseName: databaseName);

  static const _record = 'pack';
  final IndexedDbBundleStorage _storage;

  @override
  Future<Uint8List?> read(String country) async {
    final bytes = await _storage.readBytes(country, _record);
    return switch (bytes) {
      null => null,
      Uint8List() => bytes,
      _ => Uint8List.fromList(bytes),
    };
  }

  @override
  Future<void> replace(String country, Uint8List bytes) => _storage.write(country, {_record: bytes});

  @override
  Future<void> remove(String country) => _storage.remove(country);
}
