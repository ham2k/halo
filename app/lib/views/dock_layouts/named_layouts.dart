// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Named layouts and layout files, as the dock host carries them out
// (docs/design/layouts.md § Named layouts, § Layout files). A part of
// dock_host.dart rather than more of it: the host's per-class state is
// private to that library, and this is the half of the host that switches it.

part of '../dock_host.dart';

extension NamedLayouts<T extends StatefulWidget> on DockHost<T> {
  /// Whether the named-layout controls are offered. The stored list is read
  /// either way: with the experiment off the view goes on drawing whichever
  /// layout was last chosen, rather than swapping the operator's arrangement
  /// for another one under them.
  bool get namedLayoutsOffered => dockServices.settings.experimentEnabled('layouts') /* stored key, see experiments.yaml */;

  /// What [layout] is called on screen. Only a list that could not be read
  /// leaves a layout other than the first one without a name.
  String layoutName(ViewLayout layout) =>
      layout.name ?? (layout.id == ViewLayouts.defaultId ? _t.layouts.defaultName : _t.layouts.untitledName(number: layout.id));

  /// The stored list, as [ViewLayouts.read] makes it out. One it had to
  /// recover is written back at once, so the operator is told once, not on
  /// every launch until something else writes the list.
  ViewLayouts _readViewLayouts() {
    final read = ViewLayouts.read(dockServices.settings, dockView);
    if (read.recovered) {
      // Not from here: this runs from `build`, and both calls notify.
      scheduleMicrotask(() {
        if (!mounted) return;
        unawaited(read.write(dockServices.settings, dockView));
        dockServices.statusBar.showNotice(
          key: 'layouts:$dockView:recovered',
          icon: 'alert-circle',
          title: _t.layouts.listRecoveredTitle,
          text: _t.layouts.listRecoveredBody,
        );
      });
    }
    return read;
  }

  void _replaceClasses(String layoutId) {
    for (final entry in _dockClasses.entries) {
      if (entry.value.recoveredDefaultNoticeListener case final listener?) {
        dockServices.statusBar.removeListener(listener);
        // Its action writes into the layout going off screen; drawing that
        // one again raises the notice again.
        dockServices.statusBar.dismissNotice('layout:$dockView:${entry.key.name}:unreadable');
      }
    }
    _dockClasses = _classesFor(layoutId);
  }

  /// Re-reads the stored list, keeping the layout this view draws. A second
  /// view of the same kind (an Operation view stacked over another) changes
  /// the same list, and a change made against a stale copy would hand out
  /// its ids again and write its layouts out of the list.
  void refreshLayouts() {
    final stored = _readViewLayouts();
    final mine = viewLayouts.activeLayout;
    _layoutDeletedElsewhere = stored[mine.id] == null ? mine.id : null;
    viewLayouts = stored.copyWith(active: mine.id, layouts: [...stored.layouts, if (_layoutDeletedElsewhere != null) mine]);
  }

  Future<void> _writeLayouts(ViewLayouts next) {
    var listed = next;
    var gone = _layoutDeletedElsewhere;
    if (gone != null && listed.active != gone) {
      // Moved off it: out of this view's list as well as the stored one.
      _layoutDeletedElsewhere = null;
      if (listed[gone] != null) listed = listed.without(gone);
      gone = null;
    }
    viewLayouts = listed;
    // Written back, it would be a layout again in both views, opening on the
    // keys the delete emptied — kept only when nothing else is left to draw.
    final written = gone != null && listed[gone] != null && listed.layouts.length > 1 ? listed.without(gone) : listed;
    return written.write(dockServices.settings, dockView);
  }

  /// Empties every key [layoutId] stores under, in both classes. Run before a
  /// new layout takes an id too: a key left behind by one that went before
  /// would otherwise be what the new layout opens on.
  ///
  /// Emptied rather than removed: every reader takes an empty map as nothing
  /// stored, and a remover would cost the settings service a method.
  Future<void> _clearLayoutKeys(String layoutId) async {
    final cleared = _clearedLayoutKeys(layoutId);
    if (cleared.isNotEmpty) await dockServices.settings.setLayoutValues(cleared);
  }

