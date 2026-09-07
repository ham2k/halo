// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Choosing which of the peers' shared screens a Remote Screen pane shows
// (HALO-369).
//
// A dialog rather than a `select` field in the panel's form, and that is not
// a style choice. `PanelDefinition.operator ==` compares `formFields.length`
// and not their contents, and `registerNative` short-circuits on equality
// from `didChangeDependencies` — so a select whose options were rebuilt from
// the live catalog would re-register as "identical", no-op, and show a
// permanently stale list. An action returning `FormActionResult.fieldUpdates`
// reads the catalog at the moment the operator opens it, every time.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../../i18n/strings.g.dart';
import '../../../services/halo_services.dart';
import '../../../services/peer/peer_screen_views.dart';
import '../../screen_source_tile.dart';
import 'remote_screen_panel.dart';

/// Returns the chosen target, or null if the operator dismissed the dialog.
Future<PeerScreenTarget?> showRemoteScreenPicker(
  BuildContext context, {
  required PeerScreenViews views,
}) {
  return showHaloDialog<PeerScreenTarget>(
    context: context,
    builder: (dialogContext) => _RemoteScreenPicker(views: views),
  );
}

class _RemoteScreenPicker extends StatefulWidget {
  final PeerScreenViews views;

  const _RemoteScreenPicker({required this.views});

  @override
  State<_RemoteScreenPicker> createState() => _RemoteScreenPickerState();
}

class _RemoteScreenPickerState extends State<_RemoteScreenPicker> {
  @override
  void initState() {
    super.initState();
    widget.views.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.views.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.operation.layout.panels;
    final catalog = widget.views.catalog;

    return HaloDialog(
      // The house width for a dialog carrying real content — a grid of
      // pictures needs the room a prompt does not.
      wide: true,
      // Zero, so the grid reaches both edges of the card and insets its own
      // contents instead, the rule a settings-shaped dialog follows.
      contentPadding: EdgeInsets.zero,
      title: Text(t.remoteScreenPickerTitle),
      content: catalog.isEmpty
          // Not an error: no device is sharing anything, which is the resting
          // state. It says where to go, rather than leaving the operator to
          // guess that the switch lives on the OTHER device.
          ? Padding(
              padding: const EdgeInsets.all(Space.xl),
              child: Text(t.remoteScreenPickerEmpty),
            )
          : SizedBox(
              width: double.infinity,
              height: 420,
              child: GridView.builder(
                padding: const EdgeInsets.all(Space.md),
                // A count, not a maximum tile width: the dialog is held to
                // one width, so a max-extent delegate lands on a different
                // column count depending on how the rounding falls.
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 4 / 3.6,
                  crossAxisSpacing: Space.md,
                  mainAxisSpacing: Space.md,
                ),
                itemCount: catalog.length,
                itemBuilder: (context, index) {
                  final (peerDeviceId, peerName, source) = catalog[index];
                  // Asked for as the tile is BUILT, so only what the operator
                  // scrolled to costs a capture on the far device.
                  widget.views.requestThumbnail(peerDeviceId, source.id);
                  return ScreenSourceTile(
                    source: source,
                    subtitle: peerName,
                    thumbnail: widget.views.thumbnailFor(peerDeviceId, source.id),
                    selected: false,
                    onTap: () => Navigator.of(context).pop(
                      PeerScreenTarget(peerDeviceId, source.id),
                    ),
                  );
                },
              ),
            ),
      cancel: TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.t.common.cancel),
      ),
    );
  }
}
/// Opens the picker and stores the answer against [panelId]'s config.
///
/// The pane calls this itself as well as the panel's settings dialog doing
/// so, because the dialog is not always reachable: the pane layout options'
/// embedded form strips every `type: 'action'` element before rendering
/// (`DockHost`), so on a layout where that is the route an operator takes,
/// the only thing left of this panel's settings is the raw target string.
/// A pane that can be pointed somewhere by tapping it needs no route at all.
Future<void> chooseRemoteScreenFor(
  BuildContext context, {
  required HaLoServices services,
  required String panelId,
}) async {
  final chosen = await showRemoteScreenPicker(context, views: services.peerScreenViews);
  if (chosen == null) return;
  final panel = services.panels[panelId];
  if (panel == null) return;
  final encoded = chosen.encode();
  // The same path the settings dialog commits through, so a source picked
  // here and one picked there land in the same place under the same id.
  await services.extensions.commitSettingsFieldValue(
    kind: 'simple',
    hookKey: panel.hookKey ?? panel.id,
    panelKey: panel.id,
    fieldKey: remoteScreenTargetKey,
    value: encoded,
    state: {remoteScreenTargetKey: encoded},
    isSecret: false,
  );
  // Nothing else tells the pane its own config moved.
  services.panels.markConfigChanged(panel.id);
}

