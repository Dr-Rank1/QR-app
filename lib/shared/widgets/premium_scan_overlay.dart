import 'dart:ui';

import 'package:flutter/material.dart';

class PremiumScanOverlay extends StatefulWidget {
  final double width;
  final double height;
  final Color primaryColor;
  final Color scanAreaColor;

  const PremiumScanOverlay({
    super.key,
    required this.width,
    required this.height,
    this.primaryColor = const Color(0xFF6750A4),
    this.scanAreaColor = Colors.black54,
  });

  @override
  State<PremiumScanOverlay> createState() => _PremiumScanOverlayState();
}

class _PremiumScanOverlayState extends State<PremiumScanOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scanLineController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();
    
    // Pulse animation for corner brackets
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    _pulseController.repeat(reverse: true);

    // Scan line animation (top to bottom bounce)
    _scanLineController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scanLineController,
        curve: Curves.easeInOut,
      ),
    );
    _scanLineController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dimmed background with scan window cutout
        _DimmedBackground(
          width: widget.width,
          height: widget.height,
          scanColor: widget.scanAreaColor,
        ),

        // Corner brackets with pulse animation
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return _CornerBrackets(
              width: widget.width * 0.7,
              height: widget.height * 0.5,
              color: widget.primaryColor,
              scale: _pulseAnimation.value,
            );
          },
        ),

        // Laser scan line
        AnimatedBuilder(
          animation: _scanLineAnimation,
          builder: (context, child) {
            return _LaserScanLine(
              width: widget.width * 0.7,
              height: widget.height * 0.5,
              color: widget.primaryColor,
              progress: _scanLineAnimation.value,
            );
          },
        ),
      ],
    );
  }
}

class _DimmedBackground extends StatelessWidget {
  final double width;
  final double height;
  final Color scanColor;

  const _DimmedBackground({
    required this.width,
    required this.height,
    required this.scanColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _DimmedBackgroundPainter(scanColor: scanColor),
    );
  }
}

class _DimmedBackgroundPainter extends CustomPainter {
  final Color scanColor;

  _DimmedBackgroundPainter({required this.scanColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = scanColor
      ..style = PaintingStyle.fill;

    final scanWidth = size.width * 0.7;
    final scanHeight = size.height * 0.5;
    final left = (size.width - scanWidth) / 2;
    final top = (size.height - scanHeight) / 2;
    final borderRadius = 12.0;

    // Create path for the full screen (rect with hole)
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, scanWidth, scanHeight),
          Radius.circular(borderRadius),
        ),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CornerBrackets extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final double scale;

  const _CornerBrackets({
    required this.width,
    required this.height,
    required this.color,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final cornerLength = 30.0 * scale;
    final strokeWidth = 4.0;
    final left = (widget.width - width) / 2;
    final top = (widget.height - height) / 2;

    return Positioned(
      left: left,
      top: top,
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _CornerBracketsPainter(
            color: color,
            cornerLength: cornerLength,
            strokeWidth: strokeWidth,
          ),
        ),
      ),
    );
  }
}

class _CornerBracketsPainter extends CustomPainter {
  final Color color;
  final double cornerLength;
  final double strokeWidth;

  _CornerBracketsPainter({
    required this.color,
    required this.cornerLength,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(Offset(0, cornerLength), Offset(0, 0), paint);
    canvas.drawLine(Offset(0, 0), Offset(cornerLength, 0), paint);

    // Top-right
    canvas.drawLine(
      Offset(size.width - cornerLength, 0),
      Offset(size.width, 0),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, cornerLength),
      paint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(0, size.height - cornerLength),
      Offset(0, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(cornerLength, size.height),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(size.width - cornerLength, size.height),
      Offset(size.width, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerBracketsPainter oldDelegate) {
    return oldDelegate.cornerLength != cornerLength;
  }
}

class _LaserScanLine extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final double progress;

  const _LaserScanLine({
    required this.width,
    required this.height,
    required this.color,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final left = (widget.width - width) / 2;
    final top = (widget.height - height) / 2;
    final y = top + (height * progress);

    return RepaintBoundary(
      child: CustomPaint(
        size: Size(widget.width, widget.height),
        painter: _LaserPainter(
          color: color,
          y: y,
          width: width,
          height: height,
        ),
      ),
    );
  }
}

class _LaserPainter extends CustomPainter {
  final Color color;
  final double y;
  final double width;
  final double height;

  _LaserPainter({
    required this.color,
    required this.y,
    required this.width,
    required this.height,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Gradient laser line
    final gradient = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.8),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, y - 20, width, 40));

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw the laser line
    canvas.drawLine(
      Offset((size.width - width) / 2 + 4, y),
      Offset((size.width + width) / 2 - 4, y),
      gradient,
    );

    // Draw glow effect
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawLine(
      Offset((size.width - width) / 2 + 4, y),
      Offset((size.width + width) / 2 - 4, y),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LaserPainter oldDelegate) {
    return oldDelegate.y != y;
  }
}