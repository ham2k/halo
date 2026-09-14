// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Installing an extension from a `.h2kext` file (HALO-422): pick it, see what
// it wants, agree, install — and the dialogs an extension has after that, its
// details and the way out.
//
// The asking is the point. An extension is code the app will run, arriving as
// a file from anyone, and the only thing between it and the operator is a
// screen that says what it will be able to reach. So the file is INSPECTED
// first and written only after — see InstalledExtensions.inspect.

import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show debugPrint, defaultTargetPlatform, kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../services/extension_info.dart';
import '../services/catalog_service.dart' show CatalogRelease;
import '../services/error_reporting_service.dart';
import '../services/halo_services.dart';
import '../services/installed_extensions.dart';

/// The file types the picker offers.
///
/// Mirrors `adifTypeGroups()`, for the same reasons and with the same two
/// platform traps: Android's `MimeTypeMap` cannot convert an extension it has
/// never heard of, so a filtered group offers a browser with nothing
/// selectable in it; and iOS filters by UTI and THROWS for a group carrying
/// none. What the operator picks is filtered by its magic bytes anyway.
@visibleForTesting
List<XTypeGroup> h2kextTypeGroups() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return const [];
  return const [
    XTypeGroup(
      label: 'Ham2K extension',
      extensions: ['h2kext'],
      // A .h2kext IS a zip, so this is honest — and `public.data` keeps a file
      // the system has not been taught about from being greyed out.
      uniformTypeIdentifiers: ['public.zip-archive', 'public.data'],
      mimeTypes: ['application/zip'],
    ),
  ];
}

/// Picks a bundle, asks, and installs it. Returns the installed extension's
/// name, or null if nothing was installed.
Future<String?> installExtensionFromFile(
  BuildContext context, {
  required InstalledExtensions store,
  required Future<void> Function(InspectedBundle) commit,
}) async {
  final file = await openFile(acceptedTypeGroups: h2kextTypeGroups());
  if (file == null) return null;
  if (!context.mounted) return null;
  return installExtensionFromBytes(context, store: store, commit: commit, read: file.readAsBytes);
}

/// The one install path, whatever the bundle arrived as — picked, dropped, or
/// fetched from a link. Keeping it one path is what stops the consent screen
/// from being the thing that gets forgotten on the route nobody tested.
///
/// [from] names where the bundle came from when that is not the operator's own
/// filesystem — a host, for a link. Shown on the consent screen, because
/// "which file did I just agree to" is a question a link cannot otherwise
/// answer.
///
/// [provenance] is the catalog listing the bytes must match; the store
/// re-checks the hash before opening them, and the record is what the
/// install writes for the key.
Future<String?> installExtensionFromBytes(
  BuildContext context, {
  required InstalledExtensions store,
  required Future<void> Function(InspectedBundle) commit,
  required Future<List<int>> Function() read,
  String? from,
  BundleProvenance? provenance,
  /// False only for a bulk update the operator has already asked for as a
  /// whole — see where the screen is shown below. Never for a file, a deep
  /// link, or anything an extension can reach.
  bool askConsent = true,
}) async {
  final InspectedBundle bundle;
  try {
    bundle = await store.inspect(await read(), provenance: provenance);
  } catch (e, stack) {
    // A BundleException is a sentence about this file and nothing more needs
    // saying. Anything else is a defect — a picker handing back a file that
    // has since gone, a decoder bug, running out of memory — and reporting it
    // is what lets ErrorPolicy decide, instead of this catch deciding for it.
    if (e is! BundleException) {
      ErrorReportingService.report(e, stack, context: 'extension-install:inspect');
    }
    // Logged even with nobody left to tell: a panel closing mid-decode must
    // not make the failure disappear entirely.
    if (!context.mounted) {
      debugPrint('[extensions] install failed after the panel closed: $e');
      return null;
    }
    await showInstallRefusal(context, e is BundleException ? e.message : '$e');
    return null;
  }

  if (!context.mounted) return null;
  // Asked for every install, and for every update taken one at a time.
  // Comparing capabilities would let a version through silently on the
  // strength of the key alone — and the code behind that key can have changed
  // completely, since nothing about the code is compared.
  //
  // [askConsent] false is the ONE exception, and it is not a capability
  // comparison: Update all is a single press on a list the operator is looking
  // at, naming every extension it will take and what each becomes. Asking five
  // times for the one thing they asked for once is how an operator learns to
  // press through the screen without reading it, which costs more than it
  // buys. It does mean an update that widens what an extension reaches is
  // applied without saying so — worth revisiting when a bundle can be shown to
  // come from who it claims, which is the same thing this whole rule waits on.
  if (askConsent) {
    final replacing = await _isInstalled(store, bundle);
    if (!context.mounted) return null;
    if (!await showConsentDialog(context, bundle: bundle, replacing: replacing, from: from)) return null;
  }

  try {
    await commit(bundle);
  } catch (e, stack) {
    // The install replaces the extension's directory before writing the new
    // one, so a failure here can leave a previously working extension gone.
    // Saying which one, and that it may need reinstalling, is the least this
    // owes the operator — a bare zone notice names nothing.
    ErrorReportingService.report(e, stack, context: 'extension-install:commit');
    if (context.mounted) await showInstallRefusal(context, context.t.extensionsPanel.installIncomplete(name: bundle.name));
    return null;
  }
  return bundle.name;
}

