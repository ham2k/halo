// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The reverse API: the calls the extension runtime makes back into the app
// (`host.*` in the SDK), answered against the service's own collaborators.

part of 'extension_service.dart';

class _ExtensionHostCalls {
  _ExtensionHostCalls(this._service);

  final ExtensionService _service;

  Future<dynamic> handle(String method, Map<String, dynamic> params) async {
    if (RadioHostCalls.handles(method)) return _service.radioCalls.handle(method, params);
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
      'getSpotsForCall' => _getSpotsForCall(params),
      'getHistoryForCall' => _getHistoryForCall(params),
      'dbLookupSelectOne' => _dbLookupSelectOne(params),
      'dbLookupSelectAll' => _dbLookupSelectAll(params),
      'dbLookupSelectByLocation' => _dbLookupSelectByLocation(params),
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

  Future<dynamic> _getAccount(Map<String, dynamic> params) async {
    final kvKey = params['kvKey'] as String;
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
    final kvKey = params['kvKey'] as String;
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
      'locale': _service.settings?.locale ?? 'en',
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
      // The RESOLVED characters, not the preference name: an extension
      // parsing what an operator typed needs to know which mark is the
      // decimal, and "use the device's settings" is not an answer it
      // could act on. Read from the same singleton every Dart surface
      // reads, so a hook and the field beside it cannot disagree.
      'decimalSeparator': NumberFormatting.instance.decimalSeparator,
      'groupingSeparator': NumberFormatting.instance.groupingSeparator,
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
    if (historyCall == null || _service.qsos == null) return const <Map<String, dynamic>>[];
    final history = await _service.qsos!.historyForCall(historyCall, limit: filter.limit, filter: filter);
    return [for (final qso in history) qso.data];
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

  Future<dynamic> _showForm(Map<String, dynamic> params) async {
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
          final res = await _service.host?.invokeHook(
            'form',
            key: formId,
            method: 'validateField',
            args: {'formId': formId, 'fieldKey': fieldKey, 'value': value, 'state': currentState},
          );
          return res as String?;
        } catch (e) {
          return t.extensionService.validationError(error: e);
        }
      },
      transformer: (fieldKey, value, currentState) async {
        try {
          final res = await _service.host?.invokeHook(
            'form',
            key: formId,
            method: 'transformField',
            args: {'formId': formId, 'fieldKey': fieldKey, 'value': value, 'state': currentState},
          );
          return res;
        } catch (_) {
          return value;
        }
      },
      onChange: (fieldKey, value, currentState) async {
        try {
          final res = await _service.host?.invokeHook(
            'form',
            key: formId,
            method: 'onChangeField',
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
    return result;
  }

  Future<dynamic> _showMessage(Map<String, dynamic> params) async {
    _service.presentResultMessage(params, ns: params['ns'] as String? ?? 'extensions');
    return null;
  }

  Future<dynamic> _statusBarSetMessage(Map<String, dynamic> params) async {
    _service.statusBar?.setMessage(
      key: _namespacedKey(params),
      icon: params['icon'] as String?,
      title: params['title'] as String?,
      text: params['text'] as String?,
    );
    return null;
  }

  Future<dynamic> _statusBarSetProgress(Map<String, dynamic> params) async {
    _service.statusBar?.setProgress(
      key: _namespacedKey(params),
      icon: params['icon'] as String?,
      title: params['title'] as String?,
      text: params['text'] as String?,
      value: (params['value'] as num?)?.toDouble(),
    );
    return null;
  }

  Future<dynamic> _statusBarClear(Map<String, dynamic> params) async {
    _service.statusBar?.clear(_namespacedKey(params));
    return null;
  }

  Future<dynamic> _statusBarShowNotice(Map<String, dynamic> params) async {
    _service.statusBar?.showNotice(
      key: _namespacedKey(params),
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

  /// Extension-supplied keys are prefixed with the calling extension's key so
  /// one extension's status bar items/notices can never collide with — or be
  /// cleared/dismissed by — another's. Same `ns` convention as `kvGet`/`kvSet`.
  String _namespacedKey(Map<String, dynamic> params) {
    final ns = params['ns'] as String;
    final key = params['key'] as String;
    return '$ns:$key';
  }
}