  /// What [_clearLayoutKeys] writes, for a caller with more to write at once.
  Map<String, Object> _clearedLayoutKeys(String layoutId) => {
    for (final layoutClass in DockLayoutClass.values)
      for (final key in dockKeysFor(layoutClass).forLayout(layoutId).all)
        if (dockServices.settings.layoutData(key) != null) key: const <String, dynamic>{},
  };

  /// The header's way into the layouts sheet, the same in and out of an
  /// edit: the layout's name, or on a phone, where the name does not fit
  /// beside the title, an icon.
  ///
  /// From the Add a Panel sheet's own header copy it takes that sheet down
  /// first. What the layouts sheet does next can end the edit, and the Add a
  /// Panel sheet left up past that writes its adds straight to settings.
  Widget _layoutSwitcher(BuildContext context, Color onHeader, {required bool inSheet}) {
    void open(double? rightInset) {
      if (inSheet) Navigator.of(context).pop();
      unawaited(showLayoutsSheet(this.context, this, rightInset: rightInset));
    }

    if (dockLayoutClass == DockLayoutClass.wide) return LayoutSwitcherButton(host: this, color: onHeader, onOpen: open);
    return IconButton(
      icon: Icon(
        MdiIcons.viewDashboardVariantOutline,
        color: onHeader,
        semanticLabel: _t.layouts.switcherLabel(name: layoutName(viewLayouts.activeLayout)),
      ),
      onPressed: () => open(null),
    );
  }

  /// Whether the edit in progress holds anything Save would write.
  bool get layoutDraftChanged {
    if (!layoutEditing) return false;
    if (_pendingSettingWrites.isNotEmpty) return true;
    const equality = DeepCollectionEquality();
    return _dockClasses.values.any(
      (klass) =>
          !equality.equals(klass.spec?.toJson(), klass.specSnapshot) ||
          !equality.equals(PaneLayoutOptions.mapToJson(klass.paneOptions), klass.paneOptionsSnapshot) ||
          !equality.equals(klass.viewOptions.toJson(), klass.viewOptionsSnapshot),
    );
  }

  /// Runs [leave], which draws another layout or takes this one away, from
  /// inside an edit as well as outside one. The edit ends first, saved when
  /// [save] says so and discarded otherwise, and opens again on whatever
  /// [leave] leaves on screen: an operator who moves to another layout from
  /// the editor is still editing.
  Future<R> leaveEditFor<R>(Future<R> Function() leave, {required bool save}) async {
    if (!layoutEditing) return leave();
    // Carried across rather than re-read: what has focus between the two
    // edits is the sheet that started this, and the panes stay out of
    // traversal for the second edit, so the field the operator left would
    // never be handed back.
    final focus = _focusBeforeLayoutEditing;
    save ? saveLayout() : revertLayout();
    try {
      return await leave();
    } finally {
      if (mounted) {
        _focusAtPress = focus;
        startLayoutEditing();
      }
    }
  }

  /// Draws the named layout [id]. Refused while editing: the draft belongs to
  /// the layout it began in, and a Save after a switch would write it into
  /// the other one.
  void switchLayout(String id) {
    refreshLayouts();
    if (layoutEditing || id == viewLayouts.active || viewLayouts[id] == null) return;
    _rebuild(() => _replaceClasses(id));
    unawaited(_writeLayouts(viewLayouts.copyWith(active: id)));
  }

  /// A new layout called [name], holding this view's default arrangements,
  /// and drawn.
  Future<void> createLayout(String name) async {
    if (layoutEditing) return;
    refreshLayouts();
    final id = viewLayouts.nextId();
    await _clearLayoutKeys(id);
    await _writeLayouts(
      viewLayouts.copyWith(
        layouts: [
          ...viewLayouts.layouts,
          ViewLayout(id: id, name: name),
        ],
      ),
    );
    if (mounted) switchLayout(id);
  }

