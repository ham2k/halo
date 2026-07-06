// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Owns the app's single PluginHost instance (background isolate) and exposes
// domain-shaped calls on top of raw hook invocations. Boots asynchronously at
// app start; every caller must tolerate `ready == false` — a missing or
// broken plugin runtime degrades features, never the core loop.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:polo_plugin_host/polo_plugin_host.dart';

class PluginService {
  PluginHost? _host;
  Future<void>? _starting;

  bool get ready => _host != null;
  PluginHost? get host => _host;

  Future<void> start() {
    return _starting ??= _start();
  }

  Future<void> _start() async {
    try {
      final index = jsonDecode(await rootBundle.loadString('assets/plugins/index.json')) as Map<String, dynamic>;
      final kernelSource = await rootBundle.loadString('assets/plugins/${index['kernel']}');
      final plugins = <PluginBundle>[];
      for (final entry in (index['plugins'] as List).cast<Map<String, dynamic>>()) {
        plugins.add(PluginBundle(
          key: entry['key'] as String,
          source: await rootBundle.loadString('assets/plugins/${entry['file']}'),
        ));
      }
      _host = await PluginHost.start(kernelSource: kernelSource, plugins: plugins);
      _host!.logs.listen((line) => debugPrint('[plugins] $line'));
      for (final line in _host!.logLines) {
        debugPrint('[plugins] $line');
      }
    } catch (e) {
      debugPrint('[plugins] failed to start plugin runtime: $e');
    }
  }

  /// Calls every registered lookup source and merges the results in priority
  /// order: the first source to provide a field wins. Returns null when no
  /// source had anything useful (or the runtime isn't up).
  Future<Map<String, dynamic>?> lookupCall(String call) async {
    final host = _host;
    if (host == null || call.length < 3) return null;

    final List<Map<String, dynamic>> entries;
    try {
      entries = await host.invokeHookAll(
        'lookup',
        method: 'lookupCall',
        args: {'callInfo': {'call': call}},
        timeout: const Duration(seconds: 5),
      );
    } on PluginHostException catch (e) {
      debugPrint('[plugins] lookup failed: $e');
      return null;
    }

    const mergeFields = ['name', 'city', 'state', 'country', 'grid', 'lat', 'lon', 'image'];
    final merged = <String, dynamic>{};
    final sources = <String>[];

    for (final entry in entries) {
      if (entry['ok'] != true) continue;
      final value = entry['value'];
      if (value is! Map) continue;
      if ((value['error'] as String?)?.isNotEmpty ?? false) continue;

      var contributed = false;
      for (final field in mergeFields) {
        final fieldValue = value[field];
        if (fieldValue == null || (fieldValue is String && fieldValue.isEmpty)) continue;
        if (merged[field] == null) {
          merged[field] = fieldValue;
          contributed = true;
        }
      }
      if (contributed) sources.add((value['source'] as String?) ?? (entry['key'] as String));
    }

    if (merged.isEmpty) return null;
    merged['sources'] = sources;
    return merged;
  }

  /// Descriptors for controls activities want on the logging panel.
  Future<List<Map<String, dynamic>>> loggingControls(Map<String, dynamic> operationData) =>
      _collectControls('loggingControls', operationData);

  /// Descriptors for controls activities want in operation settings.
  Future<List<Map<String, dynamic>>> operationControls(Map<String, dynamic> operationData) =>
      _collectControls('operationControls', operationData);

  Future<List<Map<String, dynamic>>> _collectControls(String method, Map<String, dynamic> operationData) async {
    final host = _host;
    if (host == null) return const [];
    try {
      final entries = await host.invokeHookAll('activity', method: method, args: {'operation': operationData});
      final controls = <Map<String, dynamic>>[];
      for (final entry in entries) {
        if (entry['ok'] != true || entry['value'] is! List) continue;
        controls.addAll((entry['value'] as List).cast<Map>().map((c) => c.cast<String, dynamic>()));
      }
      controls.sort((a, b) => ((a['order'] as num?) ?? 0).compareTo((b['order'] as num?) ?? 0));
      return controls;
    } on PluginHostException catch (e) {
      debugPrint('[plugins] $method failed: $e');
      return const [];
    }
  }

  /// Decorates a ref (park name, location…) via its `ref:<type>` handler.
  /// Returns the input unchanged if no handler answers.
  Future<Map<String, dynamic>> decorateRef(Map<String, dynamic> ref) async {
    final host = _host;
    final type = ref['type'] as String?;
    if (host == null || type == null) return ref;
    try {
      final decorated = await host.invokeHook('ref:$type', method: 'decorateRef', args: {'ref': ref});
      if (decorated is Map) return decorated.cast<String, dynamic>();
    } on PluginHostException catch (e) {
      debugPrint('[plugins] decorateRef failed: $e');
    }
    return ref;
  }
}
