// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The layouts the customizable views draw, as an extension reaches them
// (docs/extensions/host.md § host.layouts). A part of dock_host.dart for the
// set of mounted hosts, which is private to that library.

part of '../dock_host.dart';

/// Reads each view's layouts from the stored list, so a view that is not
/// open still answers, and changes them through the views that are open,
/// which own what they draw.
class DockLayoutControl implements LayoutControl {
  DockLayoutControl(this.services);

  final HaLoServices services;

  static const _views = [PanelViews.operation, PanelViews.logs, PanelViews.chase, PanelViews.home];

  Iterable<DockHost> _open(String view) => DockHost._mountedHosts.where((host) => host.mounted && host.dockView == view);

  /// What [host] draws. A layout just switched to has no tree until the
  /// next build resolves it, and a call in between would find it empty.
  static List<String> _panelsOf(DockHost host) {
    host.ensureDockSpec();
    return host.dockSpec?.collectModules() ?? const [];
  }

  static String _name(ViewLayout layout) => _layoutName(layout, t.operation.layout);

  @override
  List<Map<String, dynamic>> list(String? owner) => [
    for (final view in _views)
      if ((ViewLayouts.read(services.settings, view), _open(view).toList()) case (final stored, final open))
        {
          'view': view,
          'active': open.lastOrNull?.viewLayouts.active ?? stored.active,
          'layouts': [
            for (final layout in stored.layouts)
              {'id': layout.id, 'name': _name(layout), 'description': ?layout.description, if (owner != null && layout.madeBy == owner) 'mine': true},
          ],
          'open': open.isNotEmpty,
          'editing': open.any((host) => host.layoutEditing),
          if (open.isNotEmpty) 'panels': {for (final host in open) ..._panelsOf(host)}.toList(),
        },
  ];

  @override
  ({String? reason, String? name}) switchTo(String view, String id) {
    if (!_views.contains(view)) return (reason: 'invalid', name: null);
    // Without the layouts sheet the operator would have no way back.
    if (!_namedLayoutsOffered(services.settings)) return (reason: 'unavailable', name: null);
    final stored = ViewLayouts.read(services.settings, view);
    final layout = stored[id];
    if (layout == null) return (reason: 'invalid', name: null);
    final open = _open(view).toList();
    if (open.any((host) => host.layoutEditing)) return (reason: 'editing', name: null);
    final drawn = open.isEmpty ? stored.active == id : open.every((host) => host.viewLayouts.active == id);
    if (drawn) return (reason: null, name: null);
    // A list read back from its layouts' keys has lost their names, which
    // the next view opened tells the operator once. Written back from here,
    // it would read as whole and they would never hear of it.
    if (open.isEmpty && stored.recovered) return (reason: 'unavailable', name: null);
    if (open.isEmpty) {
      unawaited(stored.copyWith(active: id).write(services.settings, view));
    } else {
      for (final host in open) {
        host.switchLayout(id);
      }
    }
    return (reason: null, name: _name(layout));
  }

  @override
  String? focus(String view, String panel) {
    if (!_views.contains(view)) return 'invalid';
    final open = _open(view).toList();
    if (open.any((host) => host.layoutEditing)) return 'editing';
    final holding = open.where((host) => _panelsOf(host).contains(panel)).toList();
    if (holding.isEmpty) return 'missing';
    for (final host in holding) {
      if (host.dockKey.currentState case final dock?) {
        dock.revealModule(panel);
      } else {
        // A layout switched to a moment ago: its dock is built on the next
        // frame, which the switch has already asked for.
        WidgetsBinding.instance.addPostFrameCallback((_) => host.dockKey.currentState?.revealModule(panel));
      }
    }
    return null;
  }

  /// The view of that kind in front, which a write goes through: the one
  /// the operator is looking at when several are stacked.
  DockHost? _front(String view) => _open(view).lastOrNull;

  /// The reason [view] cannot be written to now, or null with the view to
  /// write through.
  (String?, DockHost?) _writable(String view) {
    if (!_views.contains(view)) return ('invalid', null);
    if (!_namedLayoutsOffered(services.settings)) return ('unavailable', null);
    final front = _front(view);
    if (front == null) return ('closed', null);
    if (_open(view).any((host) => host.layoutEditing)) return ('editing', null);
    return (null, front);
  }

