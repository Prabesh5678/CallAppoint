import 'package:flutter/material.dart';
import '../../features/doctors/models/doctor.dart';

class DoctorCard extends StatelessWidget {
  final Doctor doctor;
  final VoidCallback onTap;

  const DoctorCard({super.key, required this.doctor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final specialtyText = doctor.specialties.isNotEmpty
        ? doctor.specialties.map((s) => s.name).join(', ')
        : 'General Physician';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  backgroundImage: (doctor.avatarUrl != null && doctor.avatarUrl!.isNotEmpty)
                      ? NetworkImage(doctor.avatarUrl!)
                      : null,
                  child: (doctor.avatarUrl == null || doctor.avatarUrl!.isEmpty)
                      ? Icon(Icons.person, size: 36, color: Theme.of(context).colorScheme.primary)
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      specialtyText,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, size: 14, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                doctor.averageRating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${doctor.yearsExperience} years exp.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rs. ${doctor.consultationFee.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    'per visit',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Theme.of(context).hintColor.withOpacity(0.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
