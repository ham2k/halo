// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// How a connect/disconnect toggle draws its state, wherever it sits: the
// station rows' plug, and a form band's icon action.

import 'package:flutter/material.dart';

/// One green that reads on both a light and a dark surface. Spelled out
/// because the scheme has no semantic "success" colour, and `primary` is the
/// app's accent — it says nothing about being connected.
Color connectedGreen(ThemeData theme) => theme.brightness == Brightness.dark ? Colors.green.shade600 : Colors.green.shade700;

/// What a connection toggle shows while a connect or disconnect is under
/// way, in place of the button — a tap then could only queue a second
/// change behind the first. The box is an IconButton's, so the band or row
/// it sits in keeps its height.
class ConnectionBusySpinner extends StatelessWidget {
  const ConnectionBusySpinner({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 48,
    height: 48,
    child: Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2)),
  );
}
