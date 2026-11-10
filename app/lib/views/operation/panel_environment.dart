// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

/// All dimensions are the panel's logical coordinates, already inside UiScale.
/// Scaled font sizes describe the OS text scaler; scene Text applies it itself.
///
/// Reads MediaQuery one ASPECT at a time, never `MediaQuery.of`: this runs in
/// the build of every mounted extension panel, and depending on the whole
/// query would rebuild each of them on every frame of a keyboard inset
/// animation — the typing path extension_panel.dart keeps panels off.
Map<String, dynamic> panelEnvironment(BuildContext context, Size size) {
  final theme = Theme.of(context);
  final textScaler = MediaQuery.textScalerOf(context);
  final safe = PaneSafeArea.paddingOf(context);
  String rgb(Color c) => '#${(c.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0')}';
  Map<String, dynamic> type(TextStyle? style) {
    final s = style ?? const TextStyle(fontSize: 14);
    final fontSize = s.fontSize ?? 14;
    return {
      'fontFamily': s.fontFamily,
      'fontFamilyFallback': s.fontFamilyFallback ?? <String>[],
      'fontSize': fontSize,
      'scaledFontSize': textScaler.scale(fontSize),
      'fontWeight': (s.fontWeight ?? FontWeight.w400).value,
      'lineHeight': s.height ?? 1.2,
      'letterSpacing': s.letterSpacing ?? 0,
    };
  }

  return {
    'version': 1,
    'width': size.width.isFinite ? size.width : MediaQuery.sizeOf(context).width,
    'height': size.height.isFinite ? size.height : MediaQuery.sizeOf(context).height,
    'safeInsets': {'left': safe.left, 'top': safe.top, 'right': safe.right, 'bottom': safe.bottom},
    'brightness': theme.brightness.name,
    'colors': {for (final role in panelColorRoles) role: rgb(panelColorRole(context, role)!)},
    'typography': {for (final role in panelTextRoles) role: type(panelTextRole(context, role))},
    'locale': Localizations.localeOf(context).toLanguageTag(),
    'textDirection': Directionality.of(context).name,
    'devicePixelRatio': MediaQuery.devicePixelRatioOf(context),
    'reducedMotion': MediaQuery.disableAnimationsOf(context),
    'highContrast': MediaQuery.highContrastOf(context),
  };
}

/// The color behind each role the environment names, so a scene that styles a
/// grid by role is painted in the color the extension was told. One table: a
/// role advertised is a role a scene may name.
final Map<String, Color Function(BuildContext)> _colorRoles = {
  'surface': (context) => Theme.of(context).colorScheme.surface,
  'surfaceContainer': (context) => Theme.of(context).colorScheme.surfaceContainer,
  'onSurface': (context) => Theme.of(context).colorScheme.onSurface,
  'onSurfaceVariant': (context) => Theme.of(context).colorScheme.onSurfaceVariant,
  'accent': (context) => HaLoColors.of(context).onSurfaceAccent,
  'primary': (context) => Theme.of(context).colorScheme.primary,
  'onPrimary': (context) => Theme.of(context).colorScheme.onPrimary,
  'secondary': (context) => Theme.of(context).colorScheme.secondary,
  'outline': (context) => Theme.of(context).colorScheme.outline,
  'outlineVariant': (context) => Theme.of(context).colorScheme.outlineVariant,
  'error': (context) => Theme.of(context).colorScheme.error,
  'onError': (context) => Theme.of(context).colorScheme.onError,
};

final panelColorRoles = List<String>.unmodifiable(_colorRoles.keys);

/// The theme's color for [role], or null for a name that is not one.
Color? panelColorRole(BuildContext context, String role) => _colorRoles[role]?.call(context);

/// The style behind each typography role the environment describes, so a
/// scene's `nativeText` in a role is drawn in the style the extension was told.
/// One table: a role advertised is a role `nativeText` accepts.
final Map<String, TextStyle? Function(BuildContext)> _textRoles = {
  'body': (context) => Theme.of(context).textTheme.bodyMedium,
  'label': (context) => Theme.of(context).textTheme.labelSmall,
  'title': (context) => Theme.of(context).textTheme.titleMedium,
  'display': (context) => Theme.of(context).textTheme.displaySmall,
  'mono': haloMonoStyle,
};

final panelTextRoles = List<String>.unmodifiable(_textRoles.keys);

TextStyle? panelTextRole(BuildContext context, String role) => (_textRoles[role] ?? _textRoles['body']!)(context);
