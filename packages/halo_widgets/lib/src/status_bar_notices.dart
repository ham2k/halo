// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The notices: the dismissible "post-it" stack over the footer, and the card
// each one is drawn on. Its own file for size alone; it is part of the status
// bar's library and shares its band and window-fraction constants.

part of 'status_bar.dart';

/// The stack of dismissible "post-it" notices, overlaid above whatever the
/// [StatusBarFooter] is doing. [notices] is oldest-first, and so is the stack:
/// the OLDEST is drawn fully on top until it is dismissed, with the next one
/// peeking a few pixels behind when there's more than one. Notices arrive in
/// bursts (a data-file refresh posts one per file), and a stack that showed
/// the newest would bury the first of them under the rest, so the operator
/// would read them out of order, if at all.
class NoticeStack extends StatefulWidget {
  /// The vertical chrome this widget paints around its card, on top of
  /// whatever the card itself needs. Public so that anything reasoning about
  /// the stack's height — a caller's budget, a test's expected viewport —
  /// reads it rather than re-deriving it from the two paddings, which is a
  /// copy that goes stale silently the next time either one moves.
  static const double bandHeight = _noticeBandHeight;

  final List<StatusBarNoticeData> notices;
  final void Function(String key) onDismiss;

  /// Accessible name for each card's dismiss button (see
  /// [StatusBarFooter.dismissLabel]).
  final String dismissLabel;

  /// How tall the **whole stack** may grow — band included — before the card
  /// inside it scrolls. Null falls back to a fraction of the window, which is
  /// right when this owns the screen and wrong when it is sharing the bottom
  /// strip with the footer, the numbers row and the keyboard; there the caller
  /// has a budget and this is how it says so.
  ///
  /// Deliberately the total, not the card. The band is chrome this widget adds
  /// on its own account, so a caller dividing up a fixed strip cannot pay for
  /// it without knowing these internals — a card-only cap quietly overruns a
  /// tight budget by the whole band. Below [_noticeBandHeight] the
  /// band itself gives way, so this is a bound the widget cannot exceed.
  final double? maxHeight;

  /// The least this stack can be given and still SHOW a notice rather than a
  /// sliver of one: a row of card, plus the band it paints around it. The
  /// footer floors its own cap the same way (`_buildExpanded`) — a notice is
  /// where ErrorPolicy puts what the operator must read, so it may not be the
  /// one piece that silently shrinks to nothing.
  static double minHeightOf(BuildContext context) => LayoutDensity.metricsOf(context).statusBarRow + _noticeBandHeight;

  const NoticeStack({super.key, required this.notices, required this.onDismiss, this.maxHeight, this.dismissLabel = 'Dismiss'});

  @override
  State<NoticeStack> createState() => _NoticeStackState();
}

const _noticeDismissDuration = Duration(milliseconds: 220);

class _NoticeStackState extends State<NoticeStack> {
  /// Set while the top notice is fading out and the one behind it is
  /// animating into its place; cleared (and [NoticeStack.onDismiss] actually
  /// called) once that transition finishes.
  String? _dismissingKey;

  void _startDismiss(String key) {
    setState(() => _dismissingKey = key);
    Future.delayed(_noticeDismissDuration, () {
      widget.onDismiss(key);
      if (mounted) setState(() => _dismissingKey = null);
    });
  }

  /// The budget for the whole stack: what the caller allowed, or 40% of the
  /// window when it did not say.
  double _stackCap(BuildContext context) => widget.maxHeight ?? MediaQuery.sizeOf(context).height * _windowFraction;

  /// The band actually painted. Normally the full [_noticeBandHeight]; when
  /// the stack's whole budget is smaller than that, the band shrinks with it
  /// rather than pushing the stack past what it was given. Keeping the top and
  /// bottom in proportion means it reads as a tighter band, not a broken one.
  EdgeInsets _bandFor(double cap) {
    final scale = (cap / _noticeBandHeight).clamp(0.0, 1.0);
    return EdgeInsets.fromLTRB(Space.lg, _noticeBandTop * scale, Space.lg, _noticeBandBottom * scale);
  }

