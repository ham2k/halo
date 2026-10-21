// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a pane shows when the panel behind it is not in the catalog — an
// extension disabled, uninstalled, or one whose runtime has not answered
// yet — and what would bring it back (docs/design/layouts.md).
//
// The pane STAYS. A saved arrangement is never set aside for naming a
// module the catalog cannot currently explain: an extension that is only
// briefly missing repairs itself when it answers, and one that is really
// gone waits to be removed from Layout Setup, deliberately. The alternative
// — judging the arrangement unbuildable — means the next thing written
// replaces it, so a hook that timed out once costs the operator a layout
// they cannot get back.

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';

import '../../services/halo_services.dart';
import 'activities_catalog_tier.dart' show installCatalogExtension;

/// The extension a panel id belongs to, for naming it in a message. Ids are
/// `ext:<hookKey>:<panelKey>`; anything else is not an extension's.
String? extensionKeyOfPanelId(String id) {
  final parts = id.split(':');
  return parts.length >= 3 && parts.first == 'ext' ? parts[1] : null;
}

/// The panel's own key, which reads better on a tab than the full id.
String panelKeyOfPanelId(String id) {
  final parts = id.split(':');
  return parts.length >= 3 && parts.first == 'ext' ? parts.sublist(2).join(':') : id;
}

/// Gains an extension — [gain] enables or installs it, answering whether
/// it did — and brings in the panels it adds. True when it did.
typedef ExtensionGainer = Future<bool> Function(Future<bool> Function() gain);

class MissingPanelPane extends StatelessWidget {
  final HaLoServices services;
  final String panelId;
  final ExtensionGainer gainWith;

  const MissingPanelPane({super.key, required this.services, required this.panelId, required this.gainWith});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final key = extensionKeyOfPanelId(panelId);
    final installed = key == null ? null : services.extensions.extensionInfo(key);
    return Padding(
      padding: const EdgeInsets.all(Space.xl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(MdiIcons.toyBrickRemove, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: Space.lg),
            Text(
              context.t.operation.layout.missingExtension(name: installed?.nameFor(LocaleSettings.currentLocale.languageCode) ?? key ?? panelId),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (key != null) ...[const SizedBox(height: Space.md), MissingExtensionAction(services: services, extensionKey: key, gainWith: gainWith)],
          ],
        ),
      ),
    );
  }
}

/// What there is to do about an extension the app is not running: Enable
/// one that is installed and switched off, Install one the catalog has —
/// its own consent prompt and all — or, where neither can help, why not.
///
/// The catalog is asked only once Install is pressed, not when this is
/// drawn: a pane drawn on every open of a layout would otherwise be a fetch
/// the operator never asked for.
class MissingExtensionAction extends StatefulWidget {
  final HaLoServices services;
  final String extensionKey;
  final ExtensionGainer gainWith;

  const MissingExtensionAction({super.key, required this.services, required this.extensionKey, required this.gainWith});

  @override
  State<MissingExtensionAction> createState() => _MissingExtensionActionState();
}

enum _CatalogAnswer { unreachable, notListed }

class _MissingExtensionActionState extends State<MissingExtensionAction> {
  bool _busy = false;
  _CatalogAnswer? _answer;

  /// Whether the last press failed. [MissingExtensionAction.gainWith] reports
  /// that and answers false, as it does for a consent the operator declined,
  /// so the failure is caught on its way past instead.
  bool _failed = false;

  HaLoServices get _services => widget.services;

  Future<void> _gain(Future<bool> Function() gain) async {
    var failed = false;
    setState(() => _busy = true);
    try {
      await widget.gainWith(() async {
        try {
          return await gain();
        } catch (_) {
          failed = true;
          rethrow;
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = failed;
        });
      }
    }
  }

  Future<bool> _install() async {
    final entries = await _services.catalog.fetchCatalog(geo: _services.flags.operatorGeo);
    final entry = entries?.where((entry) => entry.key == widget.extensionKey).firstOrNull;
    if (!mounted) return false;
    if (entry == null) {
      setState(() => _answer = entries == null ? _CatalogAnswer.unreachable : _CatalogAnswer.notListed);
      return false;
    }
    _answer = null;
    return installCatalogExtension(context, services: _services, entry: entry);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.operation.layout;
    final extensions = _services.extensions;
    final note = Theme.of(context).textTheme.bodySmall;
    if (_busy) return const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2));
    final installed = extensions.extensionInfo(widget.extensionKey);
    if (installed == null) {
      return switch (_answer) {
        _CatalogAnswer.notListed => Text(t.missingExtensionNotInCatalog, style: note),
        _CatalogAnswer.unreachable => TextButton(onPressed: () => _gain(_install), child: Text(t.missingExtensionCatalogUnreachable)),
        null => TextButton(onPressed: () => _gain(_install), child: Text(_failed ? t.missingExtensionFailed : t.missingExtensionInstall)),
      };
    }
    if (!extensions.isExtensionAvailable(installed)) return Text(t.missingExtensionUnavailable, style: note);
    if (extensions.isExtensionRevoked(installed) || extensions.isExtensionRefused(installed)) {
      return Text(t.missingExtensionWontRun, style: note, textAlign: TextAlign.center);
    }
    if (!extensions.isExtensionEnabled(installed)) {
      return TextButton(
        onPressed: () => _gain(() async {
          await extensions.setExtensionEnabled(widget.extensionKey, true);
          return true;
        }),
        child: Text(_failed ? t.missingExtensionFailed : t.missingExtensionEnable),
      );
    }
    // Running, and its panels not in yet: the runtime has not answered.
    return const SizedBox.shrink();
  }
}
