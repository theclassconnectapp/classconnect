class Batch {
  const Batch({
    required this.id,
    required this.departmentId,
    required this.label,
    required this.startYear,
    required this.endYear,
    required this.archived,
  });

  final String id;
  final String departmentId;
  final String label;
  final int startYear;
  final int endYear;
  final bool archived;
}
