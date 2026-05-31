import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<AppUser?> getUser(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _users.doc(uid).get();
    if (!doc.exists) {
      return null;
    }
    return AppUser.fromFirestore(doc);
  }

  Future<void> saveUser(AppUser user) async {
    await _users.doc(user.uid).set(user.toFirestore());
  }

  Future<void> saveFcmToken({
    required String uid,
    required String token,
  }) async {
    await _users.doc(uid).set(<String, dynamic>{
      'fcmToken': token,
    }, SetOptions(merge: true));
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
      photoUrl: partial.photoUrl ?? firebaseUser.photoURL,
    );
  }
}
