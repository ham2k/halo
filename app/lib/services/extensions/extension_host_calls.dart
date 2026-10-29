// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The reverse API: the calls the extension runtime makes back into the app
// (`host.*` in the SDK), answered against the service's own collaborators.
//
// What an extension may put on the app's own surfaces — its dialogs, through
// extension_dialog_gate.dart, and its footer, here — is budgeted the way the
// host budgets its calls (halo_extension_host's host_budgets.dart): refused at
// the call that would exceed it, with the budget named.

part of 'extension_service.dart';

class _ExtensionHostCalls {
  _ExtensionHostCalls(this._service);

  final ExtensionService _service;

  Future<dynamic> handle(String method, Map<String, dynamic> params) async {
    if (RadioHostCalls.handles(method)) return _service.radioCalls.handle(method, params);
    if (ClusterHostCalls.handles(method)) return _service.clusterCalls.handle(method, params);
    return switch (method) {
      'getAccount' => _getAccount(params),
      'setAccountSession' => _setAccountSession(params),
      'getSettings' => _getSettings(),
      'setSettings' => _setSettings(params),
      'searchSettings' => _searchSettings(params),
      'translate' => _translate(params),
      'translateAll' => _translateAll(params),
      'getOperation' => _getOperation(params),
      'getQsos' => _getQsos(params),
      'getQsoChanges' => _getQsoChanges(params),
      'getSpotsForCall' => _getSpotsForCall(params),
      'getSpots' => _getSpots(params),
      'suggestQso' => _suggestQso(params),
      'getHistoryForCall' => _getHistoryForCall(params),
      'dbLookupSelectOne' => _dbLookupSelectOne(params),
      'dbLookupSelectAll' => _dbLookupSelectAll(params),
      'dbLookupSelectByLocation' => _dbLookupSelectByLocation(params),
      'dbLookupSelectInBounds' => _dbLookupSelectInBounds(params),
      'getLocation' => _getLocation(params),
      'getVersionInfo' => _getVersionInfo(),
      'showForm' => _showForm(params),
      'showMessage' => _showMessage(params),
      'statusBarSetMessage' => _statusBarSetMessage(params),
      'statusBarSetProgress' => _statusBarSetProgress(params),
      'statusBarClear' => _statusBarClear(params),
      'statusBarShowNotice' => _statusBarShowNotice(params),
      'statusBarDismissNotice' => _statusBarDismissNotice(params),
      _ => throw UnimplementedError('Host call method $method not implemented'),
    };
  }

  /// The `kvKey` of an account call, refused unless it sits in the calling
  /// extension's own namespace ([accountKvKeyBelongsTo]). The kernel derives
  /// both from its own records; the host judges the pair again itself.
  String _ownAccountKvKey(String method, Map<String, dynamic> params) {
    final kvKey = params['kvKey'] as String?;
    final ns = params['ns'] as String?;
    if (ns == null || kvKey == null || !accountKvKeyBelongsTo(ns, kvKey)) {
      throw ExtensionHostException("$method blocked: extension '${ns ?? 'unknown'}' asked for account '${kvKey ?? 'none'}', outside its own namespace");
    }
    return kvKey;
  }

  Future<dynamic> _getAccount(Map<String, dynamic> params) async {
    final kvKey = _ownAccountKvKey('getAccount', params);
    final cached = _service._accountItems[kvKey];
    if (cached != null) return cached.toHostResult();
    // A read made through the deadlock bypass (below) used device-local
    // options, which may not be this account's — its answer must not
    // outlive the refresh that resolves the real flag.
    final provisional = _service._refreshingAccountSynchronizable;
    final o = await _service._accountKeychainOptions(kvKey, fromHostCall: true);
    // This is the path an extension actually uses at runtime, so it must
    // not lie: an unguarded throw here rejects the host call, the
    // kernel turns a rejection into `undefined` (sdk/src/kernel.ts), and the
    // extension reads that as a logged-out account — the same collapse
    // `getAccountCredentials` refuses to make. Saying `unavailable` instead
    // lets an extension tell "you are signed out" from "we could not look".
    try {
      final credsStr = await _service._secureStorage.read(key: 'account_creds_$kvKey', mOptions: o.mOptions, iOptions: o.iOptions);
      final sessionStr = await _service._secureStorage.read(key: 'account_session_$kvKey', mOptions: o.mOptions, iOptions: o.iOptions);
      final items = AccountItems(creds: credsStr, session: sessionStr);
      if (!provisional) _service._accountItems[kvKey] = items;
      return items.toHostResult();
    } catch (e, st) {
      debugPrint('[extensions] secure storage unavailable for host getAccount $kvKey: $e');
      ErrorReportingService.report(e, st, context: 'accounts:host-get-account');
      final failed = AccountItems.unreadable();
      if (!provisional) _service._accountItems[kvKey] = failed;
      return failed.toHostResult();
    }
  }

