import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/animation/motion.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/user_repository.dart';
import '../../presentation/controllers/auth_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    this.onSignOut,
    this.isOwnProfile = true,
  });
  final AppUser user;
  final VoidCallback? onSignOut;
  final bool isOwnProfile;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final UserRepository _userRepository;

  @override
  void initState() {
    super.initState();
    _userRepository = sl<UserRepository>();
  }

  Future<void> _editName() async {
    final TextEditingController controller = TextEditingController(
      text: widget.user.name,
    );
    final String? name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit display name'),
        content: TextField(controller: controller),
        actions: [
          PressableScale(
            onTap: () => Navigator.of(context).pop(),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _userRepository.saveUser(
      AppUser(
        uid: widget.user.uid,
        name: name,
        email: widget.user.email,
        role: widget.user.role,
        dept: widget.user.dept,
        batch: widget.user.batch,
        photoUrl: widget.user.photoUrl,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Display name updated')));
  }

  Future<void> _confirmSignOut() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('You are about to sign out. Are you sure?'),
        actions: [
          PressableScale(
            onTap: () => Navigator.pop(context, false),
            child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
          ),
          PressableScale(
            onTap: () => Navigator.pop(context, true),
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      if (widget.onSignOut != null) {
        widget.onSignOut!();
      } else {
        context.read<AuthCubit>().signOut();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Class Connect',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.isOwnProfile)
                    PressableScale(
                      onTap: _confirmSignOut,
                      child: IconButton(
                        icon: Icon(Icons.logout, color: colorScheme.onSurface),
                        onPressed: _confirmSignOut,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                'Profile',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 50),
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(80),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Center(
                  child: UserAvatar(
                    name: widget.user.name,
                    photoUrl: widget.user.photoUrl,
                    radius: 48,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _InfoPill(label: 'Name: ${widget.user.name}'),
                  const SizedBox(height: 12),
                  _InfoPill(label: 'Role: ${widget.user.role.label}'),
                  const SizedBox(height: 12),
                  _InfoPill(label: 'Email: ${widget.user.email}'),
                ],
              ),
            ),
            const SizedBox(height: 28),
            if (widget.isOwnProfile)
              PressableScale(
                onTap: _editName,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: colorScheme.onSurface,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Edit',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}
