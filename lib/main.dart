import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'core/di/injection_container.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';
import 'features/auth/presentation/screens/auth_gate.dart';
import 'firebase_options.dart';
import 'core/presentation/controllers/theme_cubit.dart';
import 'features/groups/domain/repositories/group_repository.dart';
import 'shared/widgets/in_app_notification_banner.dart';

const String _googleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
  defaultValue: '',
);

const String _fallbackGoogleWebClientId =
    '703382214228-r8psaei6tcq2c5hairjiractfjh79h5a.apps.googleusercontent.com';

const String _environmentName = String.fromEnvironment(
  'ENVIRONMENT',
  defaultValue: 'development',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env.$_environmentName');
  runApp(const ClassConnectBootApp());
}

// ─────────────────────────────────────────────────────────────────────────────
// Boot wrapper — initialises Firebase + DI before showing the real app.
// ─────────────────────────────────────────────────────────────────────────────
class ClassConnectBootApp extends StatefulWidget {
  const ClassConnectBootApp({super.key});

  @override
  State<ClassConnectBootApp> createState() => _ClassConnectBootAppState();
}

class _ClassConnectBootAppState extends State<ClassConnectBootApp> {
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _ready = false;
      _error = null;
    });
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 12));

      final String? clientId = _googleWebClientId.isNotEmpty
          ? _googleWebClientId
          : (_fallbackGoogleWebClientId.contains('your-web-client-id')
                ? null
                : _fallbackGoogleWebClientId);

      await GoogleSignIn.instance
          .initialize(serverClientId: clientId)
          .timeout(const Duration(seconds: 10));

      await initDependencies();

      if (!mounted) return;
      setState(() => _ready = true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Still initialising or errored — show loading/error UI.
    if (!_ready) {
      return MaterialApp(
        title: 'ClassConnect',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: _error == null
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Starting up…'),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Startup failed',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(_error!),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _initialize,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    }

    // Firebase + DI ready → mount the real app with AuthCubit + ThemeCubit provided.
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(create: (_) => sl<AuthCubit>()),
        BlocProvider<ThemeCubit>(create: (_) => sl<ThemeCubit>()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return MaterialApp(
            title: 'ClassConnect',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeMode,
            home: const AuthGate(),
            builder: (context, child) {
              return BlocBuilder<AuthCubit, AuthState>(
                builder: (context, authState) {
                  if (authState is AuthAuthenticated) {
                    return InAppNotificationBanner(
                      user: authState.user,
                      groupRepository: sl<GroupRepository>(),
                      child: child ?? const SizedBox.shrink(),
                    );
                  }
                  return child ?? const SizedBox.shrink();
                },
              );
            },
          );
        },
      ),
    );
  }
}
