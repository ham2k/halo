// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

/// One connected command, as frames.
abstract interface class AgentLinkPeer {
  /// Each line it sends, without the newline. Ends when it hangs up, when
  /// [close] is called, or when a line runs past the frame limit.
  Stream<String> get lines;

  /// Completes once the connection is gone, whichever side ended it.
  Future<void> get done;

  /// Sends one frame. Ignored once the connection is gone.
  void send(String line);

  /// Hangs up, after what is already queued.
  Future<void> close();
}

/// A listening link.
abstract interface class AgentLinkListener {
  int get port;
  Future<void> close();
}
