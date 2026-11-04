// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Developer: experiments, the extension dev server, data folder and the
// diagnostics an operator is asked to read out in a report.

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' show min;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../config/dev_bridge.dart';
import '../../config/experiments.dart';
import '../../config/version.dart';
import 'package:halo_i18n/halo_i18n.dart';
import '../../services/halo_services.dart';
import '../../services/app_storage.dart';
import '../../services/windows_url_schemes.dart';
import '../experiments_pane.dart';
import '../qson_import_flow.dart';
import '../../services/extensions/extension_dev_client.dart';
import '../../services/extensions/installed_extensions.dart' show CatalogChannel;
import '../../settings/settings_target_dialog.dart' show settingsSliverForTarget;
import '../version_label.dart';

class DeveloperPanel extends StatelessWidget {
  final HaLoServices services;

  const DeveloperPanel({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    final settings = services.settings;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return SectionedListView(
          // No inset of its own: every row here takes the ambient
          // ListTileTheme's, like every other panel's. Its own padding on top
          // pushed these rows in twice as far as the rest of Settings and
          // stopped their backgrounds short of the pane's edges.
          padding: const EdgeInsets.only(bottom: Space.xl),
          children: [
            _settingsRows([
              {
                'type': 'field',
                'fieldType': 'checkbox',
                'key': 'developerMode',
                'label': context.t.settings.developerMode,
                'description': context.t.settings.developer.developerModeDescription,
                'icon': 'code-tags',
                'value': settings.developerMode,
              },
            ], onChange: (_, value) => settings.setDeveloperMode(value == true)),
            // Reads live — the whole panel rebuilds under the
            // ListenableBuilder(settings) above, so a flip inside the pane
            // updates the count immediately.
            FutureBuilder<List<ExperimentDefinition>>(
              future: loadExperiments(),
              builder: (context, snapshot) {
                final definitions = snapshot.data ?? const <ExperimentDefinition>[];
                // Counted against the CURRENT catalog's LISTED entries: state
                // for removed experiments doesn't inflate it, and never-enabled
                // private ones are excluded so the count can't disagree with
                // the pane (which doesn't list them).
                final enabledCount = settings.enabledExperimentCount([
                  for (final d in definitions)
                    if (!d.private || settings.experimentEverEnabled(d.key)) d.key,
                ]);
                return _settingsRows(
                  [
                    {
                      'type': 'action',
                      'style': 'row',
                      'key': 'experiments',
                      'label': context.t.settings.developer.experiments,
                      'description': context.t.settings.developer.experimentsEnabled(count: enabledCount),
                      'icon': 'flask-outline',
                    },
                  ],
                  // The pane loads the catalog itself — capturing this
                  // builder's `definitions` would freeze a still-loading
                  // (empty) snapshot into the pane for its whole lifetime.
                  onAction: (_) => showModalPane<void>(
                    context,
                    title: context.t.settings.developer.experiments,
                    closeLabel: context.t.common.close,
                    builder: (_) => ExperimentsPane(services: services),
                  ),
                );
              },
            ),
            if (settings.developerMode) ...[
              SectionHeader(context.t.settings.developer.diagnostics),
              _settingsRows([
                {
                  'type': 'field',
                  'fieldType': 'checkbox',
                  'key': 'showIdleMetrics',
                  'label': context.t.settings.developer.showIdleMetrics,
                  'description': context.t.settings.developer.showIdleMetricsDescription,
                  'icon': 'speedometer',
                  'value': settings.showIdleMetrics,
                },
              ], onChange: (_, value) => settings.setShowIdleMetrics(value == true)),
              SectionHeader(context.t.settings.developer.importExport),
              _settingsRows([
                {
                  'type': 'action',
                  'style': 'row',
                  'key': 'qsonImport',
                  'label': context.t.qsonImport.title,
                  'description': context.t.qsonImport.description,
                  'icon': 'file-import-outline',
                },
              ], onAction: (_) => runQsonImport(context, services)),
            ],
            // The extension dev loop (docs/extensions/in-repo.md#the-dev-server). Below
            // the developer-mode switch because it is meaningless without it,
            // and above the patch track because an author reaches for it far
            // more often.
            if (settings.developerMode) ...[SectionHeader(context.t.settings.developer.extDevServer), _ExtensionDevServerRow(services: services)],
            // What the Extensions panel's listing asks the catalog for. Every
            // install keeps the track it arrived on whatever this says.
            if (settings.developerMode) ...[
              SectionHeader(context.t.settings.developer.catalog),
              _settingsRows(
                [
                  {
                    'type': 'field',
                    'fieldType': 'select',
                    'key': 'catalogSearchChannel',
                    'label': context.t.settings.developer.catalogSearchTracks,
                    'icon': 'store-search-outline',
                    'value': settings.catalogSearchChannel.name,
                    'options': [
                      {'label': context.t.settings.developer.catalogSearchStable, 'value': CatalogChannel.stable.name},
                      {'label': context.t.settings.developer.catalogSearchUnstable, 'value': CatalogChannel.unstable.name},
                      {'label': context.t.settings.developer.catalogSearchBleeding, 'value': CatalogChannel.bleeding.name},
                    ],
                  },
                ],
                onChange: (_, value) async {
                  final channel = CatalogChannel.tryParse(value as String?);
                  if (channel != null) await settings.setCatalogSearchChannel(channel);
                },
              ),
            ],
            // What extensions contribute here — their `target: 'developer'`
            // fields (docs/extensions/settings.md's "Settings targets"), such
            // as POTA's switch to its test servers. No band while none do.
            if (settings.developerMode)
              SectionedSlivers(
                slivers: [settingsSliverForTarget(services: services, target: 'developer', title: context.t.settings.developer.extensionSettings)],
              ),
            // Shorebird over-the-air patch track (docs/releases.md §4.3). Only
            // shown when the Shorebird engine is actually present — i.e. a
            // `shorebird release` build, not a local/debug/web one — so it's
            // invisible and inert everywhere it can't do anything.
            if (services.updates.isAvailable) ...[
              SectionHeader(context.t.settings.developer.patchTrack, subtitle: Text(context.t.settings.developer.patchTrackDescription)),
              _sectionBody(context, [
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: 'stable', label: Text(context.t.settings.developer.trackStable)),
                    ButtonSegment(value: 'unstable', label: Text(context.t.settings.developer.trackUnstable)),
                    ButtonSegment(value: 'bleeding-edge', label: Text(context.t.settings.developer.trackBleeding)),
                  ],
                  selected: {settings.shorebirdTrack},
                  onSelectionChanged: (selected) async {
                    final track = selected.first;
                    await settings.setShorebirdTrack(track);
                    services.statusBar.setMessage(
                      key: 'shorebird:check',
                      text: t.settings.developer.checkingTrack(track: track),
                    );
                    final applied = await services.updates.checkAndApply();
                    if (!context.mounted) return;
                    services.statusBar.setMessage(
                      key: 'shorebird:check',
                      text: applied ? t.settings.developer.patchDownloaded : t.settings.developer.noNewPatch(track: track),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(top: Space.md),
                  child: FutureBuilder<({bool resolved, int? number})>(
                    future: services.updates.currentPatchNumber(),
                    builder: (context, snapshot) {
                      final patch = snapshot.data?.number;
                      return Text(
                        patch == null ? context.t.settings.developer.noPatchInstalled : context.t.settings.developer.runningPatch(patch: patch),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      );
                    },
                  ),
                ),
              ]),
            ],
            // Portable and locally-built copies have no installer to write
            // the URL-scheme keys, so deep links reach them only if the
            // operator asks (HALO-178).
            //
            // Offered on every Windows build, installed ones included: there
            // is no reliable way to tell a portable copy from an installed
            // one, and the button is safe on both — it writes the same keys
            // the installer would, and the uninstaller reclaims per-user
            // keys even for an all-users install (see the .iss `[Code]`).
            if (!kIsWeb && Platform.isWindows) ...[
              SectionHeader(context.t.settings.developer.deepLinks),
              _sectionBody(context, [
                ListTile(
                  leading: const Icon(MdiIcons.linkVariant),
                  title: Text(context.t.settings.developer.registerUrlSchemes),
                  subtitle: Text(context.t.settings.developer.registerUrlSchemesDescription),
                  onTap: () => _registerWindowsUrlSchemes(context),
                  mouseCursor: SystemMouseCursors.click,
                ),
              ]),
            ],
            SectionHeader(context.t.settings.developer.systemInformation),
            _sectionBody(context, [
              _infoRow(
                context,
                context.t.settings.sync.deviceKey,
                settings.syncDeviceKey?.substring(0, min(8, settings.syncDeviceKey!.length)) ?? context.t.settings.developer.loading,
              ),
              _infoRowWidget(context, context.t.settings.developer.appVersion, const VersionLabel()),
              // Where the log database and the data-file cache live. Platform-
              // dependent, and relocated out of Documents on Windows and Linux
              // (see app_storage.dart), so it's worth being able to read it back
              // from a running build rather than guessing.
              if (!kIsWeb) _infoRowWidget(context, context.t.settings.developer.dataFolder, const _DataFolderValue()),
              // Which checkout a dev build came from, and since when it has
              // run: with several worktrees' builds open at once, the version
              // alone does not say whose code is on screen, nor whether it
              // has been restarted since a change.
              if (DevBridge.worktree.isNotEmpty) _infoRow(context, context.t.settings.developer.worktree, DevBridge.worktree),
              if (DevBridge.instance.installed)
                _infoRow(context, context.t.settings.developer.launchedAt, DevBridge.instance.launchedAt.toLocal().toString().substring(0, 19)),
            ]),
          ],
        );
      },
    );
  }

  /// Points this build's URL schemes at itself, and says which way it went.
  ///
  /// The result is REPORTED rather than assumed: reg.exe is the one part of
  /// this that can fail on a real machine (a locked-down policy, a redirected
  /// hive), and a button that silently did nothing would leave the operator
  /// clicking it again.
  Future<void> _registerWindowsUrlSchemes(BuildContext context) async {
    final error = await registerWindowsUrlSchemes(edition: kEdition.name);
    if (!context.mounted) return;
    services.statusBar.setMessage(
      key: 'deep-link:register-schemes',
      text: error == null ? context.t.settings.developer.registerUrlSchemesDone : context.t.settings.developer.registerUrlSchemesFailed(error: error),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return _infoRowWidget(
      context,
      label,
      // SelectionArea over a plain Text rather than SelectableText, which
      // styles itself apart from the row and reads off-colour in dark mode.
      SelectionArea(
        child: Text(value, style: const TextStyle(fontFamily: 'RobotoMono')),
      ),
    );
  }

  Widget _infoRowWidget(BuildContext context, String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(flex: 3, child: value),
        ],
      ),
    );
  }
}

