import 'package:dio/dio.dart';
import '../core/config.dart';

class AdminDioClient {
  static String? _token;

  static void setToken(String? token) {
    _token = token;
  }

  static Dio get instance {
    final dio = Dio(BaseOptions(
      baseUrl: Config.adminApiBaseUrl,
    ));

    if (_token != null) {
      dio.options.headers['X-Admin-Token'] = _token;
    }

    return dio;
  }
}
