import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/dio_client.dart';

class BookingController {
  Future<void> book({
    required String doctorId,
    required DateTime start,
    required DateTime end,
    String? reason,
  }) async {
    await DioClient.instance.post(
      '/appointments/book/',
      data: {
        'doctor': doctorId,
        'scheduled_start': start.toIso8601String(),
        'scheduled_end': end.toIso8601String(),
        'reason_for_visit': reason ?? '',
      },
    );
  }
}

final bookingControllerProvider = Provider((ref) => BookingController());
