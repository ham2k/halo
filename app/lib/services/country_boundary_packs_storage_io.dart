// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;

import 'app_storage.dart';
import 'country_boundary_packs_storage.dart';

CountryBoundaryPackStorage createCountryBoundaryPackStorage() => FileCountryBoundaryPackStorage();

class FileCountryBoundaryPackStorage implements CountryBoundaryPackStorage {
  FileCountryBoundaryPackStorage({this._root});

  final Directory? _root;

  Future<File> _file(String country) async {
    final directory = _root ?? Directory(p.join((await appDataDirectory()).path, 'country-boundary-packs'));
    return File(p.join(directory.path, '$country.pack'));
  }

  @override
  Future<Uint8List?> read(String country) async {
    try {
      return await (await _file(country)).readAsBytes();
    } on PathNotFoundException {
      return null;
    }
  }

  @override
  Future<void> replace(String country, Uint8List bytes) async {
    final file = await _file(country);
    await file.parent.create(recursive: true);
    // A unique staging directory keeps simultaneous app instances from
    // writing the same temporary file. Rename stays on the same filesystem.
    final staging = await file.parent.createTemp('.boundary-pack-');
    try {
      final payload = File(p.join(staging.path, 'pack'));
      await payload.writeAsBytes(bytes, flush: true);
      await payload.rename(file.path);
    } finally {
      try {
        await staging.delete(recursive: true);
      } on FileSystemException catch (error) {
        debugPrint('[boundary packs] could not clean staging directory: $error');
      }
    }
  }

  @override
  Future<void> remove(String country) async {
    try {
      await (await _file(country)).delete();
    } on PathNotFoundException {
      // The cache entry is already gone.
    }
  }
}
