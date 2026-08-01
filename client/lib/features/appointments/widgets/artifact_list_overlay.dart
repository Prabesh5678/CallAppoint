import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/artifact_provider.dart';
import '../providers/appointment_provider.dart';
import '../models/artifact.dart';

class ArtifactListOverlay extends ConsumerWidget {
  final String appointmentId;
  final VoidCallback onClose;

  const ArtifactListOverlay({
    super.key,
    required this.appointmentId,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Fetch current appointment details to get patient/doctor context
    final appointmentAsync = ref.watch(appointmentDetailProvider(appointmentId));

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            border: const Border(top: BorderSide(color: Colors.white10, width: 1)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Clinical History',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Patient-specific artifacts',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const CircleAvatar(
                      backgroundColor: Colors.white12,
                      child: Icon(Icons.close, color: Colors.white, size: 20),
                    ),
                    onPressed: onClose,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              appointmentAsync.when(
                data: (appointment) {
                  // 2. Fetch all artifacts shared between this doctor and patient
                  final allArtifactsAsync = ref.watch(patientDoctorArtifactsProvider((
                    patientId: appointment.patientId,
                    doctorId: appointment.doctorId,
                  )));

                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.6,
                    ),
                    child: allArtifactsAsync.when(
                      data: (artifacts) => artifacts.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: artifacts.length,
                              itemBuilder: (context, index) {
                                final artifact = artifacts[index];
                                final isNew = artifact.appointmentId == appointmentId;
                                return _buildArtifactTile(context, artifact, isNew);
                              },
                            ),
                      loading: () => const Center(child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(color: Colors.blueAccent),
                      )),
                      error: (err, stack) => Center(child: Text('Error loading history: $err', style: const TextStyle(color: Colors.red))),
                    ),
                  );
                },
                loading: () => const Center(child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(color: Colors.white24),
                )),
                error: (err, stack) => Text('Context Error: $err', style: const TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48.0),
      child: Column(
        children: [
          Icon(Icons.history_edu, color: Colors.white24, size: 48),
          const SizedBox(height: 16),
          const Text(
            'No previous artifacts found for this patient.',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildArtifactTile(BuildContext context, Artifact artifact, bool isCurrentSession) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCurrentSession ? Colors.blueAccent.withOpacity(0.15) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentSession ? Colors.blueAccent.withOpacity(0.4) : Colors.white10,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _getTypeColor(artifact.reportType).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_getTypeIcon(artifact.reportType), color: _getTypeColor(artifact.reportType)),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                artifact.title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            if (isCurrentSession)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(4)),
                child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            '${artifact.reportType} • ${DateFormat.yMMMd().format(artifact.createdAt.toLocal())}',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
        onTap: () => _showDetails(context, artifact),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Clinical Note': return Icons.description;
      case 'Laboratory Referral': return Icons.biotech;
      case 'Radiology Order': return Icons.visibility;
      case 'Diagnosis': return Icons.assignment;
      case 'Prescription': return Icons.medical_services;
      default: return Icons.insert_drive_file;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Clinical Note': return Colors.blue;
      case 'Laboratory Referral': return Colors.purple;
      case 'Radiology Order': return Colors.orange;
      case 'Diagnosis': return Colors.redAccent;
      case 'Prescription': return Colors.green;
      default: return Colors.grey;
    }
  }

  void _showDetails(BuildContext context, Artifact artifact) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Artifact Details',
      pageBuilder: (context, animation, secondaryAnimation) => Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_getTypeIcon(artifact.reportType), color: _getTypeColor(artifact.reportType)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        artifact.title,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Created by ${artifact.doctorName}',
                  style: const TextStyle(color: Colors.white54),
                ),
                const Divider(height: 32, color: Colors.white10),
                const Text(
                  'OBSERVATIONS & NOTES',
                  style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      artifact.content ?? 'No detailed notes provided.',
                      style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white10,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
