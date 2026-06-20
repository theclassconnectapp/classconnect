import 'dart:developer' as developer;

/// Unified logging wrapper for the application.
/// Use `Logger` as a single entry point for debug/info/warn/error logs.
class Logger {
  Logger._();

  /// Enable or disable logging globally; defaults to true in debug builds.
  static bool enabled = true;

  static void _log(String level, String message, {Object? error, StackTrace? stackTrace}) {
    if (!enabled) return;
    final String time = DateTime.now().toIso8601String();
    final String full = '[$time] [$level] $message';
    if (error != null) {
      developer.log(full, error: error, stackTrace: stackTrace);
    } else {
      developer.log(full);
    }
  }

  /// Debug-level logging. Verbose, for development use.
  static void debug(String message, {Object? error, StackTrace? stackTrace}) {
    _log('DEBUG', message, error: error, stackTrace: stackTrace);
  }

  /// Informational messages about app flow.
  static void info(String message, {Object? error, StackTrace? stackTrace}) {
    _log('INFO', message, error: error, stackTrace: stackTrace);
  }

  /// Warning messages indicating a possible issue that does not crash the app.
  static void warn(String message, {Object? error, StackTrace? stackTrace}) {
    _log('WARN', message, error: error, stackTrace: stackTrace);
  }

  /// Error messages for unexpected failures.
  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    _log('ERROR', message, error: error, stackTrace: stackTrace);
  }
}