  Future<dynamic> _setAccountSession(Map<String, dynamic> params) async {
    final kvKey = _ownAccountKvKey('setAccountSession', params);
    final o = await _service._accountKeychainOptions(kvKey, fromHostCall: true);
    final session = params['session'] as Map<dynamic, dynamic>;
    final encoded = jsonEncode(session);
    await _service._secureStorage.write(key: 'account_session_$kvKey', value: encoded, mOptions: o.mOptions, iOptions: o.iOptions);
    final current = _service._accountItems.current(kvKey);
    if (current == null) return null;
    // The write went through, so a remembered failure no longer holds;
    // the next hook call rereads both items.
    if (current.unavailable) {
      _service._accountItems.remove(kvKey);
    } else {
      _service._accountItems[kvKey] = AccountItems(creds: current.creds, session: encoded);
    }
    return null;
  }

  Future<dynamic> _getSettings() async {
    // The full read view of the app's settings — resolved typed values
    // with defaults applied, so extensions never re-derive fallbacks.
    // Deliberately absent: credentials and accounts (those live in the
    // platform keychain via the account hook system, never in
    // SettingsService) and device identifiers.
    return {
      'developerMode': _service.settings?.developerMode ?? false,
      // So DEVMAPINFO can say which way it is about to flip it.
      'devMapInfo': _service.settings?.devMapInfo ?? false,
      // And DEVIDLE, Show idle metrics.
      'showIdleMetrics': _service.settings?.showIdleMetrics ?? false,
      // The language the app speaks, not the setting: never "system".
      'locale': resolveLocaleSetting(_service.settings?.locale ?? 'en').languageTag,
      // Lets a hook whose effect must stay invisible until its own
      // experiment ships ungated check per-call, rather than hiding at
      // the whole-extension `manifest.experiments` grain (which would
      // also gate every other hook the same extension registers).
      'enabledExperiments': [
        for (final entry in (_service.settings?.experimentStates ?? const {}).entries)
          if (entry.value is Map && (entry.value as Map)['enabled'] == true) entry.key,
      ],
      // The catalog itself, so a hook can resolve a typed key-or-alias
      // to one of those keys (the EXP preview says "Enable"/"Disable"
      // rather than "Toggle"). Private entries included: EXP accepts them.
      'experiments': [
        for (final experiment in await loadExperiments()) {'key': experiment.key, 'name': experiment.name, 'aliases': experiment.aliases},
      ],
      // Machine-facing: extensions put this in ADIF PROGRAMID, a spot's
      // source, etc. — so the fixed, platform-agnostic "Ham2K Logger", not
      // the UI's platform-tailored name.
      'appName': ham2kMachineName,
      // 'dev' | 'next' | 'prod' — for a hook whose static config must
      // vary per build edition (e.g. SOTA's OAuth client).
      'edition': kEdition.name,
      'themeMode': _service.settings?.themeMode.name ?? 'system',
      'fontScale': _service.settings?.fontScale.name ?? 'normal',
      'distanceUnits': _service.settings?.distanceUnits.name ?? 'kilometers',
      // The device's resolved characters, for ordinary numbers — not
      // frequencies, which are always written with periods. Read from the
      // same singleton every Dart number field reads, so a hook and the
      // field beside it cannot disagree.
      'decimalSeparator': NumberFormatting.instance.decimalSeparator,
      'groupingSeparator': NumberFormatting.instance.groupingSeparator,
      // The device's region, not the app's language: English on a British
      // device writes 18/3.
      'dateOrder': dateOrderFor(),
      // Resolved the same way, and for the same reason: a hook writing a
      // locator needs a number of characters, and "six" is not one.
      'gridPrecision': GridPrecision.current.digits,
      'syncEnabled': _service.settings?.syncEnabled ?? false,
      'operatorCall': _service.settings?.activeProfile.operatorCall ?? '',
      // The rest of the active profile — personal details a log generator
      // may need for a submission (Cabrillo headers, Field Day's section).
      // All optional and all free-form; an extension must cope with ''.
      'operatorName': _service.settings?.activeProfile.operatorName ?? '',
      'operatorEmail': _service.settings?.activeProfile.operatorEmail ?? '',
      'operatorClub': _service.settings?.activeProfile.operatorClub ?? '',
      'operatorSection': _service.settings?.activeProfile.operatorSection ?? '',
      'leftieMode': _service.settings?.leftieMode ?? false,
      'dxFlags': _service.settings?.dxFlags.name ?? 'dx',
      'showBearing': _service.settings?.showBearing ?? false,
      'switchSentRcvd': _service.settings?.switchSentRcvd ?? false,
      'jumpAfterRST': _service.settings?.jumpAfterRST ?? false,
      'defaultReport': _service.settings?.defaultReport ?? '',
      'defaultReportCW': _service.settings?.defaultReportCW ?? '',
      'defaultReportFT8': _service.settings?.defaultReportFT8 ?? '',
      'bands': _service.settings?.enabledBands ?? SettingsService.defaultBands,
      'modes': _service.settings?.enabledModes ?? SettingsService.defaultModes,
      'showRSTFields': _service.settings?.showRSTFields ?? true,
      'showStateField': _service.settings?.showStateField ?? false,
      'showGridField': _service.settings?.showGridField ?? false,
      'showDeletedQSOs': _service.settings?.showDeletedQSOs ?? false,
      'showQsoNumbers': _service.settings?.showQsoNumbers ?? true,
      'consentAppData': _service.settings?.consentAppData ?? false,
      'consentOpData': _service.settings?.consentOpData ?? false,
      // Extension-owned groups, raw — every extension can read every
      // group (settings are not secrets); writes are another matter.
      'extensions': _service.settings?.extensionSettingsGroups() ?? const {},
    };
  }

