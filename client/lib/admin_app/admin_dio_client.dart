import 'package:dio/dio.dart';

const String adminApiBaseUrl = 'https://call-appoint.azurewebsites.net/api/admin-panel';
// Note: In a real app, this should be handled securely.
// Using the dev token for now as per instructions.
const String adminToken = 'dev_admin_token_12345';

class AdminDioClient {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: adminApiBaseUrl,
    headers: {'X-Admin-Token': adminToken},
  ));
  static Dio get instance => _dio;
}
