// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Web fallback. Unlike the TCP stub this does NOT throw: discovery is
// optional by nature, and a caller that asks "did anything announce
// itself?" on a platform where nothing can is not a bug. An empty stream is
// the honest answer, and the Station Configuration section is hidden on web
// anyway.

import 'dart:typed_data';

Stream<Uint8List> udpBroadcastDatagrams({required int port}) => const Stream.empty();
