import 'package:flutter/material.dart';

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
    this.scanAreaColor = Colors.black54,
    this.scanLineColor = const Color(0xFF6750A4),
    this.borderLength = 30,
    this.borderWidth = 4,
    this.detected = false,
  });

  @override
  State<ScanOverlay> createState() => _ScanOverlayState();
}

class _ScanOverlayState extends State<ScanOverlay>
    with TickerProviderStateMixin {
  late AnimationController _scanLineController;
  late AnimationController _successController;
  late Animation<double> _scanLineAnimation;
  late Animation<double> _successAnimation;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _scanLineAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );
    _scanLineController.repeat(reverse: true);

    _successController = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    );
    _successAnimation = CurvedAnimation(
      parent: _successController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void didUpdateWidget(ScanOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.detected && !oldWidget.detected) {
      _successController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scanWidth = widget.width * 0.7;
    final scanHeight = widget.height * 0.5;
    final left = (widget.width - scanWidth) / 2;
    final top = (widget.height - scanHeight) / 2;

    return AnimatedBuilder(
      animation: _successAnimation,
      builder: (context, child) {
        final success = _successAnimation.value;
        final pulse = 1 + (0.04 * (1 - (success - 0.5).abs() * 2).clamp(0.0, 1.0));
        final bracketInset = 10 * success;
        final glowOpacity = 0.45 * (1 - success);

        return Stack(
          children: [
            CustomPaint(
              size: Size(widget.width, widget.height),
              painter: _ScanWindowPainter(scanAreaColor: widget.scanAreaColor),
            ),
            if (glowOpacity > 0.01)
              Positioned(
                left: left - 8,
                top: top - 8,
                child: Transform.scale(
                  scale: pulse,
                  child: Container(
                    width: scanWidth + 16,
                    height: scanHeight + 16,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: widget.scanLineColor.withValues(alpha: glowOpacity),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              left: left,
              top: top,
              child: Transform.scale(
                scale: pulse,
                child: SizedBox(
                  width: scanWidth,
                  height: scanHeight,
                  child: CustomPaint(
                    painter: _CornerBracketsPainter(
                      color: widget.scanLineColor,
                      borderLength: widget.borderLength - bracketInset,
                      borderWidth: widget.borderWidth,
                      inset: bracketInset,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: left + widget.borderWidth,
              top: top + widget.borderWidth,
              child: SizedBox(
                width: scanWidth - widget.borderWidth * 2,
                height: scanHeight - widget.borderWidth * 2,
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
      },
    );
  }
}

class _ScanWindowPainter extends CustomPainter {
  final Color scanAreaColor;

  _ScanWindowPainter({required this.scanAreaColor});

  @override
  void paint(Canvas canvas, Size size) {
    final scanWidth = size.width * 0.7;
    final scanHeight = size.height * 0.5;
    final left = (size.width - scanWidth) / 2;
    final top = (size.height - scanHeight) / 2;

    final outer = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final inner = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, scanWidth, scanHeight),
          const Radius.circular(32),
        ),
      );

    canvas.drawPath(
      Path.combine(PathOperation.difference, outer, inner),
      Paint()..color = scanAreaColor,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CornerBracketsPainter extends CustomPainter {
  final Color color;
  final double borderLength;
  final double borderWidth;
  final double inset;

  _CornerBracketsPainter({
    required this.color,
    required this.borderLength,
    required this.borderWidth,
    this.inset = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final len = borderLength.clamp(12, 40);
    final i = inset;

    void corner(Offset start, Offset elbow, Offset end) {
      canvas.drawLine(start, elbow, paint);
      canvas.drawLine(elbow, end, paint);
    }

    corner(Offset(i, i + len), Offset(i, i), Offset(i + len, i));
    corner(Offset(w - i - len, i), Offset(w - i, i), Offset(w - i, i + len));
    corner(Offset(i, h - i - len), Offset(i, h - i), Offset(i + len, h - i));
    corner(Offset(w - i - len, h - i), Offset(w - i, h - i), Offset(w - i, h - i - len));
  }

  @override
  bool shouldRepaint(covariant _CornerBracketsPainter oldDelegate) {
    return oldDelegate.borderLength != borderLength ||
        oldDelegate.inset != inset ||
        oldDelegate.color != color;
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

    final gradient = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: opacity),
          color.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, y - 20, size.width, 40));

    canvas.drawLine(Offset(0, y), Offset(size.width, y), gradient);
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.opacity != opacity;
  }
}
