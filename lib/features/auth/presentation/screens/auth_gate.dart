import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/di/injection_container.dart';
import '../../../college/presentation/screens/platform_pick_screen.dart';
import '../../../college/domain/repositories/college_repository.dart'
    as college_domain;
import '../../../dashboard/presentation/screens/welcome_screen.dart';
import '../../../dashboard/presentation/screens/student_home_screen.dart';
import '../../../tuition/presentation/screens/home_shell.dart';
import '../../../dashboard/presentation/screens/advisor_home_screen.dart';
import '../../../dashboard/presentation/screens/hod_home_screen.dart';
import '../../../dashboard/presentation/screens/sub_teacher_home_screen.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/usecases/verify_role_code.dart';
import '../controllers/auth_controller.dart';
import 'role_pick_screen.dart';
import 'role_code_screen.dart';
import 'profile_setup_screen.dart';
import 'splash_screen.dart';

/// Single source of truth for which screen is shown.
/// Every transition is driven by AuthCubit state — no manual Navigator calls.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        // 1. Loading OR splash animation still playing → always show splash.
        if (state is AuthLoading) {
          return const SplashScreen();
        }

        // 2. Not signed in.
        if (state is AuthUnauthenticated) {
          return const _SignInScreen();
        }

        // 3. Signed in but no college chosen (truly first-time ever).
        if (state is AuthNeedsCollegePick) {
          return PlatformPickScreen(
            onCollegePicked: (collegeId) =>
                context.read<AuthCubit>().onCollegePicked(collegeId),
            onTuitionPicked: () => context.read<AuthCubit>().onTuitionPicked(),
          );
        }

        if (state is AuthNeedsTuitionHome) {
          return HomeShell(user: state.user);
        }

        // 4. College chosen but no Firestore profile → full onboarding.
        if (state is AuthNeedsProfileSetup) {
          return _OnboardingFlow(firebaseUser: state.firebaseUser);
        }

        if (state is AuthNeedsWelcomeBack) {
          return WelcomeScreen(
            user: state.user,
            onDone: () => context.read<AuthCubit>().welcomeBackSeen(),
          );
        }

        // 5. Fully authenticated.
        if (state is AuthAuthenticated) {
          if (state.isNewUser) {
            // Brand-new user just finished setup → welcome splash then dashboard.
            return WelcomeScreen(
              user: state.user,
              onDone: () => context.read<AuthCubit>().welcomeSeen(),
            );
          }
          // Returning user → straight to their dashboard.
          return _dashboardFor(state.user);
        }

        return const SplashScreen();
      },
    );
  }

  static Widget _dashboardFor(AppUser user) {
    switch (user.role) {
      case UserRole.student:
        return StudentHomeScreen(user: user);
      case UserRole.advisor:
        return AdvisorHomeScreen(user: user);
      case UserRole.hod:
        return HodHomeScreen(user: user);
      case UserRole.subjectTeacher:
        return SubTeacherHomeScreen(user: user);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _OnboardingFlow — first-time only
// RolePickScreen → RoleCodeScreen (non-students) → ProfileSetupScreen
// ─────────────────────────────────────────────────────────────────────────────

class _OnboardingFlow extends StatefulWidget {
  const _OnboardingFlow({required this.firebaseUser});
  final User firebaseUser;

  @override
  State<_OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<_OnboardingFlow> {
  _OnboardingStep _step = _OnboardingStep.rolePick;
  UserRole? _pickedRole;

  void _onRolePicked(UserRole role) {
    setState(() {
      _pickedRole = role;
      _step = role == UserRole.student
          ? _OnboardingStep.profileSetup
          : _OnboardingStep.roleCode;
    });
  }

  void _backToRolePick() {
    setState(() {
      _step = _OnboardingStep.rolePick;
      _pickedRole = null;
    });
  }

  void _backToRoleCode() {
    setState(() => _step = _OnboardingStep.roleCode);
  }

  Future<void> _finish(AppUser profile) async {
    final UserRepository userRepo = sl<UserRepository>();
    await userRepo.saveUser(profile);
    if (!mounted) return;
    context.read<AuthCubit>().onProfileSaved(profile);
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _OnboardingStep.rolePick:
        return RolePickScreen(onRoleSelected: _onRolePicked);

      case _OnboardingStep.roleCode:
        return RoleCodeScreen(
          role: _pickedRole!,
          verifyRoleCode: sl<VerifyRoleCode>(),
          onRoleVerified: (UserRole role) {
            setState(() {
              _pickedRole = role;
              _step = _OnboardingStep.profileSetup;
            });
          },
          onBack: _backToRolePick,
        );

      case _OnboardingStep.profileSetup:
        return ProfileSetupScreen(
          role: _pickedRole!,
          firebaseUser: widget.firebaseUser,
          collegeRepository: sl<college_domain.CollegeRepository>(),
          onSaved: _finish,
          onBack: _pickedRole == UserRole.student
              ? _backToRolePick
              : _backToRoleCode,
        );
    }
  }
}

enum _OnboardingStep { rolePick, roleCode, profileSetup }

// ─────────────────────────────────────────────────────────────────────────────
// _SignInScreen — with smooth fade+slide entrance
// ─────────────────────────────────────────────────────────────────────────────

class _SignInScreen extends StatefulWidget {
  const _SignInScreen();

  @override
  State<_SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<_SignInScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<double>(
      begin: 24,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Opacity(
                opacity: _fadeAnim.value,
                child: Transform.translate(
                  offset: Offset(0, _slideAnim.value),
                  child: child,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.school_rounded,
                    color: colorScheme.onSurface,
                    size: 80,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Class Connect',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Podkova',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your campus, connected.',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.60),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 48),
                  _GoogleSignInButton(
                    onTap: () => context.read<AuthCubit>().signInWithGoogle(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _GoogleSignInButton
// ─────────────────────────────────────────────────────────────────────────────

class _GoogleSignInButton extends StatefulWidget {
  const _GoogleSignInButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton> {
  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return PressableScale(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomPaint(
              size: const Size.square(22),
              painter: const _GoogleLogoPainter(),
            ),
            const SizedBox(width: 12),
            Text(
              'Continue with Google',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static const Color _blue = Color(0xFF4285F4);
  static const Color _red = Color(0xFFEA4335);
  static const Color _yellow = Color(0xFFFBBC05);
  static const Color _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = size.width * 0.18;
    final Rect arcRect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    void drawArc(Color color, double startDegrees, double sweepDegrees) {
      paint.color = color;
      canvas.drawArc(
        arcRect,
        startDegrees * 3.141592653589793 / 180,
        sweepDegrees * 3.141592653589793 / 180,
        false,
        paint,
      );
    }

    drawArc(_blue, -38, 74);
    drawArc(_red, -150, 112);
    drawArc(_yellow, 142, 72);
    drawArc(_green, 45, 97);

    paint
      ..color = _blue
      ..strokeCap = StrokeCap.square;
    final Offset center = Offset(size.width / 2, size.height / 2);
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(size.width * 0.88, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.88, center.dy),
      Offset(size.width * 0.88, size.height * 0.66),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleLogoPainter oldDelegate) => false;
}
