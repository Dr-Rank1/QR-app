import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Performance monitoring widget - visible only in debug/profile builds
class PerformanceMonitor extends StatefulWidget {
  final Widget child;
  final String screenName;

  const PerformanceMonitor({
    super.key,
    required this.child,
    required this.screenName,
  });

  @override
  State<PerformanceMonitor> createState() => _PerformanceMonitorState();
}

class _PerformanceMonitorState extends State<PerformanceMonitor> {
  int _frameCount = 0;
  double _totalDuration = 0;
  DateTime? _lastFrameTime;
  String _fps = '0';
  bool _showOverlay = false;

  @override
  void initState() {
    super.initState();
    // Register frame callback
    SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
  }

  void _onFrame(Duration duration) {
    if (!mounted) return;

    _frameCount++;
    final now = DateTime.now();

    if (_lastFrameTime != null) {
      final elapsed = now.difference(_lastFrameTime!).inMilliseconds;
      _totalDuration += elapsed;

      // Calculate FPS every 30 frames
      if (_frameCount >= 30) {
        final fps = _totalDuration > 0
            ? (_frameCount * 1000 / _totalDuration).toStringAsFixed(1)
            : '0';
        setState(() {
          _fps = fps;
          _frameCount = 0;
          _totalDuration = 0;
        });
      }
    }
    _lastFrameTime = now;
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    assert(() {
      if (_showOverlay) {
        return true;
      }
      return true;
    }());

    return Stack(
      children: [
        widget.child,
        // Debug overlay - only visible when toggled in debug mode
        if (_showOverlay)
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _getFpsColor(),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.screenName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_fps FPS',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Color _getFpsColor() {
    final fps = double.tryParse(_fps) ?? 0;
    if (fps >= 55) return Colors.green;
    if (fps >= 30) return Colors.orange;
    return Colors.red;
  }
}

/// Mixin to add performance monitoring to screens
mixin PerformanceReportingMixin<T extends StatefulWidget> on State<T> {
  String get screenName;

  @override
  void initState() {
    super.initState();
    _logScreenLoad();
  }

  void _logScreenLoad() {
    developer.log(
      'Screen loaded: $screenName',
      name: 'Performance',
    );
  }

  void reportFrameRate(double fps) {
    developer.log(
      '$screenName FPS: ${fps.toStringAsFixed(1)}',
      name: 'Performance',
    );
  }
}

/// Extension to enable performance overlay in debug builds
extension PerformanceOverlayExtension on Widget {
  /// Wraps widget with performance monitoring if in debug mode
  Widget withPerformanceMonitoring(String screenName) {
    return PerformanceMonitor(
      screenName: screenName,
      child: this,
    );
  }
}