  /// Names [id] and describes it; a null [description] shows its panels.
  Future<void> editLayout(String id, {required String name, String? description}) async {
    refreshLayouts();
    if (viewLayouts[id] == null) return;
    _rebuild(() => viewLayouts = viewLayouts.edited(id, name: name, description: description));
    await _writeLayouts(viewLayouts);
  }

  /// What the layouts sheet says under [layout]'s name: the operator's own
  /// description, or else the panels it holds — which is also what the
  /// description field offers as its hint, so leaving it blank is a choice
  /// the operator can see the result of.
  String layoutDescription(ViewLayout layout) => layout.description ?? layoutPaneTitles(layout.id).join(' · ');

  /// A copy of [id] called [name], drawn. A copy, not a second name for the
  /// same placements: each instance gets an id of its own with its settings
  /// copied into it, or typing in one copy's notes pane would change the
  /// other's.
  ///
  /// From the editor the copy is of the draft on screen, and [id] keeps what
  /// it last saved: the edit carries on in the copy, shared panels' settings
  /// an import queued for Save included.
  Future<void> duplicateLayout(String id, String name) async {
    final file = await buildLayoutFile(id, {for (final layoutClass in DockLayoutClass.values) layoutClass: null}, includeSecrets: true);
    if (file == null) return;
    final queued = Map.of(_pendingSettingWrites);
    await importLayout(file.arrangements, mode: LayoutImportMode.newLayout, name: name, description: file.description);
    if (layoutEditing) _pendingSettingWrites.addAll(queued);
  }

  /// Deletes the named layout [id], and with it whatever its panel instances
  /// held — the same as removing those panes from it would. Refused for the
  /// last layout: a view has to draw something.
  Future<void> deleteLayout(String id) async {
    refreshLayouts();
    if (layoutEditing || viewLayouts.layouts.length < 2 || viewLayouts[id] == null) return;
    final placed = {
      for (final layoutClass in DockLayoutClass.values) ..._arrangementOf(id, layoutClass, fallBackToDefault: false)?.spec.collectModules() ?? const <String>[],
    };
    final next = viewLayouts.without(id);
    if (viewLayouts.active == id) _rebuild(() => _replaceClasses(next.active));
    await _writeLayouts(next);
    // Another view of this kind drawing it (one stacked under this) moves off
    // it now, draft and all, as this one did: left on it, its panes would
    // show instances forgotten below, and ids handed to the next placement.
    for (final other in DockHost._mountedHosts) {
      if (other == this || other.dockView != dockView || other.viewLayouts.active != id) continue;
      unawaited(other.leaveEditFor(() async => other.switchLayout(next.active), save: false));
    }
    await _clearLayoutKeys(id);
    // A single-placement panel's settings belong to the panel and another
    // layout may be showing it; `forgetInstanceConfig` keeps those anyway,
    // and this keeps an instance some other layout still names.
    final elsewhere = {..._instanceIdsInEveryDock()};
    for (final pane in placed.difference(elsewhere)) {
      panelTitles.remove(pane);
      unawaited(_forgetInstance(pane));
    }
    if (mounted) _rebuild(() {});
  }

  /// [PanelService.forgetInstanceConfig], and for an instance whose panel is
  /// not loaded to name its fields, every plain value stored under its id:
  /// what a layout file wrote for it, or a copy took from a switched-off
  /// extension's instance. Secrets cannot be listed, and stay.
  ///
  /// The same plain values go when the forget fails: it goes a field at a
  /// time, and a keychain refusing one secret leaves every field after it for
  /// the next pane handed this id.
  Future<void> _forgetInstance(String id) async {
    final instance = PanelDefinition.descriptorIdOf(id) != id;
    try {
      await dockServices.panels.forgetInstanceConfig(id);
    } catch (_) {
      if (instance) await dockServices.extensions.forgetStoredPanelValues(id);
      rethrow;
    }
    if (instance && dockServices.panels[id] == null) await dockServices.extensions.forgetStoredPanelValues(id);
  }

