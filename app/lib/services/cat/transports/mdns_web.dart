// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'mdns_codec.dart';

export 'mdns_codec.dart' show MdnsService, isMdnsHost;

Stream<MdnsService> mdnsBrowse(String serviceType) => const Stream.empty();
