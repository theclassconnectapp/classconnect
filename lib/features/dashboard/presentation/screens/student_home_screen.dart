import 'package:flutter/material.dart';
import '../../../../core/di/injection_container.dart';
import '../../../ai/domain/repositories/ai_repository.dart';
import '../../../ai/presentation/screens/ai_chat_screen.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/screens/profile_screen.dart';
import '../../../groups/data/repositories/semester_repository_impl.dart';
import '../../../groups/domain/repositories/group_repository.dart';
import '../../../groups/presentation/screens/archived_semesters_screen.dart';
import '../../../groups/presentation/screens/dept_batch_folder_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _selectedIndex = 1;

  late final Stream<String?> _semStream = (() async* {
    final String? batch = widget.user.batch;
    yield batch == null ? null : SemesterService.currentSemesterLabel(batch);
    yield* Stream.periodic(const Duration(minutes: 1), (_) {
      final String? batch = widget.user.batch;
      return batch == null ? null : SemesterService.currentSemesterLabel(batch);
    });
  })().distinct();

  Widget _homeTab() {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final String? dept = widget.user.dept;
    final String? batch = widget.user.batch;
    if (dept == null || batch == null) {
      return const SafeArea(
        child: Center(
          child: Text('Profile incomplete — please contact support'),
        ),
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
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.auto_awesome,
                        color: colorScheme.onSurface,
                      ),
                      tooltip: 'ClassConnect AI',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              AiChatScreen(aiRepository: sl<AiRepository>()),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.folder_open_outlined,
                        color: colorScheme.onSurface,
                      ),
                      tooltip: 'Archived Semesters',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ArchivedSemestersScreen(
                            user: widget.user,
                            dept: dept,
                            batch: batch,
                            groupRepository: sl<GroupRepository>(),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.settings_outlined,
                        color: colorScheme.onSurface,
                      ),
                      tooltip: 'Settings',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                    ),
                  ],
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
                'Semester — $dept',
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
            child: StreamBuilder<String?>(
              stream: _semStream,
              builder: (context, snapshot) {
                final String? currentSem = snapshot.data;
                if (currentSem == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.hourglass_empty,
                            color: colorScheme.onSurface.withAlpha(138),
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No active semester right now',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colorScheme.onSurface.withAlpha(179),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          'Active now',
                          style: TextStyle(
                            color: colorScheme.onSurface.withAlpha(153),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => DeptBatchFolderScreen(
                                user: widget.user,
                                dept: dept,
                                batch: batch,
                                groupRepository: sl<GroupRepository>(),
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 40,
                            horizontal: 24,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Column(
                            children: [
                              Text(
                                currentSem,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 52,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Text(
                                  SemesterService.currentAcademicYear(),
                                  style: TextStyle(
                                    color: colorScheme.onPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Tap to open',
                                style: TextStyle(
                                  color: colorScheme.onSurface.withAlpha(153),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
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
    final List<Widget> tabs = [
      AiChatScreen(aiRepository: sl<AiRepository>()),
      _homeTab(),
      ProfileScreen(user: widget.user),
    ];
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Stack + AnimatedOpacity instead of plain IndexedStack:
      // keeps every tab mounted (so state like _semStream survives switching)
      // but crossfades the visible one instead of snapping instantly.
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
