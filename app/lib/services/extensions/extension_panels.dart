// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Extension panels, both kinds: the `panel` hooks a layout renders and the
// `settingsPanel` hooks Settings renders, with the Dart-owned storage a
// panel's fields persist to.

part of 'extension_service.dart';

mixin _ExtensionPanels implements PanelExtensionSource, PanelEventSource {
  // Owned by the class or by another part of this library.
  ExtensionHost? get host;
  SettingsService? get settings;
  Future<void>? get _restartFuture;
  Future<void> start();
  Future<void> restartRuntime({bool fresh});
  FlutterSecureStorage get _secureStorage;
  Future<Map<String, String>?> getAccountCredentials(String kvKey);

  /// Every panel across every extension's `settingsPanel` registration, one
  /// entry per PANEL (not per registration — a Tier 2 hook's `getPanels()`
  /// can fan one registration out to several), sorted by `order`. Each
  /// entry is `{panelKey, hookKey, extensionKey, title, icon, order, kind}`
  /// — `hookKey` is what routes `getSettingsPanelDefinition`/action calls
  /// back to the right registered object; `panelKey` is what's passed as
  /// `args.panelKey`. They're equal for Tier 1; only a multi-panel Tier 2
  /// registration tells them apart.
  Future<List<Map<String, dynamic>>> getSettingsPanels() async {
    final host = this.host;
    if (host == null) return const [];
    try {
      final entries = await host.invokeAll(Hooks.settingsPanelGetPanels, timeout: const Duration(seconds: 2));
      final panels = <Map<String, dynamic>>[];
      for (final entry in entries) {
        if (entry['ok'] == true && entry['value'] is Map) {
          panels.add((entry['value'] as Map).cast<String, dynamic>());
        }
      }
      panels.sort((a, b) => ((a['order'] as num?) ?? 0).compareTo((b['order'] as num?) ?? 0));
      return panels;
    } catch (e) {
      debugPrint('[extensions] getSettingsPanels failed: $e');
      return const [];
    }
  }

  /// [getSettingsPanels] once the runtime has settled, for a caller that
  /// reads `ready` afterwards to tell "no panels" from "no runtime".
  ///
  /// A replacement fails every call pending on the host it disposes, so a
  /// query caught by one answers empty while no host is up — which reads as
  /// a runtime that failed to start. It is asked again of whatever the
  /// replacement brought up, and a runtime that did fail to come up answers
  /// empty with no host, as it should.
  Future<List<Map<String, dynamic>>> settledSettingsPanels() async {
    while (true) {
      await start();
      final asked = host;
      final panels = await getSettingsPanels();
      if (identical(asked, host)) return panels;
    }
  }

  /// Every panel every `panel` hook contributes, tagged with the `hookKey`
  /// that routes [renderPanel] back to it (see docs/extensions/hooks.md).
  /// Discovery only — nothing here renders anything, and a panel the
  /// operator has not put in a layout is never asked to.
  ///
  /// **Null means "could not ask"** — no runtime yet, or the call failed —
  /// as distinct from an empty list, which means the extensions genuinely
  /// offer no panels. Deliberately NOT [_collectHookResults], whose swallow
  /// to `const []` is right for an additive list (one missing export option
  /// degrades a menu) and wrong here: a caller reconciling a SAVED LAYOUT
  /// against this would read a failed call as "that panel no longer exists"
  /// and throw the operator's arrangement away.
  @override
  Future<List<Map<String, dynamic>>?> getExtensionPanels() async {
    // The getter, not the field, like every other hook call here — the field
    // is invisible to a subclass supplying its own host.
    final host = this.host;
    if (host == null) {
      debugPrint('[extensions] getExtensionPanels: no runtime yet');
      return null;
    }
    try {
      final entries = await host.invokeAll(Hooks.panelGetPanels, args: const <String, dynamic>{}, timeout: const Duration(seconds: 10));
      final results = <Map<String, dynamic>>[];
      for (final entry in entries) {
        // One hook failing is that hook's panels lost, not the catalog's —
        // but it still says so, unlike the whole call failing above.
        if (entry['ok'] != true) {
          debugPrint('[extensions] panel hook "${entry['key']}" getPanels failed: ${entry['error']}');
          continue;
        }
        if (entry['value'] is! List) {
          // A hook resolving with a single object rather than a list would
          // otherwise lose its panels with nothing said anywhere.
          debugPrint('[extensions] panel hook "${entry['key']}" getPanels did not return a list');
          continue;
        }
        for (final item in (entry['value'] as List)) {
          if (item is Map) results.add({...item.cast<String, dynamic>(), 'hookKey': entry['key']});
        }
      }
      return results;
    } catch (e) {
      debugPrint('[extensions] getExtensionPanels failed: $e');
      return null;
    }
  }

  /// One panel's content, right now. Returns null only when there is no
  /// runtime or the hook answered with something that isn't a document; a
  /// hook that throws or times out THROWS here, so the caller can tell "this
  /// panel has nothing to say" from "this panel is broken" and show the
  /// second as a panel-sized error.
  ///
  /// The timeout is short on purpose: this runs while the operator is
  /// looking at the pane, and a panel that can't answer promptly should say
  /// so rather than hold a repaint.
  @override
  Future<Map<String, dynamic>?> renderPanel({required String hookKey, required String panelKey, required Map<String, dynamic> args}) async {
    final host = this.host;
    if (host == null) return null;
    try {
      final result = await host.invoke(Hooks.panelRender, key: hookKey, args: {...args, 'panelKey': panelKey}, timeout: const Duration(seconds: 5));
      if (result is! Map) return null;
      return result.cast<String, dynamic>();
    } catch (e) {
      debugPrint('[extensions] renderPanel($hookKey/$panelKey) failed: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> panelEvent({required String hookKey, required String panelKey, required Map<String, dynamic> args}) async {
    final host = this.host;
    if (host == null) throw StateError('Extension runtime unavailable');
    final result = await host.invoke(Hooks.panelOnEvent, key: hookKey, args: {...args, 'panelKey': panelKey}, timeout: const Duration(seconds: 5));
    return result is Map ? result.cast<String, dynamic>() : null;
  }

  /// A panel's own config values, keyed by field — the same declarative
  /// storage a Tier 1 settings panel's fields use, under the panel's id, so
  /// a panel's form needs no persistence code of its own.
  @override
  Future<Map<String, dynamic>> readPanelConfig({required String panelKey, required List<Map<String, dynamic>> fields}) async {
    final values = <String, dynamic>{};
    for (final field in fields) {
      final key = field['key'] as String?;
      if (key == null) continue;
      final stored = await _readSettingsValue(panelKey: panelKey, fieldKey: key, isSecret: field['fieldType'] == 'secret');
      if (stored != null) values[key] = stored;
    }
    return values;
  }

  /// The `FormDefinition` for one panel. For a Tier 1 (`kind: 'simple'`)
  /// panel, this is the ONLY bridge call in its whole lifecycle — every
  /// plain/secret field's live value is overlaid from Dart-owned storage
  /// right here, and every subsequent read/write/validate happens locally
  /// (see [commitSettingsFieldValue]/[validateSettingsField]), matching
  /// Tier 1's "no bridge call per keystroke" design. A Tier 2
  /// (`kind: 'dynamic'`) panel's other fields are already current as
  /// returned — that tier owns its own persistence, so nothing is
  /// overlaid for them. `fieldType: 'account'` fields are resolved here
  /// regardless of tier — neither tier can know live account connection
  /// status itself, since that's entirely host-owned (see AccountHook).
  Future<Map<String, dynamic>?> getSettingsPanelDefinition({required String hookKey, required String panelKey, required String kind}) async {
    final host = this.host;
    if (host == null) return null;
    try {
      final result = await host.invoke(Hooks.settingsPanelGetDefinition, key: hookKey, args: {'panelKey': panelKey}, timeout: const Duration(seconds: 5));
      if (result is! Map) return null;
      final definition = Map<String, dynamic>.from(result);
      final elements = ((definition['elements'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      for (final el in elements) {
        if (el['type'] != 'field') continue;
        final fieldKey = el['key'] as String?;
        if (fieldKey == null) continue;
        if (el['fieldType'] == 'account') {
          final accountKey = (el['account'] as Map?)?['key'] as String?;
          if (accountKey != null) el['value'] = await _resolveAccountStatus(accountKey);
          continue;
        }
        if (kind != 'simple') continue;
        final stored = await _readSettingsValue(panelKey: panelKey, fieldKey: fieldKey, isSecret: el['fieldType'] == 'secret');
        if (stored != null) el['value'] = stored;
      }
      definition['elements'] = elements;
      return definition;
    } catch (e) {
      debugPrint('[extensions] getSettingsPanelDefinition failed: $e');
      return null;
    }
  }

  /// `{connected, label}` for a `fieldType: 'account'` field — `label` is
  /// only set when connected (a human-readable "Connected as X"). Guarded
  /// on its own: a credential-storage failure here must not take down the
  /// whole panel the way an unguarded exception bubbling up to
  /// [getSettingsPanelDefinition]'s own try/catch would.
  Future<Map<String, dynamic>> _resolveAccountStatus(String accountKey) async {
    try {
      final creds = await getAccountCredentials(accountKey);
      // Null is "we could not look", not "not connected" — say so, so an
      // extension's own UI can tell the difference too.
      if (creds == null) return {'connected': false, 'unavailable': true};
      if (creds.isEmpty) return {'connected': false};
      final identity = ExtensionService.identityFromCredentials(creds);
      return {'connected': true, if (identity != null) 'label': t.extensionService.connectedAs(identity: identity)};
    } catch (e) {
      debugPrint('[extensions] _resolveAccountStatus failed for $accountKey: $e');
      return {'connected': false};
    }
  }

  /// Validates one field's value. Tier 1 checks `pattern`/`patternError`
  /// declaratively, entirely in Dart — no bridge call. Tier 2 forwards to
  /// its `validateField` hook method.
  Future<String?> validateSettingsField({
    required String kind,
    required String hookKey,
    required String panelKey,
    required Map<String, dynamic> field,
    required String fieldKey,
    required dynamic value,
    required Map<String, dynamic> state,
  }) async {
    if (kind == 'simple') {
      final pattern = field['pattern'] as String?;
      if (pattern == null || pattern.isEmpty) return null;
      try {
        if (RegExp(pattern).hasMatch(value?.toString() ?? '')) return null;
      } catch (e) {
        // A malformed pattern is an extension bug, not a user input error —
        // still can't let it crash the caller, which (unlike submit()'s own
        // validator call) doesn't wrap this in a try/catch on the on-blur path.
        debugPrint('[extensions] settingsPanel field "${field['key']}" has an invalid pattern "$pattern": $e');
        return t.extensionService.invalidFieldConfiguration;
      }
      return field['patternError'] as String? ?? t.extensionService.invalidValue;
    }
    final host = this.host;
    if (host == null) return null;
    try {
      final res = await host.invoke(
        Hooks.settingsPanelValidateField,
        key: hookKey,
        args: {'panelKey': panelKey, 'fieldKey': fieldKey, 'value': value, 'state': state},
      );
      return res as String?;
    } catch (e) {
      return t.extensionService.validationError(error: e);
    }
  }

  /// Commits one field's value after it's been accepted (validated, and for
  /// Tier 2, transformed). Tier 1 persists directly to Dart-owned storage —
  /// kv (SharedPreferences) normally, `FlutterSecureStorage` for
  /// `fieldType: 'secret'`. Tier 2 has no local persistence at all; the
  /// call is forwarded to `onChangeField` and the extension is responsible
  /// for storing it itself (e.g. its own `host.setSettings` — NOT
  /// `host.kvSet`, which is in-memory only).
  ///
  /// [restartOnChange] (the field's own `restartOnChange` attribute, see
  /// docs/extensions/settings.md's "Restarting the runtime after a Tier 2
  /// field commits") restarts the extension runtime once the commit above
  /// finishes, so `onActivation` re-runs and can pick up the new value via
  /// `getSettings()` — for a value nothing else re-reads on its own.
  Future<void> commitSettingsFieldValue({
    required String kind,
    required String hookKey,
    required String panelKey,
    required String fieldKey,
    required dynamic value,
    required Map<String, dynamic> state,
    bool isSecret = false,
    bool restartOnChange = false,
  }) async {
    if (kind == 'simple') {
      await _writeSettingsValue(panelKey: panelKey, fieldKey: fieldKey, value: value, isSecret: isSecret);
      settingsGeneration.value++;
      return;
    }
    // Wait out any in-flight restart before touching `host` — it's briefly
    // null while `_replaceRuntime` tears down and reboots. Without this, a
    // commit landing in that window bailed out below (host == null) without
    // ever calling onChangeField, silently dropping that edit rather than
    // just delaying it.
    final inFlightRestart = _restartFuture;
    if (inFlightRestart != null) await inFlightRestart;
    final host = this.host;
    if (host == null) return;
    // Counted so a pending debounce timer cannot restart the runtime UNDER
    // this commit's bridge call — disposing the host completes the pending
    // invokeHook with an exception and the edit would be silently dropped.
    // The timer waits for quiescence before restarting.
    _inFlightFieldCommits++;
    try {
      await host.invoke(Hooks.settingsPanelOnChangeField, key: hookKey, args: {'panelKey': panelKey, 'fieldKey': fieldKey, 'value': value, 'state': state});
    } catch (e) {
      debugPrint('[extensions] settingsPanel onChangeField failed: $e');
      // Not restarted below: onChangeField is the extension's own persistence
      // call (e.g. host.setSettings) — if IT failed, the value never
      // actually saved, so restarting anyway would just re-run onActivation
      // against the same stale settings for no benefit.
      return;
    } finally {
      _inFlightFieldCommits--;
      if (_inFlightFieldCommits == 0) {
        _fieldCommitsIdle?.complete();
        _fieldCommitsIdle = null;
      }
    }
    settingsGeneration.value++;
    if (restartOnChange) await _debouncedRestartRuntime();
  }

  /// Bumped whenever an extension's own settings value is committed —
  /// neither path notifies [settings], since one writes straight to prefs
  /// and the other hands the value to the extension, so a panel showing
  /// that field has nothing else to learn the change from.
  ///
  /// The Settings panel mounts a panel's fields TWICE — once under Common
  /// Settings, once in the panel's own category — and without this the copy
  /// that did not commit keeps the old value and writes it back on the next
  /// interaction, silently reverting what the operator typed.
  final ValueNotifier<int> settingsGeneration = ValueNotifier(0);

  int _inFlightFieldCommits = 0;
  Completer<void>? _fieldCommitsIdle;

  Timer? _restartOnChangeDebounce;
  Completer<void>? _restartOnChangeCompleter;

  /// Coalesces a burst of `restartOnChange` commits (e.g. deleting or
  /// reordering several rows of an inline list field one at a time) into a
  /// SINGLE runtime restart once they settle, instead of tearing down and
  /// rebooting every OTHER loaded extension once per row action — a full
  /// [restartRuntime] is the existing, already-accepted cost of
  /// `restartOnChange` (the same one an extension enable/disable toggle
  /// pays), but nothing before call-notes' `customFiles` field exercised it
  /// from a rapid, un-awaited per-row UI action.
  Future<void> _debouncedRestartRuntime() {
    _restartOnChangeDebounce?.cancel();
    final completer = _restartOnChangeCompleter ??= Completer<void>();
    _restartOnChangeDebounce = Timer(const Duration(milliseconds: 400), () async {
      // A commit whose onChangeField round trip is still in flight when this
      // timer fires must finish before the restart tears the host down; the
      // loop re-checks because a waiting commit can itself be followed by
      // another within the same window.
      while (_inFlightFieldCommits > 0) {
        await (_fieldCommitsIdle ??= Completer<void>()).future;
      }
      // A commit that finished DURING that wait re-armed the timer onto this
      // same completer — but its write is already durable and the restart
      // below will read it, so that re-arm is redundant: absorb it. If a
      // parallel firing of this callback got here first, the completer no
      // longer matches and this one stands down.
      if (!identical(_restartOnChangeCompleter, completer)) return;
      _restartOnChangeCompleter = null;
      _restartOnChangeDebounce?.cancel();
      unawaited(restartRuntime().then(completer.complete, onError: completer.completeError));
    });
    return completer.future;
  }

  /// Transforms one field's value (Tier 2 only — Tier 1 fields never carry
  /// a transform, by construction of the `SettingsField` type).
  /// `transformField` is optional on `DynamicSettingsPanel` — a hook that
  /// doesn't implement it has nothing to distinguish "no transform
  /// declared" from "explicitly transformed to null" once the call comes
  /// back over the bridge (kernel.ts's generic dispatch has no per-field
  /// fallback the way the `form` category's kernel-side wrapper does), so
  /// a bare `null` result falls back to the original value rather than
  /// silently nulling out the field being committed.
  Future<dynamic> transformSettingsField({
    required String hookKey,
    required String panelKey,
    required String fieldKey,
    required dynamic value,
    required Map<String, dynamic> state,
  }) async {
    final host = this.host;
    if (host == null) return value;
    try {
      final result = await host.invoke(
        Hooks.settingsPanelTransformField,
        key: hookKey,
        args: {'panelKey': panelKey, 'fieldKey': fieldKey, 'value': value, 'state': state},
      );
      return result ?? value;
    } catch (e) {
      return value;
    }
  }

  /// Invokes a `FormActionElement`'s `method` (e.g. a "Test Connection" or
  /// "Clear Cache" button) against the panel's current state and returns
  /// the result string to show as a banner. `method` isn't a fixed hook
  /// method — it's resolved against whatever extra property the extension
  /// put on its registered panel object (see docs/extensions/settings.md's
  /// "The action element").
  Future<String?> runSettingsAction({required String hookKey, required String panelKey, required String method, required Map<String, dynamic> state}) async {
    final host = this.host;
    if (host == null) return t.extensionService.runtimeNotReady;
    try {
      final res = await host.invoke(
        Hooks.settingsPanelAction(method),
        key: hookKey,
        args: {'panelKey': panelKey, 'state': state},
        timeout: const Duration(seconds: 10),
      );
      return res is String ? res : res?.toString();
    } catch (e) {
      return t.extensionService.actionFailed(error: e);
    }
  }

  Future<dynamic> _readSettingsValue({required String panelKey, required String fieldKey, required bool isSecret}) async {
    final raw = isSecret
        ? await _secureStorage.read(key: _settingsSecretStorageKey(panelKey, fieldKey))
        : settings?.prefs.getString(_settingsPrefsKey(panelKey, fieldKey));
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return raw;
    }
  }

  Future<void> _writeSettingsValue({required String panelKey, required String fieldKey, required dynamic value, required bool isSecret}) async {
    final encoded = jsonEncode(value);
    if (isSecret) {
      await _secureStorage.write(key: _settingsSecretStorageKey(panelKey, fieldKey), value: encoded);
      return;
    }
    await settings?.prefs.setString(_settingsPrefsKey(panelKey, fieldKey), encoded);
  }

  /// Forgets everything stored for one panel's own form.
  ///
  /// Only a panel INSTANCE is ever forgotten (see PanelService), so this is
  /// not a settings reset — it is a placement being thrown away along with
  /// what the operator put in it. Secrets go too: leaving a keychain entry
  /// behind for an id that will be handed to the next placement of the same
  /// panel is exactly the resurrection this exists to prevent.
  @override
  Future<void> forgetPanelConfig({required String panelKey, required List<Map<String, dynamic>> fields}) async {
    for (final field in fields) {
      final key = field['key'] as String?;
      if (key == null) continue;
      if (field['fieldType'] == 'secret') {
        await _secureStorage.delete(key: _settingsSecretStorageKey(panelKey, key));
      } else {
        await settings?.prefs.remove(_settingsPrefsKey(panelKey, key));
      }
    }
  }

  String _settingsPrefsKey(String panelKey, String fieldKey) => 'settingsPanel.$panelKey.$fieldKey';

  String _settingsSecretStorageKey(String panelKey, String fieldKey) => 'settingsPanel_secret_${panelKey}_$fieldKey';
}
