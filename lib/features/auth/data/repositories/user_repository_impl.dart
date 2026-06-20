import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl({
    required this.collegeId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String collegeId;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('colleges').doc(collegeId).collection('users');

  @override
  Future<AppUser?> getUser(String uid) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _users.doc(uid).get();
      if (!doc.exists) return null;
      return AppUser.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to load user profile: $e');
    }
  }

  @override
  Future<void> saveUser(AppUser user) async {
    try {
      await _users.doc(user.uid).set(user.toFirestore());
    } catch (e) {
      throw Exception('Failed to save user profile: $e');
    }
  }

  @override
  Future<void> saveFcmToken({required String uid, required String token}) async {
    try {
      await _users.doc(uid).set(
        <String, dynamic>{'fcmToken': token},
        SetOptions(merge: true),
      );
    } catch (e) {
      throw Exception('Failed to save FCM token: $e');
    }
  }

  AppUser profileFromFirebaseUser({
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
}
