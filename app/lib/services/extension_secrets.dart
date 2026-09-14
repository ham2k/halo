// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Which of the build's secrets an extension may read.
//
// The name-prefix half of the policy lives in halo_build_tools'
// secret_policy.dart, shared with the build. This is the half that depends on
// where an extension's CODE came from, which only the running app knows.

import 'package:halo_build_tools/halo_build_tools.dart' show extensionMaySeeSecret;

import 'extension_info.dart';
import 'installed_extensions.dart';

/// Which build secrets [info] may read, out of everything the build has.
///
/// Two rules, and the first one overrules the second. An extension the app did
/// NOT ship — dev-served, or installed from a `.h2kext` — sees nothing,
/// whatever key it claims: visibility follows where the code came from, not
/// what it calls itself, so a bundle calling itself `sota` cannot inherit
/// `SOTA_*`, and neither pointing the app at a dev server nor installing a file
/// can hand a credential over (HALO-425, HALO-422). Otherwise the name-prefix
/// policy in secret_policy.dart decides.
///
/// One deliberate opening in that first rule, for the extensions Ham2K itself
/// distributes (HALO-581): an INSTALLED bundle holding a `ham2k-` key is one
/// the app pre-loaded or the catalog served, because the reserved prefix is
/// refused to a file install and the record that waives it is cleared by an
/// uninstall or by a file install of the same key. `ham2k-sota` needs
/// `SOTA_OAUTH_*` and `ham2k-wwff` needs `WWFF_API_KEY`, and without this
/// they install, load, and then fail at the first login with nothing to say
/// why. It widens what a compromise of the catalog would reach, which is why
/// it is held to the prefix nothing else can claim rather than to the record
/// alone.
///
/// Empty values are dropped rather than passed through: a build without the
/// value configured must look identical to a build that never had it, so an
/// extension's "expect null and degrade" path is the one that runs.
Map<String, String> visibleSecretsFor(ExtensionInfo info, Map<String, String> secrets) {
  final reserved = info.source == ExtensionSource.installed && info.key.startsWith(kReservedKeyPrefix);
  if (!info.source.maySeeBuildSecrets && !reserved) return const {};
  // The policy is asked under the name the SECRETS were named for. It builds
  // the allowed prefix from the key, so `ham2k-sota` would ask for
  // `HAM2K_SOTA_*` while the value it needs is `SOTA_OAUTH_CLIENT_ID_PROD` —
  // and the opening above would grant precisely nothing, which is the failure
  // it exists to prevent. The reserved prefix is what the catalog's copy of a
  // built-in wears; underneath it is the same extension asking for the same
  // value it always could.
  final policyKey = reserved ? info.key.substring(kReservedKeyPrefix.length) : info.key;
  return {
    for (final entry in secrets.entries)
      if (entry.value.isNotEmpty && extensionMaySeeSecret(policyKey, entry.key)) entry.key: entry.value,
  };
}
