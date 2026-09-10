// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The disposal contract the logging panel's models share. Not exported from
// the package: the models are the panel's own, and so is this.

import 'package:flutter/foundation.dart';

/// What every model the panel owns has in common: a disposed flag its async
/// paths check before touching state, and a notify that is a no-op once it
/// is set. A model's own [dispose] releases what it holds, then calls
/// `super.dispose()`, which sets the flag.
mixin PanelModel on ChangeNotifier {
  bool _disposed = false;

  /// True once [dispose] has run — an async path that outlived the panel
  /// checks this before touching state or notifying.
  bool get isDisposed => _disposed;

  /// [notifyListeners], unless disposed.
  void notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
