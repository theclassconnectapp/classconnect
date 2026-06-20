import 'dart:io';

/// NetworkInfo defines a platform-agnostic contract for checking connectivity.
/// Implementations must keep the implementation detail (package or platform APIs)
/// internal to the implementation to keep upper layers decoupled.
abstract class NetworkInfo {
  /// Returns `true` when an active internet connection is available.
  Future<bool> get isConnected;
}

/// Lightweight production implementation that tries a DNS lookup to determine
/// whether the device has internet access. This keeps the package surface
/// minimal and avoids adding an external dependency.
class NetworkInfoImpl implements NetworkInfo {
  const NetworkInfoImpl();

  @override
  Future<bool> get isConnected async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    }
  }
}
