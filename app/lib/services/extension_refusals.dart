// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Bundles the engine would not evaluate, and what becomes of them
// (docs/extensions/distribution.md).
//
// One bundle that throws while it is being evaluated takes the whole runtime
// generation with it — `EngineRuntime.load` evaluates each in turn and throws
// if any step fails — so a bad one has to be kept out of the set rather than
// merely noticed. Everything here is about doing that without losing the
// extension for good: the record is keyed by the VERSION that failed, so the
// next release of the same extension is given its chance by an ordinary
// update, and the operator's switch is left alone meanwhile.

import 'extension_info.dart';
import 'settings_service.dart';

/// The bundle key a failed boot names, or null.
///
/// `EngineRuntimeIo.load` evaluates every bundle under its own key, so the
/// failure carries its own culprit: `evaluating ham2k-wca: TypeError …`.
///
/// Answered only for a key [available] currently offers as an INSTALLED
/// extension. A built-in that will not evaluate is a defect in the app
/// itself, and putting it aside would ship an install quietly missing part of
/// itself; a name that matches nothing is a message this pattern misread.
String? bundleKeyFromStartFailure(String? failure, List<ExtensionInfo> available) {
  final key = _startFailurePattern.firstMatch(failure ?? '')?.group(1);
  if (key == null) return null;
  return available.any((info) => info.key == key && info.isInstalled) ? key : null;
}

final _startFailurePattern = RegExp(r'evaluating ([A-Za-z0-9][A-Za-z0-9._-]*):');

/// Whether the INSTALLED version of [info] is one the engine refused.
///
/// A version of its own is what makes the record liftable, so an extension
/// without one is never refused — there would be nothing for a later release
/// to differ from.
bool isBundleRefused(SettingsService? settings, ExtensionInfo info) {
  // INSTALLED, like the two above: a key can be both a built-in and a catalog
  // extension, and a record written for the downloaded copy must never take
  // the app's own out of the set — the doc promises exactly the opposite.
  if (!info.isInstalled) return false;
  final version = info.version;
  if (version == null) return false;
  return settings?.extensionRefused[info.key] == version;
}

/// Whether the INSTALLED version of [info] is one the catalog revoked.
///
/// Judged by version, like a refusal and for the same reason: the record
/// stops mattering the moment another version is installed, and both are
/// lifted together by [liftInstallRecordsForNewVersion].
bool isBundleRevoked(SettingsService? settings, ExtensionInfo info) {
  final version = info.version;
  return version != null && settings?.extensionRevoked[info.key]?['version'] == version;
}

/// Lifts every record an install of a DIFFERENT version makes obsolete: the
/// catalog's revocation of the version that was pulled, and a refusal of the
/// version that would not evaluate.
///
/// Both are judged by version for the same reason, and an install is the one
/// moment both can stop being true at once.
Future<void> liftInstallRecordsForNewVersion(SettingsService settings, String key, String? version) async {
  final revoked = settings.extensionRevoked;
  if (revoked[key] != null && revoked[key]!['version'] != version) {
    revoked.remove(key);
    await settings.setExtensionRevoked(revoked);
  }
  await liftRefusalForNewVersion(settings, key, version);
}

/// Lifts the refusal on [key] when [version] is not the one that failed, and
/// answers whether it did.
///
/// A different version is a different bundle and deserves its chance — this
/// is the whole recovery the record is keyed by version for.
Future<bool> liftRefusalForNewVersion(SettingsService settings, String key, String? version) async {
  final refused = {...settings.extensionRefused};
  if (refused[key] == null || refused[key] == version) return false;
  refused.remove(key);
  await settings.setExtensionRefused(refused);
  return true;
}
