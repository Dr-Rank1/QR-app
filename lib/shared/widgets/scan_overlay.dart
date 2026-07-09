import 'package:flutter/material.dart';

/// Monochrome scan viewport: dark mask, white corner brackets, moving scan line.
class ScanOverlay extends StatefulWidget {
  final double width;
  final double height;
  final Color scanAreaColor;
  final Color scanLineColor;
  final double borderLength;
  final double borderWidth;
  final bool detected;

  const ScanOverlay({
    super.key,
    required this.width,
    required this.height,
    this.scanAreaColor = const Color(0x8C000000),
    this.scanLineColor = Colors.white,
    this.borderLength = 40,
    this.borderWidth = 3,
    this.detected = false,
  });

  @override
  State<ScanOverlay> createState() => _ScanOverlayState();
}

class _ScanOverlayState extends State<ScanOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    );
    _scanLineAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );
    _scanLineController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const frameSize = 224.0;
    final left = (widget.width - frameSize) / 2;
    final top = (widget.height - frameSize) / 2;

    return Stack(
      children: [
        CustomPaint(
          size: Size(widget.width, widget.height),
          painter: _ScanWindowPainter(
            scanAreaColor: widget.scanAreaColor,
            frameSize: frameSize,
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: SizedBox(
            width: frameSize,
            height: frameSize,
            child: CustomPaint(
              painter: _CornerBracketsPainter(
                color: widget.scanLineColor,
                borderLength: widget.borderLength,
                borderWidth: widget.borderWidth,
              ),
            ),
          ),
        ),
        Positioned(
          left: left + 12,
          top: top + 12,
          child: SizedBox(
            width: frameSize - 24,
            height: frameSize - 24,
            child: AnimatedBuilder(
              animation: _scanLineAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: _ScanLinePainter(
                    color: widget.scanLineColor,
                    progress: _scanLineAnimation.value,
                    opacity: widget.detected ? 0.35 : 1,
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
  final double frameSize;

  _ScanWindowPainter({
    required this.scanAreaColor,
    required this.frameSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final left = (size.width - frameSize) / 2;
    final top = (size.height - frameSize) / 2;

    final outer = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final inner = Path()
      ..addRect(Rect.fromLTWH(left, top, frameSize, frameSize));

    canvas.drawPath(
      Path.combine(PathOperation.difference, outer, inner),
      Paint()..color = scanAreaColor,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanWindowPainter oldDelegate) {
    return oldDelegate.scanAreaColor != scanAreaColor ||
        oldDelegate.frameSize != frameSize;
  }
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
      ..strokeCap = StrokeCap.square;

    final w = size.width;
    final h = size.height;
    final len = borderLength.clamp(24.0, 48.0);

    void corner(Offset a, Offset b, Offset c) {
      canvas.drawLine(a, b, paint);
      canvas.drawLine(b, c, paint);
    }

    corner(Offset(0, len), Offset.zero, Offset(len, 0));
    corner(Offset(w - len, 0), Offset(w, 0), Offset(w, len));
    corner(Offset(0, h - len), Offset(0, h), Offset(len, h));
    corner(Offset(w - len, h), Offset(w, h), Offset(w, h - len));
  }

  @override
  bool shouldRepaint(covariant _CornerBracketsPainter oldDelegate) {
    return oldDelegate.borderLength != borderLength ||
        oldDelegate.color != color ||
        oldDelegate.borderWidth != borderWidth;
  }
}

class _ScanLinePainter extends CustomPainter {
  final Color color;
  final double progress;
  final double opacity;

  _ScanLinePainter({
    required this.color,
    required this.progress,
    this.opacity = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.opacity != opacity;
  }
}