  /// Writes [writes] into the fresh instance ids they are keyed by. One that
  /// fails takes out what the rest wrote before it rethrows: a half-written
  /// slot opens in the next pane handed its id.
  Future<void> _writeInstanceSettings(Map<String, Map<String, dynamic>> writes) async {
    final written = <String>[];
    try {
      for (final entry in writes.entries) {
        written.add(entry.key);
        await _writePanelSettings(entry.key, entry.value);
      }
    } catch (e, stack) {
      await _forgetEach(written);
      Error.throwWithStackTrace(e, stack);
    }
  }

  /// [_forgetInstance] for each of [ids], each its own [_undoStep]: the
  /// failure that sent the undo here is likely to refuse the first forget
  /// too, and the rest still have to go.
  Future<void> _forgetEach(Iterable<String> ids) async {
    for (final id in ids) {
      await _undoStep(() => _forgetInstance(id));
    }
  }

  /// One step of undoing a write that failed: reported if it fails too, and
  /// never in the way of the next step or of the failure being rethrown.
  Future<void> _undoStep(Future<void> Function() step) async {
    try {
      await step();
    } catch (e, stack) {
      ErrorReportingService.report(e, stack, context: 'layout:undo');
    }
  }

  /// One class of the named layout [layoutId]: the live draft for the layout
  /// on screen, otherwise what storage holds — or the view's default where it
  /// holds nothing, which is what drawing that layout would show. Null for a
  /// class with nothing stored when [fallBackToDefault] is off.
  ({DockNode spec, Map<String, PaneLayoutOptions> paneOptions, PaneLayoutOptions viewOptions})? _arrangementOf(
    String layoutId,
    DockLayoutClass layoutClass, {
    bool fallBackToDefault = true,
  }) {
    if (layoutId == viewLayouts.active) {
      ensureDockSpec(layoutClass);
      final klass = _dockClasses[layoutClass]!;
      return (spec: klass.spec!, paneOptions: klass.paneOptions, viewOptions: klass.viewOptions);
    }
    final keys = dockKeysFor(layoutClass).forLayout(layoutId);
    final settings = dockServices.settings;
    var spec = DockNode.fromJson(settings.layoutData(keys.spec));
    for (final retired in retiredModules) {
      spec = spec?.without(retired);
    }
    spec ??= fallBackToDefault ? buildDefaultDockSpec(layoutClass) : null;
    if (spec == null) return null;
    return (
      spec: spec,
      paneOptions: PaneLayoutOptions.mapFromJson(settings.layoutData(keys.paneOptions)),
      viewOptions: PaneLayoutOptions.fromJson(settings.layoutData(keys.viewOptions)),
    );
  }

  /// The panes the named layout [layoutId] holds in the class on screen, by
  /// name — what the layouts sheet lists under each one. The operator's own
  /// title first, then the panel's; never the live tab label, which can carry
  /// a count ("10 QSOs").
  List<String> layoutPaneTitles(String layoutId) {
    final source = _arrangementOf(layoutId, dockLayoutClass)!;
    return [
      for (final id in source.spec.collectModules())
        source.paneOptions[id]?.title ?? dockServices.panels[id]?.title ?? nativeTitles[id] ?? panelKeyOfPanelId(id),
    ];
  }

  /// The tree of one class of [layoutId], for the export dialog's diagram.
  DockNode arrangementSpec(String layoutId, DockLayoutClass layoutClass) => _arrangementOf(layoutId, layoutClass)!.spec;

