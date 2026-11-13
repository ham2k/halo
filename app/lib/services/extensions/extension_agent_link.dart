// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The agent link's endpoint (docs/design/agent-link.md): the app's own `mcp`
// extension, reached through its `agentLink` hook and no other extension's.

part of 'extension_service.dart';

/// The key the agent link delivers to.
const kAgentLinkEndpointKey = 'mcp';

mixin _ExtensionAgentLink implements AgentLinkEndpoint {
  ExtensionHost? get host;
  List<ExtensionInfo> get availableExtensions;
  Set<String> get _loadedExtensionKeys;

  final _agentLinkNews = _Pulse();

  /// Pulsed after the endpoint's own assistant has observed something: the
  /// only moment its events can change.
  @override
  Listenable get news => _agentLinkNews;

  void noteAgentLinkObserved(String hookKey) {
    if (hookKey == kAgentLinkEndpointKey) _agentLinkNews.pulse();
  }

  /// The endpoint is the bundle the app ships under [kAgentLinkEndpointKey],
  /// never one installed: an installed bundle cannot take a built-in key,
  /// and the source is checked as well so that stays true here whatever
  /// changes about installs. It must also be loaded: one switched off,
  /// gated, or still starting would leave an allowed app with nothing but
  /// errors, where `unavailable` tells it to try again.
  @override
  bool get available =>
      host != null &&
      _loadedExtensionKeys.contains(kAgentLinkEndpointKey) &&
      availableExtensions.any((info) => info.key == kAgentLinkEndpointKey && info.source == ExtensionSource.asset);

  @override
  Future<List<Map<String, dynamic>>> handle({
    required String connection,
    required AgentClient client,
    required AgentAccess access,
    required Map<String, dynamic> message,
  }) async {
    final host = this.host;
    if (host == null || !available) throw ExtensionHostException('the agent link endpoint is not running');
    final result = await host.invoke(
      Hooks.agentLinkHandle,
      key: kAgentLinkEndpointKey,
      args: {'connection': connection, 'client': client.toJson(), 'access': access.name, 'message': message},
      // Room for a tool that waits on the operator's activity before it
      // answers; the endpoint keeps its own waits under this.
      timeout: const Duration(seconds: 60),
    );
    // Thrown rather than read as "no replies": the link answers a failed
    // request with an error, and an empty list would leave it unanswered.
    if (result is! List || result.any((reply) => reply is! Map)) throw ExtensionHostException('the agent link endpoint answered ${result.runtimeType}');
    return [for (final reply in result) (reply as Map).cast<String, dynamic>()];
  }
}

class _Pulse extends ChangeNotifier {
  void pulse() => notifyListeners();
}