/// A section's hand-built contents, under its [SectionHeader], at the rows'
/// own inset — the ambient ListTileTheme's, which carries the pane's
/// centring to the ideal width, so a field or button here lines up with the
/// ListTile rows above it instead of running to the pane's edges.
Widget _sectionBody(BuildContext context, List<Widget> children) => Padding(
  padding: (ListTileTheme.of(context).contentPadding ?? EdgeInsets.zero).add(const EdgeInsets.symmetric(vertical: Space.md)),
  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
);

/// [elements] as settings rows, the same rows every declared settings panel
/// renders: a checkbox is a switch row, a select opens its picker dialog, and
/// an action row runs [onAction] with its key. [onChange] stores what the
/// operator set.
Widget _settingsRows(
  List<Map<String, dynamic>> elements, {
  Future<void> Function(String key, Object? value)? onChange,
  Future<void> Function(String key)? onAction,
}) => FormRenderer(
  formDefinition: {'elements': elements},
  initialState: const {},
  settingsList: true,
  showActions: false,
  showTitle: false,
  onChange: onChange == null
      ? null
      : (key, value, _) async {
          await onChange(key, value);
          return null;
        },
  onAction: onAction == null
      ? null
      : (key, _, _) async {
          await onAction(key);
          return null;
        },
  onSubmit: (_) {},
  onCancel: () {},
);

