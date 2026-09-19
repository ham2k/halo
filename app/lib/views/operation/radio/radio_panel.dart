// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One radio's front panel: what frequency it is on, in what mode, at what
// power — and, when it is not connected, a power button to bring it up.
//
// The readings come from CatService, which is the only writer of CAT-sourced
// state (docs/design/cat.md). This pane reads and never writes them: tuning
// is the logging panel's job, and the one control here that DOES reach the
// radio is the power button.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart'
    show NumberFormatting, fmtFreqToTheHz, freqDisplayParts, groupDigits;
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../../../services/cat/cat_service.dart';
import '../../../services/cat/equipment.dart';
import '../../../services/halo_services.dart';
import '../../../settings/settings_target_dialog.dart';
import '../clock/clock_faces.dart' show lcdPalette;
import 'radio_faces.dart';

/// The panel id the views register this pane under, and the descriptor half
/// of every placement id (`radio#1`). Shared rather than spelled twice: the
/// dock matches placements against it, and a rename that reached only the
/// registration would route every radio pane to the missing-panel fallback.
const String radioPanelId = 'radio';

/// Config keys, shared with the descriptor that declares the form.
const String radioNodeKey = 'radio';
const String radioStyleKey = 'style';

/// [radioNodeKey]'s value for "whichever radio is driving VFO A" — the
/// default, and a deliberately non-uuid string so it can never collide with
/// a node's own id.
///
/// Stored as a pointer rather than resolved at pick time: an operator who
/// chose Automatic means "follow the designated radio", so re-designating in
/// Station Configuration has to move this pane too. Writing the uuid at pick
/// time would freeze it to whatever was designated that afternoon.
const String radioNodeAuto = 'auto';

const String radioStyleLcd = 'lcd';
const String radioStyleModern = 'modern';

/// How far a disconnected readout fades. Low enough to read as off, high
/// enough that the frequency the radio was last on is still legible — which
/// is what makes the dimmed state informative rather than merely blank.
const double _dimmedAlpha = 0.40;

/// The height of the mode/power row above the frequency.
///
/// A plain logical-pixel size, like every other dimension here: the Font
/// Scale setting scales the whole UI from one root wrapper, so multiplying
/// this by it would scale it twice (docs/design/ui-scaling.md).
const double _annunciatorHeight = 22;

/// The height of the meter strip below the frequency.
///
/// Reserved whenever the radio's driver reads meters at all, empty or not,
/// and that is deliberate: the strip fills the moment the operator keys the
/// rig, and a row that APPEARED then would shove the frequency up the pane
/// at the exact moment they are watching it. A driver that reads no meters
/// declares none and gives the height back.
const double _meterStripHeight = 18;

/// The lit height of a meter bar inside that strip — shorter than the row,
/// so the segments sit on the text's own baseline band rather than towering
/// over the digits beside them.
const double _meterBarHeight = 9;

/// The top of the SWR bar's scale, as a rig's own meter face draws it: 1.0
/// to 3.0, with the red zone starting at [swrAlertThreshold]. A reading past
/// it pins the bar full and is still spelled out in the number beside it.
const double _swrFullScale = 3.0;

class RadioPanel extends StatefulWidget {
  /// The PLACEMENT's id (`radio#1`), never the descriptor's — it is the key
  /// this pane's config is stored under, so two panes handed the same one
  /// would share a radio.
  final String panelId;

  final HaLoServices services;

  /// Names the tab after the radio, so two of these are told apart.
  final ValueChanged<String?>? onTitle;

  const RadioPanel({
    super.key,
    required this.panelId,
    required this.services,
    this.onTitle,
  });

  @override
  State<RadioPanel> createState() => _RadioPanelState();
}

class _RadioPanelState extends State<RadioPanel> {
  Map<String, dynamic> _config = const {};
  int _configRevision = 0;

  /// Whether a config load has ever landed. Separate from [_configRevision]
  /// because a revision of 0 means both "never edited" and "never read": the
  /// descriptor can be absent when this pane mounts — the CAT experiment is
  /// what registers it, and a view registers from `didChangeDependencies` —
  /// and without this the load would be abandoned, the revision would still
  /// match on every later notification, and the operator's saved radio would
  /// be discarded for the life of the pane with nothing on screen to say so.
  bool _configLoaded = false;

