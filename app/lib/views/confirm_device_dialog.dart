// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Settings "Confirm a device" dialog: the APPROVING side of Ham2K Log
// Filer client linking, where switch_accounts_dialog.dart is the requesting
// side. Another device (PoLo on a phone, a second HaLo install) asks to join
// this account and shows a challenge code or a QR link; this pane finds that
// request and grants it, which is what actually moves the other device onto
// the account.
//
// Two ways in, both landing on the same confirmation:
//  - Code: the six characters the other device displays, looked up with
//    `GET v1/accounts/…/permissions?challenge_token=…`.
//  - Deep link: `com.ham2k:///link_client?id=…&token=…` from that device's
//    QR code, which names the requesting client outright. HaLo never scans
//    a QR itself — it has no camera on the platforms it mostly runs on —
//    so the link arrives from the OS, opened by a phone's camera app or
//    pasted.
//
// Approving is deliberately a two-step read-then-confirm: the operator is
// granting a stranger's device access to their whole log, and the device's
// name is the only thing they have to check it against.

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../i18n/strings.g.dart';

/// A Modal Pane (docs/design/layouts.md). Returns true once a device has
/// been linked, so the caller can refresh whatever shows the account.
Future<bool?> showConfirmDeviceDialog(
  BuildContext context, {
  required Future<Map<String, dynamic>?> Function(String challengeToken) findByCode,
  required Future<Map<String, dynamic>?> Function({required String clientUuid, required String challengeToken})
      findByClient,
  required Future<Map<String, dynamic>?> Function({required String clientUuid, String? challengeToken}) approve,
  String? clientUuid,
  String? challengeToken,
}) {
  return showModalPane<bool>(
    context,
    title: context.t.confirmDevice.title,
    closeLabel: context.t.common.close,
    builder: (context) => ConfirmDevicePane(
      findByCode: findByCode,
      findByClient: findByClient,
      approve: approve,
      clientUuid: clientUuid,
      challengeToken: challengeToken,
    ),
  );
}

class ConfirmDevicePane extends StatefulWidget {
  final Future<Map<String, dynamic>?> Function(String challengeToken) findByCode;
  final Future<Map<String, dynamic>?> Function({required String clientUuid, required String challengeToken})
      findByClient;
  final Future<Map<String, dynamic>?> Function({required String clientUuid, String? challengeToken}) approve;

  /// Set together when the pane opens from a `link_client` deep link: the
  /// request is already identified, so the code step is skipped.
  final String? clientUuid;
  final String? challengeToken;

  const ConfirmDevicePane({
    super.key,
    required this.findByCode,
    required this.findByClient,
    required this.approve,
    this.clientUuid,
    this.challengeToken,
  });

  @override
  State<ConfirmDevicePane> createState() => _ConfirmDevicePaneState();
}

class _ConfirmDevicePaneState extends State<ConfirmDevicePane> {
  final _codeController = TextEditingController();
  bool _busy = false;
  String? _error;

  /// The pending permission found by code or deep link — non-null exactly
  /// when the pane is on its confirmation step.
  Map<String, dynamic>? _request;

  /// Carried through to [approve]: for a permission created blank (the QR
  /// flow), the token is what attaches it to this account, so approving
  /// without it fails with "Permission not found".
  String? _tokenForApproval;

  @override
  void initState() {
    super.initState();
    final clientUuid = widget.clientUuid, challengeToken = widget.challengeToken;
    if (clientUuid != null && challengeToken != null) _lookUpByClient(clientUuid, challengeToken);
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  /// Shared handling of a server reply: null is a dead server, an `error`
  /// key is the server declining. Returns the map only when it's usable.
  Map<String, dynamic>? _usableResult(Map<String, dynamic>? result) {
    if (result == null) {
      _error = t.switchAccounts.serverUnreachable;
      return null;
    }
    if (result['error'] != null) {
      _error = '${result['error']}';
      return null;
    }
    return result;
  }

  Future<void> _lookUpByClient(String clientUuid, String challengeToken) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = _usableResult(await widget.findByClient(clientUuid: clientUuid, challengeToken: challengeToken));
    if (!mounted) return;
    final permission = (result?['permission'] as Map?)?.cast<String, dynamic>();
    setState(() {
      _busy = false;
      // A link whose challenge has aged out comes back as a successful
      // response with no permission in it, not as an error.
      if (result != null && permission == null) _error = t.confirmDevice.linkExpired;
      _request = permission;
      _tokenForApproval = challengeToken;
    });
  }

