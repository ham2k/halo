// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';

import 'package:ham2k_logger/services/extensions/bundle_storage.dart';

/// The installed-extension store's files in memory: a widget test's fake
/// clock never completes real file IO.
class MemoryBundleStorage implements BundleStorage {
  final files = <String, Map<String, List<int>>>{};

  @override
  Future<Map<String, String?>> manifests() async => {
    for (final MapEntry(:key, :value) in files.entries) key: value['manifest.json'] == null ? null : utf8.decode(value['manifest.json']!),
  };

  @override
  Future<String?> readText(String key, String name) async => files[key]?[name] == null ? null : utf8.decode(files[key]![name]!);

  @override
  Future<void> write(String key, Map<String, List<int>> files) async => this.files[key] = files;

  @override
  Future<void> remove(String key) async => files.remove(key);
}
