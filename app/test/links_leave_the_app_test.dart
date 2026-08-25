// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A link the app hands off — the QRZ button, a markdown link in a call note,
// an extension's notice action, the expired-build download page — opens in the
// operator's OWN browser, where their QRZ session, their extensions and their
// history are. Never an in-app browser (an Android Custom Tab, an iOS
// SFSafariViewController) wearing the app's chrome.
//
// url_launcher makes the wrong thing the easy thing: `launchUrl(uri)` with no
// mode is `platformDefault`, which IS the in-app browser on both mobile
// platforms. So this reads the source the way no_hover_tooltips_test does —
// one omitted argument is all it takes, and nothing about the call site looks
// wrong.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every `.dart` file under the app's and the widget package's `lib/`.
List<File> _sources() {
  final roots = [Directory('lib'), Directory('../packages/halo_widgets/lib')];
  // Loudly, not vacuously: a suite run from an unexpected cwd would otherwise
  // scan nothing and pass while enforcing nothing at all.
  for (final root in roots) {
    if (!root.existsSync()) {
      fail('expected ${root.path} to exist — run this suite from the app package (cwd: ${Directory.current.path})');
    }
  }
  return [
    for (final root in roots)
      ...root.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')),
  ];
}

void main() {
  test('nothing asks the platform for an in-app browser', () {
    final offenders = <String>[];
    for (final file in _sources()) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Comments are how the convention gets explained, so only code counts.
        if (line.trimLeft().startsWith('//')) continue;
        if (line.contains('LaunchMode.platformDefault') || line.contains('LaunchMode.inAppBrowserView')) {
          offenders.add('${file.path}:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Links leave the app: pass LaunchMode.externalApplication, or call openExternalUrl.\n'
          'Found:\n${offenders.join('\n')}',
    );
  });

  test('every launchUrl names its mode, since the default is the in-app one', () {
    final offenders = <String>[];
    for (final file in _sources()) {
      final source = file.readAsStringSync();
      // Whole file, not line by line: a wrapped call puts the mode on a later
      // line, and a per-line scan would read every one of those as bare.
      for (final match in RegExp(r'\blaunchUrl\s*\(').allMatches(source)) {
        final call = source.substring(match.start, (match.start + 400).clamp(0, source.length));
        final end = call.indexOf(');');
        if (end == -1) continue;
        if (!call.substring(0, end).contains('mode:')) {
          final lineNumber = '\n'.allMatches(source.substring(0, match.start)).length + 1;
          offenders.add('${file.path}:$lineNumber');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'launchUrl without `mode:` is LaunchMode.platformDefault — an in-app browser on mobile.\n'
          'Found:\n${offenders.join('\n')}',
    );
  });
}
