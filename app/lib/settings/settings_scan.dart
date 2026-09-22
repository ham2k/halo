// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One walk over every settings element the app declares — the core
// [SettingsRegistry] groups AND every extension `settingsPanel` — resolving
// system lists, applying the `environment` filter, and recording where each
// element writes back to.
//
// Two surfaces need this exact walk: [showSettingsForTarget]
// (settings_target_dialog.dart), which keeps whatever matches its `target`,
// and the SET/SHOW/HIDE command catalog (settings_catalog.dart), which keeps
// everything. They must agree on key namespacing and commit routing or a
// command would write somewhere the dialog wouldn't, so there is one copy.
//
// Extension-sourced `field` and `action` elements get their rendered `key`
// namespaced `<panelKey>.<key>` (mirroring the `<panelKey>.<fieldKey>`
// persistence convention in docs/extensions/settings.md) so two panels
// sharing a key — or an extension element colliding with a core one — can
// never misroute a commit or an action dispatch; core-group elements stay
// bare-keyed.

import '../services/halo_services.dart';
import 'settings_registry.dart';

/// Where an extension-sourced field routes on validate/commit. [field] is the
/// ORIGINAL (bare-keyed) element map as the extension declared it, distinct
/// from the namespaced copy in [ScannedSetting.element] — extension-facing
/// calls must never see this app's namespacing.
typedef ExtensionFieldRoute = ({String hookKey, String panelKey, String kind, String fieldKey, Map<String, dynamic> field});

/// Where an extension-sourced `type: 'action'` element dispatches. No `kind`,
/// unlike [ExtensionFieldRoute]: `ExtensionService.runSettingsAction` always
/// goes through the extension host regardless of panel tier.
typedef ExtensionActionRoute = ({String hookKey, String panelKey});

/// One declared settings element, with its origin and its write path.
///
/// Exactly one of [group], [fieldRoute] and [actionRoute] is non-null: a
/// core-group element commits through [group], an extension field through
/// [fieldRoute], an extension action dispatches through [actionRoute].
class ScannedSetting {
  /// The element as it should be RENDERED and keyed — see this file's header
  /// on namespacing. Never handed to an extension hook as-is.
  final Map<String, dynamic> element;

  /// [element]'s `key`. Elements without a String key (headers, dividers,
  /// markdown) are scanned with an empty key and are chrome, not settings.
  final String key;

  /// The section this element sits under — a core group's title, or an
  /// extension panel's. Shown by SET so a matched setting says where it lives.
  final String sectionTitle;

  /// Values of every OTHER element declared by the same group or panel, by
  /// bare key. `visibleWhen` names a sibling field, so evaluating it needs the
  /// form state this element would have been rendered in — which only exists
  /// here, at scan time, since nothing has built a form yet.
  final Map<String, dynamic> siblingValues;

  final SettingsGroup? group;
  final ExtensionFieldRoute? fieldRoute;
  final ExtensionActionRoute? actionRoute;

  const ScannedSetting({
    required this.element,
    required this.key,
    required this.sectionTitle,
    required this.siblingValues,
    this.group,
    this.fieldRoute,
    this.actionRoute,
  });

  bool get isField => element['type'] == 'field';

  String? get fieldType => element['fieldType'] as String?;
}

