// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Picking a new piece of equipment: the catalogue, shelved by brand under
// pinned headers, with whatever announced itself on the network as its
// first shelf and one search box across the lot (docs/design/cat.md).
//
// Its own file rather than the Station panel's, because the panel is already
// the longest view in the app and this is the one part of it an operator
// visits once per radio.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'equipment_glyphs.dart';
import '../services/cat/discovery.dart';
import '../services/cat/equipment.dart';
import '../services/cat/equipment_brands.dart';
import '../services/cat/equipment_registry.dart';
import '../services/cat/cat_service.dart';

/// Picking what to add: every radio the app knows, filtered by a search box,
/// with whatever announced itself on the network as its first shelf.
///
/// Stateful because two things here are the dialog's own and belong to
/// nothing else — the filter text and whether the discovery section is
/// currently folded away.
class AddEquipmentDialog extends StatefulWidget {
  final CatService cat;

  /// False when no pairing on this platform could discover anything, in
  /// which case the section is absent rather than permanently empty.
  final bool showDiscovery;

  /// Whether the operator has opted to track an antenna or a key against
  /// QSOs — see [SettingsService.stationInfoTrackedFields]. Off, the "Other
  /// Equipment" section would only ever grow a list nothing reads.
  final bool showAntennaAndKey;

  /// Whether "Other Equipment" offers a CW keyer — behind the keyer
  /// experiment, with everything that keys.
  final bool showKeyer;

  /// Whether "Other Equipment" offers the SDR receivers — behind `EXP SDR`.
  final bool showSdr;

  final List<EquipmentType> Function(EquipmentModel model) supportedVariants;

  const AddEquipmentDialog({
    super.key,
    required this.cat,
    required this.showDiscovery,
    required this.showAntennaAndKey,
    required this.showKeyer,
    this.showSdr = false,
    required this.supportedVariants,
  });

  @override
  State<AddEquipmentDialog> createState() => _AddEquipmentDialogState();
}

class _AddEquipmentDialogState extends State<AddEquipmentDialog> {
  final _searchController = TextEditingController();

  /// The one shelf that is open, or null for none. One at a time because the
  /// list is a way to FIND a radio, not to compare two: several open at once
  /// puts the shelf you want back below the fold, which is the state closing
  /// them was for. Searching ignores this entirely — see [build].
  ///
  /// Starts on what announced itself, where there is such a shelf: a radio
  /// the app has already found is the shortest path to a configured one, and
  /// it costs the operator nothing to see it before they go hunting by make.
  /// Every other shelf starts shut, so the whole list of makes fits on one
  /// screen.
  String? _openGroup = _discoveryKey;

  /// The header of each shelf, for scrolling one back into view — see
  /// [_toggleGroup].
  final _headerKeys = <String, GlobalKey>{};

  GlobalKey _headerKey(String group) => _headerKeys.putIfAbsent(group, GlobalKey.new);

  /// See [_refreshListKey].
  Key _listKey = listContentsKey(const []);

  /// Recreated with each [_listKey], carrying the offset over. A fresh scroll
  /// view starts at the top, and an operator opening a shelf half way down
  /// the list would be thrown back to the first one — with the header they
  /// just tapped now below the fold and unbuilt, which also leaves
  /// [_toggleGroup] nothing to scroll to.
  ScrollController _scroll = ScrollController();
  double _offset = 0;

  /// See [_revealAfterFold].
  Timer? _revealTimer;

  /// Whether the spinner row is still showing — see [_discoverySpinnerLinger].
  var _searching = true;
  Timer? _searchingTimer;

  /// What [_refreshListKey] last built a list for — see its query rule.
  String _lastQuery = '';

  /// One per shelf, so a shelf SURVIVES the remount [_refreshListKey] forces:
  /// the framework moves a globally-keyed subtree into the fresh scroll view
  /// instead of disposing it with the old one (docs/quirks.md). Without this
  /// the caret and the body cross-fade are re-inflated already at their new
  /// state, and the section snaps open with no animation at all.
  final _shelfKeys = <String, GlobalKey>{};

