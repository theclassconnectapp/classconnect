import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/screens/profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.user});

  final AppUser user;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 1;

  Widget _chatTab() {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: colorScheme.onSurface.withValues(alpha: 0.54)),
            const SizedBox(height: 16),
            Text('Private chat',
                style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Coming soon', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.60), fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _homeTab() {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: const SizedBox.expand(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      _chatTab(),
      _homeTab(),
      ProfileScreen(
        user: widget.user,
        onSignOut: () => context.read<AuthCubit>().signOut(),
      ),
    ];

    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(index: _selectedIndex, children: tabs),
      bottomNavigationBar: Container(
        color: colorScheme.surface,
        child: Row(
          children: [
            _NavItem(
              icon: Icons.chat_bubble_outline,
              label: 'Chat',
              selected: _selectedIndex == 0,
              onTap: () => setState(() => _selectedIndex = 0),
            ),
            _NavItem(
              icon: Icons.home_outlined,
              label: 'Home',
              selected: _selectedIndex == 1,
              onTap: () => setState(() => _selectedIndex = 1),
            ),
            _NavItem(
              icon: Icons.person_outline,
              label: 'Profile',
              selected: _selectedIndex == 2,
              onTap: () => setState(() => _selectedIndex = 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          color: selected ? colorScheme.primary : colorScheme.surface,
          padding: EdgeInsets.only(
            top: 10,
            bottom: 10 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 26, color: selected ? colorScheme.onPrimary : colorScheme.onSurface),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 11, color: selected ? colorScheme.onPrimary : colorScheme.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}
