import 'package:dio/dio.dart';
import '../core/config.dart';

class AdminDioClient {
  static String? _token;
  static Dio? _dio;

  static void setToken(String? token) {
    _token = token;
    _dio?.options.headers['X-Admin-Token'] = _token;
  }

  static Dio get instance {
    _dio ??= Dio(BaseOptions(
      baseUrl: Config.adminApiBaseUrl,
    ));

    if (_token != null) {
      _dio!.options.headers['X-Admin-Token'] = _token;
    }

    return _dio!;
  }
}
