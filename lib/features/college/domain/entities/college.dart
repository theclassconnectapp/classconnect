class College {
  const College({required this.id, required this.name, this.logoUrl});

  final String id;
  final String name;
  final String? logoUrl;

  factory College.fromMap(String id, Map<String, dynamic> data) {
    return College(
      id: id,
      name: data['name'] as String? ?? id,
      logoUrl: data['logoUrl'] as String?,
    );
  }
}
