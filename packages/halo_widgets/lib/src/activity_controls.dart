// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Looks up an `operationControls`/`activityControls` entry (icon, pattern,
// …) for a ref/suggestion type — shared between ActivitiesView,
// OperationLocationScreen and QsoList, which all render refs/suggestions
// using the same active-extension controls list.

import 'package:flutter/widgets.dart' show Color;

import 'icon_resolver.dart';

/// The controls entry for [refType], or null for a type with no active
/// control.
Map<String, dynamic>? controlForRefType(List<Map<String, dynamic>> controls, String? refType) {
  for (final control in controls) {
    final input = control['input'] as Map?;
    if (input?['refType'] == refType) return control;
  }
  return null;
}

/// Icon name for [refType], falling back to a generic marker (via
/// `resolveIconName`) for a type with no active control.
String? iconForRefType(List<Map<String, dynamic>> controls, String? refType) =>
    controlForRefType(controls, refType)?['icon'] as String?;

/// The control's declared accent color for [refType], or null when it has
/// none (see `resolveExtensionColor`).
Color? colorForRefType(List<Map<String, dynamic>> controls, String? refType) =>
    resolveExtensionColor(controlForRefType(controls, refType)?['color'] as String?);
