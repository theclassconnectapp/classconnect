import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/group_repository.dart';
import '../groups/folder_list_screen.dart';

class HodDashboard extends StatelessWidget {
  const HodDashboard({
    super.key,
    required this.user,
    required this.onSignOut,
  });

  final AppUser user;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return FolderListScreen(
      title: 'HOD Dashboard',
      user: user,
      groupRepository: GroupRepository(),
      onSignOut: onSignOut,
    );
  }
}
