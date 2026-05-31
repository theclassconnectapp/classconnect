import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/group_repository.dart';
import '../services/notification_service.dart';
import '../services/user_repository.dart';
import 'dashboards/dashboard_router.dart';
import 'onboarding/profile_setup_screen.dart';
import 'onboarding/role_pick_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    this.authService,
    this.userRepository,
  });

  final AuthService? authService;
  final UserRepository? userRepository;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthService _authService =
      widget.authService ?? AuthService();
  late final UserRepository _userRepository =
      widget.userRepository ?? UserRepository();
  final GroupRepository _groupRepository = GroupRepository();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final User? firebaseUser = snapshot.data;
        if (firebaseUser == null) {
          return LoginScreen(authService: _authService);
        }

        return _UserProfileGate(
          firebaseUser: firebaseUser,
          userRepository: _userRepository,
          groupRepository: _groupRepository,
          authService: _authService,
        );
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      await widget.authService.signInWithGoogle();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ClassConnect')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Organized class media, not gallery clutter.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text('Sign in with your college Google account.'),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _signInWithGoogle,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: const Text('Sign in with Google'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _UserProfileGate extends StatefulWidget {
  const _UserProfileGate({
    required this.firebaseUser,
    required this.userRepository,
    required this.groupRepository,
    required this.authService,
  });

  final User firebaseUser;
  final UserRepository userRepository;
  final GroupRepository groupRepository;
  final AuthService authService;

  @override
  State<_UserProfileGate> createState() => _UserProfileGateState();
}

class _UserProfileGateState extends State<_UserProfileGate> {
  final NotificationService _notificationService = NotificationService();
  AppUser? _profile;
  UserRole? _pendingRole;
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final AppUser? profile = await widget.userRepository
          .getUser(widget.firebaseUser.uid)
          .timeout(const Duration(seconds: 8));
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile;
        _pendingRole = null;
        _loading = false;
      });
      if (profile != null) {
        if (profile.role == UserRole.advisor &&
            profile.dept != null &&
            profile.batch != null) {
          await widget.groupRepository.ensureGeneralGroupExists(
            dept: profile.dept!,
            batch: profile.batch!,
            advisorUid: profile.uid,
            advisorName: profile.name,
          );
          await widget.groupRepository.addMember(
            groupId: widget.groupRepository.generalGroupId(
              dept: profile.dept!,
              batch: profile.batch!,
            ),
            user: profile,
          );
        }
        await _notificationService.initialize(uid: profile.uid);
      }
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage =
            'Taking too long to reach the server. Please check your connection and try again.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _saveProfile(AppUser profile) async {
    await widget.userRepository.saveUser(profile);
    await widget.groupRepository.syncMembership(profile);
    await _loadProfile();
  }

  void _onRoleSelected(UserRole role) {
    if (role == UserRole.subjectTeacher) {
      final AppUser profile = widget.userRepository.profileFromFirebaseUser(
        firebaseUser: widget.firebaseUser,
        partial: AppUser(
          uid: widget.firebaseUser.uid,
          name: widget.firebaseUser.displayName ?? '',
          email: widget.firebaseUser.email ?? '',
          role: role,
          photoUrl: widget.firebaseUser.photoURL,
        ),
      );
      _saveProfile(profile);
      return;
    }
    setState(() => _pendingRole = role);
  }

  Future<void> _signOut() async {
    if (mounted) {
      setState(() {
        _profile = null;
        _pendingRole = null;
        _errorMessage = null;
        _loading = true;
      });
    }
    await widget.authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Connecting to ClassConnect')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Could not load your profile.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_errorMessage!),
              const Spacer(),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _signOut,
                      child: const Text('Sign out'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _loadProfile,
                      child: const Text('Retry'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_profile != null) {
      return DashboardRouter(user: _profile!, onSignOut: _signOut);
    }

    if (_pendingRole != null) {
      return ProfileSetupScreen(
        firebaseUser: widget.firebaseUser,
        role: _pendingRole!,
        userRepository: widget.userRepository,
        onSaved: _saveProfile,
        onBack: () => setState(() => _pendingRole = null),
      );
    }

    return RolePickScreen(onRoleSelected: _onRoleSelected);
  }
}