  Future<dynamic> _setSettings(Map<String, dynamic> params) async {
    // Writes are namespaced to the calling extension's own group
    // (`extension_<ns>`), enforced here by the SDK-injected ns — an
    // extension can never write core settings or another extension's.
    final ns = params['ns'] as String?;
    final values = params['values'];
    if (ns == null || ns.isEmpty || values is! Map) {
      debugPrint('[extensions] setSettings: missing ns or values — ignored');
      return null;
    }
    await _service.settings?.updateSettingsGroup('extension_$ns', values.cast<String, dynamic>());
    return null;
  }

  Future<dynamic> _searchSettings(Map<String, dynamic> params) async {
    // SET/SHOW/HIDE, resolved app-side: the settings catalog, the current
    // values, the option lists and the commit routing all live here, so
    // the command hook asks rather than carrying its own copy (which is
    // exactly what goes stale in app-polo's hand-listed version).
    //
    // This re-enters the extension runtime to read every settingsPanel
    // while the calling command hook is still awaiting us. Safe: hook
    // calls are keyed by id with independent completers and no lock (see
    // halo_extension_host.dart's `_send`), so the nested call settles
    // while the outer one waits.
    final search = _service.onSearchSettings;
    if (search == null) return {'found': false};
    return search(params['args'] as String? ?? '', params['kind'] as String?);
  }

  Future<dynamic> _translate(Map<String, dynamic> params) async {
    final key = params['key'] as String;
    final value = t[key];
    return value is String ? value : null;
  }

  Future<dynamic> _translateAll(Map<String, dynamic> params) async {
    final keys = (params['keys'] as List).cast<String>();
    return {for (final key in keys) key: (t[key] is String ? t[key] : null)};
  }

  Future<dynamic> _getOperation(Map<String, dynamic> params) async {
    final uuid = params['uuid'] as String;
    final operation = await _service.operations?.get(uuid);
    // Same shape as qsonPayloadFor's `operation`: the QSON with `uuid`
    // folded in.
    return operation == null ? null : {...operation.data, 'uuid': operation.uuid};
  }

  Future<dynamic> _getQsos(Map<String, dynamic> params) async {
    final operationUuid = params['operationUuid'] as String;
    // Null — not an empty list — when the operation is unknown or this
    // host has no log access, so callers can tell "no such operation"
    // from "operation with no QSOs yet" (see HookContext.getQsos).
    if (_service.operations == null || _service.qsos == null) return null;
    if (await _service.operations!.get(operationUuid) == null) return null;
    // Excludes soft-deleted records, keeps event markers; oldest first.
    final list = await _service.qsos!.forOperation(operationUuid);
    return [for (final qso in list) qso.data];
  }

