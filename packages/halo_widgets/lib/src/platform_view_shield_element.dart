// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/widgets.dart';

/// Nothing to block anywhere but the web — see platform_view_shield.dart.
Widget platformViewBlocker() => const SizedBox.expand(key: ValueKey('platform-view-blocker'));
