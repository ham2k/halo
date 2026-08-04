// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Station Configuration panel: the equipment the station is made of,
// and whether the app can currently talk to it (docs/design/cat.md).
//
// Hand-built rather than a declarative `fieldType: 'list'` — that field's
// `itemFields` is a static declaration and can't express a Connect button
// or a live status line. Individual editors DO go through the declarative
// path: `showFormPane` over the equipment type's own `configElements`, so a
// new type contributes its settings without touching this file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../i18n/strings.g.dart';
import '../main.dart';
import '../settings/settings_target_dialog.dart';
import '../services/cat/discovery.dart';
import '../services/cat/equipment.dart';
import '../services/cat/equipment_registry.dart';
import '../services/cat/cat_service.dart';
import '../tools/form_chrome_labels.dart';

/// Shown as the HINT of a secret field whose value is already in the keychain,
/// never as its value: a hint cannot be submitted, cannot be revealed by the
/// field's show/hide eye, and leaves the field genuinely empty — which is what
/// CatService reads as "keep what is stored".
///
/// A fixed count, deliberately. Matching the real length would leak it.
const _storedSecretPlaceholder = '••••••••';

class StationPanel extends StatelessWidget {
  final HaLoServices services;

  const StationPanel({super.key, required this.services});

  CatService get _cat => services.cat;

  Future<void> _addEquipment(BuildContext context) async {
    // Only FlexRadio announces itself today, over a UDP broadcast the web
    // build's transport can't open — starting discovery there would just
    // bind a socket that never reports anything, and `_showAddDialog`
    // would spin its "searching" state forever for no reason.
    final canDiscover =
        _cat.registry.types.any((type) => type.discoverer != null && type.isSupportedOnThisPlatform);
    // Discovery holds a bound UDP socket, so it runs only while the dialog
    // that shows its results is open — and the socket has to be released
    // even if the dialog throws, or `isDiscovering` stays true and every
    // later Add silently reuses an orphaned subscription.
    if (canDiscover) _cat.startDiscovery();
    final _AddChoice? choice;
    try {
      choice = await _showAddDialog(context, showDiscovery: canDiscover);
    } finally {
      if (canDiscover) _cat.stopDiscovery();
    }
    if (choice == null || !context.mounted) return;

    if (choice.discovered != null) {
      // Already has everything it needs — no form to fill in.
      await _cat.addDiscovered(choice.discovered!);
      return;
    }

    final model = choice.model!;
    final variants = _supportedVariants(model);
    if (variants.isEmpty) return;
    final values = await _editValues(
      context,
      model: model,
      type: variants.first,
      // Prefilled rather than left blank, and editable: the operator sees
      // what it will be called before agreeing to it. addNode computes the
      // same suggestion again if they clear the field, since this one is
      // already stale by the time they submit.
      name: _cat.suggestedNameFor(variants.first.key),
      config: const {},
    );
    if (values == null) return;

    await _cat.addNode(typeKey: values.typeKey, name: values.name, config: values.config);
  }

  Future<_AddChoice?> _showAddDialog(BuildContext context, {required bool showDiscovery}) {
    return showHaloDialog<_AddChoice>(
      context: context,
      builder: (context) => _AddEquipmentDialog(
        cat: _cat,
        showDiscovery: showDiscovery,
        supportedVariants: _supportedVariants,
      ),
    );
  }

  /// The pairings of [model] this platform could actually connect — web has
  /// no raw sockets and no serial, so a model can be reachable everywhere
  /// but here.
  List<EquipmentType> _supportedVariants(EquipmentModel model) => [
        for (final variant in model.variants)
          if (_cat.registry.typeFor(variant.key) case final type?)
            if (type.isSupportedOnThisPlatform) type,
      ];

  Future<void> _editEquipment(BuildContext context, EquipmentNode node) async {
    final type = _cat.typeFor(node);
    if (type == null) return;

    final values =
        await _editValues(context, model: type.model, type: type, name: node.name, config: node.config, node: node);
    // Null also means the editor removed the node, or was cancelled — either
    // way there is nothing left to write back.
    if (values == null) return;

    await _cat.updateNode(
      node.copyWith(typeKey: values.typeKey, name: values.name, config: values.config),
    );
  }

