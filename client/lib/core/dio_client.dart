import 'package:dio/dio.dart';
import 'supabase_client.dart';

const apiBaseUrl = 'http://10.0.2.2:8000/api'; // Android emulator -> localhost
// use 'http://localhost:8000/api' for iOS simulator or web
// use your machine's LAN IP for a physical device, e.g. http://192.168.1.5:8000/api

class DioClient {
  static final Dio _dio = Dio(BaseOptions(baseUrl: apiBaseUrl));

  static Dio get instance {
    if (_dio.interceptors.isEmpty) {
      _dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          final session = supabase.auth.currentSession;
          if (session != null) {
            options.headers['Authorization'] = 'Bearer ${session.accessToken}';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // if token expired, Supabase auto-refreshes on next currentSession access,
          // so a simple retry-once covers most 401s
          if (error.response?.statusCode == 401) {
            await supabase.auth.refreshSession();
            final retryOptions = error.requestOptions;
            final session = supabase.auth.currentSession;
            if (session != null) {
              retryOptions.headers['Authorization'] = 'Bearer ${session.accessToken}';
              try {
                final response = await _dio.fetch(retryOptions);
                return handler.resolve(response);
              } catch (_) {}
            }
          }
          return handler.next(error);
        },
      ));
    }
    return _dio;
  }
}