  /// The named layout [layoutId] as a file: each class in [classes], pruned
  /// to the panes its `keep` accepts, or whole for null. Null when nothing
  /// is left to write.
  ///
  /// [includeSecrets] only for a copy that stays on this device — a file is
  /// something the operator hands to other people.
  Future<LayoutFile?> buildLayoutFile(String layoutId, Map<DockLayoutClass, bool Function(String id)?> classes, {bool includeSecrets = false}) async {
    final arrangements = <DockLayoutClass, LayoutFileArrangement>{};
    final extensionKeys = <String>{};
    for (final entry in classes.entries) {
      final source = _arrangementOf(layoutId, entry.key)!;
      final settings = <String, Map<String, dynamic>>{};
      for (final id in source.spec.collectModules()) {
        if (!(entry.value?.call(id) ?? true)) continue;
        settings[id] = await _panelSettingsOf(id, includeSecrets: includeSecrets);
        if (extensionKeyOfPanelId(id) case final key?) extensionKeys.add(key);
      }
      final arrangement = LayoutFileArrangement.fromDock(
        source.spec,
        paneOptions: source.paneOptions,
        viewOptions: source.viewOptions,
        settingsFor: (id) => settings[id] ?? const {},
        keep: entry.value,
      );
      if (arrangement != null) arrangements[entry.key] = arrangement;
    }
    if (arrangements.isEmpty) return null;
    final locale = LocaleSettings.currentLocale.languageCode;
    return LayoutFile(
      view: dockView,
      name: layoutName(viewLayouts[layoutId]!),
      description: viewLayouts[layoutId]!.description,
      extensions: [for (final key in extensionKeys) LayoutFileExtension(key: key, name: dockServices.extensions.extensionInfo(key)?.nameFor(locale))],
      arrangements: arrangements,
    );
  }

  Future<Map<String, dynamic>> _panelSettingsOf(String id, {required bool includeSecrets}) async {
    final panel = dockServices.panels[id];
    // An extension switched off still has what its panel stored; with no
    // fields to say which values are secret, only the plain ones are read.
    if (panel == null) return extensionKeyOfPanelId(id) == null ? const {} : dockServices.extensions.readStoredPanelValues(id);
    // Secret fields left out of the read, not only the result: each is a
    // keychain read, which can prompt or fail.
    final fields = [
      for (final field in panel.formFields)
        if (includeSecrets || field['fieldType'] != 'secret') field,
    ];
    if (fields.isEmpty) return const {};
    return dockServices.extensions.readPanelConfig(panelKey: panel.id, fields: fields);
  }

  /// [_writePanelSettings] once every write queued before it is done: Save
  /// writes the settings an import queued without waiting, and an import
  /// right after it writing the same panel's would otherwise interleave with
  /// it field by field.
  Future<void> _queuePanelSettings(String id, Map<String, dynamic> values) {
    final write = _panelSettingsQueue.then((_) => _writePanelSettings(id, values));
    // The queue only keeps the order; a failure is [write]'s, for its caller.
    _panelSettingsQueue = write.then((_) {}, onError: (Object _) {});
    return write;
  }

  Future<void> _writePanelSettings(String id, Map<String, dynamic> values) async {
    // Unknown fields for a panel whose extension is not here yet — stored as
    // plain values, which is all a file can hold, and read by the panel once
    // it is installed and declares them.
    final panel = dockServices.panels[id];
    for (final entry in values.entries) {
      final field = panel?.formFields.where((f) => f['key'] == entry.key).firstOrNull;
      await dockServices.extensions.commitSettingsFieldValue(
        kind: 'simple',
        hookKey: panel?.hookKey ?? id,
        panelKey: id,
        fieldKey: entry.key,
        value: entry.value,
        state: const {},
        isSecret: field?['fieldType'] == 'secret',
      );
    }
    dockServices.panels.markConfigChanged(id);
  }

  /// Whether this view can hold the panel [descriptorId] at all. An extension
  /// panel the catalog does not know is held (it renders as a missing
  /// panel, and installing its extension fills it in); another view's own
  /// pane is not.
  bool offersPanel(String descriptorId) {
    if (nativeModuleIds.contains(descriptorId)) return true;
    final panel = dockServices.panels[descriptorId];
    if (panel != null) return panel.availableIn(dockView);
    return extensionKeyOfPanelId(descriptorId) != null;
  }

