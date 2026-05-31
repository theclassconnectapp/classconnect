import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/user_role.dart';
import 'advisor_dashboard.dart';
import 'hod_dashboard.dart';
import 'student_dashboard.dart';
import 'sub_teacher_dashboard.dart';

class DashboardRouter extends StatelessWidget {
  const DashboardRouter({
    super.key,
    required this.user,
    required this.onSignOut,
  });

  final AppUser user;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    switch (user.role) {
      case UserRole.student:
        return StudentDashboard(user: user, onSignOut: onSignOut);
      case UserRole.advisor:
        return AdvisorDashboard(user: user, onSignOut: onSignOut);
      case UserRole.subjectTeacher:
        return SubTeacherDashboard(user: user, onSignOut: onSignOut);
      case UserRole.hod:
        return HodDashboard(user: user, onSignOut: onSignOut);
    }
  }
}
