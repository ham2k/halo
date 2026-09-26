// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:js_interop';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// An empty element filling the widget's box, found by the browser before any
/// platform view it lies over — see platform_view_shield.dart.
///
/// Transparent to Flutter's own hit testing: its work is done in the browser,
/// and taking hits there would keep a tap beside a dialog's card from the
/// barrier that closes it. A mousedown on it keeps its default from moving the
/// browser's focus off the text field Flutter is editing.
Widget platformViewBlocker() => HtmlElementView.fromTagName(
  key: const ValueKey('platform-view-blocker'),
  tagName: 'div',
  isVisible: false,
  hitTestBehavior: PlatformViewHitTestBehavior.transparent,
  onElementCreated: (element) {
    element as web.HTMLElement;
    element.style
      ..width = '100%'
      ..height = '100%';
    element.addEventListener('mousedown', ((web.Event event) => event.preventDefault()).toJS);
  },
);
