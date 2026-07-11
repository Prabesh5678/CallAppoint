import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import 'supabase_client.dart';

String get _apiHost {
  if (kIsWeb) return 'localhost';
  if (Platform.isAndroid) return '10.0.2.2'; // Android emulator special alias
  return 'localhost'; // iOS simulator
}
final String apiBaseUrl = 'http://$_apiHost:8000/api';

class DioClient {
  static final Dio _dio = Dio(BaseOptions(baseUrl: apiBaseUrl))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final session = supabase.auth.currentSession;
          if (session != null) {
            options.headers['Authorization'] = 'Bearer ${session.accessToken}';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            try {
              await supabase.auth.refreshSession();
              final session = supabase.auth.currentSession;
              if (session != null) {
                final retryOptions = error.requestOptions;
                retryOptions.headers['Authorization'] =
                    'Bearer ${session.accessToken}';
                final response = await _dio.fetch(retryOptions);
                return handler.resolve(response);
              }
            } catch (_) {}
          }
          return handler.next(error);
        },
      ),
    );

  static Dio get instance => _dio;
}
