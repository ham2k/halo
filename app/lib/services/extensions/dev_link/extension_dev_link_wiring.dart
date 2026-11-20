// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The extension dev link's place among the app's services
// (docs/design/extension-dev-link.md): built at boot in a desktop build,
// listening while Developer Mode is on, closed at exit, and asking the
// operator wherever they are.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../config/dev_label.dart';
import '../../../config/navigation.dart';
import '../../../config/version.dart' show Edition, kEdition, kVersionName;
import '../../../views/extension_dev_link_dialog.dart';
import '../../error_reporting_service.dart';
import '../../halo_services.dart';
import '../extension_dev_client.dart';
import 'extension_dev_link.dart';

final _links = Expando<ExtensionDevLink>('extensionDevLink');

extension ExtensionDevLinkServices on HaLoServices {
  /// The link, or null where nothing on this machine could reach it: in a
  /// browser, which cannot listen, and on a phone, where no dev tool runs.
  ExtensionDevLink? get extensionDevLink => _links[this];
}

/// Puts [link] where Developer settings looks for it, as a desktop boot does.
@visibleForTesting
void debugSetExtensionDevLink(HaLoServices services, ExtensionDevLink? link) => _links[services] = link;

/// At boot: builds the link in a desktop build, and raises its question for
/// each tool that asks. The link itself follows Developer Mode.
void startExtensionDevLink(HaLoServices services) {
  if (kIsWeb || !(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) return;
  final link = _links[services] = services.closedOnExit<ExtensionDevLink>(
    'extension-dev-link',
    ExtensionDevLink(
      wanted: () => services.settings.developerMode,
      changes: services.settings,
      ports: extensionDevLinkPorts(kEdition.name),
      app: {'name': 'Ham2K Logger', 'edition': kEdition == Edition.prod ? 'regular' : kEdition.name, 'label': devLabel, 'version': kVersionName},
      newClient: (server, keys) => ExtensionDevClient(extensions: services.extensions, server: server, only: keys),
    ),
    (link) => link.closeForExit(),
  );
  link.addListener(() => _prompt(link));
}

/// The request a dialog is showing, so the link's own notifications cannot
/// stack a second dialog over it.
ExtensionDevLinkRequest? _showing;

void _prompt(ExtensionDevLink link) {
  final request = link.pendingRequest;
  if (request == null || _showing != null) return;
  final context = navigatorKey.currentContext;
  if (context == null) {
    // The first frame may still be building when a tool asks at launch.
    Timer(const Duration(milliseconds: 250), () => _prompt(link));
    return;
  }
  _showing = request;
  void failed(Object e, StackTrace st) {
    _showing = null;
    ErrorReportingService.reportIfRepeated('extensionDevLink:prompt', e, st, context: 'ExtensionDevLink:prompt', threshold: 1);
    Timer(const Duration(seconds: 5), () => _prompt(link));
  }

  final Future<bool> answered;
  try {
    answered = showExtensionDevLinkDialog(context, ask: request.ask, withdrawn: request.withdrawn);
  } catch (e, st) {
    failed(e, st);
    return;
  }
  unawaited(
    answered.then((allow) {
      ErrorReportingService.recordSuccess('extensionDevLink:prompt');
      _showing = null;
      link.answer(request, allow: allow);
      // The next tool waiting, if one is.
      _prompt(link);
    }, onError: failed),
  );
}
