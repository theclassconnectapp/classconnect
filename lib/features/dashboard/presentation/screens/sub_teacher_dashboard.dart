import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/di/injection_container.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/screens/profile_screen.dart';
import '../../../groups/domain/repositories/group_repository.dart';
import '../../../groups/presentation/screens/semester_screen.dart';

class SubTeacherDashboard extends StatefulWidget {
  const SubTeacherDashboard({super.key, required this.user});
  final AppUser user;

  @override
  State<SubTeacherDashboard> createState() => _SubTeacherDashboardState();
}

class _SubTeacherDashboardState extends State<SubTeacherDashboard> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _selectedIndex == 0
          ? _DashboardBody(user: widget.user)
          : ProfileScreen(user: widget.user),
      bottomNavigationBar: _BottomNav(
        selectedIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
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
                  icon: Icon(Icons.logout, color: colorScheme.onSurface),
                  onPressed: () async {
                    final bool? confirm = await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Sign out'),
                        content: const Text(
                          'You are about to sign out. Are you sure?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('No'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Yes'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      context.read<AuthCubit>().signOut();
                    }
                  },
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
                'Subject teacher dashboard',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(child: _FolderGrid(user: user)),
        ],
      ),
    );
  }
}

class _FolderGrid extends StatefulWidget {
  const _FolderGrid({required this.user});
  final AppUser user;

  @override
  State<_FolderGrid> createState() => _FolderGridState();
}

class _FolderGridState extends State<_FolderGrid> {
  final GroupRepository _repo = sl<GroupRepository>();

  List<Map<String, String>> _foldersFromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final Set<String> seen = <String>{};
    final List<Map<String, String>> folders = <Map<String, String>>[];
    for (final doc in docs) {
      final String dept = (doc.data()['dept'] as String?) ?? '';
      final String batch = (doc.data()['batch'] as String?) ?? '';
      if (dept.isEmpty || batch.isEmpty) continue;
      final String key = '$dept|$batch';
      if (seen.add(key)) {
        folders.add(<String, String>{'dept': dept, 'batch': batch});
      }
    }
    folders.sort((a, b) {
      final int deptCompare = a['dept']!.compareTo(b['dept']!);
      if (deptCompare != 0) return deptCompare;
      return a['batch']!.compareTo(b['batch']!);
    });
    return folders;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    if (widget.user.staffScopes == null || widget.user.staffScopes!.isEmpty) {
      return Center(
        child: Text(
          'No departments assigned yet',
          style: TextStyle(color: colorScheme.onPrimary.withAlpha(179)),
        ),
      );
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _repo.streamGroupsForUser(widget.user),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: colorScheme.onPrimary),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: TextStyle(color: colorScheme.onPrimary),
            ),
          );
        }
        final folders = _foldersFromDocs(snapshot.data?.docs ?? []);
        if (folders.isEmpty) {
          return Center(
            child: Text(
              'No departments found',
              style: TextStyle(color: colorScheme.onPrimary.withAlpha(179)),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            itemCount: folders.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) => _FolderCard(
              folder: folders[index],
              user: widget.user,
              repo: _repo,
            ),
          ),
        );
      },
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.folder,
    required this.user,
    required this.repo,
  });
  final Map<String, String> folder;
  final AppUser user;
  final GroupRepository repo;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final String dept = folder['dept'] ?? '';
    final String batch = folder['batch'] ?? '';
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SemesterScreen(
            user: user,
            dept: dept,
            batch: batch,
            groupRepository: repo,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Text(
          '$dept\n$batch',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selectedIndex, required this.onTap});
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.primary,
      child: Row(
        children: [
          _NavItem(
            icon: Icons.folder_outlined,
            selected: selectedIndex == 0,
            onTap: () => onTap(0),
          ),
          _NavItem(
            icon: Icons.person_outline,
            selected: selectedIndex == 1,
            onTap: () => onTap(1),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          color: selected ? colorScheme.surface : colorScheme.primary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Icon(
            icon,
            size: 28,
            color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