  /// The name field, how the radio is connected, and whatever that choice
  /// asks for, in one form. [node] is null when adding: the actions below act
  /// on equipment that already exists, so they only appear once it does.
  ///
  /// Every supported pairing's fields are rendered at once and narrowed with
  /// `visibleWhen`, rather than the form being rebuilt per transport. That is
  /// FormRenderer's own mechanism and it carries one contract with it (see
  /// its `_visibleElements` doc): a hidden field is still registered, still
  /// holds its value, and is still passed to the validator on submit. So
  /// everything below resolves the pairing from the `transport` value first
  /// and asks only that one — otherwise a serial port left over from a
  /// transport the operator switched away from would block the save.
  ///
  /// The upside of that same contract is what makes it worth it: switching
  /// transport and back keeps what was typed, with no state to thread.
  Future<({String typeKey, String name, Map<String, dynamic> config})?> _editValues(
    BuildContext context, {
    required EquipmentModel model,
    required EquipmentType type,
    required String name,
    required Map<String, dynamic> config,
    EquipmentNode? node,
  }) async {
    final st = context.t.settings.station;
    final variants = _supportedVariants(model);
    // A model with one way in asks no question — the form is exactly what it
    // was before transports were selectable.
    final choosable = variants.length > 1;

    /// Which pairing the form is currently describing. Falls back to the one
    /// it opened on, so a missing or stale `transport` value can never leave
    /// this without a type to validate against.
    EquipmentType typeForState(Map<String, dynamic> state) {
      for (final candidate in variants) {
        if (candidate.transportKey == state['transport']) return candidate;
      }
      return type;
    }

    // Which secrets already exist — the keys only; the values stay in the
    // keychain and never enter this form. A stored password otherwise renders
    // as an empty box that looks like nothing was ever saved, and the obvious
    // fix (prefill it) is the one thing we must not do: the form's values are
    // written back on save, and a revealed secret field would show it.
    // A placeholder says "something is here" and costs nothing, because an
    // untouched field still submits empty, which CatService reads as
    // "unchanged".
    final storedSecrets = node == null ? const <String>{} : await _cat.storedSecretFields(node.uuid);
    if (!context.mounted) return null;

    // No-op for every transport except the web serial one, which uses this
    // to fetch and cache navigator.serial's already-granted device list
    // before configElements() (synchronous, so it can't await this itself)
    // reads it. Every offered pairing's transport gets prepared, not just
    // the selected one: they all render, so they all have to be ready before
    // the first build.
    for (final candidate in variants) {
      await candidate.transport.prepareConfigElements();
    }
    if (!context.mounted) return null;

    // Reused whenever an action changes what's available to pick (a newly
    // granted USB device, say) — configElements() reflects the transport's
    // CURRENT state each time it's called, so rebuilding from it is enough;
    // nothing here needs to know what specifically changed.
    List<Map<String, dynamic>> buildElements() => [
          {
            'type': 'field',
            'fieldType': 'text',
            'key': 'name',
            'label': st.name,
            'description': st.nameDescription,
          },
          if (choosable)
            {
              'type': 'field',
              'fieldType': 'select',
              'key': 'transport',
              'label': st.transport,
              'description': st.transportDescription,
              'options': [
                for (final candidate in variants)
                  {
                    'value': candidate.transportKey,
                    // The short marker, not the sentence the Add list uses: a
                    // dropdown item is one unwrapped row, and the full wording
                    // overflows it.
                    'label': candidate.hardwareVerified
                        ? candidate.transportLabel
                        : '${candidate.transportLabel} (${st.unverifiedShort})',
                  },
              ],
            },
          for (final candidate in variants)
            for (final element in candidate.configElements())
              {
                ...element,
                if (storedSecrets.contains(element['key'])) 'placeholder': _storedSecretPlaceholder,
                // Only when there is a choice to hide behind: an unconditional
                // visibleWhen on a single-transport radio would depend on a
                // `transport` value no field sets.
                if (choosable) 'visibleWhen': {'field': 'transport', 'equals': candidate.transportKey},
              },
        ];

    final result = await showFormPane(
      context,
      // The radio, not the pairing: how it is connected is a field inside the
      // form now, so putting it in the title too would contradict itself the
      // moment the operator changed it.
      formDefinition: {'title': model.name, 'elements': buildElements()},
      // Seeding every pairing up front is what makes switching transport
      // arrive at sensible defaults with no onChange plumbing — the fields of
      // a transport not currently chosen are inert until it is.
      initialState: {
        'name': name,
        // Every offered pairing's prefill, then the SELECTED one's on top:
        // two variants can name the same key, and the one the form actually
        // opens on is the one whose value belongs in the box. (A registry
        // self-check forbids them disagreeing at all, so this only decides
        // the order in which identical values land — it is the guard that
        // makes the merge safe, and this makes it correct anyway.)
        for (final candidate in variants) ...candidate.defaultConfig,
        ...type.defaultConfig,
        ...config,
        if (choosable) 'transport': type.transportKey,
      },
      // Runs per field on submit, so a bad address blocks the save and says
      // so on the address field rather than failing later at connect time.
      // Asks the pairing the form is currently on: a field belonging to a
      // transport the operator switched away from is not theirs to get right.
      validator: (key, value, values) async => typeForState(values).validateField(key, value, values),
      // A transport's own action — the web serial transport's "add a USB
      // device" option, so far, living inside the port field's own list —
      // CatService's layer speaks its own EquipmentActionResult rather
      // than importing halo_widgets, so this is the one place that
      // translates.
      onAction: (actionKey, method, state) async {
        final actionResult = await typeForState(state).runAction(actionKey, method, state);
        if (actionResult == null) return null;
        return FormActionResult(
          message: actionResult.message,
          fieldUpdates: actionResult.fieldUpdates,
          // A field changing might mean something newly exists to pick —
          // the granted device isn't in the ORIGINAL options at all, so
          // its own field alone isn't enough to make it selectable.
          elements: actionResult.fieldUpdates == null ? null : buildElements(),
        );
      },
      // Only when the equipment already exists — there is nothing to delete
      // from the Add flow. Closes the editor before confirming: the question
      // is about the equipment, not about this form's unsaved edits, and
      // leaving the pane behind it would offer to Save a node about to be
      // gone.
      destructiveAction: node == null
          ? null
          : (
              label: st.remove,
              color: Theme.of(context).colorScheme.error,
              // showFormPane closes the pane before calling this, so all
              // that is left here is the confirmation.
              onPressed: () => unawaited(_removeEquipment(context, node)),
            ),
      // Cancel/Save/Close and the rest of the pane's chrome. Without this
      // the form's own fields are translated and the buttons around them
      // are not.
      labels: formRendererLabelsFor(context.t),
    );
    if (result == null) return null;

    return (
      typeKey: typeForState(result).key,
      name: (result['name'] as String? ?? '').trim(),
      // `transport` is the form's own discriminator, not a setting any
      // transport or driver reads — it leaves with the typeKey it chose.
      // Everything else stays, including fields belonging to a transport not
      // currently selected: switching back has to find them still there, and
      // `targetFor` narrows to what the connection actually needs anyway.
      config: {
        for (final entry in result.entries)
          if (entry.key != 'name' && entry.key != 'transport') entry.key: entry.value,
      },
    );
  }

