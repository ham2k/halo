// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_build_tools/halo_build_tools.dart' show Edition;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/services/agent_link/agent_link_command.dart';
import 'package:ham2k_logger/services/agent_link/agent_link_model.dart';
import 'package:ham2k_logger/services/agent_link/agent_link_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/settings/connected_apps_settings_group.dart';
import 'package:ham2k_logger/settings/integrations_settings_group.dart';

AgentLinkCommand? _resolve({
  Edition edition = Edition.prod,
  required String executable,
  Map<String, String> environment = const {},
  bool windows = false,
  String? arch,
  Set<String> files = const {},
}) => agentLinkCommand(edition: edition, executable: executable, environment: environment, windows: windows, arch: arch, exists: files.contains);

void main() {
  const macApp = '/Applications/Ham2K Logger.app/Contents/MacOS';

  test('an installed build runs the halo-mcp beside its executable, with no edition for Regular', () {
    final command = _resolve(executable: '$macApp/Ham2K Logger', files: {'$macApp/halo-mcp'})!;
    expect(command.command, '$macApp/halo-mcp');
    expect(command.args, isEmpty);
    expect(command.serverName, 'ham2k-logger');
  });

  // halo-mcp defaults to Regular's port: a Next or Dev install whose
  // command left the edition out would reach the wrong app, or none.
  test('every edition but Regular names itself, and lists under its own server name', () {
    for (final edition in [Edition.next, Edition.dev]) {
      final command = _resolve(edition: edition, executable: '$macApp/Ham2K Logger', files: {'$macApp/halo-mcp'})!;
      expect(command.args, ['--edition', edition.name]);
      expect(agentLinkPort(Edition.values.byName(command.args.last)), isNot(agentLinkPort(Edition.prod)));
      expect(command.serverName, 'ham2k-logger-${edition.name}');
    }
  });

  // Inside an AppImage the bundled command's path exists only while the
  // AppImage runs, and changes each time: only the AppImage's own path is
  // one an agent app can keep.
  test('an AppImage runs halo-mcp through its own mcp subcommand, whatever is beside the executable', () {
    final command = _resolve(
      edition: Edition.next,
      executable: '/tmp/.mount_Ham2Kx/ham2k_logger',
      environment: {'APPIMAGE': '/home/op/Apps/Ham2K-Logger-Next.AppImage', 'APPDIR': '/tmp/.mount_Ham2Kx'},
      files: {'/tmp/.mount_Ham2Kx/halo-mcp'},
    )!;
    expect(command.command, '/home/op/Apps/Ham2K-Logger-Next.AppImage');
    expect(command.args, ['mcp', '--edition', 'next']);
  });

  // A Dart executable cannot be made universal, so a universal Mac app
  // carries one per architecture, and an Intel Mac cannot run the arm64 one.
  test('a universal Mac app runs the halo-mcp for the Mac it is on', () {
    final files = {'$macApp/halo-mcp-arm64', '$macApp/halo-mcp-x64'};
    expect(_resolve(executable: '$macApp/Ham2K Logger', arch: 'arm64', files: files)!.command, '$macApp/halo-mcp-arm64');
    expect(_resolve(executable: '$macApp/Ham2K Logger', arch: 'x64', files: files)!.command, '$macApp/halo-mcp-x64');
  });

  test('the architecture comes from the Dart VM\'s own description', () {
    expect(dartArch('3.12.2 (stable) (Tue Jun 9 01:11:39 2026 -0700) on "macos_arm64"'), 'arm64');
    expect(dartArch('3.12.2 (stable) on "windows_x64"'), 'x64');
    expect(dartArch('something else'), isNull);
  });

  // AppImages hand APPIMAGE down to everything they start: a tarball build
  // or a `flutter run` started from an AppImage editor's terminal would
  // otherwise tell the agent app to run the editor.
  test('an APPIMAGE handed down from another AppImage is not this app\'s', () {
    final command = _resolve(
      executable: '/home/op/halo/ham2k_logger',
      environment: {'APPIMAGE': '/home/op/Apps/Cursor.AppImage', 'APPDIR': '/tmp/.mount_Cursorx'},
      files: {'/home/op/halo/halo-mcp'},
    )!;
    expect(command.command, '/home/op/halo/halo-mcp');
    expect(command.args, isEmpty);
  });

  // The path of a Mac app run from its disk image, or opened where it was
  // downloaded, is gone once it quits: a command pasted from there works
  // until then and never again.
  test('a Mac app run from a disk image or a translocated copy has only a temporary command', () {
    for (final dir in [
      '/Volumes/Ham2K Logger/Ham2K Logger.app/Contents/MacOS',
      '/private/var/folders/x/AppTranslocation/1234/d/Ham2K Logger.app/Contents/MacOS',
    ]) {
      expect(_resolve(executable: '$dir/Ham2K Logger', arch: 'arm64', files: {'$dir/halo-mcp-arm64'})!.temporary, isTrue);
    }
    // An app kept on a second drive stays put; calling it temporary would
    // withhold the command from it for good.
    for (final dir in [macApp, '/Volumes/SSD/Applications/Ham2K Logger.app/Contents/MacOS']) {
      expect(_resolve(executable: '$dir/Ham2K Logger', arch: 'arm64', files: {'$dir/halo-mcp-arm64'})!.temporary, isFalse);
    }
  });

  test('a Windows install runs halo-mcp.exe, quoted for a Windows shell', () {
    const dir = r'C:\Users\op\AppData\Local\Programs\Ham2K Logger';
    final command = _resolve(executable: '$dir\\ham2k_logger.exe', windows: true, files: {'$dir\\halo-mcp.exe'})!;
    expect(command.command, '$dir\\halo-mcp.exe');
    expect(command.claudeCodeLine, 'claude mcp add --scope user ham2k-logger -- "$dir\\halo-mcp.exe"');
  });

  test('a development build runs the checkout\'s halo-mcp source', () {
    const checkout = '/Users/op/halo';
    final command = _resolve(
      edition: Edition.dev,
      executable: '$checkout/app/build/macos/Build/Products/Debug/Ham2K Logger Dev.app/Contents/MacOS/Ham2K Logger Dev',
      files: {'$checkout/packages/halo_mcp/bin/halo_mcp.dart'},
    )!;
    expect(command.command, 'dart');
    expect(command.args, ['run', '$checkout/packages/halo_mcp/bin/halo_mcp.dart', '--edition', 'dev']);
  });

  test('a build with no halo-mcp anywhere has no command to offer', () {
    expect(_resolve(executable: '$macApp/Ham2K Logger'), isNull);
  });

  // A path with a space pasted unquoted into a shell is two words, and the
  // agent app is told to run a command that does not exist.
  test('the shell forms quote what a shell would split, and the JSON carries the words as they are', () {
    final command = _resolve(edition: Edition.next, executable: '$macApp/Ham2K Logger', files: {'$macApp/halo-mcp'})!;
    expect(command.commandLine, "'$macApp/halo-mcp' --edition next");
    expect(command.claudeCodeLine, "claude mcp add --scope user ham2k-logger-next -- '$macApp/halo-mcp' --edition next");
    expect(jsonDecode(command.mcpServersJson), {
      'mcpServers': {
        'ham2k-logger-next': {
          'command': '$macApp/halo-mcp',
          'args': ['--edition', 'next'],
        },
      },
    });
  });

  // The setup rows live under Integrations, which owns the settings list's
  // actions: one that does not hand them on leaves every row doing nothing.
  testWidgets('a setup row tapped under Integrations copies its form of the command', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final link = AgentLinkService(store: _NoGrants(), endpoint: _NoEndpoint(), wanted: () => false, port: 0, now: () => 1);
    addTearDown(link.closeForExit);
    final command = _resolve(executable: '$macApp/Ham2K Logger', files: {'$macApp/halo-mcp'})!;
    final integrations = IntegrationsSettingsGroup(settings)
      ..connectedApps = ConnectedAppsSettingsGroup(link: () => link, wanted: () => true, changes: settings, command: () => command);

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(
      TranslationProvider(
        child: const MaterialApp(home: Scaffold(body: SizedBox())),
      ),
    );
    final context = tester.element(find.byType(SizedBox));
    await integrations.openAction(context, 'agentSetup:claudeCode');
    expect(copied, command.claudeCodeLine);
    await integrations.openAction(context, 'agentSetup:json');
    expect(copied, command.mcpServersJson);
    await tester.pump();
  });
}

class _NoGrants implements AgentGrantStore {
  @override
  Map<String, dynamic> read() => const {};
  @override
  Future<void> write(Map<String, dynamic> grants) async {}
}

class _NoEndpoint implements AgentLinkEndpoint {
  @override
  bool get available => false;

  @override
  Listenable get news => const _Never();

  @override
  Future<List<Map<String, dynamic>>> handle({
    required String connection,
    required AgentClient client,
    required AgentAccess access,
    required Map<String, dynamic> message,
  }) async => const [];
}

class _Never implements Listenable {
  const _Never();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
