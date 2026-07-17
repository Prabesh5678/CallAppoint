import 'package:dio/dio.dart';

const String adminApiBaseUrl = 'https://call-appoint.azurewebsites.net/api/admin-panel';

class AdminDioClient {
  static String? _token;

  static void setToken(String? token) {
    _token = token;
  }

  static Dio get instance {
    final dio = Dio(BaseOptions(
      baseUrl: adminApiBaseUrl,
    ));

    if (_token != null) {
      dio.options.headers['X-Admin-Token'] = _token;
    }

    return dio;
  }
}
