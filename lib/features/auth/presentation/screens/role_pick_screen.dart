import 'package:flutter/material.dart';
import '../../../../core/animation/motion.dart';
import '../../domain/entities/user_role.dart';

class RolePickScreen extends StatefulWidget {
  const RolePickScreen({super.key, required this.onRoleSelected, this.onBack});

  final VoidCallback? onBack;

  final ValueChanged<UserRole> onRoleSelected;

  @override
  State<RolePickScreen> createState() => _RolePickScreenState();
}

class _RolePickScreenState extends State<RolePickScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<double>(
      begin: 32,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const List<_RoleMeta> _roles = [
    _RoleMeta(UserRole.student, Icons.school_rounded, 'Student'),
    _RoleMeta(
      UserRole.subjectTeacher,
      Icons.menu_book_rounded,
      'Subject Teacher',
    ),
    _RoleMeta(UserRole.advisor, Icons.groups_rounded, 'Class Advisor'),
    _RoleMeta(UserRole.hod, Icons.account_balance_rounded, 'HOD'),
  ];

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    final screenW = mq.size.width;

    final isTablet = screenW >= 600;
    final horizontalPad = isTablet ? screenW * 0.12 : 20.0;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.onBack != null
            ? PressableScale(
                onTap: widget.onBack,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onBack,
                ),
              )
            : null,
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Opacity(
          opacity: _fadeAnim.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnim.value),
            child: child,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 28),
                _HeaderBanner(),
                const SizedBox(height: 28),
                Text(
                  'What describes you here?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Podkova',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Divider(thickness: 1, color: colorScheme.outlineVariant),
                const SizedBox(height: 20),
                Expanded(
                  child: _RoleGrid(
                    roles: _roles,
                    onRoleSelected: widget.onRoleSelected,
                    controller: _controller,
                    isTablet: isTablet,
                  ),
                ),
                const SizedBox(height: 16),
                Divider(
                  thickness: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your role determines your access level',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Podkova',
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.50),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HeaderBanner
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 20),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.30),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        'Welcome to Class Connect',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Podkova',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: colorScheme.onPrimary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RoleGrid — 2×2
// ─────────────────────────────────────────────────────────────────────────────
class _RoleGrid extends StatelessWidget {
  const _RoleGrid({
    required this.roles,
    required this.onRoleSelected,
    required this.controller,
    required this.isTablet,
  });

  final List<_RoleMeta> roles;
  final ValueChanged<UserRole> onRoleSelected;
  final AnimationController controller;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: roles.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: isTablet ? 1.1 : 1.0,
      ),
      itemBuilder: (context, i) => _AnimatedRoleCard(
        meta: roles[i],
        index: i,
        controller: controller,
        onTap: () => onRoleSelected(roles[i].role),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AnimatedRoleCard — staggered entrance + tap scale
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedRoleCard extends StatefulWidget {
  const _AnimatedRoleCard({
    required this.meta,
    required this.index,
    required this.controller,
    required this.onTap,
  });

  final _RoleMeta meta;
  final int index;
  final AnimationController controller;
  final VoidCallback onTap;

  @override
  State<_AnimatedRoleCard> createState() => _AnimatedRoleCardState();
}

class _AnimatedRoleCardState extends State<_AnimatedRoleCard>
    with SingleTickerProviderStateMixin {
  late final Animation<double> _entranceAnim;

  @override
  void initState() {
    super.initState();
    final start = (widget.index * 0.12).clamp(0.0, 0.7);
    final end = (start + 0.4).clamp(0.0, 1.0);
    _entranceAnim = CurvedAnimation(
      parent: widget.controller,
      curve: Interval(start, end, curve: Curves.easeOutBack),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entranceAnim,
      builder: (context, child) => Transform.scale(
        scale: _entranceAnim.value,
        child: Opacity(
          opacity: _entranceAnim.value.clamp(0.0, 1.0),
          child: child,
        ),
      ),
      child: PressableScale(
        onTap: widget.onTap,
        child: _RoleCard(meta: widget.meta),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RoleCard — pure UI
// ─────────────────────────────────────────────────────────────────────────────
class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.meta});
  final _RoleMeta meta;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colorScheme.onPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(meta.icon, color: colorScheme.onPrimary, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            meta.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Podkova',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onPrimary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RoleMeta — pure data
// ─────────────────────────────────────────────────────────────────────────────
@immutable
class _RoleMeta {
  const _RoleMeta(this.role, this.icon, this.label);
  final UserRole role;
  final IconData icon;
  final String label;
}
