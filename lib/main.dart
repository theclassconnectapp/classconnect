import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_options.dart';
import 'screens/auth_gate.dart';

const String _googleWebClientId =
    String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: '');
const String _fallbackGoogleWebClientId =
    '703382214228-r8psaei6tcq2c5hairjiractfjh79h5a.apps.googleusercontent.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ClassConnectBootApp());
}

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
      if (!mounted) {
        return;
      }
      setState(() => _ready = true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return const ClassConnectApp();
    }
    return MaterialApp(
      title: 'ClassConnect',
      home: Scaffold(
        appBar: AppBar(title: const Text('Starting ClassConnect')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (_error == null) ...<Widget>[
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                const Text('Initializing Firebase...'),
              ] else ...<Widget>[
                const Text(
                  'Startup failed',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(_error!),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _initialize,
                    child: const Text('Retry'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ClassConnectApp extends StatelessWidget {
  const ClassConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClassConnect',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const AuthGate(),
    );
  }
}
