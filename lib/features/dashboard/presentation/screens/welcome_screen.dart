import 'package:flutter/material.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';

/// Shown once, immediately after a brand-new user completes profile setup.
/// After [_kDisplayDuration] it signals [AuthCubit] that the welcome has been
/// seen, which causes [AuthGate] to rebuild and show the correct dashboard.
/// It does NOT push any route itself — routing is always owned by [AuthGate].
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.user, required this.onDone});
  final AppUser user;
  final VoidCallback onDone;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _kDisplayDuration = Duration(milliseconds: 1300);

  late final AnimationController _controller;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideUp = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInCubic));

    Future.delayed(_kDisplayDuration, () async {
      if (!mounted) return;
      await _controller.forward();
      if (!mounted) return;
      // Tell the caller the welcome has been acknowledged.
      // AuthGate will rebuild with correct dashboard state.
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final roleName = _roleLabel(user.role);
    final String subtitle = _subtitleFor(user);
    final content = _contentFor(user.role);
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return SlideTransition(
      position: _slideUp,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(content.icon, color: colorScheme.onSurface, size: 64),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome,',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    roleName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorScheme.onSurface.withAlpha(153),
                      fontSize: 15,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.onSurface.withAlpha(153),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _WelcomeContent _contentFor(UserRole role) {
    switch (role) {
      case UserRole.student:
        return const _WelcomeContent(icon: Icons.school_outlined);
      case UserRole.advisor:
        return const _WelcomeContent(
          icon: Icons.supervised_user_circle_outlined,
        );
      case UserRole.hod:
        return const _WelcomeContent(icon: Icons.account_balance_outlined);
      case UserRole.subjectTeacher:
        return const _WelcomeContent(icon: Icons.menu_book_outlined);
    }
  }

  String _subtitleFor(AppUser user) {
    switch (user.role) {
      case UserRole.student:
        final parts = <String>[
          if (user.dept != null && user.dept!.isNotEmpty) user.dept!,
          if (user.batch != null && user.batch!.isNotEmpty) user.batch!,
        ];
        return parts.join(' · ');
      case UserRole.advisor:
      case UserRole.hod:
        return (user.dept != null && user.dept!.isNotEmpty) ? user.dept! : '';
      case UserRole.subjectTeacher:
        return '';
    }
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.student:
        return 'Student';
      case UserRole.advisor:
        return 'Class Advisor';
      case UserRole.hod:
        return 'Head of Department';
      case UserRole.subjectTeacher:
        return 'Subject Teacher';
    }
  }
}

class _WelcomeContent {
  const _WelcomeContent({required this.icon});
  final IconData icon;
}
