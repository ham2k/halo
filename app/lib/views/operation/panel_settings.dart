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

import 'package:collection/collection.dart' show DeepCollectionEquality;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import '../extension_markdown_images.dart';

import '../../services/error_reporting_service.dart';
import '../../services/file_pick.dart';
import '../../services/halo_services.dart';
import '../../services/panel_menu.dart';
import '../../services/panel_service.dart';
import '../dock_layouts/layout_menu.dart' show saveTextFile;
import 'remote_screen/remote_screen_panel.dart';
import 'remote_screen/remote_screen_picker.dart';

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

Future<void> showPanelSettings(BuildContext context, {required HaLoServices services, required PanelDefinition panel}) async {
  final current = await services.panels.configFor(panel);
  if (!context.mounted) return;
  final result = await showFormDialog(
    context,
    formDefinition: {'title': panel.title, 'elements': panel.formFields},
    initialState: current,
    markdownImages: extensionImagesFor(services.extensions, panel.hookKey),
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
            if (method == remoteScreenChooseMethod) {
              if (!context.mounted) return null;
              final chosen = await showRemoteScreenPicker(context, views: services.peerScreenViews);
              // Dismissed, not chosen — leave whatever the pane already
              // shows rather than clearing it out from under the operator.
              if (chosen == null) return null;
              return FormActionResult(fieldUpdates: {remoteScreenTargetKey: chosen.encode()});
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
  for (final field in panel.formValueFields) {
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

/// A placement's own form (`PanelContent.form`), its values one object in `config[form.key]`.
/// Its system lists (`$core.radios`) are resolved here, as a settings group's are.
Future<void> showPlacementSettings(
  BuildContext context, {
  required HaLoServices services,
  required PanelDefinition panel,
  required PanelPlacementForm form,
}) async {
  final t = context.t.operation.layout;
  try {
    final config = await services.panels.configFor(panel);
    final elements = await services.systemLists.resolveInElements(form.elements);
    if (!context.mounted) return;
    final stored = config[form.key];
    final current = stored is Map ? stored.cast<String, dynamic>() : const <String, dynamic>{};
    final result = await showFormDialog(
      context,
      formDefinition: {'title': form.title, 'elements': elements},
      initialState: current,
      markdownImages: extensionImagesFor(services.extensions, panel.hookKey),
      developerMode: services.settings.developerMode,
      settingsList: true,
    );
    if (result == null) return;
    final keys = {
      for (final element in elements)
        for (final field in element['type'] == 'row' ? (element['elements'] as List?) ?? const [] : [element])
          if (field is Map && field['key'] is String) field['key'] as String,
    };
    final next = {...current, for (final key in keys) key: result[key]};
    if (const DeepCollectionEquality().equals(next, current)) return;
    await services.panels.writeConfig(panel, {form.key: next});
  } catch (e, stack) {
    // Said here, whatever else the session has said: the operator pressed Save, and the values
    // they chose are not kept.
    ErrorReportingService.report(
      e,
      stack,
      context: 'panel:settings:${panel.id}',
      notice: ErrorNotice(
        services.statusBar,
        key: 'panel:settings:${panel.id}',
        title: t.panelSettingsFailed(panel: panel.title),
      ),
    );
  }
}

/// What an imported file may weigh: a panel's content, never a log.
const _maxPanelFileBytes = 1 << 20;

/// Picks a file of [panel]'s kind (`PanelDescriptor.file`) and sends its text to the pane as an
/// event, whose answer keeps what the panel accepts.
Future<void> importPanelFile(BuildContext context, {required HaLoServices services, required PanelDefinition panel}) async {
  final file = panel.file!;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final t = context.t.operation.layout;
  final XFile? chosen;
  try {
    chosen = await pickFile(
      acceptedTypeGroups: [
        // `public.data` keeps a file the system has not been taught about from being greyed out.
        XTypeGroup(label: file.extension, extensions: [file.extension], uniformTypeIdentifiers: const ['public.data']),
      ],
    );
  } catch (e, stack) {
    ErrorReportingService.report(e, stack, context: 'panel:file:picker', told: messenger != null);
    messenger?.showSnackBar(haloSnackBar(t.panelFileUnreadable(error: ErrorReportingService.messageOf(e))));
    return;
  }
  if (chosen == null) return;
  final String text;
  try {
    if (await chosen.length() > _maxPanelFileBytes) throw const FormatException('it is over 1 MB');
    text = await chosen.readAsString();
  } catch (e) {
    messenger?.showSnackBar(haloSnackBar(t.panelFileUnreadable(error: ErrorReportingService.messageOf(e))));
    return;
  }
  await sendPanelMenuEvent(services, panel, {
    'controlId': 'file',
    'action': 'file',
    'phase': 'commit',
    'sequence': 0,
    'text': text,
  }, failed: t.panelImportFailed(panel: panel.title));
}

/// Sends a menu's [event] to [panel]'s pane and says so when it fails: a menu entry has no control
/// to snap back, so without this a failure would look like an entry that does nothing.
Future<void> sendPanelMenuEvent(HaLoServices services, PanelDefinition panel, Map<String, dynamic> event, {required String failed}) async {
  try {
    await services.panels.queueEvent(panel.id, event);
  } catch (e, stack) {
    ErrorReportingService.report(
      e,
      stack,
      context: 'panel:menu:${panel.id}',
      notice: ErrorNotice(services.statusBar, key: 'panel:menu:${panel.id}', title: failed),
    );
  }
}

/// Saves [panel]'s `config[file.key]` as `<title>.<extension>`, the way a layout file is saved.
Future<void> exportPanelFile(BuildContext context, {required HaLoServices services, required PanelDefinition panel, required String title}) async {
  final file = panel.file!;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final t = context.t.operation.layout;
  try {
    final text = (await services.panels.configFor(panel))[file.key] ?? '';
    if (text is! String) throw FormatException('${panel.title} keeps "${file.key}" as something other than text');
    if (!context.mounted) return;
    final saved = await saveTextFile(
      context,
      services,
      name: title,
      fallback: file.extension,
      extension: file.extension,
      content: text,
      mimeType: 'text/plain',
    );
    if (saved != null) messenger?.showSnackBar(haloSnackBar(t.panelFileSaved(location: saved)));
  } catch (e, stack) {
    ErrorReportingService.report(e, stack, context: 'panel:file:export', told: messenger != null);
    messenger?.showSnackBar(haloSnackBar(t.panelFileFailed(error: ErrorReportingService.messageOf(e))));
  }
}