/// Where the log database and the data-file cache live. Platform-dependent,
/// and relocated out of Documents on Windows and Linux (see app_storage.dart),
/// so it's worth being able to read it back from a running build rather than
/// guessing.
///
/// Stateful only to hold the future: `appDataDirectory()` hands back a new one
/// on every call, and the Developer panel rebuilds on every settings change —
/// so building it inline would drop the row back to "(loading…)" each time.
class _DataFolderValue extends StatefulWidget {
  const _DataFolderValue();

  @override
  State<_DataFolderValue> createState() => _DataFolderValueState();
}

class _DataFolderValueState extends State<_DataFolderValue> {
  late final _directory = appDataDirectory();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _directory,
      builder: (context, snapshot) =>
          SelectableText(snapshot.data?.path ?? context.t.settings.developer.loading, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
    );
  }
}

/// Settings → Developer → Extension Dev Server: whether the app is loading
/// extensions from a running `npm run dev`
/// (docs/extensions/in-repo.md#the-dev-server). A settings row showing the
/// address and how the loop is doing; a tap opens [_ExtensionDevServerDialog]
/// to change the address and connect.
class _ExtensionDevServerRow extends StatelessWidget {
  final HaLoServices services;

  const _ExtensionDevServerRow({required this.services});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([services.extensionDev, services.settings]),
      builder: (context, _) {
        final address = services.settings.extensionDevServerUrl;
        return _settingsRows(
          [
            {
              'type': 'action',
              'style': 'row',
              'key': 'extensionDevServer',
              'label': context.t.settings.developer.extDevServerAddress,
              'description': [if (address.isNotEmpty) address, ..._devServerStatusLines(context, services.extensionDev)].join('\n'),
              'icon': 'lan-connect',
            },
          ],
          onAction: (_) => showHaloDialog<void>(
            context: context,
            builder: (_) => _ExtensionDevServerDialog(services: services),
          ),
        );
      },
    );
  }
}