  /// Caps a notice card so the card PLUS the band fits the stack's budget,
  /// scrolling its content when it would grow past that. Applied to every card
  /// — including the ghost that sizes the stack — so the whole stack stays
  /// within the limit, which is the property the caller is relying on.
  Widget _capHeight(BuildContext context, Widget card) {
    final cap = _stackCap(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: math.max(0.0, cap - _bandFor(cap).vertical)),
      child: SingleChildScrollView(child: card),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasNotices = widget.notices.isNotEmpty;

    final theme = Theme.of(context);
    final footerColor = theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
    final top = hasNotices ? widget.notices.first : null;
    final second = widget.notices.length > 1 ? widget.notices[1] : null;
    final isDismissingTop = top != null && top.key == _dismissingKey;

    return ClipRect(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.fastOutSlowIn,
        alignment: Alignment.bottomCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          reverseDuration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final offsetAnimation = Tween<Offset>(begin: const Offset(0, 1.0), end: Offset.zero).animate(animation);
            return SlideTransition(position: offsetAnimation, child: child);
          },
          child: !hasNotices || top == null
              ? const SizedBox(key: ValueKey('notice_empty'), width: double.infinity, height: 0)
              : Container(
                  key: const ValueKey('notice_active'),
                  width: double.infinity,
                  color: footerColor,
                  padding: _bandFor(_stackCap(context)),
                  // Hold the notice card to the ideal pane width, centered, rather than
                  // letting it stretch across a wide window (the full-width band behind it
                  // stays, matching the footer).
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: idealPaneWidth),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Invisible sizing reference: once the real cards below are
                          // `Positioned` (needed for the peek/expand animation), the
                          // Stack has no unpositioned child left to size itself from, so
                          // this ghost copy of the top card's content establishes its
                          // box — which is also how the peeking card ends up the same
                          // height as the top one, rather than a fixed decorative sliver.
                          // `onDismiss` must be non-null here too so the ghost renders
                          // the same close button as the real top card — otherwise it's
                          // shorter and the real (Positioned-constrained) card overflows
                          // its box.
                          //
                          // `ExcludeSemantics` states what `Opacity(0)` already achieves
                          // (RenderOpacity drops its child's semantics at zero alpha) so
                          // that raising the opacity for a fade one day cannot silently
                          // publish a duplicate of the notice — and a dead close button —
                          // to assistive tech. The peek below is the case that got that
                          // wrong.
                          ExcludeSemantics(
                            child: Opacity(
                              opacity: 0,
                              child: IgnorePointer(
                                child: _capHeight(context, NoticeCard(notice: top, onDismiss: () {}, dismissLabel: widget.dismissLabel)),
                              ),
                            ),
                          ),
                          if (second != null)
                            AnimatedPositioned(
                              key: ValueKey(second.key),
                              duration: _noticeDismissDuration,
                              curve: Curves.easeInOut,
                              left: isDismissingTop ? 0 : 6,
                              top: isDismissingTop ? 0 : 6,
                              right: isDismissingTop ? 0 : -6,
                              bottom: isDismissingTop ? 0 : -6,
                              // A few pixels of card edge showing behind the top one, to
                              // say "there is another". Purely visual, and it must stay
                              // that way: `IgnorePointer` takes it out of hit testing but
                              // NOT out of semantics (`ignoringSemantics` defaults to
                              // null, which reads as false), and at 0.7 opacity the
                              // subtree is not dropped either — so without the exclusion
                              // a screen reader is read the second notice in full, ahead
                              // of the one actually on top, along with a close button
                              // wired to a no-op. It is also churn: the whole card's
                              // worth of nodes appears and vanishes as notices stack, and
                              // freed nodes get recycled onto other widgets — including,
                              // on web, a focused text field, whose `<input>` the engine
                              // then disposes mid-word (see StatusBarFooter.build).
                              //
                              // This does cost something, and it is not only the label:
                              // `NoticeCard` renders `notice.actions` as live buttons, so
                              // a stacked notice's actions become unreachable to assistive
                              // tech until it reaches the top. That is the intended
                              // trade — activating a button on a card sitting visually
                              // behind another is worse than waiting for it to surface —
                              // but it is a trade, not a free silence.
                              child: ExcludeSemantics(
                                child: IgnorePointer(
                                  child: AnimatedOpacity(
                                    duration: _noticeDismissDuration,
                                    opacity: isDismissingTop ? 1 : 0.7,
                                    // A no-op `onDismiss` (rather than none) keeps this
                                    // card's rendered height identical to the ghost/top
                                    // cards — see the ghost's comment above. It's inert
                                    // either way since this whole subtree is wrapped in
                                    // `IgnorePointer`.
                                    child: _capHeight(context, NoticeCard(notice: second, onDismiss: () {}, dismissLabel: widget.dismissLabel)),
                                  ),
                                ),
                              ),
                            ),
                          AnimatedPositioned(
                            key: ValueKey(top.key),
                            duration: _noticeDismissDuration,
                            curve: Curves.easeInOut,
                            left: 0,
                            top: isDismissingTop ? 80 : 0,
                            right: 0,
                            bottom: isDismissingTop ? -80 : 0,
                            child: IgnorePointer(
                              ignoring: isDismissingTop,
                              child: AnimatedOpacity(
                                duration: _noticeDismissDuration,
                                opacity: isDismissingTop ? 0 : 1,
                                child: _capHeight(context, NoticeCard(notice: top, onDismiss: () => _startDismiss(top.key), dismissLabel: widget.dismissLabel)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _NoticeSurface extends StatelessWidget {
  final Widget child;

  const _NoticeSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(color: HaLoColors.of(context).notice, elevation: 2, child: child);
  }
}

/// The post-it keeps its own paper color in both brightnesses (see
/// [HaLoColors.notice]), so every markdown role has to be pinned to the notice
/// ink rather than inherited: what `fromTheme` derives from the ambient
/// surface is near-white under the dark theme and disappears on the yellow.
///
/// The same constraint binds every CONTROL on a notice, not just its markdown,
/// and it now cuts against the theme's own defaults: a bare `TextButton`,
/// spinner or text field takes [HaLoColors.onSurfaceAccent], which reads at
/// 2.46:1 on this yellow. Anything added to a `NoticeCard` has to pin
/// `onNotice` explicitly the way the action and dismiss buttons below do.
MarkdownStyleSheet _noticeMarkdownStyle(MarkdownStyleSheet base, ThemeData theme, Color onNotice) {
  final body = theme.textTheme.bodyMedium?.copyWith(color: onNotice);
  final faint = onNotice.withValues(alpha: 0.08);
  final rule = onNotice.withValues(alpha: 0.3);
  return base.copyWith(
    p: body,
    listBullet: body,
    blockquote: body,
    tableBody: body,
    img: body,
    checkbox: body,
    // Color only, never a body-derived style: the builder merges the link
    // style onto its parent, and `merge` takes every non-null field — a
    // fontSize or fontWeight here would override the heading or bold run the
    // link sits inside. No underline either, since without an `onTapLink`
    // these links do nothing; [StatusBarActionData]s are the actionable part.
    a: TextStyle(color: Colors.blue.shade900),
    code: body?.copyWith(backgroundColor: faint, fontFamily: 'monospace', fontSize: theme.textTheme.bodyMedium!.fontSize! * 0.85),
    h1: theme.textTheme.headlineSmall?.copyWith(color: onNotice),
    h2: theme.textTheme.titleLarge?.copyWith(color: onNotice),
    h3: theme.textTheme.titleMedium?.copyWith(color: onNotice),
    h4: theme.textTheme.bodyLarge?.copyWith(color: onNotice),
    h5: theme.textTheme.bodyLarge?.copyWith(color: onNotice),
    h6: theme.textTheme.bodyLarge?.copyWith(color: onNotice),
    codeblockDecoration: BoxDecoration(color: faint, borderRadius: BorderRadius.circular(2)),
    blockquoteDecoration: BoxDecoration(color: faint, borderRadius: BorderRadius.circular(2)),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(width: 5, color: rule)),
    ),
  );
}

/// One notice, as a "post-it" card: icon+title row, markdown body, action
/// buttons. Used both live (dismissible, in [NoticeStack]) and read-only (no
/// [onDismiss]) in the Recent Notices history screen.
class NoticeCard extends StatelessWidget {
  final StatusBarNoticeData notice;
  final VoidCallback? onDismiss;

  /// Accessible name for the dismiss button (see [StatusBarFooter.dismissLabel]).
  final String dismissLabel;

  const NoticeCard({super.key, required this.notice, this.onDismiss, this.dismissLabel = 'Dismiss'});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onNotice = HaLoColors.of(context).onNotice;

    return _NoticeSurface(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (notice.icon != null) ...[Icon(resolveIconName(notice.icon), size: 18, color: onNotice), const SizedBox(width: Space.md)],
                if (notice.title != null)
                  Expanded(
                    child: Text(
                      notice.title!,
                      style: theme.textTheme.titleSmall?.copyWith(color: onNotice, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  const Spacer(),
                if (onDismiss != null)
                  IconButton(
                    icon: Icon(MdiIcons.close, size: 18, color: onNotice, semanticLabel: dismissLabel),
                    onPressed: onDismiss,
                    // The hover/press overlay derives from foregroundColor, so
                    // without this it resolves against the ambient theme and a
                    // near-white state layer washes out on the yellow paper.
                    style: IconButton.styleFrom(foregroundColor: onNotice),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    mouseCursor: SystemMouseCursors.click,
                  ),
              ],
            ),
            const SizedBox(height: Space.xs),
            HaloMarkdown(data: notice.text, style: (base) => _noticeMarkdownStyle(base, theme, onNotice), sizedImageBuilder: notice.images),
            if (notice.actions.isNotEmpty) ...[
              const SizedBox(height: Space.md),
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final action in notice.actions.where((a) => !a.primary))
                            Padding(
                              padding: const EdgeInsets.only(right: Space.md),
                              child: TextButton(
                                onPressed: action.onTap,
                                style: TextButton.styleFrom(foregroundColor: onNotice),
                                child: Text(action.label),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Outlined, as the Extensions panel draws the same verb on the
                  // same yellow: a bare label on the notice ground reads as one
                  // more piece of the sentence above it.
                  for (final action in notice.actions.where((a) => a.primary))
                    Padding(
                      padding: const EdgeInsets.only(left: Space.md),
                      child: OutlinedButton(
                        onPressed: action.onTap,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: onNotice,
                          side: BorderSide(color: onNotice),
                        ),
                        child: Text(action.label),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
