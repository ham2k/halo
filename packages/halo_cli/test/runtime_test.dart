// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The integration this whole package rests on: a plain Dart VM booting the
// real QuickJS host against the real built bundles.
//
// It is worth a slow test. Everything else here is argument shuffling; if
// this stops working — a Flutter import creeping back into
// halo_extension_host, an engine library that no longer loads outside
// `flutter test` — every command fails at once and no unit test would say so.

import 'dart:io';

import 'package:halo_cli/src/bundles.dart';
import 'package:halo_cli/src/config.dart';
import 'package:halo_cli/src/host_calls.dart';
import 'package:halo_cli/src/runtime.dart';
import 'package:test/test.dart';

void main() {
  late BundleIndex index;
  late ExtRuntime runtime;

  setUpAll(() {
    // A missing bundle is a FAILURE, not a skip: scripts/test.sh builds them
    // first precisely so these can rely on it, so a guard that skipped could
    // only fire once that ordering had already broken — when a green run is
    // most misleading.
    index = BundleIndex.load();
  });

  Future<ExtRuntime> start({Set<String> only = const {'radio-commands', 'dev-commands'}}) async {
    final config = CliConfig(settings: const {'developerMode': true});
    final calls = CliHostCalls(config: config, index: index);
    return runtime = await ExtRuntime.start(
      index: index,
      config: config,
      onHostCall: calls.call,
      only: only,
    );
  }

  tearDown(() async => runtime.stop());

  test('boots the real engine and runs a hook', () async {
    await start();
    expect(runtime.host.engine, contains('quickjs'));

    final results = await runtime.host.invokeHookAll('command', method: 'interpret', args: {'input': '14285'});
    final matched = results.where((entry) => entry['ok'] == true && entry['value'] != null);
    expect(matched, hasLength(1), reason: 'exactly one command hook should claim a frequency');
    expect((matched.single['value'] as Map)['commands'], [
      {
        'setVfo': {'freq': 14285}
      }
    ]);
  });

  test('--only loads exactly what was asked for, core included or not', () async {
    // Debugging one extension means running that extension, not it plus
    // fifteen others whose hooks also answer the same category.
    await start(only: const {'radio-commands'});
    expect([for (final entry in runtime.loaded) entry.key], ['radio-commands']);

    final results = await runtime.host.invokeHookAll('command', method: 'interpret', args: {'input': 'DEVMODE'});
    expect(results.where((entry) => entry['value'] != null), isEmpty,
        reason: 'dev-commands was not loaded, so nothing should interpret DEVMODE');
  });

  test('an unknown --only key is named rather than silently ignored', () async {
    expect(
      () => start(only: const {'radio-commands', 'no-such-extension'}),
      throwsA(isA<CliUsageError>().having((e) => e.message, 'message', contains('no-such-extension'))),
    );
    // Nothing booted, so tearDown has nothing to stop.
    runtime = await start(only: const {'radio-commands'});
  });

  test('the kernel reports the hooks that actually registered', () async {
    // The manifest's `hooks` array is a claim; this is the fact. They differ
    // exactly when something went wrong (an activation that threw halfway, a
    // key the namespacing rule refused), which is when somebody asks.
    await start(only: const {'radio-commands'});
    final hooks = await runtime.host.invokeHook('runtime', key: 'kernel', method: 'listHooks') as List;
    final commandHooks = hooks.cast<Map>().where((hook) => hook['category'] == 'command');
    expect(commandHooks, isNotEmpty);
    expect(commandHooks.first['methods'], contains('interpret'));
    expect(commandHooks.every((hook) => hook['extensionKey'] == 'radio-commands'), isTrue);
  });

  test('the user agent names halo-ext, not the app', () {
    // Third-party APIs see this traffic. A debugging CLI must be
    // distinguishable from the product hitting the same endpoint.
    final agent = cliUserAgent(index);
    expect(agent, startsWith('Ham2K halo-ext/'));
    expect(agent, contains(Platform.operatingSystem));
  });
}
