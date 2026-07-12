import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/dio_client.dart';

class PaymentController {
  Future<Map<String, dynamic>> initiate({
    required String doctorId,
    required DateTime start,
    required DateTime end,
    String? reason,
  }) async {
    final response = await DioClient.instance.post(
      '/payments/khalti/initiate/',
      data: {
        'doctor': doctorId,
        'scheduled_start': start.toIso8601String(),
        'scheduled_end': end.toIso8601String(),
        'reason_for_visit': reason ?? '',
      },
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
