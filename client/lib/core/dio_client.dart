import 'package:dio/dio.dart';
import 'supabase_client.dart';
import 'config.dart';

class DioClient {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: Config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ),
  )
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
