import 'dart:math' as math;
import 'package:flutter/material.dart';

class PartyWheel extends StatelessWidget {
  const PartyWheel({
    super.key,
    required this.names,
    required this.angle,
    required this.glow,
  });
  final List<String> names;
  final double angle;
  final double glow;
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: CustomPaint(painter: WheelPainter(names, angle, glow)),
  );
}

class WheelPainter extends CustomPainter {
  WheelPainter(this.names, this.angle, this.glow);
  final List<String> names;
  final double angle;
  final double glow;
  static const colors = [
    Color(0xff8b5cf6),
    Color(0xffec4899),
    Color(0xff06b6d4),
    Color(0xfff59e0b),
    Color(0xff10b981),
    Color(0xff6366f1),
  ];
  @override
  void paint(Canvas canvas, Size size) {
    if (names.isEmpty) return;
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 28;
    if (radius < 10) return;
    canvas.drawCircle(
      center,
      radius + 15,
      Paint()
        ..color = const Color(0xff8b5cf6).withValues(alpha: .25 + .15 * glow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawCircle(
      center,
      radius + 17,
      Paint()..color = const Color(0xff32254f),
    );
    final sweep = math.pi * 2 / names.length;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    for (var i = 0; i < names.length; i++) {
      final start = -math.pi / 2 - sweep / 2 + i * sweep;
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius),
        start,
        sweep,
        true,
        Paint()..color = colors[i % colors.length],
      );
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius),
        start,
        sweep,
        true,
        Paint()
          ..color = Colors.white24
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final mid = start + sweep / 2;
      canvas.save();
      canvas.rotate(mid);
      final text = TextPainter(
        text: TextSpan(
          text: names[i],
          style: TextStyle(
            fontSize: names.length > 14 ? 10 : 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: radius * .6);
      text.paint(canvas, Offset(radius * .36, -text.height / 2));
      text.dispose();
      canvas.restore();
    }
    canvas.restore();
    for (var i = 0; i < 40; i++) {
      final a = i * math.pi / 20;
      final p = center + Offset(math.cos(a), math.sin(a)) * (radius + 13);
      final lit = (i + (glow * 8).floor()) % 3 != 0;
      canvas.drawCircle(
        p,
        3.5,
        Paint()
          ..color = lit ? const Color(0xffffe6a7) : const Color(0xff77624c),
      );
    }
    canvas.drawCircle(
      center,
      radius * .15,
      Paint()..color = const Color(0xffffe6a7),
    );
    canvas.drawCircle(
      center,
      radius * .11,
      Paint()..color = const Color(0xff1c2036),
    );
    final pointer = Path()
      ..moveTo(center.dx - 13, center.dy - radius - 24)
      ..lineTo(center.dx + 13, center.dy - radius - 24)
      ..lineTo(center.dx, center.dy - radius + 9)
      ..close();
    canvas.drawShadow(pointer, Colors.black, 5, true);
    canvas.drawPath(pointer, Paint()..color = const Color(0xffffe6a7));
  }

  @override
  bool shouldRepaint(covariant WheelPainter old) => true;
}
