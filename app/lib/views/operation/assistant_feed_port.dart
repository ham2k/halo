// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/widgets.dart';

import '../../services/assistant_service.dart';
import '../../services/panel_service.dart';

/// Hands a view's [PanelRenderContext] to its [AssistantFeed] each time the
/// view builds, the way an extension pane is handed it — so an assistant and a
/// panel wake on the same changes, without a pane anywhere.
class AssistantFeedPort extends StatefulWidget {
  final AssistantFeed feed;
  final PanelRenderContext renderContext;
  final Widget child;

  const AssistantFeedPort({super.key, required this.feed, required this.renderContext, required this.child});

  @override
  State<AssistantFeedPort> createState() => _AssistantFeedPortState();
}

class _AssistantFeedPortState extends State<AssistantFeedPort> {
  @override
  void initState() {
    super.initState();
    widget.feed.update(widget.renderContext);
  }

  @override
  void didUpdateWidget(AssistantFeedPort old) {
    super.didUpdateWidget(old);
    widget.feed.update(widget.renderContext);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
