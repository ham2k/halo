// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Windows URL-scheme catalog (HALO-178). These run everywhere, because
// what has to be right is which keys get written and how they are quoted —
// not whether reg.exe ran, which no test here can reach anyway.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/windows_url_schemes.dart';

/// The value written at `<scheme>\shell\open\command`, or null.
String? commandFor(List<SchemeRegistryValue> values, String scheme) {
  for (final v in values) {
    if (v.key == '$scheme\\shell\\open\\command' && v.name.isEmpty) return v.data;
  }
  return null;
}

bool hasUrlProtocolMarker(List<SchemeRegistryValue> values, String scheme) =>
    values.any((v) => v.key == scheme && v.name == 'URL Protocol');

void main() {
  final values = schemeRegistryValues(
    exePath: r'C:\Program Files\Ham2K Logger\ham2k_logger.exe',
    edition: 'dev',
  );

  group('schemeRegistryValues', () {
    test('registers every scheme the app claims on macOS', () {
      // The catalog is one list across platforms — deep_link_service.dart's
      // header and macOS Info.plist. A scheme missing here is a link that
      // opens on a Mac and does nothing on Windows.
      final schemes = values.where((v) => v.name == 'URL Protocol').map((v) => v.key).toSet();
      expect(schemes, {
        'com.ham2k',
        'com.ham2k.halo',
        'com.ham2k.halo.dev',
        'com.ham2k.halo.dev.auth',
        'com.ham2k.logger',
        'com.ham2k.logger.auth',
        'com.ham2k.logger.dev',
        'com.ham2k.logger.dev.auth',
      });
    });

    test('claims nothing under com.ham2k.polo, on any edition', () {
      // HaLo used to register PoLo's schemes so a PoLo link would still land.
      // It must not: onboarding asks canOpenURL/PackageManager whether PoLo is
      // installed (HALO-526), and a claim here makes this app answer its own
      // question — "PoLo is here" on a machine that has never had it. Windows
      // cannot run PoLo at all, so the claim is pure downside; the check lives
      // here because this table is where reinstating one is tempting.
      for (final edition in ['dev', 'next', 'prod']) {
        final schemes = schemeRegistryValues(exePath: r'C:\HaLo\app.exe', edition: edition)
            .where((v) => v.name == 'URL Protocol')
            .map((v) => v.key);
        expect(schemes.where((s) => s.startsWith('com.ham2k.polo')), isEmpty, reason: edition);
      }
    });

    test('marks every scheme with URL Protocol', () {
      // Without this value the key is a registered class the shell will not
      // treat as a URL handler — registered, and inert.
      for (final scheme in ['com.ham2k', 'com.ham2k.halo.dev.auth', 'com.ham2k.logger.dev']) {
        expect(hasUrlProtocolMarker(values, scheme), isTrue, reason: scheme);
      }
    });

    test('quotes the exe path and %1 separately', () {
      // Program Files has a space, and so can a link. Unquoted, the shell
      // splits either one into two arguments — and app_links reads argv[1]
      // alone, so it would see a truncated URL and silently ignore it.
      expect(commandFor(values, 'com.ham2k'), r'"C:\Program Files\Ham2K Logger\ham2k_logger.exe" "%1"');
    });

    test('scopes the edition-specific schemes to the edition given', () {
      final next = schemeRegistryValues(exePath: r'C:\HaLo\ham2k_logger.exe', edition: 'next');
      final schemes = next.where((v) => v.name == 'URL Protocol').map((v) => v.key);
      expect(schemes, contains('com.ham2k.halo.next'));
      expect(schemes, isNot(contains('com.ham2k.halo.dev')));
      expect(schemes, contains('com.ham2k.logger.next'));
      expect(schemes, isNot(contains('com.ham2k.logger.dev')));
      // The shared ones are NOT edition-scoped — that is what makes them
      // last-one-wins, and what a companion app sending `com.ham2k://` needs.
      expect(schemes, contains('com.ham2k'));
    });
  });

  group('regAddArguments', () {
    test('writes the default value with /ve, a named one with /v', () {
      // reg.exe spells these differently, and `/v ""` is not the same as
      // `/ve`: the first creates a value literally named empty-string, which
      // the shell never reads.
      expect(regAddArguments((key: 'com.ham2k', name: '', data: 'URL:Ham2K')),
          containsAllInOrder(['add', r'HKCU\Software\Classes\com.ham2k', '/ve']));
      expect(regAddArguments((key: 'com.ham2k', name: 'URL Protocol', data: '')),
          containsAllInOrder(['/v', 'URL Protocol']));
    });

    test('overwrites without prompting', () {
      // A portable copy that MOVED re-registers to repoint itself, and a
      // confirmation prompt nobody can see would hang the app.
      expect(regAddArguments((key: 'com.ham2k', name: '', data: 'x')), contains('/f'));
    });

    test('passes the data as one argument, unquoted', () {
      // Process.run does not go through a shell, so the command string must
      // arrive whole — adding quotes here would write them INTO the registry
      // value and break every link.
      final args = regAddArguments((key: 'k', name: '', data: r'"C:\a b\x.exe" "%1"'));
      expect(args, contains(r'"C:\a b\x.exe" "%1"'));
    });
  });

  group('the installer and this catalog register the same schemes', () {
    // The header says to keep the two lists in step, and nothing enforced it.
    // Drift here is invisible until a portable copy silently fails to answer
    // a link an installed one does — so the .iss is read, not trusted.
    test('every scheme in the Inno script is in the Dart catalog, and back', () {
      final iss = File('windows/installer/ham2k-logger.iss').readAsStringSync();
      // `Software\Classes\<scheme>` where the scheme starts with com.ham2k —
      // the ProgID rows use a different prefix and are correctly skipped.
      // A-Z included because the edition rows are templated as
      // `com.ham2k.logger.{#HaloEdition}` — a lowercase-only class stops at
      // the brace and silently drops them from the comparison.
      final pattern = RegExp(r'Software\\Classes\\(com\.ham2k[A-Za-z0-9.{}#]*)"');
      final fromIss = iss
          .split('\n')
          // `Flags: deletekey` rows REMOVE a scheme (the stale com.ham2k.polo*
          // handlers an upgrade would otherwise leave behind). Counting one as
          // a registration would demand the Dart catalog claim the very scheme
          // the installer exists to delete.
          //
          // Word-anchored, because `uninsdeletekey` CONTAINS `deletekey` and
          // means the opposite — it registers a key and removes it at
          // uninstall. A substring test drops all four edition rows, and this
          // comparison still passes only because those schemes happen to
          // appear on other rows too; consolidate the .iss and the guard would
          // quietly stop covering them.
          .where((line) => !RegExp(r'\bdeletekey\b').hasMatch(line))
          .expand(pattern.allMatches)
          .map((m) => m.group(1)!)
          // The edition rows are templated; normalize to the same 'dev' the
          // catalog below is built with.
          .map((s) => s.replaceAll('{#HaloEdition}', 'dev'))
          .toSet();
      expect(fromIss, isNotEmpty, reason: 'the .iss regex matched nothing — has the file moved?');

      final fromDart = schemeRegistryValues(exePath: r'C:\x\x.exe', edition: 'dev')
          .where((v) => v.name == 'URL Protocol')
          .map((v) => v.key)
          .toSet();
      expect(fromIss, equals(fromDart));
    });

    test('the edition rows survive the deletekey filter', () {
      // `uninsdeletekey` contains `deletekey`, so a substring filter drops
      // every edition row and the comparison above silently narrows to the
      // shared schemes. It would still pass — those editions appear on other
      // rows — which is why this asserts on the filter's own subject rather
      // than on the comparison's result.
      final iss = File('windows/installer/ham2k-logger.iss').readAsStringSync();
      final kept = iss
          .split('\n')
          .where((line) => !RegExp(r'\bdeletekey\b').hasMatch(line))
          .join('\n');
      expect(kept, contains(r'com.ham2k.logger.{#HaloEdition}'));
      expect(kept, contains(r'com.ham2k.halo.{#HaloEdition}'));
      // ...and the rows it exists to drop are gone. Registry rows only: the
      // [Code] section names the polo schemes too, to unregister them, and
      // that mention is not a claim.
      expect(kept, isNot(contains(r'Software\Classes\com.ham2k.polo')));
    });
  });

  group('stale scheme cleanup', () {
    test('names exactly the schemes the catalog no longer claims', () {
      // Registering cannot repair these: `reg add` writes the keys it is given
      // and leaves every other one alone, so a scheme dropped from the catalog
      // keeps pointing wherever it last did. A copy that registered before
      // HALO-526 therefore answers com.ham2k.polo:// forever unless it is
      // deleted outright.
      expect(staleUrlSchemes, ['com.ham2k.polo', 'com.ham2k.polo.auth']);
      final claimed = schemeRegistryValues(exePath: r'C:\x\x.exe', edition: 'dev').map((v) => v.key);
      for (final stale in staleUrlSchemes) {
        expect(claimed, isNot(contains(stale)), reason: 'deleting a scheme the catalog also claims');
      }
    });

    test('deletes under the same HKCU root the in-app registration writes', () {
      // The installer's migration writes HKA; this path writes HKCU, and the
      // installer's own notes say HKCU keys SHADOW the machine ones. Deleting
      // anywhere else would leave the shadowing key answering.
      expect(regDeleteArguments('com.ham2k.polo'), [
        'delete',
        r'HKCU\Software\Classes\com.ham2k.polo',
        '/f',
      ]);
    });
  });

  group('registerWindowsUrlSchemes', () {
    test('answers with a message off Windows instead of throwing', () {
      // The caller shows whatever comes back and has no catch of its own, so
      // every path has to be a message.
      expect(Platform.isWindows, isFalse, reason: 'this expectation only holds off Windows');
      expect(registerWindowsUrlSchemes(edition: 'dev'), completion(isNotNull));
    });
  });
}