  Future<void> _lookUpByCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = _usableResult(await widget.findByCode(code));
    if (!mounted) return;
    final permissions = (result?['permissions'] as List?) ?? const [];
    final permission = permissions.whereType<Map>().firstOrNull?.cast<String, dynamic>();
    setState(() {
      _busy = false;
      if (result != null && permission == null) _error = t.confirmDevice.codeNotFound;
      _request = permission;
      // A permission the server matched by code is already raised against
      // this account; only the blank QR kind needs its token echoed back.
      _tokenForApproval = null;
    });
  }

  Future<void> _approve() async {
    // Only the permission on screen — never widget.clientUuid as a
    // fallback. After a failed deep-link lookup the operator can type a
    // code instead, and pairing THAT permission with the deep link's client
    // would approve a device they were never shown.
    final clientUuid = _request?['client'] as String?;
    if (clientUuid == null) {
      // A reply the client can't read is not a reason to leave a button
      // that quietly does nothing.
      setState(() {
        _error = t.confirmDevice.malformedRequest;
        _request = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = _usableResult(await widget.approve(clientUuid: clientUuid, challengeToken: _tokenForApproval));
    if (!mounted) return;
    final permission = (result?['permission'] as Map?)?.cast<String, dynamic>();
    if (permission?['status'] == 'active') {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      // Only a server that actually ANSWERED tells us the request is gone.
      // Discarding it because the network blinked would strand the deep-link
      // arrival for good: there is no code to retype, and the empty field's
      // Look Up does nothing — a transient socket error would cost a trip
      // back to the other device for a fresh QR.
      if (result == null) return;
      _error = t.confirmDevice.codeNotFound;
      _request = null;
    });
  }

  void _cancel() => Navigator.of(context).pop(false);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_request != null) _buildConfirmation(context) else _buildCodeEntry(context),
        if (_error != null) ...[
          const SizedBox(height: Space.lg),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (_busy) ...[const SizedBox(height: Space.lg), const Center(child: CircularProgressIndicator())],
        const SizedBox(height: Space.xxl),
        OverflowBar(
          alignment: MainAxisAlignment.end,
          spacing: 8,
          children: [
            TextButton(onPressed: _cancel, child: Text(context.t.common.cancel)),
            if (_request != null)
              FilledButton(onPressed: _busy ? null : _approve, child: Text(context.t.confirmDevice.linkIt))
            else
              FilledButton(onPressed: _busy ? null : _lookUpByCode, child: Text(context.t.confirmDevice.lookUp)),
          ],
        ),
      ],
    );
  }

  Widget _buildCodeEntry(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t.confirmDevice.codePrompt),
        const SizedBox(height: Space.lg),
        TextField(
          selectAllOnFocus: false,
          controller: _codeController,
          autofocus: true,
          enabled: !_busy,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(fontFamily: 'RobotoMono', letterSpacing: 4),
          decoration: InputDecoration(
            labelText: context.t.confirmDevice.code,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _lookUpByCode(),
        ),
      ],
    );
  }

  Widget _buildConfirmation(BuildContext context) {
    final device = _request?['client_name'] as String?;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.t.confirmDevice.areYouSure(device: device ?? context.t.confirmDevice.unnamedDevice),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: Space.lg),
        Text(context.t.confirmDevice.grantWarning),
      ],
    );
  }
}