/// Install or Update from the catalog — the panel's button and a catalog deep
/// link take this one path. The same consent screen as a file, over bytes the
/// service matches to the listing's sha256 before the store re-checks them,
/// with the provenance the store records for the key; a built-in key is
/// refused before any download, with the sentence a file with that key gets.
/// Returns the installed extension's name, or null if nothing was installed.
///
/// [commit] is [ExtensionService.installBundle], or a wrapper that also
/// drives a caller's own "applying" state around it.
Future<String?> installFromCatalog(
  BuildContext context, {
  required HaLoServices services,
  required CatalogRelease release,
  required Future<void> Function(InspectedBundle) commit,
  bool askConsent = true,
}) async {
  final store = services.extensions.installed;
  // A press that did nothing at all, with no message and no log, is the one
  // outcome nobody could report.
  if (store == null) {
    debugPrint('[extensions] catalog install of ${release.key} before the installed store was ready');
    return null;
  }
  final catalog = services.catalog;
  final provenance = BundleProvenance(host: catalog.host, sha256: release.sha256, version: release.version);
  try {
    store.checkKeyInstallable(release.key, provenance: provenance);
  } on BundleException catch (e) {
    await showInstallRefusal(context, e.message);
    return null;
  }
  if (!context.mounted) return null;
  final name = await installExtensionFromBytes(
    context,
    store: store,
    read: () => catalog.download(release),
    from: catalog.host,
    provenance: provenance,
    commit: commit,
    askConsent: askConsent,
  );
  if (name == null) return null;
  services.catalogUpdateCheck.noteInstalled(release.key, release.version);
  // No per-key event: the catalog's keys are whatever anyone published,
  // which is unbounded cardinality and leaks what the operator uses (the
  // same reason settings_view reports every extension panel as one).
  services.track('extension_installed', {});
  services.statusBar.setMessage(key: 'extensions:installed', text: t.extensionsPanel.installedMessage(name: name));
  return name;
}

/// Whether [bundle] is replacing something, which is only how the screen is
/// worded. A store that cannot answer says no — the wrong word on a dialog is
/// a smaller failure than refusing to show one.
Future<bool> _isInstalled(InstalledExtensions store, InspectedBundle bundle) async {
  try {
    return await store.isInstalled(bundle.key);
  } catch (e) {
    debugPrint('[extensions] could not tell whether ${bundle.key} is installed: $e');
    return false;
  }
}

/// Why an install did not happen, in the install flow's own dialog — for a
/// refusal decided before the flow starts (a catalog key that is built in)
/// as much as for one it decides itself.
Future<void> showInstallRefusal(BuildContext context, String message) => showDialog<void>(
      context: context,
      builder: (context) => HaloDialog(
        title: Text(context.t.extensionsPanel.installFailed),
        content: Text(message),
        // The way out goes in `cancel:`, not `actions:` — see HaloDialog and
        // dialog_footer_convention_test.
        cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.done)),
      ),
    );

/// Shows what [bundle] will be able to reach, and returns whether the operator
/// agreed to it.
Future<bool> showConsentDialog(BuildContext context,
        {required InspectedBundle bundle, required bool replacing, String? from}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => _ConsentDialog(bundle: bundle, replacing: replacing, from: from),
    ) ??
    false;

/// What the extension will be able to reach, and a decision about it.
class _ConsentDialog extends StatelessWidget {
  final InspectedBundle bundle;
  final bool replacing;

