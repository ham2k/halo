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
/// [appOnlySecrets] refuses first, whatever the other three would answer.
/// Then three ways to qualify, in order of how most things do:
///
/// 1. **Its own prefix.** `sota` reads `SOTA_*`, `tota` reads `TOTA_*`. This
///    covers every secret in the app today, which is the point — the common
///    case needs no entry anywhere. An extension key containing `-` matches
///    both `-` and `_` in the name (`call-notes` reads `CALL_NOTES_*`).
/// 2. **[sharedSecrets]** — readable by any extension.
/// 3. **[grants]** — readable by the extensions named against it.
bool extensionMaySeeSecret(String extensionKey, String name) {
  final upperName = name.toUpperCase();
  if (appOnlySecrets.contains(upperName)) return false;
  final prefix = '${extensionKey.toUpperCase().replaceAll('-', '_')}_';
  if (upperName.replaceAll('-', '_').startsWith(prefix)) return true;
  if (sharedSecrets.contains(upperName)) return true;
  return grants[upperName]?.contains(extensionKey) ?? false;
}

/// Secrets no extension may read, whatever key it claims — the app's own
/// per-build configuration, consumed by Dart and never handed across the
/// boundary.
///
/// The prefix rule grants by NAME, so a value is reachable by whichever
/// extension key its name happens to begin with, and an extension key is not
/// entirely the app's to choose: the catalog serves Ham2K's own under a
/// reserved prefix, and the app strips that prefix before asking this. A
/// bundle published as `ham2k-pusher` would therefore be asked about as
/// `pusher` and pass the prefix rule. Nothing but this list says it should
/// not.
///
/// Listed by name rather than inferred, because what makes a value app-only is
/// which code consumes it — something no spelling of the name can carry, and
/// the distinction the flat map is missing (README.md's planned secrets
/// service).
///
/// Being refused here says nothing about being confidential. `PUSHER_KEY` and
/// `PUSHER_CLUSTER` are Pusher's client-side identifiers, public by design and
/// shipped by every Pusher client SDK; the confidential half of a Pusher app
/// is its `secret`, which lives on api-lofi and never reaches a build. They
/// are listed because `PusherService` is the only thing that wants them, not
/// because they would do harm.
const appOnlySecrets = <String>{'PUSHER_KEY', 'PUSHER_CLUSTER'};

/// Secrets any extension may read. Empty, and worth keeping that way: a value
/// here is one every bundle in the app can see.
const sharedSecrets = <String>{};

/// Secret name → the extension keys allowed to read it, for the case where a
/// value does not belong to any one extension by name. Empty today; the prefix
/// rule has covered everything so far.
const grants = <String, List<String>>{};
