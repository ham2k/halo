// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Owns the app's single ExtensionHost instance (background isolate) and exposes
// domain-shaped calls on top of raw hook invocations. Boots asynchronously at
// app start; every caller must tolerate `ready == false` — a missing or
// broken extension runtime degrades features, never the core loop.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:polo_extension_host/polo_extension_host.dart';

class ExtensionService {
  ExtensionHost? _host;
  Future<void>? _starting;

  bool get ready => _host != null;
  ExtensionHost? get host => _host;

  Future<void> start() {
    return _starting ??= _start();
  }

  /// Seeds the QRZ extension's credentials into the host's KV store. Safe to
  /// call before the runtime is up (awaits start()) or with blank values
  /// (clears them) — called both at boot, from whatever SettingsService
  /// loaded last session, and whenever Settings saves new credentials.
  Future<void> setQrzCredentials({required String username, required String password}) async {
    await start();
    _host?.setKV('qrz', 'username', username);
    _host?.setKV('qrz', 'password', password);
  }

  /// Seeds the `ham2k-lofi` sync extension's device identity (a stable
  /// per-install key, generated once by `SettingsService.syncDeviceKey`) and
  /// operator callsign. Called both at boot and whenever Settings saves a
  /// new operator callsign — same shape as `setQrzCredentials`. There's
  /// deliberately no `token` seeded here: the extension re-registers with
  /// the server on first use each run (the token is session-scoped, kept in
  /// the extension's own module state, same as app-polo's `GLOBAL.syncLoFiToken`
  /// being memory-only there too).
  Future<void> setSyncCredentials({required String deviceKey, required String operatorCall}) async {
    await start();
    _host?.setKV('ham2k-lofi', 'key', deviceKey);
    _host?.setKV('ham2k-lofi', 'call', operatorCall);
  }

  Future<void> _start() async {
    try {
      final index = jsonDecode(await rootBundle.loadString('assets/extensions/index.json')) as Map<String, dynamic>;
      final kernelSource = await rootBundle.loadString('assets/extensions/${index['kernel']}');
      final bundles = <ExtensionBundle>[];
      for (final entry in (index['extensions'] as List).cast<Map<String, dynamic>>()) {
        bundles.add(ExtensionBundle(
          key: entry['key'] as String,
          source: await rootBundle.loadString('assets/extensions/${entry['file']}'),
        ));
      }
      _host = await ExtensionHost.start(kernelSource: kernelSource, extensions: bundles);
      _host!.logs.listen((line) => debugPrint('[extensions] $line'));
      for (final line in _host!.logLines) {
        debugPrint('[extensions] $line');
      }
    } catch (e) {
      debugPrint('[extensions] failed to start extension runtime: $e');
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
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] lookup failed: $e');
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

  /// Tries every registered `command` hook (priority order) against `input`
  /// and returns the first non-null field-change result: `{freq?, band?,
  /// mode?}`. Returns null when nothing matched, the input is empty, or the
  /// runtime isn't up — callers should treat that as "not a command".
  Future<Map<String, dynamic>?> tryCommand(String input) async {
    final host = _host;
    if (host == null || input.isEmpty) return null;
    try {
      final entries = await host.invokeHookAll(
        'command',
        method: 'tryCommand',
        args: {'input': input},
        timeout: const Duration(seconds: 2),
      );
      for (final entry in entries) {
        if (entry['ok'] == true && entry['value'] is Map) {
          return (entry['value'] as Map).cast<String, dynamic>();
        }
      }
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] tryCommand failed: $e');
    }
    return null;
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
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] $method failed: $e');
      return const [];
    }
  }

  /// The current LoFi account/device/client info, for display in Settings.
  /// Returns null if the runtime isn't up or the request failed (e.g. no
  /// network) — callers should treat that as "status unknown", not "no sync".
  Future<Map<String, dynamic>?> syncAccountData() async {
    final host = _host;
    if (host == null) return null;
    try {
      final result = await host.invokeHook('syncTransport', method: 'getAccountData', args: const {});
      return result is Map ? result.cast<String, dynamic>() : null;
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] syncAccountData failed: $e');
      return null;
    }
  }

  /// Requests a link-by-email challenge from the sync server. Returns null
  /// on failure; callers should surface that as "couldn't reach the server".
  Future<Map<String, dynamic>?> syncLinkClientWithEmail(String email) async {
    final host = _host;
    if (host == null) return null;
    try {
      final result = await host.invokeHook('syncTransport', method: 'linkClientWithEmail', args: {'email': email});
      return result is Map ? result.cast<String, dynamic>() : null;
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] syncLinkClientWithEmail failed: $e');
      return null;
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
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] decorateRef failed: $e');
    }
    return ref;
  }
}