  bool isMultiplePanel(String descriptorId, {required bool fileSaysInstance}) => dockServices.panels[descriptorId]?.multiple ?? fileSaysInstance;

  /// Which of [file]'s arrangements lands in which class when it replaces a
  /// whole layout: each in its own where the file has both, and its only one
  /// in the class on screen — the arrangement the operator is looking at
  /// while they import it. [shown] is that class as the import dialog drew
  /// it, which a resize behind the dialog does not change.
  Map<DockLayoutClass, LayoutFileArrangement> importTargets(LayoutFile file, LayoutImportMode mode, {DockLayoutClass? shown}) {
    final onScreen = shown ?? dockLayoutClass;
    if (mode == LayoutImportMode.add) return {onScreen: file.arrangements[onScreen] ?? file.arrangements.values.first};
    if (file.arrangements.length == 1) return {onScreen: file.arrangements.values.single};
    return Map.of(file.arrangements);
  }

  /// Panel descriptors [arrangement] places that [mode] would leave out: one
  /// this view does not offer, and — adding — one placed once that the
  /// arrangement on screen already shows.
  Set<String> importRefusals(LayoutFileArrangement arrangement, LayoutImportMode mode) {
    final present = mode == LayoutImportMode.add ? (dockKey.currentState?.modules ?? dockSpec?.collectModules() ?? const <String>[]).toSet() : const <String>{};
    return {
      for (final panel in arrangement.panels)
        if (!offersPanel(panel) || (present.contains(panel) && !isMultiplePanel(panel, fileSaysInstance: false))) panel,
    };
  }

