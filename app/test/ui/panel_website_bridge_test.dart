// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Web Site pane shows a page anyone may have written, scripts and frames
// included. With the plugin's JavaScript bridge on, that page can post
// messages into the plugin's native code, and a malformed one crashes the
// whole app on macOS and Windows. The pane uses no bridge handler, so the
// bridge stays off; this pins it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/views/operation/website/website_panel.dart';

void main() {
  test('the Web Site pane runs a page\'s scripts but gives them no bridge into the app', () {
    final settings = websitePanelSettings();
    expect(settings.javaScriptEnabled, isTrue, reason: 'the case under test: a page with scripts');
    expect(settings.javaScriptBridgeEnabled, isFalse);
  });

  // Read from the source because `flutter test` registers no web-view
  // platform, and building the pane's InAppWebView throws before there is a
  // widget to read settings from. Settings written inline beside these, or
  // set on the controller later, would leave the test above green while the
  // pane hands every page a bridge.
  test('the pane\'s web view is built with those settings and no others', () {
    final source = File('lib/views/operation/website/website_panel.dart').readAsStringSync();
    expect(source, contains('initialSettings: websitePanelSettings()'));
    expect('InAppWebViewSettings('.allMatches(source).length, 1, reason: 'only websitePanelSettings builds settings for the pane');
    expect(source, isNot(contains('setSettings(')), reason: 'settings changed after load could turn the bridge back on');
  });
}
