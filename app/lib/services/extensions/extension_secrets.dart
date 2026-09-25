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
/// The reserved-prefix opening this once carried is gone, and nothing needs
/// it back. It let the catalog's copy of a built-in read what its namesake
/// did, for exactly one value in the end; every such value now ships as a
/// CONSTANT in the extension that calls the endpoint, because a `.h2kext` is
/// a zip the catalog serves to anyone and a key inside one was never
/// confidential. What is left in the build's store is read by Dart alone
/// (`appOnlySecrets`). An opening that grants nothing is one to re-add
/// deliberately if a twin ever needs it, not one to carry meanwhile.
///
/// Empty values are dropped rather than passed through: a build without the
/// value configured must look identical to a build that never had it, so an
/// extension's "expect null and degrade" path is the one that runs.
Map<String, String> visibleSecretsFor(ExtensionInfo info, Map<String, String> secrets) {
  if (!info.source.maySeeBuildSecrets) return const {};
  return {
    for (final entry in secrets.entries)
      if (entry.value.isNotEmpty && extensionMaySeeSecret(info.key, entry.key)) entry.key: entry.value,
  };
}