  /// Counts load passes so a slower one cannot install its answer over a
  /// newer one's. `configFor` is a per-field async read, so two edits in
  /// quick succession otherwise race and the loser's values stand — the same
  /// hazard [PanelService] carries `_refreshSeq` for.
  int _loadSeq = 0;

  /// What was last handed to [RadioPanel.onTitle], so a rebuild that did not
  /// change the radio does not reach into the VIEW's state to say so.
  String? _announcedTitle;

  CatService get _cat => widget.services.cat;

  @override
  void initState() {
    super.initState();
    widget.services.panels.addListener(_onCatalogChanged);
    // The title follows the NODE, which the build resolves fresh from
    // CatService on every notification — a rename, a re-designation of VFO A,
    // or a removal all change what this pane shows without touching its
    // config. Announcing only from the config load leaves the tab naming a
    // radio the pane stopped showing, which on a live frequency readout is
    // the worst label to get wrong.
    _cat.addListener(_onEquipmentChanged);
    _configRevision = widget.services.panels.configRevision(widget.panelId);
    unawaited(_loadConfig());
  }

  @override
  void didUpdateWidget(RadioPanel old) {
    super.didUpdateWidget(old);
    if (old.services != widget.services) {
      old.services.panels.removeListener(_onCatalogChanged);
      old.services.cat.removeListener(_onEquipmentChanged);
      widget.services.panels.addListener(_onCatalogChanged);
      widget.services.cat.addListener(_onEquipmentChanged);
    }
    if (old.panelId != widget.panelId) {
      _configRevision = widget.services.panels.configRevision(widget.panelId);
      _configLoaded = false;
      unawaited(_loadConfig());
    }
  }

  /// This pane's own config was edited, or the descriptor it was waiting for
  /// has appeared. Nothing else would tell it — the form is host-persisted
  /// and the catalog is the only thing that notices.
  void _onCatalogChanged() {
    final revision = widget.services.panels.configRevision(widget.panelId);
    if (revision == _configRevision && _configLoaded) return;
    _configRevision = revision;
    unawaited(_loadConfig());
  }

  void _onEquipmentChanged() {
    if (mounted) _announceTitle();
  }

  Future<void> _loadConfig() async {
    final panel = widget.services.panels[widget.panelId];
    // Not loaded, so a later registration retries rather than leaving the
    // pane on defaults that look like the operator's own choices.
    if (panel == null) return;
    final seq = ++_loadSeq;
    final config = await widget.services.panels.configFor(panel);
    if (!mounted || seq != _loadSeq) return;
    setState(() {
      _config = config;
      _configLoaded = true;
    });
    _announceTitle();
  }

  /// After a setState or from a listener, never from build: this reaches the
  /// VIEW's state, which setStates in turn.
  void _announceTitle() {
    final onTitle = widget.onTitle;
    if (onTitle == null) return;
    final node = _selectedNode();
    final title = node == null ? null : _cat.displayNameFor(node);
    if (title == _announcedTitle) return;
    _announcedTitle = title;
    onTitle(title);
  }

  /// The node this pane is showing, or null when there is none to show — no
  /// radio designated under Automatic, or a pinned radio that has since been
  /// removed from the station's inventory.
  EquipmentNode? _selectedNode() {
    // Read defensively, like [_style]: this runs from `build`, so a stored
    // value of the wrong type — a corrupt record, a key another writer got
    // to — would otherwise throw a TypeError out of a frame over one bad
    // settings entry.
    final stored = _config[radioNodeKey];
    final uuid = stored is! String || stored == radioNodeAuto
        // The LOCAL rig: this panel is a front panel for a session this
        // device holds, which a peer's radio is not.
        ? switch (_cat.radio1) { LocalRadio(:final uuid) => uuid, _ => null }
        : stored;
    if (uuid == null) return null;
    return _cat.nodeFor(uuid);
  }

  String get _style {
    final stored = _config[radioStyleKey];
    if (stored == null) return radioStyleLcd;
    return const {radioStyleLcd, radioStyleModern}.contains(stored) ? stored as String : radioStyleLcd;
  }

