// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:halo_i18n/halo_i18n.dart';

import '../error_reporting_service.dart';
import '../status_bar_service.dart';
import 'extension_info.dart';

/// What writing a setting for an extension came to: refused for [reason]
/// (with the store's own [message] for `rejected`), left as it was, or
/// written, with [label] and [valueLabel] to say so.
typedef SettingWrite = ({String? reason, String? message, bool unchanged, String? label, String? valueLabel});

/// What applying a layout document came to: refused for [reason] (with what
/// was wrong with the document as [message]), or written into the layout
/// [id], called [name], with the panels left out as [skipped].
typedef LayoutWrite = ({String? reason, String? message, String? id, String? name, List<String> skipped});

/// The layouts every customizable view draws, as an extension may reach
/// them. A refusal is one of the reasons docs/extensions/host.md lists.
/// [owner] is the calling extension's bundle: the layouts it made are the
/// only ones it may write.
abstract interface class LayoutControl {
  /// Every view, the layouts it keeps, which one it draws, and whether one
  /// of it is open or being edited; [owner]'s own layouts are marked.
  List<Map<String, dynamic>> list(String? owner);

  /// Draws [view]'s layout [id]: the refusal, or the name of the layout now
  /// drawn.
  ({String? reason, String? name}) switchTo(String view, String id);

  /// Brings [panel]'s tab to the front wherever [view] holds it: the
  /// refusal, or null.
  String? focus(String view, String panel);

  /// [view]'s layout [id], the one it draws when null, as a layout document.
  Future<({String? reason, Map<String, dynamic>? document})> read(String view, String? id);

  /// [document] as a new layout of [owner]'s (`mode` `new`), or in place of
  /// (`replace`) or added to (`add`) [owner]'s layout [id].
  Future<LayoutWrite> apply(String view, Object? document, {required String mode, String? id, String? name, String? description, required String owner});

  /// Deletes [owner]'s layout [id].
  Future<({String? reason, String? name})> remove(String view, String id, {required String owner});
}

/// The host calls that change the app itself, unasked: a setting
/// (`updateSetting`, under `requiresSettingsWrite`, the grant a command
/// hook's `updateSetting` action already takes) and the layouts its views
/// draw (`listLayouts`, `switchLayout`, `focusPanel`, `getLayout`,
/// `applyLayout`, `removeLayout`, under `requiresLayoutControl`).
///
/// A setting changed, or a layout switched, added, changed or removed, is
/// named on the status bar with the extension that did it: the operator did
/// not do it, and without the line a theme turning dark or a layout swapping
/// would come from nowhere.
/// A tab brought to the front is not: what is in front is the change.
/// A change that fails on the way, rather than being refused, is named too,
/// as a notice: what it did before it failed is as unexplained as what it
/// would have done.
///
/// `params['extensionKey']` is the kernel's stamp (kernel.ts
/// `IDENTITY_HOST_METHODS`), not the caller's.
class AppControlHostCalls {
  static const _settingCalls = {'updateSetting'};
  static const _layoutCalls = {'listLayouts', 'switchLayout', 'focusPanel', 'getLayout', 'applyLayout', 'removeLayout'};
  static const _changeCalls = {'updateSetting', 'switchLayout', 'applyLayout', 'removeLayout'};

  static bool handles(String method) => _settingCalls.contains(method) || _layoutCalls.contains(method);

  /// Writes a setting by the key `host.searchSettings` answers with, for the
  /// extension [callerKey]. Null on a host with nothing behind it: every
  /// write is refused `invalid`.
  Future<SettingWrite> Function(String key, Object? value, String? callerKey)? settings;

  /// The API at which `requiresSettingsWrite` reaches settings changed
  /// unasked. An extension consented to under an older one agreed to
  /// settings changed through its commands only.
  static const unaskedSettingsApi = 23;

  /// Null on a host with no views: nothing to list, every change refused
  /// `unavailable`.
  LayoutControl? layouts;

  StatusBarService? statusBar;

