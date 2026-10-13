import 'package:flutter/material.dart';

import 'savetrack_logo_painter.dart';

/// The shared SaveTrack symbol, drawn as a vector at the requested size.
/// Motion is optional and only used inside the existing session-loading view.
class SaveTrackLogo extends StatelessWidget {
  const SaveTrackLogo({
    super.key,
    this.size = 40,
    this.onDark = false,
    this.animate = false,
  });

  final double size;
  final bool onDark, animate;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final art = animate && !reduceMotion
        ? TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOutCubic,
            builder: (context, progress, child) => CustomPaint(
              painter: SaveTrackLogoPainter(
                coinProgress: progress,
                artworkScale: 1.18,
              ),
            ),
          )
        : const CustomPaint(painter: SaveTrackLogoPainter(artworkScale: 1.18));
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: onDark
                ? null
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF073F34), Color(0xFF13876D)],
                  ),
            borderRadius: BorderRadius.circular(size * .3),
          ),
          child: RepaintBoundary(child: art),
        ),
      ),
    );
  }
}