  /// Brings [arrangements] (from [importTargets], already pruned to what the
  /// operator picked) into this view. Returns the panels left out, and the
  /// pinned ones put back: a file can leave out the pane a class pins (the
  /// log, on a phone), which is the only place some work can be done there.
  ///
  /// Nothing is made when nothing in the file is placed: a new layout of
  /// only the view's defaults is one the operator would have to delete.
  ///
  /// A new layout is written, then drawn. From the editor the edit ends only
  /// once the new layout is written — saved or discarded as [saveDraft]
  /// says — and carries on in it. One that fails partway is taken out again,
  /// with the instance settings it wrote, and the edit is left as it was:
  /// what it half-wrote would otherwise open in the next layout or pane
  /// handed those ids.
  ///
  /// Replacing or adding goes into the edit DRAFT instead, entering edit
  /// mode if need be, so Save and Discard mean what they always do — adding
  /// puts the panes in a column on the right, for the operator to drag where
  /// they belong. Their instance settings are written before the draft
  /// changes, so one that fails is taken out and leaves the draft untouched.
  ///
  /// Each instance gets an id clear of every layout's, and its settings are
  /// written at once: no other pane reads that slot, and a Discard forgets
  /// it like any pane the edit added. A panel placed once shares one set of
  /// settings with every layout showing it, so the file's only replace them
  /// with [replaceSharedSettings] — and in a draft, only on Save.
  Future<({List<String> skipped, List<String> restored})> importLayout(
    Map<DockLayoutClass, LayoutFileArrangement> arrangements, {
    required LayoutImportMode mode,
    String? name,
    String? description,
    bool replaceSharedSettings = false,
    bool saveDraft = false,
  }) async {
    final skipped = <String>[];
    final restored = <String>{};
    DockNode withPinned(DockNode spec, DockLayoutClass layoutClass) {
      final present = spec.collectModules().toSet();
      final missing = [
        for (final id in pinnedModuleIdsIn(layoutClass))
          if (!present.contains(id)) id,
      ];
      restored.addAll(missing);
      return missing.isEmpty ? spec : _withLeadingTabs(spec, missing);
    }

    final instanceWrites = <String, Map<String, dynamic>>{};
    final sharedWrites = <String, Map<String, dynamic>>{};
    void collectSettings(MaterializedArrangement result) {
      for (final entry in result.settings.entries) {
        if (PanelDefinition.descriptorIdOf(entry.key) != entry.key) {
          instanceWrites[entry.key] = entry.value;
        } else if (replaceSharedSettings) {
          sharedWrites[entry.key] = entry.value;
        }
      }
    }

    switch (mode) {
      case LayoutImportMode.newLayout:
        refreshLayouts();
        final id = viewLayouts.nextId();
        // An edit still running holds ids storage has not seen, and ones its
        // Discard is about to forget: none of them may be handed out again.
        final taken = {..._instanceIdsInEveryDock(), ..._allPendingForgets, for (final klass in _dockClasses.values) ...?klass.spec?.collectModules()};
        final placed = <DockLayoutClass, MaterializedArrangement>{};
        for (final entry in arrangements.entries) {
          final result = entry.value.materialize(isMultiple: isMultiplePanel, isOffered: offersPanel, takenIds: taken);
          skipped.addAll(result.skipped);
          if (result.spec case final spec?) {
            taken.addAll(spec.collectModules());
            placed[entry.key] = result;
          }
        }
        if (placed.isEmpty) return (skipped: skipped, restored: const <String>[]);
        var instancesWritten = false;
        try {
          // One write for every key: each is the whole layout map persisted
          // and every settings listener told.
          final writes = _clearedLayoutKeys(id);
          for (final MapEntry(key: layoutClass, value: result) in placed.entries) {
            final keys = dockKeysFor(layoutClass).forLayout(id);
            writes[keys.spec] = withPinned(result.spec!, layoutClass).toJson();
            writes[keys.paneOptions] = PaneLayoutOptions.mapToJson(result.paneOptions);
            writes[keys.viewOptions] = result.viewOptions.toJson();
            collectSettings(result);
          }
          await dockServices.settings.setLayoutValues(writes);
          await _writeInstanceSettings(instanceWrites);
          instancesWritten = true;
          await _writeLayouts(
            viewLayouts.copyWith(
              layouts: [
                ...viewLayouts.layouts,
                ViewLayout(id: id, name: name, description: description),
              ],
            ),
          );
        } catch (e, stack) {
          // [_writeInstanceSettings] takes out its own on failure.
          if (instancesWritten) await _forgetEach(instanceWrites.keys);
          await _undoStep(() => _clearLayoutKeys(id));
          await _undoStep(() async {
            refreshLayouts();
            if (viewLayouts[id] != null) await _writeLayouts(viewLayouts.without(id));
          });
          Error.throwWithStackTrace(e, stack);
        }
        if (mounted) await leaveEditFor(() async => switchLayout(id), save: saveDraft);
        // After the edit ends: a Save writes the settings it queued, and the
        // file's are the operator's later word.
        for (final entry in sharedWrites.entries) {
          await _queuePanelSettings(entry.key, entry.value);
        }
      case LayoutImportMode.replace:
        startLayoutEditing();
        if (!layoutEditing) return (skipped: const <String>[], restored: const <String>[]);
        // What the layout holds now is still stored until Save, so none of it
        // may be handed out again.
        final taken = {..._instanceIdsInEveryDock(), ..._allPendingForgets, for (final klass in _dockClasses.values) ...?klass.spec?.collectModules()};
        final placed = <DockLayoutClass, (DockNode, MaterializedArrangement)>{};
        for (final entry in arrangements.entries) {
          final result = entry.value.materialize(isMultiple: isMultiplePanel, isOffered: offersPanel, takenIds: taken);
          skipped.addAll(result.skipped);
          final placedSpec = result.spec;
          if (placedSpec == null) continue;
          final spec = withPinned(placedSpec, entry.key);
          taken.addAll(spec.collectModules());
          placed[entry.key] = (spec, result);
          collectSettings(result);
        }
        // Before the draft changes, so an import that fails leaves it as it was.
        final mark = _draftMark();
        await _writeInstanceSettings(instanceWrites);
        if (!_draftUnchanged(mark)) return await _abandon(instanceWrites.keys);
        for (final MapEntry(key: layoutClass, value: (spec, result)) in placed.entries) {
          final klass = _dockClasses[layoutClass]!;
          klass.pendingForgets.addAll(klass.spec?.collectModules() ?? const []);
          klass.spec = spec;
          klass.paneOptions = {...result.paneOptions};
          klass.viewOptions = result.viewOptions;
          // emit: false, like Restore Defaults — see [restoreLayoutDefaults].
          if (klass == _active) dockKey.currentState?.replaceSpec(spec, emit: false);
        }
      case LayoutImportMode.add:
        startLayoutEditing();
        if (!layoutEditing) return (skipped: const <String>[], restored: const <String>[]);
        final current = dockSpec!;
        final present = current.collectModules();
        final result = arrangements.values.first.materialize(
          isMultiple: isMultiplePanel,
          isOffered: offersPanel,
          takenIds: {..._instanceIdsInEveryDock(), ..._allPendingForgets},
          presentIds: present,
          takenContainerIds: current.collectContainerIds(),
        );
        skipped.addAll(result.skipped);
        final added = result.spec;
        if (added == null) break;
        collectSettings(result);
        // Before the draft changes, so an import that fails leaves it as it was.
        final mark = _draftMark();
        await _writeInstanceSettings(instanceWrites);
        if (!_draftUnchanged(mark)) return await _abandon(instanceWrites.keys);
        final next = _besideOnTheRight(dockSpec!, added);
        paneOptions.addAll(result.paneOptions);
        dockKey.currentState?.replaceSpec(next, emit: false);
        dockSpec = next;
    }
    if (mode != LayoutImportMode.newLayout) {
      _pendingSettingWrites.addAll(sharedWrites);
      if (mounted) _rebuild(() {});
      bumpSheet();
    }
    return (skipped: skipped, restored: restored.toList());
  }

