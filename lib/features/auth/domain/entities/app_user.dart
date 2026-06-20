import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../college/domain/entities/user_scope.dart';
import 'user_role.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.dept,
    this.batch,
    this.collegeId,
    this.departmentId,
    this.batchId,
    this.deptName,
    this.batchLabel,
    this.staffScopes,
    this.photoUrl,
  });

  final String uid;
  final String name;
  final String email;
  final UserRole role;
  // Legacy display strings — kept for Firestore query compatibility.
  // Source of truth is departmentId/batchId (Postgres-issued UUIDs).
  final String? dept;
  final String? batch;
  final String? collegeId;
  final String? departmentId;
  final String? batchId;
  final String? deptName;
  final String? batchLabel;
  final List<UserScope>? staffScopes;
  final String? photoUrl;

  AppUser copyWith({
    String? uid,
    String? name,
    String? email,
    UserRole? role,
    String? dept,
    String? batch,
    String? collegeId,
    String? departmentId,
    String? batchId,
    String? deptName,
    String? batchLabel,
    List<UserScope>? staffScopes,
    String? photoUrl,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      dept: dept ?? this.dept,
      batch: batch ?? this.batch,
      collegeId: collegeId ?? this.collegeId,
      departmentId: departmentId ?? this.departmentId,
      batchId: batchId ?? this.batchId,
      deptName: deptName ?? this.deptName,
      batchLabel: batchLabel ?? this.batchLabel,
      staffScopes: staffScopes ?? this.staffScopes,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return AppUser(
      uid: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: UserRole.fromId(data['role'] as String? ?? UserRole.student.id),
      dept: data['dept'] as String?,
      batch: data['batch'] as String?,
      collegeId: data['collegeId'] as String?,
      departmentId: data['departmentId'] as String?,
      batchId: data['batchId'] as String?,
      deptName: data['deptName'] as String?,
      batchLabel: data['batchLabel'] as String?,
      staffScopes: _readStaffScopes(data['staffScopes']),
      photoUrl: data['photoUrl'] as String?,
    );
  }

  factory AppUser.fromFirebaseUser({
    required User firebaseUser,
    required AppUser partial,
  }) {
    return AppUser(
      uid: firebaseUser.uid,
      name: partial.name.isNotEmpty
          ? partial.name
          : firebaseUser.displayName ?? '',
      email: partial.email.isNotEmpty
          ? partial.email
          : firebaseUser.email ?? '',
      role: partial.role,
      dept: partial.dept,
      batch: partial.batch,
      collegeId: partial.collegeId,
      departmentId: partial.departmentId,
      batchId: partial.batchId,
      deptName: partial.deptName,
      batchLabel: partial.batchLabel,
      staffScopes: partial.staffScopes,
      photoUrl: partial.photoUrl ?? firebaseUser.photoURL,
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'name': name,
      'email': email,
      'role': role.id,
      'dept': dept,
      'batch': batch,
      'collegeId': collegeId,
      'departmentId': departmentId,
      'batchId': batchId,
      'deptName': deptName,
      'batchLabel': batchLabel,
      'staffScopes': staffScopes?.map(_userScopeToFirestore).toList(),
      'photoUrl': photoUrl,
    };
  }

  static List<UserScope>? _readStaffScopes(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is! Iterable<Object?>) {
      return null;
    }

    final List<UserScope> scopes = <UserScope>[];
    for (final Object? item in value) {
      final UserScope? scope = _readUserScope(item);
      if (scope != null) {
        scopes.add(scope);
      }
    }
    return scopes;
  }

  static UserScope? _readUserScope(Object? value) {
    if (value is! Map<Object?, Object?>) {
      return null;
    }

    final Object? collegeId = value['collegeId'];
    final Object? departmentId = value['departmentId'];
    final Object? batchId = value['batchId'];
    final Object? role = value['role'];

    if (collegeId is! String || departmentId is! String) {
      return null;
    }

    return UserScope(
      collegeId: collegeId,
      departmentId: departmentId,
      batchId: batchId is String ? batchId : null,
      role: UserRole.fromId(role is String ? role : UserRole.student.id),
    );
  }

  static Map<String, dynamic> _userScopeToFirestore(UserScope scope) {
    return <String, dynamic>{
      'collegeId': scope.collegeId,
      'departmentId': scope.departmentId,
      'batchId': scope.batchId,
      'role': scope.role.id,
    };
  }
}
