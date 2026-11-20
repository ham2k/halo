// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

part of 'chase_view.dart';

mixin _ChaseKeying on State<ChaseView>, LoggingViewKeying<ChaseView> {
  @override
  bool get keyingVisible => widget.visible;

  @override
  bool canFinishCwKeying(String radio) => keyingInFront && radio == keyingRadio && !keyingPhone && keyingSuperMode != 'Digital';

  @override
  String get keyingRadio => _keyingRadio;
  String _keyingRadio = 'A';

  Map<String, dynamic>? _keyerLabelDraft;
  Timer? _keyerLabelDebounce;

  void _onKeyingDraftChanged(String radio, Map<String, dynamic> qso) {
    final before = keyingSuperMode;
    final switchedRadio = _keyingRadio != radio;
    _keyingRadio = radio;
    latestKeyingDraft = qso;
    _keyerLabelDebounce?.cancel();
    if (switchedRadio || before != keyingSuperMode) {
      setState(() => _keyerLabelDraft = qso);
    } else {
      _keyerLabelDebounce = Timer(panelRenderThrottle, () => setState(() => _keyerLabelDraft = qso));
    }
  }

  @override
  void dispose() {
    _keyerLabelDebounce?.cancel();
    super.dispose();
  }
}