  /// The kernel's copy of a log, kept in step (`extensions/sdk/src/logCopy.ts`):
  /// what changed since the cursor it holds — or the whole log, `reset`, when
  /// that cannot be told — and the cursor to hold next. Null exactly where
  /// [_getQsos] is null. Each row carries its uuid from the row itself, since
  /// the copy is keyed on it.
  Future<dynamic> _getQsoChanges(Map<String, dynamic> params) async {
    final operationUuid = params['operationUuid'] as String;
    if (_service.operations == null || _service.qsos == null) return null;
    if (await _service.operations!.get(operationUuid) == null) return null;
    final changes = await _service.qsos!.changesSince(operationUuid, params['cursor'] as String?);
    return {
      'cursor': changes.cursor,
      'reset': changes.reset,
      'qsos': [
        for (final qso in changes.qsos) {...qso.data, 'uuid': qso.uuid},
      ],
      'removed': changes.removed,
      'count': changes.count,
    };
  }

  Future<dynamic> _getSpotsForCall(Map<String, dynamic> params) async {
    // Reads the already-fetched cache — never triggers a fetch. This
    // runs inside the per-keystroke lookup pipeline, where waiting on a
    // fan-out to every spot source's API would blow the lookup's own 8s
    // budget; an empty answer before the first refresh lands is the
    // correct trade.
    final call = params['call'] as String?;
    final maxAgeMinutes = params['maxAgeMinutes'];
    if (call == null || _service.spots == null) return const <Map<String, dynamic>>[];
    return _service.spots!.spotsForCall(call, maxAge: Duration(minutes: maxAgeMinutes is num ? maxAgeMinutes.toInt() : 30));
  }

  /// Backs `host.suggestQso`. Only what a tapped spot carries reaches the
  /// logging fields — the station, where and how it was heard, and its
  /// references — so an extension can prefill a contact but never write the
  /// rest of one.
  ///
  /// It tunes the radio to the spot, as a tap does, so it is a radio command:
  /// `requiresRadioWrite`. And it answers the operator using the caller's
  /// panel, so only while one of its `panel.onEvent` calls runs — from a
  /// timer or a render it would overwrite a half-typed call with nothing on
  /// screen asking for it. `extensionKey` and `duringPanelEvent` are the
  /// kernel's stamps (kernel.ts `IDENTITY_HOST_METHODS`), not the caller's.
  Future<dynamic> _suggestQso(Map<String, dynamic> params) async {
    final extensionKey = params['extensionKey'] as String?;
    if (!_service.radioCalls.canWrite(extensionKey)) {
      throw ExtensionHostException("suggestQso blocked: extension '${extensionKey ?? 'unknown'}' does not declare requiresRadioWrite");
    }
    if (params['duringPanelEvent'] != true) {
      throw ExtensionHostException("suggestQso blocked: extension '$extensionKey' called it outside its panel's onEvent");
    }
    final qso = params['qso'];
    final call = qso is Map ? (qso['their'] is Map ? (qso['their'] as Map)['call'] : null) : null;
    if (call is! String || call.trim().isEmpty) throw const FormatException('suggestQso needs qso.their.call');
    qso as Map;
    final suggestion = <String, dynamic>{
      'their': {'call': call.trim()},
      if (qso['freq'] is num) 'freq': (qso['freq'] as num).toDouble(),
      if (qso['band'] is String) 'band': qso['band'],
      if (qso['mode'] is String) 'mode': qso['mode'],
      // Each ref's plain fields, as a tapped spot passes its whole ref — a
      // park's name, a summit's points — and nothing nested.
      'refs': [
        for (final ref in qso['refs'] is List ? qso['refs'] as List : const [])
          if (ref is Map && ref['type'] is String && ref['ref'] is String)
            {
              for (final MapEntry(:key, :value) in ref.entries)
                if (key is String && (value is String || value is num || value is bool)) key: value,
            },
      ],
    };
    final operationUuid = params['operationUuid'] is String ? params['operationUuid'] as String : null;
    return {'accepted': _service.onSuggestQso?.call(suggestion, operationUuid) ?? false};
  }

  Future<dynamic> _getSpots(Map<String, dynamic> params) async {
    // Reads only what SpotBoardService already worked out — no lookup, no
    // scorer pass — so it can answer from inside a panel render or a lookup
    // (see spots_for_extensions.dart).
    final read = _service.onGetSpots;
    if (read != null) return read(params);
    // Parsed even with nothing to answer from, so a malformed option rejects
    // the same everywhere rather than only where there are spots.
    SpotsQuery.fromParams(params);
    return const <Map<String, dynamic>>[];
  }

