import 'package:flutter/material.dart';
import '../../../../core/dio_client.dart';

class CreateArtifactDialog extends StatefulWidget {
  final String appointmentId;

  const CreateArtifactDialog({super.key, required this.appointmentId});

  @override
  State<CreateArtifactDialog> createState() => _CreateArtifactDialogState();
}

class _CreateArtifactDialogState extends State<CreateArtifactDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedType = 'Clinical Note';
  bool _isLoading = false;

  final Map<String, IconData> _reportTypes = {
    'Clinical Note': Icons.note_alt_outlined,
    'Laboratory Referral': Icons.biotech_outlined,
    'Radiology Order': Icons.settings_remote_outlined,
    'Diagnosis': Icons.assignment_outlined,
    'Prescription': Icons.medical_services_outlined,
    'Other': Icons.more_horiz_outlined,
  };

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await DioClient.instance.post('/artifacts/', data: {
        'appointment': widget.appointmentId,
        'report_type': _selectedType,
        'title': _titleController.text,
        'content': _contentController.text,
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Artifact created successfully'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating artifact: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create artifact: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.add_chart, color: theme.colorScheme.primary, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'New Clinical Artifact',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a permanent clinical record for this session.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                  ),
                  const SizedBox(height: 24),

                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: InputDecoration(
                      labelText: 'Report Type',
                      prefixIcon: Icon(_reportTypes[_selectedType]),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                    items: _reportTypes.keys.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Row(
                          children: [
                            Icon(_reportTypes[type], size: 20),
                            const SizedBox(width: 10),
                            Text(type),
                          ],
                        )
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedType = val!),
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Title / Subject',
                      hintText: 'e.g., Post-consultation Summary',
                      prefixIcon: const Icon(Icons.title),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Please enter a title' : null,
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _contentController,
                    decoration: InputDecoration(
                      labelText: 'Clinical Notes',
                      hintText: 'Detailed observations, prescriptions, or instructions...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                    maxLines: 8,
                    validator: (val) => val == null || val.isEmpty ? 'Please enter content' : null,
                  ),
                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Create Record'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
