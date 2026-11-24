// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

/// A host action declined with a message the operator can act on.
class SceneEventRefusal implements Exception {
  final String message;

  const SceneEventRefusal(this.message);
}
