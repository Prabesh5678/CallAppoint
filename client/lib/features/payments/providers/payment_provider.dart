import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/dio_client.dart';

class PaymentController {
  Future<Map<String, dynamic>> initiate(String appointmentId) async {
    final response = await DioClient.instance.post(
      '/payments/khalti/initiate/$appointmentId/',
    );
    return response.data;
  }

  Future<Map<String, dynamic>> verify(String pidx) async {
    final response = await DioClient.instance.post(
      '/payments/khalti/verify/',
      data: {'pidx': pidx},
    );
    return response.data;
  }
}

final paymentControllerProvider = Provider((ref) => PaymentController());
