// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Looks up an `operationControls`/`activityControls` entry (icon, pattern,
// …) for a ref/suggestion type — shared between ActivitiesView,
// OperationLocationScreen and QsoList, which all render refs/suggestions
// using the same active-extension controls list.

import 'package:flutter/material.dart';

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

/// Whether [refType] doesn't match any currently active control — its
/// extension isn't installed/loaded/enabled right now. A null [refType]
/// (no control ever declares one) counts as unknown too, same as before
/// this got its own named helper.
bool isUnknownRefType(List<Map<String, dynamic>> controls, String? refType) =>
    controlForRefType(controls, refType) == null;

/// The icon for a ref/suggestion of [refType]: the matching control's own
/// icon, tinted with its declared accent color if any — or, when it matches
/// no active control, a pale-red circle with a question-mark, so a ref from
/// an extension that's no longer installed/loaded degrades visibly instead
/// of silently showing a generic marker (ham2k/app-halo-dist#261). Shared by
/// every place that lists refs against the current controls (ActivitiesView,
/// OperationLocationScreen, QsoList). [iconSize]/[avatarRadius] default to
/// the ambient Icon/CircleAvatar sizes (a ListTile's `leading` slot) for the
/// known-type icon — the question-mark itself defaults to 16 regardless (its
/// prior hardcoded size), overridable for a more compact inline usage (e.g.
/// QsoList's per-row count).
Widget activityRefIcon(
  List<Map<String, dynamic>> controls,
  String? refType, {
  double? iconSize,
  double? avatarRadius,
}) {
  final control = controlForRefType(controls, refType);
  if (control == null) {
    return CircleAvatar(
      radius: avatarRadius,
      backgroundColor: Colors.red,
      child: Icon(Icons.question_mark, color: Colors.white, size: iconSize ?? 16),
    );
  }
  final icon = Icon(resolveIconName(control['icon'] as String?), size: iconSize);
  final color = resolveExtensionColor(control['color'] as String?);
  return color == null
      ? icon
      : CircleAvatar(radius: avatarRadius, backgroundColor: color.withValues(alpha: 0.6), child: icon);
}
