// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart' show kReleaseMode;

import 'dev_bridge.dart';

/// Installs `window.__halo` with the read-only inspection API — `getState()`
/// and `getGuess()`, both returning plain JS objects agents parse via
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
  globalContext['__halo'] = bridge;
  DevBridge.instance.installed = true;
}
