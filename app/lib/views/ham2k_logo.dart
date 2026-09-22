// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The per-edition "HAM2K" **arc** wordmark (assets/images/ham2k-<edition>-
// arc.svg) with the product name (halo_widgets' `ham2kProductName`: "Power
// Logger", "Portable Logger") overlapping its lower-left — each word on its
// own line in bold RobotoSlab, black with a white outline and its own drop
// shadow. The brand lockup used on the startup splash, the release/onboarding
// overlays, and the About screen header. The compact home
// header/right pane use the square mark (`ham2kSquareLogoAsset`) instead.
//
// The colors are baked into each SVG per edition (the "2K" is gray on Dev,
// orange on Next), so the edition is chosen by *which file* we load — no runtime
// recoloring.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:halo_build_tools/halo_build_tools.dart' show Edition, kEdition;
import 'package:halo_widgets/halo_widgets.dart';

/// The square logo mark asset for [edition] — `ham2k-dev-square.svg` /
/// `-next-` / `-prod-`. Transparent background, brand colors baked in.
String ham2kSquareLogoAssetFor(Edition edition) => 'assets/images/ham2k-${edition.name}-square.svg';

/// The square logo mark for the current build edition. Pass to `SvgPicture`
/// wherever the compact ham2k mark is shown (home header/right pane) so each
/// edition renders in its own color.
String get ham2kSquareLogoAsset => ham2kSquareLogoAssetFor(kEdition);

/// The wide "HAM2K" **arc** wordmark asset for [edition] — `ham2k-dev-arc.svg`
/// etc. Transparent, brand colors baked in. Drives [Ham2kBrandMark].
String ham2kArcLogoAssetFor(Edition edition) => 'assets/images/ham2k-${edition.name}-arc.svg';

/// The arc wordmark for the current build edition (see [ham2kArcLogoAssetFor]).
String get ham2kArcLogoAsset => ham2kArcLogoAssetFor(kEdition);

/// The edition badge asset — a wide "NEXT EDITION" / "DEV EDITION" wordmark
/// shown next to the product name — or `null` for [Edition.prod], which has no
/// badge (it's the plain product).
String? ham2kEditionBadgeAssetFor(Edition edition) => edition == Edition.prod ? null : 'assets/images/edition-${edition.name}.svg';

/// The edition badge for the current build edition (see
/// [ham2kEditionBadgeAssetFor]); `null` on Regular builds.
String? get ham2kEditionBadgeAsset => ham2kEditionBadgeAssetFor(kEdition);

/// The current edition's badge SVG, sized to [height] or [width], with
/// [shadows] cast behind it — each a blurred, tinted, offset copy of the same
/// art, rendered exactly the way Flutter renders a text [Shadow] (offset + a
/// `convertRadiusToSigma` blur), so the badge can wear the same drop shadow as
/// the credits/version labels beside it. A zero-offset shadow reads as a glow.
/// Renders nothing on Regular builds.
class Ham2kEditionBadge extends StatelessWidget {
  /// Exactly one of [height] / [width] is given; the other dimension follows
  /// the art's own aspect ratio, which differs per edition — the Dev wordmark
  /// is narrower than Next's — so which one is pinned decides whether the
  /// editions match in height or in width.
  final double? height;
  final double? width;

  /// Shadows behind the badge art, back-to-front. Defaults to none.
  final List<Shadow> shadows;

  const Ham2kEditionBadge({super.key, this.height, this.width, this.shadows = const []})
    : assert((height == null) != (width == null), 'give exactly one of height or width');
  // Release strips that assert, and SvgPicture with neither dimension paints
  // the art at its intrinsic size — wrong, but visibly so.

  @override
  Widget build(BuildContext context) {
    final asset = ham2kEditionBadgeAsset;
    if (asset == null) return const SizedBox.shrink();
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        for (final shadow in shadows)
          Transform.translate(
            offset: shadow.offset,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: Shadow.convertRadiusToSigma(shadow.blurRadius), sigmaY: Shadow.convertRadiusToSigma(shadow.blurRadius)),
              child: SvgPicture.asset(asset, height: height, width: width, colorFilter: ColorFilter.mode(shadow.color, BlendMode.srcIn)),
            ),
          ),
        SvgPicture.asset(asset, height: height, width: width),
      ],
    );
  }
}

