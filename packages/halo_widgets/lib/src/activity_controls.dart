// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Looks up an `operationControls`/`activityControls` entry (icon, pattern,
// …) for a ref/suggestion type — shared between ActivitiesView,
// OperationLocationScreen and QsoList, which all render refs/suggestions
// using the same active-extension controls list.

import 'package:flutter/material.dart';

import 'icon_resolver.dart';
import 'mdi_icons.g.dart';

/// The controls entry for [refType], or null for a type with no active
/// control.
///
/// A null or empty [refType] matches nothing, whatever the controls hold.
/// The match below is equality, so without this a null would be answered by
/// the first control that declares no `input.refType` of its own — and every
/// caller passes a nullable type read out of extension JSON, meaning a ref
/// or an export that claims NO activity would be branded with that
/// extension's icon and accent.
Map<String, dynamic>? controlForRefType(List<Map<String, dynamic>> controls, String? refType) =>
    controlForRef(controls, type: refType);

/// The control that handles the reference [type]/[code], most precise first.
///
/// A control's `refType` is the type it publishes and answers for outright.
/// `alsoHandles` is how it reaches back for references filed under a type it
/// does not publish: `['qp/ny']` on the New York QSO Party answers
/// `{type: 'qp', ref: 'NY'}` — an operation logged when fifty parties were one
/// extension, which nothing rewrites and nobody should have to re-enter.
///
/// The longest matching prefix wins, so the party that named the reference
/// beats the bundled extension that merely contains it, and neither has to
/// know the other exists. The claims are the same strings the manifest's
/// `hooks` declare, without the `ref:` — the two are read by different layers
/// and must not drift into two vocabularies.
///
/// [code] is the reference's own code and may be null; a claim with a prefix
/// then matches nothing, because there is nothing for the prefix to begin.
Map<String, dynamic>? controlForRef(
  List<Map<String, dynamic>> controls, {
  required String? type,
  String? code,
}) {
  if (type == null || type.isEmpty) return null;
  final folded = code?.toLowerCase();
  Map<String, dynamic>? best;
  var bestStrength = -1;
  for (final control in controls) {
    final input = control['input'] as Map?;
    if (input == null) continue;
    if (input['refType'] == type && bestStrength < 0) {
      best = control;
      bestStrength = 0;
    }
    // Read defensively: `alsoHandles` is extension JSON, and a malformed
    // entry is one claim that does not match rather than a screen that fails.
    for (final claim in (input['alsoHandles'] as List?) ?? const []) {
      if (claim is! String) continue;
      final slash = claim.indexOf('/');
      if (slash <= 0 || slash == claim.length - 1) continue;
      if (claim.substring(0, slash) != type) continue;
      final prefix = claim.substring(slash + 1).toLowerCase();
      if (folded == null || !folded.startsWith(prefix)) continue;
      if (prefix.length > bestStrength) {
        best = control;
        bestStrength = prefix.length;
      }
    }
  }
  return best;
}

/// Icon name for [refType], falling back to a generic marker (via
/// `resolveIconName`) for a type with no active control.
///
/// [code] where the caller holds the whole reference: without it a control
/// that answers for this reference under a legacy type is not found, and the
/// row an extension is handling perfectly well draws the unknown-type marker.
String? iconForRefType(List<Map<String, dynamic>> controls, String? refType, {String? code}) =>
    controlForRef(controls, type: refType, code: code)?['icon'] as String?;

/// The control's declared accent color for [refType], or null when it has
/// none (see `resolveExtensionColor`).
Color? colorForRefType(List<Map<String, dynamic>> controls, String? refType, {String? code}) =>
    resolveExtensionColor(controlForRef(controls, type: refType, code: code)?['color'] as String?);

/// Whether [refType] doesn't match any currently active control — its
/// extension isn't installed/loaded/enabled right now. A null [refType]
/// (no control ever declares one) counts as unknown too.
bool isUnknownRefType(List<Map<String, dynamic>> controls, String? refType, {String? code}) =>
    controlForRef(controls, type: refType, code: code) == null;

/// A reference's own code, where it has one that is readable.
///
/// Operation refs are JSON written by extensions and by app-polo, so a `ref`
/// that is a number is not this reader's to throw over — it is a reference no
/// prefix claim matches, which is the same answer as none.
String? refCodeOf(Map<String, dynamic> ref) => ref['ref'] is String ? ref['ref'] as String : null;

/// [existing] updated with what a setup form returned, under the type the ref
/// should end up carrying.
///
/// An edited ref keeps its OWN type; only a new one takes [refType] from the
/// control that produced the form. A control answering for a legacy reference
/// (`alsoHandles`) would otherwise retype the operation the first time its
/// setup form was opened — the log editing itself, which claiming a reference
/// rather than rewriting it exists to avoid.
///
/// The type is applied last, so a form field that happens to be named `type`
/// cannot decide what the reference IS.
Map<String, dynamic> refWithFormResult(
  Map<String, dynamic>? existing,
  Map<String, dynamic> result, {
  required String refType,
}) =>
    {...?existing, ...result, 'type': existing?['type'] ?? refType};

/// The references among [refs] that no control in [controls] handles, as the
/// type and code pair an extension's manifest claim is matched against.
///
/// Both are read defensively: operation refs are JSON written by extensions
/// and by app-polo, so a `ref` that is a number is not this reader's to throw
/// over — every caller here is deciding what to OFFER, and offering nothing
/// beats taking the screen down with it.
List<({String type, String? code})> unhandledRefsIn(
  List<Map<String, dynamic>> refs,
  List<Map<String, dynamic>> controls,
) =>
    [
      for (final ref in refs)
        if (ref['type'] is String)
          if (controlForRef(controls, type: ref['type'] as String, code: refCodeOf(ref)) == null)
            (type: ref['type'] as String, code: refCodeOf(ref)),
    ];

/// The icon for a ref/suggestion of [refType]: the matching control's own
/// icon, tinted with its declared accent color if any — or, when it matches
/// no active control, a pale-red circle with a question-mark, so a ref from
/// an extension that's no longer installed/loaded degrades visibly instead
/// of silently showing a generic marker. Shared by every place that lists
/// refs against the current controls (ActivitiesView,
/// OperationLocationScreen, QsoList). [iconSize]/[avatarRadius] default to
/// the ambient Icon/CircleAvatar sizes (a ListTile's `leading` slot) for the
/// known-type icon — the question-mark itself defaults to 16 regardless,
/// overridable for a more compact inline usage (e.g. QsoList's per-row
/// count).
Widget activityRefIcon(
  List<Map<String, dynamic>> controls,
  String? refType, {
  String? code,
  double? iconSize,
  double? avatarRadius,
}) {
  final control = controlForRef(controls, type: refType, code: code);
  if (control == null) {
    return CircleAvatar(
      radius: avatarRadius,
      backgroundColor: Colors.red,
      child: Icon(MdiIcons.help, color: Colors.white, size: iconSize ?? 16),
    );
  }
  final icon = Icon(resolveIconName(control['icon'] as String?), size: iconSize);
  final color = resolveExtensionColor(control['color'] as String?);
  return color == null
      ? icon
      : CircleAvatar(radius: avatarRadius, backgroundColor: color.withValues(alpha: 0.6), child: icon);
}