/// The Remote Screen panel's settings, as the pane layout options dialog
/// embeds them.
///
/// One row that opens the same picker the pane's own empty state does. The
/// generic `formFields` embed cannot: it strips `type: 'action'` elements,
/// which would leave this panel's settings as the stored target STRING —
/// `local/app:com.apple.notificationcenterui` — and no way to change it.
class RemoteScreenSettingsRow extends StatefulWidget {
  final String panelId;
  final HaLoServices services;

  const RemoteScreenSettingsRow({super.key, required this.panelId, required this.services});

  @override
  State<RemoteScreenSettingsRow> createState() => _RemoteScreenSettingsRowState();
}

class _RemoteScreenSettingsRowState extends State<RemoteScreenSettingsRow> {
  Map<String, dynamic> _config = const {};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final panel = widget.services.panels[widget.panelId];
    if (panel == null) return;
    final config = await widget.services.panels.configFor(panel);
    if (mounted) setState(() => _config = config);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.operation.layout.panels;
    final target = PeerScreenTarget.decode(_config[remoteScreenTargetKey] as String?);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _screenRow(context, t, target),
        ListTile(
          leading: Icon(MdiIcons.crop),
          title: Text(t.remoteScreenAdjust),
          trailing: Icon(MdiIcons.chevronRight),
          // Closes on the way out: the mode it turns on lives in the PANE,
          // and leaving a dialog open over the picture being framed would
          // hide the thing being adjusted.
          onTap: () {
            widget.services.peerScreenViews.requestAdjust(widget.panelId);
            Navigator.of(context).maybePop();
          },
        ),
        ListTile(
          leading: Icon(MdiIcons.imageSizeSelectLarge),
          title: Text(t.remoteScreenDetail),
        ),
        Padding(
          // The list's own inset, read from the ambient theme rather than
          // named again: a surface whose rows are shifted — a pane behind a
          // resize strip — moves them all, and a hard-coded number would
          // leave this one behind in the gutter.
          padding: EdgeInsets.only(
            left: _rowInset(context).left,
            right: _rowInset(context).right,
            bottom: Space.sm,
          ),
          child: SegmentedButton<int>(
            // MDI-only UI: skip the framework's Material check on the
            // selected segment (same as settings_view).
            showSelectedIcon: false,
            segments: [
              for (final width in remoteScreenDetailChoices)
                ButtonSegment(value: width, label: Text(_detailLabel(context, width))),
            ],
            selected: {_detailChoice(_config[remoteScreenDetailKey])},
            onSelectionChanged: (selection) => unawaited(_setDetail(selection.first)),
          ),
        ),
      ],
    );
  }

  Future<void> _setDetail(int width) async {
    // Optimistic, because the commit below is a settings write and a catalog
    // notification: waiting on both leaves the segment the operator tapped
    // unlit for as long as they take.
    setState(() => _config = {..._config, remoteScreenDetailKey: width});
    await saveRemoteScreenDetail(
      services: widget.services, panelId: widget.panelId, detail: width);
  }

  /// Where a row in this list starts and ends — the ambient `ListTileTheme`
  /// inset, which is what every `ListTile` here is already using.
  static EdgeInsets _rowInset(BuildContext context) =>
      ListTileTheme.of(context).contentPadding?.resolve(Directionality.of(context)) ??
      const EdgeInsets.symmetric(horizontal: settingsRowInset);

  /// The stored width as one of the offered choices — a value from a build
  /// with different steps still has to light up a segment rather than none.
  static int _detailChoice(Object? stored) {
    final width = (stored as num?)?.toInt() ?? remoteScreenDetailDefault;
    var closest = remoteScreenDetailChoices.first;
    for (final choice in remoteScreenDetailChoices) {
      if ((choice - width).abs() < (closest - width).abs()) closest = choice;
    }
    return closest;
  }

  /// Named rather than numbered: "1920 px" is a claim about a picture the
  /// operator never sees at that size — what they are choosing is how much
  /// of the link this pane may spend.
  String _detailLabel(BuildContext context, int width) {
    final t = context.t.operation.layout.panels;
    return switch (width) {
      <= 1280 => t.remoteScreenDetailStandard,
      <= 1920 => t.remoteScreenDetailHigh,
      _ => t.remoteScreenDetailMaximum,
    };
  }

  Widget _screenRow(BuildContext context, dynamic t, PeerScreenTarget? target) {
    return ListTile(
      title: Text(t.remoteScreenTarget),
      // The source's own name where it can still be resolved, and the stored
      // id only where it cannot — an id is what the operator sees when the
      // device offering it has gone, which is worth telling them apart from
      // a pane that was never pointed anywhere.
      subtitle: Text(_label(context, target) ?? t.remoteScreenUnset),
      trailing: Icon(MdiIcons.chevronRight),
      onTap: () async {
        await chooseRemoteScreenFor(context, services: widget.services, panelId: widget.panelId);
        await _load();
      },
    );
  }

  String? _label(BuildContext context, PeerScreenTarget? target) {
    if (target == null) return null;
    for (final (peerDeviceId, peerName, source) in widget.services.peerScreenViews.catalog) {
      if (peerDeviceId == target.peerDeviceId && source.id == target.sourceId) {
        return '$peerName — ${source.name}';
      }
    }
    return target.sourceId;
  }
}