  /// [nameOf] names the caller as the command bar does: the bundle that
  /// defines it, in the operator's language.
  Future<dynamic> handle(
    String method,
    Map<String, dynamic> params,
    Iterable<ExtensionInfo> available, {
    required String Function(String? extensionKey) nameOf,
  }) async {
    final extensionKey = params['extensionKey'] as String?;
    final (grant, name) = _settingCalls.contains(method)
        ? ((ExtensionInfo info) => info.requiresSettingsWrite, 'requiresSettingsWrite')
        : ((ExtensionInfo info) => info.requiresLayoutControl, 'requiresLayoutControl');
    if (!CapabilityGrant.among(available, grant).allows(extensionKey)) {
      throw ExtensionHostException("$method blocked: extension '${extensionKey ?? 'unknown'}' does not declare $name");
    }
    if (_settingCalls.contains(method)) {
      final owner = CapabilityGrant.among(available, grant).ownerOf(extensionKey);
      final api = available.where((info) => info.key == owner).firstOrNull?.api;
      if (api != null && api < unaskedSettingsApi) {
        throw ExtensionHostException("$method blocked: extension '$extensionKey' declares api $api, and changing settings unasked needs $unaskedSettingsApi");
      }
    }
    final extensionName = nameOf(extensionKey);
    // The bundle, for a sub-extension: the layouts it made are the bundle's.
    final owner = CapabilityGrant.among(available, grant).ownerOf(extensionKey)!;
    try {
      return await Future<dynamic>.sync(
        () => switch (method) {
          'updateSetting' => _updateSetting(params, extensionKey, extensionName),
          'listLayouts' => layouts?.list(owner) ?? const [],
          'switchLayout' => _switchLayout(params, extensionKey, extensionName),
          'getLayout' => _getLayout(params),
          'applyLayout' => _applyLayout(params, extensionKey, extensionName, owner),
          'removeLayout' => _removeLayout(params, extensionKey, extensionName, owner),
          _ => _focusPanel(params),
        },
      );
    } catch (e, stack) {
      if (_changeCalls.contains(method)) {
        final bar = statusBar;
        ErrorReportingService.report(
          e,
          stack,
          context: 'extension:app-control',
          notice: bar == null
              ? null
              : ErrorNotice(
                  bar,
                  key: 'extension:${extensionKey ?? ''}:failed',
                  title: method == 'updateSetting'
                      ? t.extensionService.settingChangeFailed(name: extensionName)
                      : t.extensionService.layoutChangeFailed(name: extensionName),
                ),
        );
      }
      // The extension hears of it as of any call that failed.
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _updateSetting(Map<String, dynamic> params, String? extensionKey, String extensionName) async {
    final key = params['key'];
    final write = settings;
    if (key is! String || key.isEmpty || write == null) return _refused('invalid');
    final result = await write(key, params['value'], extensionKey);
    if (result.reason case final reason?) return _refused(reason, message: result.message);
    if (result.unchanged) return {'accepted': true, 'unchanged': true};
    _say(extensionKey, t.extensionService.changedSetting(name: extensionName, setting: result.label ?? key, value: result.valueLabel ?? ''));
    return {'accepted': true};
  }

  Map<String, dynamic> _switchLayout(Map<String, dynamic> params, String? extensionKey, String extensionName) {
    final view = params['view'], id = params['id'];
    final control = layouts;
    if (view is! String || id is! String) return _refused('invalid');
    if (control == null) return _refused('unavailable');
    final (:reason, :name) = control.switchTo(view, id);
    if (reason != null) return _refused(reason);
    if (name != null) _say(extensionKey, t.extensionService.switchedLayout(name: extensionName, layout: name));
    return {'accepted': true};
  }

  Map<String, dynamic> _focusPanel(Map<String, dynamic> params) {
    final view = params['view'] ?? 'operation', panel = params['panel'];
    final control = layouts;
    if (view is! String || panel is! String) return _refused('invalid');
    if (control == null) return _refused('missing');
    if (control.focus(view, panel) case final reason?) return _refused(reason);
    return {'accepted': true};
  }

  Future<Map<String, dynamic>> _getLayout(Map<String, dynamic> params) async {
    final view = params['view'], id = params['id'];
    final control = layouts;
    if (view is! String || (id != null && id is! String)) return _refused('invalid');
    if (control == null) return _refused('closed');
    final (:reason, :document) = await control.read(view, id as String?);
    if (reason != null) return _refused(reason);
    return {'accepted': true, 'document': document};
  }

  Future<Map<String, dynamic>> _applyLayout(Map<String, dynamic> params, String? extensionKey, String extensionName, String owner) async {
    final view = params['view'], mode = params['as'] ?? 'new', id = params['id'], name = params['name'], description = params['description'];
    final control = layouts;
    if (view is! String ||
        mode is! String ||
        (id != null && id is! String) ||
        (name != null && name is! String) ||
        (description != null && description is! String)) {
      return _refused('invalid');
    }
    if (control == null) return _refused('closed');
    final result = await control.apply(
      view,
      params['document'],
      mode: mode,
      id: id as String?,
      name: name as String?,
      description: description as String?,
      owner: owner,
    );
    if (result.reason case final reason?) return {..._refused(reason, message: result.message), if (result.skipped.isNotEmpty) 'skipped': result.skipped};
    final layoutName = result.name ?? result.id!;
    _say(
      extensionKey,
      mode == 'new'
          ? t.extensionService.addedLayout(name: extensionName, layout: layoutName)
          : t.extensionService.changedLayout(name: extensionName, layout: layoutName),
    );
    return {'accepted': true, 'id': result.id, if (result.skipped.isNotEmpty) 'skipped': result.skipped};
  }

  Future<Map<String, dynamic>> _removeLayout(Map<String, dynamic> params, String? extensionKey, String extensionName, String owner) async {
    final view = params['view'], id = params['id'];
    final control = layouts;
    if (view is! String || id is! String) return _refused('invalid');
    if (control == null) return _refused('closed');
    final (:reason, :name) = await control.remove(view, id, owner: owner);
    if (reason != null) return _refused(reason);
    _say(extensionKey, t.extensionService.removedLayout(name: extensionName, layout: name ?? id));
    return {'accepted': true};
  }

  Map<String, dynamic> _refused(String reason, {String? message}) => {'accepted': false, 'reason': reason, 'message': ?message};

  /// One line per extension, so a second change replaces the first rather
  /// than stacking a line for each.
  void _say(String? extensionKey, String text) => statusBar?.setMessage(
    key: 'extension:${extensionKey ?? ''}:changed',
    icon: 'cog-outline',
    text: text,
    dismissAfter: StatusBarService.completedDismissDelay,
  );
}