  /// Where the bundle came from, when that is not the operator's own disk.
  final String? from;

  const _ConsentDialog({required this.bundle, required this.replacing, this.from});

  @override
  Widget build(BuildContext context) {
    final t = context.t.extensionsPanel;
    final theme = Theme.of(context);

    return HaloDialog(
      // The extension's own name, and nothing wrapped around it. Whether
      // this is an install or an update is what the primary button says, and
      // saying it twice cost the name the room it needs — some are long, and
      // the name is the thing the operator is actually deciding about.
      title: Text(bundle.name),
      content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (bundle.version.isNotEmpty)
              Text(t.installVersion(version: bundle.version), style: theme.textTheme.bodySmall),
            // Named prominently, not tucked away: a bundle that arrived from a
            // link is one the operator did not choose off their own disk, and
            // where it came from is most of what tells them whether to trust
            // it.
            if (from != null) ...[
              const SizedBox(height: Space.sm),
              _Capability(icon: MdiIcons.downloadOutline, label: t.installedFrom(source: from!)),
            ],
            if (bundle.description != null) ...[
              const SizedBox(height: Space.md),
              Text(bundle.description!),
            ],
            const SizedBox(height: Space.xl),
            // The capabilities, given the most room. The domains list is not a
            // summary of this extension's network access — it IS that access,
            // since host.fetch permits nothing else.
            if (!bundle.claimsCapabilities)
              Text(t.noCapabilities, style: theme.textTheme.bodyMedium)
            else ...[
              Text(t.canReach, style: theme.textTheme.titleSmall),
              const SizedBox(height: Space.sm),
              for (final domain in bundle.domains)
                _Capability(icon: MdiIcons.web, label: domain),
              if (bundle.requiresLocation) _Capability(icon: MdiIcons.crosshairsGps, label: t.canUseLocation),
              if (bundle.allowUserAgentOverride) _Capability(icon: MdiIcons.cardAccountDetailsOutline, label: t.canSetUserAgent),
            ],
            const SizedBox(height: Space.xl),
            Text(
              t.sandboxNote,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
      ),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.t.common.cancel)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(replacing ? t.updateAction : t.installAction),
        ),
      ],
    );
  }
}

class _Capability extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Capability({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: Space.md),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

/// Confirms removing an installed extension. Returns true when the operator
/// agreed.
Future<bool> confirmUninstall(BuildContext context, {required String name}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => HaloDialog(
          title: Text(context.t.extensionsPanel.uninstallTitle(name: name)),
          content: Text(context.t.extensionsPanel.uninstallBody),
          cancel: TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.t.common.cancel)),
          // Removing is this dialog's whole purpose, so here — unlike the
          // details dialog it was opened from — the destructive verb IS the
          // primary action and takes the trailing edge, with the way out to
          // its left. In the error colour, because it is the press that
          // cannot be undone.
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: Text(context.t.extensionsPanel.uninstallAction),
            ),
          ],
        ),
      ) ??
      false;
}

/// The one screen Update all shows, in place of the per-extension consent it
/// skips ([installExtensionFromBytes]'s `askConsent`).
///
/// Bulk is what makes it defensible: the operator is looking at the list, the
/// dialog names how many, and one answer covers all of them. It is a weaker
/// screen than the one it replaces — it does not say what any of them will be
/// able to reach — so it stays a confirmation of a job the operator started,
/// never a way to start one.
Future<bool> confirmUpdateAll(BuildContext context, {required int count}) async {
  final t = context.t.extensionsPanel;
  return await showDialog<bool>(
        context: context,
        builder: (context) => HaloDialog(
          title: Text(t.updateAllTitle(count: count)),
          content: Text(t.updateAllBody),
          cancel: TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.t.common.cancel)),
          // Confirming is this dialog's whole purpose, so the verb takes the
          // trailing edge and the way out sits to its left — the same shape as
          // the remove confirmation.
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(t.updateAllAction),
            ),
          ],
        ),
      ) ??
      false;
}

/// Accepts a `.h2kext` dropped anywhere on its [child].
///
/// Modelled on `AdifDropTarget`, and inert on iOS and Android for the same
/// reason: `desktop_drop` is a no-op where there is no file-drag gesture, and
/// those platforms reach the same install through the button.
class ExtensionDropTarget extends StatefulWidget {
  final Widget child;
  final Future<void> Function(XFile file) onFile;

