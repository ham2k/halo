// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Choosing what this device shares (HALO-369) — a dialog of its own, with a
// tab per kind and a picture on every tile.
//
// A picture, because the names do not tell them apart. A machine offers one
// or two displays and dozens of windows, several of which are called the
// same thing ("Safari", "Untitled"), and the operator is deciding what
// leaves this device. Getting that wrong on a list of near-identical labels
// is a privacy mistake, not an inconvenience.
//
// The tiles are STILLS fetched a few at a time (`PeerScreens.requestThumbnail`),
// not live captures: eighty live streams to draw a grid would cost more than
// the feature itself.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../services/halo_services.dart';
import '../services/peer/peer_screens.dart';
import 'screen_source_tile.dart';

Future<void> showScreenSharePicker(BuildContext context, {required HaLoServices services}) {
  return showHaloDialog<void>(
    context: context,
    builder: (dialogContext) => _ScreenSharePicker(services: services),
  );
}

class _ScreenSharePicker extends StatefulWidget {
  final HaLoServices services;

  const _ScreenSharePicker({required this.services});

  @override
  State<_ScreenSharePicker> createState() => _ScreenSharePickerState();
}

class _ScreenSharePickerState extends State<_ScreenSharePicker> {
  PeerScreens get _screens => widget.services.peerScreens;

  bool _refreshing = false;

  /// What was already being shared when this dialog opened.
  ///
  /// A SNAPSHOT, and that is the whole point: the tiles are ordered by it,
  /// so what the operator already shares is at the top when they come
  /// looking — but ordering by the LIVE set instead would send a tile
  /// jumping to the front the instant it was ticked, under the pointer that
  /// ticked it. Reopening the dialog re-takes it.
  late final Set<String> _offeredOnOpen;

