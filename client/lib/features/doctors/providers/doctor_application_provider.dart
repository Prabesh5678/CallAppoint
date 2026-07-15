import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/dio_client.dart';

class DoctorApplicationController {
  Future<void> apply({
    required String licenseNumber,
    required String bio,
    required int yearsExperience,
    required double consultationFee,
    required List<String> specialtyIds,
  }) async {
    await DioClient.instance.post(
      '/doctors/apply/',
      data: {
        'license_number': licenseNumber,
        'bio': bio,
        'years_experience': yearsExperience,
        'consultation_fee': consultationFee,
        'specialty_ids': specialtyIds,
      },
    );
  }
}

final doctorApplicationControllerProvider = Provider(
  (ref) => DoctorApplicationController(),
);

final applicationStatusProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
      try {
        final response = await DioClient.instance.get(
          '/doctors/application-status/',
        );
        if (response.data == null) return null;
        if (response.data is Map<String, dynamic>) {
          return response.data as Map<String, dynamic>;
        }
        return null;
      } catch (e) {
        return null;
      }
    });
