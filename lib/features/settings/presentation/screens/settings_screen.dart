import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/presentation/controllers/theme_cubit.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  Future<void> _showComingSoon() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon')),
    );
  }

  Future<void> _confirmSignOut() async {
    final navigator = Navigator.of(context);
    final authCubit = context.read<AuthCubit>();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sign out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await authCubit.signOut();
      navigator.popUntil((route) => route.isFirst);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final bool? deleteConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
            'This will permanently delete your account and all your data. '
            'This action cannot be undone. Are you sure?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (deleteConfirmed != true || !mounted) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        String confirmationText = '';

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Are you absolutely sure?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Type DELETE to confirm permanent deletion.'),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('deleteConfirmationField'),
                    autofocus: true,
                    onChanged: (value) {
                      setState(() {
                        confirmationText = value;
                      });
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'DELETE',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: confirmationText == 'DELETE'
                      ? () => Navigator.pop(context, true)
                      : null,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  child: const Text('Confirm Delete'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      // TODO: Wire actual account deletion logic when this screen is linked.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deletion not yet implemented')),
      );
    }
  }

  Widget _buildSection({required String header, required List<Widget> children}) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              header.toUpperCase(),
              style: TextStyle(
                color: colorScheme.onSurface.withAlpha(153),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final ThemeMode currentThemeMode = context.watch<ThemeCubit>().state;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: colorScheme.onSurface,
        leading: BackButton(color: colorScheme.onSurface),
        title: const Text('Settings'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          children: [
            // Appearance section — theme mode selection
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text('APPEARANCE', style: TextStyle(color: colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
                    ),
                    RadioGroup<ThemeMode>(
                      groupValue: currentThemeMode,
                      onChanged: (value) {
                        if (value != null) {
                          context.read<ThemeCubit>().setThemeMode(value);
                        }
                      },
                      child: Column(
                        children: [
                          RadioListTile<ThemeMode>(
                            value: ThemeMode.light,
                            title: Text('Light', style: TextStyle(color: colorScheme.onSurface)),
                          ),
                          RadioListTile<ThemeMode>(
                            value: ThemeMode.dark,
                            title: Text('Dark', style: TextStyle(color: colorScheme.onSurface)),
                          ),
                          RadioListTile<ThemeMode>(
                            value: ThemeMode.system,
                            title: Text('System', style: TextStyle(color: colorScheme.onSurface)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildSection(
              header: 'General',
              children: [
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () async {
                    final Uri url = Uri.parse('https://theclassconnect-privacy.pages.dev/');
                    final messenger = ScaffoldMessenger.of(context);
                    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Could not open the link')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.gavel_outlined),
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _showComingSoon,
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  trailing: Text('v1.0.0', style: TextStyle(color: colorScheme.onSurface.withAlpha(153))),
                  onTap: null,
                ),
              ],
            ),
            _buildSection(
              header: 'Account',
              children: [
                ListTile(
                  leading: Icon(Icons.logout, color: colorScheme.error),
                  title: Text(
                    'Sign Out',
                    style: TextStyle(color: colorScheme.error),
                  ),
                  onTap: _confirmSignOut,
                ),
                ListTile(
                  leading: Icon(Icons.delete_forever_outlined, color: colorScheme.error),
                  title: Text('Delete Account', style: TextStyle(color: colorScheme.error)),
                  subtitle: Text(
                    'This action cannot be undone',
                    style: TextStyle(color: colorScheme.error.withAlpha(153)),
                  ),
                  onTap: _confirmDeleteAccount,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
