// GENERATED from assets/branding/savetrack-symbol.svg. Do not edit.
// Regenerate with: py tools/generate_branding.py
import 'package:flutter/material.dart';

/// Identical geometry for in-app branding and raster exports.
class SaveTrackLogoPainter extends CustomPainter {
  const SaveTrackLogoPainter({
    this.light = false,
    this.monochrome = false,
    this.coinProgress = 0,
    this.artworkScale = 1,
  });
  final bool light, monochrome;
  final double coinProgress, artworkScale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1024, size.height / 1024);
    canvas.translate(512, 512);
    canvas.scale(artworkScale);
    canvas.translate(-512, -512);
    final pigPath0 = Path()
      ..moveTo(710, 525)
      ..cubicTo(753, 523, 782, 498, 778, 455)
      ..cubicTo(809, 490, 794, 542, 736, 555)
      ..close();
    canvas.drawPath(
      pigPath0,
      Paint()
        ..color = monochrome
            ? Color(0xFF073F34)
            : (light ? Color(0xFF073F34) : Color(0xFF4BD4A8)),
    );
    final pigPath1 = Path()
      ..moveTo(299, 455)
      ..cubicTo(305, 422, 322, 392, 347, 369)
      ..lineTo(347, 315)
      ..quadraticBezierTo(347, 301, 361, 305)
      ..quadraticBezierTo(397, 314, 418, 349)
      ..cubicTo(448, 337, 480, 331, 514, 331)
      ..cubicTo(636, 331, 730, 417, 735, 530)
      ..cubicTo(739, 596, 705, 654, 661, 689)
      ..lineTo(661, 741)
      ..quadraticBezierTo(661, 763, 639, 763)
      ..lineTo(595, 763)
      ..quadraticBezierTo(573, 763, 573, 741)
      ..lineTo(573, 720)
      ..cubicTo(526, 737, 463, 737, 416, 721)
      ..lineTo(416, 741)
      ..quadraticBezierTo(416, 763, 394, 763)
      ..lineTo(350, 763)
      ..quadraticBezierTo(328, 763, 328, 741)
      ..lineTo(328, 689)
      ..cubicTo(294, 664, 271, 629, 259, 591)
      ..lineTo(235, 591)
      ..quadraticBezierTo(213, 591, 213, 569)
      ..lineTo(213, 489)
      ..quadraticBezierTo(213, 455, 247, 455)
      ..close();
    canvas.drawPath(
      pigPath1,
      Paint()
        ..color = monochrome
            ? Color(0xFF073F34)
            : (light ? Color(0xFF073F34) : Color(0xFF4BD4A8)),
    );
    if (!monochrome) {
      final pigPath2 = Path()
        ..moveTo(462, 364)
        ..lineTo(562, 364)
        ..cubicTo(570, 364, 576, 370, 576, 378)
        ..cubicTo(576, 386, 570, 392, 562, 392)
        ..lineTo(462, 392)
        ..cubicTo(454, 392, 448, 386, 448, 378)
        ..cubicTo(448, 370, 454, 364, 462, 364)
        ..close();
      canvas.drawPath(
        pigPath2,
        Paint()
          ..color = monochrome
              ? Color(0xFF073F34)
              : (light ? Color(0xFFDCF8EB) : Color(0xFF073F34)),
      );
    }
    if (!monochrome) {
      final pigPath3 = Path()
        ..moveTo(364, 442)
        ..cubicTo(364, 449.732, 357.732, 456, 350, 456)
        ..cubicTo(342.268, 456, 336, 449.732, 336, 442)
        ..cubicTo(336, 434.268, 342.268, 428, 350, 428)
        ..cubicTo(357.732, 428, 364, 434.268, 364, 442)
        ..close();
      canvas.drawPath(
        pigPath3,
        Paint()
          ..color = monochrome
              ? Color(0xFF073F34)
              : (light ? Color(0xFFDCF8EB) : Color(0xFF073F34)),
      );
    }
    canvas.save();
    // The slot clips the coin as it enters; no route or startup delay.
    canvas.clipRect(const Rect.fromLTRB(0, 0, 1024, 378));
    canvas.translate(0, coinProgress * 300);
    final coinPath0 = Path()
      ..moveTo(584, 222)
      ..cubicTo(584, 261.765, 551.765, 294, 512, 294)
      ..cubicTo(472.235, 294, 440, 261.765, 440, 222)
      ..cubicTo(440, 182.235, 472.235, 150, 512, 150)
      ..cubicTo(551.765, 150, 584, 182.235, 584, 222)
      ..close();
    if (monochrome) {
      coinPath0
        ..fillType = PathFillType.evenOdd
        ..moveTo(562, 222)
        ..cubicTo(562, 249.614, 539.614, 272, 512, 272)
        ..cubicTo(484.386, 272, 462, 249.614, 462, 222)
        ..cubicTo(462, 194.386, 484.386, 172, 512, 172)
        ..cubicTo(539.614, 172, 562, 194.386, 562, 222)
        ..close();
    }
    canvas.drawPath(
      coinPath0,
      Paint()..color = monochrome ? Color(0xFF073F34) : (Color(0xFFF5C96A)),
    );
    if (!monochrome) {
      final coinPath1 = Path()
        ..moveTo(562, 222)
        ..cubicTo(562, 249.614, 539.614, 272, 512, 272)
        ..cubicTo(484.386, 272, 462, 249.614, 462, 222)
        ..cubicTo(462, 194.386, 484.386, 172, 512, 172)
        ..cubicTo(539.614, 172, 562, 194.386, 562, 222)
        ..close();
      canvas.drawPath(
        coinPath1,
        Paint()
          ..color = monochrome ? Color(0xFF073F34) : (Color(0xFFDDAA4F))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12,
      );
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(SaveTrackLogoPainter oldDelegate) =>
      light != oldDelegate.light ||
      monochrome != oldDelegate.monochrome ||
      coinProgress != oldDelegate.coinProgress ||
      artworkScale != oldDelegate.artworkScale;
}
