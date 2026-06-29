import 'package:flutter/material.dart';

class ScanOverlay extends StatefulWidget {
  final double width;
  final double height;
  final Color scanAreaColor;
  final Color scanLineColor;
  final double borderLength;
  final double borderWidth;

  const ScanOverlay({
    super.key,
    required this.width,
    required this.height,
    this.scanAreaColor = Colors.black54,
    this.scanLineColor = const Color(0xFF6750A4),
    this.borderLength = 30,
    this.borderWidth = 4,
  });

  @override
  State<ScanOverlay> createState() => _ScanOverlayState();
}

class _ScanOverlayState extends State<ScanOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Darkened area around scan window
        CustomPaint(
          size: Size(widget.width, widget.height),
          painter: _ScanWindowPainter(
            scanAreaColor: widget.scanAreaColor,
          ),
        ),
        // Corner brackets
        Positioned(
          left: (widget.width - widget.width * 0.7) / 2,
          top: (widget.height - widget.height * 0.5) / 2,
          child: SizedBox(
            width: widget.width * 0.7,
            height: widget.height * 0.5,
            child: CustomPaint(
              painter: _CornerBracketsPainter(
                color: widget.scanLineColor,
                borderLength: widget.borderLength,
                borderWidth: widget.borderWidth,
              ),
            ),
          ),
        ),
        // Animated scan line
        Positioned(
          left: (widget.width - widget.width * 0.7) / 2 + widget.borderWidth,
          top: (widget.height - widget.height * 0.5) / 2 + widget.borderWidth,
          child: SizedBox(
            width: widget.width * 0.7 - widget.borderWidth * 2,
            height: widget.height * 0.5 - widget.borderWidth * 2,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return CustomPaint(
                  painter: _ScanLinePainter(
                    color: widget.scanLineColor,
                    progress: _animation.value,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanWindowPainter extends CustomPainter {
  final Color scanAreaColor;

  _ScanWindowPainter({required this.scanAreaColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = scanAreaColor;
    final scanWidth = size.width * 0.7;
    final scanHeight = size.height * 0.5;
    final left = (size.width - scanWidth) / 2;
    final top = (size.height - scanHeight) / 2;

    // Draw full screen
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );

    // Cut out the scan window (using clear blend mode)
    final clearPaint = Paint()
      ..blendMode = BlendMode.clear
      ..color = Colors.transparent;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, scanWidth, scanHeight),
        const Radius.circular(12),
      ),
      clearPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CornerBracketsPainter extends CustomPainter {
  final Color color;
  final double borderLength;
  final double borderWidth;

  _CornerBracketsPainter({
    required this.color,
    required this.borderLength,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final scanWidth = size.width;
    final scanHeight = size.height;

    // Top-left corner
    canvas.drawLine(
      Offset(0, borderLength),
      Offset(0, 0),
      paint,
    );
    canvas.drawLine(
      Offset(0, 0),
      Offset(borderLength, 0),
      paint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(scanWidth - borderLength, 0),
      Offset(scanWidth, 0),
      paint,
    );
    canvas.drawLine(
      Offset(scanWidth, 0),
      Offset(scanWidth, borderLength),
      paint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(0, scanHeight - borderLength),
      Offset(0, scanHeight),
      paint,
    );
    canvas.drawLine(
      Offset(0, scanHeight),
      Offset(borderLength, scanHeight),
      paint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(scanWidth - borderLength, scanHeight),
      Offset(scanWidth, scanHeight),
      paint,
    );
    canvas.drawLine(
      Offset(scanWidth, scanHeight),
      Offset(scanWidth, scanHeight - borderLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScanLinePainter extends CustomPainter {
  final Color color;
  final double progress;

  _ScanLinePainter({
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;

    final gradient = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0),
          color,
          color.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, y - 20, size.width, 40));

    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      gradient,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}