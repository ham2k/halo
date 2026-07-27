// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_widgets/halo_widgets.dart';

import '../i18n/strings.g.dart';

/// Builds the form renderer's localized chrome vocabulary (see
/// FormRendererLabels) from the app's translations. Takes a [Translations]
/// rather than a BuildContext so callers without one (extension_service's
/// `showForm` command) can pass the global `t`.
FormRendererLabels formRendererLabelsFor(Translations t) => FormRendererLabels(
      cancel: t.common.cancel,
      save: t.common.save,
      done: t.common.done,
      closeLabel: t.common.close,
      untitledItem: t.formChrome.untitled,
      showMore: t.formChrome.showMore,
      showAll: t.formChrome.showAll,
      showFewer: t.formChrome.showFewer,
      defaults: t.formChrome.defaults,
      searchHint: t.formChrome.search,
      clearLabel: t.formChrome.clear,
      openPageLabel: t.formChrome.openPage,
      removeItemLabel: t.formChrome.removeItem,
      connected: t.formChrome.connected,
      notConnected: t.formChrome.notConnected,
      storageUnavailable: t.formChrome.storageUnavailable,
      manage: t.formChrome.manage,
      connect: t.formChrome.connect,
      formTitle: t.formChrome.formTitle,
      addItem: (label) => t.formChrome.addItem(label: label),
      editItem: (label) => t.formChrome.editItem(label: label),
      multiselectStatus: (shown, total, selected) =>
          t.formChrome.multiselectStatus(shown: shown, total: total, selected: selected),
      validationError: (error) => t.formChrome.validationError(error: error),
      transformationError: (error) => t.formChrome.transformationError(error: error),
      actionError: (error) => t.formChrome.actionError(error: error),
    );
