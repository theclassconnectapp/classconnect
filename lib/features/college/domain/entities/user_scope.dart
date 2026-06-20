import '../../../auth/domain/entities/user_role.dart';

class UserScope {
  const UserScope({
    required this.collegeId,
    required this.departmentId,
    required this.role,
    this.batchId,
  });

  final String collegeId;
  final String departmentId;
  final String? batchId;
  final UserRole role;
}