  const ExtensionDropTarget({super.key, required this.child, required this.onFile});

  @override
  State<ExtensionDropTarget> createState() => _ExtensionDropTargetState();
}

class _ExtensionDropTargetState extends State<ExtensionDropTarget> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropTarget(
      // `desktop_drop` dispatches to EVERY listener whose box contains the
      // point — there is no topmost-wins hit test — so a target under a pushed
      // route still fires. Without this a drop while the consent dialog is
      // open starts a second install behind it.
      enable: ModalRoute.of(context)?.isCurrent ?? true,
      // Highlights for any drag, not only a bundle: what a drag carries is not
      // reliably known until it lands, so promising nothing until then would
      // mean no feedback at all on the common case. What was actually dropped
      // is decided by its magic bytes, same as the picker.
      onDragEntered: (_) => setState(() => _hovering = true),
      onDragExited: (_) => setState(() => _hovering = false),
      onDragDone: (details) async {
        setState(() => _hovering = false);
        // One at a time. Installing several would mean several consent
        // screens in a row, which is the shape people click through — and
        // picking one silently is worse.
        if (details.files.length > 1) {
          if (mounted) await showInstallRefusal(context, context.t.extensionsPanel.dropOneOnly);
          return;
        }
        final file = details.files.firstOrNull;
        if (file != null) await widget.onFile(file);
      },
      child: Stack(
        children: [
          widget.child,
          if (_hovering)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(Space.lg),
                        child: Text(context.t.extensionsPanel.dropHint, style: theme.textTheme.titleMedium),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// What the operator chose in the details dialog, or null if they closed it.
enum ExtensionDetailsAction { uninstall, update }

/// Everything the app knows about one extension, and what can be done about
/// it — the dialog behind an extension row's info button.
///
/// The row itself carries a name, a description and a switch, which is what
/// an operator scanning the list needs. Everything else about an extension —
/// where it came from, what it can reach, what it plugs into — is here rather
/// than crowding fifty rows with it.
///
/// [update] is the release the catalog offers when that is newer than what is
/// installed; null means there is nothing to move to. The dialog only ever
/// ANSWERS: acting is the panel's, which owns the applying state and the
/// status bar.
Future<ExtensionDetailsAction?> showExtensionDetails(
  BuildContext context, {
  required ExtensionInfo info,
  required String locale,
  String? installedFrom,
  IconData? installedFromIcon,
  String? updateVersion,
}) =>
    showDialog<ExtensionDetailsAction>(
      context: context,
      builder: (context) => _DetailsDialog(
        info: info,
        locale: locale,
        installedFrom: installedFrom,
        installedFromIcon: installedFromIcon,
        updateVersion: updateVersion,
      ),
    );

class _DetailsDialog extends StatelessWidget {
  final ExtensionInfo info;
  final String locale;
  final String? installedFrom;

  /// The icon for [installedFrom] — a download is not what a pre-installed
  /// bundle did, and the caller is the only thing that knows which it was.
  final IconData? installedFromIcon;
  final String? updateVersion;

  const _DetailsDialog({
    required this.info,
    required this.locale,
    required this.installedFrom,
    required this.installedFromIcon,
    required this.updateVersion,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t.extensionsPanel;
    final theme = Theme.of(context);
    final description = info.descriptionFor(locale);
    // The app's own extensions are at whatever version the app is, which is
    // not a version anybody can act on — the row says so instead of a number,
    // and so does this.
    final version = info.isInstalled ? info.version : null;
    // The same three things `InspectedBundle.claimsCapabilities` asks of a
    // bundle at install, asked of the extension afterwards.
    final claimsCapabilities = info.domains.isNotEmpty || info.requiresLocation || info.allowUserAgentOverride;
    final hookLabels = extensionHookLabels(info.hooks, t);

    return HaloDialog(
      title: Text(info.nameFor(locale)),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (version != null) Text(t.installVersion(version: version), style: theme.textTheme.bodySmall),
          if (description != null) ...[
            const SizedBox(height: Space.md),
            Text(description),
          ],
          const SizedBox(height: Space.xl),
          // Where it came from, in the same words the consent screen used
          // when it arrived. For an extension the app ships there is nothing
          // to say beyond that it does.
          _Capability(
            icon: installedFromIcon ?? MdiIcons.packageVariantClosed,
            label: installedFrom ?? t.builtIn,
          ),
          const SizedBox(height: Space.xl),
          // The same capability list the operator agreed to at install, so
          // "what did I let this reach" is answerable afterwards and not only
          // in the moment.
          if (!claimsCapabilities)
            Text(t.noCapabilities, style: theme.textTheme.bodyMedium)
          else ...[
            Text(t.canReach, style: theme.textTheme.titleSmall),
            const SizedBox(height: Space.sm),
            for (final domain in info.domains) _Capability(icon: MdiIcons.web, label: domain),
            if (info.requiresLocation) _Capability(icon: MdiIcons.crosshairsGps, label: t.canUseLocation),
            if (info.allowUserAgentOverride)
              _Capability(icon: MdiIcons.cardAccountDetailsOutline, label: t.canSetUserAgent),
          ],
          if (hookLabels.isNotEmpty) ...[
            const SizedBox(height: Space.xl),
            Text(t.detailsWhatItDoes, style: theme.textTheme.titleSmall),
            const SizedBox(height: Space.sm),
            Text(hookLabels.join(' · '), style: theme.textTheme.bodySmall),
          ],
        ],
      ),
      // Removing destroys what the extension stored, so it goes in
      // `destructive:` — the leading edge, as far from the way out as the
      // footer allows — and in the error colour, which is the one thing on
      // this dialog that cannot be undone.
      destructive: info.isInstalled
          ? TextButton(
              onPressed: () => Navigator.of(context).pop(ExtensionDetailsAction.uninstall),
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
              child: Text(t.uninstallAction),
            )
          : null,
      // Update is something else to DO with the extension rather than a way
      // out of the dialog, which is exactly what `secondary:` is for.
      secondary: updateVersion == null
          ? null
          : FilledButton(
              onPressed: () => Navigator.of(context).pop(ExtensionDetailsAction.update),
              child: Text(t.updateAction),
            ),
      // Done, not Close: the footer convention retires Close, and this dialog
      // has nothing to commit (docs/design/user-interface.md §Dialogs). With
      // no `actions:` it lands on the trailing edge itself — the last button
      // on the right, which is where the way out of a dialog that only
      // reports belongs.
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.done)),
    );
  }
}