  Future<void> _removeEquipment(BuildContext context, EquipmentNode node) async {
    final st = context.t.settings.station;
    final confirmed = await showHaloDialog<bool>(
      context: context,
      builder: (context) => HaloDialog(
        title: Text(st.removeTitle(name: _displayName(node))),
        content: Text(st.removeMessage),
        cancel: TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.t.common.cancel),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(st.remove),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _cat.removeNode(node.uuid);
  }

  String _displayName(EquipmentNode node) {
    if (node.name.isNotEmpty) return node.name;
    return _cat.typeFor(node)?.name ?? node.typeKey;
  }

  @override
  Widget build(BuildContext context) {
    final st = context.t.settings.station;

    return ListenableBuilder(
      listenable: _cat,
      builder: (context, _) {
        final safeLeft = PaneSafeArea.leftOf(context);
        final nodes = _cat.nodes;
        // Every transceiver the station knows about, connected or not —
        // this is the station's configuration, not its current link state.
        final transceivers = [
          for (final node in nodes)
            if (_cat.typeFor(node)?.category == kCategoryTransceiver) node,
        ];

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          children: [
            // What the station IS right now: the choices that decide how the
            // rest of the app behaves. Today that is one question.
            Padding(
              padding: EdgeInsets.only(left: safeLeft),
              child: SectionHeader(st.currentConfiguration),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(safeLeft + 16, 8, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                // FormFieldState reads `initialValue` once and never again
                // (its didUpdateWidget only handles forceErrorText), so
                // without a key that changes with the value this dropdown
                // shows whatever radio1 was on first build. CatService
                // reassigns it behind this panel's back — auto-designating
                // the first transceiver added, and re-designating when the
                // current one is removed — and neither would have appeared.
                      key: ValueKey(_cat.radio1),
                      // Without this the button lays its SELECTED item out
                      // unbounded, so ellipsizing the menu entries is not
                      // enough — a name wider than the field overflows the
                      // row rather than truncating.
                      isExpanded: true,
                      initialValue: transceivers.any((n) => n.uuid == _cat.radio1) ? _cat.radio1 : null,
                      icon: dropdownTrailingIcon,
                      decoration: poloFieldDecoration(context, st.transceiverForMainVfo),
                      menuMaxHeight: dropdownMenuMaxHeight(context),
                      items: [
                        DropdownMenuItem<String?>(value: null, child: Text(st.noTransceiver)),
                        for (final radio in transceivers)
                          DropdownMenuItem<String?>(
                            value: radio.uuid,
                            // Ellipsized: a DropdownMenuItem lays its child out
                            // unbounded, so a name longer than the field is wide
                            // — the operator's own, or a default like "Generic
                            // Radio via rigctld" — overflows the row rather
                            // than truncating.
                            child: Text(_displayName(radio), overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (uuid) => unawaited(_cat.setRadio1(uuid)),
                    ),
                  ),
                  // How the app behaves towards whichever radio is selected
                  // above — not that radio's own configuration, which is
                  // inside its row in the inventory below. Same tune glyph
                  // and the same target-built dialog the logging panel uses.
                  Builder(
                    builder: (buttonContext) => IconButton(
                      // The app shows no hover tooltips
                      // (docs/design/user-interface.md), so the accessible
                      // name is the only place this button is named.
                      icon: Icon(MdiIcons.tune, semanticLabel: st.currentRadioSettings),
                      onPressed: () => showSettingsForTarget(
                        buttonContext,
                        services: services,
                        target: 'current-radio',
                        title: st.currentRadioSettings,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // What the station is made OF. Every piece of equipment, whatever
            // its category and whether or not it is in use.
            Padding(
              padding: EdgeInsets.only(left: safeLeft),
              child: SectionHeader(st.equipmentInventory),
            ),
            if (nodes.isEmpty) ListTile(title: Text(st.none)),
            for (final node in nodes)
              _EquipmentTile(
                node: node,
                type: _cat.typeFor(node),
                state: _cat.stateFor(node.uuid),
                displayName: _displayName(node),
                isMainVfo: _cat.isRadio1(node.uuid),
                onEdit: () => _editEquipment(context, node),
                onRemoveUnknown: () => _removeEquipment(context, node),
                onConnect: () => _cat.connect(node.uuid),
                onDisconnect: () => _cat.disconnect(node.uuid),
              ),
            ListTile(
              leading: const Icon(MdiIcons.plus),
              title: Text(st.add),
              onTap: () => _addEquipment(context),
              mouseCursor: SystemMouseCursors.click,
            ),
          ],
        );
      },
    );
  }
}

/// How far the equipment list has to scroll before the discovery section
/// folds away. Plain logical pixels, deliberately: every Scrollable lives
/// BELOW the app's UiScale wrapper, so `metrics.pixels` is already in the
/// same scaled space this constant is written in — multiplying by the font
/// scale would double-scale it (docs/design/ui-scaling.md). Matches the
/// threshold the Home screen's FAB collapse uses.
const _discoveryCollapseAfter = 10.0;

/// Picking what to add: every radio the app knows, filtered by a search box,
/// with whatever announced itself on the network pinned underneath.
///
/// Stateful because two things here are the dialog's own and belong to
/// nothing else — the filter text and whether the discovery section is
/// currently folded away.
class _AddEquipmentDialog extends StatefulWidget {
  final CatService cat;

  /// False when no pairing on this platform could discover anything, in
  /// which case the section is absent rather than permanently empty.
  final bool showDiscovery;

  final List<EquipmentType> Function(EquipmentModel model) supportedVariants;

  const _AddEquipmentDialog({
    required this.cat,
    required this.showDiscovery,
    required this.supportedVariants,
  });

  @override
  State<_AddEquipmentDialog> createState() => _AddEquipmentDialogState();
}

class _AddEquipmentDialogState extends State<_AddEquipmentDialog> {
  final _searchController = TextEditingController();

  /// Folded away once the operator scrolls into the list. Starts open: with
  /// a short list nothing ever scrolls, and the section is the whole point
  /// of the dialog for a radio that announces itself.
  var _discoveryExpanded = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Decides the fold from a scrollable's current metrics.
  ///
  /// Folding gives the list the room the section was using, which can stop
  /// the list overflowing at all — so this reads `maxScrollExtent` as well as
  /// `pixels`. A list with nowhere left to scroll is not being browsed, and
  /// the operator has no way to scroll back up to ask for the section
  /// either, so it comes back.
  ///
  /// The consequence, which is the intended one: a list that overflows by
  /// less than the section gives up settles back OPEN after one frame,
  /// because folding it away bought nothing. Only a list still scrollable
  /// after the fold stays folded.
  void _applyScrollMetrics(ScrollMetrics metrics) {
    if (metrics.maxScrollExtent <= 0) return _setDiscoveryExpanded(true);
    _setDiscoveryExpanded(metrics.pixels <= _discoveryCollapseAfter);
  }

  void _setDiscoveryExpanded(bool expanded) {
    if (_discoveryExpanded == expanded) return;
    setState(() => _discoveryExpanded = expanded);
  }

  /// Matches the radio's name and the ways it can be reached, so "usb" finds
  /// every rig with a cable and "705" finds the one radio — an operator
  /// searching this list is as likely to know how a radio plugs in as what
  /// its family is called.
  bool _matches(({EquipmentModel model, List<EquipmentType> variants, String name}) row, String query) {
    if (query.isEmpty) return true;
    if (row.name.toLowerCase().contains(query)) return true;
    return row.variants.any((type) => type.transportLabel.toLowerCase().contains(query));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.cat,
      builder: (context, _) {
        final st = context.t.settings.station;
        final query = _searchController.text.trim().toLowerCase();
        // A radio whose transport can't connect on this platform at all
        // (TCP, Icom network, on web) would only fail loudly once picked —
        // no point offering it.
        // Resolved ONCE per model. Both the variants and the name cost real
        // work — `supportedVariants` scans the type list per variant, and
        // `name` is a localization lookup — and every one of them would
        // otherwise be repeated for the filter, the subtitle, the glyphs and
        // each comparison the sort makes, on every keystroke in the search box.
        final rows = [
          for (final model in widget.cat.registry.models)
            if (widget.supportedVariants(model) case final variants when variants.isNotEmpty)
              (model: model, variants: variants, name: model.name),
        ]
          // Sorted HERE rather than in the registry, because a model's name is
          // read from the current locale at call time — an order fixed at
          // declaration would be alphabetical in whichever language happened
          // to be active first. Case-insensitive, so a lower-case brand name
          // doesn't sort below every capitalised one.
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        final models = [
          for (final row in rows)
            if (_matches(row, query)) row,
        ];

        return HaloDialog(
          // Rows run edge to edge and the content scrolls itself, so the
          // shell must not also try to scroll it — halo_dialog.dart says an
          // Expanded/self-scrolling child REQUIRES scrollable: false.
          wide: true,
          scrollable: false,
          contentPadding: EdgeInsets.zero,
          title: Text(st.addTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  // Per docs/design/user-interface.md: focusing a field must
                  // not select what is in it.
                  selectAllOnFocus: false,
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(MdiIcons.magnify, size: 18),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(MdiIcons.close, size: 18, semanticLabel: context.t.formChrome.clear),
                            onPressed: () => setState(_searchController.clear),
                          ),
                    hintText: st.searchHint,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              if (widget.showDiscovery) ..._discoverySection(context),
              // BOTH scrolling regions are flex children, and that is what
              // keeps this dialog from overflowing: with `scrollable: false`
              // an inflexible child takes its full height off the top, so a
              // handful of announced radios would squeeze the catalogue to
              // nothing and one more would overflow the card outright.
              //
              // Loose flex, so neither claims room it does not want: on a tall
              // dialog each takes its natural height and the card shrink-wraps.
              // The weighting only decides who yields when there is not enough
              // — and the catalogue is what the operator came for.
              Flexible(
                flex: 4,
                // TWO listeners, and the second is not redundant. A scroll
                // position corrected during LAYOUT — the list shrinking under
                // a filter, or growing back when one is cleared, or gaining
                // the room the fold just freed — moves `pixels` without ever
                // dispatching a ScrollNotification. Only ScrollMetricsNotification
                // reports it, and it is not a ScrollNotification. Listening to
                // the first alone leaves the section folded shut with an
                // un-scrollable list under it and no gesture that reopens it.
                child: NotificationListener<ScrollMetricsNotification>(
                  onNotification: (notification) {
                    _applyScrollMetrics(notification.metrics);
                    return false;
                  },
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      _applyScrollMetrics(notification.metrics);
                      // Keep bubbling: these listeners observe, they do not consume.
                      return false;
                    },
                    child: models.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                          child: Text(st.noMatches, textAlign: TextAlign.center),
                        )
                      : ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.only(bottom: 8),
                          children: [
                            for (final row in models)
                              ListTile(
                                leading: Icon(_iconForCategory(row.model.category)),
                                title: Text(row.name),
                                subtitle: _modelSubtitle(context, row.variants),
                                // The glyphs belong beside the radio's NAME,
                                // not halfway down the row. Material 3 centres
                                // `leading`/`trailing` against the whole tile
                                // unless told otherwise, so a row carrying an
                                // untested caveat would otherwise drop them a
                                // line — wrapping them in a shrink-wrapping
                                // Column does NOT do this, only the alignment
                                // does.
                                titleAlignment: ListTileTitleAlignment.top,
                                trailing: _TransportIcons(types: row.variants),
                                onTap: () => Navigator.of(context).pop(_AddChoice.model(row.model)),
                                mouseCursor: SystemMouseCursors.click,
                              ),
                          ],
                        ),
                  ),
                ),
              ),
            ],
          ),
          cancel: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.t.common.cancel),
          ),
        );
      },
    );
  }

  /// What announced itself, under a title that never changes.
  ///
  /// The title is permanent on purpose: discovery runs for as long as this
  /// dialog is open, so a heading that switched between "searching" and
  /// "found" would be describing the same unfinished activity twice, and the
  /// section would jump around as radios appeared.
  ///
  /// Spread into the dialog's own Column rather than returned as one widget:
  /// the body has to be a flex sibling of the equipment list for the two to
  /// share a short dialog, and a nested Column would hide it from that.
  List<Widget> _discoverySection(BuildContext context) {
    final st = context.t.settings.station;
    final theme = Theme.of(context);
    final found = widget.cat.discovered;
    final error = widget.cat.discoveryError;

    return [
        // The spinner rides the title rather than taking a row of its own:
        // discovery runs for as long as this dialog is open, so a row that
        // exists only to say so pushed the catalogue down the whole time.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  st.lookingForEquipment,
                  style: theme.textTheme.titleSmall?.copyWith(color: HaLoColors.of(context).onSurfaceAccent),
                ),
              ),
              if (error == null) ...[
                const SizedBox(width: 8),
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ],
          ),
        ),
        // AnimatedSize alone, with no controller: the collapse is a plain
        // implicit animation, the way the Home screen's FAB does it. No
        // settle-epoch guard like that one either — a RenderAnimatedSize can
        // be stranded mid-flight by a muted ticker, but this lives in a modal
        // that is rebuilt from scratch every time it opens.
        Flexible(
          flex: 1,
          child: AnimatedSize(
          duration: layoutAnimationDuration,
          curve: layoutAnimationCurve,
          // Fold upward, so the rows slide out under the title rather than
          // the title walking down the dialog.
          alignment: Alignment.topCenter,
          child: !_discoveryExpanded
              ? const SizedBox(width: double.infinity)
              : SingleChildScrollView(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (error != null)
                      ListTile(
                        leading: Icon(MdiIcons.wifiOff, color: theme.colorScheme.error),
                        title: Text(st.discoveryUnavailable(error: error)),
                      )
                    else
                      for (final device in found)
                        ListTile(
                          leading: Icon(_iconForCategory(widget.cat.registry.typeFor(device.typeKey)?.category)),
                          title: Text(device.name),
                          subtitle: device.detail == null ? null : Text(device.detail!),
                          titleAlignment: ListTileTitleAlignment.top,
                          trailing: switch (widget.cat.registry.typeFor(device.typeKey)) {
                            final type? => _TransportIcons(types: [type]),
                            _ => null,
                          },
                          onTap: () => Navigator.of(context).pop(_AddChoice.discovered(device)),
                          mouseCursor: SystemMouseCursors.click,
                        ),
                    ],
                    ),
                ),
        ),
        ),
        const Divider(height: 1),
    ];
  }
}

