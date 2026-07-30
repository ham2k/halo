// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart' show kReleaseMode;

import 'dev_bridge.dart';

/// Installs `window.__halo` with the inspection API (`getState()`, `getGuess()`,
/// `recentLog()`), the control actions (`setField()`, `tap()`), and the `ready`
/// promise — the getters return plain JS objects agents parse via
/// javascript_tool.
///
/// Gated to non-release (debug/profile) builds — where agents run the web app
/// locally (`flutter run -d web-server`). A control surface must never ship to
/// end users. Deployed previews are release builds; extending the gate to them
/// via the preview-URL check (`webPreviewLabel()`, #234) is a one-line
/// follow-up once that lands in `dist`.
void installDevBridge() {
  if (kReleaseMode) return;

  final bridge = JSObject();
  bridge['getState'] = (() => DevBridge.instance.state().jsify()).toJS;
  bridge['getGuess'] = (() => DevBridge.instance.guess().jsify()).toJS;
  bridge['setField'] =
      ((JSString field, JSString value) => DevBridge.instance.setField(field.toDart, value.toDart)).toJS;
  bridge['tap'] = ((JSString action) => DevBridge.instance.action(action.toDart)).toJS;
  // A single stable promise (resolves when signalReady() fires) — `await
  // window.__halo.ready` replaces sleeping after a page load. #239.
  bridge['ready'] = DevBridge.instance.ready.toJS;
  // Buffered structured events ([qso], [lookup], …) — query recent history
  // instead of only streaming the console. #237.
  bridge['recentLog'] = (() => DevBridge.instance.recentLog().jsify()).toJS;
  // Command dialog (#55) — see DevBridge's own note on why the shortcut
  // can't be driven from outside.
  // A Promise: the dialog's route mounts a frame later, so callers must be
  // able to `await` it before typing into the dialog.
  bridge['openCommandBar'] = (() => DevBridge.instance.openCommandBar().toJS).toJS;
  bridge['closeCommandBar'] = (() => DevBridge.instance.closeCommandBar()).toJS;
  bridge['setCommandText'] = ((JSString text) => DevBridge.instance.setCommandText(text.toDart)).toJS;
  bridge['commandSubmit'] = (() => DevBridge.instance.commandSubmit()).toJS;
  bridge['commandMove'] = ((JSNumber delta) => DevBridge.instance.commandMove(delta.toDartInt)).toJS;
  bridge['commandBarState'] = (() => DevBridge.instance.commandBarState().jsify()).toJS;
  // Reset to a known fixture (wipe + seed + known settings), returning a
  // Promise of the summary. #238.
  bridge['resetFixture'] = (() => DevBridge.instance.resetFixture().then((r) => r.jsify()).toJS).toJS;
  globalContext['__halo'] = bridge;
  DevBridge.instance.installed = true;
}