  @override
  Future<({String? reason, Map<String, dynamic>? document})> read(String view, String? id) async {
    if (!_views.contains(view)) return (reason: 'invalid', document: null);
    final front = _front(view);
    if (front == null) return (reason: 'closed', document: null);
    // While editing, what is on screen is a draft the operator has not kept.
    if (_open(view).any((host) => host.layoutEditing)) return (reason: 'editing', document: null);
    front.refreshLayouts();
    final layoutId = id ?? front.viewLayouts.active;
    if (front.viewLayouts[layoutId] == null) return (reason: 'invalid', document: null);
    final file = await front.buildLayoutFile(layoutId, {for (final layoutClass in DockLayoutClass.values) layoutClass: null});
    if (file == null) return (reason: 'invalid', document: null);
    return (reason: null, document: file.toJson());
  }

  @override
  Future<LayoutWrite> apply(String view, Object? document, {required String mode, String? id, String? name, String? description, required String owner}) async {
    LayoutWrite refused(String reason, {String? message}) => (reason: reason, message: message, id: null, name: null, skipped: const <String>[]);
    final importMode = switch (mode) {
      'new' => LayoutImportMode.newLayout,
      'replace' => LayoutImportMode.replace,
      'add' => LayoutImportMode.add,
      _ => null,
    };
    if (importMode == null) return refused('invalid');
    final (reason, front) = _writable(view);
    if (reason != null) return refused(reason);
    final host = front!;
    final LayoutFile file;
    try {
      file = LayoutFile.fromDocument(document);
    } on LayoutFileException catch (e) {
      return refused('invalid', message: '$e');
    }
    host.refreshLayouts();
    if (importMode == LayoutImportMode.newLayout) {
      String? made;
      final layoutName = name ?? file.name;
      final (:skipped, restored: _) = await host.importLayout(
        host.importTargets(file, importMode),
        mode: importMode,
        name: layoutName,
        description: description ?? file.description,
        madeBy: owner,
        draw: false,
        onMade: (madeId) => made = madeId,
      );
      if (made == null) return (reason: 'empty', message: null, id: null, name: null, skipped: skipped);
      return (reason: null, message: null, id: made, name: _name(host.viewLayouts[made!] ?? ViewLayout(id: made!, name: layoutName)), skipped: skipped);
    }
    final layout = id == null ? null : host.viewLayouts[id];
    if (layout == null) return refused('invalid');
    if (layout.madeBy != owner) return refused('notOwn');
    final (reason: refusal, :skipped) = await host.rewriteLayout(layout.id, file, importMode, owner: owner);
    if (refusal != null) return (reason: refusal, message: null, id: null, name: null, skipped: skipped);
    return (reason: null, message: null, id: layout.id, name: _name(layout), skipped: skipped);
  }

  @override
  Future<({String? reason, String? name})> remove(String view, String id, {required String owner}) async {
    final (reason, front) = _writable(view);
    if (reason != null) return (reason: reason, name: null);
    final host = front!..refreshLayouts();
    final layout = host.viewLayouts[id];
    // The last layout stays: a view has to draw something.
    if (layout == null || host.viewLayouts.layouts.length < 2) return (reason: 'invalid', name: null);
    if (layout.madeBy != owner) return (reason: 'notOwn', name: null);
    await host.deleteLayout(id);
    return (reason: null, name: _name(layout));
  }
}

