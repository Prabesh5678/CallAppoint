import 'package:flutter/foundation.dart';

class Config {
  // Production URLs
  static const String _prodBaseUrl = 'https://call-appoint.azurewebsites.net/api';
  static const String _prodWsUrl = 'wss://call-appoint.azurewebsites.net';

  static String get apiBaseUrl {
    // Allows overriding via: flutter run --dart-define=API_URL=http://your-ip:8000/api
    const String envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) return envUrl;

    if (kDebugMode) {
      if (kIsWeb) return 'http://localhost:8000/api';

      // Android Emulator uses 10.0.2.2 to access host's localhost
      if (defaultTargetPlatform == TargetPlatform.android) {
        return 'http://10.0.2.2:8000/api';
      }
      return 'http://localhost:8000/api';
    }
    return _prodBaseUrl;
  }

  static String get wsBaseUrl {
    const String envWsUrl = String.fromEnvironment('WS_URL');
    if (envWsUrl.isNotEmpty) return envWsUrl;

    if (kDebugMode) {
      if (kIsWeb) return 'ws://localhost:8000';
      if (defaultTargetPlatform == TargetPlatform.android) {
        return 'ws://10.0.2.2:8000';
      }
      return 'ws://localhost:8000';
    }
    return _prodWsUrl;
  }

  static String get adminApiBaseUrl => '$apiBaseUrl/admin-panel';
}
