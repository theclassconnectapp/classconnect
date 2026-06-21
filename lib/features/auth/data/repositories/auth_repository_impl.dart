import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({AuthRemoteDataSource? dataSource})
    : _dataSource = dataSource ?? AuthRemoteDataSource();

  final AuthRemoteDataSource _dataSource;

  @override
  Stream<User?> get authStateChanges => _dataSource.authStateChanges;

  @override
  Future<UserCredential> signInWithGoogle() => _dataSource.signInWithGoogle();

  @override
  Future<void> signOut() => _dataSource.signOut();

  @override
  User? get currentUser => FirebaseAuth.instance.currentUser;
}