  @override
  void dispose() {
    widget.services.panels.removeListener(_onCatalogChanged);
    _cat.removeListener(_onEquipmentChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // CatService alone: every reading, the node list and the designation come
    // from it, and nothing else on this pane is read from a setting.
    return ListenableBuilder(
      listenable: _cat,
      builder: (context, _) {
        final node = _selectedNode();
        final state = node == null ? const EquipmentState() : _cat.stateFor(node.uuid);
        final palette = radioPaletteFor(context, _style);
        // Stale counts as not connected here, deliberately: a session whose
        // readings have stopped is showing a frequency from minutes ago, and
        // a confident lit display over a dead stream is exactly the failure
        // cat.md records having shipped once already.
        final live = state.status == EquipmentStatus.connected && !state.stale;

        final content = Padding(
          padding: EdgeInsets.all(Space.md).add(PaneSafeArea.paddingOf(context)),
          child: RadioReadout(
            node: node,
            state: state,
            live: live,
            style: _style,
            palette: live ? palette : palette.dimmed(_dimmedAlpha),
            // Only what the radio itself reported, and only while that
            // reading means anything. [CatService.displayedPower] would fall
            // back to the operator's manual Power setting, which is a
            // station-wide number the rig never gave — printing it in the
            // slot reserved for a measurement, on a pane whose whole premise
            // is what THIS radio is doing, is the invented reading to avoid.
            power: live ? state.power : null,
            // From the DRIVER rather than from what has arrived: the strip
            // reserves its slots before the radio has ever been keyed, so
            // the first transmission fills them instead of creating them.
            // The NODE's meters, not the driver's: a Yaesu shows what its
            // calibration file describes, and the generic Yaesu entry —
            // which does not know which radio is behind it — describes
            // nothing. Asked of the merged config so the entry's own
            // overrides are in it.
            meters: node == null
                ? const {}
                : (_cat.typeFor(node)?.telemetryMetersFor(node.config) ?? const {}),
            // The dialog governs the VFO the app FOLLOWS
            // (core_settings_groups.dart), so it is only this pane's to open
            // when this pane is showing that radio. On a second-rig pane it
            // would silently open settings for a different radio.
            onTune: node != null && _cat.isRadio1(node.uuid) ? () => _openTuneDialog(context) : null,
            powerButton: node == null
                ? null
                : RadioPowerButton(
                    status: state.status,
                    accent: palette.ink,
                    palette: palette,
                    style: _style,
                    height: _annunciatorHeight,
                    onPressed: () => _togglePower(node, state),
                  ),
          ),
        );

        // Only the LCD's glass fills the whole pane — it IS the pane's
        // background. The Modern face has none of its own and sits on the
        // dock's surface like every other panel.
        return _style == radioStyleLcd ? ColoredBox(color: palette.face, child: content) : content;
      },
    );
  }

  /// Connected radios go down, everything else comes up.
  ///
  /// `connecting` and `disconnecting` are not cases here because the button
  /// is disabled throughout both (see [RadioPowerButton]) — a branch for them
  /// would be unreachable code claiming to handle a state it never sees.
  void _togglePower(EquipmentNode node, EquipmentState state) {
    if (state.status == EquipmentStatus.connected) {
      unawaited(_cat.disconnect(node.uuid));
    } else {
      unawaited(_cat.connect(node.uuid));
    }
  }

  void _openTuneDialog(BuildContext context) => showSettingsForTarget(
        context,
        services: widget.services,
        target: 'current-radio',
        title: t.settings.station.currentRadioSettings,
      );
}

/// The frequency, mode and power, in whichever style the pane wears.
///
/// Public so the three renderings that matter — live, dimmed, and the "no
/// radio to show" case — can be driven from a constructed [EquipmentState].
/// Reaching them through [RadioPanel] would mean standing up a driver and a
/// transport to get a session into `connected`, and the one distinction most
/// worth pinning (a STALE session reads as not connected) has no way to be
/// reached from outside CatService at all.
class RadioReadout extends StatelessWidget {
  final EquipmentNode? node;
  final EquipmentState state;
  final bool live;
  final String style;
  final RadioPalette palette;
  final num? power;

  /// Which meters this radio's driver can read — [EquipmentDriver.telemetryMeters],
  /// not what has arrived. Empty hides the strip entirely.
  final Set<RadioMeter> meters;

  final VoidCallback? onTune;
  final Widget? powerButton;