/// Stores the framing the operator settled on in Adjust View.
///
/// Written on the way out of that mode rather than on every wheel notch:
/// each of these is a settings commit plus a catalog notification, and the
/// pane redraws from its own state while adjusting either way.
Future<void> saveRemoteScreenView({
  required HaLoServices services,
  required String panelId,
  required double zoom,
  required Offset pan,
}) async {
  final panel = services.panels[panelId];
  if (panel == null) return;
  final values = <String, dynamic>{
    remoteScreenZoomKey: zoom,
    remoteScreenPanXKey: pan.dx,
    remoteScreenPanYKey: pan.dy,
  };
  for (final entry in values.entries) {
    await services.extensions.commitSettingsFieldValue(
      kind: 'simple',
      hookKey: panel.hookKey ?? panel.id,
      panelKey: panel.id,
      fieldKey: entry.key,
      value: entry.value,
      state: values,
      isSecret: false,
    );
  }
  // Deliberately NOT markConfigChanged: the pane already holds this framing
  // and reloading its config would only hand back what it just sent, one
  // rebuild later.
}

/// Stores how much a pane may spend on its picture.
///
/// Unlike the framing, this DOES notify: the setting is changed from a
/// dialog and the pane is what has to act on it — it clamps its own demand
/// by this number, and nothing else would tell it the number moved.
Future<void> saveRemoteScreenDetail({
  required HaLoServices services,
  required String panelId,
  required int detail,
}) async {
  final panel = services.panels[panelId];
  if (panel == null) return;
  await services.extensions.commitSettingsFieldValue(
    kind: 'simple',
    hookKey: panel.hookKey ?? panel.id,
    panelKey: panel.id,
    fieldKey: remoteScreenDetailKey,
    value: detail,
    state: {remoteScreenDetailKey: detail},
    isSecret: false,
  );
  services.panels.markConfigChanged(panel.id);
}
