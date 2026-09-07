// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The app's one Navigator, for the code that opens UI without a BuildContext
// of its own: deep links, notices, prompts raised from a service event. Null
// until the first frame, so a caller that can arrive earlier retries rather
// than drops (services/deep_link_router.dart).

import 'package:flutter/material.dart';

final navigatorKey = GlobalKey<NavigatorState>();
