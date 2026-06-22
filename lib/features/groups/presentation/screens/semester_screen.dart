import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/screens/profile_screen.dart';
import '../../data/repositories/semester_repository_impl.dart';
import '../../domain/repositories/group_repository.dart';
import 'archived_semesters_screen.dart';
import 'dept_batch_folder_screen.dart';

class SemesterScreen extends StatefulWidget {
  const SemesterScreen({
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

  @override
  State<SemesterScreen> createState() => _SemesterScreenState();
}

class _SemesterScreenState extends State<SemesterScreen> {
  late final Stream<String?> _semStream = (() async* {
    yield SemesterService.currentSemesterLabel(widget.batch);
    yield* Stream.periodic(
      const Duration(minutes: 1),
      (_) => SemesterService.currentSemesterLabel(widget.batch),
    );
  })().distinct();

  @override
  Widget build(BuildContext context) {
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
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.folder_off_outlined,
                          color: colorScheme.onSurface,
                          size: 26,
                        ),
                        tooltip: 'Archived semesters',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ArchivedSemestersScreen(
                                user: widget.user,
                                dept: widget.dept,
                                batch: widget.batch,
                                groupRepository: widget.groupRepository,
                              ),
                            ),
                          );
                        },
                      ),
                      PopupMenuButton(
                        icon: Icon(
                          Icons.more_vert,
                          color: colorScheme.onSurface,
                        ),
                        onSelected: (String action) async {
                          if (action == 'profile') {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProfileScreen(
                                  user: widget.user,
                                  onSignOut: () =>
                                      context.read<AuthCubit>().signOut(),
                                ),
                              ),
                            );
                          } else if (action == 'signout') {
                            final bool? confirm = await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Sign out'),
                                content: const Text(
                                  'You are about to sign out. Are you sure?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('No'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Yes'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true && context.mounted) {
                              context.read<AuthCubit>().signOut();
                            }
                          }
                        },
                        itemBuilder: (_) => const <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'profile',
                            child: Text('Profile'),
                          ),
                          PopupMenuDivider(),
                          PopupMenuItem<String>(
                            value: 'signout',
                            child: Text('Sign out'),
                          ),
                        ],
                      ),
                    ],
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
                  'Semester — ${widget.dept}',
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
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.54,
                              ),
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No active semester right now',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.60,
                                ),
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
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.54,
                              ),
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
                                  dept: widget.dept,
                                  batch: widget.batch,
                                  groupRepository: widget.groupRepository,
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
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: colorScheme.outline.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.shadow.withValues(
                                    alpha: 0.08,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  currentSem,
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
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
      ),
    );
  }
}
