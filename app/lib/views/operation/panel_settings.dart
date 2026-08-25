// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An extension panel's own configuration, reached from the Layout Setup
// sheet's gear — the same control a native panel's settings sit behind.
//
// A panel declares its fields in the settings-panel schema, so the core
// renders them with the same FormRenderer and persists them through the
// same declarative storage. There is no per-panel persistence code, and no
// bridge call while the operator types: values are written on commit and
// handed back to the panel's next render as `args.config`.

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../i18n/strings.g.dart';
import '../../main.dart';
import '../../services/panel_service.dart';
import '../../tools/form_chrome_labels.dart';

/// The `method` a panel's `type: 'action'` element names to reload whatever
/// its pane is showing, without closing the sheet or saving anything.
const String panelRefreshMethod = 'refresh';

/// Whether a form's value is the same as what the config held. A config
/// omits a field it has never been given, while the form renderer seeds an
/// unset checkbox as `false` and an unset text field as `''` — so a plain
/// `==` reads Save-without-typing as a change to every field the operator
/// has never touched, and re-renders the panel for nothing.
///
/// [declaredDefault] is the field's own `value`, which is what an unstored
/// field actually READS as. Without it a field defaulting to `true` can never
/// be turned off: unchecking it produces `false` against an unstored `null`,
/// which the "unset means falsy" rule below calls unchanged, so nothing is
/// written and the panel goes on reading its default forever.
///
/// Also the gate the pane layout options dialog's embedded panel-settings
/// form uses before committing an autosaved field — the same no-op check,
/// reused rather than duplicated.
bool sameConfigValue(Object? formValue, Object? stored, Object? declaredDefault) {
  if (formValue == stored) return true;
  if (stored != null) return false;
  if (declaredDefault != null) return formValue == declaredDefault;
  return formValue == null || formValue == false || formValue == '';
}

Future<void> showPanelSettings(
  BuildContext context, {
  required HaLoServices services,
  required PanelDefinition panel,
}) async {
  final t = context.t;
  final current = await services.panels.configFor(panel);
  if (!context.mounted) return;
  final result = await showFormDialog(
    context,
    formDefinition: {'title': panel.title, 'elements': panel.formFields},
    initialState: current,
    labels: formRendererLabelsFor(t),
    developerMode: services.settings.developerMode,
    // A panel's configuration is settings, not a form to fill in — same rows
    // the Settings panels show.
    settingsList: true,
    // NATIVE panels only, and the narrowness is the point. FormRenderer
    // disables an action button when `onAction` is null, so supplying one
    // unconditionally would turn every extension panel's action button from
    // visibly disabled into visibly enabled and silently inert — a worse
    // answer than the one it replaced, since the operator now concludes the
    // extension is broken rather than that the button is unavailable.
    //
    // Extension panel actions would have to reach a hook, which nothing here
    // routes; until they do, those buttons stay disabled.
    //
    // A native action reaches its pane through the service rather than a
    // controller the dialog holds: the asker is a dialog and the answerer is
    // a pane, and the counter is the seam between them.
    onAction: panel.source != PanelSource.native
        ? null
        : (actionKey, method, state) async {
            if (method == panelRefreshMethod) {
              services.panels.requestRefresh(panel.id);
              return null;
            }
            debugPrint('[panels] ${panel.id}: no action named "$method"');
            return null;
          },
  );
  if (result == null) return;
  var changed = false;
  // Written field by field through the same path a Tier 1 settings panel
  // uses, under the PANEL's id — so a panel's config travels with the panel
  // rather than with whichever extension happens to own it today.
  for (final field in panel.formFields) {
    final key = field['key'] as String?;
    if (key == null) continue;
    if (sameConfigValue(result[key], current[key], field['value'])) continue;
    await services.extensions.commitSettingsFieldValue(
      kind: 'simple',
      hookKey: panel.hookKey ?? panel.id,
      panelKey: panel.id,
      fieldKey: key,
      value: result[key],
      state: result,
      isSecret: field['fieldType'] == 'secret',
    );
    changed = true;
  }
  // The panel is showing content rendered against the OLD config, and a
  // panel with no triggers would go on showing it forever — the SDK promises
  // a render when the form changes, and this is the only place that knows it
  // did.
  if (changed) services.panels.markConfigChanged(panel.id);
}
