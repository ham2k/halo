// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Which extension may read which build-time secret.
//
// Policy lives HERE, in committed code, rather than in each extension's
// manifest: an extension asking for access is not the same as being granted it,
// and one reviewable list beats a claim spread across thirty manifests. It is
// also deliberately not in `secrets.dart`, which CI generates — the values
// change per build, the rules do not.

/// True when [extensionKey] may read the secret called [name].
///
/// Three ways to qualify, in order of how most things do:
///
/// 1. **Its own prefix.** `sota` reads `SOTA_*`, `tota` reads `TOTA_*`. This
///    covers every secret in the app today, which is the point — the common
///    case needs no entry anywhere. An extension key containing `-` matches
///    both `-` and `_` in the name (`call-notes` reads `CALL_NOTES_*`).
/// 2. **[sharedSecrets]** — readable by any extension.
/// 3. **[grants]** — readable by the extensions named against it.
bool extensionMaySeeSecret(String extensionKey, String name) {
  final upperName = name.toUpperCase();
  final prefix = '${extensionKey.toUpperCase().replaceAll('-', '_')}_';
  if (upperName.replaceAll('-', '_').startsWith(prefix)) return true;
  if (sharedSecrets.contains(upperName)) return true;
  return grants[upperName]?.contains(extensionKey) ?? false;
}

/// Secrets any extension may read. Empty, and worth keeping that way: a value
/// here is one every bundle in the app can see.
const sharedSecrets = <String>{};

/// Secret name → the extension keys allowed to read it, for the case where a
/// value does not belong to any one extension by name. Empty today; the prefix
/// rule has covered everything so far.
const grants = <String, List<String>>{};
