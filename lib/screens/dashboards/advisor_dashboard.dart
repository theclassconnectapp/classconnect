import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/group_repository.dart';
import '../groups/folder_list_screen.dart';

class AdvisorDashboard extends StatelessWidget {
  const AdvisorDashboard({
    super.key,
    required this.user,
    required this.onSignOut,
  });

  final AppUser user;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return FolderListScreen(
      title: 'Advisor Dashboard',
      user: user,
      groupRepository: GroupRepository(),
      onSignOut: onSignOut,
    );
  }
}
