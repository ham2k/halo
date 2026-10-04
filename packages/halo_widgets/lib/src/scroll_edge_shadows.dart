// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A shadow along each edge of a scroll view that has more content past it:
// the hint that a short, capped list holds more rows than it shows. A row
// cut part-way already suggests it, but only at the bottom and only while
// the cut falls mid-row.

import 'package:flutter/material.dart';

class ScrollEdgeShadows extends StatefulWidget {
  /// A vertical scroll view; the shadows follow the nearest one below.
  final Widget child;

  const ScrollEdgeShadows({super.key, required this.child});

  static const _height = 10.0;

  @override
  State<ScrollEdgeShadows> createState() => _ScrollEdgeShadowsState();
}

class _ScrollEdgeShadowsState extends State<ScrollEdgeShadows> {
  bool _moreAbove = false;
  bool _moreBelow = false;

  // ScrollMetricsNotification as well as ScrollNotification: a list that
  // first lays out taller than its viewport, or grows a row, never scrolls,
  // and would otherwise show no shadow until it did.
  bool _onMetrics(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return false;
    final above = metrics.extentBefore > 0, below = metrics.extentAfter > 0;
    if (above != _moreAbove || below != _moreBelow) {
      setState(() {
        _moreAbove = above;
        _moreBelow = below;
      });
    }
    return false;
  }

  Widget _shadow({required bool visible, required Alignment from}) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: ScrollEdgeShadows._height,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: from, end: -from, colors: [Colors.black.withValues(alpha: 0.22), Colors.black.withValues(alpha: 0)]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NotificationListener<ScrollMetricsNotification>(
          onNotification: (n) => _onMetrics(n.metrics),
          child: NotificationListener<ScrollNotification>(onNotification: (n) => _onMetrics(n.metrics), child: widget.child),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _shadow(visible: _moreAbove, from: Alignment.topCenter),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _shadow(visible: _moreBelow, from: Alignment.bottomCenter),
        ),
      ],
    );
  }
}
