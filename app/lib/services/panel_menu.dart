// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A placement's own menu, from its last render (`PanelContent.form` and `menu`, extension API 23):
// what the tab's settings button offers for that one pane.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

/// One entry of a pane's menu: [event] sends a panel event with that action; [settings] opens the
/// descriptor's own form.
typedef PanelMenuEntry = ({String label, String? event, bool settings});

/// A placement's own settings form: shown under [title], its values one object in config [key].
typedef PanelPlacementForm = ({String key, String title, List<Map<String, dynamic>> elements});

/// A menu's event, waiting for its pane to send it; [done] says how that went.
typedef QueuedPanelEvent = ({Map<String, dynamic> event, Completer<void> done});

class PanelPlacementMenu {
  final PanelPlacementForm? form;
  final List<PanelMenuEntry> entries;

  const PanelPlacementMenu({this.form, this.entries = const []});

  /// At most this many entries, and this long a label: a menu, not a list to scroll.
  static const maxEntries = 16;
  static const maxLabel = 64;

  /// Null for a render result that carries neither. THROWS for one that is malformed, naming what,
  /// as a scene does: a menu quietly missing an entry reads as a panel without one.
  static PanelPlacementMenu? fromJson(Map<dynamic, dynamic> json) {
    final rawForm = json['form'];
    final rawMenu = json['menu'];
    if (rawForm == null && rawMenu == null) return null;
    PanelPlacementForm? form;
    if (rawForm != null) {
      if (rawForm is! Map || rawForm['key'] is! String || rawForm['title'] is! String || rawForm['elements'] is! List) {
        throw const FormatException('A render result\'s form is { key, title, elements }');
      }
      final title = (rawForm['title'] as String).trim();
      if (title.isEmpty || title.length > maxLabel) throw const FormatException('A render result\'s form needs a title of 1 to $maxLabel characters');
      form = (key: rawForm['key'] as String, title: title, elements: [for (final element in rawForm['elements'] as List) _element(element)]);
    }
    final entries = <PanelMenuEntry>[];
    if (rawMenu != null) {
      if (rawMenu is! List || rawMenu.length > maxEntries) throw const FormatException('A render result\'s menu is a list of at most $maxEntries entries');
      for (final entry in rawMenu) {
        final label = entry is Map && entry['label'] is String ? (entry['label'] as String).trim() : '';
        if (label.isEmpty || label.length > maxLabel) throw const FormatException('A menu entry needs a label of 1 to $maxLabel characters');
        final event = (entry as Map)['event'];
        final settings = entry['settings'] == true;
        if ((event is String && event.isNotEmpty) == settings) throw FormatException('Menu entry "$label" has either an `event` or `settings: true`');
        entries.add((label: label, event: settings ? null : event as String, settings: settings));
      }
    }
    // An empty one offers nothing, and the descriptor's own form stays the way in.
    if (form == null && entries.isEmpty) return null;
    return PanelPlacementMenu(form: form, entries: entries);
  }

  /// A form element, refused rather than drawn when the dialog could not keep its value: a field
  /// with no key, or a secret, which inside one config object would travel in a layout file.
  static Map<String, dynamic> _element(Object? element, {bool inRow = false}) {
    if (element is! Map) throw const FormatException('A form element is a map');
    final out = element.cast<String, dynamic>();
    if (!inRow && out['type'] == 'row') {
      final members = out['elements'];
      if (members is! List) throw const FormatException('A form row holds its fields in `elements`');
      return {
        ...out,
        'elements': [for (final member in members) _element(member, inRow: true)],
      };
    }
    if (!inRow && out['type'] == 'header') return out;
    if (out['key'] is! String || (out['key'] as String).isEmpty) throw const FormatException('A form field needs a `key`');
    if (out['fieldType'] == 'secret') throw FormatException('Form field "${out['key']}" is a secret, which a placement form does not keep');
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is PanelPlacementMenu &&
      other.form?.key == form?.key &&
      other.form?.title == form?.title &&
      jsonEncode(other.form?.elements) == jsonEncode(form?.elements) &&
      listEquals(other.entries, entries);

  @override
  int get hashCode => Object.hash(form?.key, form?.title, Object.hashAll(entries));
}
