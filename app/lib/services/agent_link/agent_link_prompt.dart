// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Raises "Allow this agent app?" wherever the operator is. An agent app
// connects while they are logging, and waits on the answer: without this the
// app's first call would hang until it gave up.

import 'dart:async';

import '../../config/navigation.dart';
import '../../views/agent_link_dialog.dart';
import '../error_reporting_service.dart';
import 'agent_link_model.dart';
import 'agent_link_service.dart';

/// Raises the question for each app [link] asks about.
void listenForAgentLinkRequests(AgentLinkService link) {
  link.addListener(() => _prompt(link));
  _prompt(link);
}

/// The request a dialog is showing, so the link's own notifications — one per
/// connection that comes and goes — cannot stack a second dialog over it.
AgentLinkRequest? _showing;

void _prompt(AgentLinkService link) {
  final request = link.pendingRequest;
  if (request == null || _showing != null) return;
  final context = navigatorKey.currentContext;
  if (context == null) {
    // The first frame may still be building when an app connects at launch.
    // The question waits for an answer however long that takes, so this
    // keeps trying while it is pending.
    Timer(const Duration(milliseconds: 250), () => _prompt(link));
    return;
  }
  _showing = request;
  void failed(Object e, StackTrace st) {
    // Not an answer: the question stays, and is raised again shortly. Once
    // per streak to the error report, which a dialog that cannot open would
    // otherwise fill.
    _showing = null;
    ErrorReportingService.reportIfRepeated('agentLink:prompt', e, st, context: 'AgentLink:prompt', threshold: 1);
    Timer(const Duration(seconds: 5), () => _prompt(link));
  }

  final Future<AgentAccess?> answered;
  try {
    answered = showAgentLinkDialog(context, client: request.client, waiting: request.waiting, withdrawn: request.withdrawn);
  } catch (e, st) {
    failed(e, st);
    return;
  }
  unawaited(
    answered.then((access) {
      ErrorReportingService.recordSuccess('agentLink:prompt');
      _showing = null;
      unawaited(link.answer(request, access));
      // The next app waiting, if one is.
      _prompt(link);
    }, onError: failed),
  );
}
