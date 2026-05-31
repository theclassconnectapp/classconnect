import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/group_repository.dart';
import '../groups/folder_list_screen.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({
    super.key,
    required this.user,
    required this.onSignOut,
  });

  final AppUser user;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return FolderListScreen(
      title: 'Student Dashboard',
      user: user,
      groupRepository: GroupRepository(),
      onSignOut: onSignOut,
    );
  }
}
