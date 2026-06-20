import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/user_repository.dart';
import '../../../groups/domain/repositories/group_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// States
// ─────────────────────────────────────────────────────────────────────────────

abstract class AuthState {}

class AuthLoading extends AuthState {}

class AuthUnauthenticated extends AuthState {}

class AuthNeedsCollegePick extends AuthState {
  AuthNeedsCollegePick(this.firebaseUser);
  final User firebaseUser;
}

class AuthNeedsProfileSetup extends AuthState {
  AuthNeedsProfileSetup(this.firebaseUser);
  final User firebaseUser;
}

class AuthAuthenticated extends AuthState {
  AuthAuthenticated(this.user, {this.isNewUser = false});
  final AppUser user;
  final bool isNewUser;
}

class AuthNeedsWelcomeBack extends AuthState {
  AuthNeedsWelcomeBack(this.user);
  final AppUser user;
}

class AuthNeedsTuitionHome extends AuthState {
  AuthNeedsTuitionHome(this.user);
  final AppUser user;
}

// ─────────────────────────────────────────────────────────────────────────────
// Cubit
// ─────────────────────────────────────────────────────────────────────────────

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required AuthRepository authRepository,
    UserRepository? userRepository,
  })  : _authRepository = authRepository,
        _userRepository = userRepository,
        super(AuthLoading()) {
    _init();
  }

  final AuthRepository _authRepository;
  UserRepository? _userRepository;
  final LocalStorageService _storage = LocalStorageService();
  User? _pendingFirebaseUser;
  AppUser? _pendingUser;

  UserRepository get _userRepo {
    _userRepository ??= sl<UserRepository>();
    return _userRepository!;
  }

  // Track if splash animation has finished
  bool _isSplashFinished = false;

  void _init() {
    _authRepository.authStateChanges.listen((User? firebaseUser) async {
      if (firebaseUser == null) {
        _pendingFirebaseUser = null;
        emit(AuthUnauthenticated());
      } else if (!_isSplashFinished) {
        _pendingFirebaseUser = firebaseUser;
        emit(AuthLoading());
      } else {
        await _handleLoggedInUser(firebaseUser);
      }
    });
  }

  /// Called by SplashScreen when animation finishes.
  void splashComplete() {
    _isSplashFinished = true;
    final pending = _pendingFirebaseUser;
    if (pending != null) {
      _pendingFirebaseUser = null;
      _handleLoggedInUser(pending);
    }
  }

  /// Central routing logic for any logged-in Firebase user.
  Future<void> _handleLoggedInUser(User firebaseUser) async {
    _pendingUser = null;

    // 1. Must have a college selected first.
    final String? collegeId = await _storage.getCollegeId();
    if (collegeId == null || collegeId.isEmpty) {
      emit(AuthNeedsCollegePick(firebaseUser));
      return;
    }

    // 2. Wire up college-scoped Firestore references.
    await initCollegeDependencies(collegeId);

    // 3. Check for existing Firestore profile.
    final AppUser? user = await _userRepo.getUser(firebaseUser.uid);
    if (user == null) {
      emit(AuthNeedsProfileSetup(firebaseUser));
    } else {
      _pendingUser = user;
      emit(AuthNeedsWelcomeBack(user));
    }
  }

  // ── Public actions ─────────────────────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    emit(AuthLoading());
    await _authRepository.signInWithGoogle();
  }

  Future<void> onCollegePicked(String collegeId) async {
    emit(AuthLoading());
    await _storage.saveCollegeId(collegeId);
    await initCollegeDependencies(collegeId);
    final User? firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      await _handleLoggedInUser(firebaseUser);
    } else {
      emit(AuthUnauthenticated());
    }
  }

  void onProfileSaved(AppUser user) {
    _pendingUser = user;
    _runSyncMembership(user);
    emit(AuthAuthenticated(user, isNewUser: true));
  }

  void welcomeSeen() {
    final current = state;
    if (current is AuthAuthenticated) {
      emit(AuthAuthenticated(current.user, isNewUser: false));
    }
  }

  void welcomeBackSeen() {
    final current = state;
    if (current is AuthNeedsWelcomeBack) {
      _runSyncMembership(current.user);
      emit(AuthAuthenticated(current.user, isNewUser: false));
    }
  }

  void onTuitionPicked() {
    if (_pendingUser != null) {
      emit(AuthNeedsTuitionHome(_pendingUser!));
      return;
    }

    final current = state;
    if (current is AuthNeedsCollegePick) {
      final firebase = current.firebaseUser;
      final minimal = AppUser(
        uid: firebase.uid,
        name: firebase.displayName ?? '',
        email: firebase.email ?? '',
        role: UserRole.student,
        photoUrl: firebase.photoURL,
      );
      emit(AuthNeedsTuitionHome(minimal));
    }
  }

  void _runSyncMembership(AppUser user) {
    try {
      final GroupRepository groupRepo = sl<GroupRepository>();
      groupRepo.syncMembership(user);
    } catch (_) {}
  }

  Future<void> signOut() async {
    _pendingUser = null;
    _pendingFirebaseUser = null;
    await _storage.clearAll();
    await _authRepository.signOut();
    emit(AuthUnauthenticated());
  }

  Future<void> clearCollege() async {
    await _storage.saveCollegeId('');
    final User? firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) emit(AuthNeedsCollegePick(firebaseUser));
  }

  AppUser? get currentUser =>
      state is AuthAuthenticated ? (state as AuthAuthenticated).user : null;
}