/// What an extension's declared [hooks] say it does, in the operator's words.
///
/// Most of the hook vocabulary is plumbing — how an extension attaches to the
/// app, not anything anybody chose it for — and those are dropped rather than
/// shown as their identifiers. A hook nobody has given words to is dropped for
/// the same reason: the list is what this extension is FOR, and an identifier
/// in it reads as a defect.
///
/// A reference hook names a program, and the pair is what says which side of
/// it: `ref:wwffActivation` is activating one and `ref:wwff` is hunting one —
/// but only when the activation twin is in the same list, since a contest
/// declares the plain form alone and is neither hunted nor activated.
///
/// A QUALIFIED claim (`ref:qp/ny`) is dropped: it is how an extension reaches
/// back for references logged under a type it does not publish, not something
/// anybody would choose it for, and its plain claim is in the same list
/// saying what it is. Shown, it reads as `QP/NY`.
List<String> extensionHookLabels(List<String> hooks, Translations$extensionsPanel$en t) {
  const refPrefix = 'ref:';
  const activationSuffix = 'Activation';
  final labels = <String>[];
  for (final hook in hooks) {
    if (!hook.startsWith(refPrefix)) {
      final label = switch (hook) {
        'account' => t.hookAccount,
        'callNotes' => t.hookCallNotes,
        'dataFile' => t.hookDataFile,
        'export' => t.hookExport,
        'lookup' => t.hookLookup,
        'scoring' => t.hookScoring,
        'spots' => t.hookSpots,
        _ => null,
      };
      if (label != null) labels.add(label);
      continue;
    }
    final code = hook.substring(refPrefix.length);
    if (refClaimOf(hook)?.code != null) continue;
    if (code.endsWith(activationSuffix)) {
      labels.add(t.hookActivating(
          program: _programName(code.substring(0, code.length - activationSuffix.length))));
    } else if (hooks.contains('$hook$activationSuffix')) {
      labels.add(t.hookHunting(program: _programName(code)));
    } else {
      labels.add(_programName(code));
    }
  }
  return labels;
}

/// A reference type as a program is written: an abbreviation hams read in
/// capitals, with the hyphens a hook name needs turned back into spaces.
String _programName(String code) => code.replaceAll('-', ' ').toUpperCase();
