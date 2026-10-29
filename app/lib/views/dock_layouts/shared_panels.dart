// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The native panels every view that hosts a dock offers — their catalog
// entries, their widgets and their own settings (docs/design/layouts.md).
// A part of dock_host.dart, like add_panel_sheet.dart, so each view reaches
// them as members of the host it mixes in.
//
// These are extension members, so a view cannot override them: one it
// declares under the same name shadows it only for the view's own calls,
// while every call from the host still reaches the one here. A view's own
// panes answer for their settings through [DockHost.nativePanelSettingsForm].

part of '../dock_host.dart';

extension SharedDashboardPanels<T extends StatefulWidget> on DockHost<T> {
  /// A purpose-built settings widget for [id], from the VIEW's own panes
  /// ([nativePanelSettingsForm]) or from the shared dashboard set, or null to
  /// fall through to the generic `formFields` embed.
  ///
  /// The shared arm exists because that embed strips every `type: 'action'`
  /// element — an action there has no route of its own to close on — and a
  /// panel whose only real control IS an action would show nothing but its
  /// stored value. Registered centrally rather than in each view's switch,
  /// the same reason [registerSharedDashboardPanels] is.
  WidgetBuilder? _panelSettingsOverride(BuildContext context, String id) => nativePanelSettingsForm(context, id) ?? sharedDashboardPanelSettings(context, id);

  /// The shared dashboard panels that answer for their own settings. Only
  /// Remote Screen does: its source is picked from a live catalog of what
  /// other devices offer, which is a dialog rather than a form field.
  WidgetBuilder? sharedDashboardPanelSettings(BuildContext context, String id) {
    if (PanelDefinition.descriptorIdOf(id) != remoteScreenPanelId) return null;
    return (builderContext) => SingleChildScrollView(
      child: RemoteScreenSettingsRow(panelId: id, services: dockServices),
    );
  }

  /// Clock, Weather, Solar, Web Site, Radio, Rotator and Remote Screen: the
  /// native panels every view offers (docs/design/layouts.md), built here once
  /// so a change to one of them doesn't have to reach every view that hosts a
  /// dock. See [registerSharedDashboardPanels] for their catalog entry — this
  /// only builds the widget for whatever placement [inLayout] holds.
  ///
  /// [operationGrid], [operationLocation], [isEnteringQso] and [callInfo]
  /// are what only an operation has: null outside one, which leaves Weather
  /// to its own configured location, Web Site to reload strictly on
  /// schedule, and Rotator with no centre but its own and no station to
  /// mark. Rotator takes the operation's [operationLocation] rather than its
  /// grid: it measures headings from it (docs/design/locations.md).
  Map<String, Widget> sharedDashboardPanes(
    List<String> inLayout, {
    String? operationGrid,
    GridLocation? operationLocation,
    bool Function()? isEnteringQso,
    CallInfoData? callInfo,
  }) => {
    for (final id in inLayout)
      if (PanelDefinition.descriptorIdOf(id) == clockPanelId)
        id: ClockPanel(key: ValueKey('panel-$id'), panelId: id, panels: dockServices.panels, onTitle: (title) => onPanelTitle(id, title))
      else if (PanelDefinition.descriptorIdOf(id) == weatherPanelId)
        id: WeatherPanel(
          key: ValueKey('panel-$id'),
          panelId: id,
          panels: dockServices.panels,
          settings: dockServices.settings,
          operationGrid: operationGrid,
          onTitle: (title) => onPanelTitle(id, title),
        )
      else if (PanelDefinition.descriptorIdOf(id) == solarPanelId)
        // No config and no title of its own: solar conditions are the same
        // everywhere, so there is nothing for a placement to say about
        // itself that the tab's own name does not.
        id: SolarPanel(key: ValueKey('panel-$id'))
      else if (PanelDefinition.descriptorIdOf(id) == websitePanelId)
        id: WebsitePanel(
          key: ValueKey('panel-$id'),
          panelId: id,
          panels: dockServices.panels,
          onTitle: (title) => onPanelTitle(id, title),
          isEnteringQso: isEnteringQso,
        )
      else if (PanelDefinition.descriptorIdOf(id) == radioPanelId)
        id: RadioPanel(key: ValueKey('panel-$id'), panelId: id, services: dockServices, onTitle: (title) => onPanelTitle(id, title))
      else if (PanelDefinition.descriptorIdOf(id) == rotatorPanelId)
        id: RotatorPanel(
          key: ValueKey('panel-$id'),
          panelId: id,
          services: dockServices,
          operationLocation: operationLocation,
          dx: _callInfoLocation(callInfo),
          onTitle: (title) => onPanelTitle(id, title),
        )
      else if (PanelDefinition.descriptorIdOf(id) == remoteScreenPanelId)
        id: Builder(
          builder: (paneContext) => RemoteScreenPanel(
            key: ValueKey('panel-$id'),
            panelId: id,
            panels: dockServices.panels,
            views: dockServices.peerScreenViews,
            onTitle: (title) => onPanelTitle(id, title),
            // The pane offers the picker itself. The panel's settings dialog
            // also does, but it is not always reachable — the pane layout
            // options' embedded form strips `type: 'action'` elements, which
            // leaves this panel's settings as a bare target string.
            onChooseSource: () => unawaited(chooseRemoteScreenFor(paneContext, services: dockServices, panelId: id)),
            onSaveView: (zoom, pan) => unawaited(saveRemoteScreenView(services: dockServices, panelId: id, zoom: zoom, pan: pan)),
          ),
        ),
  };

