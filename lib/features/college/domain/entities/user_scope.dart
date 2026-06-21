import '../../../auth/domain/entities/user_role.dart';

class UserScope {
  const UserScope({
    required this.collegeId,
    required this.departmentId,
    required this.role,
    this.id,
    this.batchId,
  });

  final String? id;
  final String collegeId;
  final String departmentId;
  final String? batchId;
  final UserRole role;
}
