class College {
  const College({
    required this.id,
    required this.name,
    this.logoUrl,
    this.allowedEmailDomain,
  });

  final String id;
  final String name;
  final String? logoUrl;
  final String? allowedEmailDomain;

  factory College.fromMap(String id, Map<String, dynamic> data) {
    return College(
      id: id,
      name: data['name'] as String? ?? id,
      logoUrl: data['logoUrl'] as String?,
      allowedEmailDomain: data['allowedEmailDomain'] as String?,
    );
  }
}
