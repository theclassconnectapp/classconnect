import 'package:flutter/material.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../data/repositories/semester_repository_impl.dart';
import '../../domain/repositories/group_repository.dart';
import 'dept_batch_folder_screen.dart';

class ArchivedSemestersScreen extends StatelessWidget {
  const ArchivedSemestersScreen({
    super.key,
    required this.user,
    required this.dept,
    required this.batch,
    required this.groupRepository,
  });

  final AppUser user;
  final String dept;
  final String batch;
  final GroupRepository groupRepository;

  List<String> _nonCurrentSemesters(String batch) {
    final String? current = SemesterService.currentSemesterLabel(batch);
    return SemesterService.allSemesters().where((s) => s != current).toList();
  }

  bool _isPast(String batch, String semLabel) {
    final int? current = SemesterService.currentSemesterNumber(batch);
    final int? semNum = int.tryParse(
      semLabel.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    if (current == null || semNum == null) return false;
    return semNum < current;
  }

  @override
  Widget build(BuildContext context) {
    final List<String> semesters = _nonCurrentSemesters(batch);
    final List<String> past = semesters
        .where((s) => _isPast(batch, s))
        .toList();
    final List<String> upcoming = semesters
        .where((s) => !_isPast(batch, s))
        .toList();

    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      'Class Connect',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'Archived Semesters',
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
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (past.isNotEmpty) ...[
                    _sectionLabel('Completed'),
                    const SizedBox(height: 10),
                    ...past.map(
                      (sem) => _SemCard(
                        semester: sem,
                        isPast: true,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => DeptBatchFolderScreen(
                              user: user,
                              dept: dept,
                              batch: batch,
                              groupRepository: groupRepository,
                              semester: sem,
                              readOnly: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (upcoming.isNotEmpty) ...[
                    _sectionLabel('Upcoming'),
                    const SizedBox(height: 10),
                    ...upcoming.map(
                      (sem) => _SemCard(
                        semester: sem,
                        isPast: false,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => DeptBatchFolderScreen(
                              user: user,
                              dept: dept,
                              batch: batch,
                              groupRepository: groupRepository,
                              semester: sem,
                              readOnly: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Builder(
        builder: (context) {
          final ColorScheme colorScheme = Theme.of(context).colorScheme;
          return Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.70),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          );
        },
      ),
    );
  }
}

class _SemCard extends StatelessWidget {
  const _SemCard({
    required this.semester,
    required this.isPast,
    required this.onTap,
  });

  final String semester;
  final bool isPast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Text(
              semester,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isPast
                    ? colorScheme.surfaceContainerHighest
                    : colorScheme.primary.withAlpha(26),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                isPast ? 'Completed' : 'Upcoming',
                style: TextStyle(
                  color: isPast
                      ? colorScheme.onSurface.withAlpha(153)
                      : colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
