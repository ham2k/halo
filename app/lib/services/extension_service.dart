// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Owns the app's single ExtensionHost instance (background isolate) and exposes
// domain-shaped calls on top of raw hook invocations. Boots asynchronously at
// app start; every caller must tolerate `ready == false` — a missing or
// broken extension runtime degrades features, never the core loop.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:halo_core/halo_core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'settings_service.dart';
import 'status_bar_service.dart';
import 'package:halo_widgets/halo_widgets.dart';
import '../main.dart';

/// The QSON payload shape shared by every hook that takes a whole operation's
/// worth of QSOs in one coarse call (export, scoring, …) — `operation.data`
/// with `uuid` folded in, plus each QSO's raw QSON `data`.
Map<String, dynamic> qsonPayloadFor({required Operation operation, required List<Qso> qsos}) => {
      'operation': {...operation.data, 'uuid': operation.uuid},
      'qsos': [for (final qso in qsos) qso.data],
    };

class ExtensionService {
  ExtensionHost? _host;
  Future<void>? _starting;
  final _secureStorage = const FlutterSecureStorage(
    mOptions: MacOsOptions(
      usesDataProtectionKeychain: false,
      accountName: 'Ham2K Logger',
    ),
    iOptions: IOSOptions(
      accountName: 'Ham2K Logger',
    ),
  );

  SettingsService? settings;
  LookupRepository? lookups;
  StatusBarService? statusBar;

  bool get ready => _host != null;
  ExtensionHost? get host => _host;

  Future<void> start() {
    return _starting ??= _start();
  }

  Future<List<Map<String, dynamic>>> getAccounts() async {
    final host = _host;
    if (host == null) return const [];
    try {
      final entries = await host.invokeHookAll('account', method: 'getDefinition', timeout: const Duration(seconds: 2));
      final accounts = <Map<String, dynamic>>[];
      for (final entry in entries) {
        if (entry['ok'] == true && entry['value'] is Map) {
          accounts.add((entry['value'] as Map).cast<String, dynamic>());
        }
      }
      return accounts;
    } catch (e) {
      debugPrint('[extensions] getAccounts failed: $e');
      return const [];
    }
  }

  Future<String> testCredentials(String accountKey, Map<String, String> credentials) async {
    final host = _host;
    if (host == null) return 'Extension runtime not ready.';
    try {
      final dynamic res = await host.invokeHook(
        'account',
        key: accountKey,
        method: 'testCredentials',
        args: credentials,
        timeout: const Duration(seconds: 10),
      );
      return res is String ? res : res?.toString() ?? '';
    } catch (e) {
      return 'Test failed: $e';
    }
  }

  Future<Map<String, String>> getAccountCredentials(String kvKey) async {
    final raw = await _secureStorage.read(key: 'account_creds_$kvKey');
    if (raw == null) return const {};
    try {
      return (jsonDecode(raw) as Map).cast<String, String>();
    } catch (_) {
      return const {};
    }
  }

  Future<void> setAccountCredentials(String kvKey, Map<String, String> credentials) async {
    await _secureStorage.write(key: 'account_creds_$kvKey', value: jsonEncode(credentials));
  }

  Future<void> clearAccount(String kvKey) async {
    await _secureStorage.delete(key: 'account_creds_$kvKey');
    await _secureStorage.delete(key: 'account_session_$kvKey');
  }

