import 'package:flutter/material.dart';

/// Keeps all [children] mounted for state preservation while cross-fading the
/// active tab.
class TabCrossfadeStack extends StatelessWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const TabCrossfadeStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 220),
  });

  @override
  Widget build(BuildContext context) {
    assert(children.isNotEmpty);
    final safeIndex = index.clamp(0, children.length - 1);

    return Stack(
      fit: StackFit.expand,
      children: List.generate(children.length, (i) {
        final selected = i == safeIndex;
        return Positioned.fill(
          child: IgnorePointer(
            ignoring: !selected,
            child: AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: duration,
              curve: Curves.easeInOut,
              child: TickerMode(
                enabled: selected,
                child: children[i],
              ),
            ),
          ),
        );
      }),
    );
  }
}
