// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a command's actions need of the extension whose hook answered — the
// operator's consent to settings writes or to radio control, or the app's
// own authorship for a developer's tool — and whose name a command from an
// extension that is not the app's own is shown under.

part of 'extension_service.dart';

/// On the hook API, whose `interpretCommand` and command catalog hand it
/// every answer a `command` hook gives.
mixin _ExtensionCommandGate on _ExtensionHookApi {
  // Owned by the class or by another part of this library.
  ExtensionInfo? extensionInfo(String key);
  RadioHostCalls get radioCalls;

  /// The actions that write a setting, which need `requiresSettingsWrite`;
  /// the ones that drive the radio, which need `requiresRadioWrite`; and the
  /// developer's, which run only for the app's own extensions. An action not
  /// listed here is one any command may carry; list it here when it writes a
  /// setting, drives the radio, or belongs to the developer.
  static const _settingsActions = {'updateSetting', 'updateSettings', 'toggleExperiment', 'setEnterSends', 'setKeyerSpeed', 'showKeyer'};
  static const _radioActions = {'setPower'};
  static const _developerActions = {
    'reloadDataFiles',
    'devNotice',
    'devStatus',
    'devProgress',
    'devHammer',
    'devSplash',
    'devOnboard',
    'devTester',
    'devTimeTravel',
    'devPopup',
    'devSentry',
    'devBench',
    'devLogCat',
    'devMapInfo',
    'devIdle',
  };

  /// [interpretation] as the app runs it: stamped with the extension the
  /// kernel says answered, refused outright when it carries an action that
  /// extension may not run (an error in place of the hook's own preview and
  /// confirmation, so nothing reads as done), and, for an extension that is
  /// not the app's own, described under its name. A missing key is no
  /// extension at all, and is refused the same way. A grant belongs to the
  /// bundle and to the sub-extensions it defines under its own key, resolved
  /// the way every other grant is.
  @override
  Map<String, dynamic> _attributedCommand(Map<String, dynamic> interpretation, String? extensionKey) {
    final settingsGrant = CapabilityGrant.among(availableExtensions, (info) => info.requiresSettingsWrite);
    final (info, name) = _commandSource(extensionKey);
    final actions = <String>{
      if (interpretation['commands'] case final List<dynamic> commands)
        for (final command in commands)
          if (command is Map) ...command.keys.whereType<String>(),
    };
    String? refusal;
    if (actions.any(_settingsActions.contains) && !settingsGrant.allows(extensionKey)) {
      refusal = t.extensionService.commandMayNotChangeSettings(name: name);
    } else if (actions.any(_radioActions.contains) && !radioCalls.canWrite(extensionKey)) {
      refusal = t.extensionService.commandMayNotControlRadio(name: name);
    } else if (actions.any(_developerActions.contains) && !(info?.core ?? false)) {
      refusal = t.extensionService.commandDeveloperOnly(name: name);
    }
    if (refusal != null) {
      debugPrint('[extensions] command from $name refused: $refusal');
      return {'error': refusal, 'extensionKey': ?extensionKey};
    }
    final describe = interpretation['describe'];
    return {...interpretation, 'extensionKey': ?extensionKey, if (describe is String && describe.isNotEmpty) 'describe': _describedBy(describe, info, name)};
  }

  /// [describe] under the name of the extension behind [extensionKey] when
  /// that is not the app's own; the app's own words stay as they are.
  @override
  String _describedByOwner(String describe, String? extensionKey) {
    final (info, name) = _commandSource(extensionKey);
    return _describedBy(describe, info, name);
  }

  /// The loaded extension behind [extensionKey] — the bundle, for a
  /// sub-extension it defines — and the name to show for it.
  (ExtensionInfo?, String) _commandSource(String? extensionKey) {
    final owner = CapabilityGrant.among(availableExtensions, (_) => false).ownerOf(extensionKey);
    final info = owner == null ? null : extensionInfo(owner);
    return (info, info?.nameFor(LocaleSettings.currentLocale.languageCode) ?? extensionKey ?? '?');
  }

  String _describedBy(String describe, ExtensionInfo? info, String name) =>
      info != null && !info.core ? t.extensionService.commandDescribeBy(describe: describe, extension: name) : describe;
}
