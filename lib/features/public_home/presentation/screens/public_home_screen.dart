import 'package:flutter/material.dart';

class PublicHomeScreen extends StatefulWidget {
  const PublicHomeScreen({super.key});

  @override
  State<PublicHomeScreen> createState() => _PublicHomeScreenState();
}

class _PublicHomeScreenState extends State<PublicHomeScreen> {
  int _selectedIndex = 1;

  Widget _homeTab() {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'Class Connect',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                'Public access',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.explore_outlined,
                      color: colorScheme.onSurface.withAlpha(138),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Browsing as guest',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.onSurface.withAlpha(179),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pick your college to unlock semesters, groups, and chat',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.onSurface.withAlpha(140),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Choose your college'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _comingSoonTab() {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: colorScheme.onSurface.withValues(alpha: 0.54),
          ),
          const SizedBox(height: 16),
          Text(
            'Private chat',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to access chat',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.60),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _signInTab() {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_outline,
            size: 48,
            color: colorScheme.onSurface.withValues(alpha: 0.54),
          ),
          const SizedBox(height: 16),
          Text(
            "You're browsing as a guest",
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [_comingSoonTab(), _homeTab(), _signInTab()];
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Stack + AnimatedOpacity instead of plain IndexedStack:
      // keeps every tab mounted but crossfades the visible one
      // instead of snapping instantly.
      body: Stack(
        children: List.generate(tabs.length, (i) {
          final bool isActive = _selectedIndex == i;
          return AnimatedOpacity(
            opacity: isActive ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: IgnorePointer(ignoring: !isActive, child: tabs[i]),
          );
        }),
      ),
      bottomNavigationBar: Container(
        color: colorScheme.primary,
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
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          color: selected ? colorScheme.primary : colorScheme.surface,
          padding: EdgeInsets.only(
            top: 10,
            bottom: 10 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: selected ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: Icon(
                  icon,
                  size: 26,
                  color: selected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? colorScheme.primary : colorScheme.onPrimary,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
