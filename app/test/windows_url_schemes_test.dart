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
        'com.ham2k.logger',
        'com.ham2k.logger.auth',
        'com.ham2k.polo',
        'com.ham2k.polo.auth',
        'com.ham2k.logger.dev',
        'com.ham2k.logger.dev.auth',
      });
    });

    test('marks every scheme with URL Protocol', () {
      // Without this value the key is a registered class the shell will not
      // treat as a URL handler — registered, and inert.
      for (final scheme in ['com.ham2k', 'com.ham2k.polo.auth', 'com.ham2k.logger.dev']) {
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
      final fromIss = pattern
          .allMatches(iss)
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
