import '../../domain/entities/batch.dart';

class BatchModel extends Batch {
  const BatchModel({
    required super.id,
    required super.departmentId,
    required super.label,
    required super.startYear,
    required super.endYear,
    required super.archived,
  });

  factory BatchModel.fromJson(Map<String, Object?> json) {
    return BatchModel(
      id: json['id'] as String? ?? '',
      departmentId: json['departmentId'] as String? ?? '',
      label: json['label'] as String? ?? '',
      startYear: _readInt(json['startYear']),
      endYear: _readInt(json['endYear']),
      archived: json['archived'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'departmentId': departmentId,
      'label': label,
      'startYear': startYear,
      'endYear': endYear,
      'archived': archived,
    };
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}