/// Either a device that announced itself (ready to add as-is) or a type to
/// configure by hand.
class _AddChoice {
  /// The radio, not the pairing: how it is connected is chosen in the
  /// editor, alongside the settings that choice decides.
  final EquipmentModel? model;
  final DiscoveredEquipment? discovered;

  const _AddChoice.model(this.model) : discovered = null;
  const _AddChoice.discovered(this.discovered) : model = null;
}

/// The same glyph the logging panel's own Radio control uses — a
/// transceiver should look like one thing throughout the app.
IconData _iconForCategory(String? category) =>
    category == kCategoryTransceiver ? MdiIcons.radio : MdiIcons.developerBoard;

/// What the Add list says under a radio's name: which of its pairings have
/// never met a radio, and nothing else.
///
/// Only the caveat, because the transports themselves are now the row's
/// trailing glyphs — naming them here as well would say the same thing twice
/// in one row. A model with every pairing untested carries the caveat whole
/// rather than per transport; a MIXED one has to name which, since the
/// IC-705's WiFi is proven on hardware and its USB side has never been
/// pointed at a radio, and one marker for the model would be wrong either
/// way round.
Widget? _modelSubtitle(BuildContext context, List<EquipmentType> variants) {
  final st = context.t.settings.station;
  final untested = [
    for (final type in variants)
      if (!type.hardwareVerified) type,
  ];
  if (untested.isEmpty) return null;
  if (untested.length == variants.length) return Text(st.unverified);
  return Text(untested.map((type) => '${type.transportLabel} (${st.unverifiedShort})').join(' · '));
}

