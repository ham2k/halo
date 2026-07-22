// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Non-web fallback: there's no window.location off the web, so a native build
// never has a preview URL to derive a DEV_LABEL from.

String webPreviewLabel() => '';