  const RadioReadout({
    super.key,
    required this.node,
    required this.state,
    required this.live,
    required this.style,
    required this.palette,
    required this.power,
    this.meters = const {},
    required this.onTune,
    required this.powerButton,
  });

  @override
  Widget build(BuildContext context) {
    final p = t.operation.layout.panels;
    if (node == null) {
      // Not dimmed prose over a dark glass: there is no radio to be off, so
      // this is a configuration message and reads as one.
      return Center(
        child: Text(
          p.radioNoRadio,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: palette.label),
        ),
      );
    }

    final freq = state.vfo.freqKHz;
    final mode = state.vfo.mode;
    // A connect that failed has a REASON, already translated by CatService
    // into something an operator can act on ("port in use", "no such
    // device"). Collapsing it into the same dark glass as a radio nobody has
    // switched on yet is what makes the power button feel like it did
    // nothing: press, flicker, and back to an identical panel.
    final failure = state.status == EquipmentStatus.error ? state.error : null;
    // Connected, but nothing has arrived in a while. NOT the same as off, and
    // the distinction is the point — the digits below are minutes old, and a
    // screen reader told "not connected" would send the operator to reconnect
    // a session that is already up (docs/design/cat.md).
    final stale = state.stale;
    // Announced ahead of the frequency, because it changes what the reading
    // MEANS: a screen-reader user handed digits alone has no way to know
    // the rig is on the air.
    final tx = state.telemetry.isTransmitting ? '${t.operation.layout.panels.radioTransmitting} ' : '';
    final label = failure ??
        (stale
            ? '${p.radioStale} ${freq == null ? '' : fmtFreqToTheHz(freq)}'
            : live
                ? '$tx${freq == null ? p.radioNoFrequency : fmtFreqToTheHz(freq)} ${mode ?? ''}'
                    '${power == null ? '' : ' ${_wattsText(power!)}'}'
                : p.radioOff);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _annunciators(context, mode, stale: stale),
        Expanded(
          // Around the FREQUENCY only, never around the whole pane:
          // `excludeSemantics` drops every node beneath it, and the power
          // button sits in the row above — wrapping the column would leave a
          // screen reader a frequency it cannot act on and no way to switch
          // the radio on at all.
          child: Semantics(
            label: label,
            // The tap has to be re-declared here: `excludeSemantics` drops
            // the whole subtree beneath it, the GestureDetector's own action
            // included, and this app shows no hover tooltips
            // (docs/design/user-interface.md) — so nothing else would
            // advertise that the readout does anything.
            onTap: onTune,
            button: onTune != null,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: onTune,
              // Opaque so the whole readout answers the tap, not only the
              // pixels the segments happen to cover.
              behavior: HitTestBehavior.opaque,
              child: failure != null
                  ? _failure(context, failure)
                  : style == radioStyleLcd
                      ? _lcd(context, freq)
                      : _modern(context, freq),
            ),
          ),
        ),
        if (live && meters.isNotEmpty) _meterStrip(context),
      ],
    );
  }

  /// What the radio's meters read, under the frequency.
  ///
  /// Rebuilt once a second on top of whatever CatService notifies, because
  /// readings EXPIRE ([meterLinger]) and nothing notifies when they do: the
  /// last thing a driver does before a reading goes stale is stop reporting,
  /// so without a tick the strip would show the SWR of a transmission that
  /// ended twenty minutes ago.
  Widget _meterStrip(BuildContext context) => SizedBox(
        height: _meterStripHeight,
        child: OncePerSecond(
          builder: (context, nowUtc) {
            final now = nowUtc.millisecondsSinceEpoch;
            return Row(
              children: [
                for (final meter in RadioMeter.values)
                  if (meters.contains(meter))
                    _meterSlot(context, meter, state.telemetry.fresh(meter, now)),
              ],
            );
          },
        ),
      );

  /// One meter's place in the row.
  ///
  /// The two with a BAR take the width that is going and the plain readings
  /// take what they need: a bar is only worth drawing at a width it can put
  /// segments in, and a voltage is a number an operator reads rather than
  /// gauges.
  Widget _meterSlot(BuildContext context, RadioMeter meter, MeterReading? reading) {
    final bar = _barFor(meter, reading);
    final cell = bar == null
        ? _meter(context, meter, reading)
        : Row(
            children: [
              Expanded(child: _bar(context, meter, bar)),
              const SizedBox(width: Space.xs),
              // Flexible, not bare: a non-flex child of a Row is given
              // unbounded width, so the reading beside a bar would take its
              // natural size whatever was left and push the row past its
              // edge — which at the tightest Font Scale is every time.
              Flexible(child: _meter(context, meter, reading)),
            ],
          );
    final padded = Padding(padding: const EdgeInsets.only(right: Space.sm), child: cell);
    // Flexible either way, never a bare child. A non-flex child of a Row is
    // given UNBOUNDED width, so on a narrow pane — or at the tightest Font
    // Scale — the plain readings would take everything they asked for, the
    // bars beside them would collapse to nothing, and the row would overflow.
    // The gauged ones take the space that is going; the plain ones take what
    // they need and give the rest back.
    return bar == null ? Flexible(child: padded) : Expanded(child: padded);
  }

  /// How far up its own scale a reading sits, and where that scale turns
  /// red — null for a meter this pane does not gauge.
  ({double fraction, double? alertFrom})? _barFor(RadioMeter meter, MeterReading? reading) {
    switch (meter) {
      case RadioMeter.powerOut:
        // Against the power the radio was SET to, which is the question an
        // operator actually has: am I making what I asked for? There is no
        // command in any of these protocols that states a radio's rated
        // maximum, so a scale of "full power" would be invented — and the
        // set level is a real number the operator chose. A reading ABOVE it
        // widens the scale rather than overflowing the bar.
        final asked = power;
        final measured = reading?.value ?? 0;
        final full = asked == null ? measured : (measured > asked ? measured : asked);
        if (full <= 0) return (fraction: 0, alertFrom: null);
        return (fraction: measured / full, alertFrom: null);
      case RadioMeter.swr:
        // 1.0 to 3.0, the span a rig's own SWR scale covers, with the red
        // zone starting at the threshold the operator is warned at.
        final value = reading?.value ?? 1.0;
        return (
          fraction: ((value - 1) / (_swrFullScale - 1)).clamp(0.0, 1.0),
          alertFrom: (swrAlertThreshold - 1) / (_swrFullScale - 1),
        );
      case RadioMeter.signalDbm:
      case RadioMeter.alc:
      case RadioMeter.supplyVolts:
        // A supply voltage has no scale worth drawing — it is 13.8 or it is
        // a problem — and ALC is a number for a developer, not a gauge.
        return null;
    }
  }

  Widget _bar(BuildContext context, RadioMeter meter, ({double fraction, double? alertFrom}) bar) => SizedBox(
        height: _meterBarHeight,
        child: CustomPaint(
          painter: MeterBarPainter(
            fraction: bar.fraction,
            alertFrom: bar.alertFrom,
            lit: palette.ink,
            // The LCD face has real unlit segments to borrow; the Modern one
            // has no ghosts of its own, so the unlit track is the label
            // colour worn thin.
            unlit: palette.ghost ?? palette.label.withValues(alpha: 0.20),
            alert: _alertColor(context),
          ),
        ),
      );

  /// One meter's reading, or its label alone while nothing has been read.
  ///
  /// The label stays visible with no value behind it, rather than the slot
  /// going blank: a strip that emptied out would read as a fault, and what
  /// is actually true is that the radio is not transmitting and there is
  /// nothing to measure.
  Widget _meter(BuildContext context, RadioMeter meter, MeterReading? reading) {
    final alert = meter == RadioMeter.swr && reading != null && reading.value >= swrAlertThreshold;
    final text = reading == null ? _meterLabel(meter) : _meterText(meter, reading.value);
    final base = (style == radioStyleLcd
            ? TextStyle(fontSize: _meterStripHeight * 0.72, fontWeight: FontWeight.w700, height: 1.0)
            : Theme.of(context).textTheme.labelSmall ?? const TextStyle())
        .copyWith(
      color: alert ? _alertColor(context) : palette.label,
      fontWeight: alert ? FontWeight.w700 : null,
      // The digits change every poll; without tabular figures the whole
      // strip shuffles sideways while the operator is transmitting.
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    // Ellipsised rather than wrapped: the strip is one row tall by
    // construction, and a second line would be clipped rather than shown.
    final label = Text(text, style: base, maxLines: 1, overflow: TextOverflow.ellipsis);
    if (!alert) return label;
    // Named rather than left as bare digits: "SWR 2.5" read aloud says
    // nothing about whether 2.5 is a problem, and this strip's whole reason
    // for colouring it — and for the red zone painted on the bar beside it —
    // is that it is.
    return Semantics(
      label: '$text — ${t.operation.layout.panels.radioSwrHigh}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(MdiIcons.alertOutline, size: _meterStripHeight * 0.8, color: _alertColor(context)),
          const SizedBox(width: Space.xxs),
          // The glyph keeps its size and the digits give way: an SWR warning
          // that lost its icon to a narrow pane would be a plain number
          // again, which is the one thing colour alone cannot say.
          Flexible(child: label),
        ],
      ),
    );
  }

  /// Red on both faces, and the only red either of them wears.
  ///
  /// The TX legend deliberately does NOT use it, though a rig's own TX lamp
  /// is red: transmitting is what the operator asked for, and if the normal
  /// case is already lit red then the one thing on this pane that means
  /// "stop and look" has nothing left to say it with.
  Color _alertColor(BuildContext context) =>
      style == radioStyleLcd ? const Color(0xFFE04A2F) : Theme.of(context).colorScheme.error;

  String _meterLabel(RadioMeter meter) {
    final p = t.operation.layout.panels;
    return switch (meter) {
      RadioMeter.signalDbm => 'dBm',
      RadioMeter.powerOut => p.radioWatts,
      RadioMeter.swr => p.radioSwr,
      RadioMeter.alc => p.radioAlc,
      RadioMeter.supplyVolts => p.radioVolts,
    };
  }

  String _meterText(RadioMeter meter, num value) {
    final p = t.operation.layout.panels;
    return switch (meter) {
      RadioMeter.signalDbm => '${value.toStringAsFixed(1)} dBm',
      RadioMeter.powerOut => '${powerText(value)} ${p.radioWatts}',
      RadioMeter.swr => '${p.radioSwr} ${value.toStringAsFixed(1)}',
      RadioMeter.alc => '${p.radioAlc} ${(value * 100).round()}%',
      RadioMeter.supplyVolts => '${value.toStringAsFixed(1)} ${p.radioVolts}',
    };
  }

  /// The row above the frequency: mode at the left, power at the right — the
  /// two corners a rig's own display puts them in, and the reason the
  /// frequency gets the whole width beneath rather than sharing a line.
  ///
  /// The power BUTTON rides here beside the power reading rather than in a
  /// row of its own, so a pane three units tall spends its height on the
  /// digits instead of on a strip holding one icon.
  Widget _annunciators(BuildContext context, String? mode, {required bool stale}) => SizedBox(
        height: _annunciatorHeight,
        child: Row(
          children: [
            if (mode != null && mode.isNotEmpty) _mode(context, mode),
            // Beside the mode rather than over the digits: the frequency is
            // still roughly where the rig is, so it stays readable and this
            // says how much to trust it.
            if (stale) ...[
              const SizedBox(width: Space.xs),
              _mode(context, t.operation.layout.panels.radioStale),
            ],
            // Only when the radio has SAID it is keyed. A driver that
            // cannot answer leaves this null, and an unlit TX legend on a
            // rig that is actually transmitting is honest about what the
            // app knows; a lit one that guessed would not be.
            if (state.telemetry.isTransmitting) ...[
              const SizedBox(width: Space.xs),
              _mode(context, t.operation.layout.panels.radioTransmitting),
            ],
            const Spacer(),
            _power(context),
            if (powerButton != null) ...[const SizedBox(width: Space.xs), powerButton!],
          ],
        ),
      );

  /// Why the radio would not come up, in place of the digits.
  ///
  /// The frequency's own space, because there is no frequency to give up —
  /// a failed connect never had one — and because a reason an operator is
  /// meant to act on has to be legible at the distance the digits are.
  Widget _failure(BuildContext context, String reason) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xs),
          child: Text(
            reason,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: (style == radioStyleLcd
                    ? TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.4)
                    : Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
                .copyWith(color: palette.ink),
          ),
        ),
      );

  Widget _mode(BuildContext context, String mode) {
    if (style == radioStyleLcd) {
      return LcdAnnunciator(text: mode, palette: palette, height: _annunciatorHeight);
    }
    // A Material tonal pill, not a copy of the LCD legend: the Modern face
    // adopts the app's own vocabulary, and a bordered box would read as a
    // disabled input rather than as a badge.
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: Space.sm),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: live ? 1.0 : _dimmedAlpha),
        borderRadius: BorderRadius.circular(_annunciatorHeight / 2),
      ),
      child: Text(
        mode,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSecondaryContainer.withValues(alpha: live ? 1.0 : _dimmedAlpha),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  Widget _power(BuildContext context) {
    final watts = power;
    if (watts == null) return const SizedBox.shrink();
    final p = t.operation.layout.panels;
    if (style == radioStyleLcd) {
      // Segments, because power IS a number — unlike the mode, which has no
      // seven-segment spelling. The `W` stays text: it is a printed unit on
      // a real display, not a digit cell.
      final cells = lcdCellsForPower(watts);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: _annunciatorHeight,
            width: lcdWidthForCells(cells, _annunciatorHeight),
            child: CustomPaint(painter: RadioLcdPainter(cells: cells, palette: palette)),
          ),
          SizedBox(width: _annunciatorHeight * 0.14),
          Text(
            p.radioWatts,
            style: TextStyle(
              color: palette.label,
              fontSize: _annunciatorHeight * 0.55,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
        ],
      );
    }
    return Text(
      _wattsText(watts),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: palette.label),
    );
  }

  /// Watts as the operator reads them, spelled once for both faces and the
  /// screen reader by [powerText].
  String _wattsText(num watts) => '${powerText(watts)} ${t.operation.layout.panels.radioWatts}';

  Widget _lcd(BuildContext context, double? freq) => LayoutBuilder(
        builder: (context, constraints) => CustomPaint(
          size: constraints.biggest,
          painter: RadioLcdPainter(cells: lcdCellsForFrequency(freq), palette: palette),
        ),
      );

  /// The Modern face's frequency, split the way a QSO row splits one: MHz
  /// bold, kHz regular, Hz smaller. One reading convention across the app, so
  /// the digits an operator's eye is trained to land on are in the same
  /// weight wherever a frequency appears.
  ///
  /// Always three Hz digits, unlike a QSO row's operation-wide
  /// [hzDigitsNeeded]: this is where the radio IS rather than where a contact
  /// was logged, and a width that changed as the last digits settled would
  /// make the readout twitch on every report.
  Widget _modern(BuildContext context, double? freq) {
    final theme = Theme.of(context);
    if (freq == null) {
      return Center(
        child: Text(
          t.operation.layout.panels.radioNoFrequency,
          style: theme.textTheme.displaySmall?.copyWith(color: palette.ink),
        ),
      );
    }
    final parts = freqDisplayParts(freq, hzDigits: 3);
    final base = theme.textTheme.displaySmall?.copyWith(
          color: palette.ink,
          // Without tabular figures the readout jitters sideways on every
          // digit the radio reports.
          fontFeatures: const [FontFeature.tabularFigures()],
        ) ??
        const TextStyle();
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          // A kHz reading, split the way the QSO row splits it: a thousands
          // mark between MHz and kHz, a decimal point before the Hz digits,
          // both in the operator's own conventions. Below 1 MHz (630m,
          // 2200m) there is no thousands group, and `0,472` is not a reading
          // anyone writes.
          if (int.parse(parts.mhz) > 0) ...[
            Text(groupDigits(parts.mhz), style: base.copyWith(fontWeight: FontWeight.w700)),
            Text(NumberFormatting.instance.groupingSeparator, style: base),
            Text(parts.khz, style: base),
          ] else
            Text(int.parse(parts.khz).toString(), style: base.copyWith(fontWeight: FontWeight.w700)),
          if (parts.hz != null) ...[
            Text(NumberFormatting.instance.decimalSeparator, style: base),
            Text(parts.hz!, style: base.copyWith(fontSize: (base.fontSize ?? 36) * 0.6)),
          ],
        ],
      ),
    );
  }
}