/// The dev server's address, the Connect or Disconnect that acts on it, and
/// the loop's status as it changes — the dialog stays open through a connect,
/// so the author sees it take or fail.
///
/// A widget of its own for the address field's controller, which has to
/// outlive the dialog's pop animation (the field rebuilds all the way
/// through it).
class _ExtensionDevServerDialog extends StatefulWidget {
  final HaLoServices services;

  const _ExtensionDevServerDialog({required this.services});

  @override
  State<_ExtensionDevServerDialog> createState() => _ExtensionDevServerDialogState();
}

class _ExtensionDevServerDialogState extends State<_ExtensionDevServerDialog> {
  late final TextEditingController _url = TextEditingController(text: widget.services.settings.extensionDevServerUrl);

  @override
  void dispose() {
    // Kept however the dialog closes — Done, Escape or a tap outside: an
    // address typed and not yet connected to is still the one to come back
    // to.
    unawaited(widget.services.settings.setExtensionDevServerUrl(_url.text));
    _url.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final settings = widget.services.settings;
    await settings.setExtensionDevServerUrl(_url.text);
    // Remembered before the attempt, not after it succeeds: an author whose
    // server is briefly down still wants the address kept.
    await settings.setExtensionDevServerEnabled(true);
    await widget.services.extensionDev.connect(settings.extensionDevServerUrl);
  }

  Future<void> _disconnect() async {
    await widget.services.settings.setExtensionDevServerEnabled(false);
    await widget.services.extensionDev.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t.settings.developer;

    return ListenableBuilder(
      listenable: Listenable.merge([widget.services.extensionDev, _url]),
      builder: (context, _) {
        final client = widget.services.extensionDev;
        final busy = client.state == DevServerState.connecting;
        final connected = client.state == DevServerState.connected;
        final canConnect = !busy && !connected && _url.text.trim().isNotEmpty;

        return HaloDialog(
          title: Text(t.extDevServer),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.extDevServerDescription, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: Space.lg),
              TextField(
                controller: _url,
                // The address in use stays put while the client holds it.
                enabled: !connected && !busy,
                autofocus: !connected,
                autocorrect: false,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: t.extDevServerAddress,
                  hintText: t.extDevServerHint,
                  // Hand-built decorations render their hint at full opacity
                  // without this, which reads as a filled-in value.
                  hintStyle: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.38)),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: canConnect ? (_) => _connect() : null,
              ),
              const SizedBox(height: Space.md),
              _devServerStatus(context, client),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: connected ? _disconnect : (canConnect ? _connect : null),
              child: Text(connected ? t.extDevServerDisconnect : t.extDevServerConnect),
            ),
          ],
          cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.done)),
        );
      },
    );
  }
}

/// How the dev loop is doing, a line per fact: the settings row's
/// description, and under the dialog's address.
List<String> _devServerStatusLines(BuildContext context, ExtensionDevClient client) {
  final t = context.t.settings.developer;
  final error = client.lastError;
  if (error != null) return [error];
  switch (client.state) {
    case DevServerState.connecting:
      return [t.extDevServerConnecting];
    case DevServerState.disconnected:
    case DevServerState.failed:
      return [t.extDevServerDisconnected];
    case DevServerState.connected:
      final reload = client.lastReload;
      final failing = client.buildErrors.length;
      return [
        t.extDevServerConnected(count: client.servedKeys.length, keys: client.servedKeys.join(', ')),
        if (reload != null) t.extDevServerLastReload(key: reload.key, time: TimeOfDay.fromDateTime(reload.at).format(context)),
        if (failing > 0) t.extDevServerBuildErrors(count: failing),
      ];
  }
}

/// [_devServerStatusLines] for the dialog, in the error colour when the
/// client has one to say or extensions are failing to build.
Widget _devServerStatus(BuildContext context, ExtensionDevClient client) {
  final theme = Theme.of(context);
  final failing = client.lastError != null || (client.state == DevServerState.connected && client.buildErrors.isNotEmpty);
  return Text(
    _devServerStatusLines(context, client).join('\n'),
    style: theme.textTheme.bodySmall?.copyWith(color: failing ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant),
  );
}