  /// Seeds the `ham2k-lofi` sync extension's device identity (a stable
  /// per-install key, generated once by `SettingsService.syncDeviceKey`) and
  /// operator callsign. Called both at boot and whenever Settings saves a
  /// new operator callsign. There's
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
      _host = await ExtensionHost.start(
        kernelSource: kernelSource,
        extensions: bundles,
        onHostCall: _handleHostCall,
      );
      _host!.logs.listen((line) => debugPrint('[extensions] $line'));
      for (final line in _host!.logLines) {
        debugPrint('[extensions] $line');
      }
    } catch (e) {
      debugPrint('[extensions] failed to start extension runtime: $e');
    }
  }

  Future<dynamic> _handleHostCall(String method, Map<String, dynamic> params) async {
    switch (method) {
      case 'getAccount':
        final kvKey = params['kvKey'] as String;
        final credsStr = await _secureStorage.read(key: 'account_creds_$kvKey');
        final sessionStr = await _secureStorage.read(key: 'account_session_$kvKey');
        return {
          'credentials': credsStr != null ? jsonDecode(credsStr) : const {},
          'session': sessionStr != null ? jsonDecode(sessionStr) : const {},
        };
      case 'setAccountSession':
        final kvKey = params['kvKey'] as String;
        final session = params['session'] as Map<dynamic, dynamic>;
        await _secureStorage.write(key: 'account_session_$kvKey', value: jsonEncode(session));
        return null;
      case 'getSettings':
        return {
          'developerMode': settings?.developerMode ?? false,
          'locale': settings?.locale ?? 'en',
        };
      case 'dbLookupSelectOne':
        final category = params['category'] as String;
        final key = params['key'] as String;
        final row = await lookups?.getLookup(category, key);
        return row == null
            ? null
            : {
                'category': row.category,
                'subCategory': row.subCategory,
                'key': row.key,
                'name': row.name,
                'data': row.data != null ? jsonDecode(row.data!) : null,
                'lat': row.lat,
                'lon': row.lon,
                'flags': row.flags,
              };
      case 'dbLookupSelectAll':
        final category = params['category'] as String;
        final query = params['query'] as String;
        final list = await lookups?.queryLookups(category, query) ?? const [];
        return list
            .map((row) => {
                  'category': row.category,
                  'subCategory': row.subCategory,
                  'key': row.key,
                  'name': row.name,
                  'data': row.data != null ? jsonDecode(row.data!) : null,
                  'lat': row.lat,
                  'lon': row.lon,
                  'flags': row.flags,
                })
            .toList();
      case 'dbLookupSelectByLocation':
        final category = params['category'] as String;
        final lat = (params['lat'] as num).toDouble();
        final lon = (params['lon'] as num).toDouble();
        final delta = (params['delta'] as num).toDouble();
        final list = await lookups?.queryLookupsByLocation(category, lat, lon, delta) ?? const [];
        return list
            .map((row) => {
                  'category': row.category,
                  'subCategory': row.subCategory,
                  'key': row.key,
                  'name': row.name,
                  'data': row.data != null ? jsonDecode(row.data!) : null,
                  'lat': row.lat,
                  'lon': row.lon,
                  'flags': row.flags,
                })
            .toList();
      case 'showForm':
        final formId = params['formId'] as String;
        final formDef = (params['form'] as Map).cast<String, dynamic>();
        final state = (params['state'] as Map? ?? const {}).cast<String, dynamic>();

        final context = navigatorKey.currentContext;
        if (context == null) {
          throw StateError('No active navigation context found');
        }

        final result = await showFormDialog(
          context,
          formDefinition: formDef,
          initialState: state,
          validator: (fieldKey, value, currentState) async {
            try {
              final res = await _host?.invokeHook(
                'form',
                key: formId,
                method: 'validateField',
                args: {
                  'formId': formId,
                  'fieldKey': fieldKey,
                  'value': value,
                  'state': currentState,
                },
              );
              return res as String?;
            } catch (e) {
              return 'Validation error: $e';
            }
          },
          transformer: (fieldKey, value, currentState) async {
            try {
              final res = await _host?.invokeHook(
                'form',
                key: formId,
                method: 'transformField',
                args: {
                  'formId': formId,
                  'fieldKey': fieldKey,
                  'value': value,
                  'state': currentState,
                },
              );
              return res;
            } catch (_) {
              return value;
            }
          },
          onChange: (fieldKey, value, currentState) async {
            try {
              final res = await _host?.invokeHook(
                'form',
                key: formId,
                method: 'onChangeField',
                args: {
                  'formId': formId,
                  'fieldKey': fieldKey,
                  'value': value,
                  'state': currentState,
                },
              );
              if (res is Map) {
                return res.cast<String, dynamic>();
              }
              return null;
            } catch (_) {
              return null;
            }
          },
        );
        return result;
      case 'statusBarSetMessage':
        statusBar?.setMessage(
          key: _namespacedKey(params),
          icon: params['icon'] as String?,
          title: params['title'] as String?,
          text: params['text'] as String?,
        );
        return null;
      case 'statusBarSetProgress':
        statusBar?.setProgress(
          key: _namespacedKey(params),
          icon: params['icon'] as String?,
          title: params['title'] as String?,
          text: params['text'] as String?,
          value: (params['value'] as num?)?.toDouble(),
        );
        return null;
      case 'statusBarClear':
        statusBar?.clear(_namespacedKey(params));
        return null;
      case 'statusBarShowNotice':
        statusBar?.showNotice(
          key: _namespacedKey(params),
          icon: params['icon'] as String?,
          title: params['title'] as String?,
          text: params['text'] as String? ?? '',
          actions: _noticeActionsFromJson(params['actions'], _namespacedKey(params)),
        );
        return null;
      case 'statusBarDismissNotice':
        statusBar?.dismissNotice(_namespacedKey(params));
        return null;
      default:
        throw UnimplementedError('Host call method $method not implemented');
    }
  }

  /// Extension-supplied keys are prefixed with the calling extension's key so
  /// one extension's status bar items/notices can never collide with — or be
  /// cleared/dismissed by — another's. Same `ns` convention as `kvGet`/`kvSet`.
  String _namespacedKey(Map<String, dynamic> params) {
    final ns = params['ns'] as String;
    final key = params['key'] as String;
    return '$ns:$key';
  }

  /// Notice actions from extensions are declarative JSON, not callbacks back
  /// into the extension (matches the `activity` hook's "describe UI as data"
  /// convention) — `link` opens a URL, `dialog` shows a markdown dialog.
  List<StatusBarAction> _noticeActionsFromJson(dynamic raw, String noticeKey) {
    if (raw is! List) return const [];
    final actions = <StatusBarAction>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final map = entry.cast<String, dynamic>();
      final label = map['label'] as String?;
      final type = map['type'] as String?;
      if (label == null || type == null) continue;
      switch (type) {
        case 'link':
          final url = map['url'] as String?;
          if (url == null) continue;
          actions.add(StatusBarAction(
            label: label,
            onTap: () => launchUrl(Uri.parse(url)),
          ));
        case 'dialog':
          final text = map['text'] as String? ?? '';
          final title = map['title'] as String?;
          actions.add(StatusBarAction(
            label: label,
            onTap: () {
              final context = navigatorKey.currentContext;
              if (context == null) return;
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: title != null ? Text(title) : null,
                  content: SingleChildScrollView(child: MarkdownBody(data: text)),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
                  ],
                ),
              );
            },
          ));
      }
    }
    return actions;
  }

  /// Runs the full lookup pipeline for one callsign — the hardcoded
  /// callsign-annotation pre-step plus every registered `lookup` hook
  /// (QRZ, HamDB, POTA, SOTA…), merged with locationScope-aware rules —
  /// entirely inside the JS runtime via the single `lookupService/core`
  /// hook (mirrors `ScoringService`'s "one coarse call in, everything back
  /// out" shape). `online: false` asks every hook to skip network access
  /// (for a fast local-data-only preview pass); `qso`/`operation` give
  /// QSO-scoped hooks (e.g. POTA) access to refs already on the in-progress
  /// QSO. Returns `{lookups: [...], guess: {...}}`, or null if the runtime
  /// isn't up or nothing came back.
  Future<Map<String, dynamic>?> lookupCall(
    String call, {
    required Map<String, dynamic> qso,
    required Map<String, dynamic> operation,
    bool online = true,
  }) async {
    final host = _host;
    if (host == null || call.length < 3) return null;

    try {
      final result = await host.invokeHook(
        'lookupService',
        key: 'core',
        method: 'lookupCallInfo',
        args: {
          'callInfo': {'call': call},
          'qso': qso,
          'operation': operation,
          'online': online,
        },
        timeout: const Duration(seconds: 8),
      );
      if (result is! Map) return null;
      return result.cast<String, dynamic>();
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] lookup failed: $e');
      return null;
    }
  }

  /// Asks every registered `command` hook (priority order) to interpret the input command.
  /// Returns the first non-null interpretation result: `{describe, confirm, commands}`.
  /// Returns null when nothing matched, the input is empty, or the runtime isn't up.
  Future<Map<String, dynamic>?> interpretCommand(
    String input, [
    Map<String, dynamic>? operation,
    Map<String, dynamic>? qso,
  ]) async {
    final host = _host;
    if (host == null || input.isEmpty) return null;
    try {
      final entries = await host.invokeHookAll(
        'command',
        method: 'interpret',
        args: {
          'input': input,
          'operation': ?operation,
          'qso': ?qso,
        },
        timeout: const Duration(seconds: 2),
      );
      for (final entry in entries) {
        if (entry['ok'] == true && entry['value'] is Map) {
          return (entry['value'] as Map).cast<String, dynamic>();
        }
      }
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] interpretCommand failed: $e');
    }
    return null;
  }

  /// Descriptors for controls activities want on the logging panel. `qso` is
  /// the in-progress QSO (including any `their.guess` from the callsign
  /// lookup pipeline) — pass it so an extension can key a QSO-scoped
  /// `placeholder`/`transforms` (e.g. a DXCC-derived reference prefix) off
  /// it; omit for a QSO-agnostic refresh (e.g. right after the operation loads).
  Future<List<Map<String, dynamic>>> loggingControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) =>
      _collectControls('loggingControls', operationData, qso: qso);

  /// Descriptors for controls activities want in operation settings.
  Future<List<Map<String, dynamic>>> operationControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) =>
      _collectControls('operationControls', operationData, qso: qso);

  Future<List<Map<String, dynamic>>> _collectControls(
    String method,
    Map<String, dynamic> operationData, {
    Map<String, dynamic>? qso,
  }) async {
    final host = _host;
    if (host == null) return const [];
    try {
      final entries = await host.invokeHookAll(
        'activity',
        method: method,
        args: {'operation': operationData, 'qso': ?qso},
      );
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

  /// Candidate activities for the "add activity" search, merged across every
  /// `activity` hook and sorted by `distance / relevance` ascending — a more
  /// relevant hit (relevance is 0..1, higher is better) effectively counts
  /// as closer, so it doesn't lose out to a less relevant but nearer one
  /// (results missing a distance sort after ranked ones — an extension
  /// search hit with no location still surfaces). `location` comes from the operation's
  /// own grid if it has one, otherwise [fallbackLocation] (typically the
  /// device's current GPS position — see ActivitiesView) so nearby
  /// suggestions still work before the operation's location is set.
  /// `callsign` falls back from the operation's own settings to the
  /// operator's global default.
  Future<List<Map<String, dynamic>>> suggestActivities(
    Map<String, dynamic> operationData, {
    String? searchTerm,
    GridLocation? fallbackLocation,
  }) async {
    final host = _host;
    if (host == null) return const [];

    final grid = operationData['grid'] as String?;
    final gridLocation = gridToLocation(grid) ?? fallbackLocation;
    final callsign = (operationData['stationCall'] as String?)?.isNotEmpty == true
        ? operationData['stationCall'] as String
        : settings?.operatorCall;

    try {
      final entries = await host.invokeHookAll(
        'activity',
        method: 'suggest',
        args: {
          'operation': operationData,
          if (gridLocation != null) 'location': {'lat': gridLocation.latitude, 'lon': gridLocation.longitude},
          if (callsign != null && callsign.isNotEmpty) 'callsign': callsign,
          if (searchTerm != null && searchTerm.isNotEmpty) 'searchTerm': searchTerm,
        },
        timeout: const Duration(seconds: 5),
      );

      final suggestions = <Map<String, dynamic>>[];
      for (final entry in entries) {
        if (entry['ok'] != true || entry['value'] is! List) continue;
        suggestions.addAll((entry['value'] as List).cast<Map>().map((s) => s.cast<String, dynamic>()));
      }

      double rank(Map<String, dynamic> s) {
        final distance = s['distance'] as num?;
        final relevance = s['relevance'] as num?;
        if (distance == null || relevance == null || relevance <= 0) return double.infinity;
        return (distance / relevance).toDouble();
      }

      suggestions.sort((a, b) => rank(a).compareTo(rank(b)));
      return suggestions;
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] suggestActivities failed: $e');
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
