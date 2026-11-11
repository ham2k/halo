// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// System lists: named option vocabularies for settings declarations. A
// field whose `options` is a `$`-prefixed name (e.g. `"$core.bands"`)
// gets it resolved here — app-side, before the definition reaches
// FormRenderer — so declarations don't copy vocabularies that something
// else owns (halo_core's band table, the extension runtime's contributed
// controls). Both core settings groups and extension settingsPanels can
// reference them. Documented in docs/extensions/settings.md.
//
// Naming: `$<namespace>.<list>` — `$core.*` for app/halo_core-owned
// vocabularies; `$extensions.*` reserved for runtime-derived ones (e.g. a
// future `$extensions.secondaryLoggingControls` for the logging panel's
// contributed control chips).

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart' as halo_core;

class SystemLists {
  /// The station's equipment of one kind (`radio`, `rotator`, `antennaSwitch`), each `{label,
  /// value}` with its id as the value; null on a host with no station behind it, where the lists
  /// are empty.
  List<Map<String, dynamic>> Function(String kind)? equipment;

  /// Resolves a `$name` to its options (`[{label, value, common?}]`), or
  /// null for an unknown name. Async because `$extensions.*` lists will
  /// need runtime round-trips.
  Future<List<Map<String, dynamic>>?> resolve(String name) async {
    switch (name) {
      // Vocabularies snapshot @ham2k/lib-operation-data (see halo_core's
      // radio.dart): the full extended set, with the lib's popular/main
      // tier flagged common.
      case r'$core.bands':
        final common = halo_core.popularBands.toSet();
        return [
          for (final band in halo_core.extendedBands) {'label': band, 'value': band, if (common.contains(band)) 'common': true},
        ];
      // Modes tier three ways, like app-polo: MAIN_MODES upfront,
      // POPULAR_MODES behind "Show more", the rest of the ADIF list
      // (uncommon) behind "Show all".
      case r'$core.modes':
        final common = halo_core.mainModes.toSet();
        final popular = halo_core.popularModes.toSet();
        return [
          for (final mode in halo_core.adifModes)
            {'label': mode, 'value': mode, if (common.contains(mode)) 'common': true, if (!common.contains(mode) && !popular.contains(mode)) 'uncommon': true},
        ];
      // The station's own, by id: what a placement's form picks a radio, rotator or switch by.
      case r'$core.radios':
        return equipment?.call('radio') ?? const [];
      case r'$core.rotators':
        return equipment?.call('rotator') ?? const [];
      case r'$core.antennaSwitches':
        return equipment?.call('antennaSwitch') ?? const [];
      default:
        return null;
    }
  }

  /// Returns [elements] with every `options: "$name"` replaced by the
  /// resolved list (recursing into `itemFields` and a row's `elements`). Unknown names resolve to
  /// no options — logged, and the field renders disabled rather than
  /// crashing the whole panel.
  Future<List<Map<String, dynamic>>> resolveInElements(List<Map<String, dynamic>> elements) async {
    final resolved = <Map<String, dynamic>>[];
    for (final el in elements) {
      var out = el;
      final options = el['options'];
      if (options is String && options.startsWith(r'$')) {
        final list = await resolve(options);
        if (list == null) debugPrint('[settings] unknown system list "$options" for field "${el['key']}"');
        // `none`: a way back to no choice, which a list of the station's own things does not offer.
        final none = el['none'];
        out = {
          ...el,
          'options': [
            if (none is String && none.isNotEmpty) {'label': none, 'value': ''},
            ...?list,
          ],
        };
      }
      final itemFields = out['itemFields'];
      if (itemFields is List) {
        out = {...out, 'itemFields': await resolveInElements(itemFields.cast<Map<String, dynamic>>())};
      }
      final members = out['elements'];
      if (out['type'] == 'row' && members is List) {
        out = {...out, 'elements': await resolveInElements(members.cast<Map<String, dynamic>>())};
      }
      resolved.add(out);
    }
    return resolved;
  }
}