  GlobalKey _shelfKey(String group) => _shelfKeys.putIfAbsent(group, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    // Started with the pane rather than with the shelf: the shelf opens
    // itself, and an operator who shuts it and comes back is not asking to be
    // told the search began all over again.
    _searchingTimer = Timer(_discoverySpinnerLinger, () {
      if (mounted) setState(() => _searching = false);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _revealTimer?.cancel();
    _searchingTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// Remembers where the list is, so [_refreshListKey] can put the remounted
  /// one back there.
  void _rememberOffset(ScrollMetrics metrics) => _offset = metrics.pixels;

  void _toggleGroup(String key, int index) {
    final opening = _openGroup != key;
    if (!opening) {
      setState(() => _openGroup = null);
      return;
    }
    // Opened FIRST, and the scroll only if the geometry is there to compute
    // it from: the reveal is a nicety, and abandoning the toggle with it
    // would make the pane's primary gesture a dead tap with no feedback.
    setState(() => _openGroup = key);
    // Where the opened header ends up: with one shelf open, everything above
    // it is a collapsed header and they are all the same height, so this is
    // arithmetic rather than a measurement of a row that may not be built.
    if (_headerKeys[key]?.currentContext?.findRenderObject() case final RenderBox header) {
      _revealAfterFold(index * header.size.height, header.size.height);
    }
  }

  /// Scrolls the opened header into view once the accordion has finished
  /// folding — by the LEAST movement that does it, and not at all when the
  /// header is already on screen.
  ///
  /// Minimal on purpose. Pinning every opened shelf to the top scrolls the
  /// ones above it away, so opening a brand made "Detected Equipment" vanish
  /// and come back — a heading that moves under the operator for no reason
  /// they asked for. What has to be true is that the shelf they just opened
  /// is visible, which is a weaker thing.
  ///
  /// A delay rather than a post-frame callback because what is being waited
  /// for is the END of an animation, not the next layout: the shelf that just
  /// shut goes on shrinking for the length of the fold, and the position
  /// clamps to a maxScrollExtent falling under it every frame, so a
  /// correction applied to any of those frames is undone by the next.
  void _revealAfterFold(double target, double headerHeight) {
    _revealTimer?.cancel();
    // A frame past the fold, not with it: the timer starts at the tap, the
    // fold on the next frame.
    _revealTimer = Timer(collapseDuration + const Duration(milliseconds: 16), () {
      if (!mounted || !_scroll.hasClients) return;
      final position = _scroll.position;
      final top = position.pixels;
      final bottom = top + position.viewportDimension;
      final want = target < top
          // Above the viewport: bring it to the top.
          ? target
          : target + headerHeight > bottom
          // Below it: bring it just inside the bottom edge.
          ? target + headerHeight - position.viewportDimension
          : null;
      if (want == null) return;
      _scroll.jumpTo(want.clamp(0, position.maxScrollExtent));
    });
  }

  /// The key the scroll view takes.
  ///
  /// On the web a click is hit-tested against the accessibility DOM, and a
  /// list rebuilt in place can leave those elements holding the previous
  /// arrangement's geometry — the click then adds the radio NEXT to the one
  /// that was tapped (docs/quirks.md, `listContentsKey`). Two things move
  /// rows here, and opening a group is the bigger of them: every row below
  /// the header shifts by the whole group's height.
  ///
  /// The cost is a remount, which restarts the scroll at the top and cuts
  /// the section's cross-fade short. Both are affordable in a list that
  /// opens with every group shut; adding the wrong radio is not.
  void _refreshListKey(List<Object?> identities, {required String query}) {
    final key = listContentsKey(identities);
    if (key == _listKey) return;
    _listKey = key;
    // A new query is a new list, and it starts at the top: carrying an offset
    // into it strands the operator half way down a set of matches they have
    // not seen, and leaves the discovery section folded over a list that no
    // longer scrolls. Only a shelf opening keeps its place — that one has a
    // place worth keeping.
    if (query != _lastQuery) _offset = 0;
    _lastQuery = query;
    // The outgoing controller is still attached to the scroll view being
    // replaced, which only detaches during the coming build — disposing it
    // here would assert.
    final outgoing = _scroll;
    WidgetsBinding.instance.addPostFrameCallback((_) => outgoing.dispose());
    _scroll = ScrollController(initialScrollOffset: _offset);
  }

  /// Everything the dialog can offer, in the order the groups are listed —
  /// the catalogue by brand, then whatever is left, then the equipment that
  /// is added by name rather than picked by model.
  ///
  /// One flat list of [_AddRow]s rather than a list per section, because
  /// SEARCH crosses all of them: an operator typing "winkey" is owed the
  /// keyer whether or not they knew it lived under "Other Equipment".
  List<({String key, String title, List<_AddRow> rows})> _groups(BuildContext context) {
    final st = context.t.settings.station;
    // Resolved ONCE per model. Both the variants and the name cost real
    // work — `supportedVariants` scans the type list per variant, and
    // `name` is a localization lookup — and every one of them would
    // otherwise be repeated for the filter, the subtitle, the glyphs and
    // each comparison the sort makes, on every keystroke in the search box.
    //
    // A radio whose transport can't connect on this platform at all (TCP,
    // Icom network, on web) would only fail loudly once picked, so it is
    // left out here rather than offered.
    final catalogue = <String, List<_AddRow>>{};
    final switches = <_AddRow>[];
    for (final model in widget.cat.registry.models) {
      if (model.hiddenFromCatalog) continue;
      final variants = widget.supportedVariants(model);
      if (variants.isEmpty) continue;
      final row = _AddRow.forModel(model, variants);
      // Antenna switches are station plumbing added once, not something an
      // operator browsing for their radio is looking for, so they sit with
      // the other one-off equipment rather than under their maker's brand.
      if (model.category == kCategoryAntennaSwitch) {
        switches.add(row);
      } else {
        catalogue.putIfAbsent(_shelfOf(model), () => []).add(row);
      }
    }
    // Sorted HERE rather than in the registry, because a model's name is
    // read from the current locale at call time — an order fixed at
    // declaration would be alphabetical in whichever language happened to be
    // active first. Case-insensitive, so a lower-case brand name doesn't
    // sort below every capitalised one.
    for (final rows in catalogue.values) {
      rows.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    switches.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    final other = <_AddRow>[
      if (widget.showAntennaAndKey) ...[
        _AddRow(title: st.newAntenna, icon: MdiIcons.antenna, choice: AddChoice.model(antennaModel)),
        _AddRow(title: st.newKey, icon: MdiIcons.key, choice: AddChoice.model(keyModel)),
      ],
      // Beside the plain key rather than in the catalogue: a keyer is where
      // an operator looks for their key, whatever its make.
      if (widget.showKeyer)
        _AddRow(
          title: st.newKeyer,
          icon: MdiIcons.keyboardVariant,
          choice: AddChoice.model(winkeyerModel),
          // A named make with a cable, unlike the two inert rows above it:
          // the glyph says how it plugs in, the same way it does in the
          // catalogue.
          variants: widget.supportedVariants(winkeyerModel),
        ),
      ...switches,
      if (widget.showSdr)
        for (final model in sdrModels)
          if (widget.supportedVariants(model) case final variants when variants.isNotEmpty) _AddRow.forModel(model, variants),
    ];

    return [
      // First, and the one shelf that opens itself: a radio the app has
      // already found is the shortest path to a configured one. Its rows are
      // whatever announced itself so far, under a heading that never changes
      // — discovery runs for as long as this pane is open, so a title that
      // switched between "searching" and "found" would name one unfinished
      // activity twice.
      if (widget.showDiscovery) (key: _discoveryKey, title: st.detectedEquipment, rows: _discoveredRows(context)),
      for (final brand in featuredBrands)
        if (catalogue[brand] case final rows? when rows.isNotEmpty) (key: brand, title: brand, rows: rows),
      if (catalogue[_softwareKey] case final rows? when rows.isNotEmpty) (key: _softwareKey, title: st.softwareIntermediaries, rows: rows),
      if (catalogue[_otherBrandsKey] case final rows? when rows.isNotEmpty) (key: _otherBrandsKey, title: st.otherBrands, rows: rows),
      if (other.isNotEmpty) (key: _otherEquipmentKey, title: st.otherEquipment, rows: other),
    ];
  }

  /// What announced itself, as rows — and the spinner as one of them.
  ///
  /// A row rather than something in the header: the search never ends while
  /// the pane is open, so a spinner beside the title would spin at the
  /// operator for as long as they were here, and one that sat above the list
  /// would push every found radio down a line the moment the first arrived.
  /// As the last row it says "still looking" exactly where the next radio
  /// will appear.
  List<_AddRow> _discoveredRows(BuildContext context) {
    final st = context.t.settings.station;
    final error = widget.cat.discoveryError;
    return [
      // Beside what was found, never instead of it: one discoverer failing to
      // bind must not take another's radios off the shelf with it.
      if (error != null)
        _AddRow(
          title: st.discoveryUnavailable(error: error),
          icon: MdiIcons.wifiOff,
          choice: const AddChoice.none(),
        ),
      for (final device in widget.cat.discovered)
        _AddRow(
          title: device.name,
          icon: iconForCategory(widget.cat.registry.typeFor(device.typeKey)?.category),
          choice: AddChoice.discovered(device),
          subtitle: device.detail,
          variants: [?widget.cat.registry.typeFor(device.typeKey)],
        ),
      if (_searching) _AddRow(title: '', icon: MdiIcons.magnify, choice: const AddChoice.none(), searching: true),
    ];
  }

  /// Which shelf a model files under — the bridges first, since they are not
  /// a make at all, then its own brand where that brand has a shelf, then
  /// everything else together. Brands are matched exactly against
  /// [featuredBrands]; see [EquipmentModel.manufacturer].
  String _shelfOf(EquipmentModel model) {
    if (softwareIntermediaryModelKeys.contains(model.key)) return _softwareKey;
    final brand = model.manufacturer;
    return brand != null && featuredBrands.contains(brand) ? brand : _otherBrandsKey;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.cat,
      builder: (context, _) {
        final st = context.t.settings.station;
        final query = _searchController.text.trim().toLowerCase();
        final groups = _groups(context);
        // A search crosses every group, and the answer to "which brand?" is
        // the row itself — headers over one-row groups would be most of what
        // came back. So a query flattens the lot into one list, in the same
        // order the groups are listed.
        final matches = query.isEmpty
            ? const <_AddRow>[]
            : [
                for (final group in groups)
                  for (final row in group.rows)
                    if (row.matches(query)) row,
              ];
        _refreshListKey(query: query, [
          query,
          if (_searching) '<searching>',
          // A radio announcing itself mid-visit INSERTS a row into the first
          // shelf and moves every row below it — a prepend, which
          // listContentsKey is explicit is not the exempt case.
          for (final device in widget.cat.discovered) device.id,
          for (final group in groups) ...[group.key, if (_openGroup == group.key) '<open>'],
        ]);
        final searchBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(8));

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The catalogue's own section header, and the field IS the
            // heading: a band saying "Equipment" with a search box under it
            // would spend a row of a pane that has none to spare saying what
            // the hint text already says.
            _sectionBand(
              context,
              child: TextField(
                // Per docs/design/user-interface.md: focusing a field must
                // not select what is in it.
                selectAllOnFocus: false,
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  // Against the band's own tint, so the box reads as a
                  // control sitting ON the header rather than a hole in it.
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  prefixIcon: const Icon(MdiIcons.magnify, size: 18),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(MdiIcons.close, size: 18, semanticLabel: context.t.formChrome.clear),
                          onPressed: () => setState(_searchController.clear),
                        ),
                  hintText: st.searchHint,
                  border: searchBorder,
                  enabledBorder: searchBorder,
                  focusedBorder: haloFocusedBorder(searchBorder, context),
                ),
              ),
            ),
            // The list is the pane's whole body now that what announced
            // itself is a shelf in it: one scrolling region, taking whatever
            // height the search band leaves.
            Expanded(
              // TWO listeners, and the second is not redundant. A scroll
              // position corrected during LAYOUT — the list shrinking under a
              // filter, or growing back when one is cleared, or a shelf
              // folding — moves `pixels` without ever dispatching a
              // ScrollNotification. Only ScrollMetricsNotification reports it,
              // and it is not a ScrollNotification.
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (notification) {
                  _rememberOffset(notification.metrics);
                  return false;
                },
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    _rememberOffset(notification.metrics);
                    // Keep bubbling: these listeners observe, they do not consume.
                    return false;
                  },
                  child: query.isNotEmpty && matches.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: Space.xxl, horizontal: Space.xl),
                          child: Text(st.noMatches, textAlign: TextAlign.center),
                        )
                      : CustomScrollView(
                          key: _listKey,
                          controller: _scroll,
                          shrinkWrap: true,
                          slivers: query.isNotEmpty
                              ? [_rowsSliver(context, matches)]
                              : [
                                  for (final (index, group) in groups.indexed) _groupSliver(context, group, index),
                                  const SliverToBoxAdapter(child: SizedBox(height: Space.md)),
                                ],
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// The strip the search field sits on.
  ///
  /// A lighter WASH of the shelf bands' ground, not the ground itself — the
  /// same treatment and the same reason as the Settings panel's own search
  /// strip (settings_view.dart): the strip belongs to the chrome above the
  /// list rather than to the list, and at the band's full strength it merges
  /// with the collapsed shelves under it into one block of tint with no edge
  /// between them.
  ///
  /// [title] and [child] are alternatives — a heading with an optional
  /// [trailing] control, or a control that IS the heading (the search box).
  Widget _sectionBand(BuildContext context, {String? title, Widget? trailing, Widget? child}) {
    final theme = Theme.of(context);
    final onHeaderColor = theme.colorScheme.onSurfaceVariant;
    return Material(
      color: Color.lerp(theme.colorScheme.surface, haloDialogBandColorAt(context), 0.5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.xl, Space.sm, Space.lg, Space.sm),
        child:
            child ??
            Row(
              children: [
                Expanded(
                  child: Text(
                    title ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(color: onHeaderColor, fontWeight: FontWeight.w600),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: Space.md), trailing],
              ],
            ),
      ),
    );
  }

  /// One brand's shelf: the header PINS, so a list scrolled deep into Icom
  /// still says Icom. All the groups share one scroll view for that reason —
  /// a pinned band only holds the top of the viewport it lives in.
  Widget _groupSliver(BuildContext context, ({String key, String title, List<_AddRow> rows}) group, int index) {
    // The Settings panel's own category heading, borrowed whole: these are
    // the same kind of thing — a shelf of rows under a band that folds — and
    // two shelf styles one pane apart read as two different mechanisms.
    // [SectionHeader.titleStyle] carries the slab face and the accent; the
    // chevron takes its colour from the same place so the two cannot drift.
    final titleStyle = SectionHeader.titleStyle(context);
    final onHeaderColor = titleStyle.color ?? Theme.of(context).colorScheme.onSurface;
    return SliverCollapsibleSection(
      key: _shelfKey(group.key),
      title: Text(group.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
      headerKey: _headerKey(group.key),
      expanded: _openGroup == group.key,
      onToggle: () => _toggleGroup(group.key, index),
      headerColor: haloDialogBandColorAt(context),
      onHeaderColor: onHeaderColor,
      sliver: _rowsSliver(context, group.rows),
    );
  }

  Widget _rowsSliver(BuildContext context, List<_AddRow> rows) => SliverList.list(
    children: [
      for (final row in rows)
        if (row.searching)
          const ListTile(
            // In the row's own width rather than the leading slot: it
            // stands for the search itself, not for a piece of equipment,
            // so it has no name beside it to line up with. The padding
            // goes to zero because a ListTile's title slot is inset by
            // its gutters, and centring inside THAT lands the spinner off
            // the row's true centre by half of them.
            contentPadding: EdgeInsets.zero,
            title: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else
          ListTile(
            leading: Icon(row.icon),
            title: Text(row.title),
            subtitle: row.subtitle == null ? null : Text(row.subtitle!),
            // The glyphs belong beside the radio's NAME, not halfway down
            // the row. Material 3 centres `leading`/`trailing` against the
            // whole tile unless told otherwise, so a two-line row would
            // otherwise drop them a line — wrapping them in a
            // shrink-wrapping Column does NOT do this, only the alignment
            // does. No catalogue row is two-line today; a discovered
            // device's is, and it draws from the same shape.
            titleAlignment: ListTileTitleAlignment.top,
            trailing: row.variants.isEmpty ? null : TransportIcons(types: row.variants),
            onTap: row.choice.isNothing ? null : () => Navigator.of(context).pop(row.choice),
            // Only where there is something to tap: a hand cursor over a row
            // that reports rather than offers promises an action it has not.
            mouseCursor: row.choice.isNothing ? null : SystemMouseCursors.click,
          ),
    ],
  );
}

/// How long the "still looking" spinner stays in the Detected Equipment
/// shelf after the pane opens.
///
/// It is a reassurance, not a status: UDP discovery has no terminal state and
/// listens for as long as the pane is open, so a spinner tied to the actual
/// activity would turn for the whole visit. Long enough to say the search
/// started, short enough not to become furniture — a radio that announces
/// itself later still appears, spinner or no spinner.
const _discoverySpinnerLinger = Duration(seconds: 3);

/// The shelf keys that are not a brand. Not localized values — they key the
/// open shelf and the list key, and the operator never sees them; the heading
/// each draws is [context.t.settings.station]'s.
const _discoveryKey = '<discovered>';
const _softwareKey = '<software>';
const _otherBrandsKey = '<other-brands>';
const _otherEquipmentKey = '<other-equipment>';

/// One row the Add dialog can offer, wherever it came from — a catalogue
/// radio under its brand, a switch, or the antenna and key that are added by
/// name rather than picked by model.
///
/// One type for all of them so that SEARCH can be one pass over one list: an
/// operator typing "winkey" is owed the keyer whether or not they knew it
/// lived under "Other Equipment".
@immutable
class _AddRow {
  final String title;
  final IconData icon;

  /// What tapping the row answers with — a model to configure, or a device
  /// that announced itself and needs nothing configured at all.
  final AddChoice choice;

  /// The pairings this platform can actually connect — empty for the inert
  /// antenna and key rows, which have no cable to draw a glyph for.
  final List<EquipmentType> variants;

  /// A discovered device's address, under its name. Null for a catalogue row:
  /// nothing about a model is worth a second line.
  final String? subtitle;

  /// What [matches] searches, lower-cased once at construction rather than
  /// per keystroke.
  final String _haystack;

  /// Whether this row IS the spinner — see [_discoveredRows].
  final bool searching;

  _AddRow({required this.title, required this.icon, required this.choice, this.variants = const [], this.subtitle, this.searching = false, String brand = ''})
    : _haystack = [title, brand, for (final type in variants) type.transportLabel].join(' ').toLowerCase();

  factory _AddRow.forModel(EquipmentModel model, List<EquipmentType> variants) => _AddRow(
    title: model.name,
    icon: iconForCategory(model.category),
    choice: AddChoice.model(model),
    // Without the derived placeholder: every radio offers it, so on a row
    // it would say nothing about how THIS radio plugs in.
    variants: [
      for (final variant in variants)
        if (!model.offersPlaceholder || variant.key != placeholderVariantFor(model.key).key) variant,
    ],
    brand: model.manufacturer ?? '',
  );

  /// Matches the radio's name, its brand and the ways it can be reached, so
  /// "usb" finds every rig with a cable and "705" finds the one radio — an
  /// operator searching this list is as likely to know how a radio plugs in
  /// as what its family is called. The brand is in the haystack because a
  /// model's name need not carry it, and because a brand with a group of its
  /// own is a heading the search has just thrown away.
  bool matches(String query) => _haystack.contains(query);
}

/// Either a device that announced itself (ready to add as-is) or a type to
/// configure by hand.
class AddChoice {
  /// The radio, not the pairing: how it is connected is chosen in the
  /// editor, alongside the settings that choice decides.
  final EquipmentModel? model;
  final DiscoveredEquipment? discovered;

  const AddChoice.model(this.model) : discovered = null;
  const AddChoice.discovered(this.discovered) : model = null;

  /// A row that reports rather than offers — the spinner, and the line that
  /// says discovery could not run. Tapping one does nothing, so the pane
  /// stays open.
  const AddChoice.none() : model = null, discovered = null;

  bool get isNothing => model == null && discovered == null;
}
