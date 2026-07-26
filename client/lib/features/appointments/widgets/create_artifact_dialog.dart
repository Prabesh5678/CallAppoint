import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
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

  final List<String> _reportTypes = [
    'Clinical Note',
    'Laboratory Referral',
    'Radiology Order',
    'Diagnosis',
    'Other'
  ];

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

      // Invalidate the provider to refresh the list
      // Note: we can't easily access ref here since it's a StatefulWidget,
      // but the caller can handle the refresh if we return true.

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Artifact created successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error creating artifact: $e');
      if (e is DioException) {
        debugPrint('Response data: ${e.response?.data}');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create artifact: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Clinical Artifact'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: 'Report Type'),
                items: _reportTypes.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (val) => setState(() => _selectedType = val!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g., Blood Test Referral',
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  hintText: 'Enter clinical notes or instructions here...',
                ),
                maxLines: 5,
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create'),
        ),
      ],
    );
  }
}
