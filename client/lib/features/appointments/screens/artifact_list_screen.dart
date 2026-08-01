import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/centered_constrained_box.dart';
import '../../../shared/widgets/theme_toggle_button.dart';
import '../providers/artifact_provider.dart';
import '../models/artifact.dart';

class ArtifactListScreen extends ConsumerWidget {
  const ArtifactListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artifactsAsync = ref.watch(filteredArtifactsProvider);
    final currentFilter = ref.watch(artifactFilterProvider);

    final List<String> filters = [
      'All',
      'Clinical Note',
      'Laboratory Referral',
      'Radiology Order',
      'Diagnosis',
      'Prescription',
      'Other'
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Clinical History'),
            centerTitle: false,
            actions: [
              const ThemeToggleButton(),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.filter_list,
                  color: currentFilter != null && currentFilter != 'All'
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                initialValue: currentFilter ?? 'All',
                onSelected: (String value) {
                  ref.read(artifactFilterProvider.notifier).state = value;
                },
                itemBuilder: (BuildContext context) {
                  return filters.map((String filter) {
                    return PopupMenuItem<String>(
                      value: filter,
                      child: Row(
                        children: [
                          if ((currentFilter ?? 'All') == filter)
                            Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.primary)
                          else
                            const SizedBox(width: 18),
                          const SizedBox(width: 8),
                          Text(filter),
                        ],
                      ),
                    );
                  }).toList();
                },
              ),
            ],
          ),
          if (currentFilter != null && currentFilter != 'All')
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Chip(
                      label: Text('Filter: $currentFilter'),
                      onDeleted: () {
                        ref.read(artifactFilterProvider.notifier).state = 'All';
                      },
                    ),
                  ],
                ),
              ),
            ),
          artifactsAsync.when(
            data: (artifacts) => artifacts.isEmpty
                ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            currentFilter != null && currentFilter != 'All'
                                ? 'No $currentFilter records found.'
                                : 'No clinical artifacts found.',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    sliver: SliverToBoxAdapter(
                      child: CenteredConstrainedBox(
                        maxWidth: 900,
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          itemCount: artifacts.length,
                          itemBuilder: (context, index) {
                            final artifact = artifacts[index];
                            return _buildArtifactCard(context, artifact);
                          },
                        ),
                      ),
                    ),
                  ),
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, stack) => SliverFillRemaining(
              child: Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtifactCard(BuildContext context, Artifact artifact) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.05)),
      ),
      color: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
      child: InkWell(
        onTap: () => _showArtifactDetails(context, artifact),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getTypeColor(artifact.reportType).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getTypeIcon(artifact.reportType),
                  color: _getTypeColor(artifact.reportType),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artifact.title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${artifact.reportType} • ${artifact.doctorName}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      artifact.content ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.3),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat.yMMMd().add_jm().format(artifact.updatedAt.toLocal()),
                          style: TextStyle(fontSize: 11, color: theme.hintColor),
                        ),
                        Icon(Icons.arrow_forward_rounded, size: 16, color: theme.hintColor),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Clinical Note': return Icons.note_alt_rounded;
      case 'Laboratory Referral': return Icons.biotech_rounded;
      case 'Radiology Order': return Icons.settings_remote_rounded;
      case 'Diagnosis': return Icons.assignment_rounded;
      case 'Prescription': return Icons.medical_services_rounded;
      default: return Icons.description_rounded;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Clinical Note': return Colors.blue;
      case 'Laboratory Referral': return Colors.purple;
      case 'Radiology Order': return Colors.orange;
      case 'Diagnosis': return Colors.red;
      case 'Prescription': return Colors.green;
      default: return Colors.grey;
    }
  }

  void _showArtifactDetails(BuildContext context, Artifact artifact) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _getTypeColor(artifact.reportType).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_getTypeIcon(artifact.reportType), color: _getTypeColor(artifact.reportType)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                artifact.title,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(artifact.reportType, style: TextStyle(color: _getTypeColor(artifact.reportType), fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildDetailRow(context, Icons.person_outline, 'Doctor', artifact.doctorName),
                    _buildDetailRow(context, Icons.calendar_today_outlined, 'Date', DateFormat.yMMMMd().add_jm().format(artifact.updatedAt.toLocal())),
                    const Divider(height: 48),
                    const Text('CLINICAL NOTES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Colors.blueGrey)),
                    const SizedBox(height: 16),
                    Text(
                      artifact.content ?? 'No content.',
                      style: const TextStyle(fontSize: 16, height: 1.6),
                    ),
                    if (artifact.fileUrl != null) ...[
                      const SizedBox(height: 32),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.attachment),
                        label: const Text('View Attached File'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Text('$label:', style: const TextStyle(color: Colors.grey)),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