/// How a pairing is plugged in, as a glyph — see `transportIconNameFor`.
///
/// Null when the transport has no glyph, so a caller leaves the slot empty.
/// Deliberately not defaulted to something generic: `resolveIconName` answers
/// an unknown name with a puzzle piece, and a puzzle piece next to a radio
/// says less than nothing.
IconData? _iconForTransport(EquipmentType type) {
  final name = type.transportIconName;
  return name == null ? null : resolveIconName(name);
}

/// The transport glyphs of a model's pairings, in one small row.
///
/// Size is spelled out because this is not a ListTile slot — those inherit 24
/// from the tile's own IconTheme, and this sits beside body text.
class _TransportIcons extends StatelessWidget {
  final List<EquipmentType> types;

  const _TransportIcons({required this.types});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icons = [
      for (final type in types)
        if (_iconForTransport(type) case final icon?) (icon: icon, label: type.transportLabel),
    ];
    if (icons.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // By index, not by `entry != icons.first`: these are records, which
        // compare by VALUE, so two pairings sharing a glyph and a label would
        // both count as the first and the second would lose its gap.
        for (final (index, entry) in icons.indexed) ...[
          if (index > 0) const SizedBox(width: 4),
          Icon(
            entry.icon,
            size: 16,
            // The app has no hover tooltips, so this is the only place the
            // glyph is named for anyone who cannot see it.
            semanticLabel: entry.label,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ],
    );
  }
}