/// The drop shadow shared across the photo-overlay lockup — the credits and
/// version labels (release_overlay.dart's `overlayVersionLabelStyle` /
/// `overlayCreditsStyle`, which import this) and the Next edition badge here —
/// so they read as one unit. Single source of truth. The Next badge art is
/// orange, which this dark drop shadow reads well against.
const kOverlayDropShadows = [Shadow(color: Colors.black54, offset: Offset(1, 2), blurRadius: 4)];

/// The Dev badge art is gray, so a dark drop shadow barely lifts it off a
/// photo; a white glow (zero-offset, stacked for strength) makes it read.
const _devEditionBadgeGlow = [Shadow(color: Colors.white, blurRadius: 4), Shadow(color: Colors.white, blurRadius: 4)];

/// The badge shadow for the current build edition (see the two lists above),
/// for a badge standing over a release photo — the splash lockup and the home
/// branding pane. The compact header bar has its own list below.
List<Shadow> get ham2kEditionBadgeShadows => kEdition == Edition.dev ? _devEditionBadgeGlow : kOverlayDropShadows;

/// Badge shadows for the compact home-app-bar badge: Dev gets the white glow
/// (its gray art needs lift off the teal bar too); other editions keep the
/// subtle black glow that sits well on teal.
List<Shadow> get ham2kHeaderEditionBadgeShadows => kEdition == Edition.dev ? _devEditionBadgeGlow : const [Shadow(color: Colors.black, blurRadius: 3)];

/// How much larger the product name is set than the lockup's base size. The
/// name is the half of the mark a reader actually reads, and the arc carries
/// the brand without it. Applied to the NAME only — see the build method.
const _titleSizeRatio = 1.3;

/// Roughly how many times wider the edition wordmark is than it is tall, for
/// deciding layout before the SVG has loaded and could be measured. Only ever
/// reserves or compares space, never sizes the art itself.
///
/// Deliberately GENEROUS — the real viewBoxes are 4.84 (Dev, 774x160) and 5.29
/// (Next, 847x160). Erring high spends a line the header might not have needed;
/// erring low hands the badge to a `shrinkToFit`, and a FittedBox forwards its
/// child's baseline unscaled, so a squeezed badge would sit off its baseline
/// with nothing to catch it. Tighten this and that becomes reachable.
const double ham2kEditionBadgeWidthRatio = 5.5;

/// The arc SVG's own viewBox is 2367×1412 — height/width, used to size the
/// lockup's box from just its width without waiting on the SVG to load.
const _arcAspectRatio = 1412 / 2367;

class Ham2kBrandMark extends StatelessWidget {
  /// Width of the arc wordmark; the product-name text, its position, and the
  /// drop shadows all scale off of this so the whole lockup stays proportional
  /// at any size.
  final double logoWidth;

  /// True to tint the arc solid white — for use over a solid dark/primary-color
  /// background where its baked-in colors wouldn't read. False keeps the
  /// edition's natural colors, for use over a light background or a photo (the
  /// release overlay, About). The product-name text's black/white-outline
  /// styling stays the same either way — it's legible over any background.
  final bool light;

  /// Soft shape-following shadow beneath the arc — a second, blurred, black-
  /// tinted copy of the same SVG behind it, since Flutter has no built-in
  /// per-pixel drop shadow for arbitrary vector art.
  final bool showShadow;

  /// Points added to the product-name text size only (not the arc, the edition
  /// badge, or the layout), for callers that want the name to read a little
  /// larger against the same lockup — e.g. the About header (+3).
  final double titleFontSizeDelta;

  const Ham2kBrandMark({super.key, this.logoWidth = 200, this.light = false, this.showShadow = false, this.titleFontSizeDelta = 0});