  Future<dynamic> _getHistoryForCall(Map<String, dynamic> params) async {
    // Backs `call-history`'s `ctx.getHistoryForCall` — cross-operation,
    // unlike `getQsos`, so it reads `qsos` directly rather than through
    // an operation. `[]` (not null) when there's no log access, same as
    // `getSpotsForCall`'s empty-cache answer: there's no "unknown call"
    // this call needs to distinguish from "no history".
    //
    // The options and their limit are `HistoryFilter`'s, shared with the
    // CLI host; a malformed one throws, rejecting the call — parsed first,
    // so it rejects even where there is no log to answer from.
    final filter = HistoryFilter.fromParams(params);
    final historyCall = params['call'] as String?;
    final qsos = _service.qsos;
    if (historyCall == null || qsos == null) return const <Map<String, dynamic>>[];
    final call = historyCall.trim().toUpperCase();
    if (call.isEmpty) return const <Map<String, dynamic>>[];
    // Every lookup asks for its call's history, and the spot board runs its
    // lookups a batch at a time: the requests landing within
    // [historyCoalesceWindow] of one another with the same options are
    // answered by one query, not a queue of them that every other reader of
    // the database would wait behind.
    final options = jsonEncode({for (final key in params.keys.where((key) => key != 'call').toList()..sort()) key: params[key]});
    final waiting = _historyWaiting[options] ??= _answerHistorySoon(options, filter, qsos);
    return (waiting[call] ??= Completer()).future;
  }

  /// How long a `getHistoryForCall` waits for others to share its query.
  /// One lookup's history comes this much later; a batch of them comes in
  /// one read instead of one each.
  static const historyCoalesceWindow = Duration(milliseconds: 10);

  /// The `getHistoryForCall` requests not yet answered, by their options
  /// and then by call.
  final Map<String, Map<String, Completer<List<Map<String, dynamic>>>>> _historyWaiting = {};

  Map<String, Completer<List<Map<String, dynamic>>>> _answerHistorySoon(String options, HistoryFilter filter, QsosRepository qsos) {
    final waiting = <String, Completer<List<Map<String, dynamic>>>>{};
    Timer(historyCoalesceWindow, () async {
      _historyWaiting.remove(options);
      try {
        // Alone, a call keeps `historyForCall`'s own LIMIT, which stops at
        // its newest rows; the shared query reads every row of every call.
        final history = waiting.length == 1
            ? {waiting.keys.single: await qsos.historyForCall(waiting.keys.single, limit: filter.limit, filter: filter)}
            : await qsos.historyForCallsEach(waiting.keys, limit: filter.limit, filter: filter);
        for (final MapEntry(key: call, value: completer) in waiting.entries) {
          completer.complete([for (final qso in history[call] ?? const <Qso>[]) qso.data]);
        }
      } catch (e, st) {
        for (final completer in waiting.values) {
          completer.completeError(e, st);
        }
      }
    });
    return waiting;
  }

  Future<dynamic> _dbLookupSelectOne(Map<String, dynamic> params) async {
    final category = params['category'] as String;
    final key = params['key'] as String;
    final row = await _service.lookups?.getLookup(category, key);
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
  }

  Future<dynamic> _dbLookupSelectAll(Map<String, dynamic> params) async {
    final category = params['category'] as String;
    final query = params['query'] as String;
    final subCategory = params['subCategory'] as String?;
    final activeOnly = params['activeOnly'] as bool? ?? false;
    final list = await _service.lookups?.queryLookups(category, query, subCategory: subCategory, activeOnly: activeOnly) ?? const [];
    return list
        .map(
          (row) => {
            'category': row.category,
            'subCategory': row.subCategory,
            'key': row.key,
            'name': row.name,
            'data': row.data != null ? jsonDecode(row.data!) : null,
            'lat': row.lat,
            'lon': row.lon,
            'flags': row.flags,
          },
        )
        .toList();
  }

  Future<dynamic> _dbLookupSelectByLocation(Map<String, dynamic> params) async {
    final category = params['category'] as String;
    final lat = (params['lat'] as num).toDouble();
    final lon = (params['lon'] as num).toDouble();
    final delta = (params['delta'] as num).toDouble();
    final activeOnly = params['activeOnly'] as bool? ?? false;
    final list = await _service.lookups?.queryLookupsByLocation(category, lat, lon, delta, activeOnly: activeOnly) ?? const [];
    return list
        .map(
          (row) => {
            'category': row.category,
            'subCategory': row.subCategory,
            'key': row.key,
            'name': row.name,
            'data': row.data != null ? jsonDecode(row.data!) : null,
            'lat': row.lat,
            'lon': row.lon,
            'flags': row.flags,
          },
        )
        .toList();
  }