  /// The edit as it stands: which layout's classes, and each one's draft and
  /// snapshot. Every change to a draft is a new tree, and every edit begun
  /// takes a new snapshot.
  List<Object?> _draftMark() => [
    _dockClasses,
    for (final klass in _dockClasses.values) ...[klass.spec, klass.specSnapshot],
  ];

  /// Whether the edit [mark] was taken in is still open and untouched. An
  /// import that waited on its writes in between would otherwise land in a
  /// draft the operator discarded, a layout another view moved this one to,
  /// or beside a pane added meanwhile that may hold one of its ids.
  bool _draftUnchanged(List<Object?> mark) {
    if (!mounted || !layoutEditing) return false;
    final now = _draftMark();
    return now.length == mark.length && [for (var i = 0; i < now.length; i++) identical(now[i], mark[i])].every((same) => same);
  }

  /// Gives up an import overtaken while it wrote: its instances' settings go
  /// again, and nothing is left out or restored, since nothing came in. The
  /// operator moved on, so nothing is said.
  Future<({List<String> skipped, List<String> restored})> _abandon(Iterable<String> written) async {
    await _forgetEach(written);
    return (skipped: const <String>[], restored: const <String>[]);
  }

  /// [ids] as the first tabs of [spec]'s first group.
  DockNode _withLeadingTabs(DockNode spec, List<String> ids) => switch (spec) {
    DockGroup(:final modules, :final nested) => DockGroup([...ids, ...modules], nested: Map.of(nested)),
    DockSplit(:final axis, :final children, :final weights) => DockSplit(axis, [_withLeadingTabs(children.first, ids), ...children.skip(1)], List.of(weights)),
  };

  /// [added] as a new column at the right of [current], taking an equal
  /// share of the width.
  DockNode _besideOnTheRight(DockNode current, DockNode added) {
    if (current case DockSplit(axis: Axis.horizontal, :final children, :final weights)) {
      final share = weights.fold(0.0, (a, b) => a + b) / weights.length;
      return DockSplit(Axis.horizontal, [...children, added], [...weights, share]);
    }
    return DockSplit(Axis.horizontal, [current, added], [1, 1]);
  }
}