/// A layout written for the extension that made it, straight to storage:
/// never into the operator's edit draft, which is theirs to Save or Discard.
extension ExtensionLayoutWrites<T extends StatefulWidget> on DockHost<T> {
  /// Writes [file] into the named layout [id] — [LayoutImportMode.replace]
  /// in place of what it holds, each class the file has in its own and a
  /// file of one class into the class on screen; [LayoutImportMode.add]
  /// beside what the class on screen holds, in a new column at the right —
  /// and redraws every open view of this kind drawing it. Answers the
  /// panels left out, and refuses `empty` when the file places nothing here.
  ///
  /// [owner] is checked again once the instances' settings are written: an
  /// edit the operator opened, or a layout they took over or deleted, while
  /// those were written refuses `editing`, `notOwn` or `invalid`. Written
  /// anyway, it would land under their draft, or over their work.
  ///
  /// The instances it places get ids clear of every layout's, and their
  /// settings are written first: written after, they would open empty. The
  /// instances it replaces are forgotten once nothing names them, as a
  /// delete forgets them. A panel placed once keeps the settings it shares
  /// with every layout showing it.
  Future<({String? reason, List<String> skipped})> rewriteLayout(String id, LayoutFile file, LayoutImportMode mode, {required String owner}) async {
    final skipped = <String>[];
    final taken = {..._instanceIdsInEveryDock(), ..._allPendingForgets};
    final writes = <String, Object>{};
    final instanceWrites = <String, Map<String, dynamic>>{};
    final leaving = <String>{};
    void collect(MaterializedArrangement result) {
      for (final entry in result.settings.entries) {
        if (PanelDefinition.descriptorIdOf(entry.key) != entry.key) instanceWrites[entry.key] = entry.value;
      }
    }

    if (mode == LayoutImportMode.add) {
      final current = _arrangementOf(id, dockLayoutClass)!;
      final result = importTargets(file, mode).values.first.materialize(
        isMultiple: isMultiplePanel,
        isOffered: offersPanel,
        takenIds: taken,
        presentIds: current.spec.collectModules(),
        takenContainerIds: current.spec.collectContainerIds(),
      );
      skipped.addAll(result.skipped);
      if (result.spec case final added?) {
        final keys = dockKeysFor(dockLayoutClass).forLayout(id);
        writes[keys.spec] = _besideOnTheRight(current.spec, added).toJson();
        writes[keys.paneOptions] = PaneLayoutOptions.mapToJson({...current.paneOptions, ...result.paneOptions});
        collect(result);
      }
    } else {
      for (final MapEntry(key: layoutClass, value: arrangement) in importTargets(file, mode, shown: dockLayoutClass).entries) {
        final result = arrangement.materialize(isMultiple: isMultiplePanel, isOffered: offersPanel, takenIds: taken);
        skipped.addAll(result.skipped);
        final placed = result.spec;
        if (placed == null) continue;
        final missing = [
          for (final pinned in pinnedModuleIdsIn(layoutClass))
            if (!placed.collectModules().contains(pinned)) pinned,
        ];
        final spec = missing.isEmpty ? placed : _withLeadingTabs(placed, missing);
        taken.addAll(spec.collectModules());
        leaving.addAll(_arrangementOf(id, layoutClass, fallBackToDefault: false)?.spec.collectModules() ?? const []);
        final keys = dockKeysFor(layoutClass).forLayout(id);
        writes[keys.spec] = spec.toJson();
        writes[keys.paneOptions] = PaneLayoutOptions.mapToJson(result.paneOptions);
        writes[keys.viewOptions] = result.viewOptions.toJson();
        collect(result);
      }
    }
    if (writes.isEmpty) return (reason: 'empty', skipped: skipped);
    // [_writeInstanceSettings] takes out its own on failure.
    await _writeInstanceSettings(instanceWrites);
    if (_overtaken(id, owner) case final reason?) {
      await _forgetEach(instanceWrites.keys);
      return (reason: reason, skipped: const <String>[]);
    }
    // The settings cache takes a write before it is persisted, and would
    // keep naming the instances forgotten below if it failed.
    final previous = {for (final key in writes.keys) key: dockServices.settings.layoutData(key) ?? const <String, dynamic>{}};
    try {
      await dockServices.settings.setLayoutValues(writes);
    } catch (e, stack) {
      await _undoStep(() => dockServices.settings.setLayoutValues(previous));
      await _forgetEach(instanceWrites.keys);
      Error.throwWithStackTrace(e, stack);
    }
    for (final host in DockHost._mountedHosts) {
      // One whose edit began during the write keeps its draft, which a Save
      // makes the operator's.
      if (host.mounted && host.dockView == dockView && !host.layoutEditing && host.viewLayouts.active == id) {
        host._rebuild(() => host._replaceClasses(id));
      }
    }
    final elsewhere = {..._instanceIdsInEveryDock()};
    for (final pane in leaving.difference(elsewhere)) {
      panelTitles.remove(pane);
      unawaited(_forgetInstance(pane));
    }
    if (mounted) _rebuild(() {});
    return (reason: null, skipped: skipped);
  }

  /// Why [owner] may no longer write layout [id], or null.
  String? _overtaken(String id, String owner) {
    if (DockHost._mountedHosts.any((host) => host.mounted && host.dockView == dockView && host.layoutEditing)) return 'editing';
    refreshLayouts();
    final layout = viewLayouts[id];
    if (layout == null) return 'invalid';
    return layout.madeBy == owner ? null : 'notOwn';
  }

  /// [id] as the operator's own, once they have saved an edit to it: an
  /// extension that made it can no longer replace or delete their work.
  void _takeOverLayout(String id) {
    refreshLayouts();
    final layout = viewLayouts[id];
    if (layout?.madeBy == null) return;
    unawaited(_writeLayouts(viewLayouts.copyWith(layouts: [for (final each in viewLayouts.layouts) each.id == id ? each.takenOver : each])));
  }
}
