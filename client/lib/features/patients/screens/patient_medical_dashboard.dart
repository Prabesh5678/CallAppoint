import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/patient_provider.dart';
import '../widgets/biomarker_chart.dart';
import '../widgets/add_biomarker_sheet.dart';
import '../models/biomarker.dart';

class PatientMedicalDashboard extends ConsumerWidget {
  const PatientMedicalDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(patientDashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Health Journey'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(patientDashboardProvider),
          ),
        ],
      ),
      body: dashboardAsync.when(
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(patientDashboardProvider),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data.isLive)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16.0),
                    child: LinearProgressIndicator(),
                  ),

                // Latest Diagnosis Section
                _buildSectionHeader(context, 'Current Status'),
                _buildDiagnosisCard(context, data.latestDiagnosis),
                const SizedBox(height: 24),

                // Biomarker Trends Section
                _buildSectionHeader(context, 'Health Trends'),
                if (data.biomarkerSummaries.isEmpty)
                  const Center(child: Text('No biomarker data recorded yet.'))
                else ...[
                  ...data.biomarkerSummaries.entries.map((entry) {
                    final points = entry.value
                        .map((e) => BiomarkerTrendPoint(
                              date: DateTime.parse(e['date']),
                              value: e['value'],
                            ))
                        .toList()
                        .reversed
                        .toList(); // Reverse to show chronological order

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: BiomarkerChart(
                            trend: BiomarkerTrend(
                              name: entry.key,
                              unit: entry.value.first['unit'],
                              points: points,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  _buildRecentResultsList(context, ref, data.biomarkerSummaries),
                ],
                const SizedBox(height: 24),

                // Medical Profile Summary
                _buildSectionHeader(context, 'Medical Baseline'),
                _buildProfileSummary(context, data.medicalProfile),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => const AddBiomarkerSheet(),
          );
        },
        label: const Text('Add Lab Result'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Widget _buildDiagnosisCard(BuildContext context, dynamic diagnosis) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.healing, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    diagnosis?.conditionName ?? 'No Active Diagnosis',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (diagnosis?.overallStage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      diagnosis.overallStage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (diagnosis != null) ...[
              const Divider(height: 24),
              _buildInfoRow(Icons.calendar_today, 'Diagnosed on',
                  DateFormat('MMM dd, yyyy').format(diagnosis.dateOfDiagnosis)),
              if (diagnosis.tumorStage != null)
                _buildInfoRow(Icons.straighten, 'TNM Stage',
                    'T${diagnosis.tumorStage} N${diagnosis.nodesStage} M${diagnosis.metastasisStage}'),
              if (diagnosis.histology != null)
                _buildInfoRow(Icons.biotech, 'Histology', diagnosis.histology!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSummary(BuildContext context, dynamic profile) {
    if (profile == null) return const Text('Profile not completed');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                _buildCircularStat(context, 'Blood', profile.bloodGroup ?? '?'),
                const Spacer(),
                _buildCircularStat(context, 'Smoke', _capitalize(profile.smokingStatus)),
                const Spacer(),
                _buildCircularStat(context, 'Alcohol', _capitalize(profile.alcoholConsumption)),
              ],
            ),
            if (profile.familyCancerHistory) ...[
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.family_restroom, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text('Family History of Cancer',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCircularStat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _capitalize(String s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}';

  Widget _buildRecentResultsList(BuildContext context, WidgetRef ref, Map<String, List<dynamic>> summaries) {
    // Flatten and sort by date
    final allResults = <Map<String, dynamic>>[];
    summaries.forEach((name, list) {
      for (var item in list) {
        allResults.add({
          'name': name,
          ...item,
        });
      }
    });

    allResults.sort((a, b) => b['date'].compareTo(a['date']));
    final recent = allResults.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Lab Results',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recent.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = recent[index];
              return ListTile(
                title: Text(item['name']),
                subtitle: Text(DateFormat('MMM dd, yyyy').format(DateTime.parse(item['date']))),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${item['value']} ${item['unit']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (item['id'] != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        onPressed: () => _confirmDelete(context, ref, item['id'], item['name']),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Result?'),
        content: Text('Are you sure you want to delete this $name result?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(biomarkerActionsProvider).deleteBiomarker(id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
