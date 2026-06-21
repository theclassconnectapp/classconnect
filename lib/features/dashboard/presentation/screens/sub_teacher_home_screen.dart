import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/di/injection_container.dart';
import '../../../ai/domain/repositories/ai_repository.dart';
import '../../../ai/presentation/screens/ai_chat_screen.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../groups/domain/repositories/group_repository.dart';
import '../../../groups/presentation/screens/semester_screen.dart';
import '../../../auth/presentation/screens/profile_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';

class SubTeacherHomeScreen extends StatefulWidget {
  const SubTeacherHomeScreen({super.key, required this.user});
  final AppUser user;

  @override
  State<SubTeacherHomeScreen> createState() => _SubTeacherHomeScreenState();
}

class _SubTeacherHomeScreenState extends State<SubTeacherHomeScreen> {
  int _selectedIndex = 1;

  Widget _homeTab() {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    if (widget.user.staffScopes == null || widget.user.staffScopes!.isEmpty) {
      return const SafeArea(
        child: Center(child: Text('No departments assigned yet')),
      );
    }
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.settings_outlined,
                    color: colorScheme.onSurface,
                  ),
                  tooltip: 'Settings',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ],
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
                'Subject Teacher Dashboard',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: sl<GroupRepository>().streamGroupsForUser(widget.user),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: colorScheme.onSurface,
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Error: \${snapshot.error}',
                        style: TextStyle(color: colorScheme.onSurface),
                      ),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? const [];
                final Map<String, Map<String, String>> folders = {};
                for (final doc in docs) {
                  final data = doc.data();
                  final dept = (data['dept'] ?? '') as String;
                  final batch = (data['batch'] ?? '') as String;
                  if (dept.isEmpty || batch.isEmpty) continue;
                  final key = '\$dept|\$batch';
                  folders[key] = {'dept': dept, 'batch': batch};
                }

                final folderList = folders.values.toList();
                folderList.sort((a, b) {
                  final deptCmp = a['dept']!.compareTo(b['dept']!);
                  if (deptCmp != 0) return deptCmp;
                  return a['batch']!.compareTo(b['batch']!);
                });

                if (folderList.isEmpty) {
                  return Center(
                    child: Text(
                      'No folders found',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: folderList.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final folder = folderList[index];
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        title: Text('${folder['dept']} — ${folder['batch']}'),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SemesterScreen(
                              user: widget.user,
                              dept: folder['dept']!,
                              batch: folder['batch']!,
                              groupRepository: sl<GroupRepository>(),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final List<Widget> tabs = [
      AiChatScreen(aiRepository: sl<AiRepository>()),
      _homeTab(),
      ProfileScreen(user: widget.user),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: List<Widget>.generate(tabs.length, (i) {
          final bool active = i == _selectedIndex;
          return AnimatedOpacity(
            opacity: active ? 1.0 : 0.0,
            duration: Motion.tabSwitch,
            curve: Motion.standard,
            child: IgnorePointer(
              ignoring: !active,
              child: tabs[i],
            ),
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
        child: Container(
          color: selected ? colorScheme.primary : colorScheme.surface,
          padding: EdgeInsets.only(
            top: 10,
            bottom: 10 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 26,
                color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: selected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