  @override
  void initState() {
    super.initState();
    _offeredOnOpen = widget.services.settings.peerSharedScreenIds.toSet();
    _screens.addListener(_onChanged);
    // Fresh on open: a window that closed since the panel last looked would
    // otherwise sit in the grid offering itself.
    //
    // After the frame, not during it. `clearThumbnails` notifies
    // synchronously, and the settings panel that opened this dialog is still
    // mounted and listening — a notify from initState reaches its setState
    // while the framework is mid-build, which is a markNeedsBuild-during-
    // build error the operator never sees (ErrorPolicy logs it and moves on).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refresh());
    });
  }

  @override
  void dispose() {
    _screens.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      _screens.clearThumbnails();
      await _screens.refreshSources();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _toggle(PeerScreenSource source, bool offered) async {
    final settings = widget.services.settings;
    final ids = settings.peerSharedScreenIds.toList();
    ids.remove(source.id);
    if (offered) ids.add(source.id);
    await settings.setPeerSharedScreenIds(ids);
    // Un-picking something a peer is watching has to stop it now, not when
    // that viewer happens to close its pane.
    await _screens.applyOffers();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.settings.peers;
    final offered = widget.services.settings.peerSharedScreenIds.toSet();
    final byKind = <String, List<PeerScreenSource>>{PeerScreenSourceKind.display: [], PeerScreenSourceKind.app: [], PeerScreenSourceKind.window: []};
    for (final source in _screens.availableSources) {
      (byKind[source.kind] ?? byKind[PeerScreenSourceKind.window]!).add(source);
    }
    // Shared first, everything else in the order the OS reported it. A
    // partition rather than a sort: Dart's sort is not stable, and the
    // enumeration order is meaningful (a machine's own display first, then
    // apps by window count) — shuffling the rest to move a few to the top
    // would cost more than it buys. It also means the tiles an operator
    // cares about are the first to ask for a thumbnail.
    for (final kind in byKind.keys) {
      final sources = byKind[kind]!;
      byKind[kind] = [...sources.where((s) => _offeredOnOpen.contains(s.id)), ...sources.where((s) => !_offeredOnOpen.contains(s.id))];
    }

    return DefaultTabController(
      length: 3,
      child: HaloDialog(
        // The house width for a dialog that carries real content, rather
        // than the compact prompt width this was silently getting — a grid
        // of tiles needs the room, and [maxDialogWidth] is as wide as any
        // modal in this app is allowed to be.
        wide: true,
        // Zero, so the tab strip reaches both edges of the card. What is
        // inside the tabs insets itself instead (the grid's own padding),
        // the same rule a settings-shaped dialog follows.
        contentPadding: EdgeInsets.zero,
        title: Row(
          children: [
            Expanded(child: Text(t.screenChooseTitle)),
            Semantics(
              label: t.screenRefresh,
              button: true,
              child: IconButton(
                icon: _refreshing ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(MdiIcons.refresh),
                onPressed: _refreshing ? null : () => unawaited(_refresh()),
              ),
            ),
          ],
        ),
        // Width is `showHaloDialog`'s shared cap, the same as every other
        // dialog — infinity fills whatever that allows rather than naming a
        // number of its own. Height IS bounded here: the window tab
        // routinely holds dozens, and a dialog that grew with them would run
        // off the screen on the smallest window the app allows.
        content: SizedBox(
          width: double.infinity,
          height: 460,
          child: Column(
            children: [
              // These tabs sit on the dialog's own surface, not on the
              // AppBar, so the app-wide tabBarTheme's onPrimary labels
              // (theme.dart's note) would be near-white on white in light
              // mode. Recoloured for a surface the way SectionHeader is:
              // the accent read ON the surface, never colorScheme.primary
              // directly, which flips meaning across brightness.
              //
              // No Material wrapper and no colour of its own — whatever the
              // card paints behind it shows through, so the strip cannot
              // drift out of step with the sections around it.
              // Surfaced HERE, not only in the settings row behind this
              // modal: a failed enumeration empties every tab, and three
              // tabs reading "Nothing of this kind was found" is a machine
              // with no screens, which no machine is.
              if (_screens.error case final problem?)
                ListTile(
                  dense: true,
                  leading: Icon(MdiIcons.alertCircleOutline, color: Theme.of(context).colorScheme.error),
                  title: Text(context.t.settings.peers.screenProblem(error: problem)),
                ),
              TabBar(
                labelColor: HaLoColors.of(context).onSurfaceAccent,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                indicatorColor: HaLoColors.of(context).onSurfaceAccent,
                // Edge to edge: equal thirds across the card's full width,
                // with none of Material's default inset.
                tabAlignment: TabAlignment.fill,
                padding: EdgeInsets.zero,
                labelPadding: EdgeInsets.zero,
                tabs: [
                  Tab(text: '${t.screenTabScreens} (${byKind[PeerScreenSourceKind.display]!.length})'),
                  Tab(text: '${t.screenTabApps} (${byKind[PeerScreenSourceKind.app]!.length})'),
                  Tab(text: '${t.screenTabWindows} (${byKind[PeerScreenSourceKind.window]!.length})'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    for (final kind in const [PeerScreenSourceKind.display, PeerScreenSourceKind.app, PeerScreenSourceKind.window])
                      _SourceGrid(sources: byKind[kind]!, offered: offered, screens: _screens, onToggle: (source, value) => unawaited(_toggle(source, value))),
                  ],
                ),
              ),
            ],
          ),
        ),
        // The `cancel:` slot, not `actions:` — every toggle in here autosaves,
        // so Done is the way OUT rather than a commit, and only that slot gets
        // the gap that keeps a dismissal off a primary action.
        cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.done)),
      ),
    );
  }
}

class _SourceGrid extends StatelessWidget {
  final List<PeerScreenSource> sources;
  final Set<String> offered;
  final PeerScreens screens;
  final void Function(PeerScreenSource, bool) onToggle;

  const _SourceGrid({required this.sources, required this.offered, required this.screens, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final t = context.t.settings.peers;
    if (sources.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Text(t.screenTabEmpty, textAlign: TextAlign.center),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(Space.md),
      // Three columns, not a maximum tile width: the dialog is held to
      // [maxDialogWidth], so a max-extent delegate lands on four cramped
      // columns or two wide ones depending on the rounding, where a count
      // gives the same layout every time.
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 4 / 3.4,
        crossAxisSpacing: Space.md,
        mainAxisSpacing: Space.md,
      ),
      itemCount: sources.length,
      itemBuilder: (context, index) {
        final source = sources[index];
        // Asked for as the tile is BUILT, so a grid of eighty fetches only
        // what the operator has actually scrolled to.
        screens.requestThumbnail(source.id);
        final isOffered = offered.contains(source.id);
        return ScreenSourceTile(
          source: source,
          thumbnail: screens.thumbnailFor(source.id),
          selected: isOffered,
          showCheckbox: true,
          onTap: () => onToggle(source, !isOffered),
        );
      },
    );
  }
}
