import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/artifact_provider.dart';
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
    final artifactsAsync = ref.watch(appointmentArtifactsProvider(appointmentId));

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Session Artifacts',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: onClose,
              ),
            ],
          ),
          const Divider(color: Colors.white24),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: artifactsAsync.when(
              data: (artifacts) => artifacts.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32.0),
                      child: Text('No artifacts created yet.', style: TextStyle(color: Colors.white70)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: artifacts.length,
                      itemBuilder: (context, index) {
                        final artifact = artifacts[index];
                        return Card(
                          color: Colors.white.withOpacity(0.1),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(
                              artifact.title,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${artifact.reportType} • ${DateFormat.jm().format(artifact.createdAt.toLocal())}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                            onTap: () => _showDetails(context, artifact),
                          ),
                        );
                      },
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
              error: (err, stack) => Text('Error: $err', style: const TextStyle(color: Colors.red)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context, Artifact artifact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(artifact.title, style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Type: ${artifact.reportType}',
                style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                artifact.content ?? 'No content provided.',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