  Future<dynamic> _dbLookupSelectInBounds(Map<String, dynamic> params) async {
    final list =
        await _service.lookups?.queryLookupsInBounds(
          params['category'] as String,
          south: (params['south'] as num).toDouble(),
          west: (params['west'] as num).toDouble(),
          north: (params['north'] as num).toDouble(),
          east: (params['east'] as num).toDouble(),
          activeOnly: params['activeOnly'] as bool? ?? false,
          limit: (params['limit'] as num?)?.toInt() ?? 500,
        ) ??
        const [];
    return list
        .map(
          (row) => {
            'category': row.category,
            'subCategory': row.subCategory,
            'key': row.key,
            'name': row.name,
            'data': row.data != null ? jsonDecode(row.data!) : null,
            'lat': row.lat,
            'lon': row.lon,
            'flags': row.flags,
          },
        )
        .toList();
  }

  Future<dynamic> _getLocation(Map<String, dynamic> params) async {
    // One-shot device GPS fix (SDK's `host.getLocation()`) — e.g. WEATHER
    // falling back to device location when there's no operation grid.
    // May prompt for location permission; null on any denial/failure.
    // Gated by the manifest's `requiresLocation` capability,
    // same allowlist shape as host.fetch's `domains`.
    final extensionKey = params['extensionKey'] as String?;
    if (!_service._location.allows(extensionKey)) {
      throw ExtensionHostException("getLocation blocked: extension '${extensionKey ?? 'unknown'}' does not declare requiresLocation");
    }
    final position = await _service.location?.getCurrentPosition();
    return position == null ? null : {'latitude': position.latitude, 'longitude': position.longitude};
  }

  Future<dynamic> _getVersionInfo() async {
    // Read-only build identity — no capability gate, unlike getLocation:
    // none of this is sensitive, same reasoning as getSettings.
    //
    // buildNumber is null on Dev, where kBuildNumber is the LAST RELEASE's
    // number rather than the running build's — the same suppression
    // views/version_label.dart and services/flags_service.dart apply, for
    // the same reason. Naming a build that isn't running is worse than
    // naming none: on Dev the SHA is the only true identity.
    return {
      'platform': platformName(),
      'edition': kEdition.name,
      'version': kPublicVersion,
      'versionName': kEditionVersionName,
      'buildNumber': kEdition == Edition.dev ? null : kBuildNumber,
      'gitSha': kGitSha,
    };
  }

  /// Where a call that names no extension is filed — the public `host.showForm`
  /// a bundle built with an SDK before 1.12.6 reaches, and any bundle still
  /// may: one dialog budget and one footer key shared by all of them, since
  /// the key such a call could claim is nobody's to verify.
  static const unattributedNamespace = 'extensions';

  Future<dynamic> _showForm(Map<String, dynamic> params) async {
    final formId = params['formId'] as String;
    final formDef = (params['form'] as Map).cast<String, dynamic>();
    final state = (params['state'] as Map? ?? const {}).cast<String, dynamic>();

    // The context is read when the form opens, which may be after a wait for
    // another extension's dialogs, not when it was asked for.
    return _service.dialogs.run(params['ns'] as String? ?? unattributedNamespace, () {
      final context = navigatorKey.currentContext;
      if (context == null) {
        throw StateError('No active navigation context found');
      }
      return showFormDialog(
        context,
        formDefinition: formDef,
        initialState: state,
        validator: (fieldKey, value, currentState) async {
          try {
            final res = await _service.host?.invoke(
              Hooks.formValidateField,
              key: formId,
              args: {'formId': formId, 'fieldKey': fieldKey, 'value': value, 'state': currentState},
            );
            return res as String?;
          } catch (e) {
            return t.extensionService.validationError(error: e);
          }
        },
        transformer: (fieldKey, value, currentState) async {
          try {
            final res = await _service.host?.invoke(
              Hooks.formTransformField,
              key: formId,
              args: {'formId': formId, 'fieldKey': fieldKey, 'value': value, 'state': currentState},
            );
            return res;
          } catch (_) {
            return value;
          }
        },
        onChange: (fieldKey, value, currentState) async {
          try {
            final res = await _service.host?.invoke(
              Hooks.formOnChangeField,
              key: formId,
              args: {'formId': formId, 'fieldKey': fieldKey, 'value': value, 'state': currentState},
            );
            if (res is Map) {
              return res.cast<String, dynamic>();
            }
            return null;
          } catch (_) {
            return null;
          }
        },
        developerMode: _service.settings?.developerMode ?? false,
      );
    });
  }