  @override
  Widget build(BuildContext context) {
    final logoHeight = logoWidth * _arcAspectRatio;
    // The badge and lockup geometry key off the base size; only the product-
    // name text takes [_titleSizeRatio] and [titleFontSizeDelta] on top of it,
    // so growing the name leaves the badge and the name's position put.
    final baseFontSize = logoWidth * 0.1785;
    final fontSize = baseFontSize * _titleSizeRatio + titleFontSizeDelta;
    // Product names are two words ("Power Logger", "Portable Logger"); stack
    // one word per line, left-aligned.
    final titleText = ham2kProductName.split(' ').join('\n');
    final titleStyle = TextStyle(
      fontFamily: 'RobotoSlab',
      fontWeight: FontWeight.w900, // "Roboto Slab Black", matching theme.dart's AppBar title
      fontSize: fontSize,
      height: 1,
    );

    // Positioned 20% in from the arc's left edge, 60% down from its top, left-
    // aligned from that point — overlapping the arc's lower half.
    final titleLeft = logoWidth * 0.20;
    final titleTop = logoHeight * 0.60;
    final titleSize = (TextPainter(
      text: TextSpan(text: titleText, style: titleStyle),
      textDirection: TextDirection.ltr,
    )..layout()).size;

    // The edition badge ("NEXT EDITION" / "DEV EDITION") sits below the name,
    // left-aligned; Regular (prod) has none.
    final badge = ham2kEditionBadgeAsset;
    final badgeHeight = baseFontSize * 0.72;
    final badgeGap = baseFontSize * 0.3;

    final nameBlock = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Ham2kOutlinedShadowText(text: titleText, style: titleStyle),
        if (badge != null) ...[
          SizedBox(height: badgeGap),
          // Nudged 5px left of the name. Next wears the same drop shadow as the
          // credits/version labels; Dev wears a white glow (see the consts).
          Transform.translate(
            offset: const Offset(-5, 0),
            child: Ham2kEditionBadge(height: badgeHeight, shadows: ham2kEditionBadgeShadows),
          ),
        ],
      ],
    );

    // Size the box to the union of the arc and the name+badge block, so a
    // `Center` above centers the whole composition. The badge is much wider than
    // the name (~5:1), so estimate its width from its height.
    final blockWidth = math.max(titleSize.width, badge == null ? 0.0 : badgeHeight * ham2kEditionBadgeWidthRatio);
    final blockHeight = titleSize.height + (badge == null ? 0.0 : badgeGap + badgeHeight);
    final unionWidth = math.max(logoWidth, titleLeft + blockWidth);
    final unionHeight = math.max(logoHeight, titleTop + blockHeight);

    final arc = SvgPicture.asset(ham2kArcLogoAsset, width: logoWidth, colorFilter: light ? const ColorFilter.mode(Colors.white, BlendMode.srcIn) : null);

    return SizedBox(
      width: unionWidth,
      height: unionHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: showShadow ? _ArcLogoWithShadow(logo: arc, width: logoWidth) : arc,
          ),
          Positioned(left: titleLeft, top: titleTop, child: nameBlock),
        ],
      ),
    );
  }
}

class _ArcLogoWithShadow extends StatelessWidget {
  final Widget logo;
  final double width;

  const _ArcLogoWithShadow({required this.logo, required this.width});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: Offset(width * 0.015, width * 0.02),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: width * 0.02, sigmaY: width * 0.02),
            child: SvgPicture.asset(ham2kArcLogoAsset, width: width, colorFilter: const ColorFilter.mode(Colors.black45, BlendMode.srcIn)),
          ),
        ),
        logo,
      ],
    );
  }
}

/// Black fill + white stroke outline + a soft blurred drop shadow — the same
/// "offset, blurred, tinted copy behind the real thing" drop-shadow technique
/// as [_ArcLogoWithShadow], plus a stroke-`Paint` outline (the standard way to
/// outline `Text` in Flutter; a `Shadow` list can fake a stroke but looks
/// noticeably rougher at this font weight/size). Renders multi-line text (one
/// word per line) left-aligned.
/// The product name as the brand lockup wears it: a white stroke around
/// black fill, over its own drop shadow, so the name holds up over an
/// arbitrary release photo in either theme. [style] must carry a fontSize —
/// every dimension here is a ratio of it.
class Ham2kOutlinedShadowText extends StatelessWidget {
  final String text;
  final TextStyle style;

  /// Fill inside the white stroke. The lockup's own name is pure black; a
  /// caller sitting on a lighter ground can soften it.
  final Color color;

  const Ham2kOutlinedShadowText({super.key, required this.text, required this.style, this.color = Colors.black});

  @override
  Widget build(BuildContext context) {
    assert(style.fontSize != null, 'Ham2kOutlinedShadowText sizes its stroke and shadow off style.fontSize');
    final fontSize = style.fontSize!;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: fontSize * 0.05,
          top: fontSize * 0.08,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: fontSize * 0.05, sigmaY: fontSize * 0.05),
            child: Text(text, style: style.copyWith(color: Colors.black45)),
          ),
        ),
        Text(
          text,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = fontSize * 0.063
              ..color = Colors.white,
          ),
        ),
        Text(text, style: style.copyWith(color: color)),
      ],
    );
  }
}
