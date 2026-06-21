import 'package:flutter/material.dart';

/// Shared motion constants and reusable animated widgets.
/// Every screen in the college feature set should use these instead of
/// inventing its own durations/curves, so motion feels consistent
/// app-wide.
class Motion {
  Motion._();

  // Tab switches, content crossfades
  static const Duration tabSwitch = Duration(milliseconds: 200);
  // Button press feedback
  static const Duration buttonDown = Duration(milliseconds: 100);
  static const Duration buttonUp = Duration(milliseconds: 150);
  // Loading -> content fade-in
  static const Duration loadFade = Duration(milliseconds: 250);
  // Staggered list item entrance
  static const Duration listItem = Duration(milliseconds: 200);
  static const Duration listItemStagger = Duration(milliseconds: 30);

  static const Curve standard = Curves.easeOut;
}

/// Fades (and very slightly slides up) a child into view once, on first
/// build. Use for loading->content transitions and list items.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = Motion.loadFade,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _controller, curve: Motion.standard);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Motion.standard));
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Wraps a tappable widget (button, card) with a subtle scale-down-on-press
/// effect for tactile feedback. Use instead of a bare GestureDetector/
/// InkWell when you want the press itself to feel responsive.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  double _scale = 1.0;

  void _setScale(double value) {
    if (widget.onTap == null) return;
    setState(() => _scale = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setScale(0.96),
      onTapUp: (_) => _setScale(1.0),
      onTapCancel: () => _setScale(1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: _scale == 1.0 ? Motion.buttonUp : Motion.buttonDown,
        curve: Motion.standard,
        child: widget.child,
      ),
    );
  }
}

/// Applies a staggered FadeSlideIn to each item in a list, based on index.
/// Use inside itemBuilder:
///   itemBuilder: (context, index) => StaggeredListItem(
///     index: index,
///     child: YourCardWidget(...),
///   )
class StaggeredListItem extends StatelessWidget {
  const StaggeredListItem({
    super.key,
    required this.index,
    required this.child,
    this.maxDelay = const Duration(milliseconds: 300),
  });

  final int index;
  final Widget child;
  final Duration maxDelay;

  @override
  Widget build(BuildContext context) {
    final int cappedIndex = index > 10 ? 10 : index;
    final Duration delay = Motion.listItemStagger * cappedIndex;
    return FadeSlideIn(
      delay: delay,
      duration: Motion.listItem,
      child: child,
    );
  }
}