/// Every settings element the app currently declares, in section order.
///
/// Core-group elements come through whole (headers and markdown included, so
/// a target-scoped caller can still pick up chrome a group declares);
/// extension panels contribute only their `field` and `action` elements,
/// which are the only ones this app knows how to route.
///
/// `environment` is applied here rather than per-caller: a platform-excluded
/// element doesn't exist on this platform's session at all, not just hidden
/// from one view of it. `devMode` and `visibleWhen` are deliberately NOT
/// applied — they're per-surface (a target dialog renders through
/// [FormRenderer], which evaluates both itself), so a caller that needs them
/// applies them on top; see settings_catalog.dart.
Future<List<ScannedSetting>> scanSettings(HaLoServices services) async {
  final scanned = <ScannedSetting>[];

  for (final group in services.settingsRegistry.groups) {
    final resolved = await services.systemLists.resolveInElements(await group.buildElements());
    final elements = filterElementsForEnvironment(resolved);
    final values = _valuesOf(elements);
    for (final el in elements) {
      scanned.add(
        ScannedSetting(element: el, key: el['key'] is String ? el['key'] as String : '', sectionTitle: group.title, siblingValues: values, group: group),
      );
    }
  }

  for (final panel in await services.extensions.getSettingsPanels()) {
    final hookKey = panel['hookKey'] as String?;
    final panelKey = panel['panelKey'] as String?;
    final kind = panel['kind'] as String?;
    if (hookKey == null || panelKey == null || kind == null) continue;
    final definition = await services.extensions.getSettingsPanelDefinition(hookKey: hookKey, panelKey: panelKey, kind: kind);
    final rawElements = (definition?['elements'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final resolved = await services.systemLists.resolveInElements(rawElements);
    final elements = filterElementsForEnvironment(resolved);
    // Sibling values stay BARE-keyed: `visibleWhen` inside an extension panel
    // names the panel's own field keys, which is what the extension declared
    // and has no idea we namespace.
    final values = _valuesOf(elements);
    final title = (panel['title'] as String?) ?? panelKey;
    for (final el in elements) {
      final type = el['type'];
      if (type != 'field' && type != 'action') continue;
      final elementKey = el['key'];
      if (elementKey is! String) continue;
      final namespacedKey = '$panelKey.$elementKey';
      scanned.add(
        ScannedSetting(
          element: {...el, 'key': namespacedKey},
          key: namespacedKey,
          sectionTitle: title,
          siblingValues: values,
          fieldRoute: type == 'field' ? (hookKey: hookKey, panelKey: panelKey, kind: kind, fieldKey: elementKey, field: el) : null,
          actionRoute: type == 'action' ? (hookKey: hookKey, panelKey: panelKey) : null,
        ),
      );
    }
  }

  return scanned;
}

Map<String, dynamic> _valuesOf(List<Map<String, dynamic>> elements) => {
  for (final el in elements)
    if (el['type'] == 'field' && el['key'] is String) el['key'] as String: declaredSettingValue(el),
};

/// [element]'s value as the FORM would hold it, not merely as declared.
///
/// `FormRenderer._initializeFormState` fills a missing value in before
/// `_isVisible` ever reads it — a `checkbox` becomes `false`, a `multiselect`
/// an empty list, a text field `''` — so comparing the raw declaration
/// against a `visibleWhen` (or against a value about to be written) can
/// disagree with the screen this claims parity with. A checkbox that omits
/// `value` reads as null here and as `false` there, which is the difference
/// between "no change" and "changed" for `HIDE`.
///
/// Only the defaults that change a comparison are mirrored; `select`, `radio`,
/// `number` and `account` default to null, which is what an absent value
/// already is.
dynamic declaredSettingValue(Map<String, dynamic> element) {
  final value = element['value'];
  if (value != null) return value;
  return switch (element['fieldType']) {
    'checkbox' => false,
    'multiselect' => const <String>[],
    'list' => const <Map<String, dynamic>>[],
    'select' || 'radio' || 'number' || 'account' => null,
    _ => '',
  };
}

/// Whether [element]'s `visibleWhen` holds against [values] — the same
/// predicate `FormRenderer._isVisible` applies at render time, evaluated here
/// against a group's own field values so the SET command can't offer a
/// setting the settings screen would be hiding. `equals` may be a single
/// value or a list meaning "any of"; naming a field that doesn't exist reads
/// as null and so hides the element, matching the renderer.
bool elementIsVisibleWhen(Map<String, dynamic> element, Map<String, dynamic> values) {
  final when = element['visibleWhen'];
  if (when is! Map) return true;
  final actual = values[when['field']];
  final expected = when['equals'];
  return expected is List ? expected.contains(actual) : actual == expected;
}
