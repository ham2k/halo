// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The operator's supporter badges and the way to contribute, pinned to the
// foot of the Settings sidebar — app-polo's MainSettingsForDistribution. Only
// in a build that sells support, which supplies the artwork.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../../services/halo_services.dart';
import '../../services/purchase_flows.dart';
import '../../services/purchase_service.dart';

/// The badges [art] holds that the operator has earned, oldest first: by an
/// active store entitlement, or by a grant in their per-callsign `badges`
/// flag (app-polo's), which is how support given outside the stores is
/// recognised.
List<SupporterBadgeArt> supporterBadges(SupporterArt art, Map<String, dynamic> flags, Set<String> entitlements) {
  final granted = flags['badges'];
  return [
    for (final badge in art.badges)
      if (entitlements.contains(badge.key) || (granted is Map && granted[badge.key] == true)) badge,
  ];
}

/// [child], the sidebar's scrollable list, with the supporter row pinned
/// below it. The row folds away while the operator scrolls the list down and
/// comes back when they scroll up. It folds only when the list would still
/// scroll without it: otherwise the room isn't needed, and with nothing left
/// to scroll there would be no way to bring it back.
class SupporterFooter extends StatefulWidget {
  final HaLoServices services;
  final Widget child;

  const SupporterFooter({super.key, required this.services, required this.child});

  @override
  State<SupporterFooter> createState() => _SupporterFooterState();
}

class _SupporterFooterState extends State<SupporterFooter> {
  static const _foldDuration = Duration(milliseconds: 200);

  final _footer = GlobalKey();
  var _folded = false;

  bool _onNotification(Notification notification) {
    if (notification is UserScrollNotification && notification.depth == 0) {
      final height = _footer.currentContext?.size?.height ?? 0;
      switch (notification.direction) {
        case ScrollDirection.reverse when !_folded && notification.metrics.maxScrollExtent > height:
          setState(() => _folded = true);
        case ScrollDirection.forward when _folded:
          setState(() => _folded = false);
        default:
      }
    } else if (notification is ScrollMetricsNotification && notification.depth == 0 && _folded && notification.metrics.maxScrollExtent <= 0) {
      // The list grew room for everything (a taller window) while folded.
      setState(() => _folded = false);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final art = widget.services.purchases.supporterArt;
    if (!widget.services.purchases.isAvailable || art == null) return widget.child;
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: NotificationListener<Notification>(onNotification: _onNotification, child: widget.child),
        ),
        // The shadow sits outside the clip, which would cut it off, and goes
        // with the row when it folds.
        AnimatedContainer(
          duration: _foldDuration,
          decoration: BoxDecoration(
            // The notice card's paper faded well into the surface: warm enough
            // to set the row apart, too faint to read as a notice, and fainter
            // at night, where the same share of yellow turns olive.
            color: Color.lerp(theme.colorScheme.surface, HaLoColors.of(context).notice, theme.brightness == Brightness.light ? 0.28 : 0.1),
            // Brown, to go with the paper; the same in both themes, as the paper is.
            border: const Border(top: BorderSide(color: Color(0xFFB07B4B))),
            boxShadow: [if (!_folded) BoxShadow(color: theme.colorScheme.shadow.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, -2))],
          ),
          child: ClipRect(
            child: AnimatedAlign(
              alignment: Alignment.topCenter,
              heightFactor: _folded ? 0 : 1,
              duration: _foldDuration,
              curve: Curves.easeOut,
              child: ExcludeFocus(
                excluding: _folded,
                child: ExcludeSemantics(
                  excluding: _folded,
                  child: SupporterRow(key: _footer, services: widget.services, art: art),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SupporterRow extends StatefulWidget {
  final HaLoServices services;
  final SupporterArt art;

  const SupporterRow({super.key, required this.services, required this.art});

  @override
  State<SupporterRow> createState() => _SupporterRowState();
}

class _SupporterRowState extends State<SupporterRow> {
  static const _badgeSize = 88.0;

  static const _inset = EdgeInsets.symmetric(horizontal: Space.lg);

  @override
  void initState() {
    super.initState();
    unawaited(identifyPurchaser(widget.services));
  }

  Future<void> _contribute() async {
    final result = await presentPaywall(widget.services);
    if (!mounted || result != PurchaseResult.unavailable) return;
    ScaffoldMessenger.of(context).showSnackBar(haloSnackBar(context.t.settings.syncPanel.purchaseUnavailable));
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    final art = widget.art;
    return ListenableBuilder(
      listenable: Listenable.merge([services.purchases.entitlements, services.flags, services.settings]),
      builder: (context, _) {
        final badges = supporterBadges(art, services.flags.flags, services.purchases.entitlements.value);
        final call = services.settings.activeProfile.operatorCall;
        final current = art.badges.isNotEmpty && badges.contains(art.badges.last);
        // The translation places the call, so the sentence is built around a
        // marker, and the call set in the callsign face where it lands.
        const marker = '\u0000';
        final supporter = context.t.settings.supporter;
        final heading = (badges.isEmpty ? supporter.couldBeSupporter(call: marker) : supporter.isSupporter(call: marker)).split(marker);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.md),
          child: Column(
            children: [
              Padding(
                padding: _inset,
                child: Text.rich(
                  TextSpan(
                    children: [
                      for (final (index, part) in heading.indexed) ...[
                        if (index > 0)
                          TextSpan(
                            text: call,
                            style: const TextStyle(fontFamily: 'RobotoMono'),
                          ),
                        TextSpan(text: part),
                      ],
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: Space.sm),
              // One line that scrolls sideways, starting at its end so the
              // contribute button shows however many badges come before it.
              LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  padding: _inset,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth - _inset.horizontal),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: Space.sm,
                      children: [
                        for (final badge in badges)
                          Image(
                            image: badge.image,
                            width: _badgeSize,
                            height: _badgeSize,
                            semanticLabel: context.t.settings.supporter.badge(year: badge.year),
                          ),
                        Semantics(
                          button: true,
                          label: context.t.settings.supporter.contribute,
                          excludeSemantics: true,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            mouseCursor: SystemMouseCursors.click,
                            onTap: () => unawaited(_contribute()),
                            child: Image(image: current ? art.contributeMore : art.contributeNow, width: _badgeSize, height: _badgeSize),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
