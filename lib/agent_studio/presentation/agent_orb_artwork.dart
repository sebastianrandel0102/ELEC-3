import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design_system.dart';

/// Static orbital geometry; only real recognizer amplitude changes its scale.
/// No timer, shader, simulated audio levels or off-screen animation controller.
class AgentOrbArtwork extends StatelessWidget {
  const AgentOrbArtwork({super.key, required this.speaking});
  final bool speaking;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _OrbPainter(),
    child: Center(
      child: Icon(
        speaking ? Icons.graphic_eq_rounded : Icons.auto_awesome_rounded,
        color: teal,
        size: 38,
      ),
    ),
  );
}

class _OrbPainter extends CustomPainter {
  const _OrbPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(
      center,
      r * .98,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.35, -.4),
          colors: [SaveTrackDesign.mist, mint, SaveTrackDesign.luminous, teal],
          stops: [0, .4, .78, 1],
        ).createShader(Offset.zero & size),
    );
    canvas.drawCircle(
      center,
      r * .78,
      Paint()
        ..color = mint.withValues(alpha: .42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    for (var i = 0; i < 4; i++) {
      canvas.save();
      canvas.rotate(-math.pi / 4 + i * math.pi / 3);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: r * 1.7,
          height: r * (.7 + i * .1),
        ),
        Paint()
          ..color = (i.isEven ? Colors.white : teal).withValues(
            alpha: i.isEven ? .55 : .16,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      canvas.restore();
    }
    canvas.restore();
    canvas.drawCircle(
      Offset(center.dx - r * .55, center.dy - r * .48),
      3,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_OrbPainter oldDelegate) => false;
}
