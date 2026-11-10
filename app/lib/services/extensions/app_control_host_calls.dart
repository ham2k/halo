// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:halo_i18n/halo_i18n.dart';

import '../status_bar_service.dart';
import 'extension_info.dart';

/// What writing a setting for an extension came to: refused for [reason]
/// (with the store's own [message] for `rejected`), left as it was, or
/// written, with [label] and [valueLabel] to say so.
typedef SettingWrite = ({String? reason, String? message, bool unchanged, String? label, String? valueLabel});

/// The layouts every customizable view draws, as an extension may reach
/// them. A refusal is one of the reasons docs/extensions/host.md lists.
abstract interface class LayoutControl {
  /// Every view, the layouts it keeps, which one it draws, and whether one
  /// of it is open or being edited.
  List<Map<String, dynamic>> list();

  /// Draws [view]'s layout [id]: the refusal, or the name of the layout now
  /// drawn.
  ({String? reason, String? name}) switchTo(String view, String id);

  /// Brings [panel]'s tab to the front wherever [view] holds it: the
  /// refusal, or null.
  String? focus(String view, String panel);
}

/// The host calls that change the app itself, unasked: a setting
/// (`updateSetting`, under `requiresSettingsWrite`, the grant a command
/// hook's `updateSetting` action already takes) and the layouts its views
/// draw (`listLayouts`, `switchLayout`, `focusPanel`, under
/// `requiresLayoutControl`).
///
/// A setting changed or a layout switched is named on the status bar with
/// the extension that did it: the operator did not do it, and without the
/// line a theme turning dark or a layout swapping would come from nowhere.
/// A tab brought to the front is not: what is in front is the change.
///
/// `params['extensionKey']` is the kernel's stamp (kernel.ts
/// `IDENTITY_HOST_METHODS`), not the caller's.
class AppControlHostCalls {
  static const _settingCalls = {'updateSetting'};
  static const _layoutCalls = {'listLayouts', 'switchLayout', 'focusPanel'};

  static bool handles(String method) => _settingCalls.contains(method) || _layoutCalls.contains(method);

  /// Writes a setting by the key `host.searchSettings` answers with, for the
  /// extension [callerKey]. Null on a host with nothing behind it: every
  /// write is refused `invalid`.
  Future<SettingWrite> Function(String key, Object? value, String? callerKey)? settings;

  /// The API at which `requiresSettingsWrite` reaches settings changed
  /// unasked. An extension consented to under an older one agreed to
  /// settings changed through its commands only.
  static const unaskedSettingsApi = 22;

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
    return switch (method) {
      'updateSetting' => _updateSetting(params, extensionKey, extensionName),
      'listLayouts' => layouts?.list() ?? const [],
      'switchLayout' => _switchLayout(params, extensionKey, extensionName),
      _ => _focusPanel(params),
    };
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
