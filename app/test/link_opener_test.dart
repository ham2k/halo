// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The scheme allowlist is the whole reason openExternalUrl exists, so it gets a
// fence: the URLs reaching it are authored by extensions and by community
// call-notes files, not by the operator.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/link_opener.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _RecordingLauncher extends UrlLauncherPlatform with MockPlatformInterfaceMixin {
  final launched = <({String url, PreferredLaunchMode? mode})>[];

  @override
  final LinkDelegate? linkDelegate = null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add((url: url, mode: options.mode));
    return true;
  }
}

void main() {
  late _RecordingLauncher launcher;

  setUp(() {
    launcher = _RecordingLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  Future<void> settle(WidgetTester tester) => tester.pump(Duration.zero);

  testWidgets('opens http, https and mailto', (tester) async {
    openExternalUrl('https://ham2k.com');
    openExternalUrl('http://ham2k.com');
    openExternalUrl('mailto:sd@ham2k.com');
    await settle(tester);

    expect(launcher.launched.map((l) => l.url).toList(), [
      'https://ham2k.com',
      'http://ham2k.com',
      'mailto:sd@ham2k.com',
    ]);
  });

  // An extension or a notes file could carry either of these; neither should
  // reach the platform just because nobody thought to exclude it.
  testWidgets('refuses javascript: and file:', (tester) async {
    openExternalUrl('javascript:alert(1)');
    openExternalUrl('file:///etc/passwd');
    await settle(tester);

    expect(launcher.launched, isEmpty);
  });

  testWidgets('refuses a scheme-less or unparseable url rather than guessing', (tester) async {
    openExternalUrl('qrz.com/db/K1ABC');
    openExternalUrl('');
    openExternalUrl('::::');
    await settle(tester);

    expect(launcher.launched, isEmpty);
  });

  // Uri normalizes the scheme's case itself, so an odd-cased URL is fine —
  // pinned so nobody "fixes" it by lowercasing twice or, worse, not at all.
  testWidgets('accepts an upper-case scheme', (tester) async {
    openExternalUrl('HTTPS://ham2k.com');
    await settle(tester);

    expect(launcher.launched, hasLength(1));
  });

  testWidgets('leaves the app by default, and stays in it when asked to', (tester) async {
    openExternalUrl('https://ham2k.com');
    openExternalUrl('https://ham2k.com', mode: LaunchMode.platformDefault);
    await settle(tester);

    expect(launcher.launched[0].mode, PreferredLaunchMode.externalApplication);
    expect(launcher.launched[1].mode, PreferredLaunchMode.platformDefault);
  });
}
