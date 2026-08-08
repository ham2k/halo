// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A page the Web Site pane could not load, typed so ErrorPolicy can tell it
// apart from a defect.
//
// The same reasoning as [MapError], and for the same operator: a pane on a
// refresh interval retries on a schedule, so an off-grid activation fails
// every single one. Untyped, those fall through to the default `notify`
// disposition and upload once per interval for the length of the activation.

import 'package:flutter/foundation.dart';

import 'connectivity_service.dart';

/// A failed load in a Web Site pane. [offline] is the device's connectivity
/// when the failure ARRIVED, not when it is classified — a failure raised
/// with no coverage stays quiet even if the device is back online by the time
/// anyone looks at it.
@immutable
class WebsitePanelError implements Exception {
  /// The placement that failed (`website#1`), so two panes pointed at
  /// different sites are distinguishable in the aggregate.
  final String panelId;

  final String message;
  final bool offline;

  WebsitePanelError({required this.panelId, required this.message}) : offline = ConnectivityService.isOffline;

  @visibleForTesting
  const WebsitePanelError.raw({required this.panelId, required this.message, required this.offline});

  @override
  String toString() => 'WebsitePanelError($panelId${offline ? ', offline' : ''}): $message';
}