class _EquipmentTile extends StatelessWidget {
  final EquipmentNode node;
  final EquipmentType? type;
  final EquipmentState state;
  final String displayName;

  /// This is `radio1` — the node whose VFO is the logging panel's, shown
  /// to the operator as "Main VFO".
  final bool isMainVfo;
  final VoidCallback onEdit;

  /// Only reachable for a record whose type isn't in the catalogue — every
  /// other row removes from inside the editor.
  final VoidCallback onRemoveUnknown;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _EquipmentTile({
    required this.node,
    required this.type,
    required this.state,
    required this.displayName,
    required this.isMainVfo,
    required this.onEdit,
    required this.onRemoveUnknown,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final st = context.t.settings.station;
    final theme = Theme.of(context);
    final resolvedType = type;

    // A record whose type isn't in the catalogue — written by a newer build,
    // or by a driver since removed. It stays listed and says so, rather than
    // silently disappearing along with the user's settings.
    if (resolvedType == null) {
      return ListTile(
        leading: Icon(MdiIcons.helpCircleOutline, color: theme.colorScheme.error),
        title: Text(displayName),
        subtitle: Text(st.unknownType(typeKey: node.typeKey)),
        // An unrecognized type has no editor to put Remove inside, so this
        // row keeps its own — it is the only way to get rid of the record.
        trailing: IconButton(
          icon: Icon(MdiIcons.deleteOutline, semanticLabel: st.remove),
          onPressed: onRemoveUnknown,
        ),
      );
    }

    // Both directions take time and both deserve the spinner: connecting
    // negotiates a handshake, disconnecting sends a goodbye that must not be
    // rushed.
    final busy = state.status == EquipmentStatus.connecting ||
        state.status == EquipmentStatus.disconnecting;
    final vfo = state.vfo;
    final reading = [
      if (vfo.mode != null) vfo.mode!,
      // To the Hz, not [fmtFreq]'s 100 Hz: this row is the app's view of
      // where the rig actually is, and Smart VFO Snap's whole effect lives in
      // the digits fmtFreq drops.
      if (vfo.freqKHz != null) fmtFreqToTheHz(vfo.freqKHz!),
    ].join('  ');
    final connected = state.status == EquipmentStatus.connected;

    final failed = state.status == EquipmentStatus.error && state.error != null;

    // Two lines. The top one is identity — what it is, then where it is.
    // The bottom is what it is doing, EXCEPT when something went wrong, in
    // which case the reason takes the whole row: an explanation squeezed
    // into half a line and ellipsized is not an explanation.
    //
    // Both rows split with spaceBetween rather than a Spacer or a trailing
    // Expanded: a flex child that uses LESS than its share leaves the slack
    // at the END of the row, which keeps the right-hand items from reaching
    // the edge.
    return ListTile(
      leading: Icon(_iconForCategory(resolvedType.category)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 3:2 — identity earns more of the row than the address does, and
          // a pill is a fixed-width thing competing with a name that can
          // ellipsize, so the split has to favour this side.
          Flexible(
            flex: 3,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(displayName, overflow: TextOverflow.ellipsis)),
                // Beside the name: which radio drives the logging panel is
                // part of what this equipment IS, not what it is doing.
                if (isMainVfo) ...[
                  const SizedBox(width: 8),
                  // Flexible, because the pill has an intrinsic width and a
                  // non-flex child in a bounded Row overflows rather than
                  // shrinking — the name collapses to nothing and the row
                  // still blows past the edge by whatever the pill needed.
                  Flexible(
                    child: _Pill(
                      label: st.mainVfo,
                      background: theme.colorScheme.secondaryContainer,
                      foreground: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Flexible(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Flexible so the address ellipsizes instead of pushing the
                  // glyph off the row — the glyph is a fixed width competing
                  // with text that can be any length.
                  Flexible(
                    child: Text(
                      resolvedType.describeTarget(node.config),
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // How it is plugged in, right where it says where it is.
                  _TransportIcons(types: [resolvedType]),
                ],
              ),
            ),
          ),
        ],
      ),
      subtitle: failed
          ? Text(
              state.error!,
              // Two lines' worth: these say what to do about it, and the
              // useful part is rarely in the first forty characters.
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    reading,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      // Dimmed once it is no longer being confirmed. The
                      // number is the last thing the radio actually said,
                      // and how old it is matters as much as what it is.
                      color: state.stale
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (connected)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: _Pill(
                      // A link that is up but silent must not wear the same
                      // confident green as one that is working: the
                      // frequency shown may be minutes old.
                      label: state.stale ? st.statusStale : st.statusConnected,
                      background: state.stale ? theme.colorScheme.error : _connectedGreen(theme),
                      foreground: Colors.white,
                    ),
                  ),
              ],
            ),
      trailing: _ConnectionToggle(
        busy: busy,
        connected: connected,
        onConnect: onConnect,
        onDisconnect: onDisconnect,
      ),
      onTap: onEdit,
      mouseCursor: SystemMouseCursors.click,
    );
  }
}