  /// A dialog is refused where there is no navigator to show it on, and the
  /// call answers once it is admitted — the dialog opens when the surface is
  /// free, which a hook awaiting the call could not wait for — while a status
  /// message goes to the footer under the extension's one [resultMessageKey],
  /// held to the footer's budgets like any other write to it.
  Future<dynamic> _showMessage(Map<String, dynamic> params) async {
    final ns = params['ns'] as String? ?? unattributedNamespace;
    final message = readResultMessage(params);
    if (message.dialog) {
      _statusBarBounded(params, textChars: statusBarMaxNoticeChars);
      if (navigatorKey.currentContext == null) throw StateError('No active navigation context found');
      _service.dialogs.show(
        ns,
        () => showExtensionMarkdownDialog(title: message.title, text: message.text, actions: message.actions, onOpenAccount: _service.onOpenAccount),
      );
    } else {
      _statusBarBounded(params, textChars: statusBarMaxTextChars);
      _statusBarAdmitKey(ns, resultMessageKey(ns));
      writeResultMessage(ns, icon: message.icon, title: message.title, text: message.text);
    }
    return null;
  }

  /// The footer line [ns]'s status result messages share — a hook result's
  /// or a `showMessage` call's — held to the coalescing like its other
  /// writes, so one held for the flush never lands over a newer one.
  void writeResultMessage(String ns, {String? icon, String? title, required String text}) {
    final key = resultMessageKey(ns);
    _statusBarWrite(ns, key, () => _service.statusBar?.setMessage(key: key, icon: icon, title: title, text: text));
  }

  /// What one extension may put in the footer: at most this many keys at
  /// once — its messages, progress bars and notices together — every string
  /// of a call at most [statusBarMaxTextChars] long, a notice's markdown
  /// [statusBarMaxNoticeChars], and at most [statusBarMaxNoticesPerMinute]
  /// notices a minute, each of which rewrites the persisted history. The
  /// footer's own caps are shared by everyone (status_bar_service.dart), so
  /// one extension past them evicts the others' items.
  static const statusBarMaxKeys = 8, statusBarMaxTextChars = 1024, statusBarMaxNoticeChars = 16384, statusBarMaxNoticesPerMinute = 10;

  /// How often one extension's messages and progress reach the footer: a
  /// write lands at once when none of its landed within this long, else the
  /// latest under each key lands when the span ends. Every landing rebuilds
  /// the footer, which a download posting each chunk would otherwise rebuild
  /// as fast as the chunks come.
  static const statusBarCoalesce = Duration(milliseconds: 100);

  final Map<String, RateWindow> _noticesBy = {};

  /// Each extension's writes held for its next flush, by key — present, empty
  /// or not, while a flush is scheduled.
  final Map<String, Map<String, void Function()>> _statusBarHeld = {};
  final Map<String, Timer> _statusBarFlush = {};

  Future<dynamic> _statusBarSetMessage(Map<String, dynamic> params) async {
    final ns = params['ns'] as String, key = _namespacedKey(params);
    _statusBarBounded(params, textChars: statusBarMaxTextChars);
    _statusBarAdmitKey(ns, key);
    final icon = params['icon'] as String?, title = params['title'] as String?, text = params['text'] as String?;
    _statusBarWrite(ns, key, () => _service.statusBar?.setMessage(key: key, icon: icon, title: title, text: text));
    return null;
  }

  Future<dynamic> _statusBarSetProgress(Map<String, dynamic> params) async {
    final ns = params['ns'] as String, key = _namespacedKey(params);
    _statusBarBounded(params, textChars: statusBarMaxTextChars);
    _statusBarAdmitKey(ns, key);
    final icon = params['icon'] as String?, title = params['title'] as String?, text = params['text'] as String?, value = (params['value'] as num?)?.toDouble();
    _statusBarWrite(ns, key, () => _service.statusBar?.setProgress(key: key, icon: icon, title: title, text: text, value: value));
    return null;
  }

  Future<dynamic> _statusBarClear(Map<String, dynamic> params) async {
    final key = _namespacedKey(params);
    // A write held for the flush would bring the item back.
    _statusBarHeld[params['ns'] as String]?.remove(key);
    _service.statusBar?.clear(key);
    return null;
  }

