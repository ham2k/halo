// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The "HAM2K" arc wordmark (assets/images/ham2k-arc.svg, copied from the
// repo-root assets/branding/ham2k-arc.svg) plus the product-name suffix
// (halo_widgets' `ham2kProductName`: "Logger" or "Portable Logger") in bold
// RobotoSlab, black with a white outline and its own drop shadow, overlapping
// the wordmark's lower-left — the app-polo-style brand lockup used on the
// startup splash/overlay and the About screen header (Issue #42).

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:halo_widgets/halo_widgets.dart';

const _arcAsset = 'assets/images/ham2k-arc.svg';

/// `ham2k-arc.svg`'s own viewBox is 2367×1412 — height/width, used to size
/// the logo's box from just its width without waiting on the SVG to load.
const _arcAspectRatio = 1412 / 2367;

class Ham2kBrandMark extends StatelessWidget {
  /// Width of the arc logo; the product-name text, its position, and the
  /// drop shadows all scale off of this so the whole mark stays proportional
  /// at any size.
  final double logoWidth;

  /// True to tint the logo solid white — for use over a solid dark/
  /// primary-color background (the splash screen) where the logo's natural
  /// teal wouldn't read. False keeps the logo's natural teal/white-outline
  /// colors, for use over a light background or a photo (the release
  /// overlay, About). The product-name text's black/white-outline styling
  /// stays the same either way — it's legible over any background.
  final bool light;

  /// Soft shape-following shadow beneath the arc logo — a second, blurred,
  /// black-tinted copy of the same SVG offset behind it, since Flutter has
  /// no built-in per-pixel drop shadow for arbitrary vector art.
  final bool showShadow;

  const Ham2kBrandMark({super.key, this.logoWidth = 200, this.light = false, this.showShadow = false});

  @override
  Widget build(BuildContext context) {
    final productName = ham2kProductName;
    final logoHeight = logoWidth * _arcAspectRatio;
    // A lone word (desktop's "Logger") reads smaller than a two-word phrase
    // at the same font size, so it's bumped up to stay visually balanced.
    final fontSize = logoWidth * (productName.contains(' ') ? 0.1785 : 0.255);
    final titleStyle = TextStyle(
      fontFamily: 'RobotoSlab',
      fontWeight: FontWeight.w900, // "Roboto Slab Black", matching theme.dart's AppBar title
      fontSize: fontSize,
      height: 1,
    );

    // Positioned 20% in from the wordmark's left edge, 60% down from its
    // top edge, left-aligned from that point — overlapping the wordmark's
    // lower half rather than sitting below it.
    final titleLeft = logoWidth * 0.20;
    final titleTop = logoHeight * 0.60;
    final titleSize = (TextPainter(
      text: TextSpan(text: productName, style: titleStyle),
      textDirection: TextDirection.ltr,
    )..layout())
        .size;

    // The title can extend past the logo's own right/bottom edge, so the
    // mark's true box is the union of both — sizing to that (rather than
    // just the logo) is what lets a `Center` above this widget center the
    // whole overlapping composition, not just the logo underneath it.
    final unionWidth = math.max(logoWidth, titleLeft + titleSize.width);
    final unionHeight = math.max(logoHeight, titleTop + titleSize.height);

    final logo = SvgPicture.asset(
      _arcAsset,
      width: logoWidth,
      colorFilter: light ? const ColorFilter.mode(Colors.white, BlendMode.srcIn) : null,
    );

    return SizedBox(
      width: unionWidth,
      height: unionHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: showShadow ? _ArcLogoWithShadow(logo: logo, width: logoWidth) : logo,
          ),
          Positioned(
            left: titleLeft,
            top: titleTop,
            child: _OutlinedShadowText(text: productName, style: titleStyle),
          ),
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
            child: SvgPicture.asset(
              _arcAsset,
              width: width,
              colorFilter: const ColorFilter.mode(Colors.black45, BlendMode.srcIn),
            ),
          ),
        ),
        logo,
      ],
    );
  }
}

/// Black fill + white stroke outline + a soft blurred drop shadow — the same
/// "offset, blurred, tinted copy behind the real thing" drop-shadow
/// technique as `_ArcLogoWithShadow`, plus a stroke-`Paint` outline (the
/// standard way to outline `Text` in Flutter; a `Shadow` list can fake a
/// stroke but looks noticeably rougher at this font weight/size).
class _OutlinedShadowText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const _OutlinedShadowText({required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
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
        Text(text, style: style.copyWith(color: Colors.black)),
      ],
    );
  }
}