  /// Clock, Weather, Solar, Web Site, Radio, Rotator and Remote Screen's
  /// catalog entries — see [sharedDashboardPanes] for the widgets. Every view
  /// that hosts a dock calls this from its own `_registerNativePanels`:
  /// [PanelService.registerNative] no-ops on an identical re-registration, so
  /// whichever view mounts first wins and every other view's call costs
  /// nothing. A single owner (Home, say, since it's the one view mounted for
  /// the app's whole lifetime) would leave these missing from Operation's or
  /// the Logs view's own catalog whenever either is exercised on its own — as
  /// every one of their widget tests does.
  void registerSharedDashboardPanels() {
    final t = context.t.operation;
    final service = dockServices.panels;
    const sharedViews = {PanelViews.home, PanelViews.operation, PanelViews.logs, PanelViews.chase};
    service.registerNative(
      PanelDefinition(
        id: clockPanelId,
        title: t.tabs.clock,
        description: t.layout.panels.clockDescription,
        icon: 'clock-outline',
        source: PanelSource.native,
        views: sharedViews,
        // The one native pane an operator plausibly wants several of: a UTC
        // clock beside the DX's local time is the whole point of it.
        multiple: true,
        formFields: [
          {
            'type': 'field',
            'key': clockFaceKey,
            'fieldType': 'select',
            'label': t.layout.panels.clockFace,
            'value': clockFaceLcd,
            'options': [
              {'label': t.layout.panels.clockFaceLcd, 'value': clockFaceLcd},
              {'label': t.layout.panels.clockFaceAnalog, 'value': clockFaceAnalog},
            ],
          },
          {
            'type': 'field',
            'key': clockZoneKey,
            'fieldType': 'select',
            // `icon` is what puts this behind a full-list dialog rather than an
            // inline dropdown — 341 zones in a ten-row popup is not a picker.
            // The dialog searches past twenty options.
            'icon': 'earth',
            'label': t.layout.panels.clockZone,
            'value': utcZoneId,
            'options': clockZoneOptions(utcLabel: t.layout.panels.clockZoneUtc, deviceLabel: t.layout.panels.clockZoneDevice),
          },
          {'type': 'field', 'key': clockShowSecondsKey, 'fieldType': 'checkbox', 'label': t.layout.panels.clockShowSeconds, 'value': true},
        ],
      ),
    );
    service.registerNative(
      PanelDefinition(
        id: weatherPanelId,
        title: t.tabs.weather,
        description: t.layout.panels.weatherDescription,
        icon: 'weather-partly-cloudy',
        source: PanelSource.native,
        views: sharedViews,
        // Instanceable so a placement in Home, in an operation and in the Logs
        // view are three independent locations rather than one shared config
        // — the same reason Clock is (see its own comment below). Unlike
        // Clock, an operator plausibly wants only one at a time; `multiple`
        // exists for the cross-view case, not to invite several in one dock.
        multiple: true,
        formFields: [
          {
            'type': 'field',
            'key': weatherUseOperationLocationKey,
            'fieldType': 'checkbox',
            'label': t.layout.panels.weatherUseOperationLocation,
            'value': true,
          },
          {
            'type': 'field',
            'key': weatherLocationKey,
            'fieldType': 'text',
            'label': t.layout.panels.weatherLocation,
            'description': t.layout.panels.weatherLocationDescription,
            'value': '',
            // Deliberately never hidden by `visibleWhen`, even though it's
            // read only while [weatherUseOperationLocationKey] is off — a
            // config predating that checkbox never wrote it, so an existing
            // override's checkbox state is INFERRED (`_useOperationLocation`)
            // rather than read back, and can disagree with what the form
            // shows. A hidden field would put the one control that explains
            // — or fixes — that disagreement out of reach.
          },
        ],
      ),
    );
    service.registerNative(
      PanelDefinition(
        id: solarPanelId,
        title: t.tabs.solar,
        description: t.layout.panels.solarDescription,
        icon: 'white-balance-sunny',
        source: PanelSource.native,
        views: sharedViews,
        // Instanceable for the cross-view case only, like Weather: a placement
        // in Home and one in an operation are independent locations. Two in one
        // dock would be the same numbers twice — there is nothing to configure
        // that would make them differ.
        multiple: true,
        // Nothing to configure. The pane's own size decides what it shows.
        formFields: [],
      ),
    );
    service.registerNative(
      PanelDefinition(
        id: websitePanelId,
        title: t.tabs.website,
        description: t.layout.panels.websiteDescription,
        icon: 'web',
        source: PanelSource.native,
        views: sharedViews,
        multiple: true,
        formFields: [
          {
            'type': 'field',
            'key': websiteUrlKey,
            // No `url` fieldType exists, and an unknown one renders as nothing
            // at all — no field, no error, no log.
            'fieldType': 'text',
            'label': t.layout.panels.websiteUrl,
            'placeholder': 'https://…',
            'value': '',
          },
          {
            'type': 'field',
            'key': websiteRefreshKey,
            'fieldType': 'select',
            'label': t.layout.panels.websiteRefresh,
            // `0`, not null: a null-valued select cannot tell "dismissed" from
            // "picked null". Ints survive the config's JSON round-trip as ints,
            // which is what the dropdown's `value ==` needs.
            'value': 0,
            'options': [
              {'label': t.layout.panels.websiteRefreshNever, 'value': 0},
              {'label': t.layout.panels.websiteRefresh1, 'value': 1},
              {'label': t.layout.panels.websiteRefresh5, 'value': 5},
              {'label': t.layout.panels.websiteRefresh15, 'value': 15},
            ],
          },
          {'type': 'field', 'key': websiteTitleKey, 'fieldType': 'text', 'label': t.layout.panels.websiteTitle, 'value': ''},
          // Live only because `showPanelSettings` passes `onAction`; without
          // that this button renders disabled.
          {'type': 'action', 'key': 'refreshNow', 'label': t.layout.panels.websiteRefreshNow, 'method': panelRefreshMethod},
        ],
      ),
    );
    // Re-registered whenever CatService notifies — see [_onEquipmentChanged],
    // which is what keeps the radio picker's options and the Automatic
    // option's name current.
    final cat = dockServices.cat;
    final designated = switch (cat.radio1) {
      LocalRadio(:final uuid) => cat.nodeFor(uuid),
      _ => null,
    };
    service.registerNative(
      PanelDefinition(
        id: radioPanelId,
        title: t.tabs.radio,
        description: t.layout.panels.radioDescription,
        icon: 'radio',
        source: PanelSource.native,
        views: sharedViews,
        // A two-radio shack wants both front panels side by side, which is
        // the case this exists for — and, as with Clock and Weather, a
        // placement in Home and one in an operation are independent
        // locations rather than one shared config.
        multiple: true,
        // Frequency, mode and power on a row that has to stay legible: the
        // seven-segment readout scales down with the pane, but below this
        // the digits stop being readable across a room, which is the only
        // reason to have a rig's display on screen at all.
        minWidth: 3,
        minHeight: 2,
        formFields: [
          {
            'type': 'field',
            'key': radioNodeKey,
            'fieldType': 'select',
            'label': t.layout.panels.radioRadio,
            'value': radioNodeAuto,
            'options': [
              {
                // The label carries the designated radio's NAME, so the
                // settings row reads "Radio: VFO A — Left Radio" and the
                // operator can see which rig Automatic currently means
                // without opening Station Configuration to find out.
                'label': designated == null ? t.layout.panels.radioAutoNone : t.layout.panels.radioAutoNamed(name: cat.displayNameFor(designated)),
                'value': radioNodeAuto,
              },
              for (final node in cat.nodes)
                if (cat.typeFor(node)?.category == kCategoryTransceiver) {'label': cat.displayNameFor(node), 'value': node.uuid},
            ],
          },
          {
            'type': 'field',
            'key': radioStyleKey,
            'fieldType': 'select',
            'label': t.layout.panels.radioStyle,
            'value': radioStyleLcd,
            'options': [
              {'label': t.layout.panels.radioStyleLcd, 'value': radioStyleLcd},
              {'label': t.layout.panels.radioStyleModern, 'value': radioStyleModern},
            ],
          },
        ],
      ),
    );
    // Behind the rotator experiment, with the equipment it shows — the
    // remote screen's registration below says what a saved arrangement
    // holding one gets with the experiment off.
    if (dockServices.settings.experimentEnabled('rotator') /* stored key, see experiments.yaml */ ) {
      final rotators = [
        for (final node in cat.nodes)
          if (cat.typeFor(node)?.category == kCategoryRotator) node,
      ];
      service.registerNative(
        PanelDefinition(
          id: rotatorPanelId,
          title: t.tabs.rotator,
          description: t.layout.panels.rotatorDescription,
          icon: 'compass-outline',
          source: PanelSource.native,
          views: sharedViews,
          // One per rotator, and independent placements across views, as
          // Radio.
          multiple: true,
          minWidth: 2,
          minHeight: 2,
          formFields: [
            {
              'type': 'field',
              'key': rotatorNodeKey,
              'fieldType': 'select',
              'label': t.layout.panels.rotatorRotator,
              'value': rotatorNodeAuto,
              'options': [
                {
                  'label': rotators.isEmpty ? t.layout.panels.rotatorAutoNone : t.layout.panels.rotatorAutoNamed(name: cat.displayNameFor(rotators.first)),
                  'value': rotatorNodeAuto,
                },
                for (final node in rotators) {'label': cat.displayNameFor(node), 'value': node.uuid},
              ],
            },
            {
              'type': 'field',
              'key': rotatorBeamWidthKey,
              'fieldType': 'number',
              'label': t.layout.panels.rotatorBeamWidth,
              'description': t.layout.panels.rotatorBeamWidthDescription,
              'value': rotatorBeamWidthDefault,
            },
            {
              'type': 'field',
              'key': rotatorLocationKey,
              'fieldType': 'text',
              'label': t.layout.panels.rotatorLocation,
              'description': t.layout.panels.rotatorLocationDescription,
              'value': '',
            },
            {
              'type': 'field',
              'key': rotatorThemeKey,
              'fieldType': 'select',
              'label': t.layout.panels.rotatorTheme,
              'value': rotatorThemeColor,
              'options': [
                {'label': t.layout.panels.rotatorThemeColor, 'value': rotatorThemeColor},
                {'label': t.layout.panels.rotatorThemeGray, 'value': rotatorThemeGray},
                {'label': t.layout.panels.rotatorThemeMuted, 'value': rotatorThemeMuted},
              ],
            },
            {'type': 'field', 'key': rotatorGraylineKey, 'fieldType': 'checkbox', 'label': t.layout.panels.rotatorGrayline, 'value': true},
          ],
        ),
      );
    }
    // Registered only with the experiment on. A saved arrangement holding one
    // of these then falls to the missing-panel placeholder rather than
    // vanishing, which is the same deal an uninstalled extension's panel
    // gets — the operator keeps their arrangement and is told.
    if (dockServices.settings.experimentEnabled('remote') /* stored key, see experiments.yaml */ ) {
      service.registerNative(
        PanelDefinition(
          id: remoteScreenPanelId,
          title: t.tabs.remoteScreen,
          description: t.layout.panels.remoteScreenDescription,
          icon: 'monitor-share',
          source: PanelSource.native,
          views: sharedViews,
          multiple: true,
          // A screen is unreadable in a three-unit pane, and unlike a clock
          // there is no smaller rendering to fall back to.
          minWidth: 3,
          minHeight: 4,
          formFields: [
            // An ACTION, never a select. The options would have to be the live
            // catalog of what peers offer, which arrives asynchronously and
            // turns over as devices come and go — nothing re-registers this
            // descriptor when it does, so a select would show whatever was on
            // offer the moment the view mounted.
            {'type': 'action', 'key': 'chooseScreen', 'label': t.layout.panels.remoteScreenChoose, 'method': remoteScreenChooseMethod},
            // What the action writes, shown so the operator can see what is
            // stored and clear it without a second control.
            {'type': 'field', 'key': remoteScreenTargetKey, 'fieldType': 'text', 'label': t.layout.panels.remoteScreenTarget, 'value': ''},
            // How the operator framed the picture. Declared, though no form
            // ever renders them: `forgetInstanceConfig` forgets only DECLARED
            // fields, so an undeclared zoom would outlive the pane that set it
            // and be inherited by whatever is placed in that slot next. Both
            // routes to this panel's settings are its own widget, so these are
            // never shown.
            {'type': 'field', 'key': remoteScreenZoomKey, 'fieldType': 'number', 'label': '', 'value': 1.0},
            {'type': 'field', 'key': remoteScreenPanXKey, 'fieldType': 'number', 'label': '', 'value': 0.0},
            {'type': 'field', 'key': remoteScreenPanYKey, 'fieldType': 'number', 'label': '', 'value': 0.0},
            // Declared for the same reason, and rendered by the same widget:
            // how much of the link this pane may spend on its picture.
            {'type': 'field', 'key': remoteScreenDetailKey, 'fieldType': 'number', 'label': '', 'value': remoteScreenDetailDefault},
          ],
        ),
      );
    }
  }
}

/// Where the station in the call field is, as well as its lookup can say.
GridLocation? _callInfoLocation(CallInfoData? info) => switch (info?.guess) {
  final guess? => locationForQsoInfo(
    exact: locationFromGuess(guess),
    grid: asQsonString(guess['grid']),
    entityPrefix: asQsonString(guess['entityPrefix']),
    state: asQsonString(guess['state']),
  ),
  null => null,
};
