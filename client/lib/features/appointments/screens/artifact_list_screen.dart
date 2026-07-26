import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/artifact_provider.dart';
import '../models/artifact.dart';

class ArtifactListScreen extends ConsumerWidget {
  const ArtifactListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artifactsAsync = ref.watch(artifactsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinical Reports & Artifacts'),
      ),
      body: artifactsAsync.when(
        data: (artifacts) => artifacts.isEmpty
            ? const Center(child: Text('No artifacts found.'))
            : ListView.builder(
                itemCount: artifacts.length,
                itemBuilder: (context, index) {
                  final artifact = artifacts[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text(artifact.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Type: ${artifact.reportType}'),
                          Text('Doctor: ${artifact.doctorName}'),
                          Text(
                            'Updated: ${DateFormat.yMMMd().add_jm().format(artifact.updatedAt.toLocal())}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      onTap: () {
                        _showArtifactDetails(context, artifact);
                      },
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _showArtifactDetails(BuildContext context, Artifact artifact) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              artifact.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Type: ${artifact.reportType}',
              style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
            const Divider(height: 32),
            if (artifact.content != null && artifact.content!.isNotEmpty) ...[
              const Text(
                'Notes:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(artifact.content!),
            ],
            if (artifact.fileUrl != null && artifact.fileUrl!.isNotEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implement file download/view
                },
                icon: const Icon(Icons.download),
                label: const Text('Download Attachment'),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
