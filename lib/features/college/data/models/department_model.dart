import '../../domain/entities/department.dart';

class DepartmentModel extends Department {
  const DepartmentModel({
    required super.id,
    required super.collegeId,
    required super.slug,
    required super.name,
    required super.code,
  });

  factory DepartmentModel.fromJson(Map<String, Object?> json) {
    return DepartmentModel(
      id: json['id'] as String? ?? '',
      collegeId: json['collegeId'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'collegeId': collegeId,
      'slug': slug,
      'name': name,
      'code': code,
    };
  }
}