/// Brings the radio up, or takes it down.
///
/// One button rather than two states of a status row: an operator looking at
/// a dark display wants the same control a rig's own front panel gives them,
/// and the button being present while connected is what makes it a switch
/// rather than a one-way "fix this" prompt.
class RadioPowerButton extends StatelessWidget {
  final EquipmentStatus status;

  /// The pane's UNDIMMED ink. The button does its own fading from [status]
  /// rather than inheriting the readout's, because the two answer different
  /// questions: the readout fades to say "this is not a live reading", while
  /// this fades to say "the radio is down" — and a connecting radio has a
  /// stale readout and a button that must already be showing what it is
  /// doing.
  final Color accent;

  /// The chrome around the glyph, so the switch reads as part of the same row
  /// as the mode legend beside it.
  final RadioPalette palette;
  final String style;

  /// The row's height. The button is sized to it rather than to Material's
  /// 48px default, which would otherwise set the height of a row built to sit
  /// above the frequency and leave the digits a strip of what is left.
  final double height;

  final VoidCallback onPressed;

  const RadioPowerButton({
    super.key,
    required this.status,
    required this.accent,
    required this.palette,
    required this.style,
    required this.height,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final p = t.operation.layout.panels;
    final connected = status == EquipmentStatus.connected;
    final busy = status == EquipmentStatus.connecting || status == EquipmentStatus.disconnecting;
    // Bright when the radio is UP, dim when it is down — the state of the
    // thing, the way a rig's own power lamp reads, not a prompt that lights
    // up when there is something to press. A switch that got brighter the
    // less there was running would invert what every panel in the shack
    // means by a lit indicator.
    final lit = connected ? accent : accent.withValues(alpha: _dimmedAlpha);
    final decoration = style == radioStyleLcd
        ? BoxDecoration(
            color: palette.ghost,
            border: Border.all(color: lit, width: height * 0.06),
            borderRadius: BorderRadius.circular(height * 0.16),
          )
        : BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .secondaryContainer
                .withValues(alpha: connected ? 1.0 : _dimmedAlpha),
            borderRadius: BorderRadius.circular(height / 2),
          );
    return Container(
      width: height,
      height: height,
      alignment: Alignment.center,
      decoration: decoration,
      child: IconButton(
        // Sized to the pill rather than padded out to Material's default,
        // which at this height would clip the glyph and overflow the row.
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(width: height, height: height),
        iconSize: height * 0.66,
        icon: Icon(
          MdiIcons.power,
          // The app shows no hover tooltips
          // (docs/design/user-interface.md), so the accessible name is the
          // only place this button is named.
          semanticLabel: connected ? p.radioDisconnect : p.radioConnect,
          color: style == radioStyleLcd
              ? lit
              : Theme.of(context)
                  .colorScheme
                  .onSecondaryContainer
                  .withValues(alpha: connected ? 1.0 : _dimmedAlpha),
        ),
        // A connect already in flight has nothing useful for a second press to
        // do, and CatService's own attempt sequence would simply supersede the
        // first — leaving the operator wondering which one they are watching.
        onPressed: busy ? null : onPressed,
      ),
    );
  }
}

