enum UserRole {
  student('student', 'Student'),
  advisor('advisor', 'Advisor'),
  subjectTeacher('subjectTeacher', 'Sub Teacher'),
  hod('hod', 'HOD');

  const UserRole(this.id, this.label);

  final String id;
  final String label;

  static UserRole fromId(String id) {
    return UserRole.values.firstWhere(
      (UserRole role) => role.id == id,
      orElse: () => UserRole.student,
    );
  }
}