/// One green that reads on both a light and a dark surface. Spelled out
/// because the scheme has no semantic "success" colour, and `primary` is the
/// app's accent — it says nothing about being connected.
Color _connectedGreen(ThemeData theme) =>
    theme.brightness == Brightness.dark ? Colors.green.shade600 : Colors.green.shade700;

/// A small rounded label. Same shape as activities_view's
/// `_AlreadySelectedChip` — nothing pill-like is exported from halo_widgets,
/// and that chip says the same kind of thing about a row. Plain logical
/// pixels: the Font Scale setting scales the whole UI from one root wrapper
/// (docs/design/ui-scaling.md).
class _Pill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _Pill({required this.label, required this.background, required this.foreground});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(10)),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}

/// The plug: pulled out (grey) or pushed in (green). Pressing it does the
/// other thing. A glyph rather than a "Not connected" label plus a Connect
/// button — two localized words' worth of row width to say what one glyph
/// says, on a row whose whole point is to show a live frequency.
class _ConnectionToggle extends StatelessWidget {
  final bool busy;
  final bool connected;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _ConnectionToggle({
    required this.busy,
    required this.connected,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final st = context.t.settings.station;
    final theme = Theme.of(context);

    if (busy) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    // No semantic "success" colour in the scheme, so it is spelled out here
    // rather than borrowed from `primary` (which is the app's accent and
    // says nothing about being connected). Two shades because one green
    // cannot carry both a light and a dark surface.
    return IconButton(
      icon: Icon(
        connected ? MdiIcons.powerPlug : MdiIcons.powerPlugOff,
        // The app has no hover tooltips, so the accessible name is the only
        // place this control is named.
        semanticLabel: connected ? st.disconnect : st.connect,
        color: connected ? _connectedGreen(theme) : theme.colorScheme.onSurfaceVariant,
      ),
      onPressed: connected ? onDisconnect : onConnect,
    );
  }
}
