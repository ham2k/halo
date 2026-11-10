// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The editor's Everyware sections (docs/design/cat.md § Green Heron
// Everyware): which of a server's devices are equipment here, and whether a
// switch moves by itself.

part of 'station_panel.dart';

extension _EverywareEditor on StationPanel {
  /// [nodes] with each Everyware server's devices right after it, in the
  /// order they were added; everything else where it was. A device whose
  /// server is gone stays where it was, rather than vanishing with it.
  List<EquipmentNode> _devicesUnderServers(List<EquipmentNode> nodes) {
    String? serverOf(EquipmentNode node) => switch (node.config[everywareServerConfigKey]) {
      final String server when _cat.typeFor(node)?.transportKey == EverywareDeviceTransport.transportKey => server,
      _ => null,
    };
    final placed = {for (final node in nodes) node.uuid};
    final under = <String, List<EquipmentNode>>{};
    for (final node in nodes) {
      if (serverOf(node) case final server? when placed.contains(server)) under.putIfAbsent(server, () => []).add(node);
    }
    final nested = {for (final devices in under.values) ...devices.map((device) => device.uuid)};
    return [
      for (final node in nodes)
        if (!nested.contains(node.uuid)) ...[node, ...?under[node.uuid]],
    ];
  }

  List<Map<String, dynamic>> _everywareElements(BuildContext context, EquipmentModel model, EquipmentNode? node) => switch (model) {
    everywareServerModel => _everywareDevices(context, node),
    everywareSwitchModel || everywareDirectionalModel when node != null => _everywareFollow(context, node),
    _ => const [],
  };

  /// A row per device the server has, its switch on the right: on makes it
  /// equipment here, off removes it. Folded into the server's list on save
  /// ([everywareDevicesFromForm]), which CatService makes into device nodes.
  ///
  /// Every device is listed, the ones nothing here can drive too, greyed:
  /// what the server live reports while it is connected, what it last
  /// reported while it is not — so a device can be switched off without
  /// connecting first. A device switched on stays listed even if the server
  /// stopped announcing it, so it can still be switched off.
  List<Map<String, dynamic>> _everywareDevices(BuildContext context, EquipmentNode? node) {
    final st = context.t.settings.station;
    final state = node == null ? null : _cat.stateFor(node.uuid);
    final live = state?.status == EquipmentStatus.connected ? state!.channels : const <EquipmentChannel>[];
    final remembered = [
      if (node?.config[everywareKnownDevicesConfigKey] case final List<Object?> list)
        for (final entry in list)
          if (entry case {'key': final String key}) (key: key, kind: entry['kind'] as String?),
    ];
    final known = live.isNotEmpty ? [for (final device in live) (key: device.key, kind: device.mode)] : remembered;
    final devices = [
      ...known,
      for (final key in _everywareTicked(node?.config ?? const {}))
        if (!known.any((device) => device.key == key)) (key: key, kind: null),
    ];
    return [
      {
        'type': 'header',
        'style': 'category',
        'title': st.everywareDevicesHeader,
        'subtitle': live.isNotEmpty
            ? st.everywareDevicesDescription
            : devices.isEmpty
            ? st.everywareDevicesDisconnected
            : st.everywareDevicesLastSeen,
      },
      for (final device in devices)
        if (parseEverywareDeviceKey(device.key) case (:final kind, :final name))
          {
            'type': 'field',
            'fieldType': 'checkbox',
            'key': everywareDeviceFormKey(device.key),
            'label': name.trim(),
            'description': _everywareKindLabel(st, kind, device.kind),
            'icon': switch (kind) {
              EverywareDeviceKind.rotor => 'compass-outline',
              // A directional switch is drawn as what it is here: a rotator.
              EverywareDeviceKind.switchBox when device.kind == EverywareSwitchKind.map.name => 'compass-outline',
              EverywareDeviceKind.switchBox => 'directions-fork',
              EverywareDeviceKind.stack => 'layers-outline',
            },
            if (everywareUnsupportedKinds.contains(device.kind) || kind == EverywareDeviceKind.stack) 'disabled': true,
          },
    ];
  }

  /// Follow the radio, for a band switch; point toward the station worked,
  /// for a map switch. Which one it is, only the server says — so a switch
  /// whose server is away shows neither, and keeps what it had.
  List<Map<String, dynamic>> _everywareFollow(BuildContext context, EquipmentNode node) {
    final st = context.t.settings.station;
    final server = node.config[everywareServerConfigKey];
    final key = everywareDeviceKey(EverywareDeviceKind.switchBox, node.config[everywareDeviceConfigKey] as String? ?? '');
    final kind = server is String ? _cat.stateFor(server).channels.where((device) => device.key == key).firstOrNull?.mode : null;
    final (label, description) = switch (kind) {
      'band' => (st.everywareFollowBand, st.everywareFollowBandDescription),
      'map' => (st.everywareFollowBearing, st.everywareFollowBearingDescription),
      _ => (null, null),
    };
    if (label == null) return const [];
    return [
      {'type': 'header', 'style': 'category', 'title': st.everywareFollowHeader},
      {'type': 'field', 'fieldType': 'checkbox', 'key': everywareFollowConfigKey, 'label': label, 'description': description},
      // Which radio a band switch follows: under SO2R each radio has its own
      // band switch, and one moved with the other radio is on the wrong band.
      if (kind == 'band')
        {
          'type': 'field',
          'fieldType': 'select',
          'key': everywareFollowRadioConfigKey,
          'label': st.everywareFollowRadio,
          'visibleWhen': [
            {'field': everywareFollowConfigKey, 'equals': true},
          ],
          'options': [
            {'value': everywareFollowRadioA, 'label': st.everywareFollowRadioA},
            {'value': everywareFollowRadioB, 'label': st.everywareFollowRadioB},
          ],
        },
    ];
  }
}

String _everywareKindLabel(Translations$settings$station$en st, EverywareDeviceKind kind, String? switchKind) => switch ((kind, switchKind)) {
  (EverywareDeviceKind.rotor, _) => st.everywareKindRotor,
  (EverywareDeviceKind.stack, _) => st.everywareKindStack,
  (_, 'map') => st.everywareKindMap,
  (_, 'band') => st.everywareKindBand,
  (_, 'bank') => st.everywareKindBank,
  _ => st.everywareKindSwitch,
};

List<String> _everywareTicked(Map<String, dynamic> config) => [
  if (config[everywareDevicesConfigKey] case final List<Object?> list) ...list.whereType<String>(),
];

/// The form key of [device]'s switch in its server's editor.
String everywareDeviceFormKey(String device) => 'everywareDevice/$device';

bool isEverywareDeviceFormKey(String key) => key.startsWith('everywareDevice/');

/// The switches' opening positions: on for each device the server's
/// [config] has ticked.
Map<String, dynamic> everywareDeviceToggles(Map<String, dynamic> config) => {
  for (final device in _everywareTicked(config)) everywareDeviceFormKey(device): true,
};

/// The server's ticked list from a saved form's switches; nothing for a
/// form that had none, which leaves the stored list as it was.
Map<String, dynamic> everywareDevicesFromForm(Map<String, dynamic> result) {
  if (!result.keys.any(isEverywareDeviceFormKey)) return const {};
  return {
    everywareDevicesConfigKey: [
      for (final entry in result.entries)
        if (isEverywareDeviceFormKey(entry.key) && entry.value == true) entry.key.substring('everywareDevice/'.length),
    ],
  };
}
