import 'package:flutter/material.dart';

import '../../../../core/di/injection_container.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../groups/domain/repositories/group_repository.dart';
import '../../../groups/presentation/screens/folder_list_screen.dart';

class HodDashboard extends StatelessWidget {
  const HodDashboard({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return FolderListScreen(
      title: 'HOD Dashboard',
      user: user,
      groupRepository: sl<GroupRepository>(),
    );
  }
}
