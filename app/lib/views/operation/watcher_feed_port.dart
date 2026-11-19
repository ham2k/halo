// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/widgets.dart';

import '../../services/panel_service.dart';
import '../../services/watcher_service.dart';

/// Hands a view's [PanelRenderContext] to its [WatcherFeed]s — the
/// assistants' and the integrations' — each time the view builds, the way an
/// extension pane is handed it, so they and a panel wake on the same changes,
/// without a pane anywhere.
class WatcherFeedPort extends StatefulWidget {
  final List<WatcherFeed> feeds;
  final PanelRenderContext renderContext;
  final Widget child;

  const WatcherFeedPort({super.key, required this.feeds, required this.renderContext, required this.child});

  @override
  State<WatcherFeedPort> createState() => _WatcherFeedPortState();
}

class _WatcherFeedPortState extends State<WatcherFeedPort> {
  void _feed() {
    for (final feed in widget.feeds) {
      feed.update(widget.renderContext);
    }
  }

  @override
  void initState() {
    super.initState();
    _feed();
  }

  @override
  void didUpdateWidget(WatcherFeedPort old) {
    super.didUpdateWidget(old);
    _feed();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
