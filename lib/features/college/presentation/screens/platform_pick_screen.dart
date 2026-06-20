import 'package:flutter/material.dart';
import '../../../public_home/presentation/screens/public_home_screen.dart';

import 'college_pick_screen.dart';

class PlatformPickScreen extends StatelessWidget {
  const PlatformPickScreen({
    super.key,
    required this.onCollegePicked,
    required this.onTuitionPicked,
  });

  final ValueChanged<String> onCollegePicked;
  final VoidCallback onTuitionPicked;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'Class Connect',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose your platform',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.70),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),
              _PlatformCard(
                icon: Icons.account_balance_rounded,
                label: 'College',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CollegePickScreen(
                        onPicked: onCollegePicked,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _PlatformCard(
                icon: Icons.school_rounded,
                label: 'School',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Coming Soon — only College is available right now'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _PlatformCard(
                icon: Icons.menu_book_rounded,
                label: 'Tuition',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Coming Soon — only College is available right now'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PublicHomeScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'Skip for now',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformCard extends StatelessWidget {
  const _PlatformCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.primary, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.38)),
          ],
        ),
      ),
    );
  }
}