  Future<dynamic> _statusBarShowNotice(Map<String, dynamic> params) async {
    final ns = params['ns'] as String, key = _namespacedKey(params);
    _statusBarBounded(params, textChars: statusBarMaxNoticeChars);
    _statusBarAdmitKey(ns, key);
    final notices = _noticesBy[ns] ??= RateWindow(statusBarMaxNoticesPerMinute, const Duration(minutes: 1));
    if (!notices.admit()) {
      throw ExtensionHostException("statusBar refused: extension '$ns' has posted $statusBarMaxNoticesPerMinute notices in the last minute");
    }
    _service.statusBar?.showNotice(
      key: key,
      icon: params['icon'] as String?,
      title: params['title'] as String?,
      text: params['text'] as String? ?? '',
      actions: noticeActionsFromJson(params['actions'], onOpenAccount: _service.onOpenAccount),
    );
    return null;
  }

  Future<dynamic> _statusBarDismissNotice(Map<String, dynamic> params) async {
    _service.statusBar?.dismissNotice(_namespacedKey(params));
    return null;
  }

  /// Every string [params] carries, its actions' included, at most
  /// [statusBarMaxTextChars] long — `text` [textChars]: a notice's markdown,
  /// and its dialog actions', may run longer than a footer line.
  void _statusBarBounded(Map<String, dynamic> params, {required int textChars}) {
    void check(String field, Object? value) {
      final max = field == 'text' ? textChars : statusBarMaxTextChars;
      if (value is String && value.length > max) throw ExtensionHostException("statusBar refused: '$field' is ${value.length} characters, more than $max");
      if (value is Map) {
        for (final MapEntry(:key, :value) in value.entries) {
          check('$key', value);
        }
      }
      if (value is List) {
        for (final item in value) {
          check(field, item);
        }
      }
    }

    params.forEach(check);
  }

  /// The keys [ns] holds in the footer — its items, its active notices and
  /// the writes held for its next flush — read from the footer itself, so
  /// what it dismisses on its own, or a restart's sweep, is counted gone.
  Set<String> _statusBarKeysOf(String ns) {
    final prefix = '$ns:', statusBar = _service.statusBar;
    return {
      if (statusBar != null) ...[
        for (final item in statusBar.items)
          if (item.key.startsWith(prefix)) item.key,
        for (final notice in statusBar.activeNotices)
          if (notice.key.startsWith(prefix)) notice.key,
      ],
      ...?_statusBarHeld[ns]?.keys,
    };
  }

  /// Refuses a key that would be [ns]'s ninth; one it holds is its to rewrite.
  void _statusBarAdmitKey(String ns, String key) {
    final held = _statusBarKeysOf(ns);
    if (!held.contains(key) && held.length >= statusBarMaxKeys) {
      throw ExtensionHostException("statusBar refused: extension '$ns' already holds $statusBarMaxKeys keys in the footer");
    }
  }

  /// Lands [write] now, or holds it as the latest under [key] for the flush
  /// [statusBarCoalesce] after [ns]'s last landing. [write] reads nothing of
  /// the call that asked for it: a malformed call fails at the call, where
  /// its params are read, not in a flush timer nobody awaits.
  void _statusBarWrite(String ns, String key, void Function() write) {
    final held = _statusBarHeld[ns];
    if (held != null) {
      held[key] = write;
      return;
    }
    write();
    _statusBarHeld[ns] = {};
    _statusBarFlush[ns] = Timer(statusBarCoalesce, () => _statusBarFlushHeld(ns));
  }

  /// Lands what [ns] held, and holds the span open after a flush that landed
  /// anything: a storm lands once a span, not twice at a span's edges.
  void _statusBarFlushHeld(String ns) {
    final held = _statusBarHeld.remove(ns);
    _statusBarFlush.remove(ns);
    if (held == null || held.isEmpty) return;
    for (final write in held.values) {
      write();
    }
    _statusBarHeld[ns] = {};
    _statusBarFlush[ns] = Timer(statusBarCoalesce, () => _statusBarFlushHeld(ns));
  }

  /// Forgets the writes held for [namespaces], whose extensions are being
  /// replaced: landed after the restart's sweep, one would put the old
  /// generation's progress bar back with nobody to finish it.
  void dropStatusBarHeld(Iterable<String> namespaces) {
    for (final ns in namespaces) {
      _statusBarHeld.remove(ns);
      _statusBarFlush.remove(ns)?.cancel();
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
}
