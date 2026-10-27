// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

/// No OS errors without dart:io: a browser reports its failures as
/// exceptions of its own, which the web transports describe themselves.
String? osErrorDetail(Object error) => null;
