import 'package:flutter/material.dart';

import '../../../auth/domain/entities/app_user.dart';
import 'student_home_screen.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return StudentHomeScreen(user: user);
  }
}
