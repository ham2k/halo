// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Off the web there is no `window` to attach `__halo` to, so the bridge
// answers on the Dart VM service every non-release build already runs: one
// `ext.halo.<call>` extension per call, reached by `scripts/halo-dev.mjs`
// through the service address `flutter run` writes out.

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show debugPrint, kReleaseMode;

import 'dev_bridge.dart';

/// Registers the `ext.halo.*` extensions. Gated to non-release builds, like
/// the web bridge: a control surface must never ship to end users.
///
/// Every answer is `{"result": …}`, because the VM service carries only a
/// JSON object back, and several calls answer a list or null.
void installDevBridge() {
  if (kReleaseMode) return;
  final bridge = DevBridge.instance;

  void register(String name, FutureOr<Object?> Function(Map<String, String> params) call) {
    developer.registerExtension('ext.halo.$name', (method, params) async {
      try {
        return developer.ServiceExtensionResponse.result(jsonEncode({'result': await call(params)}));
      } catch (error, stack) {
        // To the run's log as well as the caller: `halo-dev log --errors`
        // reads only the log, and the caller's terminal may be long gone.
        debugPrint('[dev-bridge] ext.halo.$name failed: $error\n$stack');
        return developer.ServiceExtensionResponse.error(developer.ServiceExtensionResponse.extensionError, '$error\n$stack');
      }
    });
  }

  register('state', (_) => bridge.state());
  register('guess', (_) => bridge.guess());
  register('build', (_) => bridge.build());
  register('recentLog', (_) => bridge.recentLog());
  register('setField', (params) => bridge.setField(params['field'] ?? 'call', params['value'] ?? ''));
  register('tap', (params) => bridge.tap(params['target'] ?? ''));
  register('targets', (_) => bridge.targets());
  register('runCommand', (params) => bridge.runCommand(params['text'] ?? ''));
  register('commandBarState', (_) => bridge.commandBarState());
  register('resetFixture', (_) => bridge.resetFixture());
  register('settings', (params) => bridge.settings(params['match'] ?? ''));
  register('sql', (params) => bridge.sql(params['query'] ?? ''));
  // Answers false rather than holding the call open past the caller's own
  // timeout, after which nothing would read the answer.
  register('ready', (params) async {
    final wait = Duration(milliseconds: int.tryParse(params['timeoutMs'] ?? '') ?? 60000);
    return bridge.ready.then((_) => true).timeout(wait, onTimeout: () => false);
  });
  bridge.installed = true;
}
