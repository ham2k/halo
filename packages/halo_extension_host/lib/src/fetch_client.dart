// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The guarded `host.fetch` transport where the platform offers no resolver:
// a browser decides where a name goes, so the spelling rule in
// fetch_policy.dart is the whole local-network rule on web.

import 'package:http/http.dart' as http;

/// The client for a hop that may not reach the local network. On web that is
/// the browser's own client, which reads the local-network rule only as the
/// host applied it to the spelling of the name.
http.Client guardedFetchClient() => http.Client();