/// The colours a face wears.
///
/// The LCD wears the shared [lcdPalette], because it is a replica of a
/// physical object and a themed one stops being the thing it copies. The
/// Modern face has no such identity to protect, so it adopts the scheme and
/// sits in the dock like every other pane.
RadioPalette radioPaletteFor(BuildContext context, String style) {
  final theme = Theme.of(context);
  if (style == radioStyleLcd) {
    // Glass and ink come from [lcdPalette] — the one palette every
    // seven-segment replica in the app wears — rather than from values of
    // this pane's own.
    //
    // Always the dark variant, unlike the clock's LCD: this pane fades the
    // whole palette to show a radio that is not connected, and against the
    // light face's pale glass the faded ghosts land within a few counts of
    // the glass itself — the digits survive but the segment matrix behind
    // them does not, which is the one thing the ghosts exist for.
    final glass = lcdPalette(Brightness.dark);
    return RadioPalette(
      face: glass.face,
      ink: glass.ink,
      ghost: glass.ghost,
      label: glass.ink.withValues(alpha: 0.75),
    );
  }
  final scheme = theme.colorScheme;
  return RadioPalette(
    face: scheme.surface,
    ink: HaLoColors.of(context).onSurfaceAccent,
    label: scheme.onSurfaceVariant,
  );
}
