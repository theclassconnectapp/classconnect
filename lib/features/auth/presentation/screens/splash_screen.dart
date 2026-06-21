import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../controllers/auth_controller.dart';

/// Animated splash screen.
/// Always shown first. Once the animation finishes it calls
/// AuthCubit.splashComplete() — which releases whatever auth state was
/// resolved while the animation played, making AuthGate transition naturally.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _circleScale;
  late final Animation<double> _textOpacity;
  late final Animation<double> _textOffset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _circleScale = Tween<double>(begin: 0.01, end: 35).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.65, curve: Curves.easeInOutCubic),
      ),
    );
    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.8, curve: Curves.easeOut),
      ),
    );
    _textOffset = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward().whenComplete(() {
      if (!mounted) return;
      // Tell AuthCubit the splash animation is done.
      // This releases the pending auth state → AuthGate rebuilds.
      context.read<AuthCubit>().splashComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor = isDark ? Colors.black : Colors.white;
    final Color circleColor = isDark ? Colors.white : Colors.black;
    final Color textColor = backgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: _circleScale.value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: circleColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, _textOffset.value + 8),
                  child: Opacity(
                    opacity: _textOpacity.value,
                    child: Text(
                      'Class Connect',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 24,
                        fontFamily: 'Podkova',
                        fontWeight: FontWeight.w400,
                        height: 1.0,
                        shadows: const [
                          Shadow(
                            offset: Offset(0, 4),
                            blurRadius: 4,
                            color: Color(0x40000000),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
