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

import '../../config/experiments.dart';
import '../../config/version.dart';
import 'package:halo_i18n/halo_i18n.dart';
import '../../services/halo_services.dart';
import '../../services/app_storage.dart';
import '../../services/windows_url_schemes.dart';
import '../experiments_pane.dart';
import '../../services/extensions/extension_dev_client.dart';
import '../../services/extensions/installed_extensions.dart' show CatalogChannel;
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
            SwitchListTile(
              title: Text(context.t.settings.developerMode),
              subtitle: Text(context.t.settings.developer.developerModeDescription),
              value: settings.developerMode,
              onChanged: (enabled) => settings.setDeveloperMode(enabled),
            ),
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
                return ListTile(
                  leading: const Icon(MdiIcons.flaskOutline),
                  title: Text(context.t.settings.developer.experiments),
                  subtitle: Text(context.t.settings.developer.experimentsEnabled(count: enabledCount)),
                  mouseCursor: SystemMouseCursors.click,
                  // The pane loads the catalog itself — capturing this
                  // builder's `definitions` would freeze a still-loading
                  // (empty) snapshot into the pane for its whole lifetime.
                  onTap: () => showModalPane<void>(
                    context,
                    title: context.t.settings.developer.experiments,
                    closeLabel: context.t.common.close,
                    builder: (_) => ExperimentsPane(services: services),
                  ),
                );
              },
            ),
            // The extension dev loop (docs/extensions/development.md). Below
            // the developer-mode switch because it is meaningless without it,
            // and above the patch track because an author reaches for it far
            // more often.
            if (settings.developerMode) SectionedSlivers(slivers: [_ExtensionDevServerSection(services: services)]),
            // Developer mode gates it: pointing the app at a local catalog
            // is how the catalog itself is worked on.
            if (settings.developerMode) SectionedSlivers(slivers: [_CatalogOverrideSection(services: services)]),
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

/// Settings → Developer → Extension Dev Server: connect the app to a running
/// `npm run dev`, and see whether the loop is alive
/// (docs/extensions/development.md).
///
/// Stateful only for the text field's controller — everything shown comes from
/// the client, which is a ChangeNotifier.
class _ExtensionDevServerSection extends StatefulWidget {
  final HaLoServices services;

  const _ExtensionDevServerSection({required this.services});

  @override
  State<_ExtensionDevServerSection> createState() => _ExtensionDevServerSectionState();
}

class _ExtensionDevServerSectionState extends State<_ExtensionDevServerSection> {
  late final TextEditingController _url = TextEditingController(text: widget.services.settings.extensionDevServerUrl);

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final settings = widget.services.settings;
    await settings.setExtensionDevServerUrl(_url.text);
    // Remembered before the attempt, not after it succeeds: an author whose
    // server is briefly down still wants the address kept.
    await settings.setExtensionDevServerEnabled(true);
    await widget.services.extensionDev.connect(_url.text);
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
      listenable: widget.services.extensionDev,
      builder: (context, _) {
        final client = widget.services.extensionDev;
        final busy = client.state == DevServerState.connecting;
        final connected = client.state == DevServerState.connected;

        // Its own section: the panel's list sees one child, so a band left
        // inside it would name the rows of the section above.
        return SliverMainAxisGroup(
          slivers: sectionSlivers(context, [
            SectionHeader(t.extDevServer),
            _sectionBody(context, [
              Padding(
                padding: const EdgeInsets.only(bottom: Space.md),
                child: Text(t.extDevServerDescription, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
              TextField(
                controller: _url,
                enabled: !connected && !busy,
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
                onSubmitted: busy || connected ? null : (_) => _connect(),
              ),
              Padding(
                padding: const EdgeInsets.only(top: Space.md),
                child: Row(
                  children: [
                    ElevatedButton(
                      onPressed: busy ? null : (connected ? _disconnect : _connect),
                      child: Text(connected ? t.extDevServerDisconnect : t.extDevServerConnect),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(child: _status(context, client)),
                  ],
                ),
              ),
              if (connected)
                Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: Text(t.extDevServerNoSecrets, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ),
            ]),
          ]),
        );
      },
    );
  }

  Widget _status(BuildContext context, ExtensionDevClient client) {
    final theme = Theme.of(context);
    final t = context.t.settings.developer;
    final subdued = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    final error = client.lastError;
    if (error != null) {
      return Text(error, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error));
    }
    switch (client.state) {
      case DevServerState.connecting:
        return Text(t.extDevServerConnecting, style: subdued);
      case DevServerState.disconnected:
      case DevServerState.failed:
        return Text(t.extDevServerDisconnected, style: subdued);
      case DevServerState.connected:
        final reload = client.lastReload;
        final failing = client.buildErrors.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t.extDevServerConnected(count: client.servedKeys.length, keys: client.servedKeys.join(', ')),
              style: subdued,
            ),
            if (reload != null)
              Text(
                t.extDevServerLastReload(key: reload.key, time: TimeOfDay.fromDateTime(reload.at).format(context)),
                style: subdued,
              ),
            if (failing > 0)
              Text(
                t.extDevServerBuildErrors(count: failing),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
          ],
        );
    }
  }
}

/// Settings → Developer → Extension Catalog: read the catalog from another
/// address — a local one, for working on the catalog itself. Only the
/// address is typed here; CatalogService honours it under developer mode
/// alone, and an empty field is the real catalog.
class _CatalogOverrideSection extends StatefulWidget {
  final HaLoServices services;

  const _CatalogOverrideSection({required this.services});

  @override
  State<_CatalogOverrideSection> createState() => _CatalogOverrideSectionState();
}

class _CatalogOverrideSectionState extends State<_CatalogOverrideSection> {
  late final TextEditingController _url = TextEditingController(text: widget.services.settings.catalogBaseUrl);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Saved on leaving the field as well as on Enter: a developer who types
    // an address and clicks straight into the Extensions panel expects it
    // to be in force there.
    _focus.addListener(() {
      if (!_focus.hasFocus) unawaited(_save());
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final settings = widget.services.settings;
    if (_url.text.trim() == settings.catalogBaseUrl) return;
    await settings.setCatalogBaseUrl(_url.text);
    // The cached listings belong to the previous catalog.
    widget.services.catalog.invalidate();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t.settings.developer;
    // Its own section — see [_ExtensionDevServerSection].
    return SliverMainAxisGroup(
      slivers: sectionSlivers(context, [
        SectionHeader(t.catalog),
        _sectionBody(context, [
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: Text(t.catalogDescription, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          TextField(
            controller: _url,
            focusNode: _focus,
            autocorrect: false,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: t.catalogAddress,
              hintText: t.catalogHint,
              // Hand-built decorations render their hint at full opacity
              // without this, which reads as a filled-in value.
              hintStyle: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.38)),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => unawaited(_save()),
          ),
          const SizedBox(height: Space.lg),
          // What the panel's listing shows, not what installs follow: each
          // install keeps the track it arrived on whatever this says.
          ListenableBuilder(
            listenable: widget.services.settings,
            builder: (context, _) => RowSelectField(
              label: t.catalogSearchTracks,
              value: widget.services.settings.catalogSearchChannel,
              rows: [
                SelectRow(value: CatalogChannel.stable, name: t.catalogSearchStable),
                SelectRow(value: CatalogChannel.unstable, name: t.catalogSearchUnstable),
                SelectRow(value: CatalogChannel.bleeding, name: t.catalogSearchBleeding),
              ],
              onChanged: (value) {
                if (value is CatalogChannel) unawaited(widget.services.settings.setCatalogSearchChannel(value));
              },
            ),
          ),
        ]),
      ]),
    );
  }
}
