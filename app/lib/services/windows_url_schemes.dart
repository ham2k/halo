// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Registering the `com.ham2k*://` URL schemes on Windows from inside the app
// (HALO-178), for the builds no installer ever runs for: the signed portable
// zip, and a tree built locally.
//
// The INSTALLER is the normal path and owns the same SCHEMES — see
// `windows/installer/ham2k-logger.iss`'s `[Registry]` section. Keep the two
// lists in step: a scheme added there and not here is one a portable install
// silently cannot answer. The two are not value-for-value identical (the
// installer labels its edition keys from `{#AppName}`, which this cannot
// see), and nothing depends on them being so — only on the same set of
// schemes resolving to the same exe.
//
// Driven through `reg.exe` rather than a native method channel or the `win32`
// package. The app needs no registry access anywhere else, a channel would be
// native code that `scripts/test.sh` never compiles and no test here can
// reach, and `reg.exe` fails loudly with an exit code and a message. What is
// left in Dart — which keys, holding what — is then ordinary testable logic,
// which is the part that actually has to be right.

import 'dart:io';

/// One registry value to write: `HKCU\Software\Classes\<key>`, `name` empty
/// for the key's default value.
typedef SchemeRegistryValue = ({String key, String name, String data});

/// The schemes any Ham2K app may answer, shared by every edition installed on
/// a machine — so whoever registers last owns them, exactly as the installer
/// arranges it.
/// PoLo's own `com.ham2k.polo*` are deliberately absent, here as on every
/// other platform: a Ham2K app that claims them cannot then ask whether PoLo
/// is installed, because it would be answering its own question (HALO-526).
const sharedUrlSchemes = <String, String>{
  'com.ham2k': 'URL:Ham2K',
  // Official HaLo prefix.
  'com.ham2k.logger': 'URL:Ham2K Logger',
  'com.ham2k.logger.auth': 'URL:Ham2K Logger Sign-in',
  // Alias under HaLo's own name.
  'com.ham2k.halo': 'URL:Ham2K Logger',
};

/// Every value that must exist for [exePath] to answer the catalog, in the
/// order it should be written.
///
/// `URL Protocol` is the marker that makes a class a URL handler at all — an
/// empty-STRING value, not an absent one, and a key carrying everything else
/// but this is registered as far as the registry is concerned and ignored as
/// far as the shell is concerned.
///
/// The command is quoted around both halves: `%1` unquoted splits a link
/// containing a space into two arguments (and `app_links` reads `argv[1]`
/// only, so it would see a truncated URL), while an unquoted exe path breaks
/// on the space in `Program Files`.
List<SchemeRegistryValue> schemeRegistryValues({required String exePath, required String edition}) {
  final values = <SchemeRegistryValue>[];
  final command = '"$exePath" "%1"';
  void add(String scheme, String label) {
    values.add((key: scheme, name: '', data: label));
    values.add((key: scheme, name: 'URL Protocol', data: ''));
    values.add((key: '$scheme\\DefaultIcon', name: '', data: '$exePath,0'));
    values.add((key: '$scheme\\shell\\open\\command', name: '', data: command));
  }

  sharedUrlSchemes.forEach(add);
  // Edition-specific, and unambiguous: nothing else ever claims these, so a
  // Dev install keeps answering its own links whatever else is on the machine.
  add('com.ham2k.logger.$edition', 'URL:Ham2K Logger ($edition)');
  add('com.ham2k.logger.$edition.auth', 'URL:Ham2K Logger ($edition) Sign-in');
  add('com.ham2k.halo.$edition', 'URL:Ham2K Logger ($edition)');
  add('com.ham2k.halo.$edition.auth', 'URL:Ham2K Logger ($edition) Sign-in');
  return values;
}

/// The `reg.exe add` arguments for [value]. Split out so the quoting is
/// testable without running anything.
///
/// `/f` overwrites without prompting — re-registering is how a portable copy
/// that has MOVED repoints its schemes, and a prompt no one can see would
/// hang the app instead.
List<String> regAddArguments(SchemeRegistryValue value) => [
  'add',
  'HKCU\\Software\\Classes\\${value.key}',
  if (value.name.isNotEmpty) ...['/v', value.name] else '/ve',
  '/t',
  'REG_SZ',
  '/d',
  value.data,
  '/f',
];

/// Schemes a Ham2K logger may have registered once and must not hold now.
///
/// Registering the catalog cannot repair these on its own: `reg add` writes
/// the keys it is given and leaves every other one alone, so a scheme dropped
/// from [sharedUrlSchemes] keeps whatever it was last pointed at.
const staleUrlSchemes = <String>['com.ham2k.polo', 'com.ham2k.polo.auth'];

/// Removes [scheme] and everything under it. `/f` so an absent key is not a
/// prompt on a machine with nobody watching.
List<String> regDeleteArguments(String scheme) => ['delete', 'HKCU\\Software\\Classes\\$scheme', '/f'];

/// Points every scheme in the catalog at THIS executable.
///
/// Returns null on success, or the first failure's message — the caller shows
/// it. Stops at the first failure rather than pressing on: a half-registered
/// catalog answers some links and not others, which is harder to diagnose
/// than none of them.
///
/// Every failure comes back as a MESSAGE, including the ones that arrive as a
/// throw. On the locked-down machine this is most likely to fail on — a policy
/// blocking `reg.exe`, a stripped PATH — `Process.run` raises rather than
/// returning an exit code, and letting that escape would replace the status
/// line the caller is built around with a generic error notice.
Future<String?> registerWindowsUrlSchemes({required String edition}) async {
  if (!Platform.isWindows) return 'Windows only';
  final values = schemeRegistryValues(exePath: Platform.resolvedExecutable, edition: edition);
  try {
    for (final value in values) {
      final result = await Process.run('reg.exe', regAddArguments(value));
      if (result.exitCode != 0) return _failureMessage(result);
    }
    // A copy that registered before HALO-526 wrote com.ham2k.polo* under HKCU
    // pointing at itself, and writing the current catalog does not disturb a
    // key no longer in it. Without this the copy answers com.ham2k.polo://
    // for good — the one claim no Ham2K logger may hold, and the installer's
    // own migration cannot reach it, since that writes HKA and an operator who
    // pressed this button left keys in HKCU that shadow the machine ones.
    for (final scheme in staleUrlSchemes) {
      // An absent key exits non-zero, which is the ordinary case and not a
      // failure: the delete is a repair, and reporting "not found" as an error
      // would fail a registration that fully succeeded.
      await Process.run('reg.exe', regDeleteArguments(scheme));
    }
  } catch (e) {
    return e.toString();
  }
  return null;
}

/// What went wrong, preferring whichever stream said anything.
///
/// `reg.exe` puts some of its `ERROR:` diagnostics on STDOUT, so reading only
/// stderr leaves the operator with a bare exit code and no cause.
String _failureMessage(ProcessResult result) {
  final stderrText = (result.stderr as String? ?? '').trim();
  if (stderrText.isNotEmpty) return stderrText;
  final stdoutText = (result.stdout as String? ?? '').trim();
  if (stdoutText.isNotEmpty) return stdoutText;
  return 'reg.exe exited ${result.exitCode}';
}
