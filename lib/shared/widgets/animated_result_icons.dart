import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/scanner/domain/enums/qr_result_type.dart';

class AnimatedResultIcon extends StatefulWidget {
  final QRResultType type;
  final double size;
  final Color color;

  const AnimatedResultIcon({
    super.key,
    required this.type,
    this.size = 48,
    required this.color,
  });

  @override
  State<AnimatedResultIcon> createState() => _AnimatedResultIconState();
}

class _AnimatedResultIconState extends State<AnimatedResultIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: _getDuration(),
      vsync: this,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Duration _getDuration() {
    switch (widget.type) {
      case QRResultType.url:
        return const Duration(seconds: 3);
      case QRResultType.wifi:
        return const Duration(milliseconds: 1500);
      case QRResultType.phone:
        return const Duration(milliseconds: 800);
      case QRResultType.email:
        return const Duration(milliseconds: 1200);
      case QRResultType.text:
        return const Duration(seconds: 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _AnimatedIconPainter(
            type: widget.type,
            color: widget.color,
            progress: _controller.value,
          ),
        );
      },
    );
  }
}

class _AnimatedIconPainter extends CustomPainter {
  final QRResultType type;
  final Color color;
  final double progress;

  _AnimatedIconPainter({
    required this.type,
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (type) {
      case QRResultType.url:
        _paintGlobe(canvas, size, paint);
        break;
      case QRResultType.wifi:
        _paintWifiSignal(canvas, size, paint);
        break;
      case QRResultType.phone:
        _paintPhoneRing(canvas, size, paint);
        break;
      case QRResultType.email:
        _paintEnvelope(canvas, size, paint);
        break;
      case QRResultType.text:
        _paintTyping(cursorPaint(canvas, size), size);
        break;
    }
  }

  void _paintGlobe(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.35;

    // Globe circle
    canvas.drawCircle(center, radius, paint);

    // Rotating lines
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final rotation = progress * 2 * math.pi;
    
    // Draw meridian lines
    for (var i = 0; i < 3; i++) {
      final angle = rotation + (i * math.pi / 3);
      final path = Path();
      path.moveTo(
        center.dx + radius * math.sin(angle),
        center.dy - radius * math.cos(angle),
      );
      path.lineTo(
        center.dx + radius * math.sin(angle + math.pi),
        center.dy + radius * math.cos(angle),
      );
      canvas.drawPath(path, linePaint);
    }

    // Draw equator
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      linePaint,
    );
  }

  void _paintWifiSignal(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width / 2, size.height * 0.8);
    final maxRadius = size.width * 0.4;

    // Draw 3 signal arcs
    for (var i = 0; i < 3; i++) {
      final arcProgress = (progress * 3 - i).clamp(0.0, 1.0);
      if (arcProgress <= 0) continue;

      final radius = maxRadius * (i + 1) / 3;
      final rect = Rect.fromCircle(
        center: center,
        radius: radius,
      );

      canvas.drawArc(
        rect,
        -math.pi,
        math.pi * arcProgress,
        false,
        paint..strokeWidth = 3,
      );
    }
  }

  void _paintPhoneRing(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = 0.3 + (progress * 0.2);

    // Phone icon
    final path = Path();
    final w = size.width * 0.3 * scale;
    final h = size.height * 0.5 * scale;
    
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: w,
        height: h,
      ),
      Radius.circular(w * 0.2),
    ));
    canvas.drawPath(path, paint);

    // Animated ring effect
    final ringPaint = Paint()
      ..color = color.withValues(alpha: (1 - progress) * 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(
      center,
      size.width * 0.3 * (1 + progress * 0.5),
      ringPaint,
    );
  }

  void _paintEnvelope(Canvas canvas, Size size, Paint paint) {
    final w = size.width * 0.7;
    final h = size.height * 0.5;
    final rect = Rect.fromLTWH(
      (size.width - w) / 2,
      (size.height - h) / 2,
      w,
      h,
    );

    // Envelope body
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      paint,
    );

    // Animated flap (opens based on progress)
    if (progress > 0.3) {
      final flapPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      final openAmount = ((progress - 0.3) / 0.7).clamp(0.0, 1.0);
      final topPoint = Offset(size.width / 2, rect.top);
      final leftPoint = rect.bottomLeft;
      final rightPoint = rect.bottomRight;

      final flapPath = Path();
      flapPath.moveTo(leftPoint.dx, leftPoint.dy);

      // Animated triangle flap
      final midY = rect.top + (rect.height * 0.5 * openAmount);
      flapPath.lineTo(size.width / 2, midY);
      flapPath.lineTo(rightPoint.dx, rightPoint.dy);

      canvas.drawPath(flapPath, flapPaint);
    }
  }

  Paint cursorPaint(Canvas canvas, Size size) {
    final cursorPaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    return cursorPaint;
  }

  void _paintTyping(Paint cursorPaint, Size size) {
    // Text lines
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final lineHeight = 4.0;
    final lineSpacing = 10.0;
    final startY = (size.height - lineSpacing * 2) / 2;

    // First line
    canvas.drawLine(
      Offset(4, startY),
      Offset(size.width * 0.6, startY),
      linePaint,
    );

    // Second line (shorter)
    canvas.drawLine(
      Offset(4, startY + lineSpacing),
      Offset(size.width * 0.4, startY + lineSpacing),
      linePaint,
    );

    // Third line with typing cursor animation
    final cursorX = 4 + (size.width * 0.5 * progress);
    canvas.drawLine(
      Offset(4, startY + lineSpacing * 2),
      Offset(cursorX, startY + lineSpacing * 2),
      cursorPaint,
    );

    // Blinking cursor effect
    if ((progress * 10).floor() % 2 == 0) {
      canvas.drawLine(
        Offset(cursorX, startY - 4),
        Offset(cursorX, startY + lineSpacing * 2 + 4),
        cursorPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AnimatedIconPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}