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
  List<Map<String, dynamic>> list() => [
    for (final view in _views)
      if ((ViewLayouts.read(services.settings, view), _open(view).toList()) case (final stored, final open))
        {
          'view': view,
          'active': open.lastOrNull?.viewLayouts.active ?? stored.active,
          'layouts': [
            for (final layout in stored.layouts) {'id': layout.id, 'name': _name(layout), 'description': ?layout.description},
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
}
